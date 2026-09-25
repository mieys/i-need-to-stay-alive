extends "res://scripts/enchant_behavior.gd"

## Şok Cıvatası (EnchantDefs "crossbow_sok"): şok / şokluya kritik / ölüm yıldırımı temel sınıfta. III: kritik isabet şoku
## yakındaki 2 düşmana yayar; final (Yetenek Kitabı) Tesla Cıvatası - isabet yerine 4 sn'lik tesla kulesi (en fazla 3).

const MAX_TURRETS := 3


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or not is_enemy(t):
		return
	if flag("crit_spread") and proj != null and bool(proj.get("is_crit")):
		for e in random_enemies(t.global_position, 130.0, 2, t):
			apply_shock_to(e)
			fx("chain", t.global_position, {"to": e.global_position})
	if flag("tesla_turret") and own_count("tesla") < MAX_TURRETS:
		tagged_area("tesla", "turret", t.global_position + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0)),
			{"duration": 4.0, "interval": 1.0, "range": 200.0, "damage": ap() * 0.4 * pw("shock"), "element": "shock",
			"ap": ap(), "color": Color(1.0, 0.95, 0.5)})
