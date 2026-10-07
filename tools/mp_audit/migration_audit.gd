extends SceneTree

## HOST DEVRİ denetimi: ÜÇ gerçek süreç (host "host", istemciler "b" ve "c"; başsız LAN). Oyun başlar, herkes bir silah alır, ~14. sn'de
## HOST ölür (MP_KILL=crash: süreç aniden ölür / close: oyundan çıkar = NetworkManager.close_room). Beklenen: sıradaki aday ("b", ilk katılan)
## yeni host olur, "c" ona bağlanıp geri katılım akışından geçer, ikisi de kartlarıyla/silahlarıyla/altınlarıyla kaldığı yerden devam eder ve
## yeni host'un doğurduğu yaratıklar "c"de görünür. MP_ROLE=host|b|c MP_DIR MP_PORT MP_SECS MP_KILL. Sonuç: <rol>.json (migration_compare.py okur).

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7821
var _secs: float = float(OS.get_environment("MP_SECS")) if OS.get_environment("MP_SECS") != "" else 80.0
var _kill: String = OS.get_environment("MP_KILL") if OS.get_environment("MP_KILL") != "" else "crash"
var _nm: Node
var _gm: Node
var _samples: Array = []
var _events: Array = []
var _msgs: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _player() -> Node2D:
	if current_scene == null:
		return null
	return current_scene.get_node_or_null("Player") as Node2D


func _wk(p: Node) -> Array:
	var keys: Array = []
	if p != null and "owned_weapon_nodes" in p:
		for w in p.owned_weapon_nodes:
			if is_instance_valid(w):
				keys.append(str(w.get_meta("shop_key", "")))
	keys.sort()
	return keys


func _sample(el: float) -> void:
	var p: Node2D = _player()
	var enemies: int = 0
	var puppet_enemies: int = 0
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_meta("network_enemy_id") and e.get("is_dead") != true:
			enemies += 1
	_samples.append({"t": snappedf(el, 0.1), "scene": current_scene.name if current_scene else "", "active": bool(_nm.get("is_multiplayer_active")),
		"host": bool(_nm.get("is_host")), "migrating": bool(_nm.call("is_host_migrating")), "peers": get_multiplayer().get_peers().size(),
		"lobby": _nm.get("lobby_players").size(), "count": int(_nm.call("game_player_count")), "wk": _wk(p), "level": int(_gm.get("team_level")),
		"gold": int(_gm.get("gold")), "time": snappedf(float(_gm.get("game_time")), 1.0), "enemies": enemies,
		"remotes": get_nodes_in_group("remote_players").size(), "over": bool(_gm.get("is_game_over")), "pstat": (int(get_multiplayer().multiplayer_peer.get_connection_status()) if get_multiplayer().multiplayer_peer != null else -1),
		"pcls": (get_multiplayer().multiplayer_peer.get_class() if get_multiplayer().multiplayer_peer != null else ""), "uid": int(get_multiplayer().get_unique_id()),
		"mig": ({"status": str(_nm.get("_migration").get("status", "")), "idx": int(_nm.get("_migration").get("idx", -1))} if not (_nm.get("_migration") as Dictionary).is_empty() else {}),
		"roster": (_nm.get("_migration_roster") as Array).map(func(e: Dictionary) -> String: return "%s|%s|%s" % [str(e.get("uid", "")).left(6), str(e.get("addr", "")), str(e.get("eos", "")).left(8)])})


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	_nm.connect("connection_status_changed", func(t: String) -> void: _msgs.append({"t": snappedf(Time.get_ticks_msec() / 1000.0, 0.1), "msg": t}))
	_nm.connect("host_migration_state", func(t: String, d: bool) -> void: _events.append({"e": "migration_state", "text": t, "done": d, "at": snappedf(Time.get_ticks_msec() / 1000.0, 0.1)}))
	var epic: bool = OS.get_environment("MP_NET") == "epic"
	var tag: String = OS.get_environment("MP_TAG") if OS.get_environment("MP_TAG") != "" else "MPMig"
	if _role == "host":
		if epic:
			await _nm.call("host_online", tag, 5)
			if not bool(_nm.get("is_online_session")):
				_log("HATA host_online"); quit(1); return
		elif not _nm.call("host_lan", _port, "Host", 5):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 3 and _nm.call("all_players_ready"), 90.0)
		if not _nm.call("all_players_ready"):
			_log("HATA istemciler gelmedi"); quit(1); return
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0 if _role == "b" else 6.0)
		if epic:
			var eos: Node = root.get_node("EosOnline")
			var found: Dictionary = {}
			var t_search: int = Time.get_ticks_msec()
			while found.is_empty() and Time.get_ticks_msec() - t_search < 60000:
				var lobbies: Array = await eos.call("search_lobbies_async", "Client_" + _role)
				for lb: Dictionary in lobbies:
					if str(lb.get("host_name", "")) == tag:
						found = lb
				if found.is_empty():
					await _wait(2.0)
			if found.is_empty():
				_log("HATA Epic lobisi bulunamadı"); quit(1); return
			await _nm.call("join_online", str(found["host_id"]), tag, "Client_" + _role, 13 if _role == "b" else 2)
		elif not _nm.call("join_lan", "127.0.0.1", _port, "Client_" + _role, 13 if _role == "b" else 2):
			_log("HATA join_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= (2 if _role == "b" else 3), 40.0)
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
	player.set("max_health", 1.0e9)
	player.set("health", 1.0e9)
	## Mağaza yolu (GameManager.owned_weapons'a kayıtlı): doğrudan buy_weapon_copy kaydedilmez, geri katılımda kaybolur (test hatası olurdu).
	_gm.set("gold", 1000)
	_gm.call("add_weapon_shards", 20)
	var Logic: GDScript = load("res://scripts/weapon_shop_logic.gd")
	Logic.call("buy_weapon", player, "arcane" if _role == "b" else "tufek")
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 2, 25.0)
	await _wait(1.0)
	var t0: int = Time.get_ticks_msec()
	var did: Dictionary = {}
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	var next_sample: int = 0
	var pre_wk: Array = _wk(player)
	_events.append({"e": "pre", "wk": pre_wk, "gold": int(_gm.get("gold")), "level": int(_gm.get("team_level"))})
	while Time.get_ticks_msec() - t0 < int(_secs * 1000.0):
		if not bool(_nm.call("is_host_migrating")):
			paused = false ## devir sırasında dünya BİLEREK donuk (NetworkManager); koşucu açılış duraklamasını kaldırırken buna dokunmasın
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if current_scene != null and current_scene.name == "Main":
			var sp: Node = current_scene.get_node_or_null("EnemySpawner")
			if sp:
				sp.set("_spawn_timer", 1.0e9)
			var pl: Node2D = _player()
			if pl:
				pl.set("health", 1.0e9)
				pl.set("max_health", 1.0e9)
			if _role == "host" and not did.has("spawn") and el > 3.0:
				did["spawn"] = true
				var roster: Array = sp.call("_spawnable_roster", 3)
				var center: Vector2 = pl.global_position
				for i in range(12):
					sp.call("debug_spawn_creature", roster[i % roster.size()], 3, 1, center + Vector2.from_angle(float(i) * 0.5) * 320.0)
			## yeni host (devirden sonra) kendi yaratıklarını doğurur - "c" bunları görmeli
			if _role == "b" and bool(_nm.get("is_host")) and not did.has("post_spawn") and pl and el > 20.0:
				var main_ready: bool = _nm.get("_main_ready_peers").size() >= 2 or el > 45.0
				if main_ready:
					did["post_spawn"] = true
					var roster2: Array = sp.call("_spawnable_roster", 3)
					for i in range(10):
						sp.call("debug_spawn_creature", roster2[i % roster2.size()], 3, 1, pl.global_position + Vector2.from_angle(float(i) * 0.6) * 300.0)
					_events.append({"e": "new_host_spawned", "t": el, "wk": _wk(pl)})
		if Time.get_ticks_msec() - t0 >= next_sample:
			next_sample += 500
			_sample(el)
		## ---- HOST ÖLÜR
		if _role == "host" and el > 14.0 and not did.has("die"):
			did["die"] = true
			_events.append({"e": "host_dies", "t": el, "mode": _kill})
			_flush_result()
			if _kill == "crash":
				OS.kill(OS.get_process_id())
			else:
				_nm.call("close_room")
				await _wait(1.0)
				quit()
				return
		await process_frame
	_events.append({"e": "end", "wk": _wk(_player()), "gold": int(_gm.get("gold")), "level": int(_gm.get("team_level"))})
	_flush_result()
	_log("bitti: %d örnek" % _samples.size())
	await _wait(2.0)
	quit()


func _flush_result() -> void:
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "samples": _samples, "events": _events, "msgs": _msgs}))
	out.close()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		if not bool(_nm.call("is_host_migrating")):
			paused = false ## devir sırasında dünya BİLEREK donuk (NetworkManager); koşucu açılış duraklamasını kaldırırken buna dokunmasın
		await process_frame


func _until(cond: Callable, timeout: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(timeout * 1000.0):
		if not bool(_nm.call("is_host_migrating")):
			paused = false ## devir sırasında dünya BİLEREK donuk (NetworkManager); koşucu açılış duraklamasını kaldırırken buna dokunmasın
		await process_frame


func _find_by_method(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var r: Node = _find_by_method(c, method)
		if r:
			return r
	return null
