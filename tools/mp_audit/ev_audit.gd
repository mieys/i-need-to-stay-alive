extends SceneTree

## Çok oyunculu denetim: EV KUŞATMASI + AÇILIŞ (madde 313). İki süreç (host + istemci), ikisi de evde başlar.
##  - Açılış: host evreyi elle ilerletir (huzur -> geri sayım -> saldırı) - istemci aynı evreyi alıyor mu, invasion_pending iki tarafta
##    kalkıyor mu; host 0. sırada (koltukta oturur): istemcideki kuklası ride_ klibini oynuyor mu.
##  - Kuşatma: host dışarı çıkar, istemci içeride kalır -> host'ta 10 sn sonra saldırı (istemcide under_attack + çatlak), host canı kısar ->
##    yıkılış: istemci dışarı atılıyor mu, babaanne iki tarafta dışarıda + hedef mi.
##  - Babaanne: host yanına yaratık doğurur (oyuncular uzakta) -> yaratık vuruşuyla babaanne canı iki tarafta aynı düşüyor mu; sonra
##    öldürülür -> iki tarafta kalıcı ölüm; host onarır -> istemcide ev yeniden açık.
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_audit.ps1 -Mode ev

const MATTHEW := 4
const ELARA := 6

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _events: Array = []
var _last: Dictionary = {}
var _first_true: Dictionary = {}
var _min: Dictionary = {}
var _t0: int = 0
var _gpos0: Vector2 = Vector2.INF
var _gpos_t: float = -1.0
var _bes_t: float = -1.0


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
		_min[key] = minf(float(_min.get(key, 1.0e18)), float(value))
	if _last.has(key) and _last[key] == value:
		return
	_last[key] = value
	_events.append([_now(), key, value])


func _sample(player: Node2D, house: Node) -> void:
	var intro: Node = house.call("get_intro")
	var siege: Node = house.call("get_siege")
	var bab: Node = house.call("get_babaanne")
	var fx: Node = house.call("get_damage_fx")
	_note("intro.phase", int(intro.get("phase")))
	_note("invasion_pending", bool(_gm.get("invasion_pending")))
	_note("game_time>0", float(_gm.get("game_time")) > 0.5)
	var a: Variant = player.get("anim")
	if a is AnimatedSprite2D:
		_note("own.ride", String((a as AnimatedSprite2D).animation).begins_with("ride_"))
	for r in get_nodes_in_group("remote_players"):
		var a2: Variant = r.get("anim")
		if a2 is AnimatedSprite2D:
			_note("pup.ride", String((a2 as AnimatedSprite2D).animation).begins_with("ride_"))
	_note("own.indoors", bool(player.get("is_indoors")))
	_note("siege.hp", int(float(siege.get("hp"))))
	_note("siege.attack", bool(siege.get("under_attack")))
	_note("siege.collapsed", bool(siege.get("collapsed")))
	if fx != null:
		_note("fx.cracks", int(fx.call("visible_crack_count")))
	_note("granny.hp", int(float(siege.get("granny_hp"))))
	## kuşatmacılar: evin 420 px yakınındaki yaratık sayısı (yarım saniyede bir)
	var hr: Rect2 = house.get("exterior_house_rect")
	if hr.size != Vector2.ZERO and _now() - _bes_t >= 0.5:
		_bes_t = _now()
		var near: int = 0
		for e in get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e is Node2D and e.get("is_dead") != true and (e as Node2D).global_position.distance_to(hr.get_center()) <= 420.0:
				near += 1
		_events.append([_now(), "bes", near])
		_note("besiege.any", near > 0)
	_note("granny.dead", bool(siege.get("granny_dead")))
	_note("granny.dead_flag", bool(_gm.get("babaanne_dead")))
	if bab != null and is_instance_valid(bab):
		_note("granny.outside", bool(bab.get("outside")))
		_note("granny.npc_dead", bool(bab.get("is_dead")))
		## kaçış (host yürütür, istemci izler): yarım saniyede bir ayak konumu -> iki tarafın konumu karşılaştırılır
		if bool(bab.get("outside")) and not bool(bab.get("is_dead")):
			var fw: Vector2 = bab.call("feet_world")
			if not _gpos0.is_finite():
				_gpos0 = fw
			_note("granny.fled", fw.distance_to(_gpos0) > 40.0)
			if _now() - _gpos_t >= 0.5:
				_gpos_t = _now()
				var nd: float = 1.0e9
				for e in get_nodes_in_group("enemies"):
					if is_instance_valid(e) and e is Node2D and e.get("is_dead") != true:
						nd = minf(nd, (e as Node2D).global_position.distance_to(fw))
				_events.append([_now(), "gpos", [snappedf(fw.x, 0.1), snappedf(fw.y, 0.1), int(nd)]])
	_note("granny.target", is_instance_valid(_gm.get("babaanne_target")))


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
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
	if house == null or player == null or house.call("get_siege") == null:
		_log("HATA ev/oyuncu yok"); quit(1); return
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	if _role == "host":
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
	_log("peer %s, açılış evresi %s" % [str(root.get_multiplayer().get_unique_id()), str(house.call("get_intro").get("phase"))])
	var intro: Node = house.call("get_intro")
	var siege: Node = house.call("get_siege")
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	_t0 = Time.get_ticks_msec()
	var did: Dictionary = {}
	var collapse_t: float = -1.0
	var total: float = 64.0
	player.set("max_health", 100000.0)
	player.set("health", 100000.0)
	while true:
		paused = false
		var el: float = float(Time.get_ticks_msec() - _t0) / 1000.0
		if el >= total:
			break
		player.set("health", 100000.0)
		if spawner:
			spawner.set("_spawn_timer", 1.0e9) ## doğal doğuş yok: babaanneye yalnız denetimin doğurduğu yaratıklar
		if bool(siege.get("collapsed")) and collapse_t < 0.0:
			collapse_t = el
			_events.append([el, "ev.collapse_seen", true])
		if _role == "host":
			if el > 3.0 and not did.has("countdown"):
				did["countdown"] = true
				intro.call("_host_advance", 2) ## Phase.COUNTDOWN
				_events.append([el, "ev.countdown", true])
			if el > 8.0 and not did.has("done"):
				did["done"] = true
				intro.call("_host_advance", 3) ## Phase.DONE
				_events.append([el, "ev.attack_begins", true])
			if el > 9.0 and not did.has("out"):
				did["out"] = true
				house.call("_do_exit_house")
				player.global_position += Vector2(700.0, 0.0) ## yaratıklar babaanneyi seçsin diye uzakta
				_events.append([el, "ev.host_out", true])
			if bool(siege.get("under_attack")) and not did.has("cut"):
				did["cut"] = true
				siege.set("hp", 12.0) ## 5 dk beklemeyelim: 12 sn'de yıkılır
				_events.append([el, "ev.hp_cut", true])
			if collapse_t > 0.0 and el > collapse_t + 2.0 and not did.has("spawned"):
				did["spawned"] = true
				var g: Node2D = _gm.get("babaanne_target") as Node2D
				if spawner and g != null:
					## MP_EV_TIER: hangi kademenin yaratığı (1 = en yavaş slime ~38 px/sn takip; babaanne 40 px/sn kaçar)
					var tier: int = int(OS.get_environment("MP_EV_TIER")) if OS.get_environment("MP_EV_TIER") != "" else 1
					var roster: Array = spawner.call("_spawnable_roster", tier)
					var n: int = int(spawner.call("debug_spawn_creature", roster[0], tier, 4, g.global_position + Vector2(70.0, 0.0)))
					_events.append([el, "ev.enemies", [n, str(roster[0])]])
			if collapse_t > 0.0 and el > collapse_t + 14.0 and not did.has("kill"):
				did["kill"] = true
				var g2: Node = house.call("get_babaanne")
				if g2 != null and not bool(g2.get("is_dead")):
					g2.call("take_damage", 500.0, null)
				_events.append([el, "ev.kill", true])
			if collapse_t > 0.0 and el > collapse_t + 18.0 and not did.has("repair"):
				did["repair"] = true
				for e in get_nodes_in_group("enemies"):
					if e.has_method("dismiss_without_reward"):
						e.call("dismiss_without_reward")
				siege.set("test_combat", 1)
				siege.set("hp", 0.4 * 300.0 - 1.0)
				_events.append([el, "ev.repair", true])
		else:
			## istemci içeride bekler (evi yıpratan); dışarı atılınca uzaklaşır
			if collapse_t > 0.0 and not bool(player.get("is_indoors")) and not did.has("away"):
				did["away"] = true
				player.global_position += Vector2(-700.0, 0.0)
				_events.append([el, "ev.client_ejected", true])
		_sample(player, house)
		await process_frame
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "events": _events}))
	out.close()
	var keys: Array = _first_true.keys()
	keys.sort()
	for k in keys:
		_log("ÖZET ilk doğru  %-20s %.2f sn" % [str(k), float(_first_true[k])])
	for k in ["siege.hp", "granny.hp"]:
		_log("ÖZET en küçük  %-20s %s" % [k, str(_min.get(k, "-"))])
	for ev in _events:
		var key: String = str(ev[1])
		if key.begins_with("ev.") or key in ["intro.phase", "invasion_pending", "siege.collapsed", "granny.outside", "granny.dead",
				"granny.target", "own.indoors", "pup.ride", "own.ride", "siege.attack"]:
			_log("ÖZET olay %.2f %s = %s" % [float(ev[0]), key, str(ev[2])])
		elif key == "granny.hp":
			_log("ÖZET can %.2f granny.hp = %s" % [float(ev[0]), str(ev[2])])
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
