extends Node2D

## Oakley Sarmaşıklar (E) - sabitlenen (rooted) yaratığın bacaklarına sarılan dikenli sarmaşık (kullanıcı isteği 2026-09-25:
## Oakley efektlerinin pixel tarzda yeniden tasarımı; eskiden kök salmanın HİÇ görseli yoktu, yaratık sadece duruyordu).
## tools/gen_oakley_fx.py "entangle_{s,m,l}_{back,front}" sayfaları: "grow" (topraktan çıkıp sarılır) -> "loop" (sıkar,
## dikenler parlar) -> "break" (kopup düşer). Yaratığın gövde yarıçapına göre 3 boy (ölçekleme yok - piksel boyu hep aynı).
## Arka yarısı yaratığın ARKASINDA (bu düğüm show_behind_parent), ön yarısı ÖNÜNDE (yaratığa kardeş olarak eklenen ön katman)
## - fx_paladin_barrier_link.gd ile aynı iki katman deseni.
##
## Senkron: enemy.gd _set_root_visual - host (ya da tek oyunculu) kök salmayı uygulayınca yerelde kurar ve
## broadcast_enemy_vfx "root_start"/"root_stop" ile herkese yayınlar; iki taraf bu AYNI sahneyi kurar.

const TEXEL := 1.212
## boy -> [arka, ön, kare yüksekliği H, zemin satırı gy] (bkz. gen_oakley_fx.py ENT_SIZES)
const SIZES := {
	"s": [preload("res://assets/fx/oakley/entangle_s_back_frames.tres"), preload("res://assets/fx/oakley/entangle_s_front_frames.tres"), 30.0, 24.0],
	"m": [preload("res://assets/fx/oakley/entangle_m_back_frames.tres"), preload("res://assets/fx/oakley/entangle_m_front_frames.tres"), 42.0, 33.0],
	"l": [preload("res://assets/fx/oakley/entangle_l_back_frames.tres"), preload("res://assets/fx/oakley/entangle_l_front_frames.tres"), 62.0, 51.0],
}
## Yaratıkların kökü ayak hizasına çok yakın (ölçüm: 40 yaratık sahnesinde ayak ~ +2..+22, çoğu ~+4 yerel birim).
const FEET_Y := 4.0
## Süre bitince host'un "root_stop"u gelmese bile (paket/düğüm kaybı) kendi kendine kopar.
const SELF_RELEASE_GRACE := 0.25

var _back: AnimatedSprite2D = null
var _front: AnimatedSprite2D = null
var _time_left: float = 0.0
var _releasing: bool = false


## enemy.gd ekledikten hemen sonra çağırır. body_radius: enemy.gd _body_radius (boss ölçeği dahil).
func setup(duration: float, body_radius: float) -> void:
	var key: String = "s" if body_radius <= 16.0 else ("m" if body_radius <= 30.0 else "l")
	var cfg: Array = SIZES[key]
	var center := Vector2(0.0, FEET_Y - (float(cfg[3]) - float(cfg[2]) * 0.5) * TEXEL)
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_back = _make_layer(cfg[0], center)
	add_child(_back)
	_front = _make_layer(cfg[1], center)
	var host: Node = get_parent()
	if host != null:
		host.add_child.call_deferred(_front)
	_back.animation_finished.connect(_on_anim_finished)
	_back.play(&"grow")
	_front.play(&"grow")
	_time_left = duration


## Kök salma yenilendi (aynı yaratığa yeni isabet): süre uzar, kopmaktaysa geri sarılır.
func refresh(duration: float) -> void:
	_time_left = maxf(_time_left, duration)
	if _releasing:
		_releasing = false
		_play(&"grow")


## Kök salma bitti ya da yaratık öldü: kopma animasyonu, sonra iki katman da silinir.
func release() -> void:
	if _releasing:
		return
	_releasing = true
	_play(&"break")


func _make_layer(frames: SpriteFrames, center: Vector2) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * TEXEL
	s.position = center
	return s


func _play(anim: StringName) -> void:
	if _back != null:
		_back.play(anim)
	if is_instance_valid(_front):
		_front.play(anim)


func _on_anim_finished() -> void:
	if _back.animation == &"grow":
		_play(&"loop")
	elif _back.animation == &"break":
		queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_front):
		_front.queue_free()


func _process(delta: float) -> void:
	if _back == null or _releasing:
		return
	_time_left -= delta
	if _time_left <= -SELF_RELEASE_GRACE:
		release()
	## Ön katman sonradan (call_deferred) eklendiği için karesini arka katmanla eşitle.
	if is_instance_valid(_front) and _front.animation == _back.animation and _front.frame != _back.frame:
		_front.frame = _back.frame
