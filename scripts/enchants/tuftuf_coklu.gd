extends "res://scripts/enchant_behavior.gd"

## Çoklu Üfleme (EnchantDefs "tuftuf_coklu"): yelpaze dartlar / hız / sekme / saldırı hızı temel sınıfta. Final (Kaos
## Kitabı): her 3. saldırıda 8 dartlık halka. Kaos Kitabı'nın çift ateşi _fire_at'i yeniden çağırdığı için yelpaze/halka
## da kendiliğinden ikiye katlanır.


func fire_extra(target: Node2D, is_extra: bool) -> void:
	if is_extra or n("ring_every") <= 0 or not every(n("ring_every")):
		return
	var rc: int = n("ring_count", 8)
	for j in range(rc):
		weapon.fire_enchant_shot(target, 0.06, 1.0, TAU * float(j) / float(rc))
