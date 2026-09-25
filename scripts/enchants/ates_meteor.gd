extends "res://scripts/enchant_behavior.gd"

## Meteor Asası (EnchantDefs "ates_meteor"): her N. atışta hedefe 1 sn uyarılı meteor (enchant_area.gd "meteor" - lav ve
## sersemletme parametreleri orada). Final (Kaos Kitabı): her 10 sn'de menzildeki düşmanlara 6 meteor; Kaos Kitabı'nın
## çift atış şansıyla yağmur ikiye katlanır.

const METEOR_RADIUS := 110.0
const RAIN_COOLDOWN := 10.0
const RAIN_COUNT := 6

var _rain_timer: float = RAIN_COOLDOWN


func fire_extra(target: Node2D, is_extra: bool) -> void:
	if is_extra or n("meteor_every") <= 0 or not every(n("meteor_every")) or not is_instance_valid(target):
		return
	_meteor(target.global_position)
	if n("meteor_count", 1) >= 2:
		var others: Array = random_enemies(target.global_position, 260.0, 1, target)
		if not others.is_empty():
			_meteor(others[0].global_position)


func _meteor(pos: Vector2, delay: float = 1.0) -> void:
	area("meteor", pos, {"delay": delay, "radius": METEOR_RADIUS * f("meteor_radius", 1.0), "damage": ap() * 2.0 * pw("area"),
		"lava": flag("meteor_lava"), "burn_tick": ap() * 0.10, "ap": ap(), "stun": f("meteor_stun")})


func process_extra(delta: float) -> void:
	if not flag("meteor_rain"):
		return
	_rain_timer -= delta
	if _rain_timer > 0.0:
		return
	var p: Node = owner_player()
	var rng: float = float(weapon.get("attack_range"))
	var targets: Array = random_enemies(p.global_position, rng, RAIN_COUNT) if can_act() else []
	if targets.is_empty():
		_rain_timer = 1.0
		return
	_rain_timer = RAIN_COOLDOWN
	var waves: int = 2 if randf() < double_fire_chance() else 1
	for w in range(waves):
		for i in range(targets.size()):
			if is_instance_valid(targets[i]):
				_meteor(targets[i].global_position + Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0)), 1.0 + 0.15 * float(i) + 0.6 * float(w))
