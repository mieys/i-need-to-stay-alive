extends SceneTree

## Çok oyunculu denetim: ZİNDANLAR (madde 373). İki süreç (host + istemci), açılış sahnesi atlanır, ikisi de dışarıda başlar.
##  - İstemci Kemik Mahzeni'ne iner: host'taki kuklası in_dungeon alıyor mu, host'ta zindan kampları doğuyor mu, istemci aynı yaratıkları
##    (ağ kimliği + konum) görüyor mu.
##  - İstemci kapı kapatır / kaynak toplar / sandık açar (host'a istek): iki tarafta kapı kapalı + yol engeli, kaynak düşük, sayaç İSTEMCİDE
##    artıyor (host'ta değil), sandık iki tarafta açık + ödül sandığı istemcide doğuyor; kapı 9 sn sonra iki tarafta açılıyor.
##  - İstemci avcının yanına gider: avcı onu kovalıyor mu (host durumu), "SENİ GÖRDÜ" uyarısı istemcide çıkıyor mu.
##  - Host da iner, host kendi kapısını kapatır, istemci çıkar: kukla zindan bilgisi iki yönde.
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_audit.ps1 -Mode zindan

const MATTHEW := 4
const ELARA := 6
const ID := "kemik_mahzeni"
const RES := "ruh_kozu"

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _dm: Node
var _events: Array = []
var _last: Dictionary = {}
var _snaps: Dictionary = {}
var _t0: int = 0
var _dw: GDScript ## _run içinde load (-s betiği autoload'lardan önce derlenir: preload zindan kaydını bozuk derletir)


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _now() -> float:
	return snappedf(float(Time.get_ticks_msec() - _t0) / 1000.0, 0.01)


func _note(key: String, value: Variant) -> void:
	if _last.has(key) and _last[key] == value:
		return
	_last[key] = value
	_events.append([_now(), key, value])


func _rect() -> Rect2:
	return _dw.entry(ID).get("rect", Rect2())


func _dungeon_enemies() -> Array:
	var out: Array = []
	var r: Rect2 = _rect()
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e is Node2D and e.get("is_dead") != true and r.has_point((e as Node2D).global_position):
			out.append(e)
	return out


func _first(kind: String, field: String) -> String:
	var objs: Array = (_dw.entry(ID)["data"] as Resource).call("objects_of", kind)
	return str((objs[0] as Dictionary).get(field, "")) if not objs.is_empty() else ""


func _obj_world(kind: String, field: String, key: String) -> Vector2:
	for o: Dictionary in (_dw.entry(ID)["data"] as Resource).call("objects_of", kind):
		if str(o.get(field, "")) == key:
			return _dw.local_to_world(ID, (o["rect"] as Rect2).get_center())
	return Vector2.INF


func _sample(player: Node2D, gate_key: String, node_key: String, chest_key: String) -> void:
	var st: Dictionary = _dm.call("debug_state")
	_note("own.dng", str(player.get("in_dungeon")))
	for r in get_nodes_in_group("remote_players"):
		_note("pup.dng", str(r.get("in_dungeon")))
	_note("gate.closed", (st["gates_closed"] as Array).has(gate_key))
	_note("gate2.closed", (st["gates_closed"] as Array).size() > (1 if (st["gates_closed"] as Array).has(gate_key) else 0))
	var gp: Vector2 = _obj_world("kapi", "gate_key", gate_key)
	_note("gate.blocked", bool(_gm.call("is_position_blocked_by_walls", gp)))
	_note("node.down", (st["nodes_down"] as Array).has(node_key))
	_note("chest.open", (st["chests"] as Array).has(chest_key))
	_note("res." + RES, int(_gm.call("get_dungeon_resource", RES)))
	_note("dng.enemies", _dungeon_enemies().size())
	var cp: Vector2 = _obj_world("sandik", "chest_key", chest_key)
	var near_chest: int = 0
	for c in get_nodes_in_group("chest_drops"):
		if is_instance_valid(c) and (c as Node2D).global_position.distance_to(cp) < 80.0:
			near_chest += 1
	_note("chest.drops", near_chest)
	_note("hunter.alert", float(_dm.get("_hunter_alert_until")) > float(Time.get_ticks_msec()) / 1000.0)


func _snapshot(tag: String) -> void:
	var list: Dictionary = {}
	for e in _dungeon_enemies():
		var nid: int = int(e.get_meta("network_enemy_id", 0))
		if nid > 0:
			list[str(nid)] = [snappedf((e as Node2D).global_position.x, 0.1), snappedf((e as Node2D).global_position.y, 0.1)]
	_snaps[tag] = list
	_events.append([_now(), "snap." + tag, list.size()])


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	_dw = load("res://scripts/dungeon/dungeon_world.gd")
	if _role == "host":
		if not _nm.call("host_lan", _port, "Host", MATTHEW):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2 and _nm.call("all_players_ready"), 40.0)
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0)
		if not _nm.call("join_lan", "127.0.0.1", _port, "Client", ELARA):
			_log("HATA join_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2, 30.0)
		_nm.call("set_local_ready", true)
	await _until(func(): return current_scene != null and current_scene.name == "Main", 60.0)
	if current_scene == null or current_scene.name != "Main":
		_log("HATA Main yok"); quit(1); return
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	_dm = current_scene.get_node_or_null("DungeonManager")
	if house == null or player == null or _dm == null:
		_log("HATA ev/oyuncu/zindan yok"); quit(1); return
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	if _role == "host":
		house.call("get_intro").call("_host_advance", 3) ## açılış bitti (madde 313): saat + doğuş serbest
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
	await _wait(1.0)
	if bool(player.get("is_indoors")):
		house.call("_do_exit_house")
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	var gc: Node = current_scene.get_node_or_null("GuardCamps")
	var gate_key: String = _first("kapi", "gate_key")
	var node_key: String = _first("kaynak", "node_key")
	var chest_key: String = _first("sandik", "chest_key")
	var gate2_key: String = ""
	for o: Dictionary in (_dw.entry(ID)["data"] as Resource).call("objects_of", "kapi"):
		if str(o.get("gate_key", "")) != gate_key:
			gate2_key = str(o["gate_key"])
			break
	_log("peer %s, kapı %s / %s, kaynak %s, sandık %s, invasion_pending %s" % [str(root.get_multiplayer().get_unique_id()), gate_key, gate2_key,
			node_key, chest_key, str(_gm.get("invasion_pending"))])
	_t0 = Time.get_ticks_msec()
	var did: Dictionary = {}
	var total: float = 30.0
	player.set("max_health", 100000.0)
	while true:
		paused = false
		var el: float = float(Time.get_ticks_msec() - _t0) / 1000.0
		if el >= total:
			break
		player.set("health", 100000.0)
		if spawner:
			spawner.set("_spawn_timer", 1.0e9) ## halka doğuşu yok: zindanda yalnız kamplar
		if _role == "client":
			if el > 1.0 and not did.has("enter"):
				did["enter"] = true
				_dm.call("_do_enter", ID)
				_events.append([_now(), "ev.client_enter", true])
			if el > 6.0 and not did.has("gate"):
				did["gate"] = true
				_dm.call("request_gate", gate_key)
				_events.append([_now(), "ev.req_gate", gate_key])
			if el > 7.5 and not did.has("harvest"):
				did["harvest"] = true
				_dm.call("request_harvest", node_key)
				_dm.call("request_harvest", node_key) ## ikinci istek reddedilmeli (çift ödül yok)
				_events.append([_now(), "ev.req_harvest", node_key])
			if el > 8.5 and not did.has("chest"):
				did["chest"] = true
				_dm.call("request_chest", chest_key)
				_events.append([_now(), "ev.req_chest", chest_key])
			if el > 10.0 and not did.has("hunter") and FileAccess.file_exists(_dir.path_join("hunter.txt")):
				did["hunter"] = true
				var parts: PackedStringArray = FileAccess.get_file_as_string(_dir.path_join("hunter.txt")).split(",")
				player.global_position = Vector2(float(parts[0]), float(parts[1])) + Vector2(110.0, 0.0)
				player.reset_physics_interpolation()
				_events.append([_now(), "ev.client_to_hunter", true])
			if el > 22.0 and not did.has("exit"):
				did["exit"] = true
				_dm.call("_do_exit")
				_events.append([_now(), "ev.client_exit", true])
		else:
			if el > 9.5 and not did.has("hunter_pos"):
				for e in _dungeon_enemies():
					if e.has_meta("dungeon_hunter"):
						did["hunter_pos"] = true
						var hp: Vector2 = (e as Node2D).global_position
						var f := FileAccess.open(_dir.path_join("hunter.txt"), FileAccess.WRITE)
						f.store_string("%f,%f" % [hp.x, hp.y])
						f.close()
						_events.append([_now(), "ev.hunter_pos", [int(hp.x), int(hp.y)]])
						break
			if did.has("hunter_pos") and gc != null:
				for e in _dungeon_enemies():
					if e.has_meta("dungeon_hunter"):
						_note("hunter.state", int(gc.call("state_of", e)))
						if el > 11.0 and not did.has("hunter_diag"):
							did["hunter_diag"] = true
							var bridge: Node = current_scene.get_node_or_null("EnemyWorldBridge")
							var wo: Object = bridge.get("world") if bridge else null
							for r in get_nodes_in_group("remote_players"):
								var rp: Vector2 = (r as Node2D).global_position
								_events.append([_now(), "hunter.diag", {"d": int(rp.distance_to((e as Node2D).global_position)),
										"los": bool(wo.call("is_los_clear", (e as Node2D).global_position, rp)) if wo else null,
										"dng": str(r.get("in_dungeon")), "brush": r.get("brush_state"), "indoors": r.get("is_indoors"),
										"inv": r.get("is_invisible"), "players": (gc.call("_players") as Array).size(),
										"reg_e": int(wo.call("get_region_of", (e as Node2D).global_position)) if wo else -1,
										"reg_p": int(wo.call("get_region_of", rp)) if wo else -1}])
			if el > 14.0 and not did.has("enter"):
				did["enter"] = true
				_dm.call("_do_enter", ID)
				_events.append([_now(), "ev.host_enter", true])
			if el > 19.0 and not did.has("gate2"):
				did["gate2"] = true
				_events.append([_now(), "ev.host_gate2", bool(_dm.call("host_close_gate", gate2_key))])
		if el > 13.0 and not did.has("snapA"):
			did["snapA"] = true
			_snapshot("A")
		if el > 21.0 and not did.has("snapB"):
			did["snapB"] = true
			_snapshot("B")
		_sample(player, gate_key, node_key, chest_key)
		await process_frame
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "events": _events, "snaps": _snaps}))
	out.close()
	for ev in _events:
		_log("ÖZET olay %.2f %s = %s" % [float(ev[0]), str(ev[1]), str(ev[2])])
	if _role == "client":
		## yaratık eşleşmesi: host'un anlık görüntüsüyle ağ kimliği + konum
		await _until(func(): return FileAccess.file_exists(_dir.path_join("host.json")), 15.0)
		var hj: Variant = JSON.parse_string(FileAccess.get_file_as_string(_dir.path_join("host.json")))
		if hj is Dictionary:
			for tag in ["A", "B"]:
				var hs: Dictionary = ((hj as Dictionary).get("snaps", {}) as Dictionary).get(tag, {})
				var cs: Dictionary = _snaps.get(tag, {})
				var both: int = 0
				var worst: float = 0.0
				for k in hs.keys():
					if cs.has(k):
						both += 1
						worst = maxf(worst, Vector2(hs[k][0], hs[k][1]).distance_to(Vector2(cs[k][0], cs[k][1])))
				_log("ÖZET yaratık %s: host %d, istemci %d, ortak %d, en büyük konum farkı %.0f px" % [tag, hs.size(), cs.size(), both, worst])
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
