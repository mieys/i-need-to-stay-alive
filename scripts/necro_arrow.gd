extends Node2D

## Kemik Okçusu oku (2026-11-16). Düz uçar; ormana değince durur (mermi kuralı: is_position_blocked_by_forest, madde 27).
## Kasterde (owner_player dolu) yoluna çıkan ilk düşmana vurur, Hayalet Okçu'da (pierce > 0) delip arkasındakine de vurur.
## Kozmetik kopya (owner null) yalnız uçar - hasar kasterin istemcisinden gelir (bkz. necro_fx.gd).

const NecroFx := preload("res://scripts/necro_fx.gd")
const NecroUnits := preload("res://scripts/necro_units.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const BalanceLogScript: GDScript = preload("res://scripts/balance_log.gd")

const SPEED := 520.0
const HIT_RADIUS := 16.0

var _dir: Vector2 = Vector2.RIGHT
var _travelled: float = 0.0
var _max_dist: float = 360.0
var _owner: Node = null
var _damage: float = 0.0
var _pierce_left: int = 0
var _hit: Dictionary = {}
var _start: Vector2 = Vector2.ZERO
var _ghost: bool = false


func setup(from: Vector2, to: Vector2, ghost: bool, owner_player: Node, damage: float, pierce: int, max_dist: float) -> void:
	_start = from
	var d: Vector2 = to - from
	_dir = d.normalized() if d.length() > 0.01 else Vector2.RIGHT
	_ghost = ghost
	_owner = owner_player
	_damage = damage
	_pierce_left = pierce
	_max_dist = max_dist


func _ready() -> void:
	global_position = _start
	rotation = _dir.angle()
	var s := Sprite2D.new()
	s.texture = NecroFx.arrow_texture(_ghost)
	s.scale = Vector2.ONE * NecroUnits.WORLD_SCALE
	add_child(s)
	z_as_relative = false
	z_index = 2


func _physics_process(delta: float) -> void:
	var step: float = SPEED * delta
	global_position += _dir * step
	_travelled += step
	if _travelled >= _max_dist or GameManager.is_position_blocked_by_forest(global_position):
		queue_free()
		return
	if _owner == null or not is_instance_valid(_owner):
		return
	for e in EnemyQueryScript.candidates(get_tree(), global_position, HIT_RADIUS + 20.0):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var id: int = e.get_instance_id()
		if _hit.has(id):
			continue
		if global_position.distance_to(e.global_position) > HIT_RADIUS + float(e.get("_body_radius") if e.get("_body_radius") != null else 12.0) * 0.5:
			continue
		_hit[id] = true
		if e.has_method("take_damage"):
			var crit: bool = false
			var dmg: float = _damage
			if _owner.has_method("_roll_ability_crit"):
				crit = _owner._roll_ability_crit()
				dmg = _owner._apply_ability_crit(dmg, crit)
			BalanceLogScript.tag(&"s:necro_okcu")
			e.take_damage(dmg, crit)
		_pierce_left -= 1
		if _pierce_left < 0:
			queue_free()
			return
