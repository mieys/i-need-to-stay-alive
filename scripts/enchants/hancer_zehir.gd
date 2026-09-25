extends "res://scripts/enchant_behavior.gd"

## Zehirli Hançer (EnchantDefs "hancer_zehir"): zehir / sadece ana hedef / zehirliye kritik / Engerek finali temel sınıfta.
## V: bu hançerle 20+ yük bıraktığın düşmana vurunca yerinde zehirli duman (enchant_area.gd "poison_cloud"). İstemcide
## düşmanın yük sayısı görünmediği için bu silahın bıraktığı yükler yerel olarak sayılır (track_stacks).

const SMOKE_COOLDOWN_MSEC := 3000

var _smoked: Dictionary = {} ## düşman id -> son duman anı


func hit_extra(t: Node, _dmg: float, is_primary: bool, _proj: Node2D) -> void:
	if not is_enemy(t) or (flag("primary_only") and not is_primary):
		return
	var stacks: int = track_stacks(t, n("poison_stacks", 1), n("poison_cap", 15), f("poison_dur", 10.0))
	if n("smoke_at") <= 0 or stacks < n("smoke_at"):
		return
	var id: int = t.get_instance_id()
	var now: int = Time.get_ticks_msec()
	if now - int(_smoked.get(id, -SMOKE_COOLDOWN_MSEC)) < SMOKE_COOLDOWN_MSEC:
		return
	_smoked[id] = now
	area("poison_cloud", t.global_position, {"radius": 70.0, "duration": 3.0, "dps": ap() * f("poison_dps", 0.02) * pw("poison")})
