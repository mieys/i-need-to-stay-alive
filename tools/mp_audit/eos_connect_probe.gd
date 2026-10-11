extends SceneTree

## Epic P2P bağlantı gecikmesi ölçümü (host devri incelemesi, 2026-10-10): "sunucu daha kurulmadan gelen bağlantı isteği ne kadar sürede toparlanır?"
## İKİ gerçek süreç (başsız): MP_ROLE=server|client. Sunucu girişten sonra kimliğini dosyaya yazar, MP_S_DELAY sn bekleyip create_server çağırır;
## istemci kimliği görür görmez create_client çağırır, MP_RETRY sn'de bir (0 = hiç) yeni create_client ile yeniden dener (network_manager.gd _migration_try_connect
## ile aynı yöntem). MP_MODE=fresh|lobby: lobby = sunucu bir de oda ilanı açar (host_lobby_async), istemci ilanı bulana kadar bekleyip ondan sonra bağlanır.
## Sonuç: <dir>/result.json  { "server_up": unix, "client_start": unix, "connected": unix, "attempts": n }.
## Kullanım: powershell -File tools/mp_audit/run_eos_probe.ps1 -SDelay 3 -Retry 5

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _s_delay: float = float(OS.get_environment("MP_S_DELAY")) if OS.get_environment("MP_S_DELAY") != "" else 0.0
var _retry: float = float(OS.get_environment("MP_RETRY")) if OS.get_environment("MP_RETRY") != "" else 0.0
var _mode: String = OS.get_environment("MP_MODE") if OS.get_environment("MP_MODE") != "" else "fresh"
var _tag: String = OS.get_environment("MP_TAG") if OS.get_environment("MP_TAG") != "" else "PROBE"
var _peer: MultiplayerPeer = null
var _connected_at: float = 0.0
var _server_up: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _now() -> float:
	return Time.get_unix_time_from_system()


func _write(name: String, text: String) -> void:
	var f := FileAccess.open(_dir.path_join(name), FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()


func _read(name: String) -> String:
	var p: String = _dir.path_join(name)
	if not FileAccess.file_exists(p):
		return ""
	return FileAccess.get_file_as_string(p)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _run() -> void:
	await process_frame
	var eos: Node = root.get_node("EosOnline")
	var err: String = await eos.call("ensure_ready_async", "Probe_" + _role)
	if not err.is_empty():
		print("PROBE[%s] HATA %s" % [_role, err])
		quit(1)
		return
	var my_id: String = str(eos.call("local_user_id"))
	var sock: String = str(eos.SOCKET_ID)
	if _role == "server":
		_write("server_id.txt", my_id)
		print("PROBE[server] giris tamam, id=%s" % my_id.left(8))
		await _wait(_s_delay)
		var sp := EOSGMultiplayerPeer.new()
		var e: int = sp.create_server(sock)
		if e != OK:
			print("PROBE[server] create_server hata %d" % e)
			quit(1)
			return
		_peer = sp
		get_multiplayer().multiplayer_peer = sp
		_server_up = _now()
		get_multiplayer().peer_connected.connect(func(id: int) -> void:
			print("PROBE[server] peer_connected %d  +%.2f sn" % [id, _now() - _server_up])
			_connected_at = _now())
		if _mode == "lobby":
			await eos.call("host_lobby_async", _tag, 5)
			_write("lobby_up.txt", str(_now()))
		_write("server_up.txt", str(_server_up))
		print("PROBE[server] sunucu hazir")
		var t_end: float = _now() + 120.0
		while _connected_at == 0.0 and _now() < t_end:
			await _wait(0.25)
		await _wait(3.0)
		quit(0)
		return
	# istemci
	var sid: String = ""
	var t_wait: float = _now()
	while sid == "" and _now() - t_wait < 60.0:
		sid = _read("server_id.txt").strip_edges()
		if sid == "":
			await _wait(0.2)
	if sid == "":
		print("PROBE[client] sunucu kimligi yok")
		quit(1)
		return
	if _mode == "lobby":
		while _read("lobby_up.txt") == "" and _now() - t_wait < 90.0:
			await _wait(0.1)
	var t0: float = _now()
	var attempts: int = 0
	var last_try: float = 0.0
	var done: bool = false
	while not done and _now() - t0 < 100.0:
		if attempts == 0 or (_retry > 0.0 and _now() - last_try >= _retry):
			if _peer != null:
				_peer.close()
				_peer = null
			var cp := EOSGMultiplayerPeer.new()
			var e2: int = cp.create_client(sock, sid)
			print("PROBE[client] create_client #%d -> %d  (+%.2f sn)" % [attempts + 1, e2, _now() - t0])
			if e2 == OK:
				_peer = cp
				get_multiplayer().multiplayer_peer = cp
			attempts += 1
			last_try = _now()
		if _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			done = true
			break
		await _wait(0.1)
	var t_conn: float = _now()
	var up: float = float(_read("server_up.txt")) if _read("server_up.txt") != "" else 0.0
	print("PROBE[client] sonuc: baglandi=%s  istemci_baslangic->baglanti=%.2f sn  sunucu_hazir->baglanti=%.2f sn  deneme=%d" % [str(done), t_conn - t0, t_conn - up if up > 0.0 else -1.0, attempts])
	_write("result.json", JSON.stringify({"connected": done, "client_start": t0, "connected_at": t_conn, "server_up": up, "attempts": attempts,
		"since_client_start": t_conn - t0, "since_server_up": t_conn - up if up > 0.0 else -1.0}))
	await _wait(1.0)
	quit(0)
