extends SceneTree

## Çok oyunculu denetim: HARİTA ANAHTARI (madde 605). Host + istemci (ENet), istemci HOST OLMAYAN oyuncu. Her süreç KENDİ geçici meta kaydını kullanır
## (MetaProgress.set_path_override: kullanıcının gerçek user://meta.cfg'sine dokunmaz).
##   3. sn: host K5 bossu ödülünü verir (GameManager.award_boss_keys(5), enemy.gd die() host kolunun yaptığı çağrı) -> iki tarafta 1 anahtar
##   4,5. sn: host aynı kademeyi tekrar tetikler -> verilmez (kademe başına bir kez)
##   6. sn: host K10 -> iki tarafta +2 (toplam 3); 8. sn: K4 / K11 (sonsuz boss dalgası) -> verilmez
##   11. sn: istemci host OLMADAN "broadcast_boss_keys" RPC'si atar -> HOST kaydı değişmez (_from_host kapısı)
## Ölçülenler (her iki tarafta): keys_granted olayları (harita, adet, zaman), kayıttaki adet, GameManager.run_keys.
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_audit.ps1 -Mode anahtar

const HOST_CHAR := 2
const CLIENT_CHAR := 10

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _meta: GDScript
var _t0: int = 0
var _events: Array = []
var _checks: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _now() -> float:
	return snappedf(float(Time.get_ticks_msec() - _t0) / 1000.0, 0.01)


func _run() -> void:
	await process_frame
	_meta = load("res://scripts/meta_progress.gd") as GDScript
	_meta.call("set_path_override", _dir.path_join("meta_%s.cfg" % _role)) ## yalıtılmış kayıt (iki süreç + kullanıcı kaydı karışmaz)
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	if _role == "host":
		if not _nm.call("host_lan", _port, "Host", HOST_CHAR):
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
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	if _role == "host":
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
	_gm.connect("keys_granted", func(map_id: String, n: int) -> void: _events.append([map_id, n, _now()]))
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	_t0 = Time.get_ticks_msec()
	var did: Dictionary = {}
	while true:
		paused = false
		var el: float = float(Time.get_ticks_msec() - _t0) / 1000.0
		if el >= 14.0:
			break
		if spawner:
			spawner.set("_spawn_timer", 1.0e9)
		for e in get_nodes_in_group("enemies"):
			if not e.is_queued_for_deletion():
				e.queue_free()
		if _role == "host":
			if el > 3.0 and not did.has("k5"):
				did["k5"] = true
				_gm.call("award_boss_keys", 5)
			if el > 4.5 and not did.has("k5b"):
				did["k5b"] = true
				_gm.call("award_boss_keys", 5)
			if el > 6.0 and not did.has("k10"):
				did["k10"] = true
				_gm.call("award_boss_keys", 10)
			if el > 8.0 and not did.has("none"):
				did["none"] = true
				_gm.call("award_boss_keys", 4)
				_gm.call("award_boss_keys", 11)
		if el > 9.5 and not did.has("snap1"):
			did["snap1"] = true
			_checks["1_kayit_ana"] = int(_meta.call("keys", "ana"))
			_checks["1_kosu_ana"] = int((_gm.get("run_keys") as Dictionary).get("ana", 0))
		if _role == "client" and el > 11.0 and not did.has("forge"):
			did["forge"] = true
			_nm.broadcast_boss_keys.rpc("ana", 5) ## sahte: host DEĞİL -> host ve diğerleri yok sayar
			_log("istemci sahte broadcast_boss_keys %.2f" % el)
		await process_frame
	_checks["2_kayit_ana"] = int(_meta.call("keys", "ana"))
	_checks["2_kayit_diger"] = int(_meta.call("keys", "bataklik")) + int(_meta.call("keys", "col")) + int(_meta.call("keys", "batik_nekropol")) \
			+ int(_meta.call("keys", "lagim_agi"))
	_checks["2_olay_sayisi"] = _events.size()
	## Beklenti: host'ta ve istemcide 3 anahtar (sahte çağrı yalnız İSTEMCİNİN kendi yerelini etkiler: 3 + 5 = 8; host'unki 3 kalır)
	var ok: bool
	if _role == "host":
		ok = _checks["1_kayit_ana"] == 3 and _checks["1_kosu_ana"] == 3 and _checks["2_kayit_ana"] == 3 and _checks["2_kayit_diger"] == 0 and _events.size() == 2
	else:
		ok = _checks["1_kayit_ana"] == 3 and _checks["1_kosu_ana"] == 3 and _checks["2_kayit_diger"] == 0 and _events.size() >= 2
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "events": _events, "checks": _checks, "ok": ok}))
	out.close()
	_log("olaylar: %s" % JSON.stringify(_events))
	_log("denetim: %s" % JSON.stringify(_checks))
	_log("SONUC %s" % ("TEMIZ" if ok else "HATA"))
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


## Açılış sahnesini bitirir (madde 419 / 349 tuzağı; teslim_audit.gd ile aynı).
func _finish_house_intro() -> void:
	var scene: Node = current_scene
	var intro: Node = scene.get_node_or_null("HouseInterior/HouseIntro") if scene else null
	if intro and intro.has_method("_set_phase"):
		intro.call("_set_phase", 3, 0.0)
	root.get_node("GameManager").set("invasion_pending", false)
