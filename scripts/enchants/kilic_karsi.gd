extends "res://scripts/enchant_behavior.gd"

## Karşı Saldırı (EnchantDefs "kilic_karsi"): hasar alınca (player.gd _enchant_owner_damaged -> on_owner_damaged) 1 sn
## boyunca kılıç iki kat vurur (II: alanı da büyür). Engelleme şansı (block_chance - player tavanı %35) ve engellenen
## saldırı (on_blocked) da karşılığı başlatabilir. Final (Kalkan Yüzüğü) Mükemmel Savunma: kalkan doluyken engelleme
## %35; engellenen hasarın iki katı saldırana döner ve 2 sn +%30 hasar.

const COUNTER_MSEC := 1000
const GUARD_BONUS_MSEC := 2000

var _counter_until_msec: int = 0
var _guard_until_msec: int = 0


func _countering() -> bool:
	return Time.get_ticks_msec() < _counter_until_msec


func _start_counter() -> void:
	_counter_until_msec = Time.get_ticks_msec() + COUNTER_MSEC


func on_owner_damaged(amount: float, _source: Node) -> float:
	if amount > 0.0:
		_start_counter()
	return amount


func block_chance() -> float:
	if flag("perfect_guard") and _shield_full():
		return 0.35
	return f("block")


func on_blocked(amount: float, source: Node) -> void:
	if flag("block_counter"):
		_start_counter()
	if flag("perfect_guard"):
		_guard_until_msec = Time.get_ticks_msec() + GUARD_BONUS_MSEC
		if is_enemy(source):
			hit(source, amount * 2.0)
			fx("chain", owner_player().global_position, {"to": (source as Node2D).global_position, "color": Color(0.9, 0.95, 1.0)})


func damage_extra(dmg: float, _t: Node2D) -> float:
	var m: float = 1.0
	if _countering():
		m *= f("counter_mult", 2.0)
	if Time.get_ticks_msec() < _guard_until_msec:
		m *= 1.3
	return dmg * m


func aoe_extra() -> float:
	return f("counter_aoe", 1.0) if _countering() else 1.0


func _shield_full() -> bool:
	var p: Node = owner_player()
	return p != null and float(p.get("item_shield_max")) > 0.0 and float(p.get("item_shield_hp")) >= float(p.get("item_shield_max")) - 0.5
