extends SceneTree

## Şovalye E (Koruma Bariyeri) hasar aktarımı + Ruhani "Kalkan Bağı" yansıması denetimi (2026-10-10, kullanıcı: "kalkan bağı doğru çalışmıyor, hiç etkisini
## görmedim" + "Şovalye'nin E'si arkadaşlarının hasarını emmiyor"). İki gerçek süreç (host, istemci; başsız LAN), yaratık doğumu kapalı.
##  A) host E'yi açar (_skill_paladin_barrier; karakterden bağımsız işlev) -> istemcinin KALKANI DOLUYKEN 100 hasar alması: istemci ~70 kaybetmeli,
##     host ~30 almalı (eskiden kalkan hasarı yuttuğu için aktarım SIFIRDI).
##  B) istemci Kalkan Bağı kurar -> istemcinin doğal kalkan yenilenmesi (regen tikleri) host'a yansımalı. Host'un KENDİ yenilenmesi durdurulur
##     (item_shield_regen_delay) - host kalkanındaki artış yalnız bağdan gelir (eskiden doğal yenilenme yansımıyordu -> 0).
## MP_ROLE=host|client MP_DIR MP_PORT. Sonuç: <rol>.json + "MP[...] SONUC" satırları.

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7841
var _nm: Node
var _events: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _player() -> Node2D:
	return current_scene.get_node_or_null("Player") as Node2D if current_scene else null


func _pool(p: Node) -> float:
	return float(p.get("health")) + float(p.get("item_shield_hp"))


func _flag(n: String) -> void:
	FileAccess.open(_dir.path_join(n), FileAccess.WRITE).close()


func _has(n: String) -> bool:
	return FileAccess.file_exists(_dir.path_join(n))


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
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
	var p: Node2D = _player()
	if p == null:
		_log("HATA Player yok"); quit(1); return
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	## Yan yana dur (ikisi de aynı noktaya yakın), dayanıklı ol, yaratık doğmasın.
	p.global_position = Vector2(3000, 2000) + (Vector2(0, 0) if _role == "host" else Vector2(60, 0))
	p.set("max_health", 100000.0)
	p.set("health", 100000.0)
	p.set("item_shield_max", 1000.0)
	p.set("item_shield_hp", 1000.0)
	if _role == "host":
		_flag("ready.flag")
	else:
		await _until(func(): return _has("ready.flag"), 30.0)
	var t0: int = Time.get_ticks_msec()
	var res := {}
	while Time.get_ticks_msec() - t0 < 30000:
		paused = false
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		var sp: Node = current_scene.get_node_or_null("EnemySpawner") if current_scene else null
		if sp:
			sp.set("_spawn_timer", 1.0e9)
		for e in get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.has_method("dismiss_without_reward") and _role == "host":
				e.call("dismiss_without_reward")
		p.global_position = Vector2(3000, 2000) + (Vector2(0, 0) if _role == "host" else Vector2(60, 0))
		# ---------------- A) Şovalye E
		if _role == "host" and el > 2.0 and not res.has("e_on"):
			res["e_on"] = true
			p.call("_skill_paladin_barrier")
			res["a_before"] = _pool(p) ## taban: host'ta yaratık yok, havuz sabit
			_flag("e_on.flag")
		if _role == "host" and _has("a_hit.flag") and not res.has("a_t"):
			res["a_t"] = el
		if _role == "host" and res.has("a_t") and el > float(res["a_t"]) + 2.0 and not res.has("a_after"):
			res["a_after"] = _pool(p)
			res["host_took"] = float(res["a_before"]) - float(res["a_after"])
			_log("SONUC A host (Şovalye) aktarılan hasar: %.1f (beklenen ~30)" % float(res["host_took"]))
			p.call("_end_paladin_barrier")
			_flag("a_done.flag")
		if _role == "client" and _has("e_on.flag") and not res.has("a_hit") and el > 4.0:
			res["a_hit"] = true
			p.set("_last_damage_taken_at_msec", -999999)
			p.set("item_shield_hp", 1000.0)
			var redirect: float = float(p.get("damage_redirect_percent"))
			var before: float = _pool(p)
			p.call("take_damage", 100.0)
			res["client_took"] = before - _pool(p)
			_log("SONUC A istemci: bariyer oranı %.2f, kalkanı DOLUYKEN 100 hasardan kaybedilen: %.1f (beklenen ~70)" % [redirect, float(res["client_took"])])
			await _wait(0.6) ## host'un önceki havuz ölçümünden önce RPC gitsin diye bayrağı hemen yaz
			_flag("a_hit.flag")
		# ---------------- B) Kalkan Bağı
		if _role == "host" and _has("a_done.flag"):
			p.set("item_shield_regen_delay", 1.0e9) ## host'un kendi yenilenmesi DURUR: artış yalnız bağdan
		if _role == "host" and _has("a_done.flag") and not res.has("b_ready"):
			res["b_ready"] = true
			p.set("item_shield_hp", 100.0)
			_flag("b_ready.flag")
		if _role == "client" and _has("b_ready.flag") and not res.has("bond"):
			res["bond"] = true
			p.call("_spirit_cast_kalkan_bagi")
			p.set("item_shield_hp", 200.0)
			res["bond_active"] = bool(p.get("_kalkan_bagi_active"))
			_log("istemci bağ kurdu: aktif=%s" % str(res["bond_active"]))
		if _role == "client" and res.has("bond") and not res.has("regen_done"):
			if not res.has("regen_t"):
				res["regen_t"] = el
				res["regen_given"] = 0.0
			## doğal yenilenme yolunu (regen tiki) besle: 4 sn boyunca saniyede ~40
			if el < float(res["regen_t"]) + 4.0:
				p.set("_shield_regen_tick_pending", float(p.get("_shield_regen_tick_pending")) + 40.0 * 0.016)
			else:
				res["regen_done"] = true
				_flag("regen_done.flag")
		if _role == "host" and _has("b_ready.flag") and not res.has("b_start"):
			res["b_start"] = float(p.get("item_shield_hp"))
		if _role == "host" and _has("regen_done.flag") and not res.has("b_end"):
			await _wait(1.0)
			res["b_end"] = float(p.get("item_shield_hp"))
			res["bond_gain"] = float(res["b_end"]) - float(res["b_start"])
			_log("SONUC B host'un kalkanı (kendi yenilenmesi kapalı) bağdan +%.1f kazandı (beklenen > 0; istemci ~160 yeniledi, pay %%50-80)" % float(res["bond_gain"]))
			_flag("done.flag")
		if _has("done.flag") and el > 3.0:
			break
		await process_frame
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(res))
	out.close()
	_log("bitti")
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
