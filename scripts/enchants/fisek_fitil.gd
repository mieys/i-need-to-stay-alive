extends "res://scripts/enchant_behavior.gd"

## Hızlı Fitil (EnchantDefs "fisek_fitil"): saldırı hızı / uçuş hızı / seri / çift fişek temel sınıfta. Final (Kaos
## Kitabı) Roket Bataryası: her atışta ayrıca 4 mini roket (%40 hasar, küçük) - fişek hedef NOKTAYA indiği için her
## roket yakındaki farklı bir düşmana atılır.

const ROCKETS_RADIUS := 220.0

var _rocket: bool = false


func fire_extra(target: Node2D, is_extra: bool) -> void:
	if is_extra or n("rockets") <= 0 or not is_instance_valid(target):
		return
	var others: Array = random_enemies(target.global_position, ROCKETS_RADIUS, n("rockets"))
	if others.is_empty():
		others = [target]
	_rocket = true
	for k in range(n("rockets")):
		weapon.fire_enchant_shot(others[k % others.size()], 0.0, 0.4, deg_to_rad(randf_range(-25.0, 25.0)))
	_rocket = false


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	if _rocket:
		proj.scale *= 0.6
		if "splash_radius" in proj:
			proj.set("splash_radius", float(proj.get("splash_radius")) * 0.6)
