extends SceneTree

## Lobi sistemi denetimi (2026-10-11): ÜÇ gerçek süreç (host, istemci, yabancı), başsız LAN.
##  - host "Test Odası" kurar: şifre "gizli", en fazla 2 oyuncu.
##  - istemci: şifresiz -> "şifreli" (1), yanlış şifre -> "yanlış" (2), doğru şifre -> kabul (oda adı/sınır gelir). Host karakter
##    seçimine geçirince lobby_phase_changed("select") gelmeli.
##  - yabancı (oda doluyken): yanlış şifre -> 2, doğru şifre -> "oda dolu" (3).
##  - host istemciyi atar: istemciye "atıldın" (4) + bağlantı kopar; doğru şifreyle yeniden denemesi de 4 almalı.
## MP_ROLE=host|client|stranger MP_DIR MP_PORT. Sonuç: <rol>.json (run_audit.ps1 -Mode lobby).

const PW := "gizli"

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7801
var _nm: Node
var _codes: Array = []
var _entered: int = 0
var _phases: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _flag(n: String) -> void:
	FileAccess.open(_dir.path_join(n), FileAccess.WRITE).close()


func _has_flag(n: String) -> bool:
	return FileAccess.file_exists(_dir.path_join(n))


func _save(res: Dictionary) -> void:
	var out := FileAccess.open(_dir.path_join("%s.json" % _role), FileAccess.WRITE)
	out.store_string(JSON.stringify(res))
	out.close()


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_nm.connect("room_join_rejected", func(code: int, _m: String) -> void: _codes.append(code))
	_nm.connect("room_entered", func() -> void: _entered += 1)
	_nm.connect("lobby_phase_changed", func(p: String) -> void: _phases.append(p))
	_nm.connect("lobby_updated", func() -> void: _log("lobby %s" % str(_nm.get("lobby_players").keys())))
	_nm.connect("connection_status_changed", func(t: String) -> void: _log("durum: %s" % t))
	match _role:
		"host":
			await _run_host()
		"client":
			await _run_client()
		_:
			await _run_stranger()
	quit()


func _run_host() -> void:
	_nm.call("configure_room", "Test Odası", PW, 2)
	if not _nm.call("host_lan", _port, "Host", 5):
		_log("HATA host_lan"); return
	await _until(func(): return _nm.get("lobby_players").size() >= 2, 60.0)
	var max_seen: int = _nm.get("lobby_players").size()
	_nm.call("set_lobby_phase", "select")
	await _wait(2.0)
	_flag("full.flag")
	await _until(func(): return _has_flag("stranger_done.flag"), 60.0)
	max_seen = maxi(max_seen, _nm.get("lobby_players").size())
	var victim: int = 0
	for pid in _nm.get("lobby_players").keys():
		if int(pid) != 1:
			victim = int(pid)
	_nm.call("kick_player", victim)
	await _wait(3.0)
	var after_kick: int = _nm.get("lobby_players").size()
	_flag("kicked.flag")
	await _until(func(): return _has_flag("client_done.flag"), 40.0)
	_save({"role": "host", "max_lobby": max_seen, "after_kick": after_kick, "room_max": int(_nm.get("room_max_players"))})
	_log("bitti: en çok %d oyuncu, atma sonrası %d" % [max_seen, after_kick])


## Bir katılma denemesi: kabul (room_entered) ya da ret + kopma beklenir. Dönen: kabulse 0, değilse son ret kodu (-1 = cevap yok).
func _attempt(name: String, password: String) -> int:
	var codes_before: int = _codes.size()
	var entered_before: int = _entered
	_nm.set("join_password", password)
	if not _nm.call("join_lan", "127.0.0.1", _port, name, 1):
		return -1
	await _until(func(): return _entered > entered_before or (_codes.size() > codes_before and not bool(_nm.get("is_multiplayer_active"))), 15.0)
	if _entered > entered_before:
		return 0
	return int(_codes[-1]) if _codes.size() > codes_before else -1


func _run_client() -> void:
	var r_none: int = await _attempt("Client", "")
	var r_wrong: int = await _attempt("Client", "yanlis")
	var r_ok: int = await _attempt("Client", PW)
	var room_name: String = str(_nm.get("room_name"))
	var room_max: int = int(_nm.get("room_max_players"))
	await _until(func(): return _phases.has("select"), 15.0)
	var my_id: int = _nm.multiplayer.get_unique_id()
	var ready_after_phase: bool = bool(_nm.get("lobby_players").get(my_id, {}).get("is_ready", true))
	var codes_before_kick: int = _codes.size()
	await _until(func(): return _codes.size() > codes_before_kick and not bool(_nm.get("is_multiplayer_active")), 90.0)
	var kicked_code: int = int(_codes[-1]) if _codes.size() > codes_before_kick else -1
	await _wait(1.0)
	var r_rejoin: int = await _attempt("Client", PW)
	_save({"role": "client", "no_pw": r_none, "wrong_pw": r_wrong, "ok_pw": r_ok, "room_name": room_name, "room_max": room_max,
		"phases": _phases, "ready_after_phase": ready_after_phase, "kicked_code": kicked_code, "rejoin_after_kick": r_rejoin})
	_flag("client_done.flag")
	_log("bitti: şifresiz %d, yanlış %d, doğru %d, atma %d, yeniden %d" % [r_none, r_wrong, r_ok, kicked_code, r_rejoin])


func _run_stranger() -> void:
	await _until(func(): return _has_flag("full.flag"), 90.0)
	var r_wrong: int = await _attempt("Yabanci", "x")
	var r_full: int = await _attempt("Yabanci", PW)
	_save({"role": "stranger", "wrong_pw": r_wrong, "full": r_full})
	_flag("stranger_done.flag")
	_log("bitti: yanlış %d, dolu %d" % [r_wrong, r_full])


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
