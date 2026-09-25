extends "res://scripts/enchant_behavior.gd"

## Buz Kristali (EnchantDefs "buz_kristal"): N sn'de bir sahibinin yanına buz oku atan kristal (enchant_area.gd "turret";
## yavaşlatır -> II'de dondurur; sayı sınırı; biterken patlama). Final (Kalkan Yüzüğü) Kristal Ordu - kalkan kırılınca
## (20 sn'de bir) etrafta 4 kristal, hepsi iki kat hızlı ateş eder.

const ICE := Color(0.75, 0.9, 1.0)
const ARMY_COOLDOWN := 20.0

var _timer: float = 2.0
var _last_shield: float = 0.0
var _army_cd: float = 0.0


func _turret(pos: Vector2) -> void:
	tagged_area("crystal", "turret", pos, {"duration": f("turret_dur", 8.0), "interval": 0.5 if flag("crystal_army") else 1.0,
		"range": 220.0, "damage": ap() * 0.4 * pw("area"), "element": "freeze" if flag("turret_freeze") else "slow",
		"blast": flag("turret_blast"), "color": ICE})


func process_extra(delta: float) -> void:
	_army_cd = maxf(0.0, _army_cd - delta)
	var p: Node = owner_player()
	if p == null:
		return
	if flag("crystal_army"):
		var hp: float = float(p.get("item_shield_hp"))
		if _last_shield > 0.0 and hp <= 0.0 and _army_cd <= 0.0 and can_act():
			_army_cd = ARMY_COOLDOWN
			for k in range(4):
				_turret(p.global_position + Vector2.RIGHT.rotated(TAU * float(k) / 4.0 + PI * 0.25) * 55.0)
		_last_shield = hp
	_timer -= delta
	if _timer > 0.0:
		return
	if not can_act() or own_count("crystal") >= n("turret_max", 1):
		_timer = 0.5
		return
	_timer = f("turret_cd", 8.0)
	_turret(p.global_position + Vector2(randf_range(-45.0, 45.0), randf_range(-35.0, 35.0)))
