extends Node2D

## İblis ateş topu (bkz. enemy_abilities.gd _process_fireball): düz bir çizgide uçan alev topu; ilk değdiği oyuncuya
## iblisin normal hasarını verir ve onu 3 saniye yakar (yanma player.gd take_special_damage("fireball") ->
## apply_enemy_burn - kurbanın KENDİ makinesinde işlenir). Orman duvarına, Şovalye kalkanına ve satıcı bölgesine
## çarpınca söner. Yetkili (host/tek oyunculu) örnek hasar verir, istemcilerdeki görsel kopya sadece uçar ve isabet
## anında patlama efekti oynatır (enemy_projectile.gd "network_spawned" deseniyle aynı).
## Görseller tools/gen_enemy_ability_fx.py spritesheet'leri (tek AnimatedSprite2D, uçuş yönüne döndürülür).

const TEXEL := 1.212
const FLY_FRAMES := preload("res://assets/fx/enemy_abilities/fireball_frames.tres")
const IMPACT_FRAMES := preload("res://assets/fx/enemy_abilities/fire_impact_frames.tres")
const FxScript := preload("res://scripts/fx_enemy_ability.gd")
const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const LIFETIME := 2.2
const HIT_RADIUS := 9.0
const WALL_IGNORE_TIME := 0.08
## fireball_sheet karesinde (30x20) topun merkezi x=21 - sprite'ı top merkezi node'un konumuna gelecek şekilde kaydır.
const BALL_OFFSET := Vector2(-(21.0 - 15.0), 0.0)

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _dir: Vector2 = Vector2.RIGHT
var _speed: float = 230.0
var _life: float = 0.0


func _ready() -> void:
	z_index = 11
	_dir = Vector2(data.get("dir", Vector2.RIGHT))
	if _dir.length() < 0.01:
		_dir = Vector2.RIGHT
	_dir = _dir.normalized()
	_speed = float(data.get("speed", 230.0))
	rotation = _dir.angle()
	var anim := AnimatedSprite2D.new()
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim.scale = Vector2.ONE * TEXEL
	anim.sprite_frames = FLY_FRAMES
	anim.offset = BALL_OFFSET
	add_child(anim)
	anim.play(&"fly")


func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= LIFETIME:
		queue_free()
		return
	global_position += _dir * _speed * delta
	if _life >= WALL_IGNORE_TIME and GameManager.is_position_blocked_by_forest(global_position):
		_explode()
		return
	if GameManager.merchant_zone_active and global_position.distance_to(GameManager.merchant_zone_pos) <= GameManager.MERCHANT_ZONE_RADIUS:
		_explode()
		return
	for p in AbilitiesScript.damageable_players(get_tree()):
		var pn := p as Node2D
		if "paladin_zone_active" in pn and pn.get("paladin_zone_active") == true \
				and global_position.distance_to(pn.global_position) <= float(pn.get("paladin_zone_radius")):
			_explode()
			return
		if global_position.distance_to(pn.global_position) <= HIT_RADIUS + AbilitiesScript.TARGET_BODY_RADIUS:
			if authoritative:
				AbilitiesScript.deal_special_damage(p, damage, source, "fireball")
			_explode()
			return


func _explode() -> void:
	FxScript.spawn(get_tree().current_scene, global_position, IMPACT_FRAMES, &"play", 12)
	queue_free()
