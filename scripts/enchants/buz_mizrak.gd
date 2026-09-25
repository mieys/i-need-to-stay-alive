extends "res://scripts/enchant_behavior.gd"

## Buz Mızrağı (EnchantDefs "buz_mizrak"): delme (deldikleri de donar - mermi chill'i her isabette) / boyut / donmuşa
## bonus temel sınıfta. V: son deldiği düşmanda buz patlaması (80 px, dondurur); final (Kitelama Seti) her 3. atış 5
## mızraklık yelpaze, mızraklar geri iter.

const ICE := Color(0.75, 0.9, 1.0)

var _spear_volley: bool = false


func fire_start(_target: Node2D, is_extra: bool) -> void:
	if not is_extra:
		_spear_volley = n("spear_every") > 0 and every(n("spear_every"))


## Yelpazedeki tüm mızraklar (ana + 4 ek, ek atışlar fire_extra içinde eşzamanlı) geri iter.
func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	if _spear_volley and "knockback_force" in proj:
		proj.set("knockback_force", float(proj.get("knockback_force")) + 60.0)


func fire_extra(target: Node2D, is_extra: bool) -> void:
	if is_extra or not _spear_volley:
		return
	for k in range(4):
		var side: float = 1.0 if k % 2 == 0 else -1.0
		weapon.fire_enchant_shot(target, 0.0, 1.0, deg_to_rad(12.0) * float(k / 2 + 1) * side)
	_spear_volley = false


func hit_extra(t: Node, _dmg: float, _is_primary: bool, proj: Node2D) -> void:
	if not flag("end_burst") or proj == null or not is_enemy(t):
		return
	var hits: Array = proj.get("_hit_bodies")
	if hits == null or hits.size() <= int(proj.get("pierce_count")) or proj.has_meta("enchant_burst_done"):
		return
	proj.set_meta("enchant_burst_done", true)
	fx("spark_ring", t.global_position, {"radius": 80.0, "color": ICE})
	for e in enemies_near(t.global_position, 80.0):
		freeze(e, 2.0)
