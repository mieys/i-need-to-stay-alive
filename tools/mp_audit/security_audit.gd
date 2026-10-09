extends SceneTree

## Güvenlik/sağlamlık denetimi: ÜÇ gerçek süreç (host, istemci, yabancı). Başsız LAN.
##  - host + istemci oyunu başlatır. İstemci host'a SAHTE "host-only" RPC'ler yollar (sync_game_over / sync_team_xp / broadcast_victory):
##    host durumu DEĞİŞMEMELİ (gönderen kontrolü, NetworkManager._from_host).
##  - YABANCI (oyunun oyuncusu değil) başlamış odaya bağlanır: "Bu oyun başlamış" mesajı alıp bağlantısı kesilmeli; o sırada
##    host'un game_player_count()'u 2 kalmalı ve doğan yaratığın canı istemcideki kopyayla AYNI olmalı (hayalet oyuncu canı şişirmemeli).
## MP_ROLE=host|client|stranger MP_DIR MP_PORT. Sonuç: <rol>.json (run_audit.ps1 -Mode security).

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7801
var _nm: Node
var _gm: Node
var _events: Array = []
var _msgs: Array = []
var _samples: Array = []
var _seen: Dictionary = {} ## network_enemy_id -> ilk görüldüğü andaki maks can/kalkan/oyuncu sayısı


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	_nm.connect("connection_status_changed", func(t: String) -> void: _msgs.append({"t": snappedf(Time.get_ticks_msec() / 1000.0, 0.1), "msg": t}))
	if _role == "stranger":
		await _run_stranger()
		return
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
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player == null:
		_log("HATA Player yok"); quit(1); return
	player.set("max_health", 1.0e9)
	player.set("health", 1.0e9)
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if _role == "host":
		FileAccess.open(_dir.path_join("game_started.flag"), FileAccess.WRITE).close()
	var t0: int = Time.get_ticks_msec()
	var did: Dictionary = {}
	var base_level: int = int(_gm.get("team_level"))
	var enemy_ids: Array = []
	while Time.get_ticks_msec() - t0 < 36000:
		paused = false
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if spawner:
			spawner.set("_spawn_timer", 1.0e9)
		if _role == "host" and float(player.get("health")) < 1.0e9 - 5000.0:
			_events.append({"t": snappedf(el, 0.1), "e": "HOST_PLAYER_TOOK_FORGED_DAMAGE", "amount": snappedf(1.0e9 - float(player.get("health")), 1.0)})
		player.set("health", 1.0e9)
		## ---- host: yabancı lobide İKEN (dosya bayrağı) ve kovulduktan SONRA birer test yaratığı doğurur
		if _role == "host":
			if not did.has("e1") and FileAccess.file_exists(_dir.path_join("stranger_in_lobby.flag")):
				did["e1"] = true
				enemy_ids.append(_spawn_probe(spawner, player, "with_stranger"))
			if not did.has("e2") and el > 24.0:
				did["e2"] = true
				enemy_ids.append(_spawn_probe(spawner, player, "after_kick"))
		## ---- istemci: sahte host-only RPC'ler
		if _role == "client" and el > 4.0 and not did.has("forge"):
			did["forge"] = true
			_nm.sync_game_over.rpc_id(1)
			_nm.sync_team_xp.rpc_id(1, 99999.0, 5.0, 77)
			_nm.broadcast_victory.rpc_id(1, 123.0)
			_nm.sync_game_time.rpc_id(1, 99999.0)
			_events.append({"t": el, "e": "forged_host_rpcs_sent"})
		## ---- istemci (2026-10-09): host'a SAHTE hasar + SAHTE ölüm/vfx bildirimi (forward_damage_to_peer, forward_special_damage_to_peer, broadcast_enemy_vfx death_state) - hepsi reddedilmeli
		if _role == "client" and el > 30.0 and not did.has("forge2"):
			did["forge2"] = true
			_nm.forward_damage_to_peer.rpc_id(1, 99999.0, 0, false)
			_nm.forward_special_damage_to_peer.rpc_id(1, 99999.0, 0, "minotaur")
			for e2 in get_nodes_in_group("enemies"):
				if is_instance_valid(e2) and e2.has_meta("network_enemy_id"):
					_nm.broadcast_enemy_vfx.rpc_id(1, int(e2.get_meta("network_enemy_id")), "death_state", {})
			_events.append({"t": el, "e": "forged_damage_and_death_state_sent"})
		for e in get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.has_meta("network_enemy_id"):
				var nid: int = int(e.get_meta("network_enemy_id"))
				if not _seen.has(nid):
					_seen[nid] = {"max_health": snappedf(float(e.get("max_health")), 0.1), "shield_max": snappedf(float(e.get("item_shield_max")), 0.1),
						"pc_meta": int(e.get_meta("mp_player_count", -1)), "game_players_now": int(_nm.call("game_player_count")), "t": snappedf(el, 0.1)}
		## ---- örnekler
		if int(el * 2.0) != int(did.get("last_sample", -1)):
			did["last_sample"] = int(el * 2.0)
			_samples.append({"t": snappedf(el, 0.1), "count": int(_nm.call("game_player_count")), "lobby": _nm.get("lobby_players").size(),
				"peers": get_multiplayer().get_peers().size(), "level": int(_gm.get("team_level")), "xp": snappedf(float(_gm.get("team_xp")), 1.0),
				"game_over": bool(_gm.get("is_game_over")) if _gm.get("is_game_over") != null else false, "time": snappedf(float(_gm.get("game_time")), 1.0),
				"victory": bool(_gm.get("victory_reached")) if _gm.get("victory_reached") != null else false})
		await process_frame
	var probes := {}
	for e3 in get_nodes_in_group("enemies"):
		if is_instance_valid(e3) and e3.has_meta("probe_label"):
			probes[str(e3.get_meta("probe_label"))] = {"is_dead": bool(e3.get("is_dead"))}
	var res := {"role": _role, "samples": _samples, "events": _events, "msgs": _msgs, "enemies": _seen, "base_level": base_level, "probe_ids": enemy_ids, "probes": probes}
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(res)); out.close()
	_log("bitti: %d örnek" % _samples.size())
	await _wait(2.0)
	quit()


func _spawn_probe(spawner: Node, player: Node2D, label: String) -> int:
	var pos: Vector2 = player.global_position + Vector2(260.0, 0.0)
	## Bilinen tek tür + kademe: iki test yaratığının canı (aynı oyuncu sayısıyla) bire bir aynı olmalı.
	var before: Array = get_nodes_in_group("enemies").duplicate()
	var n: int = int(spawner.call("debug_spawn_creature", "rat1", 3, 1, pos))
	for e in get_nodes_in_group("enemies"):
		if not before.has(e) and is_instance_valid(e):
			e.set_meta("probe_label", label)
			return int(e.get_meta("network_enemy_id", 0))
	return n


func _run_stranger() -> void:
	## Oyun başlayana kadar bekle, sonra (oyun başladıktan SONRA) bağlan.
	await _until(func(): return FileAccess.file_exists(_dir.path_join("game_started.flag")), 90.0)
	await _wait(3.0)
	if not _nm.call("join_lan", "127.0.0.1", _port, "Yabanci", 1):
		_log("HATA join_lan"); quit(1); return
	var t0: int = Time.get_ticks_msec()
	await _until(func(): return _nm.get("lobby_players").size() >= 1, 20.0)
	FileAccess.open(_dir.path_join("stranger_in_lobby.flag"), FileAccess.WRITE).close()
	_nm.call("set_local_ready", true)
	var disconnected_at: float = -1.0
	while Time.get_ticks_msec() - t0 < 14000:
		paused = false
		if disconnected_at < 0.0 and not bool(_nm.get("is_multiplayer_active")):
			disconnected_at = float(Time.get_ticks_msec() - t0) / 1000.0
		await process_frame
	var res := {"role": "stranger", "msgs": _msgs, "disconnected_at": disconnected_at, "still_active": bool(_nm.get("is_multiplayer_active")),
		"blocked_flag": bool(_nm.call("is_join_blocked_by_game"))}
	var out := FileAccess.open(_dir.path_join("stranger.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(res)); out.close()
	_log("bitti: kopma %.1f sn, mesajlar %d" % [disconnected_at, _msgs.size()])
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
