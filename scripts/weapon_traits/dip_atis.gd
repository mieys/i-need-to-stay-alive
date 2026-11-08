extends "res://scripts/enchant_behavior.gd"

## Dip Atış (Pompalı Tüfek, kalıcı özellik) - bkz. weapon_traits.gd "dip_atis" (madde 448). Her atış `pellets` saçma atar (asıl atış +
## weapon.fire_pellets ile pellets-1 tane, koni scripts/pompali_math.gd); her saçma saldırı gücünün %25'ini vurur, yani hasar
## hedefin mesafesine göre kendiliğinden değişir: dibinde hepsi isabet eder, uzakta azı. Kırıcı Darbe: `push` birim, 100 birim
## içinde vurulan sıradan yaratıklar geri itilir (aynı yaratığa 0,25 sn'de bir; bosslar/elitler itilmez). Tam Yük: her
## `full_every`. atış çift yüktür (2x saçma, koni %30 geniş). Sadece kasterde çalışır; uzak oyuncular mermileri broadcast_projectile ile görür.

const PompaliMath := preload("res://scripts/pompali_math.gd")
const PUSH_RANGE := 100.0
const PUSH_GAP_MSEC := 250
const FULL_CONE_MULT := 1.3

var _last_push: Dictionary = {} ## yaratık id -> son itiş zamanı (ms)
var volleys: int = 0 ## gözlem/test
var last_count: int = 0


## Bu atışın saçma sayısı + koni açısı (Tam Yük dahil). every(): attacks on_fire'da arttı (4., 8., ... atış).
func volley_plan() -> Dictionary:
	var count: int = maxi(1, n("pellets", 6))
	var cone: float = f("cone", PompaliMath.CONE_DEG) * f("cone_mult", 1.0)
	var full: bool = n("full_every") > 0 and every(n("full_every"))
	if full:
		count *= 2
		cone *= FULL_CONE_MULT
	return {"count": count, "cone": cone, "full": full}


func fire_extra(target: Node2D, is_extra: bool) -> void:
	if is_extra or not is_instance_valid(target) or not can_act():
		return
	var plan: Dictionary = volley_plan()
	volleys += 1
	last_count = int(plan["count"])
	var angles: Array = PompaliMath.extra_angles(int(plan["count"]), float(plan["cone"]), PompaliMath.JITTER_DEG)
	if not angles.is_empty():
		weapon.fire_pellets(target, angles)


func hit_extra(t: Node, _dmg: float, _is_primary: bool, _proj: Node2D) -> void:
	if f("push") <= 0.0 or not is_enemy(t) or not can_act():
		return
	if status(t, "boss") or t.get("is_elite") == true:
		return
	var p: Node = owner_player()
	if p == null or not (p is Node2D):
		return
	var from: Vector2 = (p as Node2D).global_position
	var to_e: Vector2 = (t as Node2D).global_position - from
	if to_e.length() > PUSH_RANGE:
		return
	var id: int = t.get_instance_id()
	var now: int = Time.get_ticks_msec()
	if now - int(_last_push.get(id, -100000)) < PUSH_GAP_MSEC:
		return
	if _last_push.size() > 64:
		_last_push.clear()
	_last_push[id] = now
	el(t, "knock", {"dir": to_e.normalized() if to_e.length() > 1.0 else Vector2.RIGHT, "dist": f("push"), "quiet": true})
