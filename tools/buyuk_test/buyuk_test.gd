extends SceneTree

## BÜYÜK TEST (2026-11-06, kullanıcı: "bütün karakterleri bütün silahları ve bütün kademeleri test et, konfor/görünüş/kalite/buglı her şeyi fark et").
## Gerçek renderer + gerçek Main + gizli masaüstü (`run.ps1`). Sonuç satırları "BT ..." ile başlar, motor hataları aynı günlüğe düşer
## (rapor betiği `rapor.py` ikisini sırayla okuyup hatayı o anki yapılandırmaya bağlar). Ekran görüntüleri BT_OUT altına jpg.
## Kipler (BT_MODE):
##   data  : başsız veri tutarlılığı - karakter/silah/yaratık kayıtları, ikon + klip eksikleri, bekleme metni <-> SKILL_TIMING.
##   wt    : TEK karakterde 19 silah x 6 kademe (1-5 + final sonrası "güçlendirme +5"): hasar, kare süresi, düğüm sızıntısı, 2 görüntü.
##   ch    : her karakter x Q/E/R (+ boşta): durum geçişi, bekleme, hasar farkı, kare süresi, 2 görüntü.
##   cw    : her karakter x 19 silah (kademe 1): karaktere özgü silah etkileşimleri, hasar, 1 görüntü.
##   crowd : 15 kademenin kalabalığı (yaratık listesi + boss): tam kare görüntü (HUD dahil), kare süresi, boss yanında görüntü.
## Ortam: BT_CHAR, BT_CHARS (a,b,c), BT_WEAPONS (a,b), BT_TIERS (1,5), BT_N (yaratık), BT_SEC (silah başına süre), BT_TIER_LIST.

const CHARS_ALL: Array = [1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15]
const LOADOUT: Array = ["uzunkilic", "tabanca", "fire_staff"]
const DUMMY_ROSTER: Array = ["slime1", "zombie1", "zombie2", "iskelet2", "ork1"]
const DIRS: Array = ["down", "left", "right", "up"]
const REQ_CLIPS: Array = ["idle_", "walk_", "hurt_", "downed_", "death_", "eat_", "ride_"]
const INFO_CLIPS: Array = ["sit_", "run_", "dash_"]

var _mode: String = OS.get_environment("BT_MODE")
var _out: String = OS.get_environment("BT_OUT")
var _char: int = _env_int("BT_CHAR", 2)
var _n: int = _env_int("BT_N", 5)
var _sec: float = float(_env_int("BT_SEC", 5))
var _gm: Node = null
var _main: Node = null
var _player: Node2D = null
var _spawner: Node = null
var _dummies: Array = []
var _dummy_start: Array = []
var _target_crowd: int = 0
var _roster: Array = []
var _tier: int = 1
var _walk: bool = false


func _env_int(k: String, d: int) -> int:
	var v: String = OS.get_environment(k)
	return int(v) if v != "" else d


func _env_list(k: String, d: Array) -> Array:
	var v: String = OS.get_environment(k)
	if v == "":
		return d
	var out: Array = []
	for s in v.split(","):
		out.append(s.strip_edges())
	return out


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


var _keep_pause: bool = false


func _on_frame() -> void:
	if not _keep_pause:
		paused = false
	if _player == null or not is_instance_valid(_player):
		return
	_player.set("xp_to_next_level", 1.0e12) ## seviye atlama/pazar ekranı görüntüleri kaplamasın
	if _gm != null:
		_gm.set("team_xp_needed", 1.0e12) ## asıl sayaç TAKIM seviyesi (GameManager.add_team_xp) - oyuncunun xp_to_next_level'i değil
	if _target_crowd > 0 and _spawner != null and Engine.get_process_frames() % 6 == 0:
		var near: int = 0
		var pp: Vector2 = _player.global_position
		for e in get_nodes_in_group("enemies"):
			if e is Node2D and (e as Node2D).global_position.distance_squared_to(pp) < 900.0 * 900.0:
				near += 1
		if near < _target_crowd and not _roster.is_empty():
			for i in mini(8, _target_crowd - near):
				_spawner.call("debug_spawn_creature", _roster[randi() % _roster.size()], _tier, 1, pp)
	if _walk:
		var ph: int = int(Time.get_ticks_msec() / 1500) % 4
		for a in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(a)
		Input.action_press(["move_right", "move_down", "move_left", "move_up"][ph])


func _boot(char_id: int, start_weapon: String) -> bool:
	_target_crowd = 0
	_walk = false
	_player = null
	_dummies.clear()
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	for c in _gm.get_children():
		var sc: Variant = c.get_script()
		if sc != null and str((sc as Script).resource_path).ends_with("hitch_log.gd"):
			c.set_process(false)
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", char_id)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(char_id).get("skill", 1))
	_gm.set("selected_start_weapon", start_weapon)
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true) ## kayıt (Ruh Kıymığı/rekor) yazılmasın
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	if current_scene == null or current_scene.name != "Main":
		return false
	_main = current_scene
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	await _wait(2.5)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house") and OS.get_environment("BT_NO_EXIT_HOUSE") == "":
		house.call("_do_exit_house")
	await _wait(2.0)
	_player = _main.get_node_or_null("Player") as Node2D
	_spawner = _main.get_node_or_null("EnemySpawner")
	if _spawner:
		_spawner.set("_spawn_timer", 1.0e9)
	if not process_frame.is_connected(_on_frame):
		process_frame.connect(_on_frame)
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 150.0) ## gündüz, açık hava
		atmo.call("debug_set_weather", 0)
	return _player != null


func _fix_sky() -> void:
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 150.0)
		atmo.call("debug_set_weather", 0)


func _clear_weapons() -> void:
	while (_player.get("owned_weapon_nodes") as Array).size() > 0:
		_player.call("remove_owned_weapon", 0)
	await _wait(0.25)


func _clear_enemies() -> void:
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	_dummies.clear()


## Hareketsiz + ölmeyen hedefler. Hız/can _ready'den ÖNCE verilir (C++ dünyasına kayıt anında okunur).
func _spawn_dummies(count: int, rmin: float, rmax: float) -> void:
	_clear_enemies()
	_dummy_start.clear()
	await _wait(0.2)
	var pp: Vector2 = _player.global_position
	for i in range(count):
		var id: String = DUMMY_ROSTER[i % DUMMY_ROSTER.size()]
		var ps: PackedScene = load("res://scenes/creatures/enemy_%s.tscn" % id)
		var e: Node2D = ps.instantiate()
		e.set("speed", 0.0)
		e.set("max_health", 1.0e9)
		_main.add_child(e)
		var a: float = TAU * float(i) / float(maxi(1, count)) + 0.4
		e.global_position = pp + Vector2(cos(a), sin(a) * 0.7) * randf_range(rmin, rmax)
		e.set("health", 1.0e9)
		_dummies.append(e)
		_dummy_start.append(e.global_position)
	await _wait(0.4)


func _dummy_hp() -> float:
	var s: float = 0.0
	for d in _dummies:
		if is_instance_valid(d):
			s += float(d.get("health"))
		else:
			s += 0.0
	return s


func _shot(nm: String, crop: Vector2i = Vector2i(640, 360), down: float = 1.0) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null or img.is_empty():
		print("BT SHOTFAIL %s" % nm)
		return
	if crop.x > 0:
		var sz: Vector2i = img.get_size()
		var c: Vector2i = Vector2i(clampi(sz.x / 2 - crop.x / 2, 0, maxi(0, sz.x - crop.x)), clampi(sz.y / 2 - crop.y / 2, 0, maxi(0, sz.y - crop.y)))
		img = img.get_region(Rect2i(c, Vector2i(mini(crop.x, sz.x), mini(crop.y, sz.y))))
	if down != 1.0:
		img.resize(int(img.get_width() * down), int(img.get_height() * down), Image.INTERPOLATE_LANCZOS)
	img.save_jpg(_out.path_join(nm + ".jpg"), 0.9)


func _shot_rect(nm: String, rect: Rect2i) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null or img.is_empty():
		print("BT SHOTFAIL %s" % nm)
		return
	img = img.get_region(rect.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	img.save_jpg(_out.path_join(nm + ".jpg"), 0.92)


func _stats(arr: Array) -> Dictionary:
	if arr.is_empty():
		return {"mean": 0.0, "p50": 0.0, "p95": 0.0, "max": 0.0}
	var a: Array = arr.duplicate()
	a.sort()
	var s: float = 0.0
	for v in a:
		s += float(v)
	return {"mean": s / a.size(), "p50": a[a.size() / 2], "p95": a[mini(a.size() - 1, int(a.size() * 0.95))], "max": a[a.size() - 1]}


## sec boyunca kare süreleri; shots listesi görüntüleri süreye eşit aralıkla alır.
func _window(sec: float, shots: Array, crop: Vector2i, down: float = 1.0) -> Dictionary:
	var arr: Array = []
	var t0: int = Time.get_ticks_usec()
	var last: int = t0
	var si: int = 0
	while float(Time.get_ticks_usec() - t0) / 1.0e6 < sec:
		await process_frame
		var now: int = Time.get_ticks_usec()
		arr.append(float(now - last) / 1000.0)
		last = now
		if si < shots.size() and float(now - t0) / 1.0e6 >= sec * float(si + 1) / float(shots.size() + 1):
			await _shot(str(shots[si]), crop, down)
			last = Time.get_ticks_usec()
			si += 1
	return _stats(arr)


func _fmt(m: Dictionary) -> String:
	return "mean=%.2f p50=%.2f p95=%.2f max=%.1f" % [m["mean"], m["p50"], m["p95"], m["max"]]


func _nodes() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(_out)
	print("BT START mode=%s char=%d" % [_mode, _char])
	match _mode:
		"data":
			_data()
		"wt":
			await _wt()
		"ch":
			await _ch()
		"cw":
			await _cw()
		"crowd":
			await _crowd()
		"dmgnum":
			await _dmgnum()
		"dock":
			await _dock()
		"select":
			await _select()
		"prompt":
			await _prompt()
		"dil":
			await _dil()
		"gizlenme":
			await _gizlenme()
		"esc":
			await _esc()
		_:
			print("BT BADMODE %s" % _mode)
	print("BT DONE mode=%s" % _mode)
	quit(0)


# ───────────────────────────── esc ─────────────────────────────
## ESC duraklatma menüsü (kullanıcı 2026-11-09: "karakter ölünce esc'ye basılmıyor, çoğu zaman esc menüsü açılamıyor").
## Gerçek Main + gerçek tuş olayı (Input.parse_input_event): canlıyken tekrarlı aç/kapa, çok kısa dokunuş, izleyici (ölü, takım hayatta) ve oyun bitti.

func _esc_event(pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.keycode = KEY_ESCAPE
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _press_esc(hold_frames: int = 6) -> void:
	_esc_event(true)
	for i in hold_frames:
		await process_frame
	_esc_event(false)
	await process_frame


func _pause_open() -> bool:
	var inst: Variant = _main.get("pause_menu_instance")
	return inst != null and is_instance_valid(inst) and not (inst as Node).is_queued_for_deletion()


func _esc_state(tag: String) -> void:
	print("BT ESC %s acik=%s paused=%s engelleyici=%s tuketildi=%s oyun_bitti=%s" % [tag, _pause_open(), paused,
			_gm.call("is_any_blocking_panel_open"), _gm.call("was_ui_cancel_consumed"), _gm.get("is_game_over")])


func _esc() -> void:
	if not await _boot(_char, LOADOUT[0]):
		print("BT BOOTFAIL")
		return
	_keep_pause = true
	_gm.set("debug_immortal", true)
	_esc_state("basla")
	var esc_case: String = OS.get_environment("BT_ESC_CASE")
	if esc_case == "intro":
		# açılış sahnesi (evde, deprem + geri sayım): ESC her an açılmalı
		for i in 8:
			await _press_esc()
			await _wait(0.5)
			var open_a: bool = _pause_open()
			if open_a:
				await _press_esc()
				await _wait(0.5)
			print("BT ESC intro t=%d acti=%s kapandi=%s kuşatma_bekliyor=%s" % [i, open_a, not _pause_open(), _gm.get("invasion_pending")])
			await _wait(1.5)
		return
	if esc_case == "c_only" or esc_case == "b_plain":
		if esc_case == "c_only":
			_main.call("_show_death_overlay", false)
			await _wait(0.5)
		else:
			_esc_event(true)
			_esc_event(false)
			await _wait(0.5)
			_esc_state("b_dokunus")
			await _press_esc()
			await _wait(0.5)
			_esc_state("b_kapatma")
		for i in 4:
			await _press_esc()
			await _wait(0.5)
			_esc_state("%s i=%d" % [esc_case, i])
			if i == 0:
				await _shot("esc_%s_acik" % esc_case, Vector2i(0, 0), 0.5)
				await _wait(0.3)
		return
	# A: canlıyken 6 kez aç/kapa (çift sıra = açık beklenir)
	for i in 6:
		await _press_esc()
		await _wait(0.5)
		_esc_state("canli i=%d beklenen=%s" % [i, "acik" if i % 2 == 0 else "kapali"])
	if _pause_open():
		await _press_esc()
		await _wait(0.5)
	# B: aynı karede basış + bırakış (çok kısa dokunuş)
	_esc_event(true)
	_esc_event(false)
	await _wait(0.5)
	_esc_state("ayni_kare_dokunus")
	if _pause_open():
		await _press_esc()
		await _wait(0.5)
	# C: ölü izleyici (takım hayatta, oyun bitmedi): ölüm ekranı açık -> menü AÇILMALI ve ölüm ekranının ÜSTÜNDE olmalı
	_main.call("_show_death_overlay", false)
	await _wait(0.5)
	await _press_esc()
	await _wait(0.6)
	_esc_state("izleyici")
	print("BT ESC izleyici menu_katman=%s" % [str((_main.get("pause_menu_instance") as CanvasLayer).layer) if _pause_open() else "yok"])
	await _shot("esc_izleyici_acik", Vector2i(0, 0), 0.5)
	await _wait(0.3)
	if _pause_open():
		await _press_esc()
		await _wait(0.5)
	_esc_state("izleyici_kapandi")
	# D: oyun bitti -> menü AÇILMALI
	_gm.set("is_game_over", true)
	_main.call("_show_death_overlay", true)
	await _wait(0.5)
	await _press_esc()
	await _wait(0.6)
	_esc_state("oyun_bitti")
	print("BT ESC oyun_bitti menu_katman=%s" % [str((_main.get("pause_menu_instance") as CanvasLayer).layer) if _pause_open() else "yok"])
	await _shot("esc_oyun_bitti_acik", Vector2i(0, 0), 0.5)
	await _wait(0.3)
	if _pause_open():
		await _press_esc()
		await _wait(0.5)
	_esc_state("oyun_bitti_kapandi")


# ───────────────────────────── data ─────────────────────────────

func _data() -> void:
	var chars: GDScript = load("res://scripts/characters.gd")
	var defs: Dictionary = chars.DEFS
	var pl: GDScript = load("res://scripts/player.gd")
	var pcm: Dictionary = pl.get_script_constant_map()
	var re: RegEx = RegEx.create_from_string("\\((\\d+(?:[.,]\\d+)?)\\s*sn bekleme\\)")
	for cid in defs:
		var d: Dictionary = defs[cid]
		var nm: String = str(d.get("name", "?"))
		for k in ["name", "skill", "skill_name", "skill_desc", "skill_icon", "passive", "frames", "portrait", "scale"]:
			if not d.has(k) or (d[k] is String and str(d[k]) == ""):
				print("BT DATA char=%d %s eksik anahtar: %s" % [cid, nm, k])
		for ik in ["skill_icon", "skill2_icon", "skill3_icon", "passive_icon", "portrait", "frames"]:
			if d.has(ik) and not ResourceLoader.exists(str(d[ik])):
				print("BT DATA char=%d %s dosya yok: %s=%s" % [cid, nm, ik, str(d[ik])])
		var fr: SpriteFrames = load(str(d.get("frames", ""))) as SpriteFrames if ResourceLoader.exists(str(d.get("frames", ""))) else null
		if fr == null:
			print("BT DATA char=%d %s SpriteFrames yüklenemedi" % [cid, nm])
		else:
			var missing: PackedStringArray = []
			var empty: PackedStringArray = []
			for pre in REQ_CLIPS:
				for dr in DIRS:
					var cn: String = pre + dr
					if not fr.has_animation(cn):
						missing.append(cn)
					elif fr.get_frame_count(cn) == 0:
						empty.append(cn)
			var cast_ok: bool = false
			for dr in DIRS:
				if fr.has_animation("shrug_" + dr) or fr.has_animation("spellcast_" + dr):
					cast_ok = true
			if not cast_ok:
				missing.append("shrug_/spellcast_ (yetenek klibi)")
			if not missing.is_empty():
				print("BT DATA char=%d %s eksik klip: %s" % [cid, nm, ",".join(missing)])
			if not empty.is_empty():
				print("BT DATA char=%d %s boş klip: %s" % [cid, nm, ",".join(empty)])
			var info_missing: PackedStringArray = []
			for pre in INFO_CLIPS:
				if not fr.has_animation(pre + "down"):
					info_missing.append(pre)
			if not info_missing.is_empty():
				print("BT DATAINFO char=%d %s klip ailesi yok: %s" % [cid, nm, ",".join(info_missing)])
			var nclips: int = fr.get_animation_names().size()
			print("BT DATAINFO char=%d %s klip_sayisi=%d" % [cid, nm, nclips])
		for slot in [["skill", "SKILL_TIMING"], ["skill2", "SKILL2_TIMING"], ["skill3", "SKILL3_TIMING"]]:
			var sk: String = slot[0]
			if not d.has(sk):
				print("BT DATA char=%d %s %s yok" % [cid, nm, sk])
				continue
			for need in [sk + "_name", sk + "_desc", sk + "_icon"]:
				if not d.has(need) or str(d[need]) == "":
					print("BT DATA char=%d %s eksik: %s" % [cid, nm, need])
			var tid: int = int(d[sk])
			var tm: Dictionary = pcm.get(slot[1], {})
			if not tm.has(tid):
				print("BT DATA char=%d %s %s id=%d zamanlama tablosunda YOK (%s)" % [cid, nm, sk, tid, slot[1]])
			else:
				var cd: float = float(tm[tid].get("cooldown", -1.0))
				var desc: String = str(d.get(sk + "_desc", ""))
				var m: RegExMatch = re.search(desc)
				if m != null:
					var txt: float = float(m.get_string(1).replace(",", "."))
					if absf(txt - cd) > 0.51:
						print("BT DATA char=%d %s %s metin '%s sn bekleme' <-> kod cooldown=%.1f (id %d)" % [cid, nm, sk, m.get_string(1), cd, tid])
				else:
					print("BT DATAINFO char=%d %s %s metinde '(N sn bekleme)' yok (cooldown kod=%.1f)" % [cid, nm, sk, cd])
		var bs: Dictionary = chars.get_base_stats(cid)
		if bs.is_empty():
			print("BT DATA char=%d %s BASE_STATS yok" % [cid, nm])
	# ── silahlar ──
	var wc: GDScript = load("res://scripts/weapon_catalog.gd")
	var ed: GDScript = load("res://scripts/enchant_defs.gd")
	var ta: GDScript = load("res://scripts/weapon_tier_art.gd")
	var scenes_by_key: Dictionary = pcm.get("WEAPON_SCENES_BY_KEY", {})
	for k in wc.KEYS:
		if not wc.NAMES.has(k):
			print("BT DATA silah=%s NAMES yok" % k)
		if not wc.DESCRIPTIONS.has(k):
			print("BT DATA silah=%s DESCRIPTIONS yok" % k)
		if not ResourceLoader.exists(str(wc.ICONS.get(k, ""))):
			print("BT DATA silah=%s ikon dosyası yok: %s" % [k, str(wc.ICONS.get(k, ""))])
		if not scenes_by_key.has(k):
			print("BT DATA silah=%s player.WEAPON_SCENES_BY_KEY içinde YOK" % k)
		else:
			var ps: PackedScene = scenes_by_key[k]
			var inst: Node = ps.instantiate()
			if inst == null:
				print("BT DATA silah=%s sahne örneklenemedi" % k)
			else:
				inst.free()
		if not ta.ART.has(k):
			print("BT DATAINFO silah=%s weapon_tier_art.ART içinde yok (eski sahne ikonunda kalır)" % k)
		elif not ResourceLoader.exists(str(ta.ART[k])):
			print("BT DATA silah=%s ART dosyası yok: %s" % [k, str(ta.ART[k])])
		var tid: String = str(ed.trait_of(k))
		if tid == "":
			print("BT DATA silah=%s doğuştan özellik YOK" % k)
			continue
		var def: Dictionary = ed.get_def(tid)
		if def.is_empty():
			print("BT DATA silah=%s özellik=%s tanımsız" % [k, tid])
			continue
		var ups: Array = def.get("upgrades", [])
		if ups.size() != 4:
			print("BT DATA silah=%s özellik=%s geliştirme sayısı %d (4 bekleniyordu)" % [k, tid, ups.size()])
		for i in range(ups.size()):
			if str(ups[i].get("name", "")) == "" or str(ups[i].get("text", "")) == "":
				print("BT DATA silah=%s özellik=%s geliştirme %d adı/metni boş" % [k, tid, i])
		if not def.has("final") or str(def["final"].get("name", "")) == "" or str(def["final"].get("text", "")) == "":
			print("BT DATA silah=%s özellik=%s final adı/metni eksik" % [k, tid])
		for t in range(1, 7):
			var rec: Dictionary = {"id": tid, "ups": range(mini(4, t - 1)) if t < 5 else [0, 1, 2, 3], "final": t >= 5, "plus": 5 if t == 6 else 0}
			if (ed.resolve(rec, k) as Dictionary).is_empty():
				print("BT DATA silah=%s kademe %d çözümlenemedi" % [k, t])
		var sp: String = "res://scripts/weapon_traits/%s.gd" % tid
		if not ResourceLoader.exists(sp):
			print("BT DATAINFO silah=%s özellik=%s özel davranış betiği yok (ortak taban sınıf)" % [k, tid])
	# ── yaratıklar ──
	var da: DirAccess = DirAccess.open("res://scenes/creatures")
	if da != null:
		for f in da.get_files():
			if not f.ends_with(".tscn"):
				continue
			var path: String = "res://scenes/creatures/" + f
			var ps2: PackedScene = load(path) as PackedScene
			if ps2 == null:
				print("BT DATA yaratık %s yüklenemedi" % f)
				continue
			var e: Node = ps2.instantiate()
			var sprites: Array = e.find_children("*", "AnimatedSprite2D", true, false)
			if sprites.is_empty():
				print("BT DATAINFO yaratık %s: AnimatedSprite2D yok" % f)
			else:
				var sf: SpriteFrames = (sprites[0] as AnimatedSprite2D).sprite_frames
				if sf == null:
					print("BT DATA yaratık %s: sprite_frames boş" % f)
				else:
					var names: Array = Array(sf.get_animation_names())
					names.sort()
					print("BT DATAINFO yaratık %s klipler=%s" % [f, ",".join(PackedStringArray(names))])
			e.free()


# ───────────────────────────── wt: silah x kademe ─────────────────────────────

func _tier_record(wkey: String, tier: int) -> Dictionary:
	var ed: GDScript = load("res://scripts/enchant_defs.gd")
	var id: String = str(ed.trait_of(wkey))
	if id == "":
		return {}
	var ups: Array = []
	var fin: bool = false
	var plus: int = 0
	match tier:
		2:
			ups = [0]
		3:
			ups = [0, 1]
		4:
			ups = [0, 1, 2]
		5:
			ups = [0, 1, 2, 3]
			fin = true
		6:
			ups = [0, 1, 2, 3]
			fin = true
			plus = 5
	return {"id": id, "ups": ups, "final": fin, "plus": plus}


func _one_weapon(wkey: String, tier: int, tag: String, sec: float, shots: Array) -> void:
	_fix_sky()
	await _clear_weapons()
	seed(7)
	await _spawn_dummies(_n, float(_env_int("BT_RMIN", 70)), float(_env_int("BT_RMAX", 125)))
	var nodes0: int = _nodes()
	var ok: bool = bool(_player.call("buy_weapon_copy", wkey, 1))
	await _wait(0.3)
	var ws: Array = _player.get("owned_weapon_nodes")
	if not ok or ws.is_empty():
		print("BT FAIL %s buy_weapon_copy başarısız" % tag)
		return
	var w: Node = ws[0]
	var rec: Dictionary = _tier_record(wkey, tier)
	if not rec.is_empty():
		w.call("set_enchant", rec)
	await _wait(0.4)
	var glow: int = int(w.get("enchant_glow_tier"))
	var hp0: float = _dummy_hp()
	var m: Dictionary = await _window(sec, shots, Vector2i(640, 360))
	var dmg: float = hp0 - _dummy_hp()
	var vis: bool = (w as CanvasItem).is_visible_in_tree() if w is CanvasItem else true
	var drift: float = 0.0
	var dist_end: float = 0.0
	var nd: int = 0
	for i in range(_dummies.size()):
		if is_instance_valid(_dummies[i]) and i < _dummy_start.size():
			drift += (_dummies[i] as Node2D).global_position.distance_to(_dummy_start[i])
			dist_end += (_dummies[i] as Node2D).global_position.distance_to(_player.global_position)
			nd += 1
	print("BT CFG %s dmg=%.0f dps=%.1f glow=%d vis=%s nodes_d=%d drift=%.0f dist_end=%.0f | %s" % [tag, dmg, dmg / sec, glow, str(vis), _nodes() - nodes0, drift / maxi(1, nd), dist_end / maxi(1, nd), _fmt(m)])


func _wt() -> void:
	if not await _boot(_char, "dagger"):
		print("BT BOOTFAIL")
		return
	_player.set("level", 20)
	var wc: GDScript = load("res://scripts/weapon_catalog.gd")
	var keys: Array = _env_list("BT_WEAPONS", Array(wc.KEYS))
	var tiers: Array = _env_list("BT_TIERS", ["1", "2", "3", "4", "5", "6"])
	for k in keys:
		for t in tiers:
			print("BT >> wt %s t%d" % [k, int(t)])
			await _one_weapon(str(k), int(t), "wt w=%s t=%d" % [k, int(t)], _sec, ["wt_%s_t%d_a" % [k, int(t)], "wt_%s_t%d_b" % [k, int(t)]])


# ───────────────────────────── cw: karakter x silah ─────────────────────────────

func _cw() -> void:
	var wc: GDScript = load("res://scripts/weapon_catalog.gd")
	var keys: Array = _env_list("BT_WEAPONS", Array(wc.KEYS))
	var ids: Array = _env_list("BT_CHARS", CHARS_ALL)
	for cid in ids:
		if not await _boot(int(cid), "dagger"):
			print("BT BOOTFAIL char=%s" % str(cid))
			continue
		_player.set("level", 20)
		for k in keys:
			print("BT >> cw c%s %s" % [str(cid), k])
			await _one_weapon(str(k), 1, "cw c=%s w=%s" % [str(cid), k], 3.5, ["cw_c%s_%s" % [str(cid), k]])


# ───────────────────────────── ch: karakter yetenekleri ─────────────────────────────

func _slot_vars(slot: String) -> Array:
	return ["skill_state" if slot == "skill" else slot + "_state", "skill_timer" if slot == "skill" else slot + "_timer"]


func _press(slot: String) -> void:
	Input.action_press(slot)
	await process_frame
	await physics_frame
	await process_frame
	await process_frame
	Input.action_release(slot)


func _ch() -> void:
	var ids: Array = _env_list("BT_CHARS", CHARS_ALL)
	for cid in ids:
		if not await _boot(int(cid), LOADOUT[0]):
			print("BT BOOTFAIL char=%s" % str(cid))
			continue
		for k in [LOADOUT[1], LOADOUT[2]]:
			_player.call("buy_weapon_copy", k, 1)
		_player.set("level", 20)
		await _spawn_dummies(6, 90.0, 200.0)
		await _wait(1.0)
		print("BT >> ch c%s idle" % str(cid))
		var hp_a: float = _dummy_hp()
		var base: Dictionary = await _window(3.0, ["ch_c%s_idle" % str(cid)], Vector2i(800, 450))
		var base_dmg: float = (hp_a - _dummy_hp()) / 3.0
		print("BT CHIDLE c=%s base_dps=%.1f unlocked=%s | %s" % [str(cid), base_dmg, str([_player.call("is_skill_slot_unlocked", "skill"), _player.call("is_skill_slot_unlocked", "skill2"), _player.call("is_skill_slot_unlocked", "skill3")]), _fmt(base)])
		for slot in ["skill", "skill2", "skill3"]:
			var sv: Array = _slot_vars(slot)
			print("BT >> ch c%s %s" % [str(cid), slot])
			_player.set(sv[0], "ready")
			_player.set(sv[1], 0.0)
			_player.set("item_shield_max", 300.0)
			_player.set("item_shield_hp", 300.0)
			_player.set("necro_souls", 25)
			var st0: String = str(_player.get(sv[0]))
			var hp0: float = _dummy_hp()
			await _press(slot)
			var st1: String = str(_player.get(sv[0]))
			var tm1: float = float(_player.get(sv[1])) if _player.get(sv[1]) != null else -1.0
			var m: Dictionary = await _window(4.0, ["ch_c%s_%s_a" % [str(cid), slot], "ch_c%s_%s_b" % [str(cid), slot]], Vector2i(960, 540))
			var dmg: float = hp0 - _dummy_hp()
			var st2: String = str(_player.get(sv[0]))
			if st2 == "active" or st2 == "on":
				await _press(slot) ## aç/kapa yeteneği kapat
			print("BT CAST c=%s slot=%s st=%s>%s>%s timer=%.1f dps=%.1f base_dps=%.1f | %s" % [str(cid), slot, st0, st1, st2, tm1, dmg / 4.0, base_dmg, _fmt(m)])
			await _wait(3.0)


# ───────────────────────────── crowd: 15 kademe kalabalığı ─────────────────────────────

func _crowd() -> void:
	if not await _boot(_char, LOADOUT[0]):
		print("BT BOOTFAIL")
		return
	for k in [LOADOUT[1], LOADOUT[2]]:
		_player.call("buy_weapon_copy", k, 1)
	_player.set("level", 20)
	_clear_enemies()
	var scm: Dictionary = (_spawner.get_script() as GDScript).get_script_constant_map()
	var rosters: Dictionary = scm.get("TIER_ROSTER", {})
	var bosses: Dictionary = scm.get("NEW_BOSS_TIERS", {})
	var tiers: Array = _env_list("BT_TIER_LIST", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
	_walk = true
	for t in tiers:
		_tier = int(t)
		_roster = Array(rosters.get(_tier, rosters.get(1, [])))
		_gm.set("game_time", float(_tier - 1) * 150.0 + 20.0)
		if _spawner:
			_spawner.set("_spawn_tier", _tier)
		_clear_enemies()
		_fix_sky()
		_target_crowd = _env_int("BT_N", 70)
		print("BT >> crowd tier %d roster=%s" % [_tier, str(_roster)])
		await _wait(7.0)
		var near: int = 0
		for e in get_nodes_in_group("enemies"):
			if e is Node2D and (e as Node2D).global_position.distance_to(_player.global_position) < 700.0:
				near += 1
		var m: Dictionary = await _window(4.0, ["crowd_t%02d" % _tier], Vector2i(0, 0), 0.5)
		print("BT CROWD tier=%d near=%d nodes=%d | %s" % [_tier, near, _nodes(), _fmt(m)])
		if bosses.has(_tier):
			_target_crowd = 20
			for bid in bosses[_tier]:
				_spawner.call("debug_spawn_creature", str(bid), _tier, 1, _player.global_position)
			await _wait(4.0)
			var mb: Dictionary = await _window(3.0, ["crowd_t%02d_boss" % _tier], Vector2i(0, 0), 0.5)
			print("BT BOSS tier=%d id=%s boss_nodes=%d | %s" % [_tier, str(bosses[_tier]), get_nodes_in_group("boss").size(), _fmt(mb)])
	_target_crowd = 0
	_walk = false


# ───────────────────────────── dmgnum: hasar sayısı önce/sonra (madde 429) ─────────────────────────────
## Kalabalıkta (BT_N, varsayılan 60) tek kademe (BT_TIER, varsayılan 8) savaşı; ortadan 960x540 1:1 kırpılmış BT_SHOTS görüntü + ekrandaki
## canlı sayı adedi (ortalama / en çok). BT_DN_OLD=1: DamageNumbers düğümünün betiği tools/buyuk_test/_dn_eski.gd olur (madde 429 öncesi görünüş).
func _dmgnum() -> void:
	if not await _boot(_char, LOADOUT[0]):
		print("BT BOOTFAIL")
		return
	for k in [LOADOUT[1], LOADOUT[2]]:
		_player.call("buy_weapon_copy", k, 1)
	_player.set("level", 20)
	_player.set("fire_rate_mult", float(_player.get("fire_rate_mult")) / 2.5) ## +%150 saldırı hızı (aralık çarpanı): karmaşanın kötü hâli
	var dn_script: GDScript = load("res://scripts/damage_numbers.gd")
	var dn: Node = dn_script.call("get_instance", self)
	await _wait(0.2)
	var old: bool = OS.get_environment("BT_DN_OLD") == "1"
	if old and dn != null:
		dn.set_script(load("res://tools/buyuk_test/_dn_eski.gd"))
		dn.set_process(true)
	print("BT DMGNUM old=%s dn=%s script=%s" % [str(old), str(dn), str(dn.get_script().resource_path if dn else "")])
	_tier = _env_int("BT_TIER", 8)
	var scm: Dictionary = (_spawner.get_script() as GDScript).get_script_constant_map()
	_roster = Array((scm.get("TIER_ROSTER", {}) as Dictionary).get(_tier, []))
	_gm.set("game_time", float(_tier - 1) * 150.0 + 20.0)
	_spawner.set("_spawn_tier", _tier)
	_clear_enemies()
	_fix_sky()
	_target_crowd = _env_int("BT_N", 60)
	_walk = true
	await _wait(6.0)
	var shots: int = _env_int("BT_SHOTS", 4)
	var counts: Array = []
	var t0: int = Time.get_ticks_msec()
	var si: int = 0
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame
		counts.append((dn.get("_list") as Array).size())
		if si < shots and Time.get_ticks_msec() - t0 >= 6000 * (si + 1) / (shots + 1):
			await _shot("dn_%s_%d" % ["eski" if old else "yeni", si], Vector2i(960, 540), 1.0)
			si += 1
	var m: Dictionary = _stats(counts)
	print("BT DMGNUM_COUNT old=%s mean=%.1f p95=%.0f max=%.0f" % [str(old), m["mean"], m["p95"], m["max"]])
	_target_crowd = 0
	_walk = false


# ───────────────────────────── dock: her karakterin tam HUD'u ─────────────────────────────

func _dock() -> void:
	var ids: Array = _env_list("BT_CHARS", CHARS_ALL)
	for cid in ids:
		if not await _boot(int(cid), LOADOUT[0]):
			print("BT BOOTFAIL char=%s" % str(cid))
			continue
		for k in [LOADOUT[1], LOADOUT[2]]:
			_player.call("buy_weapon_copy", k, 1)
		_player.set("level", 20)
		_fix_sky()
		await _spawn_dummies(4, 90.0, 220.0)
		await _wait(2.0)
		print("BT >> dock c%s" % str(cid))
		await _shot("dock_c%s_full" % str(cid), Vector2i(0, 0), 0.5)
		await _shot_rect("dock_c%s_ui" % str(cid), Rect2i(0, 700, 1100, 380)) ## sol alt: yetenek paneli + mini stat paneli, tam çözünürlük
		print("BT DOCK c=%s ok" % str(cid))


# ───────────────────────────── gizlenme: Assasin E odağı + görünmezken karartma, Don Nova dalgası (madde 533) ─────────────────────────────

func _gizlenme() -> void:
	if await _boot(5, LOADOUT[0]):
		_player.set("level", 10)
		_player.set("item_shield_max", 2000.0) ## yetenek bedeli (mana kalkanı)
		_player.set("item_shield_hp", 2000.0)
		_fix_sky()
		await _spawn_dummies(4, 120.0, 260.0)
		await _wait(2.0)
		await _shot("gizlenme_once", Vector2i(0, 0), 0.5)
		_player.call("_activate_skill2")
		await _wait(1.0)
		print("BT GIZ odak alfa=%.2f karartma=%.2f" % [float(_player.modulate.a), float(_player.call("stealth_vision_amount"))])
		await _shot("gizlenme_odak", Vector2i(0, 0), 0.5)
		await _wait(1.6)
		print("BT GIZ gorunmez=%s alfa=%.2f" % [str(_player.get("is_invisible")), float(_player.modulate.a)])
		await _shot("gizlenme_gorunmez", Vector2i(0, 0), 0.5)
	if await _boot(4, LOADOUT[0]):
		_player.set("level", 10)
		_player.set("item_shield_max", 2000.0) ## yetenek bedeli (mana kalkanı)
		_player.set("item_shield_hp", 2000.0)
		_fix_sky()
		await _spawn_dummies(6, 80.0, 300.0)
		await _wait(2.0)
		_player.call("_buyucu_try_activate_variation_r")
		await _wait(0.5)
		print("BT NOVA odak=%s" % str(_player.call("is_buyucu_nova_focusing")))
		await _shot("nova_odak", Vector2i(0, 0), 0.5)
		await _wait(1.3)
		await _shot("nova_dalga_08", Vector2i(0, 0), 0.5)
		await _wait(1.0)
		await _shot("nova_dalga_18", Vector2i(0, 0), 0.5)


# ───────────────────────────── select: karakter seçim ekranı ─────────────────────────────

func _select() -> void:
	var ids: Array = _env_list("BT_CHARS", CHARS_ALL)
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("debug_mode_unlocked", true)
	change_scene_to_file("res://scenes/character_select.tscn")
	await _wait(2.5)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	var cs: Node = current_scene
	var desk: Object = cs.get("_desk") if cs != null else null
	if desk == null:
		print("BT FAIL select: _desk yok (sahne=%s)" % str(cs))
		return
	for cid in ids:
		print("BT >> select c%s" % str(cid))
		desk.call("show_character", int(cid), false)
		await _wait(0.8)
		await _shot("select_c%s" % str(cid), Vector2i(0, 0), 0.75)
		print("BT SELECT c=%s ok" % str(cid))


# ───────────────────────────── prompt: ev ipucu seviye ekranının üstünde kalıyor mu (madde 421) ─────────────────────────────

func _prompt() -> void:
	if not await _boot(_char, LOADOUT[0]):
		print("BT BOOTFAIL")
		return
	var house: Node = _main.get_node_or_null("HouseInterior")
	var layer: Node = house.get_node_or_null("HouseInteriorPromptLayer") if house else null
	if layer == null:
		print("BT FAIL prompt: katman yok")
		return
	# oyuncuyu giriş alanına koy (ipucu görünsün)
	var area: Node = house.get("_entrance_area") if house else null
	await _wait(1.0)
	var lbl: Node = layer.get_node_or_null("InteractPrompt")
	print("BT PROMPT once: etiket_gorunur=%s katman_gorunur=%s near=%s" % [str(lbl.get("visible")) if lbl else "?", str(layer.get("visible")), str(house.get("_near_entrance"))])
	_keep_pause = true
	_main.call("_show_level_up_screen", 2)
	await _wait(1.2)
	print("BT PROMPT seviye_ekrani: paused=%s katman_gorunur=%s" % [str(paused), str(layer.get("visible"))])
	await _shot("prompt_seviye", Vector2i(0, 0), 0.5)
	_keep_pause = false
	paused = false
	await _wait(0.5)


# ───────────────────────────── dil: İngilizce ekranlar (madde 446; run.ps1 -Mode dil -Env "DIL=en") ─────────────────────────────

func _dil() -> void:
	var sc: float = 0.6
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _wait(3.0)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	await _shot("dil_1_ana_menu", Vector2i(0, 0), sc)
	var mm: Node = current_scene
	if mm and mm.has_method("_on_settings_pressed"):
		mm.call("_on_settings_pressed")
		await _wait(1.2)
		await _shot("dil_2_ayarlar", Vector2i(0, 0), sc)
	_gm = root.get_node("GameManager")
	_gm.call("reset")
	_gm.set("debug_mode_unlocked", true)
	change_scene_to_file("res://scenes/character_select.tscn")
	await _wait(3.0)
	var cs: Node = current_scene
	var desk: Object = cs.get("_desk") if cs != null else null
	if desk:
		desk.call("show_character", 9, false)
		await _wait(0.8)
	await _shot("dil_3_secim", Vector2i(0, 0), sc)
	if not await _boot(9, LOADOUT[0]):
		print("BT BOOTFAIL dil")
		return
	for k in [LOADOUT[1], LOADOUT[2]]:
		_player.call("buy_weapon_copy", k, 1)
	_player.set("level", 12)
	_fix_sky()
	await _wait(1.5)
	await _shot("dil_4_hud", Vector2i(0, 0), sc)
	_keep_pause = true
	_main.call("_show_level_up_screen", 3)
	await _wait(1.5)
	await _shot("dil_5_seviye", Vector2i(0, 0), sc)
	var lus: Node = get_first_node_in_group("level_up_screen")
	if lus == null:
		for c in _main.get_children():
			if str(c.name).to_lower().contains("level"):
				lus = c
	if lus and lus.has_method("_on_upgrade_selected"):
		pass
	for c in _main.get_children():
		if c is CanvasLayer and str(c.name).to_lower().contains("levelup"):
			c.queue_free()
	await _wait(0.3)
	if _main.has_method("_try_open_level_market"):
		_main.call("_try_open_level_market")
		await _wait(1.5)
		await _shot("dil_6_pazar", Vector2i(0, 0), sc)
	_keep_pause = false
	paused = false
	print("BT DIL ok")
