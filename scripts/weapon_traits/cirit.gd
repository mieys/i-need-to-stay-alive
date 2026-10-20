extends "res://scripts/enchant_behavior.gd"

## Cirit (Mızrak) - bkz. weapon_traits.gd "cirit" (madde 305). Her N. saplamada mızrak fırlatılır: weapon.gd _start_mizrak_thrust
## wants_throw()/throw_params() sorar, görünüş + zaman çizelgesi scripts/mizrak_thrust_math.gd (ikonun kendisi uçar, kukla aynı planı
## oynatır). HASAR burada: bırakış anında (weapon.gd _mizrak_release -> release_cirit) karede ilerleyen bir uç başlar, yolundaki her
## düşmana BİR kez saldırı gücü x cirit_ap (alan hasarı sayılır). Yarık Zırh: vurulan 3 sn mızraktan fazla hasar alır (damage_extra =
## birincil saplama, vuln_mult = hattaki diğerleri). Final (cirit_skewer): ilk 3 (boss hariç) düşmanı uçta yolun sonuna iter, sonda
## sersemletme + ek hasar + çevreye pay. Sadece kasterde çalışır (hasar yetkisi silahın sahibinde, diğer silah vuruşları gibi).

const MizrakThrustMath := preload("res://scripts/mizrak_thrust_math.gd")
const HIT_RADIUS := 14.0 ## uç çevresinde vuruş yarıçapı (k = 1; saplama hattının yarı genişliği)
const VULN_MS := 3000
const SKEWER_STUN := 1.0
const SKEWER_AP := 1.0
const SKEWER_AOE := 70.0
const SKEWER_AOE_AP := 0.5

var _flights: Array = [] ## {pos, dir, left, speed, r, dmg, hit: {id: true}, skew: [düşman]}
var _vuln: Dictionary = {} ## düşman id -> bitiş (msec)
var throws: int = 0 ## bırakılan cirit sayısı (test/gözlem)


## Bu saldırı fırlatma mı (attacks on_fire'da arttı: 4., 8., ... saplama; Hafif Cirit ile 3.).
func wants_throw() -> bool:
	return can_act() and every(maxi(1, n("cirit_every", 4)))


func throw_params() -> Dictionary:
	return {"range": f("cirit_range", MizrakThrustMath.CIRIT_RANGE), "speed": MizrakThrustMath.CIRIT_SPEED * maxf(0.1, f("cirit_speed", 1.0))}


func release_cirit(pos: Vector2, dir: Vector2, travel: float, speed: float, k: float = 1.0) -> void:
	if not can_act() or dir.is_zero_approx():
		return
	throws += 1
	_flights.append({"pos": pos, "dir": dir.normalized(), "left": travel, "speed": speed, "r": HIT_RADIUS * clampf(k, 0.5, 3.0),
		"dmg": ap() * f("cirit_ap", 0.9), "hit": {}, "skew": []})


func process_extra(delta: float) -> void:
	if _flights.is_empty():
		return
	var keep: Array = []
	for fl: Dictionary in _flights:
		var step: float = minf(float(fl["left"]), float(fl["speed"]) * delta)
		## hızlı uç küçük yaratığı atlamasın: alt adım <= yarıçap
		var n_sub: int = maxi(1, ceili(step / maxf(4.0, float(fl["r"]))))
		for i in range(n_sub):
			fl["pos"] = Vector2(fl["pos"]) + Vector2(fl["dir"]) * (step / float(n_sub))
			fl["left"] = float(fl["left"]) - step / float(n_sub)
			_hit_around(fl)
		if float(fl["left"]) <= 0.01:
			_land(fl)
		else:
			keep.append(fl)
	_flights = keep


func _hit_around(fl: Dictionary) -> void:
	var hits: Dictionary = fl["hit"]
	var skew: Array = fl["skew"]
	for e in enemies_near(fl["pos"], float(fl["r"])):
		var id: int = e.get_instance_id()
		if hits.has(id):
			continue
		hits[id] = true
		hit(e, float(fl["dmg"]))
		if f("cirit_vuln") > 0.0:
			_vuln[id] = Time.get_ticks_msec() + VULN_MS
		if skew.size() < n("cirit_skewer") and not status(e, "boss"):
			skew.append(e)
			el(e, "knock", {"dir": fl["dir"], "dist": float(fl["left"]), "quiet": true})


## Final: şişlenenler yolun sonunda sersemler + ek hasar, çakıldığı yerin çevresine pay.
func _land(fl: Dictionary) -> void:
	var skew: Array = fl["skew"]
	if skew.is_empty():
		return
	var end: Vector2 = fl["pos"]
	var done: Dictionary = {}
	for e in skew:
		if is_enemy(e):
			done[e.get_instance_id()] = true
			hit(e, ap() * SKEWER_AP)
			el(e, "stun", {"dur": SKEWER_STUN})
	for e in enemies_near(end, SKEWER_AOE):
		if not done.has(e.get_instance_id()):
			hit(e, ap() * SKEWER_AOE_AP)
	fx("spark_ring", end, {"radius": SKEWER_AOE, "color": Color(1.0, 0.95, 0.8)})


## Yarık Zırh: ciritin vurduğu düşman mızraktan bu çarpanla hasar alır (süre dolunca 1).
func vuln_mult(t: Node) -> float:
	if f("cirit_vuln") <= 0.0 or not is_instance_valid(t):
		return 1.0
	var id: int = t.get_instance_id()
	var until: int = int(_vuln.get(id, 0))
	if until <= Time.get_ticks_msec():
		if until > 0:
			_vuln.erase(id)
		return 1.0
	return 1.0 + f("cirit_vuln")


func damage_extra(dmg: float, t: Node2D) -> float:
	return dmg * vuln_mult(t)
