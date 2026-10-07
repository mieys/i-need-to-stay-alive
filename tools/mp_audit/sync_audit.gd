extends SceneTree

## Genel çok oyunculu senkron denetimi: iki gerçek süreç (host = Assasin, istemci = Vampir), başsız LAN.
## Her 1 sn'de iki taraf da kendi "gerçek" durumunu VE diğer oyuncunun kuklasında gördüğünü, yaratıkları ve drop sayılarını kaydeder;
## Python (sync_audit_compare.py) zamana göre eşleyip fark raporu çıkarır. MP_ROLE=host|client MP_DIR MP_PORT MP_SECS MP_N

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7797
var _secs: float = float(OS.get_environment("MP_SECS")) if OS.get_environment("MP_SECS") != "" else 40.0
var _n: int = int(OS.get_environment("MP_N")) if OS.get_environment("MP_N") != "" else 70
var _nm: Node
var _gm: Node
var _snaps: Array = []
var _events: Array = []
var _kills: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _wk(p: Node) -> Array:
	var keys: Array = []
	if "owned_weapon_nodes" in p:
		for w in p.owned_weapon_nodes:
			if is_instance_valid(w):
				keys.append(str(w.get_meta("shop_key", "")))
	elif "_weapon_keys" in p:
		keys = (p._weapon_keys as Array).duplicate()
	keys.sort()
	return keys


func _pl(p: Node, remote: bool) -> Dictionary:
	if p == null or not is_instance_valid(p):
		return {}
	var anim_name: String = ""
	if p.get("anim") != null:
		anim_name = str(p.anim.animation)
	return {"pos": [snappedf(p.global_position.x, 0.1), snappedf(p.global_position.y, 0.1)], "anim": anim_name,
		"hp": snappedf(float(p.get("health")), 1.0), "max": snappedf(float(p.get("max_health")), 1.0),
		"sh": snappedf(float(p.get("item_shield_hp")), 1.0), "shm": snappedf(float(p.get("item_shield_max")), 1.0),
		"wk": _wk(p), "indoors": bool(p.get("is_indoors")), "inv": bool(p.get("is_invisible")),
		"downed": bool(p.get("is_downed")), "dead": bool(p.get("is_dead"))}


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


var _bytes_sent: int = 0
var _bytes_recv: int = 0
var _pk_sent: int = 0
var _pk_recv: int = 0


func _net_stats() -> void:
	var mp: MultiplayerPeer = get_multiplayer().multiplayer_peer
	if mp is ENetMultiplayerPeer:
		var h: ENetConnection = (mp as ENetMultiplayerPeer).host
		if h != null:
			_bytes_sent += int(h.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA))
			_pk_sent += int(h.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS))
			_bytes_recv += int(h.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA))
			_pk_recv += int(h.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS))


func _snap(player: Node) -> void:
	_net_stats()
	var rp: Node = null
	for r in get_nodes_in_group("remote_players"):
		rp = r
	var enemies := {}
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_meta("network_enemy_id"):
			enemies[str(e.get_meta("network_enemy_id"))] = [snappedf(e.global_position.x, 0.1), snappedf(e.global_position.y, 0.1),
				snappedf(float(e.get("health")), 1.0), bool(e.get("is_dead"))]
	_snaps.append({"t": Time.get_unix_time_from_system(), "own": _pl(player, false), "pup": _pl(rp, true), "enemies": enemies,
		"drops": _drops(), "team": {"lvl": int(_gm.get("team_level")), "xp": snappedf(float(_gm.get("team_xp")), 1.0),
		"time": snappedf(float(_gm.get("game_time")), 0.5), "gold": int(_gm.get("gold")), "shards": int(_gm.get("weapon_shards")),
		"kills": int(_gm.get("run_kills")), "items": (_gm.get("owned_items") as Array).size()}})


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
		if not _nm.call("all_players_ready"):
			_log("HATA istemci gelmedi"); quit(1); return
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
	await _until(func(): return current_scene != null and current_scene.name == "Main", 40.0)
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
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player == null:
		_log("HATA Player yok"); quit(1); return
	player.set("max_health", 1.0e9)
	player.set("health", 1.0e9)
	player.call("buy_weapon_copy", "tufek", 2)
	if _role == "client":
		var p: Vector2 = player.global_position + Vector2(300, 0)
		for i in 20:
			if not _gm.call("is_position_blocked_by_walls", p):
				break
			p += Vector2(0, 32)
		player.global_position = p
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	await _wait(1.0)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	var drop_script: GDScript = load("res://scripts/weapon_shard_drop.gd")
	if _role == "host":
		_gm.connect("enemy_died", func(_p: Vector2) -> void: _kills += 1)
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
	var t0: int = Time.get_ticks_msec()
	var next_snap: int = 0
	var did: Dictionary = {}
	while Time.get_ticks_msec() - t0 < int(_secs * 1000.0):
		paused = false
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if spawner:
			spawner.set("_spawn_timer", 1.0e9)
		player.set("health", 1.0e9)
		if Time.get_ticks_msec() - t0 >= next_snap:
			next_snap += 1000
			_snap(player)
		## --- senaryo (her olay bir kez, kendi tarafında)
		if el > 3.0 and not did.has("shop"):
			did["shop"] = true
			_gm.set("gold", 1000)
			_gm.call("add_weapon_shards", 20)
			var Logic: GDScript = load("res://scripts/weapon_shop_logic.gd")
			var ok: bool = bool(Logic.call("buy_weapon", player, "arcane"))
			_events.append({"t": el, "e": "shop_buy_arcane", "ok": ok, "shards_after": int(_gm.get("weapon_shards")), "gold_after": int(_gm.get("gold"))})
		player.set("item_shield_max", 2000.0)
		if el > 5.0 and el < 36.0:
			if _role == "host":
				if int(el) % 5 == 0 and not did.has("q%d" % int(el)):
					did["q%d" % int(el)] = true
					player.call("_try_assasin_dash2")
					_events.append({"t": el, "e": "assasin_Q", "crit_active": bool(player.call("assasin_guaranteed_crit_active"))})
				if el > 8.0 and not did.has("e"):
					did["e"] = true
					player.set("item_shield_hp", 2000.0)
					player.call("_activate_skill2")
					_events.append({"t": el, "e": "assasin_E", "state": str(player.get("skill2_state"))})
				if el > 17.0 and not did.has("r"):
					did["r"] = true
					player.set("item_shield_hp", 2000.0)
					player.call("_activate_skill3")
					_events.append({"t": el, "e": "assasin_R", "state": str(player.get("skill3_state"))})
				if el > 14.0 and not did.has("shards"):
					did["shards"] = true
					var remote2: Node2D = get_nodes_in_group("remote_players")[0] as Node2D
					for i in range(3):
						drop_script.call("spawn", self, remote2.global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4)), 1)
					_events.append({"t": el, "e": "spawn_3_shards_on_client"})
			else:
				if int(el) % 4 == 0 and not did.has("vq%d" % int(el)):
					did["vq%d" % int(el)] = true
					player.set("item_shield_hp", 2000.0)
					player.call("_activate_skill")
					_events.append({"t": el, "e": "vampir_Q", "state": str(player.get("skill_state")), "shield": snappedf(float(player.get("item_shield_hp")), 1.0)})
				if el > 10.0 and not did.has("ve"):
					did["ve"] = true
					player.call("_activate_skill2")
					_events.append({"t": el, "e": "vampir_E_bat", "state": str(player.get("skill2_state"))})
				if el > 20.0 and not did.has("vr"):
					did["vr"] = true
					player.call("_activate_skill3")
					_events.append({"t": el, "e": "vampir_R", "state": str(player.get("skill3_state"))})
		await process_frame
	_net_stats()
	var res := {"role": _role, "snaps": _snaps, "events": _events, "kills": _kills, "net": {"sent": _bytes_sent, "recv": _bytes_recv, "pk_sent": _pk_sent, "pk_recv": _pk_recv}}
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(res)); out.close()
	_log("bitti: %d örnek, olaylar %d, öldürme %d" % [_snaps.size(), _events.size(), _kills])
	await _wait(5.0)
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
