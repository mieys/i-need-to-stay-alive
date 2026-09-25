extends "res://scripts/enchant_behavior.gd"

## Şok Bıçağı (EnchantDefs "hancer_sok"): şok / sıçrama / şoklu bonus / ölüm yıldırımı temel sınıfta (shock_every ile
## her N. isabet). Final (Yetenek Kitabı): Statik Fırtına - yetenek kullanınca ekrandaki tüm şoklu düşmanlara yıldırım.

const STORM_RADIUS := 900.0


func on_skill_used() -> void:
	if not flag("static_storm"):
		return
	var p: Node = owner_player()
	if p == null:
		return
	for e in enemies_near(p.global_position, STORM_RADIUS):
		if status(e, "shocked"):
			fx("bolt", e.global_position, {"warn": 0.02})
			hit(e, ap() * 1.0 * pw("shock"))
