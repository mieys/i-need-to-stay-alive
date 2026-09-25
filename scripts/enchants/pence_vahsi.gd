extends "res://scripts/enchant_behavior.gd"

## Vahşi Pençe (EnchantDefs "pence_vahsi"): kanama / kanayana bonus / saldırı hızı temel sınıfta. IV: bu pençeyle 10+
## kanama yükü bıraktığın düşmana her vuruş ek parçalama hasarı (yükler yerel sayılır, track_stacks). Final (Vampir Dişi)
## Kurt Kanı: kanayana vurulan hasarın %3'ü can; can %50 altındayken +%40 saldırı hızı.

const BLEED_WINDOW := 4.0


func hit_extra(t: Node, dmg: float, is_primary: bool, _proj: Node2D) -> void:
	if not is_enemy(t):
		return
	var was_bleeding: bool = stacks_on(t, BLEED_WINDOW) > 0
	var stacks: int = track_stacks(t, n("bleed_stacks", 1), n("bleed_cap", 8), BLEED_WINDOW)
	if flag("rend") and is_primary and stacks >= 10:
		hit(t, ap() * 0.6 * pw("bleed"))
		fx("burst", t.global_position, {"palette": "fire", "count": 6, "speed": 70.0, "life": 0.25})
	if flag("wolf_blood") and was_bleeding and dmg > 0.0:
		heal_owner(dmg * 0.03 * (1.0 if is_primary else 0.33))


func attack_speed_extra() -> float:
	if not flag("wolf_blood"):
		return 0.0
	var p: Node = owner_player()
	return 0.4 if p and float(p.get("health")) < float(p.get("max_health")) * 0.5 else 0.0
