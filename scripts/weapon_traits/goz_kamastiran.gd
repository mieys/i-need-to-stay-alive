extends "res://scripts/enchant_behavior.gd"

## Göz Kamaştıran Işık (Gökkuşağı Asası, kalıcı özellik, madde 306) - bkz. WeaponTraits "goz_kamastiran".
## Işın (weapon.gd beam_targets: birincil + finalde delinenler) AYNI düşmanda dz_need sn kesintisiz kalınca o düşman dz_dur sn kamaşır:
## sıradan yaratık sersemler (enemy "stun": saldıramaz/yetenek yok, başında dönen yıldızlar), boss/elit kamaşmaz -> dz_boss sn %20 az hasar
## verir (enemy "weaken"). Işın başka hedefe geçer ya da kesilirse sayaç sıfırlanır; kamaşma bitene kadar sayılmaz, bitince sıfırdan dolar.
## Kör Nokta (dz_vuln): kamaşan herkesten fazla hasar alır (enemy "vuln"). Işık Saçılması (dz_burst): kamaşma anında çevreye hasar + kısa
## kamaşma. Kamaşma anı efekti EnchantFx "sprite" rainbow_dazzle (diğer oyunculara da gider). Sayaç SADECE kasterde (silahın sahibinde)
## tutulur; etkiler apply_element ile host'a gider (istemcide yönlendirilir).

const DAZZLE_SCALE := 1.0 / 1.212 ## sayfa 1 dünya px/doku pikseli (fx_enchant_sprite.gd TEXEL 1,212)
const BOSS_WEAKEN := 0.2

var _hold: Dictionary = {} ## düşman kimliği -> {"node", "t" (sn), "block" (ms: kamaşma bitimi)}


func process_extra(delta: float) -> void:
	if not is_instance_valid(weapon) or not weapon.has_method("beam_targets"):
		return
	var now: int = Time.get_ticks_msec()
	var seen: Dictionary = {}
	for e in weapon.beam_targets():
		if not is_enemy(e):
			continue
		var id: int = e.get_instance_id()
		seen[id] = true
		var rec: Dictionary = _hold.get(id, {})
		if rec.is_empty():
			rec = {"node": e, "t": 0.0, "block": 0}
			_hold[id] = rec
		if now < int(rec["block"]):
			continue
		rec["t"] = float(rec["t"]) + delta
		if float(rec["t"]) >= f("dz_need", 3.0):
			rec["t"] = 0.0
			rec["block"] = now + int(f("dz_dur", 1.5) * 1000.0)
			_dazzle(e)
	for id in _hold.keys():
		if not seen.has(id):
			_hold.erase(id)


func beam_glow(t: Node) -> float:
	if not is_instance_valid(t):
		return 0.0
	var rec: Dictionary = _hold.get(t.get_instance_id(), {})
	if rec.is_empty():
		return 0.0
	if Time.get_ticks_msec() < int(rec["block"]):
		return 2.0
	return clampf(float(rec["t"]) / maxf(0.1, f("dz_need", 3.0)), 0.0, 1.0)


## Boss ve elit kamaşmaz (zayıflar).
func _tough(e: Node) -> bool:
	return e.get("is_boss") == true or e.get("is_elite") == true


func _dazzle(e: Node) -> void:
	var pos: Vector2 = (e as Node2D).global_position
	sprite("rainbow_dazzle", pos, {"scale": Vector2.ONE * DAZZLE_SCALE, "z": 9})
	_apply_daze(e, f("dz_dur", 1.5))
	if f("dz_burst") > 0.0:
		for o in enemies_near(pos, f("dz_burst_r", 70.0), e):
			hit(o, ap() * f("dz_burst"))
			_apply_daze(o, f("dz_burst_stun", 0.75))


func _apply_daze(e: Node, dur: float) -> void:
	if not is_enemy(e):
		return
	if _tough(e):
		el(e, "weaken", {"pct": BOSS_WEAKEN, "dur": f("dz_boss", 3.0) * dur / maxf(0.1, f("dz_dur", 1.5))})
		return
	el(e, "stun", {"dur": dur})
	if f("dz_vuln") > 0.0:
		el(e, "vuln", {"pct": f("dz_vuln"), "dur": dur})
