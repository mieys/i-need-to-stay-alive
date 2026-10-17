extends SceneTree

## Son eklenen kozmetik/durum senkronlarının denetimi (CLAUDE.md madde 97-107): iki gerçek süreç (host = Matthew + Kelebek Ruhu, istemci = Talon + Peri; başsız LAN).
## Her tarafta KENDİ durumu ve DİĞER oyuncunun kuklasında gördüğü durum değiştiği anda kaydedilir ("kendi" vs "kukla" aynı zaman çizelgesinde).
## Matthew: Elektrik Topu / Yıldırım Kalkanı parıltısı / izi / şimşek efekti / Kelebek Ruhu kuklası + atışı. Talon: Silah Salvosu zincirleri, Ayna Formu boyaması, Peri kuklası + büyü.
## MP_ROLE=host|client MP_DIR MP_PORT. Sonuç: <rol>.json (newfx_audit_compare.py özetler). run_audit.ps1 -Mode newfx.

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _events: Array = [] ## [t, anahtar, değer]
var _last: Dictionary = {}
var _t0: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _now() -> float:
	return snappedf(float(Time.get_ticks_msec() - _t0) / 1000.0, 0.01)


## Değer değiştiyse kaydet.
func _note(key: String, value: Variant) -> void:
	if _last.has(key) and _last[key] == value:
		return
	_last[key] = value
	_events.append([_now(), key, value])


func _count_script(n: Node, frag: String, depth: int) -> int:
	var c: int = 0
	var s: Variant = n.get_script()
	if s != null and (s as Script).resource_path.contains(frag):
		c += 1
	elif n.scene_file_path.contains(frag):
		c += 1
	if depth > 0:
		for ch in n.get_children():
			c += _count_script(ch, frag, depth - 1)
	return c


func _find_script_child(n: Node, frag: String) -> Node:
	for ch in n.get_children():
		var s: Variant = ch.get_script()
		if s != null and (s as Script).resource_path.contains(frag):
			return ch
	return null


func _sample_own(player: Node2D) -> void:
	_note("own.hp", int(float(player.get("health"))))
	_note("own.parrot", player.get_node_or_null("KorsanParrot") != null)
	_note("own.dog", is_instance_valid(player.get("_matthew_pet")))
	if _role == "host":
		_note("own.ball", bool(player.get("_matthew_ball_active")))
		_note("own.dome", bool(player.get("matthew_dome_active")))
		var kel: Node = player.get_node_or_null("KelebekRuhu")
		_note("own.kelebek", kel != null)
	else:
		_note("own.salvo", bool(player.get("_talon_weapon_salvo_active")))
		_note("own.form", bool(player.get("_talon_mirror_form_active")))
		_note("own.peri", player.get_node_or_null("Peri") != null)
		var own_kirpi: Node = player.get_node_or_null("Kirpi")
		_note("own.kirpi", own_kirpi != null)
		if own_kirpi != null:
			_note("own.kirpi_open", bool(own_kirpi.call("is_open")))
		var pc: Node = _find_script_child(player, "fx_talon_chains")
		_note("own.chains", pc != null)


func _sample_puppet() -> void:
	var rp: Node = null
	for r in get_nodes_in_group("remote_players"):
		rp = r
	if rp == null:
		return
	_note("pup.parrot", rp.get_node_or_null("KorsanParrot") != null)
	var pv: Variant = rp.get("_pet_visuals")
	_note("pup.dog", pv is Dictionary and (pv as Dictionary).size() > 0)
	if _role == "client":
		## kukla = host'un Matthew'u
		_note("pup.kelebek", rp.get_node_or_null("KelebekRuhu") != null)
		var kel: Node = rp.get_node_or_null("KelebekRuhu")
		if kel != null:
			_note("pup.kelebek_bolts", int(kel.get("_bolts")))
		_note("pup.ball", int(rp.get("_matthew_ball")))
		_note("pup.glow", int(rp.get("_matthew_glow_step")))
		_note("pup.empowered", bool(rp.get("_matthew_empowered")))
		_note("pup.trail", is_instance_valid(rp.get("_matthew_trail")))
		var a: Variant = rp.get("anim")
		if a is AnimatedSprite2D:
			_note("pup.glow_material", (a as AnimatedSprite2D).material != null)
			_note("pup.anim_visible", (a as AnimatedSprite2D).visible)
		## şimşek / kıvılcım / nova efekt düğümleri (sahnede + kuklada)
		var bolts: int = _count_script(current_scene, "fx_matthew_bolt", 1) + _count_script(rp, "fx_matthew_bolt", 2)
		_note("pup.bolt_nodes>0", bolts > 0)
		_note("pup.shield_ring", _count_script(rp, "fx_matthew_lightning_shield", 2) > 0)
		_note("pup.nova", _count_script(current_scene, "fx_matthew_nova", 1) > 0)
	else:
		## kukla = istemcinin Talon'u
		_note("pup.peri", rp.get_node_or_null("Peri") != null)
		var pup_kirpi: Node = rp.get_node_or_null("Kirpi")
		_note("pup.kirpi", pup_kirpi != null)
		if pup_kirpi != null:
			_note("pup.kirpi_open", bool(pup_kirpi.call("is_open")))
		var peri: Node = rp.get_node_or_null("Peri")
		if peri != null and peri.get("_sprite") is AnimatedSprite2D:
			_note("pup.peri_anim", String((peri.get("_sprite") as AnimatedSprite2D).animation).begins_with("cast"))
		_note("pup.peri_heal_fx", rp.get_node_or_null("PeriHealFx") != null)
		_note("pup.formation", str(rp.get("_talon_formation")))
		_note("pup.form", bool(rp.get("_talon_form_active")))
		var chains: Node = _find_script_child(rp, "fx_talon_chains")
		_note("pup.chains", chains != null)
		if chains != null:
			var ropes: Variant = chains.get("_rope_x")
			var linked: int = 0
			if ropes is Array:
				for x in (ropes as Array):
					if (x as PackedVector2Array).size() > 0:
						linked += 1
			_note("pup.rope_count", linked)
		var form: Node = _find_script_child(rp, "fx_talon_form")
		_note("pup.form_fx", form != null)
		var a2: Variant = rp.get("anim")
		if a2 is AnimatedSprite2D:
			_note("pup.form_material", (a2 as AnimatedSprite2D).material is ShaderMaterial)
		_note("pup.scale", snappedf(rp.scale.x, 0.01))


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	## Evcil hayvan seçimi (menüde yerel tercih olarak yazılan alan): oyun kurulmadan ÖNCE.
	## MP_HOST_PET / MP_CLIENT_PET ile değiştirilebilir (kopek|papagan|kelebek|peri|kirpi).
	var host_pet: String = OS.get_environment("MP_HOST_PET") if OS.get_environment("MP_HOST_PET") != "" else "kelebek"
	var client_pet: String = OS.get_environment("MP_CLIENT_PET") if OS.get_environment("MP_CLIENT_PET") != "" else "peri"
	_gm.set("selected_pet", host_pet if _role == "host" else client_pet)
	if _role == "host":
		if not _nm.call("host_lan", _port, "Host", 3):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2 and _nm.call("all_players_ready"), 40.0)
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0)
		if not _nm.call("join_lan", "127.0.0.1", _port, "Client", 1):
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
	player.call("buy_weapon_copy", "tufek", 2)
	if _role == "client":
		var p: Vector2 = player.global_position + Vector2(300, 0)
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
	_log("pet: %s, kimlik %s" % [str(player.get("_pet_kind")), str(_gm.get("selected_char_id"))])
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	_t0 = Time.get_ticks_msec()
	var did: Dictionary = {}
	var total: float = 36.0
	player.set("item_shield_max", 4000.0)
	if _role == "client":
		player.set("max_health", 1000.0)
		player.set("health", 400.0) ## Peri can eksikken basar
		player.set("damage_bonus", 300.0) ## +30 can / büyü: iyileşme gözle görülür
	while true:
		paused = false
		var el: float = float(Time.get_ticks_msec() - _t0) / 1000.0
		if el >= total:
			break
		if spawner:
			spawner.set("_spawn_timer", 1.0e9)
		player.set("item_shield_hp", 4000.0)
		if _role == "host":
			player.set("max_health", 1.0e9)
			player.set("health", 1.0e9)
			Input.action_release("move_right")
			if el > 2.0 and el < 9.0:
				Input.action_press("move_right")
			if el > 1.0 and not did.has("enemies") and spawner:
				did["enemies"] = true
				var roster: Array = spawner.call("_spawnable_roster", 3)
				var n: int = int(spawner.call("debug_spawn_creature", roster[0], 3, 14, player.global_position + Vector2(160, 0)))
				_events.append([el, "ev.enemies", n])
			if el > 4.0 and not did.has("q"):
				did["q"] = true
				player.call("_activate_skill")
				_events.append([el, "ev.Q", str(player.get("skill_state"))])
			if el > 9.5 and not did.has("e"):
				did["e"] = true
				player.call("_activate_skill2")
				_events.append([el, "ev.E", str(player.get("skill2_state"))])
			if el > 18.0 and not did.has("r"):
				did["r"] = true
				player.call("_activate_skill3")
				_events.append([el, "ev.R", str(player.get("skill3_state"))])
			if el > 22.0 and not did.has("dome_dmg"):
				did["dome_dmg"] = true
				player.set("matthew_dome_hp", float(player.get("matthew_dome_max")) * 0.3) ## parıltı basamağı artmalı
		else:
			if el > 6.0 and not did.has("e"):
				did["e"] = true
				player.call("_activate_skill2")
				_events.append([el, "ev.E", str(player.get("skill2_state"))])
			if el > 18.0 and not did.has("r"):
				did["r"] = true
				player.call("_activate_skill3")
				_events.append([el, "ev.R", str(player.get("skill3_state"))])
		_sample_own(player)
		_sample_puppet()
		await process_frame
	Input.action_release("move_right")
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "events": _events}))
	out.close()
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
