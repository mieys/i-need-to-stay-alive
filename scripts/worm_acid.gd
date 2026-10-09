extends Node2D

## Yeraltı Canavarı'nın asit tükürüğü (bkz. worm_limb.gd _fire_acid, spawn_world_fx kind "worm_acid"): düz bir çizgide uçan zehirli yeşil damla.
## İlk değdiği oyuncuya data.damage (110) verir, orman duvarına / satıcı bölgesine / Şovalye kalkanına çarpınca ya da menzili bitince sönüp sıçrar.
## Yetkili (host/tek oyunculu) örnek hasar verir (player.gd take_special_damage kind "worm_acid" = normal vuruş); istemcilerdeki görsel kopya sadece uçar
## ve değince aynı sıçrama animasyonunu oynar (enemy_fireball.gd ile AYNI desen). Görseller paketin "poison shot" sayfaları (20x21 kare, SAĞA uçar).
## Sayılar worm_boss_math.gd'de.

const MathScript := preload("res://scripts/worm_boss_math.gd")
const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const LOOP_TEX := preload("res://assets/enemies/sandworm/acid_loop.png")
const END_TEX := preload("res://assets/enemies/sandworm/acid_end.png")
const FRAME_W := 20
const FRAME_H := 21
const TEXEL := 2.2 ## dünya birimi / doku pikseli (solucan 2,4)
const FPS := 14.0
const WALL_IGNORE_TIME := 0.08

static var _frames: SpriteFrames = null

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _dir: Vector2 = Vector2.RIGHT
var _speed: float = MathScript.ACID_SPEED
var _range_left: float = MathScript.ACID_RANGE
var _life: float = 0.0


func _ready() -> void:
	z_index = 11
	_dir = Vector2(data.get("dir", Vector2.RIGHT))
	if _dir.length() < 0.01:
		_dir = Vector2.RIGHT
	_dir = _dir.normalized()
	_speed = float(data.get("speed", MathScript.ACID_SPEED))
	_range_left = float(data.get("range", MathScript.ACID_RANGE))
	if damage <= 0.0:
		damage = float(data.get("damage", MathScript.ACID_DAMAGE))
	rotation = _dir.angle()
	var anim := AnimatedSprite2D.new()
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim.scale = Vector2.ONE * TEXEL
	anim.sprite_frames = _sprite_frames()
	add_child(anim)
	anim.play(&"fly")


func _physics_process(delta: float) -> void:
	_life += delta
	var step: float = _speed * delta
	global_position += _dir * step
	_range_left -= step
	if _range_left <= 0.0:
		_splash()
		return
	if _life >= WALL_IGNORE_TIME and GameManager.is_position_blocked_by_forest(global_position):
		_splash()
		return
	if GameManager.merchant_zone_active and global_position.distance_to(GameManager.merchant_zone_pos) <= GameManager.MERCHANT_ZONE_RADIUS:
		_splash()
		return
	for p in AbilitiesScript.damageable_players(get_tree()):
		var pn := p as Node2D
		if "paladin_zone_active" in pn and pn.get("paladin_zone_active") == true \
				and global_position.distance_to(pn.global_position) <= float(pn.get("paladin_zone_radius")):
			_splash()
			return
		if pn.has_method("get_talon_ward_radius"):
			var ward_r: float = float(pn.call("get_talon_ward_radius"))
			if ward_r > 0.0 and global_position.distance_to(pn.global_position) <= ward_r:
				_splash()
				return
		if pn.get("is_indoors") == true or pn.get("is_downed") == true:
			continue
		if global_position.distance_to(pn.global_position) <= MathScript.ACID_HIT_RADIUS + AbilitiesScript.TARGET_BODY_RADIUS:
			if authoritative:
				AbilitiesScript.deal_special_damage(p, damage, source, "worm_acid")
			_splash()
			return


## Sıçrama: ending animasyonu tek seferlik (sahne köküne, damla silinse de oynasın).
func _splash() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.current_scene != null and DisplayServer.get_name() != "headless":
		var fx := AnimatedSprite2D.new()
		fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fx.scale = Vector2.ONE * TEXEL
		fx.sprite_frames = _sprite_frames()
		fx.rotation = rotation
		fx.z_index = 11
		fx.position = global_position
		tree.current_scene.add_child(fx)
		fx.play(&"end")
		fx.animation_finished.connect(fx.queue_free)
	queue_free()


## "fly" (3 kare döngü) + "end" (3 kare tek sefer) - iki 60x21 şeritten AtlasTexture dilimleriyle bir kez kurulur.
static func _sprite_frames() -> SpriteFrames:
	if _frames != null:
		return _frames
	var f := SpriteFrames.new()
	f.remove_animation(&"default")
	for pair: Array in [[&"fly", LOOP_TEX, true], [&"end", END_TEX, false]]:
		var name: StringName = pair[0]
		var tex: Texture2D = pair[1]
		f.add_animation(name)
		f.set_animation_speed(name, FPS)
		f.set_animation_loop(name, bool(pair[2]))
		for i in range(int(tex.get_width() / FRAME_W)):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * FRAME_W, 0, FRAME_W, FRAME_H)
			f.add_frame(name, at)
	_frames = f
	return f
