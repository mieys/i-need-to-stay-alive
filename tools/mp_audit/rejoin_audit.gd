extends SceneTree

## Yeniden katılım (rejoin) denetimi: iki gerçek süreç. İstemci 12. sn'de bağlantıyı keser, 2 sn sonra aynı kimlikle (LILSLAYERS_UID) yeniden katılıp HAZIRIM'a basar.
## Host oyunu sürdürür: yaratıklar + yerde duran parçacık/altın/XP drop'ları + (varsa) görev. Yeniden katılan istemcinin gördükleri host'unkilerle karşılaştırılır.
## MP_ROLE=host|client MP_DIR MP_PORT. Sonuç: <rol>.json

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7799
var _nm: Node
var _gm: Node
var _snaps: Array = []
var _events: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _drops() -> Dictionary:
	var out := {}
	for g in ["xp_orbs", "gold_drops", "food_drops", "magnet_drops", "chest_drops", "weapon_shard_drops"]:
		var total: int = 0
		var visual: int = 0
		for n in get_nodes_in_group(g):
			if is_instance_valid(n) and not n.is_queued_for_deletion():
				total += 1
				if bool(n.get_meta("network_spawned", false)):
					visual += 1
		out[g] = [total, visual]
	return out


func _snap(label: String) -> void:
	var enemies := {}
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_meta("network_enemy_id") and e.get("is_dead") != true:
			enemies[str(e.get_meta("network_enemy_id"))] = [snappedf(e.global_position.x, 1.0), snappedf(e.global_position.y, 1.0), snappedf(float(e.get("health")), 1.0)]
	var p: Node = current_scene.get_node_or_null("Player") if current_scene else null
	var wk: Array = []
	if p != null:
		for w in p.owned_weapon_nodes:
			if is_instance_valid(w):
				wk.append(str(w.get_meta("shop_key", "")))
		wk.sort()
	var rp: Node = null
	for r in get_nodes_in_group("remote_players"):
		rp = r
	_snaps.append({"t": Time.get_unix_time_from_system(), "label": label, "enemies": enemies, "drops": _drops(), "wk": wk,
		"team": {"lvl": int(_gm.get("team_level")), "xp": snappedf(float(_gm.get("team_xp")), 1.0), "time": snappedf(float(_gm.get("game_time")), 0.5),
		"gold": int(_gm.get("gold")), "shards": int(_gm.get("weapon_shards")), "kills": int(_gm.get("run_kills")), "items": (_gm.get("owned_items") as Array).size()},
		"puppet": (rp != null and is_instance_valid(rp)), "puppet_wk": (rp._weapon_keys as Array) if rp != null else [],
		"missions": (current_scene.get("_world_event_visuals") as Dictionary).keys() if (current_scene != null and current_scene.get("_world_event_visuals") != null) else [],
		"scene": current_scene.name if current_scene else ""})


func _enter_game(first: bool) -> Node2D:
	await _until(func(): return current_scene != null and current_scene.name == "Main", 60.0)
	if current_scene == null or current_scene.name != "Main":
		return null
	await _wait(2.0)
	if first:
		var ws: Node = _find_by_method(current_scene, "_auto_pick_random_card")
		if ws:
			ws.call("_auto_pick_random_card")
		await _wait(1.0)
		var house: Node = current_scene.get_node_or_null("HouseInterior")
		if house and house.has_method("_do_exit_house"):
			house.call("_do_exit_house")
		await _wait(1.5)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player != null:
		player.set("max_health", 1.0e9)
		player.set("health", 1.0e9)
	return player


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	var epic: bool = OS.get_environment("MP_NET") == "epic"
	var tag: String = OS.get_environment("MP_TAG") if OS.get_environment("MP_TAG") != "" else "MPAudit"
	if _role == "host":
		if epic:
			await _nm.call("host_online", tag, 5)
			if not bool(_nm.get("is_online_session")):
				_log("HATA host_online"); quit(1); return
		elif not _nm.call("host_lan", _port, "Host", 5):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2 and _nm.call("all_players_ready"), 40.0)
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0)
		if epic:
			var eos: Node = root.get_node("EosOnline")
			var found: Dictionary = {}
			var t_search: int = Time.get_ticks_msec()
			while found.is_empty() and Time.get_ticks_msec() - t_search < 40000:
				var lobbies: Array = await eos.call("search_lobbies_async", "Client")
				for lb: Dictionary in lobbies:
					if str(lb.get("host_name", "")) == tag:
						found = lb
				if found.is_empty():
					await _wait(2.0)
			if found.is_empty():
				_log("HATA Epic lobisi bulunamadı (%s)" % tag); quit(1); return
			await _nm.call("join_online", str(found["host_id"]), tag, "Client", 13)
		elif not _nm.call("join_lan", "127.0.0.1", _port, "Client", 13):
			_log("HATA join_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2, 30.0)
		_nm.call("set_local_ready", true)
	var player: Node2D = await _enter_game(true)
	if player == null:
		_log("HATA Main yok"); quit(1); return
	player.call("buy_weapon_copy", "tufek", 2)
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	await _wait(1.0)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	var drop_script: GDScript = load("res://scripts/weapon_shard_drop.gd")
	if _role == "host":
		var roster: Array = spawner.call("_spawnable_roster", 3)
		var remote: Node2D = get_nodes_in_group("remote_players")[0] as Node2D
		var center: Vector2 = (player.global_position + remote.global_position) * 0.5
		var rng := RandomNumberGenerator.new(); rng.seed = 99
		var spawned: int = 0
		var guard: int = 0
		while spawned < 40 and guard < 200:
			guard += 1
			var id: String = roster[rng.randi() % roster.size()]
			spawned += int(spawner.call("debug_spawn_creature", id, 3, 1, center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(300.0, 600.0)))
		## yerde duran ve kimsenin toplamayacağı parçacıklar (iki oyuncudan uzakta)
		for i in range(4):
			drop_script.call("spawn", self, center + Vector2(900.0 + i * 20.0, 900.0), 1)
		_events.append({"e": "host_spawned", "enemies": spawned, "far_shards": 4})
	var t0: int = Time.get_ticks_msec()
	var next_snap: int = 0
	var did: Dictionary = {}
	var total: float = 45.0
	while Time.get_ticks_msec() - t0 < int(total * 1000.0):
		paused = false
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if spawner and is_instance_valid(spawner):
			spawner.set("_spawn_timer", 1.0e9)
		if Time.get_ticks_msec() - t0 >= next_snap:
			next_snap += 1000
			_snap("play")
		if _role == "host" and el > 6.0 and not did.has("mission"):
			did["mission"] = true
			var wem: Node = current_scene.get_node_or_null("WorldEventManager")
			var started: bool = wem != null and bool(wem.call("debug_force_start_mission", "capture_point"))
			_events.append({"t": el, "e": "host_started_mission", "ok": started})
		if el > 3.0 and not did.has("shop"):
			did["shop"] = true
			_gm.set("gold", 1000)
			_gm.call("add_weapon_shards", 20)
			var Logic: GDScript = load("res://scripts/weapon_shop_logic.gd")
			var ok: bool = bool(Logic.call("buy_weapon", player, "arcane"))
			_events.append({"t": el, "e": "shop_buy", "ok": ok, "shards": int(_gm.get("weapon_shards")), "gold": int(_gm.get("gold")), "wk": _snaps[-1]["wk"] if not _snaps.is_empty() else []})
		if _role == "client" and el > 12.0 and not did.has("drop"):
			did["drop"] = true
			await _wait(1.5) ## son anlık görüntü (6 sn'de bir) için pay
			var pre: Dictionary = {"shards": int(_gm.get("weapon_shards")), "gold": int(_gm.get("gold")), "level": int(_gm.get("team_level")), "wk": []}
			for w in player.owned_weapon_nodes:
				if is_instance_valid(w):
					pre["wk"].append(str(w.get_meta("shop_key", "")))
			pre["wk"].sort()
			_events.append({"t": el, "e": "client_drops_connection", "pre": pre})
			_snap("pre_drop")
			_nm.call("disconnect_from_room")
			await _wait(2.0)
			change_scene_to_file("res://scenes/main_menu.tscn")
			await _wait(2.0)
			var joined: bool = false
			if OS.get_environment("MP_NET") == "epic":
				var eos2: Node = root.get_node("EosOnline")
				var found2: Dictionary = {}
				var ts: int = Time.get_ticks_msec()
				while found2.is_empty() and Time.get_ticks_msec() - ts < 40000:
					for lb2: Dictionary in await eos2.call("search_lobbies_async", "Client"):
						if str(lb2.get("host_name", "")) == (OS.get_environment("MP_TAG") if OS.get_environment("MP_TAG") != "" else "MPAudit"):
							found2 = lb2
					if found2.is_empty():
						await _wait(2.0)
				if not found2.is_empty():
					await _nm.call("join_online", str(found2["host_id"]), "MPAudit", "Client", 13)
					joined = true
			else:
				joined = bool(_nm.call("join_lan", "127.0.0.1", _port, "Client", 13))
			if not joined:
				_events.append({"e": "rejoin_join_failed"})
				break
			await _until(func(): return _nm.get("lobby_players").size() >= 2, 20.0)
			_events.append({"e": "rejoin_lobby", "players": _nm.get("lobby_players").size(), "in_progress": bool(_nm.get("_is_game_in_progress"))})
			_nm.call("set_local_ready", true)
			player = await _enter_game(false)
			if player == null:
				_events.append({"e": "rejoin_main_missing", "scene": current_scene.name if current_scene else ""})
				break
			spawner = current_scene.get_node_or_null("EnemySpawner")
			_events.append({"t": float(Time.get_ticks_msec() - t0) / 1000.0, "e": "client_rejoined_main", "shards": int(_gm.get("weapon_shards")), "gold": int(_gm.get("gold"))})
		await process_frame
	await _wait(1.0)
	_snap("end")
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "snaps": _snaps, "events": _events}))
	out.close()
	_log("bitti: %d örnek, olaylar %d" % [_snaps.size(), _events.size()])
	await _wait(4.0)
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
