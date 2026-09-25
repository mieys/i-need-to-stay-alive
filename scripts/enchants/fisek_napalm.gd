extends "res://scripts/enchant_behavior.gd"

## Napalm Fişeği (EnchantDefs "fisek_napalm"): patlamanın vurdukları yanar (temel sınıf burn_*), patlama yeri süreli
## yanan zemine döner (enchant_area.gd "lava"; V: üstünde duran sahibine saldırı hızı "owner_haste"). Final (Sigara)
## Cehennem Ateşi: patlama alanı x2 (aoe_mult, temel sınıf), zemin 8 sn.


func on_explode(proj: Node2D, pos: Vector2) -> void:
	if f("lava_dur") <= 0.0:
		return
	var lp: Dictionary = burn_area_params()
	lp["radius"] = float(proj.get("splash_radius")) * f("lava_scale", 1.0) if "splash_radius" in proj else 66.0
	lp["duration"] = f("lava_dur")
	lp["owner_haste"] = f("lava_haste")
	area("lava", pos, lp)
