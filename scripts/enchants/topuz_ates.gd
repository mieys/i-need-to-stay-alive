extends "res://scripts/enchant_behavior.gd"

## Ateş Topuzu (EnchantDefs "topuz_ates"): yakma / yanan bonusu temel sınıfta. II: vuruş yerinde lav (enchant_area.gd
## "lava"). Final (Sigara): her 5. vuruşta çevresine lav topu fırlatan küçük bir volkan (enchant_area.gd "volcano").

var _last_pos: Vector2 = Vector2.ZERO


func fire_start(target: Node2D, _is_extra: bool) -> void:
	if is_instance_valid(target):
		_last_pos = target.global_position


func fire_extra(_target: Node2D, is_extra: bool) -> void:
	if is_extra:
		return
	var bp: Dictionary = burn_area_params()
	if f("lava_dur") > 0.0:
		var lp: Dictionary = bp.duplicate()
		lp["radius"] = f("lava_radius", 60.0)
		lp["duration"] = f("lava_dur")
		area("lava", _last_pos, lp)
	if n("volcano_every") > 0 and every(n("volcano_every")):
		area("volcano", _last_pos, {"duration": 5.0, "radius": 160.0, "damage": ap() * 0.6 * power,
			"burn_tick": float(bp["burn_tick"]), "ap": ap()})
