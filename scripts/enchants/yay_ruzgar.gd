extends "res://scripts/enchant_behavior.gd"

## Rüzgâr Oku (EnchantDefs "yay_ruzgar"): delme / hız / menzil / delme rampası temel sınıfta. V: isabet hareket hızı
## verir. Final (Deri Çizme): her 6. ok isabet noktasından okun yönünde ilerleyip düşmanları sürükleyen bir kasırga
## doğurur (enchant_area.gd "tornado").

var _tornado_shot: bool = false


func fire_start(_target: Node2D, is_extra: bool) -> void:
	_tornado_shot = not is_extra and n("tornado_every") > 0 and every(n("tornado_every"))


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	if _tornado_shot:
		proj.set_meta("enchant_tornado", true)


func look_extra(proj: Node2D, d: Dictionary) -> Dictionary:
	d["tint"] = Color(0.75, 1.0, 0.92) if proj.has_meta("enchant_tornado") else Color(0.9, 1.0, 0.97)
	if proj.has_meta("enchant_tornado"):
		d["scale"] = 1.3
	return d


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if is_primary and f("hit_speed_buff") > 0.0:
		var p: Node = owner_player()
		if p and p.has_method("enchant_speed_buff"):
			p.enchant_speed_buff(f("hit_speed_buff"), 2.0)
	if is_primary and proj != null and proj.has_meta("enchant_tornado") and is_enemy(t):
		proj.remove_meta("enchant_tornado")
		area("tornado", t.global_position, {"duration": 2.5, "speed": 150.0, "radius": 70.0,
			"damage": ap() * 0.5 * power, "dir": Vector2(proj.get("direction"))})
