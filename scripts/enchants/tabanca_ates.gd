extends "res://scripts/enchant_behavior.gd"

## Ateşli Mermi (EnchantDefs "tabanca_ates"): yakma / yanana kritik hasarı temel sınıfta. II: yanan düşmana isabet küçük
## patlama; final (Sigara) Barut Fıçısı - her 10. mermi 150 px dev patlama (yakar, geri iter).

const FIRE := Color(1.0, 0.55, 0.2)
const KEG_RADIUS := 150.0

var _keg_shot: bool = false


func fire_start(_target: Node2D, is_extra: bool) -> void:
	_keg_shot = not is_extra and n("keg_every") > 0 and every(n("keg_every"))


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	if _keg_shot:
		proj.set_meta("enchant_keg", true)


func look_extra(proj: Node2D, d: Dictionary) -> Dictionary:
	if proj.has_meta("enchant_keg"):
		d["scale"] = 1.6
		d["trail"] = "fire"
	return d


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or not is_enemy(t):
		return
	var pos: Vector2 = t.global_position
	if proj != null and proj.has_meta("enchant_keg"):
		proj.remove_meta("enchant_keg")
		for e in blast(pos, KEG_RADIUS, ap() * 2.5 * pw("burn"), FIRE):
			apply_burn_to(e)
			var away: Vector2 = e.global_position - pos
			if e.get("is_boss") != true and away.length() > 1.0:
				e.apply_element("knock", {"dir": away.normalized(), "dist": 70.0, "quiet": true})
		fx("burst", pos, {"palette": "fire", "count": 30, "speed": 240.0, "life": 0.6})
		return
	if f("burn_pop") > 0.0 and status(t, "burning"):
		blast(pos, f("burn_pop"), ap() * 0.3 * pw("burn"), FIRE)
