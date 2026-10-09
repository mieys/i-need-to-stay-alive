extends SceneTree

## Matthew'in KÖPEĞİ çok oyunculu denetimi (CLAUDE.md madde 38): iki gerçek süreç (host = Matthew, istemci = Vampir; başsız LAN). Host yürür/durur, sonra yakınına
## yaratıklar çıkar; HER İKİ tarafta köpeğin (host'ta gerçeği, istemcide kozmetik kopyası) konumu ve klip geçişleri KARE KARE kaydedilir
## (dog_audit_compare.py karşılaştırır: konum hatası, ısırma klibi iki tarafta da, klip titremesi). MP_ROLE=host|client MP_DIR MP_PORT. Sonuç: <rol>.json

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7851
var _nm: Node
var _gm: Node
var _pos: Array = [] ## [t, x, y]
var _trans: Array = [] ## [t, klip, x, y] (klip değiştiği her kare)
var _events: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _player() -> Node2D:
	return current_scene.get_node_or_null("Player") as Node2D if current_scene else null


## Host: kendi gerçek köpeği; istemci: host'un kuklasındaki kozmetik köpek kopyası.
func _pet() -> Node2D:
	if _role == "host":
		var p: Node2D = _player()
		if p == null:
			return null
		var pet: Variant = p.get("_matthew_pet")
		return pet as Node2D if is_instance_valid(pet) else null
	for rp in get_nodes_in_group("remote_players"):
		var d: Variant = rp.get("_pet_visuals")
		if d is Dictionary:
			for k in (d as Dictionary).keys():
				var v: Variant = (d as Dictionary)[k]
				if is_instance_valid(v):
					return v as Node2D
	return null


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	if _role == "host":
		if not _nm.call("host_lan", _port, "Host", 3):
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
	await _until(func(): return _pet() != null, 25.0)
	_log("köpek bulundu: %s" % (_pet() != null))
	if _role == "host":
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	var t0: int = Time.get_ticks_msec()
	var next_pos: int = 0
	var last_clip: String = ""
	var did: Dictionary = {}
	while Time.get_ticks_msec() - t0 < 40000:
		paused = false
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if spawner and el <= 26.0:
			spawner.set("_spawn_timer", 1.0e9) ## yürüyüş fazında rastgele doğuş yok; savaş fazında (26 sn+) NORMAL doğuş açık: silahlar sürekli yakındakileri öldürür
		if _role == "host":
			player.set("health", 1.0e9)
			player.set("max_health", 1.0e9)
			## Faz A (2-24 sn): yürü / dur / geri yürü / dur - köpek akmalı, durunca yanında bekleyip idle olmalı
			Input.action_release("move_right")
			Input.action_release("move_left")
			Input.action_release("move_down")
			if el > 2.0 and el < 7.0:
				Input.action_press("move_right")
			elif el > 10.0 and el < 15.0:
				Input.action_press("move_left")
			elif el > 17.0 and el < 21.0:
				Input.action_press("move_down")
			## Faz B (26 sn): yakına yaratıklar - köpek ısırmalı (host + istemcide ısırma klibi)
			if el > 26.0 and not did.has("enemies") and spawner:
				did["enemies"] = true
				var roster: Array = spawner.call("_spawnable_roster", 3)
				var n: int = int(spawner.call("debug_spawn_creature", roster[0], 3, 12, player.global_position))
				_events.append({"t": el, "e": "enemies_spawned", "n": n})
		var pet: Node2D = _pet()
		if pet != null:
			var clip: String = String((pet.get("anim") as AnimatedSprite2D).animation)
			if clip != last_clip:
				last_clip = clip
				_trans.append([snappedf(el, 0.01), clip, snappedf(pet.global_position.x, 0.1), snappedf(pet.global_position.y, 0.1)])
			if Time.get_ticks_msec() - t0 >= next_pos:
				next_pos += 250
				_pos.append([snappedf(el, 0.01), snappedf(pet.global_position.x, 0.1), snappedf(pet.global_position.y, 0.1), snappedf(player.global_position.x if _role == "host" else 0.0, 0.1), snappedf(player.global_position.y if _role == "host" else 0.0, 0.1)])
		await process_frame
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("move_down")
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "pos": _pos, "trans": _trans, "events": _events}))
	out.close()
	_log("bitti: %d konum, %d klip geçişi" % [_pos.size(), _trans.size()])
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
