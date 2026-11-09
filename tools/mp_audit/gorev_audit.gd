extends SceneTree

## Çok oyunculu denetim: YENİ GÖREVLER (madde 496). Host + istemci, başsız (pencere yok). Host görevi başlatır (debug yolu), istemci HOST
## OLMAYAN oyuncu olarak bakar:
##   1) Yuvaları Kapat: istemcide yuva sayısı = host'unki; istemcinin vuruşu host'taki gerçek yuvayı yıkar, ikisinde de söner; bitiş = başarı.
##   2) Kaçan Hazine: istemci kopyası host'un konumunda (sersemletilip ölçülür); istemcinin vuruşu host'ta altın düşürür (yarı can = 4 yığın),
##      altın istemcide de yerde görünür; süre dolunca iki tarafta da kaybolur (başarısız).
##   3) Ritüeli Boz: istemcide heykel + kristaller; istemci kırar -> başarı.
##   4) Gezici Işık: host ışıkta durunca ilerler, istemcideki ışık aynı yerde; karanlıktaki istemci oyuncusu hasar alır.
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_audit.ps1 -Mode gorev

const HADIME := 14
const CLIENT_CHAR := 2

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _fails: int = 0
var _started: Dictionary = {} ## tür -> görev kimliği
var _completed: Array = [] ## [tür, başarı]


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _check(name: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	_log("%s %s %s" % ["OK  " if ok else "FAIL", name, detail])


func _flag(n: String, data: Dictionary = {}) -> void:
	var f := FileAccess.open(_dir.path_join(n + ".flag"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _has_flag(n: String) -> bool:
	return FileAccess.file_exists(_dir.path_join(n + ".flag"))


func _flag_data(n: String) -> Dictionary:
	var t: String = FileAccess.get_file_as_string(_dir.path_join(n + ".flag"))
	var v: Variant = JSON.parse_string(t)
	return v if v is Dictionary else {}


func _targets(kind: String) -> Array:
	var out: Array = []
	var mid: int = int(_started.get(kind, -1))
	for n: Node in get_nodes_in_group("mission_targets"):
		if is_instance_valid(n) and int(n.get("mission_id")) == mid and n.get("is_dead") != true:
			out.append(n)
	return out


func _was_completed(kind: String) -> Variant:
	for c in _completed:
		if c[0] == kind:
			return c[1]
	return null


func _slot_of(wem: Node, kind: String) -> Dictionary:
	for s: Dictionary in wem.get("_slots"):
		if str(s.get("state", "")) == "active" and wem.MISSION_KIND_NAMES.get(s.get("kind"), "") == kind:
			return s
	return {}


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	_nm.connect("world_event_started", func(mid: int, kind: String, _p: Vector2, _r: float, _d: float, _e: Dictionary) -> void: _started[kind] = mid)
	_nm.connect("world_event_completed", func(_mid: int, kind: String, success: bool) -> void: _completed.append([kind, success]))
	if _role == "host":
		if not _nm.call("host_lan", _port, "Host", HADIME):
			_log("HATA host_lan"); quit(1); return
		await _until_forced(func(): return _nm.get("lobby_players").size() >= 2 and _nm.call("all_players_ready"), 40.0)
		_nm.call("start_multiplayer_game")
	else:
		await _wait_forced(1.0)
		if not _nm.call("join_lan", "127.0.0.1", _port, "Client", CLIENT_CHAR):
			_log("HATA join_lan"); quit(1); return
		await _until_forced(func(): return _nm.get("lobby_players").size() >= 2, 30.0)
		_nm.call("set_local_ready", true)
	await _until_forced(func(): return current_scene != null and current_scene.name == "Main", 60.0)
	if current_scene == null or current_scene.name != "Main":
		_log("HATA Main yok"); quit(1); return
	await _wait_forced(2.0)
	var ws: Node = _find_by_method(current_scene, "_auto_pick_random_card")
	if ws:
		ws.call("_auto_pick_random_card")
	await _wait_forced(1.0)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	_finish_house_intro()
	await _wait_forced(1.5)
	var main: Node = current_scene
	var player: Node2D = main.get_node_or_null("Player") as Node2D
	if player == null:
		_log("HATA Player yok"); quit(1); return
	await _until_forced(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	## Seyyar satıcı (ilk ziyaret 60-180 sn) güvenli alanı karanlık hasarını keser (madde 496) - denetim sırasında gelmesin.
	var merchant: Node = main.get_node_or_null("TravelingMerchant")
	if merchant:
		merchant.process_mode = Node.PROCESS_MODE_DISABLED
	_gm.set("merchant_zone_active", false)
	player.set("max_health", 100000.0)
	player.set("health", 100000.0)
	var wem: Node = main.get_node_or_null("WorldEventManager")
	_check("%s.gorev_yoneticisi_var" % _role, wem != null)
	if wem == null:
		quit(1); return
	if _role == "host":
		_flag("ready")
	else:
		await _until_forced(func(): return _has_flag("ready"), 30.0)
	if _role == "host":
		await _host(main, wem, player)
	else:
		await _client(main, player)
	_log("ÖZET başarısız=%d" % _fails)
	await _wait_forced(1.0)
	quit()


## Zindan haritasında oyuncunun yanındaki sabit ofset duvara düşebilir: oyunun kendi seçicisi (madde 496 mission_spots.gd), ana haritada ofset.
func _at(wem: Node, kind_name: String, fallback: Vector2) -> Vector2:
	if not load("res://scripts/mission_spots.gd").active():
		return fallback
	for k in wem.MISSION_KIND_NAMES:
		if wem.MISSION_KIND_NAMES[k] == kind_name:
			var p: Vector2 = wem.call("_pick_mission_position", k)
			if p != Vector2.ZERO:
				return p
	return fallback


func _host(main: Node, wem: Node, player: Node2D) -> void:
	var base: Vector2 = player.global_position
	## 1) yuvalar
	_check("host.yuva_basladi", wem.call("debug_force_start_mission", "close_nests", _at(wem, "close_nests", base + Vector2(0, 260))))
	await _wait_forced(1.5)
	var nests: Array = _targets("close_nests")
	_check("host.yuva_kuruldu", nests.size() == 3, str(nests.size()))
	_flag("n1", {"count": nests.size()})
	await _until_forced(func(): return _has_flag("c_n1"), 30.0)
	await _wait_forced(1.5)
	_check("host.istemci_vurusu_yuvayi_yikti", _targets("close_nests").size() == nests.size() - 1, str(_targets("close_nests").size()))
	for n: Node in _targets("close_nests"):
		n.call("take_damage", 1.0e9)
	await _wait_forced(1.5)
	_check("host.yuva_basari", _was_completed("close_nests") == true)
	_flag("n2")
	## 2) kaçan hazine
	_check("host.hazine_basladi", wem.call("debug_force_start_mission", "treasure_runner", _at(wem, "treasure_runner", base + Vector2(220, 0))))
	await _wait_forced(1.5)
	var runners: Array = _targets("treasure_runner")
	_check("host.hazine_kuruldu", runners.size() == 1)
	if runners.size() == 1:
		var r: Node2D = runners[0]
		r.call("apply_stun", 6.0)
		await _wait_forced(1.0)
		_flag("r1", {"x": r.global_position.x, "y": r.global_position.y, "max": float(r.get("max_health"))})
		await _until_forced(func(): return _has_flag("c_r1"), 30.0)
		await _wait_forced(1.0)
		_check("host.istemci_vurusu_altin_dusurdu", is_instance_valid(r) and int(r.call("dropped_gold_total")) == 48,
				str(r.call("dropped_gold_total")) if is_instance_valid(r) else "yok")
	var sl: Dictionary = _slot_of(wem, "treasure_runner")
	if not sl.is_empty():
		sl["timer"] = 0.01
	await _wait_forced(1.5)
	_check("host.hazine_kacti", _was_completed("treasure_runner") == false and _targets("treasure_runner").is_empty())
	_flag("r2")
	## 3) ritüel
	_check("host.rituel_basladi", wem.call("debug_force_start_mission", "break_ritual", _at(wem, "break_ritual", base + Vector2(-260, 0))))
	await _wait_forced(1.5)
	_flag("q1", {"count": _targets("break_ritual").size()})
	await _until_forced(func(): return _has_flag("c_q1"), 30.0)
	await _wait_forced(2.0)
	_check("host.rituel_bozuldu", _was_completed("break_ritual") == true, str(_targets("break_ritual").size()))
	_flag("q2")
	## 4) gezici ışık: host ışıkta durur (3 sn), sonra uzaklaşır; ışık durunca konum karşılaştırılır
	_check("host.isik_basladi", wem.call("debug_force_start_mission", "wandering_light", base))
	await _wait_forced(1.0)
	_flag("l0")
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		var s: Dictionary = _slot_of(wem, "wandering_light")
		if not s.is_empty():
			player.global_position = load("res://scripts/mission_van.gd").point_on_path(s["route"], float(s["progress"]))
		paused = false
		await process_frame
	var s2: Dictionary = _slot_of(wem, "wandering_light")
	_check("host.isik_ilerledi", not s2.is_empty() and float(s2["progress"]) > 60.0, str(s2.get("progress", -1)))
	player.global_position += Vector2(2000, 0)
	await _wait_forced(1.0)
	var lp: Vector2 = load("res://scripts/mission_van.gd").point_on_path(s2["route"], float(_slot_of(wem, "wandering_light").get("progress", 0.0)))
	_flag("l1", {"x": lp.x, "y": lp.y})
	await _until_forced(func(): return _has_flag("c_l1"), 30.0)
	var s3: Dictionary = _slot_of(wem, "wandering_light")
	if not s3.is_empty():
		s3["timer"] = 0.01
	await _wait_forced(1.5)
	_flag("done")
	await _wait_forced(2.0)


func _client(main: Node, player: Node2D) -> void:
	## 1) yuvalar
	await _until_forced(func(): return _has_flag("n1"), 30.0)
	await _wait_forced(1.5)
	var nests: Array = _targets("close_nests")
	_check("istemci.yuva_sayisi_ayni", nests.size() == int(_flag_data("n1").get("count", -1)), "%d / %s" % [nests.size(), _flag_data("n1").get("count")])
	_check("istemci.yuva_kozmetik", not nests.is_empty() and nests[0].call("is_host_simulated") == false)
	if not nests.is_empty():
		nests[0].call("take_damage", 1.0e9)
	_flag("c_n1")
	await _wait_forced(1.5)
	_check("istemci.yikilan_yuva_sondu", _targets("close_nests").size() == nests.size() - 1)
	await _until_forced(func(): return _has_flag("n2"), 30.0)
	await _wait_forced(1.0)
	_check("istemci.yuva_basari", _was_completed("close_nests") == true and _targets("close_nests").is_empty())
	## 2) kaçan hazine
	await _until_forced(func(): return _has_flag("r1"), 30.0)
	await _wait_forced(1.0)
	var runners: Array = _targets("treasure_runner")
	_check("istemci.hazine_var", runners.size() == 1)
	if runners.size() == 1:
		var d: Dictionary = _flag_data("r1")
		var hp := Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
		var r: Node2D = runners[0]
		_check("istemci.hazine_konumu_ayni", r.global_position.distance_to(hp) < 8.0, "%.1f px" % r.global_position.distance_to(hp))
		r.call("take_damage", float(d.get("max", 100.0)) * 0.5 + 1.0)
	_flag("c_r1")
	await _until_forced(func(): return _has_flag("r2"), 30.0)
	await _wait_forced(1.0)
	_check("istemci.hazine_kayboldu", _targets("treasure_runner").is_empty() and _was_completed("treasure_runner") == false)
	var golds: int = 0
	for n: Node in main.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("gold_drop.gd"):
			golds += 1
	_check("istemci.yerde_altin_gorunur", golds >= 4, str(golds))
	## 3) ritüel
	await _until_forced(func(): return _has_flag("q1"), 30.0)
	await _wait_forced(1.0)
	var altar: Node = null
	for n: Node in main.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("mission_ritual_altar.gd"):
			altar = n
	_check("istemci.heykel_var", altar != null)
	var crystals: Array = _targets("break_ritual")
	_check("istemci.kristal_sayisi_ayni", crystals.size() == int(_flag_data("q1").get("count", -1)), str(crystals.size()))
	for c: Node in crystals:
		c.call("take_damage", 1.0e9)
	_flag("c_q1")
	await _until_forced(func(): return _has_flag("q2"), 30.0)
	await _wait_forced(1.0)
	_check("istemci.rituel_basari", _was_completed("break_ritual") == true)
	## 4) gezici ışık: istemci karanlık halkada durur
	await _until_forced(func(): return _has_flag("l0"), 30.0)
	var light: Node2D = null
	for n: Node in main.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("mission_light.gd"):
			light = n
	_check("istemci.isik_var", light != null)
	var hp0: float = float(player.get("health"))
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000 and light != null and is_instance_valid(light): ## eşik 1,5 sn + tik 1 sn
		player.global_position = light.global_position + Vector2(300, 0)
		paused = false
		await process_frame
	_check("istemci.karanlikta_hasar", float(player.get("health")) < hp0, "%.0f -> %.0f (ruh=%s güvenli=%s)" % [hp0, float(player.get("health")),
			player.get("in_limbo"), _gm.get("merchant_zone_active")])
	await _until_forced(func(): return _has_flag("l1"), 30.0)
	await _wait_forced(1.0)
	if light != null and is_instance_valid(light):
		var d2: Dictionary = _flag_data("l1")
		var hl := Vector2(float(d2.get("x", 0)), float(d2.get("y", 0)))
		_check("istemci.isik_konumu_ayni", light.global_position.distance_to(hl) < 6.0, "%.1f px" % light.global_position.distance_to(hl))
	_flag("c_l1")
	await _until_forced(func(): return _has_flag("done"), 30.0)
	await _wait_forced(1.0)
	_check("istemci.isik_kalkti", light == null or not is_instance_valid(light))


func _wait_forced(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _until_forced(cond: Callable, timeout: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(timeout * 1000.0):
		paused = false
		await process_frame


func _find_by_method(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var r: Node = _find_by_method(c, method)
		if r:
			return r
	return null


func _finish_house_intro() -> void:
	var scene: Node = current_scene
	var intro: Node = scene.get_node_or_null("HouseInterior/HouseIntro") if scene else null
	if intro and intro.has_method("_set_phase"):
		intro.call("_set_phase", 3, 0.0) ## HouseIntro.Phase.DONE
	root.get_node("GameManager").set("invasion_pending", false)
