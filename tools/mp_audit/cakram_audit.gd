extends SceneTree

## Çok oyunculu denetim: ÇAKRAM özelliği SEKEN ÇELİK + final ÇELİK DEĞİRMEN (madde 591) - kaster HOST OLMAYAN oyuncu (CLAUDE.md).
## İstemci çakram alır, özelliği tam (4 geliştirme + final) yapılır; host istemcinin sağına sık dizili dayanıklı yaratıklar doğurur.
## Ölçülenler: istemcide gerçek sekme / kopya sayısı (seken_celik.gd bounces / mills); host'ta istemcinin çakram KOPYALARININ sekme
## sayısı (boomerang_projectile.gd bounces_done, kasterin "chakram_leg" mesajıyla artar) ve sahnede doğan Çelik Değirmen görselleri.
## Beklenen: host'un gördüğü sekme ~= istemcinin sekmesi, kopya görseli = istemcinin kopyası.
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_audit.ps1 -Mode cakram

## preload YOK: -s betikleri autoload'lardan önce derlenir (GameManager bağımlılığı derlenemez) - adlar düz yazıldı.
const PROJ_SCRIPT := "res://scripts/boomerang_projectile.gd"
const MILL_SCRIPT := "res://scripts/chakram_mill_fx.gd"
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
var _copy_bounces: Dictionary = {} ## kopya instance id -> görülen en yüksek bounces_done
var _mills_seen: Dictionary = {}
var _beh: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _now() -> float:
	return snappedf(float(Time.get_ticks_msec() - _t0) / 1000.0, 0.01)


func _script_path(n: Node) -> String:
	var s: Script = n.get_script() as Script
	return s.resource_path if s != null else ""


func _sample() -> void:
	if _role == "client":
		if is_instance_valid(_beh):
			_count["own.sekme"] = int(_beh.get("bounces"))
			_count["own.degirmen"] = int(_beh.get("mills"))
		return
	for n in current_scene.get_children():
		var sp: String = _script_path(n)
		if sp == PROJ_SCRIPT and n.get_meta("network_spawned", false):
			var id: int = n.get_instance_id()
			var b: int = int(n.get("bounces_done"))
			if b > int(_copy_bounces.get(id, 0)):
				_events.append([_now(), "pup.sekme", b])
			_copy_bounces[id] = maxi(b, int(_copy_bounces.get(id, 0)))
			_count["pup.kopya_cakram"] = _copy_bounces.size()
		elif sp == MILL_SCRIPT and not _mills_seen.has(n.get_instance_id()):
			_mills_seen[n.get_instance_id()] = true
			_events.append([_now(), "pup.degirmen", _mills_seen.size()])
	var total: int = 0
	for id in _copy_bounces:
		total += int(_copy_bounces[id])
	_count["pup.sekme"] = total
	_count["pup.degirmen"] = _mills_seen.size()


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
	_finish_house_intro()
	await _wait(1.5)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player == null:
		_log("HATA Player yok"); quit(1); return
	if _role == "client":
		## Yalnız çakram: diğer silahlar sekme hedeflerini öldürmesin / sayımı kirletmesin.
		for w in (player.get("owned_weapon_nodes") as Array).duplicate():
			if is_instance_valid(w):
				w.queue_free()
		(player.get("owned_weapon_nodes") as Array).clear()
		## Defter ÖNCE yazılır (buy_weapon_copy kaydın efsununu aynı sıradan uygular); tipli dizi yerinde temizlenir (set ile [] atamak tutmaz).
		var owned: Array = _gm.get("owned_weapons")
		owned.clear()
		var entry: Dictionary = load("res://scripts/enchant_defs.gd").call("new_weapon_entry", "boomerang", 1, 0)
		entry["enchant"] = {"id": "seken_celik", "ups": [0, 1, 2, 3], "final": true}
		owned.append(entry)
		player.call("buy_weapon_copy", "boomerang", 1)
		for w in player.get("owned_weapon_nodes"):
			if is_instance_valid(w) and is_instance_valid(w.get("enchant_behavior")):
				_beh = w.get("enchant_behavior")
		_log("davranış %s" % (_script_path(_beh) if _beh else "YOK"))
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	if _role == "host":
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
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
			## host: istemcinin sağına (çakram menzili ~167 içinde) birbirine yakın (sekme 140 birim) dayanıklı yaratıklar
			did["setup"] = true
			player.global_position = rp.global_position + Vector2(-60.0, 0.0)
			if spawner:
				var roster: Array = spawner.call("_spawnable_roster", 1)
				var n: int = int(spawner.call("debug_spawn_creature", roster[0], 1, 6, rp.global_position + Vector2(110, 0)))
				_events.append([el, "ev.yaratik", n])
			for e in get_nodes_in_group("enemies"):
				e.set("max_health", 1.0e7)
				e.set("health", 1.0e7)
				e.set("speed", 0.0)
		_sample()
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


## Açılış sahnesini (madde 313, HouseIntro) bitirir - madde 419: yoksa GameManager.invasion_pending true kalır, yaratık senkronu çalışmaz.
func _finish_house_intro() -> void:
	var scene: Node = current_scene
	var intro: Node = scene.get_node_or_null("HouseInterior/HouseIntro") if scene else null
	if intro and intro.has_method("_set_phase"):
		intro.call("_set_phase", 3, 0.0) ## HouseIntro.Phase.DONE
	root.get_node("GameManager").set("invasion_pending", false)
