extends Node2D

## BOSS BÜYÜ MERMİSİ (2026-10-09, Balkabağı Kafa'nın ateş topları; ileride diğer bosslar da kullanabilir): düz çizgide uçan top. Yetkili (host/tek oyunculu) örnek ilk değdiği oyuncuya
## `damage` verir (take_special_damage kind "bossfire"); istemcideki görsel kopya sadece uçar ve patlama efekti oynatır (enemy_fireball.gd ile aynı sözleşme: data/authoritative/source/damage).
## Orman duvarına, Şovalye kalkanına, Talon kalkan çemberine ve satıcı bölgesine çarpınca söner.
## data: dir (Vector2), speed (px/sn), life (sn), radius (isabet yarıçapı), look ("pumpkin": turuncu büyü).

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const FxUtil := preload("res://scripts/boss_fx_util.gd")
const FLY_PATH := "res://assets/fx/pumpkin/spell_fly.png"
const IMPACT_PATH := "res://assets/fx/pumpkin/spell_impact.png"
const WALL_IGNORE_TIME := 0.08

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _dir: Vector2 = Vector2.RIGHT
var _speed: float = 200.0
var _life: float = 0.0
var _max_life: float = 3.0
var _radius: float = 9.0


func _ready() -> void:
	z_index = 11
	_dir = Vector2(data.get("dir", Vector2.RIGHT))
	if _dir.length() < 0.01:
		_dir = Vector2.RIGHT
	_dir = _dir.normalized()
	_speed = float(data.get("speed", 200.0))
	_max_life = float(data.get("life", 3.0))
	_radius = float(data.get("radius", 9.0))
	## Sayfadaki top SOLA bakar (kuyruk sağda): uçuş yönüne göre döndürülür.
	rotation = _dir.angle() + PI
	var sp := AnimatedSprite2D.new()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.sprite_frames = FxUtil.frames_from_strip(FLY_PATH, 36, 40, &"fly", 14.0, true)
	sp.scale = Vector2.ONE * 0.9
	add_child(sp)
	sp.play(&"fly")


func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= _max_life:
		queue_free()
		return
	global_position += _dir * _speed * delta
	if _life >= WALL_IGNORE_TIME and GameManager.is_position_blocked_by_forest(global_position):
		_burst()
		return
	if GameManager.merchant_zone_active and global_position.distance_to(GameManager.merchant_zone_pos) <= GameManager.MERCHANT_ZONE_RADIUS:
		_burst()
		return
	for p in AbilitiesScript.damageable_players(get_tree()):
		var pn := p as Node2D
		if "paladin_zone_active" in pn and pn.get("paladin_zone_active") == true \
				and global_position.distance_to(pn.global_position) <= float(pn.get("paladin_zone_radius")):
			_burst()
			return
		if pn.has_method("get_talon_ward_radius"):
			var ward_r: float = float(pn.call("get_talon_ward_radius"))
			if ward_r > 0.0 and global_position.distance_to(pn.global_position) <= ward_r:
				_burst()
				return
		if global_position.distance_to(pn.global_position) <= _radius + AbilitiesScript.TARGET_BODY_RADIUS:
			if authoritative:
				AbilitiesScript.deal_special_damage(p, damage, source, "bossfire")
			_burst()
			return


func _burst() -> void:
	FxUtil.play_once(get_tree().current_scene, global_position, FxUtil.frames_from_strip(IMPACT_PATH, 36, 40, &"burst", 14.0, false), &"burst", 1.0)
	queue_free()
