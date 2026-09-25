extends "res://scripts/enchant_behavior.gd"

## Buz Pençesi (EnchantDefs "pence_buz"): yavaşlatma / N isabette donma / donmuşa bonus temel sınıfta. III: isabetten
## ÖNCE donmuş düşmana vuruş çevreye buz kıymıkları saçar; final (Steroid) Yeti Pençesi - her 3. saldırıda 150 px buz
## depremi (saldırı gücü + maks can'ın %3'ü, dondurur).

const ICE := Color(0.75, 0.9, 1.0)
const YETI_RADIUS := 150.0

var _last_pos: Vector2 = Vector2.ZERO


func fire_start(target: Node2D, _is_extra: bool) -> void:
	if is_instance_valid(target):
		_last_pos = target.global_position


func on_hit(t: Node, dmg: float, is_primary: bool, proj: Node2D) -> void:
	var was_frozen: bool = status(t, "frozen")
	super.on_hit(t, dmg, is_primary, proj)
	if f("frozen_shatter") > 0.0 and is_primary and was_frozen and is_enemy(t):
		var pts: Array = [t.global_position]
		for e in random_enemies(t.global_position, 120.0, 3, t):
			hit(e, ap() * f("frozen_shatter") * pw("hit"))
			pts.append(e.global_position)
		fx("bursts", t.global_position, {"points": pts, "palette": "spark", "count": 6})


func fire_extra(_target: Node2D, is_extra: bool) -> void:
	if is_extra or n("yeti_every") <= 0 or not every(n("yeti_every")):
		return
	for e in blast(_last_pos, YETI_RADIUS, (ap() * 1.0 + max_hp() * 0.03) * pw("hit"), ICE, "slam"):
		freeze(e, 2.0)
