extends SceneTree

## Melek Q/E SİHİRLİ BAĞ denetimi (madde 212; CLAUDE.md: "yeni yetenek/efekti iki pencerede HOST OLMAYAN oyuncuyla izle").
## İki gerçek süreç (başsız LAN), yaratık doğumu kapalı: host = Şovalye (bağın hedefi), istemci = Melek (kaster, host DEĞİL).
## İstemci 4. sn'de Q (Can Basma), 13. sn'de E (Kalkan Yenileme) kullanır; host'un canı/kalkanı düşük tutulur ki hedef o olsun.
## Her iki tarafta kaydedilir (değiştiği anda): hedefteki bağ (var mı, kasteri kim, bağlandı mı, kaç tik paketi geldi, ip düğümü),
## Melek'in üstündeki bağ renkli hale (var mı, boyuyor mu). Beklenen: host KENDİ Player'ında, istemci host KUKLASINDA aynı
## bağı görür; ikisinde de tik sayısı ~6 (Q) / ~6 (E, host kalkanı doluysa daha az); Melek kuklasında hale; yetenek bitince hepsi kalkar.
## MP_ROLE=host|client MP_DIR MP_PORT. Sonuç: <rol>.json + "MP[...] SONUC" satırları. run_audit.ps1 -Mode melek.

const SOVALYE := 7
const MELEK := 10

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _events: Array = []
var _last: Dictionary = {}
var _t0: int = 0
var _max_pulses: Dictionary = {}


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


func _halo_on(n: Node, kind: String) -> Node:
	if n == null:
		return null
	for ch in n.get_children():
		var s: Variant = ch.get_script()
		if s != null and (s as Script).resource_path.ends_with("melek_halo_fx.gd") and ch.get("aura_type") == kind \
				and not ch.is_queued_for_deletion():
			return ch
	return null


func _ribbons() -> int:
	var c: int = 0
	for ch in current_scene.get_children():
		var s: Variant = ch.get_script()
		if s != null and (s as Script).resource_path.ends_with("melek_bond_ribbon.gd") and not ch.is_queued_for_deletion():
			c += 1
	return c


func _sample(player: Node2D, puppet: Node2D) -> void:
	## bağın hedefi = Şovalye: host'ta KENDİ Player'ı, istemcide host kuklası. Hale = Melek: istemcide kendisi, host'ta kukla.
	var target: Node2D = player if _role == "host" else puppet
	var melek: Node2D = puppet if _role == "host" else player
	for kind: String in ["heal", "shield"]:
		var reg: Variant = target.get("_ally_aura_fx") if target != null else null
		var bond: Variant = (reg as Dictionary).get(kind, null) if reg is Dictionary else null
		var ok: bool = bond != null and is_instance_valid(bond) and (bond as Object).has_method("pulse")
		_note("bag.%s" % kind, ok)
		if ok:
			var c: Variant = (bond as Object).get("caster")
			_note("bag.%s.kaster_melek" % kind, c != null and is_instance_valid(c) and c == melek)
			_note("bag.%s.bagli" % kind, bool((bond as Object).call("is_connected_bond")))
			var n: int = int((bond as Object).get("pulses_received"))
			_note("bag.%s.tik" % kind, n)
			_max_pulses[kind] = maxi(int(_max_pulses.get(kind, 0)), n)
		var halo: Node = _halo_on(melek, kind)
		_note("hale.%s" % kind, halo != null)
		if halo != null:
			_note("hale.%s.boyuyor" % kind, bool(halo.call("is_tinting")))
	_note("ip_dugumu", _ribbons())


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	if _role == "host":
		if not _nm.call("host_lan", _port, "Host", SOVALYE):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2 and _nm.call("all_players_ready"), 40.0)
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0)
		if not _nm.call("join_lan", "127.0.0.1", _port, "Client", MELEK):
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
		var p: Vector2 = player.global_position + Vector2(120, 0)
		for i in 20:
			if not _gm.call("is_position_blocked_by_walls", p):
				break
			p += Vector2(0, 32)
		player.global_position = p
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	if _role == "host":
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
	var puppet: Node2D = null
	for r in get_nodes_in_group("remote_players"):
		puppet = r
	_log("karakter %s, peer %s, kukla %s" % [str(_gm.get("selected_char_id")), str(root.get_multiplayer().get_unique_id()), str(puppet)])
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
		if _role == "host":
			## en düşük canlı + en düşük kalkanlı dost host olsun (istemcinin kuklası bu değerleri görür)
			player.set("max_health", 1000.0)
			player.set("health", 300.0)
			player.set("item_shield_max", 1000.0)
			if el < 12.0:
				player.set("item_shield_hp", 100.0)
		else:
			player.set("max_health", 1000.0)
			player.set("health", 900.0)
			if el > 4.0 and not did.has("q"):
				did["q"] = true
				player.call("_activate_skill")
				_events.append([el, "ev.Q", str(player.get("skill_state"))])
			if el > 13.0 and not did.has("e"):
				did["e"] = true
				player.call("_activate_skill2")
				_events.append([el, "ev.E", str(player.get("skill2_state"))])
		_sample(player, puppet)
		await process_frame
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "events": _events}))
	out.close()
	for e: Array in _events:
		_log("%6.2f %s = %s" % [float(e[0]), str(e[1]), str(e[2])])
	_log("SONUC tik heal=%d shield=%d" % [int(_max_pulses.get("heal", 0)), int(_max_pulses.get("shield", 0))])
	await _wait(1.0)
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
