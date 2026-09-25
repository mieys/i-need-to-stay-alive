extends "res://scripts/enchant_behavior.gd"

## Dörtlü Pençe (EnchantDefs "pence_dortlu"): darbe sayısı / çevre hasarı / alan / saldırı hızı temel sınıfta. Final
## (Eldiven) Pençe Fırtınası: her 5. saldırıda sahibinin çevresinde 140 px'lik 360° pençe dönüşü.

const STORM_RADIUS := 140.0
const CLAW := Color(0.95, 0.85, 0.7)


func fire_extra(_target: Node2D, is_extra: bool) -> void:
	if is_extra or n("claw_storm_every") <= 0 or not every(n("claw_storm_every")):
		return
	var p: Node = owner_player()
	blast(p.global_position, STORM_RADIUS, ap() * 1.2 * pw("hit"), CLAW, "slam")
	fx("burst", p.global_position, {"palette": "dust", "count": 20, "speed": 200.0, "life": 0.4})
