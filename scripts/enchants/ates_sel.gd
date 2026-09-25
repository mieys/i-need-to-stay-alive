extends "res://scripts/enchant_behavior.gd"

## Alev Seli (EnchantDefs "ates_sel"): çoklu ateş topu / delme (her delişte patlama - projectile.gd splash her isabette) /
## alan / hız temel sınıfta. Final (Steroid): Ejder Nefesi - her 6 sn'de önüne 1,5 sn'lik alev konisi
## (enchant_area.gd "flame_cone", sahibini izler).

const DRAGON_COOLDOWN := 6.0

var _dragon_timer: float = DRAGON_COOLDOWN


func process_extra(delta: float) -> void:
	if not flag("dragon"):
		return
	_dragon_timer -= delta
	if _dragon_timer > 0.0:
		return
	var p: Node = owner_player()
	var e: Node = nearest_enemy(p.global_position, 260.0) if can_act() else null
	if e == null:
		_dragon_timer = 0.5
		return
	_dragon_timer = DRAGON_COOLDOWN
	area("flame_cone", p.global_position, {"follow": true, "duration": 1.5, "radius": 170.0, "half_angle": 28.0,
		"dir": dir_to(p.global_position, e), "damage": (ap() * 0.4 + max_hp() * 0.02) * pw("hit"),
		"burn_tick": ap() * 0.10, "ap": ap()})
