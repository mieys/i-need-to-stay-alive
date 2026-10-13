extends SceneTree

## CADI çok oyunculu denetimi (2026-10-13, madde 113): iki gerçek süreç (başsız LAN). İSTEMCİ = Cadı (host OLMAYAN kaster -
## CLAUDE.md "yeni yetenek/efekti HOST OLMAYAN oyuncuyla izle"), HOST = Suriyeli Hadime (yolcu).
## Her tarafta KENDİ durumu ve DİĞER oyuncunun kuklasında/sahnesinde gördüğü, değiştiği anda zaman damgasıyla kaydedilir.
##   Q  : kuklada Q bayrağı + şişe düğümü, host sahnesinde kozmetik bulut sayısı, host'taki yaratıkların canı düşüyor mu
##   R  : 5 iksir sırayla; host sahnesinde şişe/alan kopyaları + host-yetkili yaratık etkileri (deli / donmuş / korkmuş sayısı)
##   E  : kuklada süpürge bayrağı + düğümü + ride_* klibi; host cadıya değip BİNER (iki tarafta yolcu listesi, koltuk mesafesi,
##        host'un canı/kalkanı süpürgeden yenileniyor mu), hareket edip İNER
## MP_ROLE=host|client MP_DIR MP_PORT. Sonuç: <rol>.json + günlükte "MP[rol] ÖZET ..." satırları. run_audit.ps1 -Mode cadi.

const CADI := 15
const HADIME := 14

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _events: Array = [] ## [t, anahtar, değer]
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


## Değer değiştiyse kaydet; ilk "doğru" anı ve sayıların en büyüğü özet için tutulur.
func _note(key: String, value: Variant) -> void:
	if value is bool and value and not _first_true.has(key):
		_first_true[key] = _now()
	if value is int or value is float:
		_max[key] = maxf(float(_max.get(key, -1.0e18)), float(value))
	if _last.has(key) and _last[key] == value:
		return
	_last[key] = value
	_events.append([_now(), key, value])


func _group_count(g: String, authoritative: Variant = null, potion: int = -1) -> int:
	var c: int = 0
	for n in get_nodes_in_group(g):
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		if authoritative != null and bool(n.get("authoritative")) != bool(authoritative):
			continue
		if potion >= 0 and int(n.get("potion")) != potion:
			continue
		c += 1
	return c


func _enemy_stats() -> Dictionary:
	var out: Dictionary = {"n": 0, "mad": 0, "frozen": 0, "feared": 0, "lost": 0.0}
	for e in get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		out["n"] += 1
		if e.get("is_mad") == true:
			out["mad"] += 1
		if e.get("is_frozen") == true:
			out["frozen"] += 1
		if e.get("is_feared") == true:
			out["feared"] += 1
		out["lost"] += maxf(0.0, float(e.get("max_health")) - float(e.get("health")))
	return out


func _sample(player: Node2D) -> void:
	var rp: Node2D = null
	for r in get_nodes_in_group("remote_players"):
		rp = r as Node2D
	_note("own.hp", int(float(player.get("health"))))
	_note("own.shield", int(float(player.get("item_shield_hp"))))
	_note("own.ride_host", int(player.get("cadi_ride_host_peer")))
	_note("scene.smoke_copies", _group_count("cadi_smokes", false))
	_note("scene.smoke_own", _group_count("cadi_smokes", true))
	for p in [0, 1, 3, 4]:
		_note("scene.zone%d_copy" % (p + 1), _group_count("cadi_zones", false, p) > 0)
		_note("scene.zone%d_own" % (p + 1), _group_count("cadi_zones", true, p) > 0)
	if _role == "client":
		_note("own.q", bool(player.get("_cadi_q_active")))
		_note("own.broom", bool(player.get("_cadi_broom_active")))
		_note("own.charges", int(player.get("cadi_r_charges")))
		_note("own.riders", _riders(int(player.call("cadi_peer"))))
		if rp != null:
			## kukla = host'un Hadime'si (yolcu)
			_note("pup.ride_host", int(rp.get("cadi_ride_host_peer")))
			_note("pup.dist", int(player.global_position.distance_to(rp.global_position)))
			var a: Variant = rp.get("anim")
			if a is AnimatedSprite2D:
				_note("pup.ride_clip", String((a as AnimatedSprite2D).animation).begins_with("ride_"))
	else:
		var st: Dictionary = _enemy_stats()
		_note("host.enemies", int(st["n"]))
		_note("host.mad", int(st["mad"]))
		_note("host.frozen", int(st["frozen"]))
		_note("host.feared", int(st["feared"]))
		_note("host.enemy_hp_lost", int(float(st["lost"]) / 50.0) * 50)
		if rp != null:
			## kukla = istemcinin Cadı'sı
			_note("pup.q", bool(rp.get("_cadi_q")))
			_note("pup.potion_node", rp.get_node_or_null("CadiPotion") != null)
			_note("pup.broom", bool(rp.call("is_cadi_broom_active")))
			var a2: Variant = rp.get("anim")
			if a2 is AnimatedSprite2D:
				_note("pup.broom_node", (a2 as AnimatedSprite2D).get_node_or_null("CadiBroom") != null)
				_note("pup.ride_clip", String((a2 as AnimatedSprite2D).animation).begins_with("ride_"))
				_note("pup.lifted", (a2 as AnimatedSprite2D).offset.y < float(Vector2(rp.get("cadi_base_offset")).y) - 0.5)
			_note("pup.riders", _riders(int(rp.get("peer_id"))))
			_note("own.seat_dist", int(player.global_position.distance_to(rp.global_position)))


func _riders(witch_peer: int) -> int:
	var cm: GDScript = load("res://scripts/cadi_math.gd") as GDScript
	return (cm.riders_of(self, witch_peer) as Array).size()


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
		if not _nm.call("join_lan", "127.0.0.1", _port, "Client", CADI):
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
	if _role == "host":
		## Host (yolcu) cadıdan uzakta başlar - süpürge açılınca yanına gelir.
		var p: Vector2 = player.global_position + Vector2(-260, 0)
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
	_log("karakter %s, peer %s" % [str(_gm.get("selected_char_id")), str(root.get_multiplayer().get_unique_id())])
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	_t0 = Time.get_ticks_msec()
	var did: Dictionary = {}
	var total: float = 34.0
	player.set("item_shield_max", 4000.0)
	player.set("max_health", 100000.0)
	player.set("damage_bonus", 200.0)
	player.set("health", 100000.0)
	var throws: int = 0
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
			## ---- Cadı (kaster, host DEĞİL)
			player.set("item_shield_hp", 4000.0)
			player.set("health", 100000.0)
			Input.action_release("move_right")
			if el > 3.0 and not did.has("q_on"):
				did["q_on"] = true
				player.set("skill_state", "ready")
				player.call("_cadi_toggle_q")
				_events.append([el, "ev.Q_on", bool(player.get("_cadi_q_active"))])
			if (el > 3.2 and el < 6.5) or (el > 21.0 and el < 23.5):
				Input.action_press("move_right")
			if el > 8.0 and not did.has("q_off"):
				did["q_off"] = true
				player.call("_cadi_end_q")
			## 5 iksir sırayla (0,7 sn arayla): Delilik, Don, Patlama, Şifa, Korku
			if el > 10.0 + throws * 0.7 and throws < 5:
				player.set("_cadi_r_lock", 0.0)
				player.set("_cadi_next_potion", throws)
				player.call("_cadi_try_throw")
				_events.append([el, "ev.throw", throws + 1])
				throws += 1
			if el > 19.0 and not did.has("e"):
				did["e"] = true
				player.set("skill2_state", "ready")
				player.call("_activate_skill2")
				_events.append([el, "ev.E", bool(player.get("_cadi_broom_active"))])
		else:
			## ---- Hadime (host, yolcu)
			Input.action_release("move_left")
			if el < 19.0:
				player.set("health", 100000.0)
				player.set("item_shield_hp", 4000.0)
			if el > 1.0 and not did.has("enemies") and spawner and rp != null:
				did["enemies"] = true
				var roster: Array = spawner.call("_spawnable_roster", 2)
				var n: int = int(spawner.call("debug_spawn_creature", roster[0], 2, 12, rp.global_position + Vector2(70, 0)))
				for e in get_nodes_in_group("enemies"):
					e.set("max_health", 1.0e7)
					e.set("health", 1.0e7)
				_events.append([el, "ev.enemies", n])
			## Süpürge açılınca canı/kalkanı düşür (yenilenme görülsün) ve cadıya değ.
			if el > 19.6 and not did.has("touch") and rp != null and bool(rp.call("is_cadi_broom_active")):
				did["touch"] = true
				player.set("health", 50000.0)
				player.set("item_shield_hp", 1000.0)
				player.global_position = rp.global_position + Vector2(8, 0)
				_events.append([el, "ev.touch", true])
			## Yolculuğun sonunda hareket edip iner (ilk 1 sn inilemez - çoktan geçti).
			if el > 24.5 and el < 25.5:
				Input.action_press("move_left")
		_sample(player)
		await process_frame
	Input.action_release("move_right")
	Input.action_release("move_left")
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
		if str(ev[1]) in ["own.ride_host", "pup.ride_host", "pup.riders", "own.riders", "pup.broom", "own.broom", "pup.q", "own.q", "own.charges"]:
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
