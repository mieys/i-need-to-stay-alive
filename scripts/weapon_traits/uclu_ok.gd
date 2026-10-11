extends "res://scripts/enchant_behavior.gd"

## Üçlü Ok (Yay, kalıcı özellik) - bkz. EnchantDefs "uclu_ok". Her fan_every. atışta ana okun yanında fan_extra ok daha yelpaze
## halinde (fan_deg derece aralıkla, iki yana dönüşümlü; yan oklar fan_dmg hasar). Oklar silahın normal atış yolundan geçer
## (weapon.gd fire_enchant_shot) -> ses/efekt/uzak kopya normal atışla aynı. Delici Uçlar = ortak "pierce". Final: yelpaze sonrası
## fan_haste kadar kısa süre saldırı hızı.

const HASTE_TIME := 1.5


func fire_extra(target: Node2D, is_extra: bool) -> void:
	if is_extra or not is_instance_valid(target) or not can_act() or not every(n("fan_every", 3)):
		return
	var deg: float = f("fan_deg", 10.0)
	for k in range(n("fan_extra", 2)):
		var side: float = 1.0 if k % 2 == 0 else -1.0
		var step: float = float(k / 2 + 1)
		weapon.fire_enchant_shot(target, 0.02, f("fan_dmg", 0.8), deg_to_rad(deg * step * side))
	if f("fan_haste") > 0.0:
		haste(f("fan_haste"), HASTE_TIME)
