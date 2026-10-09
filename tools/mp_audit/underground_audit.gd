extends SceneTree

## YERALTI CANAVARI (Kademe 5 bossu, CLAUDE.md madde 41) çok oyunculu denetimi: iki gerçek süreç (host = Assasin, istemci = Vampir; başsız LAN, GERÇEK Main + gerçek harita).
## Host gerçek bossu doğurur; iki oyuncu dönüşümlü yürür (uzuvlar yollarını keser), silahlar uzuvlara otomatik ateş eder (hasar bossun havuzundan düşer).
## HER İKİ tarafta her 0,25 sn: bossun can + kalkanı, yüzeydeki uzuv sayısı, asit damlası düğümleri, kendi oyuncunun can+kalkanı/konumu; her 0,5 sn: her uzvun (ağ kimliğiyle)
## konum / poz / tür / can bilgisi. underground_audit_compare.py karşılaştırır. MP_ROLE=host|client MP_DIR MP_PORT MP_SECS. Sonuç: <rol>.json

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7871
var _secs: float = float(OS.get_environment("MP_SECS")) if OS.get_environment("MP_SECS") != "" else 70.0
var _nm: Node
var _gm: Node
var _samples: Array = [] ## [t, boss_hp, boss_shield, n_limbs, n_acid, px, py, player_pool]
var _limb_log: Array = [] ## [t, {net_id: [x, y, pose, kind, health]}]
var _events: Array = []
var _stress: bool = OS.get_environment("MP_STRESS") == "1" ## 1: iki oyuncu da uzuvlara doğrudan hasar basar (parçalanma/geri dönüş/boss ölümü senkronu)


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _player() -> Node2D:
	return current_scene.get_node_or_null("Player") as Node2D if current_scene else null


func _boss() -> Node2D:
	for e in get_nodes_in_group("boss"):
		if is_instance_valid(e):
			return e as Node2D
	return null


func _limbs() -> Array:
	var out: Array = []
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and str(e.get_meta("creature_id", "")) == "sandworm1" and e.get("is_dead") != true:
			out.append(e)
	return out


func _acid_count() -> int:
	var n: int = 0
	if current_scene == null:
		return 0
	for c in current_scene.get_children():
		var sc: Variant = c.get_script()
		if sc != null and str((sc as Script).resource_path).ends_with("worm_acid.gd"):
			n += 1
	return n


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
	player.set("max_health", 1.0e7)
	player.set("health", 1.0e7)
	if _role == "host":
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
		await _wait(1.0)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var t0: int = Time.get_ticks_msec()
	var did: Dictionary = {}
	var last_pool: float = float(player.get("health")) + float(player.get("item_shield_hp"))
	var next_limb_log: float = 0.0
	var next_sample: float = 0.0
	var wall_ever: bool = false
	var next_hit: float = 12.0
	while Time.get_ticks_msec() - t0 < int(_secs * 1000.0):
		paused = false
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if spawner:
			spawner.set("_spawn_timer", 1.0e9)
		var pool_now: float = float(player.get("health")) + float(player.get("item_shield_hp"))
		if pool_now < last_pool - 0.5:
			_events.append({"t": snappedf(el, 0.01), "e": "player_damaged", "amount": snappedf(last_pool - pool_now, 0.1)})
		last_pool = pool_now
		if float(player.get("health")) < 9.0e6:
			player.set("health", 1.0e7)
			last_pool = float(player.get("health")) + float(player.get("item_shield_hp"))
		if _role == "host" and el > 3.0 and not did.has("boss") and spawner:
			did["boss"] = true
			spawner.set("_boss_tiers_spawned", {3: true, 5: true})
			var made: Array = spawner.call("_spawn_boss_group", ["underground1"], 5)
			_events.append({"t": snappedf(el, 0.01), "e": "boss_spawned", "n": made.size(), "hp": float(made[0].get("max_health")) if not made.is_empty() else 0.0,
					"shield": float(made[0].get("item_shield_max")) if not made.is_empty() else 0.0})
		if _stress and el >= next_hit:
			next_hit = el + 0.7
			var limbs_now: Array = _limbs()
			for i in range(mini(2, limbs_now.size())):
				var l: Node = limbs_now[(int(el * 3.0) + i) % limbs_now.size()]
				if _role == "host":
					l.call("take_damage_host", 450.0, false, 0.0, 0)
				else:
					l.call("take_damage", 450.0)
		if _stress and _role == "host" and el > 45.0 and not did.has("low"):
			did["low"] = true
			var bb: Node2D = _boss()
			if bb:
				bb.set("health", 3000.0)
				bb.set("item_shield_hp", 0.0)
				_events.append({"t": snappedf(el, 0.01), "e": "boss_pool_set_low"})
		## İki oyuncu da dönüşümlü yürür (farklı evrelerle): uzuvlar yollarını kessin.
		for a in ["move_right", "move_left", "move_down", "move_up"]:
			Input.action_release(a)
		if el > 6.0:
			var phase: int = int((el - 6.0 + (0.0 if _role == "host" else 1.7)) / 2.4) % 6
			var acts: Array = ["move_right", "move_right", "move_down", "move_left", "move_left", "move_up"]
			Input.action_press(acts[phase])
		if bool(_gm.call("is_position_blocked_by_walls", player.global_position)):
			wall_ever = true
		if el >= next_sample:
			next_sample = el + 0.25
			var b: Node2D = _boss()
			_samples.append([snappedf(el, 0.001), float(b.get("health")) if b else -1.0, float(b.get("item_shield_hp")) if b else -1.0, _limbs().size(), _acid_count(),
					snappedf(player.global_position.x, 0.1), snappedf(player.global_position.y, 0.1), pool_now, 1 if (b != null and b.get("is_dead") == true) else 0])
		if el >= next_limb_log:
			next_limb_log = el + 0.5
			var rec: Dictionary = {}
			for l in _limbs():
				rec[str(int(l.get_meta("network_enemy_id", 0)))] = [snappedf(l.global_position.x, 0.1), snappedf(l.global_position.y, 0.1), int(l.get("_pose_override")), int(l.get("kind")), float(l.get("health"))]
			_limb_log.append([snappedf(el, 0.01), rec])
		await process_frame
	for a2 in ["move_right", "move_left", "move_down", "move_up"]:
		Input.action_release(a2)
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "samples": _samples, "limbs": _limb_log, "events": _events, "wall_ever": wall_ever}))
	out.close()
	_log("bitti: %d örnek, %d uzuv kaydı, %d olay, duvara girdi=%s" % [_samples.size(), _limb_log.size(), _events.size(), wall_ever])
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
