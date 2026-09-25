extends "res://scripts/enchant_behavior.gd"

## Deprem (EnchantDefs "topuz_deprem"): sersemletme / alan temel sınıfta. II: her N. vuruş yere şok dalgası; IV: dalga
## yavaşlatır. Final (Steroid): her 6. vuruşta 250 px Tektonik Darbe (saldırı gücü + maks can'ın %3'ü, 1,5 sn sersem).

const SLAM_RADIUS := 250.0

var _last_pos: Vector2 = Vector2.ZERO


func fire_start(target: Node2D, _is_extra: bool) -> void:
	if is_instance_valid(target):
		_last_pos = target.global_position


func fire_extra(_target: Node2D, is_extra: bool) -> void:
	if is_extra:
		return
	if n("wave_every") > 0 and every(n("wave_every")):
		var r: float = f("wave_radius", 150.0)
		for e in blast(_last_pos, r, float(weapon.get("damage")) * f("wave_ratio", 0.6) * power, Color(0.88, 0.78, 0.56), "wave"):
			if f("wave_slow") > 0.0:
				e.apply_element("slow", {"pct": f("wave_slow"), "dur": 2.0})
	if n("slam_every") > 0 and every(n("slam_every")):
		for e in blast(_last_pos, SLAM_RADIUS, (ap() * 2.5 + max_hp() * 0.03) * power, Color(0.92, 0.82, 0.6), "slam"):
			e.apply_element("stun", {"dur": 1.5})
		fx("burst", _last_pos, {"palette": "dust", "count": 30, "speed": 220.0, "life": 0.6})
