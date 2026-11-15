extends SceneTree

## DÜNYA HARİTASI OYLAMASI denetimi (madde 620): iki gerçek süreç (host + istemci), başsız LAN, lobi aşaması (oyun başlamaz).
##  1. ortak oy: host oylamayı açar -> istemcide ekran verisi (açık + süre) gelir; istemci oy verir -> host görür; host aynı haritaya oy verir ->
##     herkes oy verdi: kazanan = o harita (beraberlik yok), kazanan + son oy dökümü istemcide de; host kapatınca istemci temizlenir.
##  2. beraberlik: oylar farklı -> kazanan eşitlerden biri, beraberlik bayrağı + İKİ tarafta AYNI kazanan.
##  3. ayrılan oyuncu: istemci oy vermeden kopar -> host'un oyu tek başına yeter, oylama biter.
## MP_ROLE=host|client MP_DIR MP_PORT. Sonuç: <rol>.json + "MP[rol] KONTROL ..." satırları (run_audit.ps1 -Mode haritaoy).

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7802
var _nm: Node
var _ids: Array = []
var _checks: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _flag(n: String, text: String = "") -> void:
	var f := FileAccess.open(_dir.path_join(n), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _has_flag(n: String) -> bool:
	return FileAccess.file_exists(_dir.path_join(n))


func _read(n: String) -> String:
	return FileAccess.get_file_as_string(_dir.path_join(n))


func _check(name: String, ok: bool, detail: String = "") -> void:
	_checks[name] = ok
	_log("KONTROL %s %s %s" % [name, "ok" if ok else "HATA", detail])


func _save() -> void:
	var out := FileAccess.open(_dir.path_join("%s.json" % _role), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "checks": _checks}))
	out.close()


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_ids = (load("res://scripts/map_profiles.gd") as GDScript).call("selectable_ids")
	if _ids.size() < 3:
		_log("HATA: en az 3 seçilebilir harita gerek")
		quit()
		return
	if _role == "host":
		await _run_host()
	else:
		await _run_client()
	_save()
	var bad: Array = []
	for k in _checks:
		if not bool(_checks[k]):
			bad.append(k)
	_log("ÖZET %d kontrol, hata: %s" % [_checks.size(), str(bad)])
	quit()


func _votes_has(pid_other: int, id: String) -> bool:
	return _nm.get("world_map_votes").get(pid_other, "") == id


func _other_pid() -> int:
	for pid in _nm.get("lobby_players").keys():
		if int(pid) != 1:
			return int(pid)
	return 0


func _run_host() -> void:
	_nm.call("configure_room", "Harita Oy", "", 2)
	if not _nm.call("host_lan", _port, "Host", 5):
		_log("HATA host_lan")
		return
	await _until(func(): return _nm.get("lobby_players").size() >= 2, 60.0)
	var other: int = _other_pid()
	_check("0_odada_iki_kisi", other != 0 and bool(_nm.call("world_map_vote_needed")))
	## --- tur 1: ortak oy
	_nm.call("host_begin_world_map_vote", _ids[0])
	_flag("r1_open.flag")
	await _until(func(): return _votes_has(other, _ids[2]), 20.0)
	_check("1_host_istemci_oyunu_gordu", _votes_has(other, _ids[2]))
	_check("1_oylama_suruyor", str(_nm.get("world_map_vote_winner")) == "")
	_nm.call("cast_world_map_vote", _ids[2])
	await _wait(1.0)
	_check("1_kazanan_ortak_harita", str(_nm.get("world_map_vote_winner")) == _ids[2] and not bool(_nm.get("world_map_vote_tie")), str(_nm.get("world_map_vote_winner")))
	_flag("r1_resolved.flag")
	await _until(func(): return _has_flag("r1_client_ok.flag"), 20.0)
	_nm.call("broadcast_world_map", false)
	_flag("r1_closed.flag")
	await _until(func(): return _has_flag("r1_client_closed_ok.flag"), 20.0)
	_check("1_host_temiz", _nm.get("world_map_votes").is_empty() and str(_nm.get("world_map_vote_winner")) == "")
	## --- tur 2: beraberlik
	_nm.call("host_begin_world_map_vote", _ids[0])
	_flag("r2_open.flag")
	await _until(func(): return _votes_has(other, _ids[1]), 20.0)
	_nm.call("cast_world_map_vote", _ids[0])
	await _wait(1.0)
	var w2: String = str(_nm.get("world_map_vote_winner"))
	_check("2_beraberlik_kazanan_adaylardan", (w2 == _ids[0] or w2 == _ids[1]) and bool(_nm.get("world_map_vote_tie")), w2)
	_flag("r2_winner.txt", w2)
	await _until(func(): return _has_flag("r2_client_ok.flag"), 20.0)
	_nm.call("broadcast_world_map", false)
	_flag("r2_closed.flag")
	await _until(func(): return _has_flag("r2_client_closed_ok.flag"), 20.0)
	## --- tur 3: istemci oy vermeden kopar
	_nm.call("host_begin_world_map_vote", _ids[0])
	_flag("r3_open.flag")
	_nm.call("cast_world_map_vote", _ids[1])
	await _wait(0.5)
	_check("3_istemci_oy_vermeden_bitmedi", str(_nm.get("world_map_vote_winner")) == "")
	_flag("r3_host_voted.flag")
	await _until(func(): return _nm.get("lobby_players").size() == 1, 30.0)
	await _until(func(): return str(_nm.get("world_map_vote_winner")) != "", 10.0)
	_check("3_kopunca_host_oyu_yeter", str(_nm.get("world_map_vote_winner")) == _ids[1] and not bool(_nm.get("world_map_vote_tie")), str(_nm.get("world_map_vote_winner")))
	_log("bitti")


func _run_client() -> void:
	await _wait(1.0)
	if not _nm.call("join_lan", "127.0.0.1", _port, "Client", 1):
		_log("HATA join_lan")
		return
	await _until(func(): return _nm.get("lobby_players").size() >= 2, 30.0)
	## --- tur 1
	await _until(func(): return _has_flag("r1_open.flag"), 60.0)
	await _until(func(): return bool(_nm.get("world_map_open")) and float(_nm.get("world_map_vote_time_left")) > 0.0, 10.0)
	var left1: float = float(_nm.get("world_map_vote_time_left"))
	_check("1_istemcide_ekran_acik_sureli", bool(_nm.get("world_map_open")) and left1 > 0.0 and left1 <= float(_nm.WORLD_MAP_VOTE_TIMEOUT), "kalan %.1f" % left1)
	_nm.call("cast_world_map_vote", _ids[2])
	await _until(func(): return _has_flag("r1_resolved.flag"), 30.0)
	await _until(func(): return str(_nm.get("world_map_vote_winner")) != "", 10.0)
	_check("1_istemcide_kazanan", str(_nm.get("world_map_vote_winner")) == _ids[2] and not bool(_nm.get("world_map_vote_tie")), str(_nm.get("world_map_vote_winner")))
	_check("1_son_dokum_iki_oy", _nm.get("world_map_votes").size() == 2, str(_nm.get("world_map_votes")))
	_flag("r1_client_ok.flag")
	await _until(func(): return _has_flag("r1_closed.flag"), 20.0)
	await _until(func(): return not bool(_nm.get("world_map_open")), 10.0)
	_check("1_istemci_temiz", not bool(_nm.get("world_map_open")) and _nm.get("world_map_votes").is_empty() and str(_nm.get("world_map_vote_winner")) == "")
	_flag("r1_client_closed_ok.flag")
	## --- tur 2: beraberlik (istemci farklı haritaya oy verir)
	await _until(func(): return _has_flag("r2_open.flag"), 30.0)
	await _until(func(): return bool(_nm.get("world_map_open")), 10.0)
	_nm.call("cast_world_map_vote", _ids[1])
	await _until(func(): return _has_flag("r2_winner.txt"), 30.0)
	await _until(func(): return str(_nm.get("world_map_vote_winner")) != "", 10.0)
	var host_w2: String = _read("r2_winner.txt")
	_check("2_ayni_kazanan_iki_tarafta", str(_nm.get("world_map_vote_winner")) == host_w2 and bool(_nm.get("world_map_vote_tie")), "host %s istemci %s" % [host_w2, str(_nm.get("world_map_vote_winner"))])
	_flag("r2_client_ok.flag")
	await _until(func(): return _has_flag("r2_closed.flag"), 20.0)
	await _until(func(): return not bool(_nm.get("world_map_open")), 10.0)
	_flag("r2_client_closed_ok.flag")
	## --- tur 3: oy vermeden kop
	await _until(func(): return _has_flag("r3_host_voted.flag"), 30.0)
	_check("3_istemcide_oylama_acik", bool(_nm.get("world_map_open")) and str(_nm.get("world_map_vote_winner")) == "")
	_nm.call("disconnect_from_room", false)
	await _wait(1.0)
	_log("bitti")


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
