extends SceneTree

## Çok oyunculu denetim: Vampir Yarasa Formu geçiş efekti "Kızıl Girdap" (madde 516) - Vampir HOST OLMAYAN oyuncu (CLAUDE.md).
## İstemci 3. sn'de E'ye basar (gerçek _activate_skill2), yarasa formunda sağa kayar, 5. sn'de formu iptal eder (_vampir_cancel_bat_form).
## Ölçülenler (her iki tarafta): vampir_fx.gd düğümleri - tür (bat_in / bat_out) ilk görülme zamanı, katman sayısı ve ground z'si,
## efekt konumunun izlenen gövdeye (oyuncu/kukla çizilen konum + BODY_CENTER) en büyük uzaklığı.
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_audit.ps1 -Mode vampir

const HOST_CHAR := 2
const CLIENT_CHAR := 13
const VAMPIR_FX := "res://scripts/vampir_fx.gd"
const BODY_CENTER := Vector2(0, -6)

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _t0: int = 0
var _seen: Dictionary = {}   ## düğüm kimliği -> true
var _first: Dictionary = {}  ## tür -> ilk görülme sn
var _info: Dictionary = {}   ## tür -> {layers, ground_z, front_z, max_off, frames}


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _now() -> float:
	return snappedf(float(Time.get_ticks_msec() - _t0) / 1000.0, 0.01)


func _vis(n: Node2D) -> Vector2:
	return (load("res://scripts/physics_interp.gd") as GDScript).call("visual_position", n)


func _sample(player: Node2D) -> void:
	var owner_body: Node2D = player
	if _role == "host":
		var rps: Array = get_nodes_in_group("remote_players")
		owner_body = rps[0] if rps.size() > 0 else null
	for c in current_scene.get_children():
		var sc: Script = c.get_script()
		if sc == null or sc.resource_path != VAMPIR_FX:
			continue
		var kind: String = str(c.get("kind"))
		if kind != "bat_in" and kind != "bat_out":
			continue
		var layers: Array = c.get("_sheet")
		if not _seen.has(c.get_instance_id()):
			_seen[c.get_instance_id()] = true
			if not _first.has(kind):
				_first[kind] = _now()
			_info[kind] = {"layers": layers.size(), "front_z": int(c.z_index),
				"ground_z": int((layers[1] as Sprite2D).z_index) if layers.size() > 1 else -99,
				"ground_rel": bool((layers[1] as Sprite2D).z_as_relative) if layers.size() > 1 else true,
				"follow_ok": c.get("follow") == owner_body, "max_off": 0.0, "frames": 0}
		if owner_body != null and is_instance_valid(owner_body):
			var off: float = (c as Node2D).global_position.distance_to(_vis(owner_body) + BODY_CENTER)
			_info[kind]["max_off"] = maxf(float(_info[kind]["max_off"]), snappedf(off, 0.01))
		_info[kind]["frames"] = int(_info[kind]["frames"]) + 1


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	_gm.set("debug_immortal", true)
	if _role == "host":
		if not _nm.call("host_lan", _port, "Host", HOST_CHAR):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2 and _nm.call("all_players_ready"), 40.0)
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0)
		if not _nm.call("join_lan", "127.0.0.1", _port, "Client", CLIENT_CHAR):
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
	_finish_house_intro()
	await _wait(1.5)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player == null:
		_log("HATA Player yok"); quit(1); return
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	if _role == "host":
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
	_log("karakter %s" % str(_gm.get("selected_char_id")))
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	_t0 = Time.get_ticks_msec()
	var did: Dictionary = {}
	var total: float = 9.0
	var last: int = Time.get_ticks_msec()
	while true:
		paused = false
		var now: int = Time.get_ticks_msec()
		var dt: float = float(now - last) / 1000.0
		last = now
		var el: float = float(now - _t0) / 1000.0
		if el >= total:
			break
		if spawner:
			spawner.set("_spawn_timer", 1.0e9)
		for e in get_nodes_in_group("enemies"):
			if not e.is_queued_for_deletion():
				e.queue_free()
		if _role == "client":
			if el > 3.0 and not did.has("in"):
				did["in"] = true
				player.set("skill2_state", "ready")
				player.set("skill2_timer", 0.0)
				player.call("_activate_skill2")
				_log("E basıldı %.2f form=%s" % [el, str(player.get("_vampir_bat_form_active"))])
			if did.has("in") and not did.has("out"):
				player.global_position += Vector2(90.0 * dt, 0.0) ## yarasa sağa uçar: efekt izlemeli
			if el > 5.0 and not did.has("out"):
				did["out"] = true
				player.call("_vampir_cancel_bat_form")
				_log("iptal %.2f form=%s" % [el, str(player.get("_vampir_bat_form_active"))])
			if did.has("out") and el < 5.6:
				player.global_position += Vector2(-60.0 * dt, 0.0)
		_sample(player)
		await process_frame
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "first": _first, "info": _info}))
	out.close()
	_log("ilk: %s" % JSON.stringify(_first))
	_log("bilgi: %s" % JSON.stringify(_info))
	_log("bitti")
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


## Açılış sahnesini bitirir (madde 419 / 349 tuzağı; evcil_audit.gd ile aynı).
func _finish_house_intro() -> void:
	var scene: Node = current_scene
	var intro: Node = scene.get_node_or_null("HouseInterior/HouseIntro") if scene else null
	if intro and intro.has_method("_set_phase"):
		intro.call("_set_phase", 3, 0.0)
	root.get_node("GameManager").set("invasion_pending", false)
