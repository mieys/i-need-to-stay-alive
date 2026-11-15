extends SceneTree

## Çok oyunculu denetim: Shaman E (Kalkan Totemi) AURA SINIRI "Işık Perdesi" (madde 586) - Shaman HOST OLMAYAN oyuncu (CLAUDE.md).
## İstemci 3. sn'de E'ye basar (gerçek _activate_skill2 -> gerçek totem + ağ kopyası), 6. sn'de totemi süresi dolmuş gibi kapatır
## (_on_expire -> died -> broadcast_pet_despawn). Ölçülenler (iki tarafta): "shaman_aura_borders" düğümleri - ilk görülme / kayboluş zamanı,
## en çok aynı anda kaç tane, shader merkezinin totem konumuna uzaklığı, açılış sonrası yarıçap, haritadaki sıra (ebeveyn + sonraki kardeş).
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_audit.ps1 -Mode shamanaura

const HOST_CHAR := 2
const CLIENT_CHAR := 12
const BORDER_GROUP := "shaman_aura_borders"

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _t0: int = 0
var _info: Dictionary = {"first": -1.0, "gone": -1.0, "max_count": 0, "max_center_off": 0.0, "radius": 0.0,
	"parent": "", "next_sibling": "", "fade_seen": false, "totems": 0}


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _now() -> float:
	return snappedf(float(Time.get_ticks_msec() - _t0) / 1000.0, 0.01)


func _shield_totems() -> Array:
	var out: Array = []
	for t in get_nodes_in_group("shaman_totems"):
		if is_instance_valid(t) and t.has_method("aura_border"):
			out.append(t)
	return out


func _sample() -> void:
	var borders: Array = get_nodes_in_group(BORDER_GROUP)
	var totems: Array = _shield_totems()
	_info["totems"] = maxi(int(_info["totems"]), totems.size())
	_info["max_count"] = maxi(int(_info["max_count"]), borders.size())
	if borders.size() > 0 and float(_info["first"]) < 0.0:
		_info["first"] = _now()
		var b: Node = borders[0]
		_info["parent"] = str(b.get_parent().name)
		var idx: int = b.get_index() + 1
		_info["next_sibling"] = str(b.get_parent().get_child(idx).name) if idx < b.get_parent().get_child_count() else "-"
	if borders.is_empty() and float(_info["first"]) >= 0.0 and float(_info["gone"]) < 0.0:
		_info["gone"] = _now()
	for b in borders:
		if bool(b.call("is_fading")):
			_info["fade_seen"] = true
		if totems.size() > 0 and not bool(b.call("is_fading")) and (b as CanvasItem).visible:
			var mat: ShaderMaterial = (b as CanvasItem).material as ShaderMaterial
			var c: Vector2 = mat.get_shader_parameter("center")
			_info["max_center_off"] = maxf(float(_info["max_center_off"]), snappedf(c.distance_to((totems[0] as Node2D).global_position), 0.01))
			_info["radius"] = snappedf(float(b.call("drawn_radius")), 0.01)


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
	while true:
		paused = false
		var el: float = float(Time.get_ticks_msec() - _t0) / 1000.0
		if el >= total:
			break
		if spawner:
			spawner.set("_spawn_timer", 1.0e9)
		for e in get_nodes_in_group("enemies"):
			if not e.is_queued_for_deletion():
				e.queue_free()
		if _role == "client":
			if el > 3.0 and not did.has("e"):
				did["e"] = true
				var before: int = _shield_totems().size()
				player.set("skill2_state", "ready")
				player.set("skill2_timer", 0.0)
				player.call("_activate_skill2")
				if _shield_totems().size() == before:
					player.call("_skill_shaman_shield_totem")
				_log("E basıldı %.2f totem=%d" % [el, _shield_totems().size()])
			if el > 6.0 and not did.has("x"):
				did["x"] = true
				for t in _shield_totems():
					t.call("_on_expire")
				_log("süre doldu %.2f" % el)
		_sample()
		await process_frame
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "info": _info}))
	out.close()
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
