extends "res://scripts/enchant_behavior.gd"

## Tekrarlı Arbalet (EnchantDefs "crossbow_tekrarli"): saldırı hızı / çift cıvata / hız temel sınıfta. Final (Eldiven)
## Makineli Arbalet: her 12 sn'de 3 sn boyunca saldırı hızı üç katı (+%200).

const FRENZY_DUR := 3.0

var _frenzy_timer: float = 3.0


func process_extra(delta: float) -> void:
	if f("frenzy_cd") <= 0.0:
		return
	_frenzy_timer -= delta
	if _frenzy_timer > 0.0:
		return
	var p: Node = owner_player()
	if not can_act() or nearest_enemy(p.global_position, float(weapon.get("attack_range"))) == null:
		_frenzy_timer = 0.5
		return
	_frenzy_timer = f("frenzy_cd")
	haste(2.0, FRENZY_DUR)
	fx("text", p.global_position, {"text": "Makineli!", "color": Color(1.0, 0.85, 0.4)})
