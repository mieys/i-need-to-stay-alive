extends "res://scripts/enchant_behavior.gd"

## Bumerang Testeresi (Bumerang) - bkz. EnchantDefs "bumerang_testeresi". Bumerang uç noktada (ortak "apex_pause" - uzak
## kopya da aynı süre durur) saw_dur sn yerinde döner: saw_tick'te bir çevresindekilere hasar (bumerangın kendi duraklama
## vuruşları kapalı - "pause_hits": false, çift sayılmasın), (Girdap Tutuşu) merkezine çeker. Görsel: saw sayfası (süreli
## döngü). Final: testere döndüğü her saniye %15 güçlenir; dönüşte değdiği herkese kesin kritik ("hit_on_return" +
## "return_crit" - boomerang_projectile.gd).

const SHEET_R := 33.0

var _saws: Array = [] ## {proj, t, tick, pos}


func _on_setup() -> void:
	stats["apex_pause"] = f("saw_dur", 1.5)


func look_extra(_proj: Node2D, d: Dictionary) -> Dictionary:
	var props: Dictionary = {"pause_hits": false}
	if flag("return_crit"):
		props["hit_on_return"] = true
		props["return_crit"] = true
	d["props"] = props
	return d


func on_boomerang_apex(proj: Node2D) -> void:
	if not is_instance_valid(proj) or not can_act():
		return
	var at: Vector2 = proj.global_position
	sprite("saw", at, {"loop_time": f("saw_dur", 1.5), "scale": f("saw_radius", 40.0) / (SHEET_R * 1.212), "z": 9})
	_saws.append({"proj": proj, "t": 0.0, "tick": 0.0, "pos": at})


func process_extra(delta: float) -> void:
	if _saws.is_empty():
		return
	var keep: Array = []
	for s in _saws:
		s["t"] = float(s["t"]) + delta
		if float(s["t"]) >= f("saw_dur", 1.5):
			continue
		keep.append(s)
		s["tick"] = float(s["tick"]) - delta
		if float(s["tick"]) > 0.0:
			continue
		s["tick"] = maxf(0.08, f("saw_tick", 0.3))
		var at: Vector2 = Vector2(s["pos"])
		var r: float = f("saw_radius", 40.0)
		var ramp: float = 1.0 + f("saw_ramp") * floorf(float(s["t"]))
		for e in enemies_near(at, r):
			hit(e, ap() * f("saw_ap") * ramp)
		if flag("saw_pull"):
			for e in enemies_near(at, r * 2.2):
				if e.is_boss:
					continue
				var to_c: Vector2 = at - e.global_position
				if to_c.length() > 10.0:
					e.apply_element("knock", {"dir": to_c.normalized(), "dist": minf(26.0, to_c.length() - 8.0), "quiet": true})
	_saws = keep
