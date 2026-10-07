extends Node

## KAMERA SARSINTISI (kullanıcı isteği 2026-10-05: boss doğuşu/ölümü, zafer, ultimate patlamaları, yıldırım, ağır hasar, kendi ölümün
## gibi nadir ve güçlü anlara kısa sarsıntı + AYARLARDAN KAPATMA). Merkezi sistem, tek yerden:
##  - Olay yeri `CameraShake.add(miktar)` (her yerde) ya da `add_at(dünya_konumu, miktar)` (kameraya uzaklığa göre azalır) çağırır.
##    `add_limited(anahtar, miktar, aralık)` aynı olayın art arda tetiklenmesini sınırlar (ör. 13 boss'un doğuş RPC'leri).
##  - Sarsıntı AĞDAN GÖNDERİLMEZ: her peer olayı zaten kendi yerelinde alıyor (boss RPC'si, yıldırım yayını, FX sahneleri kendi
##    _ready/setup'ında çağırır) ve kendi kamerasına uzaklığa göre sarsılır - CLAUDE.md'nin "kaster görür, diğeri görmez" sınıfına girmez.
##  - Model: biriken "travma" (0..1) zamanla söner; titreme genliği travma^2 (küçük travma neredeyse hiç, büyüğü belirgin).
##    Piksel-art uyumu: dönme YOK, ofset kamera zoom'una göre tam EKRAN pikseline yuvarlanır, her 1/STEP_HZ sn'de bir yeni yön
##    (yumuşak gürültü yerine "retro" adımlı titreme).
##  - Ayar: UISound.camera_shake_percent (0 = kapalı). 0'dayken hiçbir şey birikmez ve kameraya dokunulmaz.
## Sürücü düğüm (bu script'in örneği) main.gd'de sahneye eklenir; kamera ofsetini her kare "fark" olarak uygular (başka biri
## Camera2D.offset'i değiştirirse ezmez). Oyun duraklatılınca (level atlama, menü) ofset hemen sıfırlanır, travma silinir.
## Kullanım: const CameraShakeScript := preload("res://scripts/camera_shake.gd") ; CameraShakeScript.add_at(pos, 0.5)

const MAX_OFFSET := 12.0 ## travma 1'de dünya birimi (zoom 2'de 24 ekran px)
const DECAY := 1.3 ## travma/sn
const STEP_HZ := 30.0
const FALLOFF_RADIUS := 1300.0 ## dünya birimi: bundan uzaktaki olay hiç sarsmaz (kamera yarı genişliği 480)

static var trauma: float = 0.0
## Testler gerçek kullanıcı ayarına dokunmadan gücü sabitler (<0 = UISound.camera_shake_percent'e bak).
static var strength_override: float = -1.0
static var _last_fire: Dictionary = {} ## anahtar -> Time.get_ticks_msec()

var _cam: Camera2D = null
var _applied: Vector2 = Vector2.ZERO
var _step_timer: float = 0.0
var _dir: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()


# ---------------------------------------------------------------- olay API'si (static)
## 0..1 arası güç: kullanıcı ayarı (UISound.camera_shake_percent / 100) ya da test için strength_override.
static func strength() -> float:
	if strength_override >= 0.0:
		return strength_override
	return clampf(UISound.camera_shake_percent / 100.0, 0.0, 1.0)


static func set_strength_override(v: float) -> void:
	strength_override = v


static func reset() -> void:
	trauma = 0.0
	_last_fire.clear()


## Konumdan bağımsız sarsıntı (kameraya her yerde aynı).
static func add(amount: float) -> void:
	if strength() <= 0.0 or amount <= 0.0:
		return
	trauma = minf(1.0, trauma + amount)


## Dünya konumundaki olay: aktif kameranın merkezine uzaklığa göre azalır (smoothstep, FALLOFF_RADIUS'ta 0).
static func add_at(world_pos: Vector2, amount: float, radius: float = FALLOFF_RADIUS) -> void:
	if strength() <= 0.0 or amount <= 0.0:
		return
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	var cam: Camera2D = loop.root.get_viewport().get_camera_2d()
	if cam == null:
		return
	add(amount * falloff(cam.get_screen_center_position().distance_to(world_pos), radius))


## Aynı anahtarlı olay en çok `interval` saniyede bir (global). world_pos verilirse add_at, yoksa add.
static func add_limited(key: String, amount: float, interval: float, world_pos: Variant = null) -> void:
	var now: int = Time.get_ticks_msec()
	if now - int(_last_fire.get(key, -1000000)) < int(interval * 1000.0):
		return
	_last_fire[key] = now
	if world_pos == null:
		add(amount)
	else:
		add_at(world_pos as Vector2, amount)


## Mesafe -> 0..1 çarpan (SAF).
static func falloff(distance: float, radius: float) -> float:
	if radius <= 0.0:
		return 0.0
	var f: float = clampf(1.0 - distance / radius, 0.0, 1.0)
	return f * f * (3.0 - 2.0 * f)


## Travma + güç + yön -> ham ofset (SAF; yön -1..1 bileşenli).
static func raw_offset(trauma_value: float, strength_value: float, dir: Vector2) -> Vector2:
	var t: float = clampf(trauma_value, 0.0, 1.0)
	return dir * (MAX_OFFSET * t * t * clampf(strength_value, 0.0, 1.0))


## Ofseti kamera zoom'una göre tam ekran pikseline yuvarlar (SAF): 1 ekran px = 1/zoom dünya birimi.
static func snap(offset: Vector2, zoom: float) -> Vector2:
	var step: float = 1.0 / maxf(zoom, 0.01)
	return Vector2(roundf(offset.x / step), roundf(offset.y / step)) * step


# ---------------------------------------------------------------- sürücü düğüm
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS ## duraklatılınca da çalışır: ofseti temizlemesi gerek
	_rng.randomize()


func _exit_tree() -> void:
	_release()


func _process(delta: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam != _cam:
		_release()
		_cam = cam
	if _cam == null:
		return
	if get_tree().paused or strength() <= 0.0:
		trauma = 0.0
	trauma = maxf(0.0, trauma - DECAY * delta)
	var target: Vector2 = Vector2.ZERO
	if trauma > 0.0:
		_step_timer += delta
		if _step_timer >= 1.0 / STEP_HZ or _dir == Vector2.ZERO:
			_step_timer = 0.0
			_dir = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
		target = snap(raw_offset(trauma, strength(), _dir), _cam.zoom.x)
	if target != _applied:
		_cam.offset += target - _applied
		_applied = target


## Uygulanan ofseti kameradan geri al (kamera değişince / düğüm kalkınca).
func _release() -> void:
	if _cam != null and is_instance_valid(_cam) and _applied != Vector2.ZERO:
		_cam.offset -= _applied
	_applied = Vector2.ZERO
	_cam = null
