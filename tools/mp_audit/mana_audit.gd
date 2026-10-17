extends SceneTree

## MANA KALKANI "B - Mühür" çok oyunculu denetimi (2026-10-14, madde 148): iki gerçek süreç (başsız LAN). İSTEMCİ = kalkan
## sahibi (host OLMAYAN oyuncu - CLAUDE.md "yeni efekti HOST OLMAYAN oyuncuyla izle"), HOST = izleyici.
## İstemci: Kale Mana Kalkanı (mor) seçer; 3 darbe (sol / sağ / kuzey), sonra kalkanı bitiren darbe (kırılma), sonra
## kalkanı saniyede bir 4 adımda doldurur (tik benzetimi) -> doldu. Her iki taraf KENDİ efektini ve DİĞERİNİN kuklasındaki
## efekti kaydeder: disk sayısı, kırılma, yer mührü (yenilenme), doldu taraması, palet türü.
## MP_ROLE=host|client MP_DIR MP_PORT. Sonuç: <rol>.json + günlükte "MP[rol] ÖZET ..." satırları. run_audit.ps1 -Mode mana.

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


func _fx_state(prefix: String, holder: Node) -> void:
	var fx: Node = holder.get_node_or_null("ManaShieldFx") if holder else null
	if fx == null:
		_note(prefix + ".fx", false)
		return
	_note(prefix + ".fx", true)
	_note(prefix + ".disc", int(fx.call("disc_count")))
	_note(prefix + ".disc_back", _disc_behind(fx))
	_note(prefix + ".break", bool((fx.get("_break_front") as Sprite2D).visible))
	_note(prefix + ".regen", bool(fx.call("is_regen_shown")))
	_note(prefix + ".rise", bool((fx.get("_rise_front") as Sprite2D).visible))
	_note(prefix + ".type", str(fx.get("_type")))
	_note(prefix + ".shield", int(float(holder.get("item_shield_hp"))))


func _disc_behind(fx: Node) -> bool:
	for d in fx.get("_discs"):
		var s: Node = d["spr"]
		if is_instance_valid(s) and s.get_parent() != fx:
			return true
	return false


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	if _role == "host":
		if not _nm.call("host_lan", _port, "Host", 1):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2 and _nm.call("all_players_ready"), 40.0)
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0)
		if not _nm.call("join_lan", "127.0.0.1", _port, "Client", 2):
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
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	var src := Node2D.new() ## darbe kaynağı (yönü belirler)
	current_scene.add_child(src)
	_t0 = Time.get_ticks_msec()
	var did: Dictionary = {}
	var total: float = 18.0
	player.set("max_health", 100000.0)
	player.set("health", 100000.0)
	if _role == "client":
		_gm.set("shield_enchant", "shield_kale")
		player.call("refresh_shield_stats")
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
		player.set("health", 100000.0)
		if _role == "client":
			if el > 1.0 and not did.has("setup"):
				did["setup"] = true
				player.set("item_shield_max", 150.0)
				player.set("item_shield_hp", 150.0)
				player.set("shield_protection", 0.65)
			## 3 darbe: soldan, sağdan, kuzeyden (kalkan 150 -> ~20, kırılmaz)
			var hits := [[3.0, Vector2(-60, 0)], [4.2, Vector2(60, 0)], [5.4, Vector2(0, -60)]]
			for i in hits.size():
				if el > float(hits[i][0]) and not did.has("hit%d" % i):
					did["hit%d" % i] = true
					src.global_position = player.global_position + (hits[i][1] as Vector2)
					player.set("_last_damage_taken_at_msec", -100000)
					player.call("take_damage", 60.0, src)
					_events.append([el, "ev.hit%d" % i, int(float(player.get("item_shield_hp")))])
			## kalkanı bitiren darbe
			if el > 7.0 and not did.has("break"):
				did["break"] = true
				player.set("item_shield_hp", 5.0)
				src.global_position = player.global_position + Vector2(-60, 0)
				player.set("_last_damage_taken_at_msec", -100000)
				player.call("take_damage", 60.0, src)
				_events.append([el, "ev.break", int(float(player.get("item_shield_hp")))])
			## yenilenme benzetimi: 4 tik, saniyede bir (gerçek tik = SHIELD_REGEN_TICK_INTERVAL 1 sn)
			for k in 4:
				if el > 10.0 + k and not did.has("tick%d" % k):
					did["tick%d" % k] = true
					player.set("item_shield_regen_delay", 30.0) ## oyunun kendi yenilenmesi araya girmesin
					player.set("item_shield_hp", 37.5 * (k + 1))
					_events.append([el, "ev.tick%d" % k, int(37.5 * (k + 1))])
			_fx_state("own", player)
			_fx_state("pup", rp)
		else:
			_fx_state("pup", rp)
		await process_frame
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "events": _events}))
	out.close()
	var keys: Array = _first_true.keys()
	keys.sort()
	for k in keys:
		_log("ÖZET ilk doğru  %-18s %.2f sn" % [str(k), float(_first_true[k])])
	var mkeys: Array = _max.keys()
	mkeys.sort()
	for k in mkeys:
		_log("ÖZET en büyük  %-18s %s" % [str(k), str(_max[k])])
	for ev in _events:
		if str(ev[1]).ends_with(".type") or str(ev[1]).begins_with("ev."):
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
