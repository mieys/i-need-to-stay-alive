extends Node2D

## Assasin Çocuk pasifi "Bıçak Uzmanlığı" görseli - kullanıcı isteği (2026-10-16): "pasifi için de özel efekt hazırlayalım, varlığı
## hiç belli olmuyor". Pasif (yetenek kullanımından sonraki 3 sn garantili kritik, player.gd _assasin_crit_timer) hiç görünmüyordu.
## Gövdeye (yerel Player ya da uzak kukla) eklenen TEK düğüm; assasin_ult_fx.gd trigger_passive() her yetenek kullanımında yeniler:
##  - passive_proc: tetiklenince gövde merkezinde parlama + dışa açılan kırmızı halka + yukarı süzülen bıçak kıymıkları.
##  - Dış hat: karakterin O ANKİ karesinin kopyası + shaders/assasin_passive_outline.gdshader (kritik kırmızısı, kayan parıltı bandı).
##  - passive_glint: süre boyunca gövdenin çevresinde ara ara küçük yıldız parlamaları.
##  - Son BLINK_TIME sn dış hat yanıp söner (bitiş okunur); süre dolunca düğüm silinir.
## Sprite'lar karakterin PİKSEL ölçeğinde (gövde sprite'ının ölçeği - 48x48 dili, sayfalar tools/gen_assasin_passive_fx.py). Gövdenin
## çocuğu olduğu için modulate'ini (görünmezlik saydamlığı, ulti koyu tonu) kendiliğinden miras alır. Gece ışığı YOK (gizlilik).

const PROC_FRAMES: SpriteFrames = preload("res://assets/fx/assasin/passive_proc_frames.tres")
const GLINT_FRAMES: SpriteFrames = preload("res://assets/fx/assasin/passive_glint_frames.tres")
const OUTLINE_SHADER: Shader = preload("res://shaders/assasin_passive_outline.gdshader")
const BLINK_TIME := 0.6
const BLINK_HZ := 10.0
const GLINT_INTERVAL := 0.3
## Parıltıların çıktığı elips (karakter pikseli, gövde merkezine göre) - gövde ~16x38.
const GLINT_AREA := Vector2(10.0, 17.0)
## Kare merkezinden gövde merkezine (karakter pikseli): ayak satırı 40, baş ~2 -> merkez ~21, kare merkezi 24.
const BODY_CENTER := Vector2(0.0, -3.0)

static var _outline_mat: ShaderMaterial = null

var _time_left: float = 0.0
var _sprite: AnimatedSprite2D = null
var _outline: Sprite2D = null
var _glint_timer: float = 0.0


func refresh(duration: float) -> void:
	_time_left = duration
	_glint_timer = 0.12
	_ensure_parts()
	if _sprite == null:
		return
	var proc := AnimatedSprite2D.new()
	proc.sprite_frames = PROC_FRAMES
	proc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	proc.scale = _px_scale()
	proc.position = _body_center()
	add_child(proc)
	proc.play(&"play")
	proc.animation_finished.connect(proc.queue_free)


func time_left() -> float:
	return _time_left


func _ensure_parts() -> void:
	if _sprite == null or not is_instance_valid(_sprite):
		_sprite = get_parent().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _outline == null:
		if _outline_mat == null:
			_outline_mat = ShaderMaterial.new()
			_outline_mat.shader = OUTLINE_SHADER
		_outline = Sprite2D.new()
		_outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_outline.material = _outline_mat
		add_child(_outline)
		_sync_outline()


func _px_scale() -> Vector2:
	return _sprite.scale.abs() if _sprite != null else Vector2.ONE


func _body_center() -> Vector2:
	if _sprite == null:
		return Vector2.ZERO
	return _sprite.position + (_sprite.offset + BODY_CENTER) * _sprite.scale


func _process(delta: float) -> void:
	_time_left -= delta
	var body: Node = get_parent()
	if _time_left <= 0.0 or body == null or body.get("is_dead") == true:
		name = "AssasinPassiveFxEnd" ## aynı karede yeniden tetiklenirse yeni düğüm asıl adı alabilsin (yoksa ikinci dış hat)
		queue_free()
		return
	_sync_outline()
	if _outline != null:
		_outline.visible = _outline.texture != null and (_time_left > BLINK_TIME or fmod(_time_left * BLINK_HZ, 1.0) < 0.5)
	_glint_timer -= delta
	if _glint_timer <= 0.0 and _sprite != null:
		_glint_timer = GLINT_INTERVAL * randf_range(0.7, 1.3)
		_spawn_glint()


func _sync_outline() -> void:
	if _outline == null:
		return
	var s: AnimatedSprite2D = _sprite
	if s == null or not is_instance_valid(s) or s.sprite_frames == null or not s.sprite_frames.has_animation(s.animation):
		_outline.texture = null
		return
	_outline.texture = s.sprite_frames.get_frame_texture(s.animation, s.frame)
	_outline.position = s.position
	_outline.rotation = s.rotation
	_outline.scale = s.scale
	_outline.offset = s.offset
	_outline.centered = s.centered
	_outline.flip_h = s.flip_h
	_outline.flip_v = s.flip_v


func _spawn_glint() -> void:
	var a: float = randf() * TAU
	var r: float = randf_range(0.65, 1.0)
	var g := AnimatedSprite2D.new()
	g.sprite_frames = GLINT_FRAMES
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.scale = _px_scale()
	g.position = _body_center() + Vector2(cos(a) * GLINT_AREA.x, sin(a) * GLINT_AREA.y) * r * _px_scale()
	add_child(g)
	g.play(&"play")
	g.animation_finished.connect(g.queue_free)
