extends "res://scripts/enchant_behavior.gd"

## Matryoshka Fireworks (Fişek) - bkz. EnchantDefs "matryoshka". Fişek patlayınca etrafa küçük fişekler (enchant_area
## "mini_fw": yay çizerek uçar, patlar - mini_fw / mini_pop sayfaları); hasarları fişeğin isabet hasarının oranı. Final:
## her küçük fişek bir kez daha 2 mikro fişeğe bölünür (alan kendisi doğurur ve yayınlar).


func on_explode(proj: Node2D, pos: Vector2) -> void:
	if not can_act():
		return
	var main_dmg: float = float(proj.get("damage")) if is_instance_valid(proj) and "damage" in proj else ap()
	var count: int = maxi(1, n("mini_count", 2))
	var base_ang: float = randf() * TAU
	for i in range(count):
		var ang: float = base_ang + TAU * float(i) / float(count) + randf_range(-0.25, 0.25)
		var to: Vector2 = pos + Vector2(cos(ang), sin(ang) * 0.8) * f("mini_range", 60.0)
		area("mini_fw", pos, {"to": to, "flight": 0.35, "damage": main_dmg * f("mini_ratio", 0.4) * f("mini_dmg_mult", 1.0),
			"radius": f("mini_radius", 35.0), "stun": f("mini_stun"), "range": f("mini_range", 60.0),
			"micro": main_dmg * f("micro"), "sheet": "mini_fw"})
