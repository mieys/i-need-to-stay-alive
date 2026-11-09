extends SceneTree

## TANITIM - CO-OP SAHNESİ (2026-11-09, kullanıcı: "evet ekle" - videolara gerçek çok oyunculu sahne). mp_clutter.gd (madde 425) düzeni:
## host + c1 + c2 BAŞSIZ eşler (savaşır, yetenek basar), viewer = gizli masaüstünde pencereli İSTEMCİ, dikey 1080x1920 kaydeder.
## Movie Maker KULLANILMAZ: sabit kare adımı yalnız bir süreci yavaşlatır, ağ gerçek zamanlı akar -> kuklalar kayar. Viewer gerçek zamanlı
## koşar; her karede kök doku JPG (yan iş parçacığında yazılır) + zaman damgası (zaman.json), ses Master bus'ta AudioEffectRecord (ses.wav).
## Herkes aynı çapaya (SPOT + rol ofseti) bağlı yürür -> grup kadrajda toplu kalır. Yaratıklar host'ta, oyunun doğuş kuralıyla (arazi + duvar,
## tanitim_capture.gd _spawn_ok ile aynı), istemcilere duyurulur. Sürücü: tools/tanitim/coop.ps1. Ortam: CO_ROLE, CO_CHAR, CO_WEAPONS,
## CO_NAME, CO_PORT, CO_PLAYERS, CO_TIER, CO_N, CO_SECS, CO_REC_FROM, CO_REC_SECS, CO_ZOOM, TN_DIR.

const SPOT := Vector2(3616, 2000)
const DUSK := 352.0
const OFFSETS := {"viewer": Vector2(0, 0), "host": Vector2(-62, -30), "c1": Vector2(64, -26), "c2": Vector2(4, 58)}
const PHASE := {"host": 0.0, "c1": 1.3, "c2": 2.6, "viewer": 3.9}
const KEEP_LAYER_SCRIPTS: Array = ["atmosphere_overlay.gd", "vision_fog.gd", "sun_clouds.gd"]

var _role: String = OS.get_environment("CO_ROLE")
var _char: int = _ei("CO_CHAR", 10)
var _port: int = _ei("CO_PORT", 7833)
var _expected: int = _ei("CO_PLAYERS", 4)
var _tier: int = _ei("CO_TIER", 7)
var _n: int = _ei("CO_N", 45)
var _secs: float = float(_ei("CO_SECS", 40))
var _rec_from: float = float(_ei("CO_REC_FROM", 10))
var _rec_secs: float = float(_ei("CO_REC_SECS", 14))
var _zoom: float = float(OS.get_environment("CO_ZOOM")) if OS.get_environment("CO_ZOOM") != "" else 2.6
var _dir: String = OS.get_environment("TN_DIR")
var _nm: Node
var _gm: Node
var _main: Node
var _player: Node2D
var _spawner: Node
var _roster: Array = []
var _merchant: Node = null
var _rec: bool = false
var _rec_i: int = 0
var _rec_t: Array = []
var _rec_t0: int = 0
var _audio_rec: AudioEffectRecord = null
var _pending: int = 0
var _mutex := Mutex.new()
var _rd_fmt: Dictionary = {}
var _cam_off: Vector2 = Vector2.ZERO


func _ei(k: String, d: int) -> int:
	var v: String = OS.get_environment(k)
	return int(v) if v != "" else d


func _initialize() -> void:
	if _role == "viewer":
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		root.content_scale_size = Vector2i(1080, 1920)
		RenderingServer.frame_post_draw.connect(_on_post_draw)
	_run.call_deferred()


func _log(s: String) -> void:
	print("CO[%s] %s" % [_role, s])


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


func _press(slot: String) -> void:
	Input.action_press(slot)
	await process_frame
	await physics_frame
	await process_frame
	await process_frame
	Input.action_release(slot)


# ───────────────────────────── kayıt (viewer) ─────────────────────────────

## Okuma GPU'yu durdurmadan: RenderingDevice.texture_get_data_async (ilk deneme get_image ile 28,6 fps, 22-74 ms düzensiz aralık).
## RD yoksa (uyumluluk sürücüsü) eşzamanlı get_image'a düşer.
func _on_post_draw() -> void:
	if not _rec:
		return
	var path: String = _dir.path_join("kareler/coop/%05d.jpg" % _rec_i)
	_rec_t.append(Time.get_ticks_usec() - _rec_t0)
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
			_log("rd doku %dx%d bicim %d" % [tf.width, tf.height, tf.format])
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
	DirAccess.make_dir_recursive_absolute(_dir.path_join("kareler/coop"))
	_audio_rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, _audio_rec)
	_rec_t0 = Time.get_ticks_usec()
	_audio_rec.set_recording_active(true)
	_rec = true
	_log("kayit basladi")


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
	var f := FileAccess.open(_dir.path_join("zaman.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"frames": _rec_i, "t_us": _rec_t, "dur": dur, "audio_len": audio_len}))
	f.close()
	_log("kayit bitti kare=%d sure=%.2f ort_fps=%.1f ses=%.2f" % [_rec_i, dur, float(_rec_i) / maxf(0.01, dur), audio_len])


# ───────────────────────────── yardımcılar ─────────────────────────────

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


func _spawn_at(id: String, pos: Vector2) -> void:
	var nid: int = int(_spawner.get("_next_network_enemy_id"))
	_spawner.set("_next_network_enemy_id", nid + 1)
	var e: Node2D = _spawner.call("_spawn_creature", id, pos, nid)
	if e == null:
		return
	e.set_meta("spawn_tier", _tier)
	if e.has_method("apply_tier_scaling"):
		e.call("apply_tier_scaling", _tier)
	_spawner.call("_enable_regular_shield", e, _tier)
	_spawner.call("_apply_global_buff", e)
	_spawner.call("_announce_spawn", e, id, pos, _tier, false, nid, false, false)


# ───────────────────────────── akış ─────────────────────────────

func _run() -> void:
	await process_frame
	if _role != "viewer":
		AudioServer.set_bus_mute(0, true)
		Engine.max_fps = 60 ## başsız eşler sınırsız dönüp izleyicinin işlemcisini yemesin
	var mb: int = AudioServer.get_bus_index("Music")
	if mb >= 0:
		AudioServer.set_bus_mute(mb, true)
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	var nick: String = OS.get_environment("CO_NAME") if OS.get_environment("CO_NAME") != "" else _role
	if _role == "host":
		if not _nm.call("host_lan", _port, nick, _char):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= _expected and _nm.call("all_players_ready"), 90.0)
		if not _nm.call("all_players_ready"):
			_log("HATA istemciler gelmedi"); quit(1); return
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0 + float(PHASE.get(_role, 0.0)) * 0.4)
		if not _nm.call("join_lan", "127.0.0.1", _port, nick, _char):
			_log("HATA join_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= _expected, 60.0)
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
	await _wait(1.5)
	_player = _main.get_node_or_null("Player") as Node2D
	_spawner = _main.get_node_or_null("EnemySpawner")
	if _player == null:
		_log("HATA Player yok"); quit(1); return
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", DUSK)
		atmo.call("debug_set_weather", 0)
	while (_player.get("owned_weapon_nodes") as Array).size() > 0:
		_player.call("remove_owned_weapon", 0)
	await _wait(0.3)
	for k in OS.get_environment("CO_WEAPONS").split(","):
		if k.strip_edges() != "":
			_player.call("buy_weapon_copy", k.strip_edges(), 3)
	_player.set("level", 20)
	var anchor: Vector2 = SPOT + OFFSETS.get(_role, Vector2.ZERO)
	_player.global_position = anchor
	var cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.reset_smoothing()
	await _until(func(): return get_nodes_in_group("remote_players").size() >= _expected - 1, 30.0)
	_log("senaryo (kukla: %d)" % get_nodes_in_group("remote_players").size())
	if _spawner and _role == "host":
		_spawner.set("_spawn_tier", _tier)
		_gm.set("game_time", float(_tier - 1) * 150.0 + 20.0)
		_roster = _spawner.call("_spawnable_roster", _tier)
	var phase: float = float(PHASE.get(_role, 0.0))
	var next: Dictionary = {"skill": 3.0 + phase, "skill2": 5.0 + phase, "skill3": 8.0 + phase}
	var gaps: Dictionary = {"skill": 6.0, "skill2": 9.0, "skill3": 13.0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 909 + _char
	var t0: int = Time.get_ticks_msec()
	var frame: int = 0
	var rec_done: bool = false
	while float(Time.get_ticks_msec() - t0) / 1000.0 < _secs:
		paused = false
		frame += 1
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if _spawner:
			_spawner.set("_spawn_timer", 1.0e9)
		_gm.set("team_xp_needed", 1.0e12)
		_player.set("xp_to_next_level", 1.0e12)
		_player.set("max_health", 1.0e9)
		_player.set("health", 1.0e9)
		if frame % 30 == 0:
			if _role != "viewer":
				Engine.max_fps = 60
			_no_merchant()
			if _role == "viewer":
				_hide_ui()
		if _role == "viewer" and cam and is_instance_valid(cam):
			cam.zoom = Vector2(_zoom, _zoom)
			## Kadraj grubun ortasına: kamera sürükleme payı (yatay ekrana göre) dikeyde oyuncuyu kenara itiyordu.
			cam.drag_horizontal_enabled = false
			cam.drag_vertical_enabled = false
			var c: Vector2 = _player.global_position
			var k: int = 1
			for r in get_nodes_in_group("remote_players"):
				if r is Node2D and (r as Node2D).global_position.distance_to(_player.global_position) < 400.0:
					c += (r as Node2D).global_position
					k += 1
			_cam_off = _cam_off.lerp(c / float(k) - _player.global_position, 0.08)
			cam.offset = _cam_off
		## hareket: aynı kare desen, çapadan 120 px'ten fazla uzaklaşınca çapaya dön (grup toplu kalır)
		var act: String = ["move_right", "move_down", "move_left", "move_up"][int((el + phase) / 1.2) % 4]
		var d: Vector2 = anchor - _player.global_position
		if d.length() > 120.0:
			act = ("move_right" if d.x > 0.0 else "move_left") if absf(d.x) > absf(d.y) else ("move_down" if d.y > 0.0 else "move_up")
		for a in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(a)
		Input.action_press(act)
		for slot in ["skill", "skill2", "skill3"]:
			if el >= float(next[slot]):
				next[slot] = el + float(gaps[slot])
				var sv: Array = ["skill_state" if slot == "skill" else slot + "_state", "skill_timer" if slot == "skill" else slot + "_timer"]
				_player.set(sv[0], "ready")
				_player.set(sv[1], 0.0)
				_player.set("item_shield_max", 2000.0)
				_player.set("item_shield_hp", 2000.0)
				_player.set("necro_souls", 25)
				_press(slot)
		if _role == "host" and _spawner and frame % 6 == 0 and not _roster.is_empty():
			var near: int = 0
			for e in get_nodes_in_group("enemies"):
				if e is Node2D and (e as Node2D).global_position.distance_squared_to(SPOT) < 800.0 * 800.0:
					near += 1
			for i in mini(6, _n - near):
				for _try in range(6):
					var a: float = rng.randf() * TAU
					var p: Vector2 = SPOT + Vector2(cos(a) * 300.0, sin(a) * 470.0) * rng.randf_range(1.0, 1.15)
					if _spawn_ok(p):
						_spawn_at(str(_roster[rng.randi() % _roster.size()]), p)
						break
		if _role == "viewer":
			if not _rec and not rec_done and el >= _rec_from:
				_start_rec()
			elif _rec and el >= _rec_from + _rec_secs:
				await _stop_rec()
				rec_done = true
		await process_frame
	if _rec:
		await _stop_rec()
	_log("bitti")
	await _wait(2.0)
	quit()
