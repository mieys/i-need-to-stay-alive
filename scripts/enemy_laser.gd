extends Node2D

## Röntgen lazeri (bkz. enemy_abilities.gd _process_laser): önce data.warn saniye boyunca yaratığın baktığı yöne doğru
## akan kesikli kırmızı UYARI ÇİZGİSİ (kullanıcı isteği: "ışın atılmadan önce uyarı çizgisi gelmeli"), sonra data.fire
## saniye boyunca parlayan mor-beyaz IŞIN. Işın süresince çizgiye değen her oyuncu BİR kez vurulur (host/yetkili
## örnek), hasar player.gd take_special_damage("laser") ile - kalkana normalin 2 katı.
## PERFORMANS: çizgi ve ışın TEK bir Sprite2D (tools/gen_enemy_ability_fx.py karoları, texture_repeat + region ile
## uzunluğa yayılır); uyarı çizgisinin akışı sadece region.position.x kaydırması, ışın titreşimi 4 karonun sırayla
## değişmesi - her karede _draw() yok.

const TEXEL := 1.212
const WARN_TEX := preload("res://assets/fx/enemy_abilities/laser_warn.png")
const BEAM_TEX := [
	preload("res://assets/fx/enemy_abilities/laser_beam_0.png"),
	preload("res://assets/fx/enemy_abilities/laser_beam_1.png"),
	preload("res://assets/fx/enemy_abilities/laser_beam_2.png"),
	preload("res://assets/fx/enemy_abilities/laser_beam_3.png"),
]
const FLASH_FRAMES := preload("res://assets/fx/enemy_abilities/laser_flash_frames.tres")
const FxScript := preload("res://scripts/fx_enemy_ability.gd")
const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const WARN_SCROLL_SPEED := 40.0 ## karo pikseli/sn - çizgi yaratıktan hedefe doğru akar
const BEAM_FRAME_TIME := 0.05
const BEAM_HALF_WIDTH := 7.0 ## dünya birimi - isabet toleransı (+ oyuncu gövdesi)
const WARN_START_ALPHA := 0.45

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _dir: Vector2 = Vector2.RIGHT
var _length: float = 400.0
var _warn: float = 0.9
var _fire: float = 0.3
var _t: float = 0.0
var _sprite: Sprite2D = null
var _fired: bool = false
var _beam_frame: int = 0
var _beam_frame_t: float = 0.0
var _hit: Array = []


func _ready() -> void:
	z_index = 11
	_dir = Vector2(data.get("dir", Vector2.RIGHT))
	if _dir.length() < 0.01:
		_dir = Vector2.RIGHT
	_dir = _dir.normalized()
	_length = float(data.get("length", 400.0))
	_warn = float(data.get("warn", 0.9))
	_fire = float(data.get("fire", 0.3))
	rotation = _dir.angle()
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.scale = Vector2.ONE * TEXEL
	add_child(_sprite)
	_set_texture(WARN_TEX)
	_sprite.modulate.a = WARN_START_ALPHA


func _set_texture(tex: Texture2D) -> void:
	_sprite.texture = tex
	var h: float = float(tex.get_height())
	_sprite.region_rect = Rect2(0.0, 0.0, _length / TEXEL, h)
	_sprite.offset = Vector2(0.0, -h * 0.5)


func _process(delta: float) -> void:
	_t += delta
	if _t < _warn:
		## Uyarı: çizgi akar, sona yaklaştıkça hızlı yanıp söner ve belirginleşir.
		var k: float = _t / maxf(_warn, 0.01)
		var r: Rect2 = _sprite.region_rect
		r.position.x = -_t * WARN_SCROLL_SPEED
		_sprite.region_rect = r
		var blink: float = 0.5 + 0.5 * sin(_t * lerpf(10.0, 34.0, k))
		_sprite.modulate.a = lerpf(WARN_START_ALPHA, 1.0, k) * (0.65 + 0.35 * blink)
		return
	if not _fired:
		_fired = true
		_set_texture(BEAM_TEX[0])
		_sprite.modulate.a = 1.0
		var scene_root: Node = get_tree().current_scene
		FxScript.spawn(scene_root, global_position + _dir * 8.0, FLASH_FRAMES, &"muzzle", 12)
		FxScript.spawn(scene_root, global_position + _dir * _length, FLASH_FRAMES, &"hit", 12)
	var ft: float = _t - _warn
	if ft >= _fire:
		queue_free()
		return
	_beam_frame_t += delta
	if _beam_frame_t >= BEAM_FRAME_TIME:
		_beam_frame_t = 0.0
		_beam_frame = (_beam_frame + 1) % BEAM_TEX.size()
		_sprite.texture = BEAM_TEX[_beam_frame]
	## Son %40'ta incelerek söner.
	var fade: float = clampf((_fire - ft) / (_fire * 0.4), 0.0, 1.0)
	_sprite.scale = Vector2(TEXEL, TEXEL * lerpf(0.3, 1.0, fade))
	_sprite.modulate.a = fade
	if authoritative:
		_check_hits()


func _check_hits() -> void:
	var a: Vector2 = global_position
	var b: Vector2 = global_position + _dir * _length
	for p in AbilitiesScript.damageable_players(get_tree()):
		if p in _hit:
			continue
		var pos: Vector2 = (p as Node2D).global_position
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(pos, a, b)
		if closest.distance_to(pos) <= BEAM_HALF_WIDTH + AbilitiesScript.TARGET_BODY_RADIUS:
			_hit.append(p)
			AbilitiesScript.deal_special_damage(p, damage, source, "laser")
