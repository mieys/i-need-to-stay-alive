extends Node2D

## EVCİL HAYVAN "KİRPİ" (kullanıcı isteği 2026-10-13): "Sana saldıran tüm yaratıklar kalkan gücünün %5'i kadar hasar alır, kalkanın varken
## aldığın tüm hasar %5 azalır. Dikenler sahibinin görüş açısında düşman varsa AÇIK, düşman yokken KAPALI."
##  - Hasar kuralları player.gd _kirpi_on_hit'te (take_damage kancası; sabitler pet_catalog.gd KIRPI_*). Bu betik sadece GÖRSEL + dikenlerin
##    açık/kapalı kararı: oyunun hiçbir hesabı dikenin açık olmasına bağlı DEĞİL (diken her zaman çalışır, açık hali "düşman var" göstergesi).
##  - Zemin hayvanı: sahibin çocuğu ama top_level; köpekle aynı "topuk noktası" takibi (sahibin hareket yönünün arkası + yan), engel/su/ağaç
##    gövdesinde (GameManager.is_position_blocked_by_terrain) yürümez, çok uzaklaşınca / sıkışınca topuk noktasına atlar. Gölge sprite'ta pişmiş.
##  - Yön sprite sayfasından (kirpi_frames.tres, üretici tools/gen_kirpi.py): acik_/kapali_ + [walk_] + down|up|left|right; yürürken
##    walk_ klibi (gövde sekmesi + ayak değişimi karelerde), dururken nefes klibi; klip değişirken kare korunur.
##  - Çizim sırası: hayvan sahibin ARKASINDA (ayağı sahibin ayağından yukarıda) ise çocuk sırasının başına, önündeyse sonuna alınır
##    (sahibin sprite'ı da bir çocuk; oyuncular zaten kendi aralarında y-sıralı - main.gd _update_character_draw_order).
##
## "Görüşünde düşman": sahibin KENDİ görüşü (VisionFog.own_vision_contains - sis elipsi + duvar/ağaç ışını; takım arkadaşının görüşü sayılmaz).
## Taramalar SCAN_INTERVAL'da bir ve EnemyQuery.candidates (C++ ızgara) ile; kapanma CLOSE_DELAY gecikmeli (yaratık sınırda gidip gelirken
## diken titremesin). Açılma anında hemen açar.
##
## Çok oyunculu (Peri/Kelebek deseni): seçim ağdan gitmez. Karar SADECE sahibinin ekranında verilir; değişince + NET_HEARTBEAT'te bir
## NetworkManager.broadcast_kirpi yollar, diğer ekranlardaki kukla ilk olayda kurulur (remote_player.gd kirpi_event) ve durumu uygular. Konumu
## kukla kendi hesaplar (sahibin kuklasını aynı kuralla izler) - konum ağdan gitmez.

const VisionFogScript: GDScript = preload("res://scripts/vision_fog.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const FRAMES: SpriteFrames = preload("res://assets/pets/kirpi/kirpi_frames.tres")
const PetFollowScript := preload("res://scripts/pet_follow.gd")

const SCAN_INTERVAL := 0.25
const CLOSE_DELAY := 1.0
const NET_HEARTBEAT := 8.0
## Takip (köpek player_pet.gd ile aynı model, daha sade).
const HEEL_BEHIND := 15.0
const HEEL_SIDE := 13.0
const OWNER_MOVING_SPEED := 25.0
const HEADING_SMOOTH := 5.0
const ACCEL := 1100.0 ## düşük ivme: kalkış/duruş yumuşak, ani dönüş yok
const MIN_SPEED_CAP := 220.0
const WARP_DISTANCE := 480.0
const STUCK_SECONDS := 1.5
const MOVING_SPEED_MIN := 12.0
const BEHIND_HYSTERESIS := 3.0
const POP_TIME := 0.14 ## diken açılıp kapanırken kısa "çök-ve-aç" vurgusu

var owner_body: Node2D = null
var char_anim: AnimatedSprite2D = null
var is_puppet: bool = false

var _sprite: AnimatedSprite2D = null
var _open: bool = false
var _dir: String = "down"
var _moving: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _heading: Vector2 = Vector2.DOWN
var _follow = PetFollowScript.new()
var _owner_prev: Vector2 = Vector2.ZERO
var _owner_vel: Vector2 = Vector2.ZERO
var _have_owner_prev: bool = false
var _stuck_t: float = 0.0
var _stuck_sample: float = 0.0
var _stuck_ref: Vector2 = Vector2.ZERO
var _scan_cd: float = 0.0
var _close_cd: float = 0.0
var _net_idle: float = NET_HEARTBEAT - 1.0 ## ilk "buradayım" kurulumdan 1 sn sonra
var _pop: float = 0.0
var _is_behind: bool = false


func setup(body: Node2D, anim_src: AnimatedSprite2D, puppet: bool) -> void:
	owner_body = body
	char_anim = anim_src
	is_puppet = puppet
	name = "Kirpi"
	_follow.comfort_radius = 24.0 ## küçük hayvan: sahibe daha yakın durur
	_follow.start_radius = 46.0
	top_level = true
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	## Hücre 32x32; ayak (gölge altı) hücrenin alt kenarına yakın - düğüm orijini ayak hizasına gelsin.
	_sprite.offset = Vector2(0.0, -14.0)
	add_child(_sprite)
	global_scale = Vector2.ONE * EntityScale.SIZE
	_sprite.play(&"kapali_down")
	global_position = _heel_point()
	_owner_prev = body.global_position
	_stuck_ref = global_position


func _process(delta: float) -> void:
	if not is_instance_valid(owner_body) or not is_instance_valid(char_anim):
		return
	delta = minf(delta, 0.1)
	_pop = maxf(0.0, _pop - delta)
	_update_owner_velocity(delta)
	_process_movement(delta)
	_update_animation()
	_update_draw_order()
	_sprite.scale = Vector2(1.0 + 0.12 * (_pop / POP_TIME), 1.0 - 0.18 * (_pop / POP_TIME)) if _pop > 0.0 else Vector2.ONE
	if not is_puppet:
		process_spikes(delta)


## ---------------------------------------------------------------- takip

func _update_owner_velocity(delta: float) -> void:
	var o: Vector2 = owner_body.global_position
	if _have_owner_prev and delta > 0.0:
		var raw: Vector2 = (o - _owner_prev) / delta
		_owner_vel = _owner_vel.lerp(raw, minf(1.0, delta * 12.0)) if raw.length() < 1500.0 else Vector2.ZERO
	_owner_prev = o
	_have_owner_prev = true


func _heel_point() -> Vector2:
	var o: Vector2 = owner_body.global_position
	var p: Vector2 = o - _heading * HEEL_BEHIND + _heading.orthogonal() * HEEL_SIDE
	if GameManager.is_position_blocked_by_terrain(p):
		return o
	return p


func _warp_to_heel() -> void:
	global_position = _heel_point()
	_velocity = Vector2.ZERO
	_follow.active = false
	_stuck_t = 0.0
	_stuck_ref = global_position


func _process_movement(delta: float) -> void:
	var o: Vector2 = owner_body.global_position
	if global_position.distance_to(o) > WARP_DISTANCE:
		_warp_to_heel()
		return
	if _owner_vel.length() > OWNER_MOVING_SPEED:
		_heading = _heading.lerp(_owner_vel.normalized(), minf(1.0, delta * HEADING_SMOOTH))
		_heading = _heading.normalized() if _heading.length() > 0.05 else _owner_vel.normalized()
	## Doğal takip (pet_follow.gd): sahibin hızı kullanılmaz; sahip uzaklaşınca uzaklığa göre hızlanıp yaklaşınca yavaşlayarak yetişir.
	var cap: float = maxf(MIN_SPEED_CAP, _owner_vel.length() * 1.3)
	var desired: Vector2 = _follow.ground_velocity(global_position, o, delta, cap)
	_velocity = _velocity.move_toward(desired, ACCEL * delta)
	if _velocity.length() > 1.0:
		_step(_velocity * delta)
	_check_stuck(delta, desired.length() > 60.0)


## Engele (su/bina tabanı/ağaç gövdesi) girmeden adım: önce tam adım, olmazsa tek eksen.
func _step(step: Vector2) -> void:
	var p: Vector2 = global_position
	if not GameManager.is_position_blocked_by_terrain(p + step):
		global_position = p + step
	elif not GameManager.is_position_blocked_by_terrain(p + Vector2(step.x, 0.0)):
		global_position = p + Vector2(step.x, 0.0)
	elif not GameManager.is_position_blocked_by_terrain(p + Vector2(0.0, step.y)):
		global_position = p + Vector2(0.0, step.y)
	else:
		_velocity = Vector2.ZERO


## Gitmek istediği halde 0,5 sn'de 14 px'ten az ilerliyorsa sıkışık sayar; STUCK_SECONDS sürerse ve sahipten uzaksa topuk noktasına atlar.
func _check_stuck(delta: float, wants_move: bool) -> void:
	_stuck_sample += delta
	if _stuck_sample < 0.5:
		return
	_stuck_sample = 0.0
	var moved: float = global_position.distance_to(_stuck_ref)
	_stuck_ref = global_position
	if wants_move and moved < 14.0:
		_stuck_t += 0.5
	else:
		_stuck_t = 0.0
		return
	if _stuck_t >= STUCK_SECONDS:
		_stuck_t = 0.0
		if global_position.distance_to(owner_body.global_position) > 90.0:
			_warp_to_heel()


## ---------------------------------------------------------------- görsel

func _update_animation() -> void:
	_moving = _velocity.length() > MOVING_SPEED_MIN
	if _moving:
		_dir = _dir_of(_velocity)
	_apply_clip()


## Eksen baskınlığı (köpekle aynı): yatay hız dikeyden büyükse sağ/sol, değilse aşağı/yukarı.
static func _dir_of(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0.0 else "left"
	return "down" if v.y > 0.0 else "up"


## Klip = (açık|kapalı) + (yürüyorsa walk_) + yön; yön/diken değişirken kare ve ilerleme korunur (nefes/adım baştan başlamaz).
## Duruş <-> yürüyüş geçişinde kare sayıları farklı (duruş 15, yürüyüş 4): yeni klip baştan başlar.
func _apply_clip() -> void:
	var want := StringName(("acik_" if _open else "kapali_") + ("walk_" if _moving else "") + _dir)
	if _sprite.animation != want:
		var keep: bool = FRAMES.get_frame_count(want) == FRAMES.get_frame_count(_sprite.animation)
		var f: int = _sprite.frame
		var p: float = _sprite.frame_progress
		_sprite.play(want)
		if keep:
			_sprite.set_frame_and_progress(f, p)


func is_open() -> bool:
	return _open


func current_clip() -> StringName:
	return _sprite.animation


func set_open(v: bool) -> void:
	if v == _open:
		return
	_open = v
	_pop = POP_TIME
	if _sprite:
		_apply_clip()


## Hayvan sahibinin arkasındaysa çocuk sırasının başında (sahibin sprite'ının altında), önündeyse sonunda çizilir.
func _update_draw_order() -> void:
	var dy: float = global_position.y - owner_body.global_position.y
	var want_behind: bool = _is_behind
	if dy < -BEHIND_HYSTERESIS:
		want_behind = true
	elif dy > BEHIND_HYSTERESIS:
		want_behind = false
	if want_behind != _is_behind or get_parent() != owner_body:
		_is_behind = want_behind
		if get_parent() == owner_body:
			owner_body.move_child(self, 0 if want_behind else owner_body.get_child_count() - 1)


## ---------------------------------------------------------------- diken kararı (sahibin ekranı)

## Her karede (testler doğrudan çağırır): tarama aralığında düşman var mı bakar; varsa hemen açar, yoksa CLOSE_DELAY sonra kapatır.
func process_spikes(delta: float) -> void:
	if owner_frozen(): ## güvenli alanda (satıcı koruması / demirci) zaman donar: tarama durur, diken durumu olduğu gibi kalır (madde 327)
		return
	_net_idle += delta
	_scan_cd -= delta
	if _scan_cd <= 0.0:
		_scan_cd = SCAN_INTERVAL
		if owner_sees_enemy():
			_close_cd = CLOSE_DELAY
			if not _open:
				set_open(true)
				_broadcast()
		else:
			_close_cd = maxf(0.0, _close_cd - SCAN_INTERVAL)
			if _open and _close_cd <= 0.0:
				set_open(false)
				_broadcast()
	if _net_idle >= NET_HEARTBEAT:
		_broadcast()


## Sahip güvenli alanda mı (player.gd is_safe_zone_frozen): evcil hayvanlar orada çalışmaz.
func owner_frozen() -> bool:
	return is_instance_valid(owner_body) and owner_body.has_method("is_safe_zone_frozen") and owner_body.is_safe_zone_frozen()


## Sahibin KENDİ görüşünde canlı bir yaratık var mı (takım görüşü sayılmaz).
func owner_sees_enemy() -> bool:
	if not is_inside_tree() or not is_instance_valid(owner_body):
		return false
	if owner_body.get("is_dead") == true or owner_body.get("is_indoors") == true:
		return false
	var tree: SceneTree = get_tree()
	var o: Vector2 = owner_body.global_position
	var reach: float = VisionFogScript.current_radius(tree) * VisionFogScript.VISION_WIDTH_SCALE + EnemyQueryScript.BODY_PAD
	for e in EnemyQueryScript.candidates(tree, o, reach):
		var n := e as Node2D
		if n == null or not is_instance_valid(n) or not n.is_in_group("enemies") or n.get("is_dead") == true:
			continue
		if VisionFogScript.own_vision_contains(tree, o, n.global_position):
			return true
	return false


func _broadcast() -> void:
	_net_idle = 0.0
	if is_puppet or not NetworkManager.is_multiplayer_active:
		return
	NetworkManager.broadcast_kirpi.rpc(multiplayer.get_unique_id(), _open)


## remote_player.gd -> kirpi_event: sahibi dikenlerin durumunu bildirdi (konum kuklada kendi hesaplanır).
func apply_remote_state(open: bool) -> void:
	set_open(open)
