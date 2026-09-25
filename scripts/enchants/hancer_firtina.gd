extends "res://scripts/enchant_behavior.gd"

## Fırtına Bıçakları (EnchantDefs "hancer_firtina"): darbe sayısı / saldırı hızı / aynı hedef rampası / menzil temel
## sınıfta. Final (Eldiven): Eldiven'in isabet başına düz hasarı (item_flat_hit_damage) her darbeye ayrı eklenir -
## weapon.gd onu bir kez ekleyip parçalara böldüğü için burada (darbe - 1) kez daha eklenir.


func damage_extra(dmg: float, _t: Node2D) -> float:
	if not flag("flat_per_segment"):
		return dmg
	var p: Node = owner_player()
	var flat: float = float(p.get("item_flat_hit_damage")) if p and "item_flat_hit_damage" in p else 0.0
	return dmg + flat * float(maxi(0, n("segments", 3) - 1))
