extends SceneTree

## Çok oyunculu denetim: Oakley R "Hayat Ağacı" (madde 266) - kaster HOST OLMAYAN oyuncu (CLAUDE.md: yeni yetenek host olmayanla izlenir).
## İstemci Oakley (2) sağa bakıp R'yi kullanır; host (Hadime) ağacın gölgesine girer, canı düşük; host önüne dayanıklı yaratıklar
## doğurur. Ölçülenler (her iki tarafta): gerçek/kozmetik ağaç sayısı, yer altı kök izleri, ağaç kökü sarılması (fx_oakley_tree_root)
## olan yaratıklar, çiçekler, eğilme klibi (pickup_), host'un canı (istemcinin ağacından elma = sync_ally_heal).
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_audit.ps1 -Mode oakley

const OAKLEY := 2
const HADIME := 14

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _events: Array = []
var _last: Dictionary = {}
var _first_true: Dictionary = {}
var _max: Dictionary = {}
var _t0: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _now() -> float:
	return snappedf(float(Time.get_ticks_msec() - _t0) / 1000.0, 0.01)


func _note(key: String, value: Variant) -> void:
	if value is bool and value and not _first_true.has(key):
		_first_true[key] = _now()
	if value is int or value is float:
		_max[key] = maxf(float(_max.get(key, -1.0e18)), float(value))
	if _last.has(key) and _last[key] == value:
		return
	_last[key] = value
	_events.append([_now(), key, value])


func _trees(real: bool) -> int:
	var c: int = 0
	for n in get_nodes_in_group("oakley_trees"):
		if is_instance_valid(n) and not n.is_queued_for_deletion() and (n.get("caster") != null) == real:
			c += 1
	return c


func _scene_count(pred: Callable) -> int:
	var c: int = 0
	for n in current_scene.get_children():
		if is_instance_valid(n) and not n.is_queued_for_deletion() and pred.call(n):
			c += 1
	return c


func _tree_rooted() -> int:
	var scr: Script = load("res://scripts/fx_oakley_tree_root.gd")
	var c: int = 0
	for e in get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var fx: Variant = e.get("_entangle_fx")
		if fx is Node and is_instance_valid(fx) and (fx as Node).get_script() == scr:
			c += 1
	return c


func _sample(player: Node2D) -> void:
	var rp: Node2D = null
	for r in get_nodes_in_group("remote_players"):
		rp = r as Node2D
	_note("scene.tree_real", _trees(true))
	_note("scene.tree_cosmetic", _trees(false))
	_note("scene.root_trails", _scene_count(func(n: Node) -> bool: return n.get("seed_phase") != null and n.get("_pts") != null))
	_note("scene.tree_rooted", _tree_rooted())
	var flower_scr: Script = load("res://scripts/oakley_flower.gd")
	_note("scene.flowers", _scene_count(func(n: Node) -> bool: return n.get_script() == flower_scr))
	_note("own.hp", int(float(player.get("health"))))
	var a: Variant = player.get("anim")
	if a is AnimatedSprite2D:
		_note("own.pickup", String((a as AnimatedSprite2D).animation).begins_with("pickup_"))
	if rp != null:
		var a2: Variant = rp.get("anim")
		if a2 is AnimatedSprite2D:
			_note("pup.pickup", String((a2 as AnimatedSprite2D).animation).begins_with("pickup_"))
	if _role == "client":
		_note("own.r_state", str(player.get("skill3_state")))


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	if _role == "host":
		if not _nm.call("host_lan", _port, "Host", HADIME):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2 and _nm.call("all_players_ready"), 40.0)
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0)
		if not _nm.call("join_lan", "127.0.0.1", _port, "Client", OAKLEY):
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
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	if _role == "host":
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
	_log("karakter %s, peer %s" % [str(_gm.get("selected_char_id")), str(root.get_multiplayer().get_unique_id())])
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	_t0 = Time.get_ticks_msec()
	var did: Dictionary = {}
	var total: float = 22.0
	player.set("item_shield_max", 4000.0)
	player.set("damage_bonus", 100.0)
	while true:
		paused = false
		var el: float = float(Time.get_ticks_msec() - _t0) / 1000.0
		if el >= total:
			break
		if spawner:
			spawner.set("_spawn_timer", 1.0e9)
		var rp: Node2D = null
		for r in get_nodes_in_group("remote_players"):
			rp = r as Node2D
		if _role == "client":
			## ---- Oakley (kaster, host DEĞİL)
			player.set("item_shield_hp", 4000.0)
			player.set("max_health", 100000.0)
			player.set("health", 100000.0)
			if el > 3.0 and not did.has("r"):
				did["r"] = true
				player.set("facing", "right")
				player.set("skill3_state", "ready")
				player.call("_activate_skill3")
				_events.append([el, "ev.R", str(player.get("skill3_state"))])
		else:
			## ---- Host: Oakley'nin önüne (ağacın gölgesine) geçer, canı düşük; yaratıklar ağacın sağında
			if el > 1.0 and not did.has("setup") and rp != null:
				did["setup"] = true
				player.global_position = rp.global_position + Vector2(40.0, 6.0)
				player.set("max_health", 5000.0)
				player.set("health", 400.0)
				if spawner:
					var roster: Array = spawner.call("_spawnable_roster", 2)
					var n: int = int(spawner.call("debug_spawn_creature", roster[0], 2, 6, rp.global_position + Vector2(170, 0)))
					_events.append([el, "ev.enemies", n])
				for e in get_nodes_in_group("enemies"):
					e.set("max_health", 1.0e7)
					e.set("health", 1.0e7)
			if el < 3.0 and did.has("setup"):
				player.set("health", 400.0)
			player.set("item_shield_hp", 0.0)
		_sample(player)
		await process_frame
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "events": _events}))
	out.close()
	var keys: Array = _first_true.keys()
	keys.sort()
	for k in keys:
		_log("ÖZET ilk doğru  %-22s %.2f sn" % [str(k), float(_first_true[k])])
	var mkeys: Array = _max.keys()
	mkeys.sort()
	for k in mkeys:
		_log("ÖZET en büyük  %-22s %s" % [str(k), str(_max[k])])
	for ev in _events:
		if str(ev[1]).begins_with("ev.") or str(ev[1]) in ["scene.tree_real", "scene.tree_cosmetic", "scene.flowers"]:
			_log("ÖZET olay %.2f %s = %s" % [float(ev[0]), str(ev[1]), str(ev[2])])
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
