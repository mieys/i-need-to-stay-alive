extends "res://scripts/enchant_behavior.gd"

## Kanayan Kesikler (Bıçak, kalıcı özellik) - bkz. EnchantDefs "kanayan_kesikler". Her vuruş süreli bir kanama yığını bırakır
## (enchant_behavior.gd dot_*: yığın başına saniyede saldırı gücü x kb_ap, kb_dur sn, en çok kb_cap yığın); art arda kb_combo.
## vuruş (2 sn ara verince sıfırlanır) hedefteki yüklerin KALAN hasarını tek seferde patlatır. Final (kb_spread): kanayan düşman
## ölünce yükleri 100 birim içindeki en yakın düşmana geçer.

const COMBO_RESET := 2.0
const SPREAD_RANGE := 100.0

var _combo_n: int = 0
var _last_hit_msec: int = -100000


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or proj != null or not is_enemy(t) or not can_act():
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_hit_msec > int(COMBO_RESET * 1000.0):
		_combo_n = 0
	_last_hit_msec = now
	_combo_n += 1
	dot_add(t, ap() * f("kb_ap", 0.06), f("kb_dur", 4.0), n("kb_cap", 5))
	if _combo_n >= n("kb_combo", 3):
		_combo_n = 0
		_burst(t)


func _burst(t: Node) -> void:
	var left: float = dot_remaining(t) * f("kb_burst", 1.0)
	if left <= 0.0:
		return
	var at: Vector2 = (t as Node2D).global_position
	dot_clear(t)
	hit(t, left)
	var col: Color = EnchantDefs.element_color("kanama")
	fx("ring", at, {"radius": 34.0, "color": col, "duration": 0.35})
	fx("burst", at, {"palette": "fire", "count": 10, "speed": 90.0, "life": 0.35})


func on_dot_victim_died(rec: Dictionary) -> void:
	if not flag("kb_spread") or not can_act():
		return
	var pos: Vector2 = rec["pos"]
	var nxt: Node = nearest_enemy(pos, SPREAD_RANGE)
	if nxt == null:
		return
	dot_transfer(rec, nxt, n("kb_cap", 5))
	fx("chain", pos, {"to": (nxt as Node2D).global_position, "color": EnchantDefs.element_color("kanama")})
