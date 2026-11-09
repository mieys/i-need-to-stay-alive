extends SceneTree

## Çok oyunculu denetim: yeni evciller Minik Cadı (slime) + Hayalet (madde 509) - sahip HOST OLMAYAN oyuncu (CLAUDE.md).
## İstemcinin evcili MP_CLIENT_PET (slime | hayalet; varsayılan slime). İstemci 3. sn'de tetikler: slime -> ulti kancası (_pet_on_ult_used),
## hayalet -> canı %20'ye çeker (düşük can tetiği). Ölçülenler (yükselen kenar zamanları):
##   istemci: own.slime_buyu / own.boy>1 / own.ortu / own.gorunmez
##   host   : pup.slime / pup.slime_buyu_klibi / pup.slime_efekt / pup.boy>1 / pup.hayalet / pup.hayalet_ortu / pup.gorunmez (yaratık hedeflemez)
## Kullanım: $env:MP_CLIENT_PET="hayalet"; powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_audit.ps1 -Mode evcil

const HOST_CHAR := 14
const CLIENT_CHAR := 2

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _pet: String = OS.get_environment("MP_CLIENT_PET") if OS.get_environment("MP_CLIENT_PET") != "" else "slime"
var _nm: Node
var _gm: Node
var _events: Array = []
var _t0: int = 0
var _first: Dictionary = {}
var _prev: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _now() -> float:
	return snappedf(float(Time.get_ticks_msec() - _t0) / 1000.0, 0.01)


func _edge(key: String, on: bool) -> void:
	if on and not bool(_prev.get(key, false)):
		_events.append([_now(), key + " AÇIK"])
		if not _first.has(key):
			_first[key] = _now()
	elif not on and bool(_prev.get(key, false)):
		_events.append([_now(), key + " kapalı"])
	_prev[key] = on


func _sample(player: Node2D) -> void:
	if _role == "client":
		_edge("own.slime_buyu", bool(player.call("slime_buff_active")))
		_edge("own.boy>1", float(player.call("get_pet_size_mult")) > 1.01)
		_edge("own.ortu", bool(player.call("ghost_cover_active")))
		_edge("own.gorunmez", bool(player.call("is_invisible_now")))
		return
	for rp in get_nodes_in_group("remote_players"):
		var s: Node = rp.get_node_or_null("Slime")
		_edge("pup.slime", s != null)
		if s != null:
			_edge("pup.slime_buyu_klibi", String(s.call("current_clip")).begins_with("cast_"))
		_edge("pup.slime_efekt", rp.get_node_or_null("SlimeSpellFx") != null)
		_edge("pup.slime_buff_gorunusu", rp.get_node_or_null("SlimeBuffFx") != null)
		_edge("pup.boy>1", float(rp.get("_pet_size_mult")) > 1.01)
		var g: Node = rp.get_node_or_null("Hayalet")
		_edge("pup.hayalet", g != null)
		if g != null:
			_edge("pup.hayalet_ortu", bool(g.call("is_covering")))
		_edge("pup.gorunmez", rp.get("is_invisible") == true)


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	_gm.set("selected_pet", "kopek" if _role == "host" else _pet)
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
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player == null:
		_log("HATA Player yok"); quit(1); return
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	if _role == "host":
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
	_log("evcil %s, karakter %s" % [str(_gm.get("selected_pet")), str(_gm.get("selected_char_id"))])
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	_t0 = Time.get_ticks_msec()
	var did: Dictionary = {}
	var total: float = 16.0
	while true:
		paused = false
		var el: float = float(Time.get_ticks_msec() - _t0) / 1000.0
		if el >= total:
			break
		if spawner:
			spawner.set("_spawn_timer", 1.0e9)
		if _role == "client" and el > 3.0 and not did.has("tetik"):
			did["tetik"] = true
			if _pet == "slime":
				player.call("_pet_on_ult_used")
			else:
				player.set("health", float(player.get("max_health")) * 0.2)
			_events.append([_now(), "TETİK " + _pet])
			_first["TETİK"] = _now()
		_sample(player)
		await process_frame
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "pet": _pet, "events": _events, "first": _first}))
	out.close()
	for e in _events:
		_log("olay %6.2f %s" % [float(e[0]), str(e[1])])
	_log("bitti: %d olay" % _events.size())
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


## Açılış sahnesini bitirir (madde 419 / 349 tuzağı; sarjor_audit.gd ile aynı).
func _finish_house_intro() -> void:
	var scene: Node = current_scene
	var intro: Node = scene.get_node_or_null("HouseInterior/HouseIntro") if scene else null
	if intro and intro.has_method("_set_phase"):
		intro.call("_set_phase", 3, 0.0)
	root.get_node("GameManager").set("invasion_pending", false)
