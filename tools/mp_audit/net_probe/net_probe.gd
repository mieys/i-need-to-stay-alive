extends SceneTree

## AĞ SONDASI (madde 349, 2026-10-21): iki gerçek başsız süreç (host + istemci, LAN/ENet), isteğe bağlı UDP vekil (gecikme/jitter/kayıp).
## Her 100 ms'de: yaratık konumları (host gerçeği vs istemcide görünen), oyuncu kuklaları, kare süresi/fizik adımı, ENet bayt/paket, senkron turu;
## probe_node.gd ile oyunun kendi güvenilir/güvenilmez trafiğiyle birlikte zaman damgalı ping (tek yön gecikme, kayıp, sıra bozulması).
## Çalıştırma: tools/mp_audit/net_probe/run_net_probe.ps1 (rapor: net_probe_report.py). Açılış sahnesi (HouseIntro) atlanır -
## yoksa GameManager.invasion_pending enemy_spawner._process'i (yaratık senkronu dahil) hiç çalıştırmaz (madde 313).
## Ortam: MP_ROLE=host|client MP_DIR MP_PORT MP_JOIN_PORT MP_SECS MP_N MP_FPS (Engine.max_fps) MP_STEPS (max_physics_steps_per_frame) MP_FIGHT=1 (3 silah)
var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7797
var _join_port: int = int(OS.get_environment("MP_JOIN_PORT")) if OS.get_environment("MP_JOIN_PORT") != "" else _port
var _secs: float = float(OS.get_environment("MP_SECS")) if OS.get_environment("MP_SECS") != "" else 25.0
var _n: int = int(OS.get_environment("MP_N")) if OS.get_environment("MP_N") != "" else 100
var _nm: Node
var _gm: Node
var _pn: Node


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("PROBE[%s] %s" % [_role, s])


func _run() -> void:
	await process_frame
	var cap: int = int(OS.get_environment("MP_FPS")) if OS.get_environment("MP_FPS") != "" else 0
	if cap > 0:
		Engine.max_fps = cap
	var steps: int = int(OS.get_environment("MP_STEPS")) if OS.get_environment("MP_STEPS") != "" else 0
	if steps > 0:
		Engine.max_physics_steps_per_frame = steps
	var gs := GDScript.new()
	gs.source_code = FileAccess.get_file_as_string("res://tools/mp_audit/net_probe/probe_node.gd")
	var rl: Error = gs.reload()
	_pn = Node.new()
	_pn.set_script(gs)
	_pn.name = "ProbeNode"
	root.add_child(_pn)
	_log("probe node: reload=%d has_rpc=%s" % [rl, str(_pn.has_method("send_pair"))])
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	if _role == "host":
		if not _nm.call("host_lan", _port, "Host", 5):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2 and _nm.call("all_players_ready"), 90.0)
		if not _nm.call("all_players_ready"):
			_log("HATA istemci gelmedi"); quit(1); return
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0)
		if not _nm.call("join_lan", "127.0.0.1", _join_port, "Client", 13):
			_log("HATA join_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2, 90.0)
		_nm.call("set_local_ready", true)
	await _until(func(): return current_scene != null and current_scene.name == "Main", 90.0)
	if current_scene == null or current_scene.name != "Main":
		_log("HATA Main yok"); quit(1); return
	await _wait(1.5)
	var ws: Node = _find_by_method(current_scene, "_auto_pick_random_card")
	if ws:
		ws.call("_auto_pick_random_card")
	await _wait(1.0)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(1.5)
	var intro: Node = current_scene.get_node_or_null("HouseInterior/HouseIntro")
	if intro == null:
		intro = _find_by_method(current_scene, "_host_advance")
	if intro:
		intro.call("_set_phase", 3, 0.0)
	_gm.set("invasion_pending", false)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player == null:
		_log("HATA Player yok"); quit(1); return
	player.set("max_health", 1.0e9)
	player.set("health", 1.0e9)
	var base: Vector2 = player.global_position
	if _role == "client":
		var p: Vector2 = base + Vector2(300, 0)
		for i in 20:
			if not _gm.call("is_position_blocked_by_walls", p):
				break
			p += Vector2(0, 32)
		base = p
		player.global_position = base
	if OS.get_environment("MP_FIGHT") == "1":
		player.call("buy_weapon_copy", "tufek", 2)
		player.call("buy_weapon_copy", "fire_staff", 2)
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 30.0)
	await _wait(1.0)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if _role == "host":
		var roster: Array = spawner.call("_spawnable_roster", 3)
		var remote: Node2D = get_nodes_in_group("remote_players")[0] as Node2D
		var center: Vector2 = (player.global_position + remote.global_position) * 0.5
		var rng := RandomNumberGenerator.new(); rng.seed = 4242
		var spawned: int = 0
		var guard: int = 0
		while spawned < _n and guard < _n * 4:
			guard += 1
			var id: String = roster[rng.randi() % roster.size()]
			var at: Vector2 = center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(250.0, 420.0)
			spawned += int(spawner.call("debug_spawn_creature", id, 3, 1, at))
		_log("yaratık doğdu: %d" % spawned)
	await _wait(5.0)
	var samples: Array = []
	var t0: int = Time.get_ticks_msec()
	var next_s: int = 0
	var last_us: int = Time.get_ticks_usec()
	var max_dt: float = 0.0
	var frames: int = 0
	var next_ping: int = 0
	var radius: float = 120.0
	var omega: float = 0.8 ## rad/sn -> ~96 px/sn çevresel hız (oyuncu yürüyüşü civarı)
	while Time.get_ticks_msec() - t0 < int(_secs * 1000.0):
		paused = false
		if spawner:
			spawner.set("_spawn_timer", 1.0e9)
		player.set("health", 1.0e9)
		## oyuncuyu dairesel gezdir (konum paketi gerçek hareketle gitsin)
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		var target: Vector2 = base + Vector2(cos(el * omega), sin(el * omega)) * radius
		if not _gm.call("is_position_blocked_by_walls", target):
			player.global_position = target
		if Time.get_ticks_msec() - t0 >= next_ping:
			next_ping += 50
			var peer_id: int = 1
			if _role == "host":
				peer_id = 0
				for pid in _nm.get("lobby_players").keys():
					if int(pid) != 1:
						peer_id = int(pid)
			if peer_id > 0:
				_pn.call("send_pair", peer_id)
		var now_us: int = Time.get_ticks_usec()
		var dt: float = float(now_us - last_us) / 1000.0
		last_us = now_us
		max_dt = maxf(max_dt, dt)
		frames += 1
		if Time.get_ticks_msec() - t0 >= next_s:
			next_s += 100
			var en := {}
			for e in get_nodes_in_group("enemies"):
				if is_instance_valid(e) and e.has_meta("network_enemy_id") and e.get("is_dead") != true:
					en[int(e.get_meta("network_enemy_id"))] = [snappedf(e.global_position.x, 0.1), snappedf(e.global_position.y, 0.1)]
			var rp: Node2D = null
			for r in get_nodes_in_group("remote_players"):
				rp = r as Node2D
			var bs: int = 0
			var bp: int = 0
			var br: int = 0
			var bpr: int = 0
			var mp: MultiplayerPeer = get_multiplayer().multiplayer_peer
			if mp is ENetMultiplayerPeer:
				var hh: ENetConnection = (mp as ENetMultiplayerPeer).host
				if hh != null:
					bs = int(hh.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA))
					bp = int(hh.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS))
					br = int(hh.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA))
					bpr = int(hh.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS))
			var tick_h: int = int(spawner.get("_far_tier_tick")) if _role == "host" else -1
			var tick_c: int = int(spawner.get("_enemy_sync_last_tick")) if _role != "host" else -1
			samples.append({"pf": Engine.get_physics_frames(), "gt": snappedf(float(_gm.get("game_time")), 0.01), "bs": bs, "bp": bp, "br": br, "bpr": bpr, "u": Time.get_unix_time_from_system(), "fr": frames, "mx": snappedf(max_dt, 0.1),
				"n": en.size(), "th": tick_h, "tc": tick_c,
				"own": [snappedf(player.global_position.x, 0.1), snappedf(player.global_position.y, 0.1)],
				"pup": ([snappedf(rp.global_position.x, 0.1), snappedf(rp.global_position.y, 0.1)] if rp else []),
				"en": en})
			frames = 0
			max_dt = 0.0
		await process_frame
	var cost := {}
	var last_extra: Variant = current_scene.get("_last_sent_extra_state")
	if last_extra is Dictionary:
		cost["extra_state_bytes"] = var_to_bytes(last_extra).size()
		cost["extra_state_keys"] = (last_extra["extra"] as Dictionary).size() if (last_extra as Dictionary).has("extra") else 0
	if _role == "client" and spawner:
		var Codec: GDScript = load("res://scripts/enemy_sync_codec.gd")
		var states: Array = []
		for e in get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.has_meta("network_enemy_id") and e.get("is_dead") != true:
				states.append([int(e.get_meta("network_enemy_id")), e.global_position, false, float(e.get("health")), 0.0, false, 0, 0])
		var packets: Array = []
		for i in range(0, states.size(), 40):
			packets.append(Codec.call("encode", 1, states.slice(i, i + 40)))
		var tick0: int = int(spawner.get("_enemy_sync_last_tick")) + 1000
		var reps: int = 50
		var us0: int = Time.get_ticks_usec()
		for r in reps:
			var tk: int = (tick0 + r) & 0xFFFF
			for pk in packets:
				spawner.call("_sync_enemy_positions", tk, pk)
		cost["client_apply_ms_per_tick"] = float(Time.get_ticks_usec() - us0) / 1000.0 / float(reps)
		cost["client_apply_states"] = states.size()
	var lat := {"sent_rel": int(_pn.get("sent_rel")), "sent_unr": int(_pn.get("sent_unr")), "rel": _pn.get("rel_lat"), "unr": _pn.get("unr_lat"), "sent_chan": int(_pn.get("sent_chan")), "chan": _pn.get("chan_lat")}
	var res := {"role": _role, "n": _n, "samples": samples, "cost": cost, "lat": lat}
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(res)); out.close()
	_log("bitti: %d örnek %s" % [samples.size(), str(cost)])
	await _wait(3.0)
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
