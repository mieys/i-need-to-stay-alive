extends "res://scripts/enchant_behavior.gd"

## Uyku Okları (EnchantDefs "tuftuf_uyku"): her N. dart hedefi uyutur (enemy.gd _apply_sleep_host - sersemletme üstüne
## kurulu, boss hariç). Uyku bonusu/savunmasızlığı/uyanınca yavaşlama host'ta çözülür.

var _sleep_shot: bool = false


func fire_start(_target: Node2D, is_extra: bool) -> void:
	_sleep_shot = not is_extra and every(n("sleep_every", 4))


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	if _sleep_shot:
		proj.set_meta("enchant_sleep", true)


func look_extra(proj: Node2D, d: Dictionary) -> Dictionary:
	if proj.has_meta("enchant_sleep"):
		d["tint"] = Color(0.82, 0.72, 1.0)
		d["scale"] = 1.15
	return d


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or proj == null or not proj.has_meta("enchant_sleep") or not is_enemy(t):
		return
	var p: Dictionary = elem({"dur": f("sleep_dur", 1.5), "break": flag("sleep_break"), "bonus": f("sleep_bonus") * power,
		"vuln": f("sleep_vuln"), "wake_slow": f("sleep_wake_slow")})
	var victims: Array = [t]
	if f("sleep_radius") > 0.0:
		victims = enemies_near(t.global_position, f("sleep_radius"))
		if not victims.has(t):
			victims.append(t)
	for v in victims:
		if is_enemy(v) and v.get("is_boss") != true:
			v.apply_element("sleep", p)
	fx("text", t.global_position, {"text": "Zzz", "color": Color(0.82, 0.72, 1.0)})
