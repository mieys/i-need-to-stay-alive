extends SceneTree

## Çok oyunculu denetim: TESLİM OYLAMASI (madde 540). Host + istemci (ENet), istemci HOST OLMAYAN oyuncu.
##   3. sn: istemci oylama başlatır (request_surrender_vote = ESC > TESLİM OL)  -> 4,5. sn: host HAYIR der -> iki tarafta "geçmedi 1/2" + bekleme
##   7. sn: iki taraf bekleme süresini yerelde sıfırlar (120 sn beklememek için)
##   8. sn: host başlatır -> 9,5. sn: istemci F1'e basar (panelin gerçek _input'u) -> iki tarafta oyun "TESLİM OLUNDU" ile biter.
## Ölçülenler (her iki tarafta): olay zamanları (başladı / bitti / geçti), panel görünürlüğü, oy kutusu sayısı, bekleme, oyun bitti başlığı.
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_audit.ps1 -Mode teslim

const HOST_CHAR := 2
const CLIENT_CHAR := 10

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _t0: int = 0
var _events: Array = []
var _checks: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _now() -> float:
	return snappedf(float(Time.get_ticks_msec() - _t0) / 1000.0, 0.01)


func _panel_box() -> Control:
	var p: Node = current_scene.get_node_or_null("SurrenderVotePanel")
	return p.get_node_or_null("Panel") as Control if p else null


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	if _role == "host":
		if not _nm.call("host_lan", _port, "Host", HOST_CHAR):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2 and _nm.call("all_players_ready"), 40.0)
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0)
		if not _nm.call("join_lan", "127.0.0.1", _port, "Client", CLIENT_CHAR):
			_log("HATA join_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2, 30.0)
		_nm.call("set_local_ready", true)
	await _until(func(): return current_scene != null and current_scene.name == "Main", 60.0)
	if current_scene == null or current_scene.name != "Main":
		_log("HATA Main yok"); quit(1); return
	await _wait(2.0)
	var ws: Node = _find_by_method(current_scene, "_auto_pick_random_card")
	if ws:
		ws.call("_auto_pick_random_card")
	await _wait(1.0)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	_finish_house_intro()
	await _wait(1.5)
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	if _role == "host":
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
	_nm.connect("surrender_vote_started", func(init: int) -> void: _events.append(["basladi", _now(), init]))
	_nm.connect("surrender_vote_ended", func(p: bool, y: int, t: int) -> void: _events.append(["bitti", _now(), p, y, t]))
	_nm.connect("surrender_passed", func() -> void: _events.append(["gecti", _now()]))
	_checks["panel_var"] = _panel_box() != null
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	_t0 = Time.get_ticks_msec()
	var did: Dictionary = {}
	while true:
		paused = false
		var el: float = float(Time.get_ticks_msec() - _t0) / 1000.0
		if el >= 13.0:
			break
		if spawner:
			spawner.set("_spawn_timer", 1.0e9)
		for e in get_nodes_in_group("enemies"):
			if not e.is_queued_for_deletion():
				e.queue_free()
		if _role == "client" and el > 3.0 and not did.has("c_start"):
			did["c_start"] = true
			_nm.call("request_surrender_vote")
			_log("istemci oylama başlattı %.2f" % el)
		if el > 4.2 and not did.has("snap1"):
			did["snap1"] = true
			var box: Control = _panel_box()
			_checks["1_aktif"] = bool(_nm.get("surrender_vote_active"))
			_checks["1_panel_gorunur"] = box != null and box.visible
			var pips: Node = current_scene.find_child("Pips", true, false)
			_checks["1_kutu"] = (pips.get("voters") as PackedInt32Array).size() if pips else -1
			_checks["1_benim_oyum"] = int(_nm.call("my_surrender_vote"))
		if _role == "host" and el > 4.5 and not did.has("h_no"):
			did["h_no"] = true
			_nm.call("submit_surrender_vote", false)
			_log("host HAYIR %.2f" % el)
		if el > 6.0 and not did.has("snap2"):
			did["snap2"] = true
			_checks["2_aktif"] = bool(_nm.get("surrender_vote_active"))
			_checks["2_bekleme_sn"] = snappedf(float(_nm.call("surrender_cooldown_left")), 1.0)
			_checks["2_oyun_bitti"] = bool(_gm.get("is_game_over"))
		if el > 7.0 and not did.has("reset_cd"):
			did["reset_cd"] = true
			_nm.call("reset_surrender_vote")
		if _role == "host" and el > 8.0 and not did.has("h_start"):
			did["h_start"] = true
			_nm.call("request_surrender_vote")
			_log("host oylama başlattı %.2f" % el)
		if _role == "client" and el > 9.5 and not did.has("c_f1"):
			did["c_f1"] = true
			var panel: Node = current_scene.get_node_or_null("SurrenderVotePanel")
			var ev := InputEventKey.new()
			ev.pressed = true
			ev.keycode = KEY_F1
			ev.physical_keycode = KEY_F1
			if panel:
				panel.call("_input", ev)
			_log("istemci F1 %.2f" % el)
		await process_frame
	var title: Label = current_scene.get_node_or_null("DeathOverlay/Window/VBox/Title") as Label
	if title == null:
		for c in current_scene.get_children():
			if c is CanvasLayer and c.get_node_or_null("Window/VBox/Title"):
				title = c.get_node("Window/VBox/Title") as Label
	_checks["3_oyun_bitti"] = bool(_gm.get("is_game_over"))
	_checks["3_teslim"] = bool(_gm.get("run_surrendered"))
	_checks["3_baslik"] = title.text if title else "(yok)"
	_checks["3_panel_gorunur"] = _panel_box() != null and _panel_box().visible
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "events": _events, "checks": _checks}))
	out.close()
	_log("olaylar: %s" % JSON.stringify(_events))
	_log("denetim: %s" % JSON.stringify(_checks))
	_log("bitti")
	await _wait(2.0)
	quit()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _until(cond: Callable, timeout: float) -> void:
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


## Açılış sahnesini bitirir (madde 419 / 349 tuzağı; evcil_audit.gd ile aynı).
func _finish_house_intro() -> void:
	var scene: Node = current_scene
	var intro: Node = scene.get_node_or_null("HouseInterior/HouseIntro") if scene else null
	if intro and intro.has_method("_set_phase"):
		intro.call("_set_phase", 3, 0.0)
	root.get_node("GameManager").set("invasion_pending", false)
