extends SceneTree

## Epic P2P HOST DEVRİ bağlantı gecikmesi ölçümü (2026-10-10): "host düşünce ikinci istemci yeni host'a neden 15-25 sn'de bağlanıyor?"
## ÜÇ gerçek süreç (başsız): MP_ROLE=h|b|c.  H = ilk host (SOCKET_ID sunucusu), B ve C ona bağlanır; B/C bağlanınca H bir süre sonra kapanır
## (peer.close + çıkış). B host kaybını fark edince yeni sunucu kurar (MP_NEWSOCK=same: eski soket adıyla, diff: başka adla), C yeni sunucuya bağlanır
## (MP_RETRY sn'de bir yeni create_client; 0 = hiç).  MP_B_DELAY: B'nin host kaybını fark edince sunucu kurmadan önce beklediği süre.
## MP_CLOSE_OLD=1: istemciler eski bağlantılarını bırakmadan önce peer.close() çağırır (oyundaki gibi); 0: close çağırmadan doğrudan yenisini kurar.
## Sonuç: <dir>/c_result.json.  Kullanım: tools/mp_audit/run_eos_migration_probe.ps1

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _newsock: String = OS.get_environment("MP_NEWSOCK") if OS.get_environment("MP_NEWSOCK") != "" else "same"
var _b_delay: float = float(OS.get_environment("MP_B_DELAY")) if OS.get_environment("MP_B_DELAY") != "" else 0.0
var _retry: float = float(OS.get_environment("MP_RETRY")) if OS.get_environment("MP_RETRY") != "" else 0.0
var _close_old: bool = OS.get_environment("MP_CLOSE_OLD") != "0"
var _pause: bool = OS.get_environment("MP_PAUSE") == "1" ## host kaybında ağacı duraklat (oyundaki host devri gibi)
var _always: bool = OS.get_environment("MP_ALWAYS") == "1" ## EOSGRuntime duraklamada da işlesin (düzeltme)
var _peer: MultiplayerPeer = null
var _lost_at: float = 0.0
var _lost: bool = false


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
	return FileAccess.get_file_as_string(p).strip_edges() if FileAccess.file_exists(p) else ""


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _wait_file(name: String, timeout: float) -> String:
	var t: float = _now()
	var v: String = _read(name)
	while v == "" and _now() - t < timeout:
		await _wait(0.1)
		v = _read(name)
	return v


func _sock_new(sock: String) -> String:
	return sock if _newsock == "same" else sock + "NEW"


func _run() -> void:
	await process_frame
	var eos: Node = root.get_node("EosOnline")
	var err: String = await eos.call("ensure_ready_async", "Probe_" + _role)
	if not err.is_empty():
		print("MPR[%s] HATA %s" % [_role, err])
		quit(1)
		return
	if _always:
		var rt: Node = root.get_node_or_null("EOSGRuntime")
		if rt:
			rt.process_mode = Node.PROCESS_MODE_ALWAYS
			print("MPR[%s] EOSGRuntime process_mode ALWAYS" % _role)
	var my_id: String = str(eos.call("local_user_id"))
	var sock: String = str(eos.SOCKET_ID)
	var mp: MultiplayerAPI = get_multiplayer()
	if _role == "h":
		var sp := EOSGMultiplayerPeer.new()
		sp.create_server(sock)
		_peer = sp
		mp.multiplayer_peer = sp
		var joined: Array = []
		mp.peer_connected.connect(func(id: int) -> void: joined.append(id))
		_write("h_id.txt", my_id)
		print("MPR[h] sunucu hazir")
		var t0: float = _now()
		while joined.size() < 2 and _now() - t0 < 90.0:
			await _wait(0.2)
		print("MPR[h] iki istemci bagli: %d" % joined.size())
		await _wait(4.0)
		_write("h_closing.txt", str(_now()))
		print("MPR[h] kapaniyor")
		_peer.close()
		await _wait(1.0)
		quit(0)
		return
	var hid: String = await _wait_file("h_id.txt", 60.0)
	if hid == "":
		print("MPR[%s] h_id yok" % _role)
		quit(1)
		return
	var cp := EOSGMultiplayerPeer.new()
	cp.create_client(sock, hid)
	_peer = cp
	mp.multiplayer_peer = cp
	mp.server_disconnected.connect(func() -> void:
		if not _lost:
			_lost = true
			_lost_at = _now()
			print("MPR[%s] host kaybi algilandi" % _role))
	var tw: float = _now()
	while cp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED and _now() - tw < 60.0:
		await _wait(0.1)
	print("MPR[%s] h'ye bagli (%.2f sn)" % [_role, _now() - tw])
	_write(_role + "_id.txt", my_id)
	_write(_role + "_connected.txt", "1")
	## host kaybı: server_disconnected sinyali ya da bağlantı durumu düşünce
	var t_loss: float = _now()
	while not _lost and _now() - t_loss < 90.0:
		if _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			_lost = true
			_lost_at = _now()
			print("MPR[%s] host kaybi (durum) " % _role)
		await _wait(0.05)
	if not _lost:
		print("MPR[%s] host kaybi hic algilanmadi" % _role)
		quit(1)
		return
	var new_sock: String = _sock_new(sock)
	if _pause and _role == "c":
		paused = true
		print("MPR[c] agac duraklatildi")
	if _role == "b":
		if _close_old:
			_peer.close()
			_peer = null
		await _wait(_b_delay)
		var sp2 := EOSGMultiplayerPeer.new()
		var e: int = sp2.create_server(new_sock)
		var server_up: float = _now()
		_peer = sp2
		mp.multiplayer_peer = sp2
		var got: Array = []
		mp.peer_connected.connect(func(id: int) -> void:
			got.append(id)
			print("MPR[b] c baglandi: sunucu_hazir +%.2f sn, kayip +%.2f sn" % [_now() - server_up, _now() - _lost_at]))
		_write("b_server_up.txt", str(server_up))
		print("MPR[b] yeni sunucu kuruldu (%d) kayiptan +%.2f sn" % [e, server_up - _lost_at])
		var t1: float = _now()
		while got.is_empty() and _now() - t1 < 100.0:
			await _wait(0.2)
		await _wait(2.0)
		quit(0)
		return
	# c
	var bid: String = await _wait_file("b_id.txt", 30.0)
	var t0c: float = _lost_at
	if _close_old:
		_peer.close()
		_peer = null
	var attempts: int = 0
	var last_try: float = 0.0
	var ok: bool = false
	while not ok and _now() - t0c < 100.0:
		if attempts == 0 or (_retry > 0.0 and _now() - last_try >= _retry):
			if _peer != null:
				_peer.close()
				_peer = null
			var c2 := EOSGMultiplayerPeer.new()
			var e2: int = c2.create_client(new_sock, bid)
			print("MPR[c] create_client #%d -> %d (+%.2f sn)" % [attempts + 1, e2, _now() - t0c])
			if e2 == OK:
				_peer = c2
				mp.multiplayer_peer = c2
			attempts += 1
			last_try = _now()
		if _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			ok = true
			break
		await _wait(0.1)
	var up: float = float(_read("b_server_up.txt")) if _read("b_server_up.txt") != "" else 0.0
	print("MPR[c] SONUC baglandi=%s  kayiptan=%.2f sn  sunucu_hazirdan=%.2f sn  deneme=%d" % [str(ok), _now() - t0c, (_now() - up) if up > 0.0 else -1.0, attempts])
	_write("c_result.json", JSON.stringify({"ok": ok, "since_loss": _now() - t0c, "since_server_up": (_now() - up) if up > 0.0 else -1.0, "attempts": attempts}))
	await _wait(1.0)
	quit(0)
