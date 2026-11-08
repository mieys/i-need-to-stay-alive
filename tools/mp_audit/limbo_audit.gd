extends SceneTree

## Çok oyunculu denetim: RUH HÂLİ (madde 438). Host + istemci, başsız (pencere yok).
##   1) İstemci level ekranını açar (host oynamaya devam eder): istemci donuk/dokunulmaz/okuma klibinde, dünya AKAR; host'ta kukla ruh.
##   2) Host da açar: herkes menüde -> iki tarafta da dünya DURUR.
##   3) İstemci kartını seçip pazarı kapatır: istemci döner, dünya yine akar (host hâlâ menüde, host'un kuklası istemcide ruh).
##   4) Host da biter: herkes normal.
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_audit.ps1 -Mode limbo

const HADIME := 14
const CLIENT_CHAR := 2

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _check(name: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	_log("%s %s %s" % ["OK  " if ok else "FAIL", name, detail])


func _flag(n: String) -> void:
	FileAccess.open(_dir.path_join(n + ".flag"), FileAccess.WRITE).close()


func _has_flag(n: String) -> bool:
	return FileAccess.file_exists(_dir.path_join(n + ".flag"))


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
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
	player.set("max_health", 100000.0)
	player.set("health", 100000.0)
	if _role == "host":
		_flag("ready")
	else:
		await _until_forced(func(): return _has_flag("ready"), 30.0)
	paused = false
	var rp: Node = get_nodes_in_group("remote_players")[0]

	if _role == "client":
		## 1) istemci menüye girer
		main.call("_show_level_up_screen", int(_gm.get("team_level")))
		await _wait(1.5)
		_check("istemci.ruh_hali", player.get("in_limbo") == true)
		_check("istemci.oyuncu_donuk", player.process_mode == Node.PROCESS_MODE_DISABLED)
		_check("istemci.okuma_klibi", String(player.get("anim").animation).begins_with("read_"), String(player.get("anim").animation))
		_check("istemci.ruh_gorseli", player.get_node_or_null("LimboFx") != null)
		_check("istemci.dunya_akiyor(host oynuyor)", not paused)
		var hp0: float = float(player.get("health"))
		player.call("take_damage", 500.0)
		_check("istemci.dokunulmaz", is_equal_approx(float(player.get("health")), hp0), str(player.get("health")))
		var pos0: Vector2 = player.global_position
		_flag("c_in")
		## 2) host da girince dünya durur
		await _until(func(): return _has_flag("h_in"), 30.0)
		await _wait(1.5)
		_check("istemci.herkes_menude_dunya_durur", paused)
		_check("istemci.host_kuklasi_ruh", rp.get("in_limbo") == true)
		_check("istemci.yerinden_oynamadi", player.global_position.distance_to(pos0) < 0.5)
		## 3) kart + pazar
		var picked: bool = await _finish_my_flow(main)
		_check("istemci.akisi_bitirdi", picked)
		await _wait(1.0)
		_check("istemci.dondu", player.get("in_limbo") != true and player.process_mode != Node.PROCESS_MODE_DISABLED)
		_check("istemci.ruh_gorseli_kalkti", player.get_node_or_null("LimboFx") == null)
		_check("istemci.karakter_gorunur", player.get("anim").visible == true)
		_check("istemci.dunya_akiyor(host menude)", not paused)
		_check("istemci.host_kuklasi_hala_ruh", rp.get("in_limbo") == true)
		_flag("c_out")
		await _until(func(): return _has_flag("h_out"), 30.0)
		await _wait(1.5)
		_check("istemci.host_kuklasi_dondu", rp.get("in_limbo") != true and rp.get_node_or_null("LimboFx") == null)
		_check("istemci.host_kuklasi_gorunur", rp.get("anim").visible == true)
		_check("istemci.son_dunya_akiyor", not paused)
	else:
		await _until(func(): return _has_flag("c_in"), 30.0)
		await _wait(1.0)
		_check("host.istemci_kuklasi_ruh", rp.get("in_limbo") == true)
		_check("host.kukla_donuk", rp.process_mode == Node.PROCESS_MODE_DISABLED)
		_check("host.kukla_ruh_gorseli", rp.get_node_or_null("LimboFx") != null)
		_check("host.kukla_okuma_klibi", String(rp.get("anim").animation).begins_with("read_"), String(rp.get("anim").animation))
		_check("host.dunya_akiyor", not paused)
		## yaratık hedeflemesi: kukla hedef listesinde hedeflenemez olmalı
		var bridge: Node = _find_by_method(main, "_build_targets")
		if bridge:
			bridge.call("_build_targets")
			var nodes: Array = bridge.get("_target_nodes")
			_check("host.kukla_hedef_listesinde", nodes.has(rp))
		## 2) host da girer
		main.call("_show_level_up_screen", int(_gm.get("team_level")))
		await _wait(1.0)
		_flag("h_in")
		await _wait(1.0)
		_check("host.herkes_menude_dunya_durur", paused)
		await _until(func(): return _has_flag("c_out"), 40.0)
		await _wait(1.5)
		_check("host.istemci_dondu_dunya_akar", not paused)
		_check("host.istemci_kuklasi_normal", rp.get("in_limbo") != true and rp.process_mode != Node.PROCESS_MODE_DISABLED)
		_check("host.istemci_kuklasi_gorunur", rp.get("anim").visible == true)
		_check("host.kendisi_hala_ruh", player.get("in_limbo") == true)
		var picked: bool = await _finish_my_flow(main)
		_check("host.akisi_bitirdi", picked)
		await _wait(1.0)
		_check("host.dondu", player.get("in_limbo") != true and player.process_mode != Node.PROCESS_MODE_DISABLED)
		await _wait(0.5)
		_check("host.karakter_gorunur", player.get("anim").visible == true)
		_flag("h_out")
		await _wait(3.0)
	_log("ÖZET başarısız=%d" % _fails)
	await _wait(1.0)
	quit()


## Kart ekranında rastgele kart seçer, pazar açılırsa kapatır; ruh hâli bitene dek (en çok 15 sn).
func _finish_my_flow(main: Node) -> bool:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 15000:
		if not bool(main.call("is_local_limbo")):
			return true
		var lu: Node = main.get_node_or_null("LevelUpScreen")
		if lu and lu.has_method("_auto_pick_random_card"):
			lu.call("_auto_pick_random_card")
		var mk: Node = main.get_node_or_null("LevelMarketScreen")
		if mk and mk.has_method("close"):
			mk.call("close")
		for c in main.get_children():
			if c.has_method("setup") and c.has_signal("closed") and String(c.name).begins_with("ChestMenu"):
				c.emit_signal("closed")
		await _wait(0.3)
	return not bool(main.call("is_local_limbo"))


## Duraklamayı ZORLAMAYAN bekleme (denetlenen şey duraklama).
func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _until(cond: Callable, timeout: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(timeout * 1000.0):
		await process_frame


## Kurulum aşaması (silah seçimi vb. duraklatır) - duraklamayı açarak bekler.
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
