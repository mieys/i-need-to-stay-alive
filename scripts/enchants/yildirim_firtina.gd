extends "res://scripts/enchant_behavior.gd"

## Fırtına Asası (EnchantDefs "yildirim_firtina"): her N sn'de ışının hedefine (ışın yoksa menzildeki en yakın düşmana)
## gökten yıldırım. Şoklama, ikinci yıldırım, alan, elektrik alanı (enchant_area.gd "field" mode shock). Final (Kaos
## Kitabı): saniyede bir; çift atış şansıyla üçlü yıldırım.

const BOLT_RADIUS := 70.0
const SHOCK_COLOR := Color(1.0, 0.92, 0.4)

var _timer: float = 1.0


func process_extra(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	var target: Node2D = weapon.get("_beam_target") as Node2D
	if not is_enemy(target):
		target = nearest_enemy(weapon.global_position, float(weapon.get("attack_range"))) as Node2D
	if target == null or not can_act():
		_timer = 0.3
		return
	_timer = f("storm_cd", 4.0)
	var spots: Array = [target.global_position]
	if n("storm_count", 1) >= 2:
		for e in random_enemies(target.global_position, 250.0, 1, target):
			spots.append(e.global_position)
	if flag("storm_chaos") and randf() < double_fire_chance():
		for e in random_enemies(target.global_position, 300.0, 2, target):
			spots.append(e.global_position)
	for pos in spots:
		_strike(pos)


func _strike(pos: Vector2) -> void:
	var r: float = BOLT_RADIUS * f("storm_radius", 1.0)
	fx("bolt", pos, {"warn": 0.02})
	for e in enemies_near(pos, r):
		hit(e, ap() * 1.2 * pw("area"))
		if flag("storm_shock"):
			apply_shock_to(e)
	if flag("storm_field"):
		area("field", pos, {"radius": r, "duration": 2.0, "tick": 0.5, "damage": ap() * 0.3 * 0.5 * pw("area"),
			"mode": "shock", "ap": ap(), "color": SHOCK_COLOR})
