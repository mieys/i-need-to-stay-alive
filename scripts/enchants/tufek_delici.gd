extends "res://scripts/enchant_behavior.gd"

## Delici Mermi (EnchantDefs "tufek_delici"): delme / delinene hasar / delme rampası temel sınıfta. Final (Keskin Uçlar)
## Raylı Top: her 5. atışta ayrıca ekranı boydan boya geçen kalın bir ışın (enchant_area.gd "line", anında hasar,
## "pen" = 1 -> kalkanı tamamen deler).

const RAIL_LENGTH := 1400.0

var _rail_shot: bool = false


func fire_start(_target: Node2D, is_extra: bool) -> void:
	_rail_shot = not is_extra and n("rail_every") > 0 and every(n("rail_every"))


func fire_extra(target: Node2D, is_extra: bool) -> void:
	if is_extra or not _rail_shot or not is_instance_valid(target):
		return
	var from: Vector2 = weapon.global_position
	var dir: Vector2 = dir_to(from, target)
	area("line", from, {"to": from + dir * RAIL_LENGTH, "width": 30.0, "duration": 0.45, "instant": ap() * 3.0 * power,
		"pen": 1.0, "color": Color(0.7, 0.95, 1.0)})
	fx("burst", from, {"palette": "spark", "count": 14, "speed": 160.0, "life": 0.3})
