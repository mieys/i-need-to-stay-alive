extends SceneTree

## BOSS YAKALAMA (geç katılan / yeniden katılan oyuncu) denetimi - Minotaur (K3) + Yeraltı Canavarı (K5), CLAUDE.md madde 40-41. Üç süreç değil, İKİ gerçek süreç (host + istemci, başsız LAN):
## host iki bossu da doğurur (Yeraltı Canavarı uzuv çıkarmaya başlar), istemci 14. sn'de bağlantıyı keser, 2 sn sonra aynı kimlikle (LILSLAYERS_UID) yeniden katılır.
## 46. sn'de host bir bayrak dosyası yazar; İKİ taraf da bayrağı görünce AYNI ANDA bir anlık görüntü alır: her boss'un statları/canı/kalkanı/konumu + her uzvun (ağ kimliğiyle)
## konum/poz/tür/can bilgisi. boss_catchup_audit_compare.py kümeleri karşılaştırır. MP_ROLE=host|client MP_DIR MP_PORT. Sonuç: <rol>.json

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7881
var _nm: Node
var _gm: Node
var _snaps: Array = []
var _events: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _snap(label: String) -> void:
	var bosses := {}
	var limbs := {}
	for e in get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true or not e.has_meta("network_enemy_id"):
			continue
		var nid: String = str(int(e.get_meta("network_enemy_id")))
		var cid: String = str(e.get_meta("creature_id", ""))
		if e.is_in_group("boss"):
			bosses[nid] = {"id": cid, "max_health": float(e.get("max_health")), "health": float(e.get("health")), "shield_max": float(e.get("item_shield_max")),
					"shield": float(e.get("item_shield_hp")), "protection": float(e.get("shield_protection")), "x": snappedf(e.global_position.x, 1.0), "y": snappedf(e.global_position.y, 1.0),
					"is_boss": bool(e.get("is_boss")), "pose": int(e.get("_pose_override")), "tier": int(e.get("_current_tier"))}
		elif cid == "sandworm1":
			limbs[nid] = [snappedf(e.global_position.x, 0.5), snappedf(e.global_position.y, 0.5), int(e.get("_pose_override")), int(e.get("kind")), snappedf(float(e.get("health")), 1.0),
					bool(e.has_meta(&"untargetable"))]
	_snaps.append({"label": label, "t": Time.get_unix_time_from_system(), "bosses": bosses, "limbs": limbs,
			"team": {"game_time": snappedf(float(_gm.get("game_time")), 0.5)}})


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
	var player: Node2D = await _enter_game(true)
	if player == null:
		_log("HATA Main yok"); quit(1); return
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	await _wait(1.0)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	var t0: int = Time.get_ticks_msec()
	var did: Dictionary = {}
	var total: float = 60.0
	while Time.get_ticks_msec() - t0 < int(total * 1000.0):
		paused = false
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if spawner and is_instance_valid(spawner):
			spawner.set("_spawn_timer", 1.0e9)
		if _role == "host" and el > 3.0 and not did.has("boss") and spawner:
			did["boss"] = true
			spawner.set("_boss_tiers_spawned", {3: true, 5: true})
			var a: Array = spawner.call("_spawn_boss_group", ["underground1"], 5)
			var b: Array = spawner.call("_spawn_boss_group", ["minotaur1"], 3)
			_events.append({"t": el, "e": "bosses_spawned", "underground": a.size(), "minotaur": b.size()})
		if _role == "host" and el > 46.0 and not did.has("flag"):
			did["flag"] = true
			FileAccess.open(_dir.path_join("snap.flag"), FileAccess.WRITE).close()
		if el > 46.0 and not did.has("snap") and FileAccess.file_exists(_dir.path_join("snap.flag")):
			did["snap"] = true
			_snap("sync_end")
		## İki oyuncu da dönüşümlü yürür: uzuvlar yolunu keser, Minotaur kovalar.
		for act in ["move_right", "move_left", "move_down", "move_up"]:
			Input.action_release(act)
		if el > 5.0 and player != null and is_instance_valid(player):
			var phase: int = int((el - 5.0 + (0.0 if _role == "host" else 1.7)) / 2.4) % 6
			var acts: Array = ["move_right", "move_right", "move_down", "move_left", "move_left", "move_up"]
			Input.action_press(acts[phase])
			player.set("health", 1.0e9)
		if _role == "client" and el > 14.0 and not did.has("drop"):
			did["drop"] = true
			await _wait(1.0)
			for act2 in ["move_right", "move_left", "move_down", "move_up"]:
				Input.action_release(act2)
			_snap("pre_drop")
			_events.append({"t": el, "e": "client_drops_connection"})
			_nm.call("disconnect_from_room")
			await _wait(2.0)
			change_scene_to_file("res://scenes/main_menu.tscn")
			await _wait(2.0)
			var joined: bool = bool(_nm.call("join_lan", "127.0.0.1", _port, "Client", 13))
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
			_events.append({"t": float(Time.get_ticks_msec() - t0) / 1000.0, "e": "client_rejoined_main"})
		await process_frame
	for act3 in ["move_right", "move_left", "move_down", "move_up"]:
		Input.action_release(act3)
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "snaps": _snaps, "events": _events}))
	out.close()
	_log("bitti: %d anlık görüntü, %d olay" % [_snaps.size(), _events.size()])
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
