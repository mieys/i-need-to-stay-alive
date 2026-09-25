extends "res://scripts/enchant_behavior.gd"

## Rüzgâr Kılıcı (EnchantDefs "kilic_ruzgar"): vuruş sıklığı (orbit_cd_mult) / alan temel sınıfta. Her N savuruşta
## (on_revolution - çeyrek tur, ~1 sn) sahibinin çevresinde kasırga savuruşu (V: içeri çeker). Final (Deri Çizme) Kılıç Ustası: hareket
## halindeyken kılıç iki kat vurur; sıyrılınca (player.gd -> on_dodge) 3 sn boyunca yarım saniyede bir kasırga.

const WHIRL_RADIUS := 120.0
const WIND := Color(0.85, 0.95, 1.0)
const DANCE_MSEC := 3000
const DANCE_INTERVAL := 0.5

var _dance_until_msec: int = 0
var _dance_timer: float = 0.0


func revolution_extra(_pos: Vector2) -> void:
	if n("whirl_every") > 0 and every(n("whirl_every")) and can_act():
		_whirl()


func _whirl() -> void:
	var p: Node2D = owner_player() as Node2D
	if p == null:
		return
	var pos: Vector2 = p.global_position
	for e in blast(pos, WHIRL_RADIUS, ap() * 0.8 * power, WIND, "wave"):
		var to_c: Vector2 = pos - e.global_position
		if flag("whirl_pull") and e.get("is_boss") != true and to_c.length() > 30.0:
			e.apply_element("knock", {"dir": to_c.normalized(), "dist": minf(40.0, to_c.length() - 25.0), "quiet": true})
	fx("burst", pos, {"palette": "dust", "count": 14, "speed": 180.0, "life": 0.35})


func damage_extra(dmg: float, _t: Node2D) -> float:
	return dmg * 2.0 if flag("sword_master") and is_moving() else dmg


func on_dodge() -> void:
	if flag("sword_master"):
		_dance_until_msec = Time.get_ticks_msec() + DANCE_MSEC
		_dance_timer = 0.0


func process_extra(delta: float) -> void:
	if Time.get_ticks_msec() >= _dance_until_msec:
		return
	_dance_timer -= delta
	if _dance_timer <= 0.0:
		_dance_timer = DANCE_INTERVAL
		if can_act():
			_whirl()
