extends "res://scripts/enchant_behavior.gd"

## Mana Kalkanı (EnchantDefs "arcane_mana"): bu asanın verdiği hasarın bir kısmı kalkana döner (efsun gücü bu miktarı
## çarpar); kalkan doluyken bonus temel sınıfta. Kalkan kırılınca arcane patlaması (bekleme süreli); final (Kalkan
## Yüzüğü) kalkan doluyken alınan hasarın %30'u saldırana yansır.

const ARCANE := Color(0.7, 0.45, 1.0)
const BURST_RADIUS := 150.0

var _last_shield: float = 0.0
var _burst_cd: float = 0.0


func hit_extra(_t: Node, dmg: float, is_primary: bool, _proj: Node2D) -> void:
	if f("mana_leech") <= 0.0 or dmg <= 0.0:
		return
	var p: Node = owner_player()
	if p and p.has_method("heal_shield"):
		p.heal_shield(dmg * f("mana_leech") * pw("shield") * (1.0 if is_primary else 0.33))


func process_extra(delta: float) -> void:
	_burst_cd = maxf(0.0, _burst_cd - delta)
	if f("mana_burst") <= 0.0:
		return
	var p: Node = owner_player()
	if p == null:
		return
	var hp: float = float(p.get("item_shield_hp"))
	if _last_shield > 0.0 and hp <= 0.0 and _burst_cd <= 0.0 and can_act():
		_burst_cd = f("mana_burst")
		blast(p.global_position, BURST_RADIUS, ap() * 1.0, ARCANE)
		fx("ring", p.global_position, {"radius": BURST_RADIUS, "color": ARCANE, "duration": 0.5})
	_last_shield = hp


func on_owner_damaged(amount: float, source: Node) -> float:
	if f("mana_reflect") <= 0.0 or not is_enemy(source):
		return amount
	var p: Node = owner_player()
	if p and float(p.get("item_shield_max")) > 0.0 and float(p.get("item_shield_hp")) >= float(p.get("item_shield_max")) - 0.5:
		hit(source, amount * f("mana_reflect"))
		fx("chain", p.global_position, {"to": (source as Node2D).global_position, "color": ARCANE})
	return amount
