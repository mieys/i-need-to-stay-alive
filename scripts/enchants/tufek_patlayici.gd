extends "res://scripts/enchant_behavior.gd"

## Patlayıcı Mermi (EnchantDefs "tufek_patlayici"): mermi ilk vurduğu düşmanda patlar ve patlamadakileri yakar; II: deldiği
## her düşmanda küçük patlama; V: patlama yerinde lav; final (Sigara) Napalm - merminin geçtiği yol 4 sn yanar
## (enchant_area.gd "line" mode fire).

const FIRE := Color(1.0, 0.55, 0.2)

var _origin: Vector2 = Vector2.ZERO


func fire_start(_target: Node2D, _is_extra: bool) -> void:
	_origin = weapon.global_position


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	proj.set_meta("enchant_origin", _origin)


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_enemy(t) or proj == null:
		return
	if not is_primary and not flag("blast_each"):
		return
	var pos: Vector2 = t.global_position
	var r: float = f("blast_radius", 70.0) * (1.0 if is_primary else 0.6)
	var burn_extra: Dictionary = {"tick": ap() * f("blast_burn", 0.10) * pw("area")}
	for e in blast(pos, r, ap() * f("blast_pct", 0.6) * pw("area") * (1.0 if is_primary else 0.5), FIRE):
		apply_burn_to(e, burn_extra)
	if is_primary and flag("blast_lava"):
		var lp: Dictionary = burn_area_params()
		lp["burn_tick"] = ap() * f("blast_burn", 0.10) * pw("area")
		lp["radius"] = r * 0.7
		lp["duration"] = 3.0
		area("lava", pos, lp)
	if is_primary and flag("napalm"):
		var from: Vector2 = Vector2(proj.get_meta("enchant_origin", weapon.global_position))
		var dir: Vector2 = (pos - from).normalized() if pos.distance_to(from) > 1.0 else Vector2(proj.get("direction"))
		area("line", from, {"to": pos + dir * 220.0, "width": 22.0, "duration": 4.0, "tick": 0.5,
			"damage": ap() * 0.15 * pw("area"), "mode": "fire", "burn_tick": ap() * 0.10 * pw("area"), "ap": ap(), "color": FIRE})
