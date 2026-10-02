extends "res://scripts/enchant_behavior.gd"

## Sismik Dalga (Topuz) - bkz. EnchantDefs "sismik_dalga". Her ana hedef isabeti şansa bağlı olarak sahibin çevresine yayılan
## bir dalga (seismic_ring sayfası): hasar + itme; Çift Nabız ile 0,25 sn arayla 2 dalga. Final: şans %50, dalga düşmanları
## 1,5 sn yere serer (sersemletme); savrulan düşmanın düşeceği yerde başka bir düşman varsa ikisi de çarpışma hasarı alır.

const PULSE_GAP := 0.25
const COLLIDE_DIST := 26.0


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or proj != null or not is_enemy(t) or not can_act():
		return
	if randf() >= maxf(f("seis_chance"), f("seis_chance_final")):
		return
	var pulses: int = maxi(1, n("seis_pulses", 1))
	for i in range(pulses):
		if i == 0:
			_pulse()
		else:
			get_tree().create_timer(PULSE_GAP * float(i), false).timeout.connect(_pulse)


func _pulse() -> void:
	var pl: Node2D = owner_player() as Node2D
	if pl == null or not can_act():
		return
	var at: Vector2 = pl.global_position
	var r: float = f("seis_radius", 110.0)
	var push: float = f("seis_push", 60.0)
	sprite("seismic_ring", at, {"scale": r / (91.0 * 1.212), "z": 3})
	var victims: Array = enemies_near(at, r)
	var landing: Dictionary = {}
	for e in victims:
		hit(e, ap() * f("seis_ap"))
		var away: Vector2 = e.global_position - at
		var d: Vector2 = away.normalized() if away.length() > 1.0 else Vector2.RIGHT.rotated(randf() * TAU)
		if not e.is_boss:
			e.apply_element("knock", {"dir": d, "dist": push, "quiet": true})
			landing[e.get_instance_id()] = [e, e.global_position + d * push]
		if f("seis_knockdown") > 0.0:
			e.apply_element("stun", {"dur": f("seis_knockdown")})
	if f("seis_collide") <= 0.0:
		return
	## Savrulan düşmanın düşeceği noktada başka bir düşman varsa ikisi de çarpışma hasarı alır (düşman başına bir kez).
	var struck: Dictionary = {}
	for id in landing:
		var rec: Array = landing[id]
		var others: Array = enemies_near(Vector2(rec[1]), COLLIDE_DIST, rec[0])
		if others.is_empty():
			continue
		for victim in [rec[0], others[0]]:
			var vid: int = victim.get_instance_id()
			if not struck.has(vid):
				struck[vid] = true
				hit(victim, ap() * f("seis_collide"))
