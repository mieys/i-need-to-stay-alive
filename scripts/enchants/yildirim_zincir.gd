extends "res://scripts/enchant_behavior.gd"

## Zincir Yıldırım (EnchantDefs "yildirim_zincir"): ek sıçrama / sıçrama hasarı / menzil temel sınıfta (chain_*, weapon.gd
## _apply_chain_jumps). Burada: sıçranan düşmanları şoklama, %10 ana hedefe geri dönüş, final (Yetenek Kitabı) zincirin
## son halkasına saniyede bir dev yıldırım.

const BOLT_RADIUS := 60.0
const BOLT_INTERVAL_MSEC := 1000

var _last_bolt_msec: int = 0


func on_chain(primary: Node, targets: Array, dmg: float) -> void:
	if targets.is_empty():
		return
	if flag("chain_shock"):
		for t in targets:
			apply_shock_to(t)
	if f("chain_return") > 0.0 and is_enemy(primary):
		for _t in targets:
			if randf() < f("chain_return"):
				hit(primary, dmg)
				fx("chain", (targets[-1] as Node2D).global_position, {"to": (primary as Node2D).global_position})
				break
	if flag("chain_bolt"):
		var now: int = Time.get_ticks_msec()
		var last: Node = targets[-1]
		if now - _last_bolt_msec >= BOLT_INTERVAL_MSEC and is_enemy(last):
			_last_bolt_msec = now
			fx("bolt", last.global_position, {"warn": 0.02})
			for e in enemies_near(last.global_position, BOLT_RADIUS):
				hit(e, ap() * 1.5 * power)
