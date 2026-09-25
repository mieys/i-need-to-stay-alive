extends "res://scripts/enchant_behavior.gd"

## Alevli Çark (EnchantDefs "bumerang_alev"): yakma / yanana bonus / yanma yığını / boyut temel sınıfta. Yakalayınca
## gidilen yol (sahip -> uç nokta) yanan bir şerit olur (enchant_area.gd "line" mode fire); V: yakalayınca alev halkası;
## final (Steroid) Güneş Diski - iki kat büyük, alev izli disk.

const FIRE := Color(1.0, 0.55, 0.2)


func on_boomerang_apex(proj: Node2D) -> void:
	proj.set_meta("enchant_apex", proj.global_position)


func look_extra(_proj: Node2D, d: Dictionary) -> Dictionary:
	if flag("sun_disc"):
		d["tint"] = Color(1.0, 0.75, 0.35)
		d["trail"] = "fire"
	return d


func on_boomerang_caught(proj: Node2D) -> void:
	var p: Node = owner_player()
	if p == null:
		return
	var pos: Vector2 = p.global_position
	var bp: Dictionary = burn_area_params()
	if f("fire_trail") > 0.0:
		var apex: Vector2 = Vector2(proj.get_meta("enchant_apex", proj.global_position))
		area("line", pos, {"to": apex, "width": 20.0 * f("trail_width", 1.0), "duration": f("fire_trail"), "tick": 0.5,
			"damage": ap() * 0.05 * pw("burn"), "mode": "fire", "burn_tick": float(bp["burn_tick"]), "ap": ap(), "color": FIRE})
	if flag("catch_ring"):
		for e in blast(pos, 80.0, ap() * 0.5 * pw("burn"), FIRE, "ring"):
			apply_burn_to(e)
