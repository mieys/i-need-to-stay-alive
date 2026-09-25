extends "res://scripts/enchant_behavior.gd"

## Aşırı Gerilim (EnchantDefs "yildirim_gerilim"): ışın aynı düşmanda kaldıkça hasar birikir (her tikte geçen süre kadar).
## Tavanda: sersemletme (bir kez), kalkan delme; final (Kalkan Yüzüğü) Tesla Bobini - tavanda kalkan saniyede %2 dolar,
## kalkan doluyken ışın +%30.

const TESLA_BONUS := 0.3

var _ramp_target_id: int = 0
var _ramp: float = 0.0
var _last_tick_msec: int = 0
var _stunned_ids: Dictionary = {}


func _cap() -> float:
	return f("ramp_cap", 0.6)


func _at_cap() -> bool:
	return _ramp >= _cap() - 0.001


## modify_damage beam tikinde on_beam_tick'ten ÖNCE çağrılır - birikimi burada güncelle.
func damage_extra(dmg: float, t: Node2D) -> float:
	if not is_instance_valid(t):
		return dmg
	var now: int = Time.get_ticks_msec()
	var id: int = t.get_instance_id()
	if id != _ramp_target_id:
		_ramp = _ramp * f("ramp_keep")
		_ramp_target_id = id
		_last_tick_msec = now
	var dt: float = clampf(float(now - _last_tick_msec) / 1000.0, 0.0, 0.5)
	_last_tick_msec = now
	_ramp = minf(_cap(), _ramp + f("ramp_rate", 0.1) * dt)
	var m: float = 1.0 + _ramp
	if flag("tesla") and _shield_full():
		m *= 1.0 + TESLA_BONUS
	return dmg * m


func pen_extra() -> float:
	return f("ramp_pen") if _at_cap() else 0.0


func on_beam_tick(target: Node, dmg: float) -> void:
	super.on_beam_tick(target, dmg)
	if not _at_cap() or not is_enemy(target):
		return
	if flag("ramp_stun") and not _stunned_ids.has(target.get_instance_id()):
		_stunned_ids[target.get_instance_id()] = true
		target.apply_element("stun", {"dur": 0.5})
		fx("burst", target.global_position, {"palette": "spark", "count": 12, "speed": 120.0, "life": 0.35})
	if flag("tesla"):
		var p: Node = owner_player()
		if p and p.has_method("heal_shield"):
			## Tik ~1/3 sn: saniyede %2.
			p.heal_shield(float(p.get("item_shield_max")) * 0.02 * float(weapon.get("beam_tick_interval")) * pw("hit"))


func _shield_full() -> bool:
	var p: Node = owner_player()
	return p != null and float(p.get("item_shield_max")) > 0.0 and float(p.get("item_shield_hp")) >= float(p.get("item_shield_max")) - 0.5
