extends "res://scripts/enchant_behavior.gd"

## Kan Emici (EnchantDefs "pence_kan"): can çalma / düşük canda iki kat temel sınıfta (lifesteal - efsun gücü çarpar).
## Öldürme başına can (player -> "kill" olayı), can doluyken kazanılan kalkana döner; final (Vitamin) Kan Lordu -
## can doluyken kazanılan fazlanın %10'u kalıcı maksimum cana (kesirler silah meta'sında birikir).


func on_event(event: String, _data: Dictionary) -> void:
	if event == "kill" and f("kill_heal") > 0.0:
		_lifesteal(f("kill_heal") * pw("heal"))


func _lifesteal(amount: float) -> void:
	var p: Node = owner_player()
	if p == null or amount <= 0.0:
		return
	var missing: float = maxf(0.0, float(p.get("max_health")) - float(p.get("health")))
	var overflow: float = maxf(0.0, amount - missing)
	if missing > 0.0:
		heal_owner(minf(amount, missing))
	if overflow <= 0.0:
		return
	if flag("overheal_shield") and p.has_method("heal_shield"):
		p.heal_shield(overflow)
	if flag("blood_lord") and p.has_method("enchant_add_max_health"):
		var acc: float = float(keep_get("blood_lord", 0.0)) + overflow * 0.10
		if acc >= 1.0:
			p.enchant_add_max_health(floorf(acc))
			acc -= floorf(acc)
		keep_set("blood_lord", acc)
