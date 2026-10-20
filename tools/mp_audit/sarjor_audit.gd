extends SceneTree

## Çok oyunculu denetim: Tabanca + Tüfek ŞARJÖRÜ (madde 296) - kaster HOST OLMAYAN oyuncu (CLAUDE.md). İstemci Tabanca + Tüfek alır,
## host önüne (istemcinin sağına, menzil içinde) dayanıklı yaratıklar doğurur; istemcinin silahları ateş edip doldurur.
## Ölçülenler: istemcide gerçek doldurma sayısı (weapon.gd is_reloading geçişleri) ve kovan/şarjör parçaları; host'ta kuklanın ikonunda
## doldurma sürücüsü (GunReloadFx META geçişleri) ve kuklanın ateşinden doğan kovanlar (ShellCasingFx).
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_audit.ps1 -Mode sarjor

## preload YOK: -s betikleri autoload'lardan önce derlenir (GameManager bağımlılığı derlenemez) - adlar düz yazıldı.
const RELOAD_META := &"gun_reload" ## GunReloadFx.META
const CASING_NODE := "ShellCasingFx" ## ShellCasingFx.NODE_NAME
const HADIME := 14
const CLIENT_CHAR := 2

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _events: Array = []
var _t0: int = 0
var _count: Dictionary = {}
var _prev: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _now() -> float:
	return snappedf(float(Time.get_ticks_msec() - _t0) / 1000.0, 0.01)


## Yükselen kenar sayacı (false -> true).
func _edge(key: String, on: bool) -> void:
	if on and not bool(_prev.get(key, false)):
		_count[key] = int(_count.get(key, 0)) + 1
		_events.append([_now(), key, int(_count[key])])
	_prev[key] = on


## Artış sayacı (canlı parça sayısı yükseldikçe toplam doğan).
func _rise(key: String, value: int) -> void:
	var last: int = int(_prev.get(key, 0))
	if value > last:
		_count[key] = int(_count.get(key, 0)) + (value - last)
	_prev[key] = value


func _sample(player: Node2D) -> void:
	var mgr: Node = current_scene.get_node_or_null(CASING_NODE)
	_rise("scene.parca_dogan", int(mgr.call("alive_count")) if mgr != null else 0)
	if _role == "client":
		for w in player.get("owned_weapon_nodes"):
			if not is_instance_valid(w) or int(w.get("max_ammo")) <= 0:
				continue
			var k: String = String(w.get("_mag_key"))
			_edge("own.doldurma." + k, bool(w.get("is_reloading")))
	else:
		for rp in get_nodes_in_group("remote_players"):
			var icons: Array = rp.get("_weapon_icons")
			var keys: Array = rp.get("_weapon_keys")
			for i in icons.size():
				var ic: Node2D = icons[i]
				if is_instance_valid(ic) and i < keys.size():
					_edge("pup.doldurma." + str(keys[i]), ic.has_meta(RELOAD_META))


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
	await _wait(1.5)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player == null:
		_log("HATA Player yok"); quit(1); return
	if _role == "client":
		player.call("buy_weapon_copy", "tabanca", 1)
		player.call("buy_weapon_copy", "tufek", 1)
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	if _role == "host":
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
	var guns: Array = []
	for w in player.get("owned_weapon_nodes"):
		if is_instance_valid(w):
			guns.append("%s(%d)" % [String(w.get("_mag_key")), int(w.get("max_ammo"))])
	_log("karakter %s, silahlar %s" % [str(_gm.get("selected_char_id")), str(guns)])
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	_t0 = Time.get_ticks_msec()
	var did: Dictionary = {}
	var total: float = 24.0
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
			player.set("item_shield_max", 4000.0)
			player.set("item_shield_hp", 4000.0)
			player.set("max_health", 100000.0)
			player.set("health", 100000.0)
		elif el > 1.0 and not did.has("setup") and rp != null:
			## host: istemcinin sağına (Tabanca menzili 210 içinde) dayanıklı yaratıklar
			did["setup"] = true
			player.global_position = rp.global_position + Vector2(-60.0, 0.0)
			if spawner:
				var roster: Array = spawner.call("_spawnable_roster", 1)
				var n: int = int(spawner.call("debug_spawn_creature", roster[0], 1, 5, rp.global_position + Vector2(120, 0)))
				_events.append([el, "ev.yaratik", n])
			for e in get_nodes_in_group("enemies"):
				e.set("max_health", 1.0e7)
				e.set("health", 1.0e7)
				e.set("speed", 0.0)
		_sample(player)
		await process_frame
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "events": _events, "count": _count}))
	out.close()
	var keys: Array = _count.keys()
	keys.sort()
	for k in keys:
		_log("ÖZET sayı %-28s %d" % [str(k), int(_count[k])])
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
