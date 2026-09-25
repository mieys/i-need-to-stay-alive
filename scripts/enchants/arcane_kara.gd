extends "res://scripts/enchant_behavior.gd"

## Kara Büyü (EnchantDefs "arcane_kara"): işaret yükleri / tavan / ruh (mark_soul) / ölüm patlaması temel sınıfta +
## host'ta (enemy.gd - işaretli düşman ölünce "soul" olayı bu oyuncuya gelir). II: ruh 10 sn +%1 hasar (10 kez); IV:
## işaret yakındaki 2 düşmana bulaşır; final (Hasat Çantası) Ruh Hasadı - her 50 ruh kalıcı +1 saldırı gücü (sayaç silah
## meta'sında).

const SOUL_PER := 0.01
const SOUL_MAX := 10
const SOUL_DUR_MSEC := 10000
const SOULS_PER_AP := 50

var _souls: int = 0
var _souls_until_msec: int = 0


func hit_extra(t: Node, _dmg: float, is_primary: bool, _proj: Node2D) -> void:
	if not is_primary or not flag("mark_spread") or not is_enemy(t):
		return
	for e in random_enemies(t.global_position, 100.0, 2, t):
		apply_mark_to(e)


func damage_extra(dmg: float, _t: Node2D) -> float:
	if _souls > 0 and Time.get_ticks_msec() >= _souls_until_msec:
		_souls = 0
	return dmg * (1.0 + SOUL_PER * float(_souls))


func on_event(event: String, _data: Dictionary) -> void:
	if event != "soul":
		return
	if flag("soul_buff"):
		_souls = mini(SOUL_MAX, _souls + 1)
		_souls_until_msec = Time.get_ticks_msec() + SOUL_DUR_MSEC
	if flag("soul_harvest"):
		var total: int = int(keep_get("souls", 0)) + 1
		keep_set("souls", total)
		if total % SOULS_PER_AP == 0:
			var p: Node = owner_player()
			if p and p.has_method("enchant_add_attack_power"):
				p.enchant_add_attack_power(1.0)
