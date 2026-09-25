extends "res://scripts/enchant_behavior.gd"

## Avcı İşareti (EnchantDefs "tabanca_isaret"): işaret yükleri / tavan / süre / yük başına artış / aktarım / Ölüm
## Fermanı temel sınıfta + host'ta (enemy.gd "mark"). III: bu tabancayla 20+ işaret bıraktığın düşmana kesin kritik -
## istemcide yük sayısı görünmediği için bu silahın bıraktıkları yerel sayılır (track_stacks).


func crit_extra(t: Node2D) -> float:
	if n("mark_crit") > 0 and stacks_on(t, f("mark_dur", 20.0)) >= n("mark_crit"):
		return 1.0
	return 0.0


func hit_extra(t: Node, _dmg: float, is_primary: bool, _proj: Node2D) -> void:
	if is_primary and is_enemy(t):
		track_stacks(t, n("mark_stacks", 2), n("mark_cap", 20), f("mark_dur", 20.0))
