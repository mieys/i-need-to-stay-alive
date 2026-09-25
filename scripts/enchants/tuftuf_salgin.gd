extends "res://scripts/enchant_behavior.gd"

## Salgın (EnchantDefs "tuftuf_salgin"): zehir + ölümde bulaşma. Bulaşma/öksürük host'taki düşmanda çözülür (enemy.gd
## _plague, _on_death_elements) - buradan her zehir uygulamasına "plague" parametresi eklenir. Final (Hasat Çantası)
## olayı "plague_death" host'tan bu oyuncuya gelir (enemy.gd _notify_enchant_owner -> player.on_enchant_event).

const WAVE_EVERY := 20
const WAVE_RADIUS := 900.0

var _plague_deaths: int = 0


func poison_extra() -> Dictionary:
	return {"plague": {"radius": f("plague_radius", 80.0), "ratio": f("plague_ratio", 0.5),
		"refresh": flag("plague_refresh"), "cough": flag("plague_cough"), "final": flag("plague_final")}}


func on_event(event: String, _data: Dictionary) -> void:
	if event != "plague_death" or not flag("plague_final"):
		return
	var p: Node = owner_player()
	if p == null:
		return
	if p.has_method("enchant_speed_buff"):
		p.enchant_speed_buff(0.10, 3.0)
	_plague_deaths += 1
	if _plague_deaths % WAVE_EVERY != 0:
		return
	for e in enemies_near(p.global_position, WAVE_RADIUS):
		if status(e, "poisoned"):
			apply_poison_to(e, {"stacks": 5})
	fx("ring", p.global_position, {"radius": 260.0, "color": Color(0.55, 0.9, 0.35), "duration": 0.7})
	fx("text", p.global_position, {"text": "Veba Dalgası", "color": Color(0.6, 0.95, 0.4)})
