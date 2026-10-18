extends SceneTree

## ŞOVALYE E (Koruma Bariyeri) + R (kubbe) çok oyunculu denetimi (2026-10-18, madde 251): iki gerçek süreç (başsız LAN).
## İSTEMCİ = Şovalye (id 7, host OLMAYAN oyuncu - CLAUDE.md "yeni efekti HOST OLMAYAN oyuncuyla izle"), HOST = Matthew (id 3, korunan dost + yaratık sahibi).
## Zaman çizelgesi (istemci Şovalye'yi sürer): 2 sn E -> 6 sn host 100 hasar yer (yansıtma: Şovalye'nin canı düşmeli) -> 10 sn R (kubbe) -> 12 sn host kubbenin
## çevresine yaratık doğurur (ELİPS içine girmemeli) -> 26 sn biter. Her iki taraf KENDİ durumunu ve DİĞERİNİN kuklasında gördüğünü değiştiği anda kaydeder.
## Ölçülenler: korunan dostta damage_redirect_*, host'ta asist kaydı (Assist.paladin_support), kuklada paladin_guard/paladin_zone, kubbe görseli,
## kubbe içindeki yaratık sayısı (host gerçek yaratıkları + istemcideki kopyalar). MP_ROLE=host|client MP_DIR MP_PORT. run_audit.ps1 -Mode paladin.

const PaladinDome := preload("res://scripts/paladin_dome.gd")
const AssistScript := preload("res://scripts/assist.gd")

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _events: Array = [] ## [t, anahtar, değer]
var _last: Dictionary = {}
var _t0: int = 0
var _min_u: float = 99.0 ## kubbe aktifken en yakın yaratığın elips-normalize uzaklığı (1 = kenar, <1 = içeride)
var _inside_samples: int = 0


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


func _rp() -> Node2D:
	for r in get_nodes_in_group("remote_players"):
		return r as Node2D
	return null


## Kubbe elipsine göre normalize uzaklık (u < 1 = içeride).
func _ellipse_u(center: Vector2, radius: float, pos: Vector2) -> float:
	var d: Vector2 = pos - center
	var r: Vector2 = PaladinDome.radii(radius)
	return sqrt((d.x / r.x) * (d.x / r.x) + (d.y / r.y) * (d.y / r.y))


func _sample_enemies(center: Vector2, radius: float, tag: String) -> void:
	var best: float = 99.0
	var inside: int = 0
	var alive: int = 0
	for e in get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true or not (e is Node2D):
			continue
		alive += 1
		var u: float = _ellipse_u(center, radius, (e as Node2D).global_position)
		best = minf(best, u)
		if u < 0.9:
			inside += 1
	_min_u = minf(_min_u, best)
	_inside_samples += inside
	_note(tag + ".enemies", alive)
	_note(tag + ".inside", inside)
	if alive > 0:
		_note(tag + ".min_u", snappedf(best, 0.1))


func _sample_own(player: Node2D) -> void:
	_note("own.zone", bool(player.get("paladin_zone_active")))
	_note("own.guard", bool(player.get("paladin_guard_active")))
	_note("own.redirect", snappedf(float(player.get("damage_redirect_percent")), 0.01))
	_note("own.redirect_peer", int(player.get("damage_redirect_peer_id")))
	_note("own.hp", int(float(player.get("health")) / 5.0) * 5)
	_note("own.barrier_node", is_instance_valid(player.get("_paladin_barrier_instance")))


func _sample_puppet() -> void:
	var rp: Node2D = _rp()
	if rp == null:
		_note("pup.exists", false)
		return
	_note("pup.exists", true)
	_note("pup.zone", bool(rp.get("paladin_zone_active")))
	_note("pup.guard", bool(rp.get("paladin_guard_active")))
	_note("pup.guard_fx", is_instance_valid(rp.get("_paladin_guard_fx")))
	_note("pup.barrier_visual", is_instance_valid(rp.get("_barrier_visual")))
	var a: Variant = rp.get("anim")
	if a is AnimatedSprite2D:
		_note("pup.anim_bariyer", String((a as AnimatedSprite2D).animation).begins_with("bariyer_"))
	_note("pup.lev", bool(rp.get("_paladin_lev_on")))
	if _role == "host":
		var cover: Dictionary = AssistScript.paladin_support(self)
		var covered: Array = []
		for k in cover.keys():
			covered.append([int(k), cover[k]])
		_note("host.assist_cover", str(covered))


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
		if not _nm.call("join_lan", "127.0.0.1", _port, "Client", 7):
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
	_log("karakter kimliği: %s" % str(_gm.get("selected_char_id")))
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	_t0 = Time.get_ticks_msec()
	var did: Dictionary = {}
	var total: float = 28.0
	player.set("max_health", 1.0e6)
	player.set("health", 1.0e6)
	player.set("item_shield_max", 5000.0)
	if _role == "host":
		player.set("max_health", 1.0e9)
		player.set("health", 1.0e9)
	var src := Node2D.new() ## darbe kaynağı
	current_scene.add_child(src)
	while true:
		paused = false
		var el: float = float(Time.get_ticks_msec() - _t0) / 1000.0
		if el >= total:
			break
		if spawner and not did.has("spawn_gate"):
			spawner.set("_spawn_timer", 1.0e9)
		player.set("item_shield_hp", 5000.0)
		var rp: Node2D = _rp()
		if _role == "client":
			if el < 5.5 or el > 7.0: ## yansıtılan hasar 6 sn'de ölçülür: o aralıkta canı yenileme
				player.set("health", 1.0e6)
			if el > 0.5 and not did.has("near") and rp != null:
				did["near"] = true
				player.global_position = rp.global_position + Vector2(50, 0)
			if el > 2.0 and not did.has("e"):
				did["e"] = true
				player.call("_activate_skill2")
				_events.append([el, "ev.E", str(player.get("skill2_state"))])
			if el > 10.0 and not did.has("r"):
				did["r"] = true
				player.call("_activate_skill3")
				_events.append([el, "ev.R", str(player.get("skill3_state"))])
			if player.get("paladin_zone_active") == true:
				_sample_enemies(player.global_position, float(player.get("paladin_zone_radius")), "own")
		else:
			Input.action_release("move_right")
			if el > 6.0 and not did.has("hit"):
				did["hit"] = true
				if rp != null:
					src.global_position = player.global_position + Vector2(-60, 0)
					var before: float = float(player.get("health"))
					player.set("_last_damage_taken_at_msec", -100000)
					player.call("take_damage", 100.0, src)
					_events.append([el, "ev.host_hit", snappedf(before - float(player.get("health")), 0.1)])
			if el > 12.0 and not did.has("enemies") and spawner and rp != null:
				did["enemies"] = true
				var roster: Array = spawner.call("_spawnable_roster", 3)
				var total_n: int = 0
				for k in 4:
					var ang: float = TAU * float(k) / 4.0
					total_n += int(spawner.call("debug_spawn_creature", roster[0], 3, 8, rp.global_position + Vector2(cos(ang), sin(ang) * 0.5) * 260.0))
				_events.append([el, "ev.enemies", total_n])
			if rp != null and rp.get("paladin_zone_active") == true:
				_sample_enemies(rp.global_position, float(rp.get("paladin_zone_radius")), "pup")
		_sample_own(player)
		_sample_puppet()
		await process_frame
	Input.action_release("move_right")
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "events": _events}))
	out.close()
	_log("ÖZET kubbe içi örnek toplamı %d, en yakın u %.2f" % [_inside_samples, _min_u])
	for ev in _events:
		_log("ÖZET %.2f %s = %s" % [float(ev[0]), str(ev[1]), str(ev[2])])
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
