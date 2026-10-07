extends SceneTree

## Diriltme hakkı sayacı hızlanması denetimi (CLAUDE.md madde 32): iki gerçek süreç (host, istemci; başsız LAN). İstemcinin hakkı 0'a çekilir ve
## öldürülür (kalıcı ölü); host'un oyuncusu cesedin yanında bekler -> istemcinin kalp sayacı 1,8x hızlı akmalı (host'ta VE istemcide gösterilen
## hız/kalan süre), host uzaklaşınca 1,0x'e dönmeli. MP_ROLE=host|client MP_DIR MP_PORT. Sonuç: <rol>.json

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7841
var _nm: Node
var _gm: Node
var _samples: Array = []
var _events: Array = []
var _client_peer: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _player() -> Node2D:
	return current_scene.get_node_or_null("Player") as Node2D if current_scene else null


func _sample(el: float) -> void:
	var p: Node2D = _player()
	var row := {"t": snappedf(el, 0.1), "dead": (p != null and bool(p.get("is_dead"))),
		"lives": int(_gm.call("get_peer_revives", get_multiplayer().get_unique_id())),
		"left": snappedf(float(_gm.call("get_local_revive_regen_left")), 0.01), "rate": snappedf(float(_gm.call("get_local_revive_regen_rate")), 0.01)}
	if _role == "host" and _client_peer > 0:
		row["h_left"] = snappedf(float((_gm.get("_revive_regen_left") as Dictionary).get(_client_peer, -1.0)), 0.01)
		row["h_rate"] = snappedf(float((_gm.get("_revive_regen_rate") as Dictionary).get(_client_peer, 1.0)), 0.01)
		row["h_assist"] = int(_gm.call("revive_assist_count", _client_peer))
	_samples.append(row)


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	if _role == "host":
		if not _nm.call("host_lan", _port, "Host", 5):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2 and _nm.call("all_players_ready"), 40.0)
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0)
		if not _nm.call("join_lan", "127.0.0.1", _port, "Client", 13):
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
	await _wait(1.5)
	var player: Node2D = _player()
	if player == null:
		_log("HATA Player yok"); quit(1); return
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	if _role == "host":
		for rp in get_nodes_in_group("remote_players"):
			_client_peer = int(rp.get("peer_id"))
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
	var t0: int = Time.get_ticks_msec()
	var did: Dictionary = {}
	var next_sample: int = 0
	var corpse_pos: Vector2 = Vector2.ZERO
	while Time.get_ticks_msec() - t0 < 42000:
		paused = false
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		var sp: Node = current_scene.get_node_or_null("EnemySpawner") if current_scene else null
		if sp:
			sp.set("_spawn_timer", 1.0e9)
		if _role == "host" and el > 2.0 and not did.has("zero"):
			## İstemcinin hakkını 0'a çek (host yetkili) ve herkese bildir
			did["zero"] = true
			_gm.get("peer_revives")[_client_peer] = 0
			_nm.sync_revive_consumed.rpc(_client_peer, 0)
			_events.append({"t": el, "e": "client_lives_zeroed", "peer": _client_peer})
		if _role == "client" and el > 4.0 and not did.has("die"):
			did["die"] = true
			player.set("max_health", 5.0)
			player.set("health", 5.0)
			player.call("take_damage", 1.0e9)
			_events.append({"t": el, "e": "client_killed"})
		if _role == "client":
			if bool(player.get("is_dead")) and corpse_pos == Vector2.ZERO:
				corpse_pos = player.global_position
		if _role == "host":
			var rp_dead: bool = false
			for rp in get_nodes_in_group("remote_players"):
				if int(rp.get("peer_id")) == _client_peer and bool(rp.get("is_dead")):
					rp_dead = true
					if not did.has("near") and el > 8.0:
						did["near"] = true
						player.global_position = (rp as Node2D).global_position + Vector2(30.0, 0.0)
						_events.append({"t": el, "e": "host_moves_next_to_corpse"})
					if did.has("near") and el > 24.0 and not did.has("away"):
						did["away"] = true
						player.global_position = (rp as Node2D).global_position + Vector2(900.0, 0.0)
						_events.append({"t": el, "e": "host_walks_away"})
			if did.has("near") and not did.has("away"):
				player.set("health", 1.0e9)
		if Time.get_ticks_msec() - t0 >= next_sample:
			next_sample += 500
			_sample(el)
		await process_frame
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "samples": _samples, "events": _events}))
	out.close()
	_log("bitti: %d örnek" % _samples.size())
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
