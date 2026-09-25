extends "res://scripts/enchant_behavior.gd"

## Zehirli Tüftüf (EnchantDefs "tuftuf_zehir"): zehir yükleri temel sınıfta (poison_*); V'te zehir öncelikli hedefleme
## geri gelir (tuftuf_targeting.gd); final (Vitamin): tavan kalkar + yakındaki zehirli düşman başına can yenilenmesi.

const REGEN_RADIUS := 800.0
const REGEN_MAX_PER_SEC := 5.0

var _regen_timer: float = 1.0


func _on_setup() -> void:
	if flag("poison_priority"):
		weapon.set_enchant_prop("target_highest_health", true)


func process_extra(delta: float) -> void:
	if f("poison_regen") <= 0.0:
		return
	_regen_timer -= delta
	if _regen_timer > 0.0:
		return
	_regen_timer = 1.0
	var p: Node = owner_player()
	if p == null or not can_act():
		return
	var count: int = 0
	for e in enemies_near(p.global_position, REGEN_RADIUS):
		if status(e, "poisoned"):
			count += 1
	if count > 0:
		heal_owner(minf(REGEN_MAX_PER_SEC, f("poison_regen") * float(count) * power))
