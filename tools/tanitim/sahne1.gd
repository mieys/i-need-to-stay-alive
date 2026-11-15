extends SceneTree

## FRAGMAN SAHNE 1 v2 - "Asla yalnız değilsin" (2026-11-10; v1 "ruhsuz, hissiz, Talon yaprağın altında kaldı" -> baştan tasarım).
## Düzen tanitim_coop.gd: host (Şovalye 7) + c1 (Talon 1) BAŞSIZ gerçek eşler, viewer (Büyücü Kız 4) gizli masaüstünde pencereli istemci,
## 1920x1080 gerçek zamanlı JPG + zaman.json (kare başı can / isabet / zaman ölçeği) + ses.wav. Renk, sarsıntı, parlama, yazı, ses aksanları,
## kapanış kartı kurguda (tools/tanitim/sahne_kurgu.py).
## Duygu araçları (oyun içinde): GERÇEK AĞIR ÇEKİM (üç süreçte aynı anda Engine.time_scale, sinyal dosyasıyla tetiklenir - kayıt gerçek
## zamanlı olduğu için video kendiliğinden yavaşlar, ses perdesi bozulmaz), serbest sinematik kamera (yakın plan, Şovalye takibi, geri çekilip
## kalabalığı açma), oyunun GERÇEK sohbet emojileriyle konuşma (:yardim: / :kirp: / :kalp: / :saskin: / :kilic: / :ates: ...), korku balonları,
## sırt sırta duruş, bakışma, kubbe zorlanırken titreme (viewer'da kozmetik).
## Zaman: go.txt (host, +GO_LEAD) ortak başlangıç; sinyaller sig_<ad>.txt (duvar saniyesi). Bekleyişler OYUN zamanında (_gwait).
## Ortam: CO_ROLE (host|c1|viewer), CO_CHAR, CO_NAME, CO_PORT, CO_WEAPONS, TN_DIR, HARITA=col. Sürücü: tools/tanitim/sahne1.ps1.

const SPOT := Vector2(2112, 3470) ## temiz kum (yapraklı bitki yok); solda kaya sütunu
const DUSK := 352.0
const OFF := {"viewer": Vector2(0, 0), "c1": Vector2(-470, 8), "host": Vector2(470, -16)}
const KEEP_LAYER_SCRIPTS: Array = ["atmosphere_overlay.gd", "sun_clouds.gd"] ## görüş sisi gizli: zoom değişince ekranı karartıyor (madde 552)
const P1_IDS: Array = ["zombie1", "iskelet2", "iskelet1", "zombie2", "iskelet2"]
const HORDE_IDS: Array = ["ork1", "ork2", "lich1", "iskelet2", "zombie3", "ork1", "iskelet2"]
const MOVES: Array = ["move_left", "move_right", "move_up", "move_down"]
const GO_LEAD := 5.0
## Kamera zoom'u ekranda ayarın ~2/3'ü kadar etkili (madde 552) - aşağıdaki değerler EKRANDAKİ zoom.
const ZOOM_FIX := 1.5
## AĞIR ÇEKİM: [sinyal, başlangıç (sinyalden sonra duvar sn), süre (duvar sn), ölçek]. Üç süreç aynı tabloyu okur.
const SLOWMO: Array = [
	["help", 0.05, 2.1, 0.42],
	["talon_pre", 0.0, 1.05, 0.3],
	["blink", 0.08, 1.6, 0.3],
	["look", 0.0, 2.3, 0.5],
	["impact", 0.0, 1.9, 0.33],
]
const SLOW_RAMP := 0.22

var _role: String = OS.get_environment("CO_ROLE")
var _char: int = int(OS.get_environment("CO_CHAR")) if OS.get_environment("CO_CHAR") != "" else 4
var _port: int = int(OS.get_environment("CO_PORT")) if OS.get_environment("CO_PORT") != "" else 7833
var _dir: String = OS.get_environment("TN_DIR")
var _nick: String = ""
var _tier: int = 4
var _nm: Node
var _gm: Node
var _main: Node
var _player: Node2D
var _spawner: Node
var _cam: Camera2D = null
var _go: float = 0.0
var _move: Array = []
var _rng := RandomNumberGenerator.new()
var _sig_cache: Dictionary = {}
var _done: bool = false
var _merchant: Node = null
## kayıt (viewer)
var _rec: bool = false
var _rec_i: int = 0
var _rec_t: Array = []
var _rec_hp: Array = []
var _rec_ts: Array = []
var _rec_hit: Array = []
var _rec_T0: float = 0.0
var _rec_t0: int = 0
var _audio_rec: AudioEffectRecord = null
var _pending: int = 0
var _mutex := Mutex.new()
var _rd_fmt: Dictionary = {}
## kamera (viewer)
var _cam_mode: String = "self"
var _cam_pos: Vector2 = Vector2.ZERO
var _cam_k: float = 0.05
var _zoom: float = 2.2
var _zoom_target: float = 2.2
var _zoom_k: float = 0.012
var _cam_bias: Vector2 = Vector2(0, -14)
## viewer can
var _hp_ratio: float = 0.5
var _hp_set: float = 250.0
var _hit_now: int = 0
var _shield_hold: float = 0.0
var _kite: bool = true
var _dome_flicker: bool = false
## host
var _trickle: bool = false
var _dome_t0: float = -1.0
var _spawn_acc: float = 0.0


func _initialize() -> void:
	if _role == "viewer":
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		root.content_scale_size = Vector2i(1920, 1080)
		RenderingServer.frame_post_draw.connect(_on_post_draw)
	_run.call_deferred()


func _log(s: String) -> void:
	print("SH[%s] %s" % [_role, s])


## Duvar saati: go anından beri (sinyaller bununla yazılır).
func _t() -> float:
	return Time.get_unix_time_from_system() - _go


func _at(t: float) -> void:
	while _t() < t:
		paused = false
		await process_frame


## OYUN zamanında bekle (ağır çekimde uzar).
func _gwait(sec: float) -> void:
	var acc: float = 0.0
	while acc < sec:
		paused = false
		await process_frame
		acc += root.get_process_delta_time()


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


## ───────────── sinyaller ─────────────

func _sig(name: String) -> void:
	var f := FileAccess.open(_dir.path_join("sig_%s.txt" % name), FileAccess.WRITE)
	if f:
		f.store_string("%.4f" % _t())
		f.close()
	_sig_cache[name] = _t()
	_log("sig %s T=%.2f" % [name, _t()])


func _sig_time(name: String) -> float:
	if _sig_cache.has(name):
		return float(_sig_cache[name])
	var p: String = _dir.path_join("sig_%s.txt" % name)
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		if f:
			var txt: String = f.get_as_text()
			f.close()
			if txt.strip_edges() != "":
				_sig_cache[name] = float(txt)
				return float(txt)
	return -1.0


## Sinyal gelene kadar bekle, sonra sinyalin duvar zamanından itibaren delay (duvar) sn daha.
func _wait_sig(name: String, delay: float = 0.0) -> void:
	while _sig_time(name) < 0.0:
		paused = false
		await process_frame
	await _at(_sig_time(name) + delay)


## Ağır çekim yönetmeni: tüm süreçler aynı tablodan aynı ölçeği hesaplar.
func _ts_now(T: float) -> float:
	var ts: float = 1.0
	for s in SLOWMO:
		var st: float = _sig_time(str(s[0]))
		if st < 0.0:
			continue
		var a: float = st + float(s[1])
		var b: float = a + float(s[2])
		if T < a - SLOW_RAMP or T > b + SLOW_RAMP:
			continue
		var k: float = 1.0
		if T < a:
			k = (T - (a - SLOW_RAMP)) / SLOW_RAMP
		elif T > b:
			k = 1.0 - (T - b) / SLOW_RAMP
		ts = minf(ts, lerpf(1.0, float(s[3]), clampf(k, 0.0, 1.0)))
	return ts


## ───────────── girdi / sohbet ─────────────

func _press(slot: String) -> void:
	Input.action_press(slot)
	await process_frame
	await physics_frame
	await process_frame
	await process_frame
	Input.action_release(slot)


func _cast(slot: String, shield: float = 0.0) -> void:
	var st: Array = ["skill_state", "skill_timer"]
	if slot == "skill2":
		st = ["skill2_state", "skill2_timer"]
	elif slot == "skill3":
		st = ["skill3_state", "skill3_timer"]
	elif slot == "skill4":
		st = ["spirit_state", "spirit_timer"]
	_player.set(st[0], "ready")
	if st[1] in _player:
		_player.set(st[1], 0.0)
	if shield > 0.0:
		_player.set("item_shield_max", shield)
		_player.set("item_shield_hp", shield)
	await _press(slot)


## Gerçek sohbet: herkese gider, konuşanın üstünde balon + sohbet sesi (main.gd _on_chat_message_received).
func _say(text: String) -> void:
	_nm.rpc("broadcast_chat_message", get_multiplayer().get_unique_id(), _nick, text)
	_log("sohbet %s" % text)


func _nudge(action: String, sec: float = 0.08) -> void:
	_move = [action]
	await _gwait(sec)
	_move = []


func _dir_to(from: Vector2, to: Vector2) -> Array:
	var d: Vector2 = to - from
	var out: Array = []
	if d.length() < 1.0:
		return out
	var n: Vector2 = d.normalized()
	if n.x > 0.38:
		out.append("move_right")
	elif n.x < -0.38:
		out.append("move_left")
	if n.y > 0.38:
		out.append("move_down")
	elif n.y < -0.38:
		out.append("move_up")
	return out


func _remote_char(cid: int) -> Node2D:
	for r in get_nodes_in_group("remote_players"):
		if r is Node2D and is_instance_valid(r) and int(r.get("char_id")) == cid:
			return r as Node2D
	return null


func _pos_of(cid: int) -> Vector2:
	if cid == _char:
		return _player.global_position
	var r: Node2D = _remote_char(cid)
	return r.global_position if r else Vector2.INF


## ───────────── kayıt (viewer) ─────────────

func _on_post_draw() -> void:
	if not _rec:
		return
	var path: String = _dir.path_join("kareler/sahne/%05d.jpg" % _rec_i)
	_rec_t.append(Time.get_ticks_usec() - _rec_t0)
	_rec_hp.append(snappedf(_hp_ratio, 0.001))
	_rec_ts.append(snappedf(Engine.time_scale, 0.001))
	_rec_hit.append(_hit_now)
	_hit_now = 0
	_rec_i += 1
	_mutex.lock()
	_pending += 1
	_mutex.unlock()
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	var tex_rid: RID = RenderingServer.texture_get_rd_texture(root.get_texture().get_rid()) if rd else RID()
	if rd and tex_rid.is_valid():
		if _rd_fmt.is_empty():
			var tf: RDTextureFormat = rd.texture_get_format(tex_rid)
			_rd_fmt = {"w": tf.width, "h": tf.height, "fmt": tf.format}
		rd.texture_get_data_async(tex_rid, 0, _on_rd_data.bind(path))
	else:
		var img: Image = root.get_texture().get_image()
		WorkerThreadPool.add_task(_save_img.bind(img, path))


func _on_rd_data(data: PackedByteArray, path: String) -> void:
	WorkerThreadPool.add_task(_save_raw.bind(data, path))


func _save_raw(data: PackedByteArray, path: String) -> void:
	var w: int = int(_rd_fmt["w"])
	var h: int = int(_rd_fmt["h"])
	var img: Image = null
	if data.size() == w * h * 4:
		img = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	elif data.size() == w * h * 8:
		img = Image.create_from_data(w, h, false, Image.FORMAT_RGBAH, data)
		img.convert(Image.FORMAT_RGBA8)
	if img:
		img.save_jpg(path, 0.95)
	_mutex.lock()
	_pending -= 1
	_mutex.unlock()


func _save_img(img: Image, path: String) -> void:
	img.save_jpg(path, 0.95)
	_mutex.lock()
	_pending -= 1
	_mutex.unlock()


func _start_rec() -> void:
	DirAccess.make_dir_recursive_absolute(_dir.path_join("kareler/sahne"))
	_audio_rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, _audio_rec)
	_rec_t0 = Time.get_ticks_usec()
	_rec_T0 = _t()
	_audio_rec.set_recording_active(true)
	_rec = true
	_log("kayit basladi T=%.3f" % _rec_T0)


func _stop_rec() -> void:
	_rec = false
	_audio_rec.set_recording_active(false)
	var wav: AudioStreamWAV = _audio_rec.get_recording()
	var audio_len: float = 0.0
	if wav:
		wav.save_to_wav(_dir.path_join("ses.wav"))
		audio_len = wav.get_length()
	var t0: int = Time.get_ticks_msec()
	while _pending > 0 and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	var dur: float = float(Time.get_ticks_usec() - _rec_t0) / 1.0e6
	var sigs: Dictionary = {}
	for f in DirAccess.get_files_at(_dir):
		if f.begins_with("sig_") and f.ends_with(".txt"):
			var nm: String = f.trim_prefix("sig_").trim_suffix(".txt")
			sigs[nm] = _sig_time(nm)
	var fz := FileAccess.open(_dir.path_join("zaman.json"), FileAccess.WRITE)
	fz.store_string(JSON.stringify({"frames": _rec_i, "t_us": _rec_t, "hp": _rec_hp, "ts": _rec_ts, "hit": _rec_hit, "rec_T0": _rec_T0,
			"dur": dur, "audio_len": audio_len, "sig": sigs}))
	fz.close()
	_log("kayit bitti kare=%d sure=%.2f ort_fps=%.1f ses=%.2f" % [_rec_i, dur, float(_rec_i) / maxf(0.01, dur), audio_len])


## ───────────── yardımcılar ─────────────

func _hide_ui() -> void:
	for n in root.find_children("*", "CanvasLayer", true, false):
		var cl: CanvasLayer = n as CanvasLayer
		if cl.follow_viewport_enabled:
			continue
		var keep: bool = false
		var sc: Variant = cl.get_script()
		if sc != null:
			var p: String = str((sc as Script).resource_path)
			for k in KEEP_LAYER_SCRIPTS:
				if p.ends_with(k):
					keep = true
		if not keep and cl.visible:
			cl.visible = false


func _no_merchant() -> void:
	if _merchant == null or not is_instance_valid(_merchant):
		_merchant = null
		for n in _main.find_children("*", "", true, false):
			var sc: Variant = n.get_script()
			if sc != null and str((sc as Script).resource_path).ends_with("traveling_merchant.gd"):
				_merchant = n
				break
	if _merchant != null:
		_merchant.set("_cooldown_timer", 1.0e9)


func _spawn_ok(p: Vector2) -> bool:
	for o in [Vector2.ZERO, Vector2(18, 0), Vector2(-18, 0), Vector2(0, 14), Vector2(0, -14)]:
		var q: Vector2 = p + o
		if _gm.call("is_position_blocked_by_terrain", q) or _gm.call("is_position_blocked_by_walls", q):
			return false
	return true


func _spawn_at(id: String, pos: Vector2, hp: float) -> void:
	var nid: int = int(_spawner.get("_next_network_enemy_id"))
	_spawner.set("_next_network_enemy_id", nid + 1)
	var e: Node2D = _spawner.call("_spawn_creature", id, pos, nid)
	if e == null:
		return
	e.set_meta("spawn_tier", _tier)
	if e.has_method("apply_tier_scaling"):
		e.call("apply_tier_scaling", _tier)
	_spawner.call("_apply_global_buff", e)
	e.set("max_health", hp)
	e.set("health", hp)
	_spawner.call("_announce_spawn", e, id, pos, _tier, false, nid, false, false)


func _ring_spawn(ids: Array, center: Vector2, rx: float, ry: float, hp: float) -> bool:
	for _try in range(8):
		var a: float = _rng.randf() * TAU
		var p: Vector2 = center + Vector2(cos(a) * rx, sin(a) * ry) * _rng.randf_range(1.0, 1.14)
		if _spawn_ok(p):
			_spawn_at(str(ids[_rng.randi() % ids.size()]), p, hp)
			return true
	return false


func _enemies_near(c: Vector2, r: float) -> Array:
	var out: Array = []
	for e in get_nodes_in_group("enemies"):
		if e is Node2D and is_instance_valid(e) and e.get("is_dead") != true and (e as Node2D).global_position.distance_to(c) < r:
			out.append(e)
	return out


func _soften(hp: float) -> void:
	for e in _enemies_near(SPOT, 1000.0):
		var h: float = float(e.get("health"))
		e.set("health", minf(h, hp * _rng.randf_range(0.5, 1.0)))


func _kill_all() -> void:
	for e in _enemies_near(SPOT, 1300.0):
		if e.has_method("take_damage"):
			e.call("take_damage", 99999.0)


## ───────────── akış ─────────────

func _run() -> void:
	await process_frame
	if _role != "viewer":
		AudioServer.set_bus_mute(0, true)
		Engine.max_fps = 60
	var mb: int = AudioServer.get_bus_index("Music")
	if mb >= 0:
		AudioServer.set_bus_mute(mb, true)
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	_rng.seed = 4242
	_nick = OS.get_environment("CO_NAME") if OS.get_environment("CO_NAME") != "" else _role
	_gm.set("selected_map", "col")
	if _role == "host":
		_gm.set("selected_spiritual", "taktik")
		if not _nm.call("host_lan", _port, _nick, _char):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 3 and _nm.call("all_players_ready"), 90.0)
		if not _nm.call("all_players_ready"):
			_log("HATA istemciler gelmedi"); quit(1); return
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0 + (0.6 if _role == "c1" else 1.4))
		if not _nm.call("join_lan", "127.0.0.1", _port, _nick, _char):
			_log("HATA join_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 3, 60.0)
		_nm.call("set_local_ready", true)
	await _until(func(): return current_scene != null and current_scene.name == "Main", 90.0)
	if current_scene == null or current_scene.name != "Main":
		_log("HATA Main yok"); quit(1); return
	_main = current_scene
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	await _until(func(): return get_first_node_in_group("loading_overlay") == null, 60.0)
	await _wait(1.0)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	var intro: Node = _main.get_node_or_null("HouseInterior/HouseIntro")
	if intro and intro.has_method("_set_phase"):
		intro.call("_set_phase", 3, 0.0)
	_gm.set("invasion_pending", false)
	for n in _main.find_children("*", "", true, false):
		var wsc: Variant = n.get_script()
		if wsc != null and str((wsc as Script).resource_path).ends_with("world_event_manager.gd"):
			n.set_process(false) ## dünya görevleri (Konvoyu Koru vb.) sahneye karışmasın
			break
	await _wait(1.5)
	_player = _main.get_node_or_null("Player") as Node2D
	_spawner = _main.get_node_or_null("EnemySpawner")
	if _player == null:
		_log("HATA Player yok"); quit(1); return
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", DUSK)
		atmo.call("debug_set_weather", 0)
		atmo.call("debug_set_time_scale", 0.0)
	while (_player.get("owned_weapon_nodes") as Array).size() > 0:
		_player.call("remove_owned_weapon", 0)
	await _wait(0.3)
	for k in OS.get_environment("CO_WEAPONS").split(","):
		if k.strip_edges() != "":
			_player.call("buy_weapon_copy", k.strip_edges(), 3)
	_player.set("level", 20)
	_player.set("_die_pending", true) ## ölümsüz (canı biz yazıyoruz; debug_immortal darbe tepkisini de kapatır)
	_player.global_position = SPOT + OFF.get(_role, Vector2.ZERO)
	_cam = _player.get_node_or_null("Camera2D") as Camera2D
	if _cam:
		_cam.position_smoothing_enabled = false
		_cam.drag_horizontal_enabled = false
		_cam.drag_vertical_enabled = false
		_cam.reset_smoothing()
	_cam_pos = _player.global_position + _cam_bias
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 2, 30.0)
	_log("senaryo (kukla: %d)" % get_nodes_in_group("remote_players").size())
	if _spawner and _role == "host":
		_spawner.set("_spawn_tier", 1) ## boss kapısı açılmasın (madde 552)
		_gm.set("game_time", 30.0)
	var rf := FileAccess.open(_dir.path_join("ready_%s.txt" % _role), FileAccess.WRITE)
	rf.store_string("1")
	rf.close()
	if _role == "host":
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready_c1.txt")) and FileAccess.file_exists(_dir.path_join("ready_viewer.txt")), 60.0)
		var gf := FileAccess.open(_dir.path_join("go.txt"), FileAccess.WRITE)
		gf.store_string("%.4f" % (Time.get_unix_time_from_system() + GO_LEAD))
		gf.close()
	await _until(func(): return FileAccess.file_exists(_dir.path_join("go.txt")), 60.0)
	await _wait(0.2)
	var gr := FileAccess.open(_dir.path_join("go.txt"), FileAccess.READ)
	_go = float(gr.get_as_text())
	gr.close()
	_log("go=%.3f simdi-go=%.2f" % [_go, -_t()])
	match _role:
		"viewer":
			_viewer_script()
		"c1":
			_talon_script()
		"host":
			_host_script()
	var frame: int = 0
	while true:
		paused = false
		frame += 1
		var T: float = _t()
		Engine.time_scale = _ts_now(T)
		if _done or T > 75.0:
			break
		_tick(T, frame)
		if _role == "viewer" and not _rec and T >= 0.0:
			_start_rec()
		await process_frame
	Engine.time_scale = 1.0
	if _rec:
		await _stop_rec()
	_log("bitti")
	await _wait(2.0)
	quit()


func _tick(T: float, frame: int) -> void:
	if _spawner:
		_spawner.set("_spawn_timer", 1.0e9)
	_gm.set("team_xp_needed", 1.0e12)
	_player.set("xp_to_next_level", 1.0e12)
	if frame % 30 == 0:
		if _role != "viewer":
			Engine.max_fps = 60
		_no_merchant()
		if _role == "viewer":
			_hide_ui()
	for a in MOVES:
		if _move.has(a):
			Input.action_press(a)
		else:
			Input.action_release(a)
	if _role != "viewer" and _sig_time("end") >= 0.0 and T > _sig_time("end") + 0.5:
		_done = true
	match _role:
		"viewer":
			_tick_viewer(T)
		"c1":
			_player.set("max_health", 600.0)
			_player.set("health", 600.0)
			_player.set("item_shield_max", 2000.0)
			_player.set("item_shield_hp", 2000.0)
		"host":
			_tick_host(T)


func _tick_viewer(T: float) -> void:
	## ── kamera ──
	if _cam and is_instance_valid(_cam):
		var me: Vector2 = _player.global_position
		var goal: Vector2 = me
		var tal: Vector2 = _pos_of(1)
		var sov: Vector2 = _pos_of(7)
		match _cam_mode:
			"pair":
				if tal != Vector2.INF and tal.distance_to(me) < 420.0:
					goal = (me + tal) * 0.5
			"sov":
				if sov != Vector2.INF:
					goal = sov + Vector2(-70, 0) ## koşu yönünde boşluk bırak
			"trio":
				var c: Vector2 = me
				var k: int = 1
				for p in [tal, sov]:
					if p != Vector2.INF and p.distance_to(me) < 420.0:
						c += p
						k += 1
				goal = c / float(k)
		_cam_pos = _cam_pos.lerp(goal + _cam_bias, _cam_k)
		_zoom = lerpf(_zoom, _zoom_target, _zoom_k)
		_cam.zoom = Vector2(_zoom, _zoom) * ZOOM_FIX
		_cam.offset = _cam_pos - me
	## ── Büyücü canı: eğri + gerçek isabet algısı (kurgudaki kırmızı nabız için) ──
	var cur: float = float(_player.get("health"))
	if cur < _hp_set - 0.5:
		_hit_now = 1
	_hp_set = _hp_ratio * 500.0
	_player.set("max_health", 500.0)
	_player.set("health", _hp_set)
	_player.call("emit_signal", "health_changed", _hp_set, 500.0)
	if _shield_hold > 0.0:
		_player.set("item_shield_max", _shield_hold)
		_player.set("item_shield_hp", _shield_hold)
	else:
		_player.set("item_shield_hp", 0.0)
	if T < 6.0 and T >= -3.0:
		_hp_ratio = lerpf(0.52, 0.11, clampf(T / 6.0, 0.0, 1.0))
	## ── ilk çekimde kaçınma yürüyüşü ──
	if _kite and T < 5.6:
		var seq: Array = [["move_left"], ["move_up"], ["move_right"], ["move_down"], ["move_left", "move_down"], ["move_right", "move_up"]]
		_move = seq[int(maxf(T + 3.0, 0.0) / 0.9) % seq.size()]
		if (SPOT - _player.global_position).length() > 90.0:
			_move = _dir_to(_player.global_position, SPOT)
	## ── kubbe zorlanıyor: Şovalye kuklasının kubbe görseli titrer (yalnız bu ekranda) ──
	var sv: Node2D = _remote_char(7)
	if sv:
		var bv: Variant = sv.get("_barrier_visual")
		if bv is CanvasItem and is_instance_valid(bv):
			if _dome_flicker:
				var tt: float = float(Time.get_ticks_msec()) / 1000.0
				var a: float = 0.62 + 0.38 * absf(sin(tt * 13.0))
				if fmod(tt * 7.3, 1.0) < 0.12:
					a = 0.25
				(bv as CanvasItem).modulate.a = a
			else:
				(bv as CanvasItem).modulate.a = 1.0


func _tick_host(T: float) -> void:
	_player.set("max_health", 600.0)
	_player.set("health", 600.0)
	if _dome_t0 < 0.0:
		_player.set("item_shield_max", 2000.0)
		_player.set("item_shield_hp", 2000.0)
	else:
		var f: float = clampf((T - _dome_t0) / 5.5, 0.0, 1.0)
		_player.set("item_shield_max", 1000.0)
		_player.set("item_shield_hp", lerpf(1000.0, 90.0, f * f))
	if _trickle:
		_spawn_acc += root.get_process_delta_time()
		if _spawn_acc >= 0.5:
			_spawn_acc = 0.0
			if _enemies_near(SPOT, 520.0).size() < 11:
				_ring_spawn(P1_IDS, SPOT, 330.0, 220.0, 280.0)


## ───────────── BÜYÜCÜ KIZ (viewer): kamera + kendi oyunu ─────────────

func _viewer_script() -> void:
	## ÇEKİM 1 "Tek başına": geniş çöl -> yavaşça içeri
	_cam_mode = "self"
	_zoom = 2.2
	_zoom_target = 3.7
	_zoom_k = 0.010
	await _at(1.2)
	await _cast_boosted("skill2")
	await _at(3.8)
	await _cast_boosted("skill2")
	## ÇEKİM 2 "Yardım": yakın plan, ağır çekim, gerçek sohbet
	await _at(5.6)
	_kite = false
	_move = []
	_zoom_target = 5.4
	_zoom_k = 0.05
	_hp_ratio = 0.09
	await _at(6.0)
	_sig("help")
	_say(":yardim:")
	## ÇEKİM 3 "Talon": Talon kenardan girer, kadraj ikisini alır
	await _wait_sig("help", 2.3)
	_zoom_target = 3.9
	_zoom_k = 0.03
	await _wait_sig("talon_pre", 0.0) ## kamera o ana kadar yalnız Büyücü'de: Talon kenardan, ağır çekimde girer
	_cam_mode = "pair"
	_cam_k = 0.035
	await _wait_sig("talon_e", 0.0)
	_zoom_target = 4.2
	await _wait_sig("talon_wink", 0.9)
	_say(":kalp:")
	## ÇEKİM 4 "Kalabalık": geri çekilip halkayı göster, korku
	await _wait_sig("horde", 0.25)
	_zoom_target = 2.0
	_zoom_k = 0.06
	await _wait_sig("horde", 1.3)
	_nudge("move_right", 0.06) ## sırtı Talon'a dönük, dışarı bakar
	var fe: GDScript = load("res://scripts/fear_emote.gd")
	fe.call("show_on", _player, 0, 3.2, 0.0)
	var tal: Node2D = _remote_char(1)
	if tal:
		fe.call("show_on", tal, 2, 3.2, 0.3)
	_hp_ratio = 0.07
	await _wait_sig("horde", 2.0)
	_say(":saskin:")
	_zoom_target = 2.6
	_zoom_k = 0.012
	## ÇEKİM 5 "Şovalye": kamera koşan Şovalye'ye kayar, ışınlanınca ikiliye savrulur
	await _wait_sig("sov_run", 0.15)
	_cam_mode = "sov"
	_cam_k = 0.09
	_zoom_target = 3.3
	_zoom_k = 0.05
	await _wait_sig("blink", 0.0)
	_cam_mode = "trio"
	_cam_k = 0.14
	_zoom_target = 2.8
	await _wait_sig("dome", 0.6)
	_cam_k = 0.05
	_cam_bias = Vector2(0, -34)
	## ÇEKİM 6 "Kalkan zorlanıyor"
	await _wait_sig("dome", 1.2)
	_dome_flicker = true
	_zoom_target = 3.0
	_zoom_k = 0.01
	## ÇEKİM 7 "Bakışma": yakın iki kişilik plan, ağır çekim
	await _wait_sig("dome", 3.8)
	_cam_mode = "pair"
	_cam_bias = Vector2(0, -10)
	_cam_k = 0.07
	_zoom_target = 4.7
	_zoom_k = 0.06
	_nudge("move_left", 0.06) ## Talon'a dön
	_sig("look")
	await _wait_sig("look", 1.3)
	_say(":ates:")
	## ÇEKİM 8 "Birlikte": set değişimi + meteor; geri çekil
	await _wait_sig("look", 2.45)
	_shield_hold = 300.0
	await _cast("skill") ## Büyü Değişimi -> Set 2 (R = Meteor)
	await _gwait(0.35)
	_cam_mode = "trio"
	_cam_bias = Vector2(0, -30)
	_zoom_target = 2.45
	_zoom_k = 0.04
	_cam_k = 0.05
	await _cast("skill3", 300.0) ## Meteor Patlaması (3 sn odak)
	_sig("meteor")
	await _gwait(3.0)
	_sig("impact")
	_dome_flicker = false
	await _wait_sig("impact", 2.4)
	_shield_hold = 0.0
	## ÇEKİM 9 "Zafer": üçlüye yaklaş, emojiler
	await _wait_sig("impact", 3.2)
	_zoom_target = 3.5
	_zoom_k = 0.015
	_hp_ratio = 0.12
	await _wait_sig("impact", 4.6)
	_say(":kalp:")
	await _wait_sig("impact", 6.6)
	_sig("end")
	_done = true


## Mana kalkanı yetmezse yetenek "MANA K. YETERSİZ" der: bastığı anda kısa süre kalkan, sonra sıfır.
func _cast_boosted(slot: String) -> void:
	_shield_hold = 120.0
	await _gwait(0.08)
	await _cast(slot, 120.0)
	await _gwait(0.2)
	_shield_hold = 0.0


## ───────────── TALON (c1) ─────────────

func _talon_script() -> void:
	await _wait_sig("help", 0.7)
	var guard: int = 0
	while guard < 2000:
		guard += 1
		var her: Vector2 = _pos_of(4)
		if her == Vector2.INF:
			await process_frame
			continue
		if her.distance_to(_player.global_position) <= 262.0:
			break
		_move = _dir_to(_player.global_position, her)
		await process_frame
	var her2: Vector2 = _pos_of(4)
	_move = _dir_to(_player.global_position, her2) if her2 != Vector2.INF else ["move_right"]
	_sig("talon_pre")
	await _gwait(0.06)
	await _cast("skill") ## Hamle Vuruşu (Q)
	_sig("talon_q")
	await _gwait(0.3)
	_move = []
	await _cast("skill2") ## Silah Salvosu (E)
	_sig("talon_e")
	await _gwait(2.9)
	_say(":kirp:")
	_sig("talon_wink")
	## kalabalık: Büyücü'nün yanına, sırt sırta
	await _wait_sig("horde", 0.4)
	guard = 0
	while guard < 600:
		guard += 1
		var her3: Vector2 = _pos_of(4)
		if her3 == Vector2.INF:
			break
		var spot: Vector2 = her3 + Vector2(-30, 4)
		if spot.distance_to(_player.global_position) <= 8.0:
			break
		_move = _dir_to(_player.global_position, spot)
		await process_frame
	_move = []
	await _nudge("move_left", 0.06) ## dışarı bak
	## bakışma
	await _wait_sig("look", 0.0)
	_nudge("move_right", 0.06)
	await _wait_sig("look", 0.6)
	_say(":kilic:")
	await _wait_sig("look", 2.9)
	await _cast("skill3", 2000.0) ## Ayna Formu (R)
	await _wait_sig("meteor", 0.0)
	await _gwait(2.2)
	await _cast("skill2") ## Silah Salvosu (E) - meteor inişini kapsar
	_sig("talon_fin")
	await _wait_sig("impact", 3.5)
	_say(":kahkaha:")


## ───────────── ŞOVALYE (host): yaratıklar + kendi oyunu ─────────────

func _host_script() -> void:
	await _at(-3.6)
	_trickle = true
	for i in 9:
		_ring_spawn(P1_IDS, SPOT, 280.0, 190.0, 280.0)
	await _wait_sig("talon_e", 0.3)
	_trickle = false
	_soften(8.0)
	await _wait_sig("talon_e", 2.2)
	_soften(1.0)
	await _wait_sig("talon_wink", 1.6)
	for e in _enemies_near(SPOT, 1300.0):
		e.call("take_damage", 99999.0)
	## sakinlik, sonra kalabalık: dışarıdan içe dolan halka
	await _wait_sig("talon_wink", 2.6)
	_sig("horde")
	for i in 42:
		_ring_spawn(HORDE_IDS, SPOT, 410.0, 255.0, 900.0) ## geri çekilen kadrajın hemen dışında: zoom açılınca çember görünür
		if i % 6 == 5:
			await _gwait(0.12)
	_log("kalabalik: %d" % _enemies_near(SPOT, 1300.0).size())
	## Şovalye koşar (kamera onu takip eder)
	await _wait_sig("horde", 2.6)
	_sig("sov_run")
	var guard: int = 0
	while guard < 2000:
		guard += 1
		var c: Vector2 = Vector2.ZERO
		var k: int = 0
		for cid in [1, 4]:
			var p: Vector2 = _pos_of(cid)
			if p != Vector2.INF:
				c += p
				k += 1
		if k == 0:
			await process_frame
			continue
		c /= float(k)
		## ikilinin ÜSTÜNE değil biraz arkasına (yukarı) insin: Büyücü'yü örtmesin (v2 ilk çekimde tam üstüne iniyordu)
		var tgt: Vector2 = c + Vector2(0, -46)
		var d: Vector2 = tgt - _player.global_position
		if d.x >= -240.0 and absf(d.y) <= 8.0:
			break
		var mv: Array = []
		if d.x < -240.0:
			mv.append("move_left")
		elif d.x > 0.0:
			mv.append("move_right")
		if d.y < -6.0:
			mv.append("move_up")
		elif d.y > 6.0:
			mv.append("move_down")
		_move = mv
		await process_frame
	_move = ["move_left"] ## ışınlanma yönü: tam sola
	await _gwait(0.03)
	await _cast("skill4") ## Taktiksel (F) - ışınlanma
	_sig("blink")
	await _gwait(0.22)
	_move = []
	_dome_t0 = _t()
	await _cast("skill3", 1000.0) ## Koruma Baloncuğu (R)
	_sig("dome")
	## final: meteor inişinde yaratıklar kırılgan
	await _wait_sig("impact", 0.0)
	_soften(26.0)
	await _gwait(1.1)
	_soften(3.0)
	await _wait_sig("impact", 4.05)
	_say(":begen:")
	await _wait_sig("impact", 4.8)
	_kill_all()
