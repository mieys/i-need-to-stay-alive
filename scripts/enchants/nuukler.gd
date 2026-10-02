extends "res://scripts/enchant_behavior.gd"

## Nuukler (Fişek) - bkz. EnchantDefs "nuukler". Fişek patladığı yerde radyasyon alanı (enchant_area "field" + radiation
## sayfası): 0,5 sn'de bir hasar, (Doku Çürümesi) yavaşlatma + "tüm hasardan fazla al". Final: çarpma anında mantar bulutu
## (mushroom sayfası, 100 birim %200) ve radyasyon kalkanı tamamen yok sayar ("pen" 1.0).

const MUSHROOM_RADIUS := 100.0


func on_explode(_proj: Node2D, pos: Vector2) -> void:
	if not can_act():
		return
	var r: float = f("rad_radius", 60.0)
	area("field", pos, {"radius": r, "duration": f("rad_dur", 3.0), "tick": 0.5, "damage": ap() * f("rad_dps") * 0.5,
		"slow": f("rad_slow"), "vuln": f("rad_vuln"), "pen": f("rad_pen"), "color": Color(0.7, 1.0, 0.35),
		"sheet": "radiation", "sheet_scale": r / (49.0 * 1.212)})
	if f("mushroom") > 0.0:
		sprite("mushroom", pos, {"offset": Vector2(0.0, -76.0), "z": 9})
		for e in enemies_near(pos, MUSHROOM_RADIUS):
			hit(e, ap() * f("mushroom"))
