extends "res://scripts/enchant_behavior.gd"

## Seri Parmak (Tabanca, kalıcı özellik) - bkz. EnchantDefs "seri_parmak". Öldürdüğün her düşman sp_dur sn saldırı hızı yığını verir
## (yığın başına sp_per, en çok sp_cap; her öldürme süreyi yeniler). Öldürme: hasardan ÖNCE hedef mark_kill ile işaretlenir
## (enemy.gd "evo_kill"), kısa süre içinde ölürse host "sp_kill" olayını yollar - istemcide de çalışır.
## Kurşun Yağmuru: 3+ yığında atış şansla ek mermi; Final: yığın dolunca her atış çift mermi.

const KILL_FLAG_TIME := 0.8
const MIN_STACKS_EXTRA := 3

var _stacks: int = 0
var _until_msec: int = 0


func damage_extra(dmg: float, t: Node2D) -> float:
	mark_kill(t, "sp_kill", KILL_FLAG_TIME)
	return dmg


func on_event(event: String, _data: Dictionary) -> void:
	if event != "sp_kill" or not can_act():
		return
	if Time.get_ticks_msec() >= _until_msec:
		_stacks = 0
	_stacks = mini(n("sp_cap", 5), _stacks + 1)
	_until_msec = Time.get_ticks_msec() + int(f("sp_dur", 3.0) * 1000.0)
	fx("text", (owner_player() as Node2D).global_position, {"text": "x%d" % _stacks, "color": Color(1.0, 0.8, 0.35)})


func current_stacks() -> int:
	return _stacks if Time.get_ticks_msec() < _until_msec else 0


func attack_speed_extra() -> float:
	return float(current_stacks()) * f("sp_per", 0.12)


func fire_extra(target: Node2D, is_extra: bool) -> void:
	if is_extra or not is_instance_valid(target) or not can_act():
		return
	var st: int = current_stacks()
	var full: bool = flag("sp_full_double") and st >= n("sp_cap", 5)
	var extra: bool = st >= MIN_STACKS_EXTRA and randf() < f("sp_extra")
	if full or extra:
		weapon.fire_enchant_shot(target, 0.06, 1.0, deg_to_rad(randf_range(-6.0, 6.0)))
