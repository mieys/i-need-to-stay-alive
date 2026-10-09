extends SceneTree

## MINOTAUR (Kademe 3 bossu, CLAUDE.md madde 40) çok oyunculu denetimi: iki gerçek süreç (host = Assasin, istemci = Vampir; başsız LAN, GERÇEK Main + gerçek harita).
## Host, gerçek bossu (spawner _setup_boss_enemy ile) istemcinin oyuncusunun yakınında doğurur; istemcinin oyuncusu hareketsiz durur ve boss ona hücum eder.
## HER İKİ tarafta kare kare kaydedilir: bossun konumu (host'ta gerçeği, istemcide kuklası), poz (_pose_override), istemcideki ağ hızı tavanı, uyarı şeridi düğümü sayısı;
## istemcinin KENDİ oyuncusu için: can+kalkan (hasar işlendi mi), konum (savrulma) ve duvar hücresinde olup olmadığı. minotaur_audit_compare.py karşılaştırır.
## MP_ROLE=host|client MP_DIR MP_PORT MP_SECS. Sonuç: <rol>.json

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _secs: float = float(OS.get_environment("MP_SECS")) if OS.get_environment("MP_SECS") != "" else 45.0
var _nm: Node
var _gm: Node
var _samples: Array = [] ## [t, bx, by, pose, cap, lanes, px, py, hp, in_wall]
var _events: Array = []
var _target_host: bool = OS.get_environment("MP_MINO_TARGET") == "host" ## 1: boss HOST'un kendi oyuncusuna hücum eder (yerel hasar + yerel savrulma yolu); varsayılan: istemciye (uzak yol)


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _player() -> Node2D:
	return current_scene.get_node_or_null("Player") as Node2D if current_scene else null


func _boss() -> Node2D:
	for e in get_nodes_in_group("boss"):
		if is_instance_valid(e) and e.get("is_dead") != true:
			return e as Node2D
	return null


func _lane_count() -> int:
	var n: int = 0
	if current_scene == null:
		return 0
	for c in current_scene.get_children():
		var sc: Variant = c.get_script()
		if sc != null and str((sc as Script).resource_path).ends_with("enemy_charge_lane.gd"):
			n += 1
	return n


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	if _role == "host":
		if not _nm.call("host_lan", _port, "Host", 5):
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
	## Her iki oyuncu da ölmesin (hasar gözlenir ama oyun bitmesin).
	player.set("max_health", 1.0e7)
	player.set("health", 1.0e7)
	if _role == "host":
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
		await _wait(1.0) ## istemci kendi oyuncusunu sabitlemiş olsun
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9) ## rastgele doğuş yok
	var t0: int = Time.get_ticks_msec()
	var start_pos: Vector2 = player.global_position
	var did: Dictionary = {}
	var last_pose: int = -1
	var last_health: float = float(player.get("health")) + float(player.get("item_shield_hp"))
	var wall_ever: bool = false
	var start_in_wall: bool = bool(_gm.call("is_position_blocked_by_walls", player.global_position))
	while Time.get_ticks_msec() - t0 < int(_secs * 1000.0):
		paused = false
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if spawner:
			spawner.set("_spawn_timer", 1.0e9)
		var hp_now: float = float(player.get("health")) + float(player.get("item_shield_hp"))
		if hp_now < last_health - 0.5:
			_events.append({"t": snappedf(el, 0.01), "e": "client_damaged" if _role == "client" else "host_damaged", "amount": snappedf(last_health - hp_now, 0.1)})
		last_health = hp_now
		if float(player.get("health")) < 9.0e6:
			player.set("health", 1.0e7) ## ölmesin: ama hasar önce ÖLÇÜLDÜ (yukarıda), sonra yenilenir
			last_health = float(player.get("health")) + float(player.get("item_shield_hp"))
		if _target_host and _role == "client" and el > 1.0 and not did.has("away"):
			did["away"] = true
			player.global_position += Vector2(-1100.0, 0.0) ## istemci kendi oyuncusunu uzağa alır: boss en yakın hedef olarak HOST'u seçsin
			_events.append({"t": el, "e": "client_moved_away"})
		if _role == "host":
			## Host oyuncusu bossun ilgisinden uzak dursun: istemcinin 1100 px batısına ışınlanır (boss en yakın hedefi seçer = istemci).
			if el > 1.0 and not did.has("away") and not _target_host:
				did["away"] = true
				var rp: Node2D = null
				for r in get_nodes_in_group("remote_players"):
					rp = r as Node2D
				if rp != null:
					player.global_position = rp.global_position + Vector2(-1100.0, 0.0)
					_events.append({"t": el, "e": "host_moved_away"})
			## Boss: istemcinin oyuncusunun yakınında açık bir noktada doğur.
			if el > 4.0 and not did.has("boss") and spawner:
				var rp2: Node2D = player if _target_host else null
				for r2 in get_nodes_in_group("remote_players"):
					if not _target_host:
						rp2 = r2 as Node2D
				if rp2 != null:
					var spot: Variant = _open_spot(rp2.global_position)
					if spot != null:
						did["boss"] = true
						var nid: int = int(spawner.get("_next_network_enemy_id"))
						spawner.set("_next_network_enemy_id", nid + 1)
						var b: Node = spawner.call("_spawn_creature", "minotaur1", spot, nid)
						b.add_to_group("boss")
						spawner.call("_setup_boss_enemy", b, "minotaur1", 3)
						spawner.call("_announce_spawn", b, "minotaur1", spot, 3, true, nid, true, false)
						spawner.set("_boss_tiers_spawned", {3: true})
						_events.append({"t": el, "e": "boss_spawned", "x": spot.x, "y": spot.y, "hp": float(b.get("max_health")), "shield": float(b.get("item_shield_max"))})
		if (_role == "client") != _target_host:
			## Hedef oyuncu (varsayılan: istemci; MP_MINO_TARGET=host: host) 9 sn'den sonra dört yöne dönüşümlü yürür: boss geride kalıp uzaktan hücum etsin (yakındayken hücum yok, bkz. RANGE_MIN).
			for a in ["move_right", "move_left", "move_down", "move_up"]:
				Input.action_release(a)
			if el > 9.0:
				var phase: int = int((el - 9.0) / 2.2) % 6
				var acts: Array = ["move_right", "move_right", "move_down", "move_left", "move_left", "move_up"]
				Input.action_press(acts[phase])
		var boss: Node2D = _boss()
		var in_wall: bool = bool(_gm.call("is_position_blocked_by_walls", player.global_position))
		if in_wall and not start_in_wall:
			wall_ever = true
		if boss != null:
			var pose: int = int(boss.get("_pose_override"))
			if pose != last_pose:
				last_pose = pose
				_events.append({"t": snappedf(el, 0.01), "e": "pose", "pose": pose, "cap": float(boss.get("_net_speed_cap_override")), "x": snappedf(boss.global_position.x, 0.1), "y": snappedf(boss.global_position.y, 0.1)})
			_samples.append([snappedf(el, 0.001), snappedf(boss.global_position.x, 0.1), snappedf(boss.global_position.y, 0.1), pose,
					float(boss.get("_net_speed_cap_override")), _lane_count(), snappedf(player.global_position.x, 0.1), snappedf(player.global_position.y, 0.1), hp_now, in_wall])
		await process_frame
	for a2 in ["move_right", "move_left", "move_down", "move_up"]:
		Input.action_release(a2)
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "samples": _samples, "events": _events, "start_pos": [start_pos.x, start_pos.y], "wall_ever": wall_ever, "start_in_wall": start_in_wall}))
	out.close()
	_log("bitti: %d örnek, %d olay, duvara girdi=%s" % [_samples.size(), _events.size(), wall_ever])
	await _wait(2.0)
	quit()


## center çevresinde (320 px) engelsiz, merkezle arası açık bir nokta ara.
func _open_spot(center: Vector2) -> Variant:
	for dist in [320.0, 280.0, 360.0, 240.0]:
		for i in range(16):
			var ang: float = TAU * float(i) / 16.0
			var p: Vector2 = center + Vector2.from_angle(ang) * dist
			if bool(_gm.call("is_position_blocked_by_terrain", p)):
				continue
			var clear: bool = true
			for k in range(1, 12):
				if bool(_gm.call("is_position_blocked_by_walls", center.lerp(p, float(k) / 12.0))):
					clear = false
					break
			if clear:
				return p
	return null


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
