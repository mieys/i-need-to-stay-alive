extends SceneTree

## FPS ÖLÇÜM DÜZENEĞİ (2026-10-18, FPS turu; bkz. docs/notlar madde 267). Gerçek renderer'da (pencereli 1920x1080, vsync kapalı), gerçek Main'de, tek fonksiyonu / sistemi
## ölçer. Tüm-kare farkı gürültülü (±2 ms; 44 geçişlik "sistem sistem kapat" taraması bile anlamsız çıktı) -> MİKRO ÖLÇÜM: tek fonksiyonu aynı karede döngüde zamanla
## (medyan us), eski sürümü AYNI koşuda yanında tut (diff_* kipleri), değişikliği kare başına ms'ye çevir.
## Çalıştırma (GERÇEK PENCERE açar, kullanıcının ekranında öne çıkar: önce kullanıcıdan izin al, -AllowWindow şart): powershell -ExecutionPolicy Bypass -File tools/fps_micro/run.ps1 -Mode micro_crowd -AllowWindow -Env "PG_N=200;PG_FIGHT=1"
##   (run.ps1 kullanıcı verisini YALITIR: APPDATA geçici klasöre çevrilir; gerçek meta.cfg / records.cfg / kayıtlar bozulmaz. Oyun açıkken ölçme.)
## Kipler (PG_MODE): micro_crowd (kalabalık: köprü alanları, derinlik, itme/tik geçişleri, sis, hasar sayıları; PG_FIGHT=1 silahlı savaş, PG_N yaratık),
##   micro_hit / prof_hit (take_damage parçaları), prof_tick (_ew_tick parçaları + durum dağılımı), prof_depth, prof_depth_cpp (madde 286: creature_depth C++ yolu parça parça + C++ <-> eski yol toplamı), micro_lb (betik başına _process/_physics_process
##   liderlik tablosu), diff_depth / diff_dn (ESKİ sürüm <-> yeni: eşdeğerlik + süre; eski kopya `git show HEAD:scripts/x.gd > scripts/_old_x.gd` ile GEÇİCİ konur,
##   commit etme), ab_weapons / ab_rain (açık/kapalı ardışık A/B), rain_shot (yağmur açık/kapalı görüntü farkı), firstuse (her yeteneğin 1. / 2. basışı kare ms),
##   prof_fight (FPS turu 4: savaşta uyanık yaratık sınıfları, köprü fazları, uyku geçişleri, olay sayıları, sis öğe maliyeti, hasar sayısı gerçek maliyeti), prof_player (oyuncu _physics_process yardımcıları),
##   firstweapon, prof_fog (sis CPU parçaları), warm_vis (ısınma dörtgenlerinin görünür kalıntısı: katman 100 / -100), micro_splash (alan hasarı aday taraması), scale / scale2 / bisect / hitstorm / weapons / chars / status / uiopen / drift (önceki oturumun kipleri). Ortam: PG_TIER, PG_N, PG_HOUR,
##   PG_WEATHER (0 açık 1 rüzgarlı 2 yağmur 3 sağanak), PG_NLIST, PG_CHARS, PG_PRELOAD_FILE, PG_POTION (firstuse: Cadı R iksirini 0-4 zorla), PG_CYCLES ... (bkz. kodda _env_int / OS.get_environment).
## Sonuç satırları "PG ..." ile başlar (stdout dosyası). Gürültü: aynı koşu içinde karşılaştır; mikro ölçümler ~%2 oynar.

const ALL_WEAPONS: Array = ["dagger", "fire_staff", "lightning_staff", "tabanca", "tuftuf", "tufek", "arcane", "yay", "crossbow", "boomerang", "buz_asasi", "fisek", "pence", "topuz", "uzunkilic"]
const LOADOUT: Array = ["uzunkilic", "tabanca", "fire_staff"]
const ROSTERS := {
	6: ["ork1", "slime1", "zombie3", "iskelet2"],
	8: ["lich2", "ork2", "ork3", "slime2", "iskelet3"],
	11: ["agac1", "agac2", "bitki1", "bitki2", "mantar2"],
	14: ["demon1", "hayalet1", "hayalet2", "vampire1", "vampire2", "iblis1", "iblis2"],
}

var _mode: String = OS.get_environment("PG_MODE")
var _tier: int = _env_int("PG_TIER", 14)
var _n: int = _env_int("PG_N", 100)
var _hour: float = float(_env_int("PG_HOUR", 150))
var _weather: int = _env_int("PG_WEATHER", 0)
var _reps: int = _env_int("PG_REPS", 2)
var _char: int = _env_int("PG_CHAR", 2)

var _gm: Node = null
var _main: Node = null
var _player: Node2D = null
var _spawner: Node = null
var _enemy_target: int = 0
var _walk: bool = false
var _fi: int = 0
var _near_enemies: int = 0
var _loadout: Array = LOADOUT.duplicate()
var _natural: bool = false
var _t_start: int = -1
var _logic_sum: float = 0.0
var _logic_n: int = 0


func _env_int(k: String, d: int) -> int:
	var v: String = OS.get_environment(k)
	return int(v) if v != "" else d


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _on_frame() -> void:
	paused = false
	if _player == null or not is_instance_valid(_player):
		return
	_fi += 1
	if _fi % 6 == 0:
		var near: int = 0
		var pp: Vector2 = _player.global_position
		for e in get_nodes_in_group("enemies"):
			if e is Node2D and (e as Node2D).global_position.distance_squared_to(pp) < 900.0 * 900.0:
				near += 1
		_near_enemies = near
		if _enemy_target > 0 and _spawner != null and near < _enemy_target:
			var roster: Array = ROSTERS.get(_tier, ROSTERS[14])
			for i in mini(8, _enemy_target - near):
				_spawner.call("debug_spawn_creature", roster[randi() % roster.size()], _tier, 1, pp)
	if _walk:
		var ph: int = int(Time.get_ticks_msec() / 1500) % 4
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("move_up")
		Input.action_release("move_down")
		Input.action_press(["move_right", "move_down", "move_left", "move_up"][ph])


func _on_frame_start() -> void:
	if _t_start < 0:
		_t_start = Time.get_ticks_usec()


func _on_pre_draw() -> void:
	if _t_start >= 0:
		_logic_sum += float(Time.get_ticks_usec() - _t_start) / 1000.0
		_logic_n += 1
	_t_start = -1


func _viewports() -> Array[RID]:
	var out: Array[RID] = [root.get_viewport_rid()]
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			stack.append(c)
			if c is SubViewport:
				out.append((c as SubViewport).get_viewport_rid())
	return out


## sec boyunca kare süresi (ms) istatistiği + GPU / render-CPU / çizim sayısı.
func _measure(sec: float) -> Dictionary:
	var vps: Array[RID] = _viewports()
	for r in vps:
		RenderingServer.viewport_set_measure_render_time(r, true)
	await process_frame
	var arr: Array = []
	var gpu: float = 0.0
	var rcpu: float = 0.0
	var draws: float = 0.0
	var en: float = 0.0
	var t0: int = Time.get_ticks_usec()
	var last: int = t0
	var ls0: float = _logic_sum
	var ln0: int = _logic_n
	var pf0: int = Engine.get_physics_frames()
	while float(Time.get_ticks_usec() - t0) / 1.0e6 < sec:
		await process_frame
		var now: int = Time.get_ticks_usec()
		arr.append(float(now - last) / 1000.0)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		en += float(_near_enemies)
		for r in vps:
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(r)
			rcpu += RenderingServer.viewport_get_measured_render_time_cpu(r)
	var n: int = maxi(1, arr.size())
	arr.sort()
	var s: float = 0.0
	for v in arr:
		s += float(v)
	var logic: float = (_logic_sum - ls0) / maxf(1.0, float(_logic_n - ln0))
	var pt: float = float(Engine.get_physics_frames() - pf0) / float(n)
	return {"pt": pt, "logic": logic, "mean": s / n, "p50": arr[n / 2], "p95": arr[mini(n - 1, int(n * 0.95))], "max": arr[n - 1], "gpu": gpu / n, "rcpu": rcpu / n, "draws": draws / n, "en": en / n, "n": n}


func _fmt(m: Dictionary) -> String:
	return "pt=%.2f logic=%.2f mean=%.2f p50=%.2f p95=%.2f max=%.1f gpu=%.2f rcpu=%.2f draws=%d en=%d fps=%.0f" % [m["pt"], m["logic"], m["mean"], m["p50"], m["p95"], m["max"], m["gpu"], m["rcpu"], int(m["draws"]), int(m["en"]), 1000.0 / maxf(0.001, float(m["mean"]))]


func _boot(char_id: int, start_weapon: String) -> bool:
	_enemy_target = 0
	_walk = false
	_player = null
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	for c in _gm.get_children():
		var sc: Variant = c.get_script()
		if sc != null and str((sc as Script).resource_path).ends_with("hitch_log.gd"):
			c.set_process(false) ## kullanıcının gerçek takılma günlüğü kirlenmesin
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", char_id)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(char_id).get("skill", 1))
	_gm.set("selected_start_weapon", start_weapon)
	_gm.set("debug_immortal", true)
	## Kayıt yazılmasın (2026-10-18): Main'in "progress" yolu (kademe atlayınca) run_record_suppressed'e BAKMAZ; yalıtılmamış (APPDATA) bir koşuda
	## Ruh Kıymığı + rekor yazardı (bir kez gerçek meta.cfg / records.cfg bozuldu). Debug bayrağı _record_skip_reason'ı açar -> hiçbir kayıt yazılmaz.
	## Yalnız kayıt yolunu ölçeceksen PG_RECORDS=1 (run.ps1 APPDATA'yı yine yalıtır).
	if OS.get_environment("PG_RECORDS") != "1":
		_gm.set("debug_mode_unlocked", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	if current_scene == null or current_scene.name != "Main":
		return false
	print("PG BOOT main_ms=%d" % (Time.get_ticks_msec() - t0)) ## sahne değiştirme -> Main hazır (harita yükleme maliyeti, madde 371)
	_main = current_scene
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	await _wait(2.5)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house") and OS.get_environment("PG_INDOOR") != "1": ## PG_INDOOR=1: evin içinde kal (ev içi ışığı, madde 311)
		house.call("_do_exit_house")
	await _wait(2.0)
	_player = _main.get_node_or_null("Player") as Node2D
	_spawner = _main.get_node_or_null("EnemySpawner")
	if _spawner and not _natural:
		_spawner.set("_spawn_timer", 1.0e9)
	if not process_frame.is_connected(_on_frame):
		process_frame.connect(_on_frame)
		process_frame.connect(_on_frame_start)
		physics_frame.connect(_on_frame_start)
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	return _player != null


func _prepare(extra_weapons: bool, jump_tier: bool = true) -> void:
	if extra_weapons:
		for k in [_loadout[1], _loadout[2]]:
			_player.call("buy_weapon_copy", k, 1)
	_player.set("level", 20)
	if jump_tier:
		_gm.set("game_time", float(_tier - 1) * 150.0 + 20.0)
		if _spawner:
			_spawner.set("_spawn_tier", _tier)
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", _hour)
		atmo.call("debug_set_weather", _weather)
	await _wait(0.5)


const DUMMY_ROSTER: Array = ["slime1", "zombie1", "zombie2", "iskelet2", "ork1"]
var _dummies: Array = []


## Hareketsiz + ölmeyen hedefler (gürültüsüz taban): hız ve can _ready'den ÖNCE verilir (C++ dünyasına kayıt anında okunur).
func _spawn_dummies(count: int) -> void: ## (await ile çağır)
	for d in _dummies:
		if is_instance_valid(d):
			d.queue_free()
	_dummies.clear()
	var pp: Vector2 = _player.global_position
	for i in range(count):
		var id: String = DUMMY_ROSTER[i % DUMMY_ROSTER.size()]
		var ps: PackedScene = load("res://scenes/creatures/enemy_%s.tscn" % id)
		var e: Node2D = ps.instantiate()
		e.set("speed", 0.0)
		e.set("max_health", 1.0e9)
		_main.add_child(e)
		var a: float = randf() * TAU
		e.global_position = pp + Vector2(cos(a), sin(a)) * randf_range(70.0, 230.0)
		e.set("health", 1.0e9)
		_dummies.append(e)
	await _wait(0.5)
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not _dummies.has(e):
			e.queue_free()
	await _wait(0.5)


func _clear_weapons() -> void:
	while (_player.get("owned_weapon_nodes") as Array).size() > 0:
		_player.call("remove_owned_weapon", 0)
	await _wait(0.3)


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	if OS.get_environment("PG_LOADOUT") != "":
		_loadout = Array(OS.get_environment("PG_LOADOUT").split(","))
	print("PG START mode=%s tier=%d n=%d hour=%d weather=%d" % [_mode, _tier, _n, int(_hour), _weather])
	match _mode:
		"smoke":
			await _smoke()
		"sys":
			await _sys()
		"scale":
			await _scale()
		"weapons":
			await _weapons()
		"chars":
			await _chars()
		"drift":
			await _drift()
		"bisect":
			await _bisect()
		"scale2":
			await _scale2()
		"status":
			await _status()
		"uiopen":
			await _uiopen()
		"hitstorm":
			await _hitstorm()
		"micro_crowd":
			await _micro_crowd()
		"micro_hit":
			await _micro_hit()
		"micro_lb":
			await _micro_lb()
		"diff_depth":
			await _diff_depth()
		"prof_depth":
			await _prof_depth()
		"prof_depth_cpp":
			await _prof_depth_cpp()
		"prof_tick":
			await _prof_tick()
		"prof_fight":
			await _prof_fight()
		"prof_player":
			await _prof_player()
		"diff_dn":
			await _diff_dn()
		"firstuse":
			await _firstuse()
		"ab_weapons":
			await _ab_weapons()
		"micro_splash":
			await _micro_splash()
		"prof_fog":
			await _prof_fog()
		"warm_vis":
			await _warm_vis()
		"firstweapon":
			await _firstweapon()
		"ab_rain":
			await _ab_rain()
		"rain_shot":
			await _rain_shot()
		"prof_hit":
			await _prof_hit()
		"draw_sweep":
			await _draw_sweep()
	print("PG DONE")
	quit()


func _smoke() -> void:
	var ok: bool = await _boot(_char, _loadout[0])
	print("PG boot ok=%s" % str(ok))
	await _prepare(true)
	_enemy_target = 30
	await _wait(6.0)
	print("PG near enemies=%d weapons=%d level=%d unlocked_R=%s" % [_near_enemies, (_player.get("owned_weapon_nodes") as Array).size(), int(_player.get("level")), str(_player.call("is_skill_slot_unlocked", "skill3"))])
	var m: Dictionary = await _measure(3.0)
	print("PG smoke ", _fmt(m))


func _sys() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(true)
	_enemy_target = _n
	_walk = true
	await _wait(25.0)
	print("PG pre-probe near enemies=%d" % _near_enemies)
	var pp: GDScript = load("res://scripts/perf_probe.gd")
	pp.call("start", self)
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 150000:
		await process_frame
		var node: Node = root.get_node_or_null("PerfProbe")
		if node != null and (node.get("_rows") as Array).size() >= 14:
			break
	print("PG probe finished, enemies near now=%d" % _near_enemies)


func _scale() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(true)
	var lst: PackedStringArray = (OS.get_environment("PG_NLIST") if OS.get_environment("PG_NLIST") != "" else "0,25,50,100,150").split(",")
	_walk = true
	for s in lst:
		_enemy_target = int(s)
		if _enemy_target == 0:
			for e in get_nodes_in_group("enemies"):
				if is_instance_valid(e) and e is Node2D:
					e.queue_free()
		await _wait(10.0)
		var m: Dictionary = await _measure(5.0)
		print("PG SCALE n=%s %s" % [s, _fmt(m)])


func _weapons() -> void:
	if not await _boot(_char, "dagger"):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	_enemy_target = 0
	_walk = false
	await _clear_weapons()
	await _spawn_dummies(_n)
	await _wait(3.0)
	var base: Dictionary = await _measure(5.0)
	print("PG WEAPON none %s" % _fmt(base))
	var keys: Array = ALL_WEAPONS
	if OS.get_environment("PG_WEAPONS") != "":
		keys = Array(OS.get_environment("PG_WEAPONS").split(","))
	for k in keys:
		await _clear_weapons()
		if OS.get_environment("PG_FRESH") != "":
			await _spawn_dummies(_n) ## her silah için temiz hedefler (durum etkileri birikmesin)
			await _wait(1.0)
		_player.call("buy_weapon_copy", k, 1)
		await _wait(2.0)
		var m: Dictionary = await _measure(6.0)
		print("PG WEAPON %s d_mean=%+.2f %s" % [k, float(m["mean"]) - float(base["mean"]), _fmt(m)])


func _slot_vars(slot: String) -> Array:
	return ["skill_state" if slot == "skill" else slot + "_state", "skill_timer" if slot == "skill" else slot + "_timer"]


func _press(slot: String) -> void:
	Input.action_press(slot)
	await process_frame
	await physics_frame
	await process_frame
	await process_frame
	Input.action_release(slot)


func _chars() -> void:
	var ids: Array = [1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15]
	if OS.get_environment("PG_CHARS") != "":
		ids = []
		for s in OS.get_environment("PG_CHARS").split(","):
			ids.append(int(s))
	for cid in ids:
		if not await _boot(cid, _loadout[0]):
			print("PG BOOTFAIL char=%d" % cid)
			continue
		await _prepare(true, false)
		_enemy_target = 0
		_walk = false
		await _spawn_dummies(_n)
		await _wait(4.0)
		print("PG CHAR %d begin near=%d unlockedR=%s" % [cid, _near_enemies, str(_player.call("is_skill_slot_unlocked", "skill3"))])
		for slot in ["skill", "skill2", "skill3"]:
			var sv: Array = _slot_vars(slot)
			for rep in range(_reps):
				_player.set(sv[0], "ready")
				_player.set(sv[1], 0.0)
				_player.set("item_shield_max", 300.0)
				_player.set("item_shield_hp", 300.0)
				_player.set("necro_souls", 25)
				var before: Dictionary = await _measure(2.0)
				await _press(slot)
				var st: String = str(_player.get(sv[0]))
				var during: Dictionary = await _measure(5.0)
				var st2: String = str(_player.get(sv[0]))
				if st2 == "active" or st2 == "on":
					await _press(slot) ## aç/kapa yetenekleri kapat
				await _wait(3.5)
				print("PG CAST char=%d slot=%s rep=%d st=%s/%s d_mean=%+.2f d_p50=%+.2f d_gpu=%+.2f d_rcpu=%+.2f | before %s | during %s" % [cid, slot, rep + 1, st, st2, float(during["mean"]) - float(before["mean"]), float(during["p50"]) - float(before["p50"]), float(during["gpu"]) - float(before["gpu"]), float(during["rcpu"]) - float(before["rcpu"]), _fmt(before), _fmt(during)])


func _group_counts() -> String:
	var parts: PackedStringArray = []
	for g in ["enemies", "xp_orbs", "gold_drops", "food_drops", "magnet_drops", "shield_orb_drops", "weapon_shard_drops", "chest_drops", "enemy_projectiles", "summons"]:
		parts.append("%s=%d" % [g, get_nodes_in_group(g).size()])
	return " ".join(parts)


func _child_hist(node: Node, top: int) -> String:
	var h: Dictionary = {}
	for c in node.get_children():
		var sc: Variant = c.get_script()
		var key: String = (sc as Script).resource_path.get_file().get_basename() if sc != null else c.get_class()
		h[key] = int(h.get(key, 0)) + 1
	var arr: Array = []
	for k in h:
		arr.append([h[k], k])
	arr.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var out: PackedStringArray = []
	for i in range(mini(top, arr.size())):
		out.append("%s:%d" % [arr[i][1], arr[i][0]])
	return ", ".join(out)


## Doğal oyun akışı (gerçek spawner + gerçek silahlar + yürüyen oyuncu): zamanla kare süresi / nesne sayıları nasıl değişiyor?
func _drift() -> void:
	_natural = true
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(true)
	_walk = true
	var total: float = float(_env_int("PG_SECONDS", 240))
	var step: float = 20.0
	var t_begin: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t_begin) / 1000.0 < total:
		await _wait(step - 3.0)
		var m: Dictionary = await _measure(3.0)
		var el: float = float(Time.get_ticks_msec() - t_begin) / 1000.0
		print("PG DRIFT t=%.0f %s | nodes=%d orphans=%d objs=%d | %s | main_children=%d: %s" % [el, _fmt(m), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)), _group_counts(), _main.get_child_count(), _child_hist(_main, 9)])


func _has_processing(n: Node) -> bool:
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		if x.is_processing() or x.is_physics_processing():
			return true
		for c in x.get_children():
			stack.append(c)
	return false


func _toggle_report(name: String, a1: Dictionary, tm: Dictionary, a2: Dictionary) -> void:
	var ab_logic: float = (float(a1["logic"]) + float(a2["logic"])) * 0.5
	var ab_frame: float = (float(a1["mean"]) + float(a2["mean"])) * 0.5
	print("PG TOGGLE %-60s d_logic=%+.2f d_frame=%+.2f | A1 %.2f/%.2f  T %.2f/%.2f  A2 %.2f/%.2f (logic/frame) en=%d" % [name, float(tm["logic"]) - ab_logic, float(tm["mean"]) - ab_frame, a1["logic"], a1["mean"], tm["logic"], tm["mean"], a2["logic"], a2["mean"], int(tm["en"])])


## Sistem sistem kapatıp mantık süresindeki (CPU) düşüşü ölçer (ABA: önce/sonra taban ortalaması).
func _bisect() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(true)
	_enemy_target = _n
	_walk = true
	await _wait(25.0)
	var base0: Dictionary = await _measure(6.0)
	print("PG BISECT base ", _fmt(base0))
	var toggles: Array = [] ## [ad, Array[Node], sadece_betik]
	var ew: Array = []
	for c in _main.get_children():
		var sc: Variant = c.get_script()
		var sp: String = (sc as Script).resource_path if sc != null else ""
		if sp.ends_with("enemy_world_bridge.gd"):
			ew.append(c)
	toggles.append(["EnemyWorldBridge (C++ adim)", ew, false])
	toggles.append(["Main betigi (sadece kendi _process)", [_main], true])
	toggles.append(["Player betigi (sadece kendi _process)", [_player], true])
	toggles.append(["Player + silahlar (tum alt agac)", [_player], false])
	var wn: Array = []
	for w in (_player.get("owned_weapon_nodes") as Array):
		wn.append(w)
	toggles.append(["Sadece silahlar", wn, false])
	var by_key: Dictionary = {}
	for c in _main.get_children():
		if c == _player or ew.has(c) or c.is_in_group("enemies"):
			continue
		if not _has_processing(c):
			continue
		var sc2: Variant = c.get_script()
		var key: String = (sc2 as Script).resource_path.get_file() if sc2 != null else ("%s(%s)" % [c.name, c.get_class()])
		if not by_key.has(key):
			by_key[key] = []
		(by_key[key] as Array).append(c)
	for key in by_key:
		toggles.append(["Main/%s x%d" % [key, (by_key[key] as Array).size()], by_key[key], false])
	var expand: PackedStringArray = PackedStringArray()
	if OS.get_environment("PG_EXPAND") != "":
		expand = OS.get_environment("PG_EXPAND").split(",")
	for c in _main.get_children():
		if expand.has(String(c.name)):
			for g in c.get_children():
				if _has_processing(g):
					var sc3: Variant = g.get_script()
					toggles.append(["%s/%s [%s]" % [c.name, g.name, (sc3 as Script).resource_path.get_file() if sc3 != null else g.get_class()], [g], false])
	for c in root.get_children():
		if c == _main or c.name == "PerfProbe" or not _has_processing(c):
			continue
		toggles.append(["root/" + String(c.name), [c], false])
	print("PG BISECT toggles=%d" % toggles.size())
	for t in toggles:
		var nodes: Array = []
		for n in t[1]:
			if is_instance_valid(n):
				nodes.append(n)
		if nodes.is_empty():
			continue
		var a1: Dictionary = await _measure(2.5)
		var saved: Array = []
		for n in nodes:
			saved.append([n, n.process_mode, n.is_processing(), n.is_physics_processing()])
			if bool(t[2]):
				n.set_process(false)
				n.set_physics_process(false)
			else:
				n.process_mode = Node.PROCESS_MODE_DISABLED
		var tm: Dictionary = await _measure(3.5)
		for e in saved:
			if is_instance_valid(e[0]):
				var nn: Node = e[0]
				nn.process_mode = int(e[1]) as Node.ProcessMode
				nn.set_process(bool(e[2]))
				nn.set_physics_process(bool(e[3]))
		await _wait(0.4)
		var a2: Dictionary = await _measure(2.5)
		_toggle_report(str(t[0]), a1, tm, a2)
	## Yaratiklarin kendi dugum islemleri (tum "enemies" uyeleri)
	var ens: Array = []
	for e in get_nodes_in_group("enemies"):
		ens.append(e)
	var saved_target: int = _enemy_target
	_enemy_target = 0
	var a1b: Dictionary = await _measure(2.5)
	var saved2: Array = []
	for e in ens:
		if is_instance_valid(e):
			saved2.append([e, e.process_mode])
			e.process_mode = Node.PROCESS_MODE_DISABLED
	var tb: Dictionary = await _measure(3.5)
	for e in saved2:
		if is_instance_valid(e[0]):
			(e[0] as Node).process_mode = int(e[1]) as Node.ProcessMode
	var a2b: Dictionary = await _measure(2.5)
	_toggle_report("TUM yaratik dugumleri (%d)" % ens.size(), a1b, tb, a2b)
	_enemy_target = saved_target


## Sabit kalabalık (silah YOK, ölüm/doğma YOK): yaratıklar halkadan gelip oyuncunun etrafında toplanır -> N'ye göre kare süresi.
func _scale2() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	_enemy_target = 0
	_walk = false
	await _clear_weapons()
	var lst: PackedStringArray = (OS.get_environment("PG_NLIST") if OS.get_environment("PG_NLIST") != "" else "0,50,100,150,200,250").split(",")
	var roster: Array = ROSTERS.get(_tier, ROSTERS[14])
	for s in lst:
		for e in get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e is Node2D:
				e.queue_free()
		await _wait(1.5)
		var want: int = int(s)
		var made: int = 0
		var pp: Vector2 = _player.global_position
		while made < want:
			var ang: float = randf() * TAU
			var center: Vector2 = pp + Vector2(cos(ang), sin(ang)) * randf_range(380.0, 650.0)
			var k: int = mini(10, want - made)
			for i in range(k):
				_spawner.call("debug_spawn_creature", roster[randi() % roster.size()], _tier, 1, center)
			made += k
		await _wait(14.0)
		var m: Dictionary = await _measure(5.0)
		print("PG SCALE2 n=%s %s" % [s, _fmt(m)])


## Durum etkileri (zehir/yanma/donma/...) 40 yaratığa BİRDEN uygulanınca kare maliyeti.
func _status() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	_enemy_target = 0
	_walk = false
	await _clear_weapons()
	await _spawn_dummies(_n)
	await _wait(3.0)
	var base: Dictionary = await _measure(4.0)
	print("PG STATUS none %s" % _fmt(base))
	var pp: Vector2 = _player.global_position
	var list: Array = [
		["poison", "apply_poison", [1.0, 5.0, 10.0]],
		["burn", "apply_burn", [1.0, 8.0]],
		["bleed", "apply_bleed", [1.0, 3, 5]],
		["chill", "apply_chill", [3]],
		["slow", "apply_slow", [0.4, 8.0]],
		["frost_slow", "apply_frost_slow", [0.4, 8.0]],
		["root", "apply_root", [8.0]],
		["stun", "apply_stun", [8.0]],
		["freeze", "apply_freeze_full", [8.0]],
		["fear", "apply_fear", [pp, 8.0]],
		["fear_wander", "apply_fear_wander", [8.0]],
		["madness", "apply_madness", [8.0]],
		["taunt", "apply_taunt", [8.0, _player]],
		["mark", "apply_mark_stack", [5]],
		["bee_poison", "apply_bee_poison", [1.0]],
	]
	for it in list:
		var b: Dictionary = await _measure(2.0)
		for d in _dummies:
			if is_instance_valid(d) and d.has_method(String(it[1])):
				d.callv(String(it[1]), it[2])
		await _wait(0.7)
		var m: Dictionary = await _measure(4.0)
		print("PG STATUS %-12s d_mean=%+.2f d_logic=%+.2f d_rcpu=%+.2f d_draws=%+d | before %s | during %s" % [it[0], float(m["mean"]) - float(b["mean"]), float(m["logic"]) - float(b["logic"]), float(m["rcpu"]) - float(b["rcpu"]), int(m["draws"]) - int(b["draws"]), _fmt(b), _fmt(m)])
		await _wait(6.0)


## Arayüz açılış takılması: seviye atlama ekranı (ilk açılış / sonrakiler) - eşzamanlı süre + sonraki kareler.
func _uiopen() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	_enemy_target = 0
	await _wait(2.0)
	for i in range(4):
		var t0: int = Time.get_ticks_usec()
		_main.call("_show_level_up_screen", 2 + i)
		var t1: int = Time.get_ticks_usec()
		var fr: PackedStringArray = []
		var last: int = t1
		for k in range(10):
			await process_frame
			var n: int = Time.get_ticks_usec()
			fr.append("%.0f" % (float(n - last) / 1000.0))
			last = n
		print("PG UIOPEN levelup #%d sync=%.1f ms next_frames_ms=%s" % [i + 1, float(t1 - t0) / 1000.0, ",".join(fr)])
		var scr: Node = _main.get_node_or_null("LevelUpScreen")
		if scr != null:
			scr.queue_free()
		paused = false
		await _wait(1.5)


## Alan hasarı fırtınası: 40 yaratığa BİR karede vurma maliyeti (bölüm bölüm) + sonraki 1,2 sn'nin ek maliyeti.
func _hitstorm() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	_enemy_target = 0
	_walk = false
	await _clear_weapons()
	await _spawn_dummies(_n)
	await _wait(3.0)
	var base: Dictionary = await _measure(3.0)
	print("PG HITSTORM base %s" % _fmt(base))
	for variant in ["none", "full", "flash", "overhead", "number", "wake", "full"]:
		var syncs: Array = []
		var deltas: Array = []
		var peaks: Array = []
		for rep in range(6):
			await _wait(0.8)
			var b: Dictionary = await _measure(0.8)
			var t0: int = Time.get_ticks_usec()
			for d in _dummies:
				if not is_instance_valid(d):
					continue
				match variant:
					"full":
						d.call("take_damage", 5.0, false, 0.0, true)
					"flash":
						d.call("_flash")
					"overhead":
						d.call("_show_overhead_bar")
					"number":
						d.call("_show_hit_number", 5.0, false)
					"wake":
						d.call("_ew_wake")
			var t1: int = Time.get_ticks_usec()
			var a: Dictionary = await _measure(1.2)
			syncs.append(float(t1 - t0) / 1000.0)
			deltas.append(float(a["mean"]) - float(b["mean"]))
			peaks.append(float(a["max"]))
		syncs.sort()
		deltas.sort()
		peaks.sort()
		print("PG HITSTORM %-9s sync_ms(median)=%.2f  after_extra_ms_per_frame(median)=%+.2f  max_frame(median)=%.1f  | sync_all=%s" % [variant, syncs[3], deltas[3], peaks[3], str(syncs)])


## ---------------------------------------------------------------- MIKRO ÖLÇÜM (tek fonksiyonu döngüde zamanlar; tüm-kare A/B'sinden çok daha az gürültülü)
func _t_us(c: Callable, reps: int) -> Array: ## [medyan, ortalama, en küçük] (us)
	var arr: Array = []
	for i in range(reps):
		var t0: int = Time.get_ticks_usec()
		c.call()
		arr.append(Time.get_ticks_usec() - t0)
	arr.sort()
	var s: float = 0.0
	for v in arr:
		s += float(v)
	return [float(arr[arr.size() / 2]), s / float(arr.size()), float(arr[0])]


func _pr(label: String, r: Array, extra: String = "") -> void:
	print("PG MICRO %-38s median=%9.1f us  mean=%9.1f  min=%9.1f  %s" % [label, r[0], r[1], r[2], extra])


func _spawn_crowd(count: int) -> void: ## scale2 gibi: halkadan gelen gerçek yaratıklar, oyuncunun etrafında toplanır
	var roster: Array = ROSTERS.get(_tier, ROSTERS[14])
	var made: int = 0
	var pp: Vector2 = _player.global_position
	while made < count:
		var ang: float = randf() * TAU
		var center: Vector2 = pp + Vector2(cos(ang), sin(ang)) * randf_range(380.0, 650.0)
		var k: int = mini(10, count - made)
		for i in range(k):
			_spawner.call("debug_spawn_creature", roster[randi() % roster.size()], _tier, 1, center)
		made += k


func _micro_crowd() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	var fight: bool = OS.get_environment("PG_FIGHT") != ""
	if fight:
		await _prepare(true)
		_enemy_target = _n
		_walk = true
		await _wait(float(_env_int("PG_SETTLE", 25)))
	else:
		await _prepare(false, false)
		_enemy_target = 0
		_walk = false
		await _clear_weapons()
		_spawn_crowd(_n)
		await _wait(float(_env_int("PG_SETTLE", 16)))
	var bridge: Node = _main.get_node("EnemyWorldBridge")
	var cd: Node = _main.get_node("CreatureDepth")
	var eq: GDScript = load("res://scripts/enemy_world/enemy_query.gd")
	var pp: Vector2 = _player.global_position
	var world: Object = bridge.get("world")
	print("PG MICRO crowd registered=%d awake=%d enemies_group=%d" % [int(world.call("get_count")), (bridge.get("_active") as Array).size(), get_nodes_in_group("enemies").size()])
	## awake dağılımı (aile / yetenek)
	var fam: Dictionary = {}
	for e in (bridge.get("_active") as Array):
		if is_instance_valid(e):
			var key: String = "%s%s" % [str(e.call("creature_family")), "+ab" if e.get("_abilities") != null else ""]
			fam[key] = int(fam.get(key, 0)) + 1
	print("PG MICRO awake by family: ", str(fam))
	## 1) köprü alanları (3 sn, fizik karesi başına ortalama)
	var fr: int = 0
	var sums: Array = [0.0, 0.0, 0.0, 0.0]
	var act: float = 0.0
	var dn_live: float = 0.0
	var dn_node: Node = null
	var t_end: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < t_end:
		await physics_frame
		if dn_node == null or not is_instance_valid(dn_node):
			dn_node = current_scene.get_node_or_null("DamageNumbers")
		if dn_node != null:
			dn_live += float((dn_node.get("_entries") as Dictionary).size())
		sums[0] += float(bridge.get("last_bridge_ms"))
		sums[1] += float(bridge.get("last_step_ms"))
		sums[2] += float(bridge.get("last_view_ms"))
		sums[3] += float(bridge.get("last_tick_ms"))
		act += float((bridge.get("_active") as Array).size())
		fr += 1
	print("PG MICRO bridge/frame ms: total=%.2f cpp_step=%.2f (view %.2f) gd_events+ticks=%.2f awake_avg=%.0f frames=%d" % [sums[0] / fr, sums[1] / fr, sums[2] / fr, sums[3] / fr, act / fr, fr])
	print("PG MICRO live damage-number entries avg=%.0f" % (dn_live / fr))
	## 2) tek tek parçalar
	var act_arr: Array = (bridge.get("_active") as Array).duplicate()
	_pr("depth.update_now (tum)", _t_us(func() -> void: cd.call("update_now"), 30))
	var cn: Array = eq.call("candidates", self, pp, 394.0)
	_pr("EnemyQuery.candidates r=394", _t_us(func() -> void: eq.call("candidates", self, pp, 394.0), 40), "n=%d" % cn.size())
	_pr("main._update_creature_draw_order_ew", _t_us(func() -> void: _main.call("_update_creature_draw_order_ew", world), 30))
	_pr("push_state pass (awake)", _t_us(func() -> void:
		for e in act_arr:
			if is_instance_valid(e) and e._ew_slot >= 0:
				e._ew_push_state(), 30), "n=%d" % act_arr.size())
	_pr("ew_tick(0) pass (awake)", _t_us(func() -> void:
		for e in act_arr:
			if is_instance_valid(e) and e._ew_slot >= 0:
				e._ew_tick(0.0), 30), "n=%d" % act_arr.size())
	var fog: Node = get_first_node_in_group("vision_fog")
	if fog != null:
		_pr("vision_fog.update_fog", _t_us(func() -> void: fog.call("update_fog", 0.016), 30))
	## 3) hasar sayıları: 600 kayıt, yarısı sönme evresinde (alfa her karede değişir), yarısı tutma evresinde
	var dnmod: GDScript = load("res://scripts/damage_numbers.gd")
	var dn: Node2D = dnmod.call("get_instance", self)
	await process_frame
	await process_frame
	var ens: Array = get_nodes_in_group("enemies")
	var n_entries: int = _env_int("PG_DN", 600)
	if dn != null and fight:
		_pr("damage_numbers._process (real x%d)" % (dn.get("_entries") as Dictionary).size(), _t_us(func() -> void: dn.call("_process", 0.0001), 40))
	elif dn != null and ens.size() > 0:
		for i in range(n_entries):
			var en: Node2D = ens[i % ens.size()]
			dn.call("spawn_fixed", en, en.global_position + Vector2(randf_range(-20, 20), randf_range(-30, 0)), str(10 + i % 90), Color.WHITE)
		var j: int = 0
		var ents: Dictionary = dn.get("_entries")
		for id in ents:
			var ee: Variant = ents[id]
			ee.fade_t = 0.6 if j % 2 == 0 else 0.3
			ee.rise_t = ee.fade_t
			j += 1
		_pr("damage_numbers._process x%d" % ents.size(), _t_us(func() -> void: dn.call("_process", 0.0001), 40))
		for id in ents.keys():
			dn.call("remove", id)


func _micro_hit() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	_enemy_target = 0
	_walk = false
	await _clear_weapons()
	await _spawn_dummies(_n)
	await _wait(2.0)
	var variants: Array = ["full", "number", "flash", "overhead", "wake", "full", "number"]
	for variant in variants:
		var syncs: Array = []
		var extra: Array = []
		for rep in range(int(_env_int("PG_REPS_HIT", 9))):
			await _wait(0.9)
			var b: Dictionary = await _measure(0.5)
			var t0: int = Time.get_ticks_usec()
			for d in _dummies:
				if not is_instance_valid(d):
					continue
				match variant:
					"full":
						d.call("take_damage", 5.0, false, 0.0, true)
					"flash":
						d.call("_flash")
					"overhead":
						d.call("_show_overhead_bar")
					"number":
						d.call("_show_hit_number", 5.0, false)
					"wake":
						d.call("_ew_wake")
			var t1: int = Time.get_ticks_usec()
			var a: Dictionary = await _measure(1.0)
			syncs.append(float(t1 - t0))
			extra.append(float(a["mean"]) - float(b["mean"]))
		syncs.sort()
		extra.sort()
		print("PG MICRO hit %-9s sync_us(median)=%8.1f  per_enemy_us=%6.2f  after_extra_ms_per_frame(median)=%+.2f" % [variant, syncs[syncs.size() / 2], syncs[syncs.size() / 2] / float(maxi(1, _dummies.size())), extra[extra.size() / 2]])


## ---------------------------------------------------------------- _process / _physics_process LİDERLİK TABLOSU (betik başına, kare başına us)
func _lb_collect(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_lb_collect(c, out)


func _lb_script_key(n: Node) -> String:
	var sc: Variant = n.get_script()
	if sc == null:
		return "<%s>" % n.get_class()
	return (sc as Script).resource_path.get_file()


func _micro_lb() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(true)
	_enemy_target = _n
	_walk = true
	await _wait(float(_env_int("PG_SETTLE", 25)))
	var passes: int = _env_int("PG_PASSES", 7)
	var proc_pass: Array = [] ## her geçiş: {betik: [us_toplam, adet]}
	var phys_pass: Array = []
	var dt: float = 1.0 / 60.0
	for pi in range(passes):
		var nodes: Array = []
		_lb_collect(root, nodes)
		var pp: Dictionary = {}
		var fp: Dictionary = {}
		for n in nodes:
			if not is_instance_valid(n) or n == self or n.get_script() == null:
				continue
			var key: String = _lb_script_key(n)
			if n.is_processing() and n.has_method("_process"):
				var t0: int = Time.get_ticks_usec()
				n.call("_process", dt)
				var d: int = Time.get_ticks_usec() - t0
				var e: Array = pp.get(key, [0, 0])
				e[0] += d
				e[1] += 1
				pp[key] = e
			if n.is_physics_processing() and n.has_method("_physics_process"):
				var t1: int = Time.get_ticks_usec()
				n.call("_physics_process", dt)
				var d2: int = Time.get_ticks_usec() - t1
				var e2: Array = fp.get(key, [0, 0])
				e2[0] += d2
				e2[1] += 1
				fp[key] = e2
		proc_pass.append(pp)
		phys_pass.append(fp)
		await process_frame
	for kind in ["_process", "_physics_process"]:
		var passes_arr: Array = proc_pass if kind == "_process" else phys_pass
		var keys: Dictionary = {}
		for p in passes_arr:
			for k in p:
				keys[k] = true
		var rows: Array = []
		for k in keys:
			var vals: Array = []
			var cnt: int = 0
			for p in passes_arr:
				if p.has(k):
					vals.append(float(p[k][0]))
					cnt = maxi(cnt, int(p[k][1]))
			vals.sort()
			rows.append([vals[vals.size() / 2], k, cnt])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		var total: float = 0.0
		for r in rows:
			total += float(r[0])
		print("PG LB %s toplam=%.0f us (%d betik)" % [kind, total, rows.size()])
		for i in range(mini(22, rows.size())):
			print("PG LB   %-34s %9.0f us   x%d" % [rows[i][1], rows[i][0], rows[i][2]])


## ---------------------------------------------------------------- creature_depth ESKİ (_old_creature_depth.gd) <-> YENİ (creature_depth.gd) fark testi + süre
class FakeCreature extends Node2D:
	var is_dead: bool = false


class FakeChar extends Node2D:
	var is_dead: bool = false
	var is_indoors: bool = false
	var paladin_zone_active: bool = false
	var paladin_zone_radius: float = 0.0


func _fake_creature(pos: Vector2, w: int, h: int, sc: float, cut: int) -> Node2D:
	var e := FakeCreature.new()
	e.add_to_group("enemies")
	e.add_to_group("mission_copies")
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	for y in range(h - cut, h):
		for x in range(w):
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	spr.texture = ImageTexture.create_from_image(img)
	e.add_child(spr)
	e.scale = Vector2(sc, sc)
	_main.add_child(e)
	e.global_position = pos
	return e


func _depth_maps(nodes: Array, chars: Array) -> Array:
	var zs: PackedInt32Array = PackedInt32Array()
	for n in nodes:
		zs.append((n as Node2D).z_index if is_instance_valid(n) else -999)
	for c in chars:
		zs.append((c as Node2D).z_index if is_instance_valid(c) else -999)
	return [zs]


func _diff_depth() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	_enemy_target = 0
	_walk = false
	await _clear_weapons()
	var game_cd: Node = _main.get_node("CreatureDepth")
	game_cd.set_process(false)
	game_cd.call("_exit_tree")
	var old_node := Node.new()
	old_node.set_script(load("res://scripts/_old_creature_depth.gd"))
	old_node.name = "OldDepth"
	var new_node := Node.new()
	new_node.set_script(load("res://scripts/creature_depth.gd"))
	new_node.name = "NewDepth"
	_main.add_child(old_node)
	_main.add_child(new_node)
	old_node.set_process(false)
	new_node.set_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var pp: Vector2 = _player.global_position
	var player_z: int = _player.z_index
	## ---- Bölüm A: sentetik (görev kopyası tarzı) yaratıklar + sahte uzak oyuncu
	var fakes: Array = []
	var ncount: int = _env_int("PG_FAKES", 160)
	for i in range(ncount):
		var w: int = [24, 32, 48, 64, 96][rng.randi() % 5]
		var h: int = [32, 48, 64, 96][rng.randi() % 4]
		var f: Node2D = _fake_creature(pp + Vector2(rng.randf_range(-300, 300), rng.randf_range(-200, 330)), w, h, [0.5, 0.75, 1.0, 1.5][rng.randi() % 4], rng.randi() % 9)
		fakes.append(f)
	var rp := FakeChar.new()
	rp.add_to_group("remote_players")
	rp.z_index = player_z
	_main.add_child(rp)
	rp.global_position = pp + Vector2(70, 40)
	var chars: Array = [_player, rp]
	var mism: int = 0
	var checks: int = 0
	var trials: int = _env_int("PG_TRIALS", 70)
	for t in range(trials):
		for f in fakes:
			var r: float = rng.randf()
			if r < 0.25:
				f.global_position = pp + Vector2(rng.randf_range(-300, 300), rng.randf_range(-200, 330))
			else:
				f.global_position += Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
			f.visible = rng.randf() > 0.06
			f.is_dead = rng.randf() < 0.05
		rp.global_position += Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
		var dome_on: bool = t >= 20 and t < 45
		_player.set("paladin_zone_active", dome_on)
		_player.set("paladin_zone_radius", 110.0 + float(t % 30) * 2.0)
		rp.paladin_zone_active = t >= 32 and t < 45
		rp.paladin_zone_radius = 100.0
		## eski
		for f in fakes:
			(f as Node2D).z_index = 0
		for c in chars:
			(c as Node2D).z_index = player_z
		old_node.call("update_now")
		var m_old: Array = _depth_maps(fakes, chars)
		for f in fakes:
			(f as Node2D).z_index = 0
		for c in chars:
			(c as Node2D).z_index = player_z
		new_node.call("update_now")
		var m_new: Array = _depth_maps(fakes, chars)
		var za: PackedInt32Array = m_old[0]
		var zb: PackedInt32Array = m_new[0]
		var bad: int = 0
		for k in range(za.size()):
			checks += 1
			if za[k] != zb[k]:
				bad += 1
		if bad > 0:
			mism += bad
			if mism <= bad + 6:
				print("PG DIFF trial=%d dome=%s mismatches=%d (ilk fark idx=%d eski=%d yeni=%d)" % [t, str(dome_on), bad, _first_diff(za, zb), za[_first_diff(za, zb)], zb[_first_diff(za, zb)]])
	print("PG DIFF A (sentetik): kontrol=%d uyusmazlik=%d" % [checks, mism])
	## süre (son sahne): sıfırlayıp iki yolu da 25 kez
	var t_old: Array = _t_us(func() -> void: old_node.call("update_now"), 25)
	var t_new: Array = _t_us(func() -> void: new_node.call("update_now"), 25)
	_pr("A old update_now (sentetik %d)" % ncount, t_old)
	_pr("A new update_now (sentetik %d)" % ncount, t_new)
	for f in fakes:
		if is_instance_valid(f):
			(f as Node2D).z_index = 0
			f.queue_free()
	rp.queue_free()
	_player.set("paladin_zone_active", false)
	await _wait(0.3)
	## ---- Bölüm B: gerçek C++ yaratıkları (hareketli kalabalık)
	_spawn_crowd(_n)
	await _wait(float(_env_int("PG_SETTLE", 14)))
	var reals: Array = []
	var mism2: int = 0
	var checks2: int = 0
	var told: Array = []
	var tnew: Array = []
	for t in range(40):
		await physics_frame
		reals = get_nodes_in_group("enemies")
		for e in reals:
			(e as Node2D).z_index = 0
		_player.z_index = player_z
		var a0: int = Time.get_ticks_usec()
		old_node.call("update_now")
		told.append(Time.get_ticks_usec() - a0)
		var ma: Array = _depth_maps(reals, [_player])
		for e in reals:
			(e as Node2D).z_index = 0
		_player.z_index = player_z
		var b0: int = Time.get_ticks_usec()
		new_node.call("update_now")
		tnew.append(Time.get_ticks_usec() - b0)
		var mb: Array = _depth_maps(reals, [_player])
		var za2: PackedInt32Array = ma[0]
		var zb2: PackedInt32Array = mb[0]
		for k in range(za2.size()):
			checks2 += 1
			if za2[k] != zb2[k]:
				mism2 += 1
	told.sort()
	tnew.sort()
	print("PG DIFF B (gercek kalabalik): kontrol=%d uyusmazlik=%d  old_median=%d us new_median=%d us (n=%d)" % [checks2, mism2, told[told.size() / 2], tnew[tnew.size() / 2], reals.size()])
	for e in reals:
		if is_instance_valid(e):
			(e as Node2D).z_index = 0


func _first_diff(a: PackedInt32Array, b: PackedInt32Array) -> int:
	for k in range(a.size()):
		if a[k] != b[k]:
			return k
	return 0


func _prof_depth() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	_enemy_target = 0
	_walk = false
	await _clear_weapons()
	var game_cd: Node = _main.get_node("CreatureDepth")
	game_cd.set_process(false)
	game_cd.call("_exit_tree")
	_spawn_crowd(_n)
	await _wait(float(_env_int("PG_SETTLE", 14)))
	var scr: GDScript = load("res://scripts/_prof_creature_depth.gd")
	var node := Node.new()
	node.set_script(scr)
	_main.add_child(node)
	node.set_process(false)
	for i in range(40):
		await physics_frame
		node.call("update_now")
	var t: PackedFloat64Array = scr.get("T")
	var n: int = int(scr.get("N"))
	print("PG PROF pool_index: total_us/call=%.0f calls/call=%.1f misses/call=%.1f ; should_cover total_us/call=%.0f n/call=%.1f" % [float(scr.get("PI_US")) / n, float(scr.get("PI_CALLS")) / n, float(scr.get("MISS")) / n, float(scr.get("SHOULD_US")) / n, float(scr.get("SHOULD_N")) / n])
	print("PG PROF depth (us/call, n=%d): chars=%.0f query=%.0f cand_loop=%.0f close_core=%.0f dome=%.0f apply=%.0f | want_avg=%.1f" % [n, t[0] / n, t[1] / n, t[2] / n, t[3] / n, t[4] / n, t[5] / n, t[6] / n])


## creature_depth.gd C++ yolunun (madde 280) parça parça maliyeti: karakter toplama / kubbe sorgusu / C++ tarama / uygulama; toplam update_now (C++ yol <-> eski yol).
func _prof_depth_cpp() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	_enemy_target = 0
	_walk = false
	await _clear_weapons()
	var game_cd: Node = _main.get_node("CreatureDepth")
	game_cd.set_process(false)
	_spawn_crowd(_n)
	await _wait(float(_env_int("PG_SETTLE", 14)))
	var DepthScript: GDScript = load("res://scripts/depth_occluders.gd")
	var PaladinDome: GDScript = load("res://scripts/paladin_dome.gd")
	var ew: Object = _main.get_node("EnemyWorldBridge").get("world")
	var tree: SceneTree = self
	var cd_script: GDScript = load("res://scripts/creature_depth.gd")
	var cd: Node = Node.new()
	cd.set_script(cd_script)
	_main.add_child(cd)
	cd.set_process(false)
	for i in range(30):
		await physics_frame
		cd.call("update_now")
	var t_chars: Array = _t_us(func() -> void: DepthScript.collect_characters(tree), 60)
	var t_doms: Array = _t_us(func() -> void: PaladinDome.active_domes(tree), 60)
	var chars: Array[Vector4] = DepthScript.collect_characters(tree)
	var cxy := PackedFloat64Array()
	for c in chars:
		cxy.append(c.x)
		cxy.append(c.y)
	var params := PackedFloat64Array([cd_script.SCAN_RADIUS, cd_script.CLOSURE_PAD, cd_script.ABOVE_SKIP, cd_script.HYSTERESIS, DepthScript.BODY_HALF_WIDTH, 24.0])
	var t_scan: Array = _t_us(func() -> void: ew.call("depth_scan", cxy, [], PackedFloat64Array(), PackedByteArray(), params, false), 60)
	var res: Array = ew.call("depth_scan", cxy, [], PackedFloat64Array(), PackedByteArray(), params, false)
	var t_dict: Array = _t_us(func() -> void:
		var w: Dictionary = {}
		for n in res:
			w[n] = true, 60)
	var t_all: Array = _t_us(func() -> void: cd.call("update_now"), 60)
	_pr("collect_characters", t_chars)
	_pr("active_domes", t_doms)
	_pr("depth_scan (C++, %d istenen)" % res.size(), t_scan)
	_pr("istenen -> sozluk", t_dict)
	_pr("update_now TOPLAM (C++ yol, n=%d)" % get_nodes_in_group("enemies").size(), t_all)
	cd_script.set("_cpp_on", false)
	var t_old: Array = _t_us(func() -> void: cd.call("update_now"), 60)
	_pr("update_now TOPLAM (eski GDScript yol)", t_old)
	cd_script.set("_cpp_on", true)


func _prof_tick() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	_enemy_target = 0
	_walk = false
	await _clear_weapons()
	_spawn_crowd(_n)
	await _wait(float(_env_int("PG_SETTLE", 16)))
	var bridge: Node = _main.get_node("EnemyWorldBridge")
	var act_arr: Array = (bridge.get("_active") as Array).duplicate()
	var valid: Array = []
	for e in act_arr:
		if is_instance_valid(e) and e._ew_slot >= 0:
			valid.append(e)
	var ab: Array = []
	for e in valid:
		if e._abilities != null:
			ab.append(e)
	print("PG PROF tick: awake=%d with_abilities=%d" % [valid.size(), ab.size()])
	var per := func(label: String, r: Array, n: int) -> void:
		print("PG PROF %-34s total=%7.0f us  per_creature=%5.2f us (n=%d)" % [label, r[0], r[0] / float(maxi(1, n)), n])
	per.call("loop overhead (empty)", _t_us(func() -> void:
		for e in valid:
			pass, 40), valid.size())
	per.call("is_instance_valid + _ew_slot", _t_us(func() -> void:
		for e in valid:
			if is_instance_valid(e) and e._ew_slot >= 0:
				pass, 40), valid.size())
	per.call("_ew_push_state", _t_us(func() -> void:
		for e in valid:
			e._ew_push_state(), 40), valid.size())
	per.call("_ew_still_active", _t_us(func() -> void:
		for e in valid:
			e._ew_still_active(), 40), valid.size())
	per.call("_ew_hit_radius", _t_us(func() -> void:
		for e in valid:
			e._ew_hit_radius(), 40), valid.size())
	per.call("get_target+dist+target_node", _t_us(func() -> void:
		for e in valid:
			var ti: int = e._ew_world.get_target(e._ew_slot)
			if ti >= 0:
				var p: Node2D = bridge.target_node(ti)
				var d: float = e._ew_world.get_target_dist(e._ew_slot), 40), valid.size())
	per.call("abilities.process(0,null,INF)", _t_us(func() -> void:
		for e in ab:
			e._abilities.process(0.0, null, INF), 40), ab.size())
	per.call("full _ew_tick(0)", _t_us(func() -> void:
		for e in valid:
			e._ew_tick(0.0), 40), valid.size())
	## durum dagilimi + alt kume zamanlari
	var cnt: Dictionary = {}
	var by_state: Dictionary = {}
	for e in valid:
		var k: String = "state%d%s" % [int(e._state), "+ab" if e._abilities != null else ""]
		cnt[k] = int(cnt.get(k, 0)) + 1
		if not by_state.has(int(e._state)):
			by_state[int(e._state)] = []
		(by_state[int(e._state)] as Array).append(e)
	print("PG PROF states: ", str(cnt), "  (0=WALK 1=HURT 2=ATTACK 3=DEATH 4=IDLE)")
	var fastd: Dictionary = {}
	for e in valid:
		if e._abilities != null:
			var ok: bool = e._abilities.process_fast(0.00001)
			var fk: String = "%s st%d fast=%s" % [e._abilities.family, int(e._state), str(ok)]
			fastd[fk] = int(fastd.get(fk, 0)) + 1
	print("PG PROF process_fast outcomes: ", str(fastd))
	for st in by_state:
		var arr: Array = by_state[st]
		per.call("  _ew_tick(0) only state %d" % int(st), _t_us(func() -> void:
			for e in arr:
				e._ew_tick(0.0), 40), arr.size())
	per.call("is_dead/ability checks only", _t_us(func() -> void:
		for e in valid:
			if e.is_frozen: pass
			if e.is_feared: pass
			if e._abilities_checked: pass, 40), valid.size())


## Oyuncunun _physics_process'indeki her yardımcı çağrının savaştaki süresi (medyan us; durumu değiştirmeden dt=0 ile) - FPS turu 4.
func _prof_player() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(true)
	_enemy_target = _n
	_walk = true
	await _wait(float(_env_int("PG_SETTLE", 25)))
	var names: Array = ["_refresh_ui_skill_block", "_refresh_korsan_gold_ap", "_refresh_item_ap_percent", "_update_death_status_fx", "_update_revive_rewind_fx", "_process_vampir", "_process_hadime_visuals", "_process_cadi_visuals", "_process_paladin_levitate", "_process_shaman_golem", "_process_matthew_form", "_process_spirit", "_clamp_to_map_bounds", "_process_mining", "_process_regen", "_process_enemy_burn", "_process_enemy_bleed", "_process_skill", "_process_skill2", "_process_item_shield", "_process_item_passives", "_process_kalkan_yenileme", "_process_healer_heal_tick", "_process_temp_speed_boost", "_process_shield_regen_tick", "_process_paladin_ulti", "_process_elara_evasion", "_update_shield_bubble", "_process_spray", "_process_xp_streak", "_process_character_passive", "_process_korsan_bombs", "_process_pet", "_process_korsan_bombardment", "_process_talon_weapon_salvo", "_process_talon_mirror_form", "_process_assasin_dash2_charges", "_process_shaman_q_charges", "_process_necro_skeleton_cooldown", "_process_necro", "_process_matthew_speed_lines", "_process_buyucu", "_process_hadime", "_process_cadi", "_process_evo", "_process_skill3", "_process_oakley_bond", "_process_damage_redirect_range_check", "_process_paladin_barrier_roster", "_refresh_local_barrier_link_visual", "_process_merchant_zone_state", "_block_movement_into_enemies", "_block_movement_into_blockers", "_block_movement_into_players", "_block_movement_into_terrain", "get_effective_move_speed", "move_and_slide"]
	var rows: Array = []
	for nm in names:
		if not _player.has_method(nm):
			continue
		var takes: int = 0
		for m in _player.get_method_list():
			if m["name"] == nm:
				takes = (m["args"] as Array).size()
				break
		var r: Array = _t_us(func() -> void:
			if takes == 1:
				_player.call(nm, 0.0)
			else:
				_player.call(nm), 60)
		rows.append([r[0], nm, r[1]])
	var tw: Array = []
	for i in range(3):
		tw.append(_t_us(func() -> void: _player.call("_update_walk_sound", true, 0.0), 60))
	rows.append([tw[1][0], "_update_walk_sound(true,0)", tw[1][1]])
	rows.append([_t_us(func() -> void: _player.call("_update_facing", Vector2(1, 0)), 60)[0], "_update_facing", 0.0])
	rows.append([_t_us(func() -> void: _player.call("_update_animation", true), 60)[0], "_update_animation(true)", 0.0])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var total: float = 0.0
	for r in rows:
		total += float(r[0])
	print("PG PLAYER toplam=%.0f us (%d çağrı, dt=0 medyanları)" % [total, rows.size()])
	for i in range(mini(24, rows.size())):
		print("PG PLAYER   %-40s median=%7.1f us  mean=%7.1f" % [rows[i][1], rows[i][0], rows[i][2]])


## SAVAŞTA (silahlı oyuncu, PG_N yaratık) uyanık yaratıkların sınıfları: aile + durum başına _ew_tick(0) / _ew_push_state maliyeti (FPS turu 4).
func _prof_fight() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(true)
	_enemy_target = _n
	_walk = true
	await _wait(float(_env_int("PG_SETTLE", 25)))
	var bridge: Node = _main.get_node("EnemyWorldBridge")
	var groups: Dictionary = {}
	var total: int = 0
	for e in (bridge.get("_active") as Array):
		if not is_instance_valid(e) or e._ew_slot < 0:
			continue
		total += 1
		var fam: String = ("ab:" + str(e._abilities.family)) if e._abilities != null else ("plain:" + str(e.call("creature_family")))
		var key: String = "%s st%d" % [fam, int(e._state)]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(e)
	print("PG FIGHT awake=%d registered=%d" % [total, int(bridge.get("world").call("get_count"))])
	var keys: Array = groups.keys()
	keys.sort()
	var sum_tick: float = 0.0
	var sum_push: float = 0.0
	for key in keys:
		var arr: Array = groups[key]
		var r_tick: Array = _t_us(func() -> void:
			for e in arr:
				e._ew_tick(0.0), 40)
		var r_push: Array = _t_us(func() -> void:
			for e in arr:
				e._ew_push_state(), 40)
		sum_tick += r_tick[0]
		sum_push += r_push[0]
		print("PG FIGHT %-26s n=%3d  tick(0)=%6.2f us/e  push=%5.2f us/e  (tick sum %6.0f us)" % [key, arr.size(), r_tick[0] / float(arr.size()), r_push[0] / float(arr.size()), r_tick[0]])
	print("PG FIGHT total tick(0) sum=%.0f us  push sum=%.0f us" % [sum_tick, sum_push])
	var world: Object = bridge.get("world")
	var sums: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var fr: int = 0
	var ev0: PackedInt32Array = (bridge.get("event_counts") as PackedInt32Array).duplicate()
	var st0: Array = [int(bridge.get("stat_sleeps")), int(bridge.get("stat_wakes_ext")), int(bridge.get("stat_wakes_due"))]
	var dorm_sum: float = 0.0
	var act_sum: float = 0.0
	var t_end: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < t_end:
		await physics_frame
		sums[0] += float(bridge.get("last_bridge_ms"))
		sums[1] += float(bridge.get("last_step_ms"))
		sums[2] += float(bridge.get("last_view_ms"))
		sums[3] += float(bridge.get("last_tick_ms"))
		sums[4] += float(bridge.get("last_pre_ms"))
		sums[5] += float(bridge.get("last_events_ms"))
		sums[6] += float(bridge.get("last_loop_ms"))
		dorm_sum += float(bridge.get("dormant_count"))
		act_sum += float((bridge.get("_active") as Array).size())
		fr += 1
	print("PG FIGHT bridge/frame ms: total=%.2f cpp_step=%.2f (view %.2f) gd_events+ticks=%.2f frames=%d" % [sums[0] / fr, sums[1] / fr, sums[2] / fr, sums[3] / fr, fr])
	print("PG FIGHT dormancy transitions per tick: sleeps=%.2f wakes_external=%.2f wakes_due=%.2f" % [float(int(bridge.get("stat_sleeps")) - st0[0]) / fr, float(int(bridge.get("stat_wakes_ext")) - st0[1]) / fr, float(int(bridge.get("stat_wakes_due")) - st0[2]) / fr])
	print("PG FIGHT bridge phases ms: pre(grid+targets+extra+push)=%.2f step=%.2f events+sweep+wake=%.2f tick-loop=%.2f" % [sums[4] / fr, sums[1] / fr, sums[5] / fr, sums[6] / fr])
	var ev1: PackedInt32Array = bridge.get("event_counts")
	var evs: Array = []
	for i in range(ev1.size()):
		evs.append("%d:%.1f/tik" % [i, float(ev1[i] - ev0[i]) / float(fr)])
	print("PG FIGHT events per tick (0 melee 1 barrier 2 ghost 3 ranged 4 homing 5 taunt 6 loco): %s ; dormant avg=%.0f active avg=%.0f" % [", ".join(evs), dorm_sum / fr, act_sum / fr])
	## Yetenekli yaratıkların "sessiz bekleme" payı: kalan sessiz süre (sn) dağılımı, 12 örnek x 1 sn
	var buckets: Dictionary = {}
	var samples: int = 0
	for s in range(12):
		await _wait(1.0)
		for e in (bridge.get("_active") as Array):
			if not is_instance_valid(e) or e._ew_slot < 0 or e._abilities == null:
				continue
			var ab: RefCounted = e._abilities
			var fam: String = ab.family
			var rem: float = 0.0
			var busy: bool = e._flash_time_left > 0.0 or e.is_frozen or e.is_feared or e.is_stunned or e.ability_move_lock > 0.0 or e._state_duration > 0.0 \
					or e._overhead_bar_hide_timer > 0.0 or e.burn_time_left > 0.0 or e.mark_stacks > 0 or e.bleed_stacks > 0 or e.shock_time_left > 0.0 \
					or e._sleep_time > 0.0 or e.chill_stacks > 0 or e._boss_chill_stacks > 0 or e._slow_timer > 0.0 or e._slow_fx_time_left > 0.0 \
					or e._slow_fx_broadcast_cooldown > 0.0 or e._root_timer > 0.0 or e.is_mad or (e._state != 0 and e._state != 4) \
					or not e._poison_stack_time.is_empty() or not e._plague.is_empty() or not e._enchant_flags.is_empty() or not e._bee_poison_stacks.is_empty() \
					or (e.item_shield_max > 0.0 and (e.item_shield_regen_delay > 0.0 or e.item_shield_hp < e.item_shield_max))
			if fam == "hayalet":
				rem = ab._timer if e.is_ability_invisible else ab._cd
			elif fam == "vampire":
				rem = ab._cd if ab._cd > 0.0 else (ab._vision_check if ab._pending < 0.0 else ab._pending)
			elif fam in ["rontgen", "iblis", "agac"]:
				rem = ab._cd
			else:
				rem = -1.0 ## boss / minotaur: hızlı yol yok
			var bk: String = "%s %s %s" % [fam, "BUSY" if busy else "quiet", ("rem<=0" if rem <= 0.0 else ("rem<0.1" if rem < 0.1 else ("rem<0.5" if rem < 0.5 else ("rem<2" if rem < 2.0 else "rem>=2"))))]
			buckets[bk] = int(buckets.get(bk, 0)) + 1
			samples += 1
	## Hangi "meşgul" koşul kaç yetenekli yaratıkta doğru (anlık)
	var cond: Dictionary = {}
	var n_ab: int = 0
	for e in (bridge.get("_active") as Array):
		if not is_instance_valid(e) or e._ew_slot < 0 or e._abilities == null:
			continue
		n_ab += 1
		var tests: Dictionary = {
			"flash": e._flash_time_left > 0.0, "frozen": e.is_frozen, "feared": e.is_feared, "stunned": e.is_stunned, "move_lock": e.ability_move_lock > 0.0,
			"state_duration": e._state_duration > 0.0, "overhead_timer": e._overhead_bar_hide_timer > 0.0,
			"item_shield": e.item_shield_max > 0.0 and (e.item_shield_regen_delay > 0.0 or e.item_shield_hp < e.item_shield_max), "burn": e.burn_time_left > 0.0,
			"mark": e.mark_stacks > 0, "bleed": e.bleed_stacks > 0, "shock": e.shock_time_left > 0.0, "sleep": e._sleep_time > 0.0, "chill": e.chill_stacks > 0,
			"boss_chill": e._boss_chill_stacks > 0, "slow_timer": e._slow_timer > 0.0, "slow_fx": e._slow_fx_time_left > 0.0, "slow_bc": e._slow_fx_broadcast_cooldown > 0.0,
			"root": e._root_timer > 0.0, "mad": e.is_mad, "state_not_walk_idle": e._state != 0 and e._state != 4, "poison": not e._poison_stack_time.is_empty(),
			"plague": not e._plague.is_empty(), "enchant": not e._enchant_flags.is_empty(), "bee": not e._bee_poison_stacks.is_empty(),
		}
		for k in tests:
			if tests[k]:
				cond[k] = int(cond.get(k, 0)) + 1
	print("PG FIGHT busy-cond (of %d ability creatures now): %s" % [n_ab, str(cond)])
	var bk_keys: Array = buckets.keys()
	bk_keys.sort()
	for k in bk_keys:
		print("PG FIGHT quiet-dist %-30s %5.1f%%  (avg %.1f creatures)" % [k, 100.0 * float(buckets[k]) / float(samples), float(buckets[k]) / 12.0])
	## Sisin her karede dolaştığı grupların boyutları (vision_fog.gd HIDEABLE_GROUPS) ve toplam düğüm sayısı
	var gsz: Array = []
	for g in ["enemies", "enemy_projectiles", "xp_orbs", "gold_drops", "food_drops", "chest_drops", "magnet_drops", "shield_orb_drops"]:
		gsz.append("%s=%d" % [g, get_nodes_in_group(g).size()])
	print("PG FIGHT fog groups: %s ; nodes total=%d" % [", ".join(gsz), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	## Sis: yerdeki / mermi öğeleri için GDScript yönetimi (_manage_item) - öğe sayısı, elips içindekiler ve tüm öğeler için tek geçiş süresi
	var fog: Node = get_first_node_in_group("vision_fog")
	if fog != null:
		var items: Array = []
		for g in ["enemy_projectiles", "xp_orbs", "gold_drops", "food_drops", "chest_drops", "magnet_drops", "shield_orb_drops"]:
			for it in get_nodes_in_group(g):
				if it is Node2D:
					items.append(it)
		var inside: int = 0
		for it in items:
			if float((it as Node).get_meta("vision_fog_vis", 0.0)) > 0.0:
				inside += 1
		var r_all: Array = _t_us(func() -> void:
			for it in items:
				fog.call("_manage_item", it, 0.016), 30)
		var r_upd: Array = _t_us(func() -> void: fog.call("update_fog", 0.016), 30)
		## Işın hızlı retinin (vision_occluders.gd _box_is_clear) gerçek haritada tutma oranı: ızgaranın ortasındaki yarı bölgede rastgele kaynak, <= 400 px rastgele ışın
		var occ: Variant = fog.get("_occluders")
		if occ != null and not (occ as RefCounted).call("is_empty"):
			var go: Vector2i = occ.call("get_grid_origin")
			var gs: Vector2i = occ.call("get_grid_size")
			var cs: float = float(occ.call("get_cell_size"))
			var wo: Vector2 = occ.call("get_world_origin")
			var rng := RandomNumberGenerator.new()
			rng.seed = 99
			var clear_n: int = 0
			var tot: int = 3000
			for k in range(tot):
				var cx: float = float(go.x) + float(gs.x) * rng.randf_range(0.25, 0.75)
				var cy: float = float(go.y) + float(gs.y) * rng.randf_range(0.25, 0.75)
				var src: Vector2 = wo + Vector2(cx, cy) * cs
				var dst: Vector2 = src + Vector2(rng.randf_range(-360.0, 360.0), rng.randf_range(-260.0, 260.0))
				if occ.call("_box_is_clear", occ.call("world_to_cell_f", src), occ.call("world_to_cell_f", dst)):
					clear_n += 1
			print("PG FIGHT raybox hit rate (grid center half, rays <= 360x260 px): %.1f%% of %d" % [100.0 * float(clear_n) / float(tot), tot])
		print("PG FIGHT fog items: n=%d inside_ellipse=%d ; _manage_item pass (all) median=%.0f us (%.2f us/item) ; update_fog median=%.0f us" % [items.size(), inside, r_all[0], r_all[0] / float(maxi(1, items.size())), r_upd[0]])
	## Hasar sayıları: savaşta gerçek kayıt sayısı + _process(0) süresi (dt=0: durum değişmez), 240 kare örneği
	var dnmod: GDScript = load("res://scripts/damage_numbers.gd")
	var dn: Node2D = dnmod.call("get_instance", self)
	if dn != null:
		var ts: Array = []
		var ns: Array = []
		for k in range(240):
			await process_frame
			var cnt: int = (dn.get("_entries") as Dictionary).size()
			var t0: int = Time.get_ticks_usec()
			dn.call("_process", 0.0)
			ts.append(float(Time.get_ticks_usec() - t0))
			ns.append(float(cnt))
		var st: float = 0.0
		var sn: float = 0.0
		for k in range(ts.size()):
			st += ts[k]
			sn += ns[k]
		var ts_sorted: Array = ts.duplicate()
		ts_sorted.sort()
		print("PG FIGHT damage_numbers._process(0): mean=%.0f us median=%.0f us p90=%.0f us  entries mean=%.0f  (us/entry %.2f)" % [st / ts.size(), ts_sorted[ts.size() / 2], ts_sorted[int(ts.size() * 0.9)], sn / ts.size(), st / maxf(1.0, sn)])
	print("PG FIGHT world=%s" % str(world))


## ---------------------------------------------------------------- DamageNumbers ESKİ (_old_damage_numbers.gd) <-> YENİ: iki SubViewport'ta aynı olaylar, piksel piksel karşılaştırma
func _old_capped(dn: Node2D, ids: Array, target: Node2D, pos: Vector2, text: String, color: Color) -> Array:
	var alive: Array = []
	for id in ids:
		if dn.is_alive(id):
			alive.append(id)
	while alive.size() >= 5:
		dn.remove(alive.pop_front())
	alive.append(dn.spawn_fixed(target, pos, text, color))
	return alive


func _make_dn_view(script_path: String) -> Array:
	var vp := SubViewport.new()
	vp.size = Vector2i(360, 260)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.2, 0.12, 1.0)
	bg.size = Vector2(360, 260)
	vp.add_child(bg)
	var dn := Node2D.new()
	dn.set_script(load(script_path))
	vp.add_child(dn)
	dn.set_process(false)
	var targets: Array = []
	for i in range(6):
		var t := Node2D.new()
		vp.add_child(t)
		targets.append(t)
	return [vp, dn, targets]


func _diff_dn() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _wait(1.0)
	var A: Array = _make_dn_view("res://scripts/_old_damage_numbers.gd")
	var B: Array = _make_dn_view("res://scripts/damage_numbers.gd")
	## sis meta'sı: hedef 1 gizli (0.0), hedef 2 ortada gizlenir
	for V in [A, B]:
		(V[2][1] as Node2D).set_meta("vision_fog_vis", 0.0)
		(V[2][0] as Node2D).set_meta("vision_fog_vis", 1.0)
	var texts: Array = ["12", "13", "12", "7", "99", "12", "104", "7", "55", "13", "12", "8"]
	var cols: Array = [Color(1, 1, 1), Color(1, 1, 1), Color(1, 0.25, 0.2), Color(1, 1, 1)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var ids_old: Array = [[], [], []]
	var ids_new: Array = [[], [], []]
	var ids_old_plain: Array = []
	var ids_new_plain: Array = []
	var diffs: int = 0
	var captures: int = 0
	var dts: Array = [0.0166, 0.0167, 0.0166, 0.02, 0.0133, 0.0166, 0.0166, 0.033]
	for step in range(130):
		if step == 0 or step == 70 or step == 90:
			for i in range(14):
				var tx: String = texts[(i + step) % texts.size()]
				var col: Color = cols[(i * 3 + step) % cols.size()]
				var pos := Vector2(rng.randf_range(60, 300), rng.randf_range(80, 220))
				var ti: int = i % 3
				var which: int = rng.randi() % 3
				if i < 8:
					## yaratık başına sınırlı (enemy.gd yolu): 3 sahte yaratık
					ids_old[which] = _old_capped(A[1], ids_old[which], A[2][ti], pos, tx, col)
					var arr: Array[int] = []
					arr.assign(ids_new[which])
					B[1].spawn_fixed_capped(B[2][ti], pos, tx, col, arr, 5)
					ids_new[which] = arr
				else:
					ids_old_plain.append(A[1].spawn_fixed(A[2][ti], pos, tx, col))
					ids_new_plain.append(B[1].spawn_fixed(B[2][ti], pos, tx, col))
		if step == 95:
			## erken silme (havuza gider)
			for k in range(mini(4, ids_old_plain.size())):
				A[1].remove(ids_old_plain[k])
				B[1].remove(ids_new_plain[k])
		if step == 100:
			(A[2][2] as Node2D).set_meta("vision_fog_vis", 0.0)
			(B[2][2] as Node2D).set_meta("vision_fog_vis", 0.0)
		var dt: float = dts[step % dts.size()]
		A[1].call("_process", dt)
		B[1].call("_process", dt)
		if step in [2, 8, 15, 30, 50, 62, 72, 76, 85, 93, 97, 104, 112, 125]:
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var ia: Image = (A[0] as SubViewport).get_texture().get_image()
			var ib: Image = (B[0] as SubViewport).get_texture().get_image()
			captures += 1
			var nonbg: int = 0
			for yy in range(0, ia.get_height(), 2):
				for xx in range(0, ia.get_width(), 2):
					var pc: Color = ia.get_pixel(xx, yy)
					if absf(pc.r - 0.12) > 0.03 or absf(pc.g - 0.2) > 0.03:
						nonbg += 1
			print("PG DN step=%d text-pixels(sampled)=%d" % [step, nonbg])
			var da: PackedByteArray = ia.get_data()
			var db: PackedByteArray = ib.get_data()
			var nd: int = 0
			if da.size() != db.size():
				nd = -1
			else:
				for q in range(da.size()):
					if da[q] != db[q]:
						nd += 1
			if nd != 0:
				diffs += 1
				print("PG DN step=%d farkli bayt=%d" % [step, nd])
				if diffs == 1:
					ia.save_png("user://dn_old_%d.png" % step)
					ib.save_png("user://dn_new_%d.png" % step)
	print("PG DN karsilastirma: yakalama=%d farkli_kare=%d  (live old=%d new=%d, pool new=%d)" % [captures, diffs, (A[1].get("_entries") as Dictionary).size(), (B[1].get("_entries") as Dictionary).size(), int(B[1].get("_free_count"))])


## ---------------------------------------------------------------- İLK KULLANIM takılmaları: her yetenek tuşuna ilk (rep1) ve ikinci (rep2) basış, kare kare süre
func _firstuse() -> void:
	var ids: Array = []
	for t in (OS.get_environment("PG_CHARS") if OS.get_environment("PG_CHARS") != "" else "12,14,9,8").split(","):
		ids.append(int(t))
	var slots: Array = ["skill", "skill2", "skill3"]
	if OS.get_environment("PG_SLOTS") != "":
		slots = Array(OS.get_environment("PG_SLOTS").split(","))
	for cid in ids:
		if not await _boot(cid, _loadout[0]):
			print("PG BOOTFAIL char=%d" % cid)
			continue
		await _prepare(true, false)
		_enemy_target = 0
		_walk = false
		await _spawn_dummies(_n)
		if OS.get_environment("PG_PRELOAD_FILE") != "":
			var held: Array = []
			var t_pl: int = Time.get_ticks_usec()
			for pth0 in FileAccess.get_file_as_string(OS.get_environment("PG_PRELOAD_FILE")).split("
", false):
				var pth: String = pth0.strip_edges()
				if pth != "" and ResourceLoader.exists(pth):
					held.append(load(pth))
			set_meta("held_resources", held)
			print("PG PRELOAD %d kaynak, %.1f ms" % [held.size(), float(Time.get_ticks_usec() - t_pl) / 1000.0])
		await _wait(float(_env_int("PG_PRE", 3)))
		for slot in slots:
			var sv: Array = _slot_vars(slot)
			for rep in range(2):
				_player.set(sv[0], "ready")
				_player.set(sv[1], 0.0)
				_player.set("item_shield_max", 300.0)
				_player.set("item_shield_hp", 300.0)
				_player.set("necro_souls", 25)
				if OS.get_environment("PG_POTION") != "":
					_player.set("_cadi_next_potion", int(OS.get_environment("PG_POTION"))) ## Cadi R: iksiri zorla
					_player.set("cadi_r_charges", 5)
				await _wait(0.8)
				print("PG MARK char=%d slot=%s rep=%d" % [cid, slot, rep + 1])
				Input.action_press(slot)
				var frames: Array = []
				var last: int = Time.get_ticks_usec()
				for f in range(150):
					await process_frame
					var now: int = Time.get_ticks_usec()
					frames.append(float(now - last) / 1000.0)
					last = now
					if f == 3:
						Input.action_release(slot)
				var mx: float = 0.0
				var mi: int = 0
				for i in range(frames.size()):
					if float(frames[i]) > mx:
						mx = float(frames[i])
						mi = i
				var st: String = str(_player.get(sv[0]))
				print("PG FIRST char=%d slot=%s rep=%d state=%s max=%.1f ms @frame %d | first6=%s" % [cid, slot, rep + 1, st, mx, mi, ",".join(PackedStringArray(frames.slice(0, 6).map(func(v: float) -> String: return "%.1f" % v)))])
				if st == "active" or st == "on":
					Input.action_press(slot)
					await process_frame
					await process_frame
					Input.action_release(slot)
				print("PG MARKEND")
				await _wait(2.0)


func _prof_hit() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	_enemy_target = 0
	_walk = false
	await _clear_weapons()
	await _spawn_dummies(_n)
	await _wait(2.0)
	var pl: Node = _player
	var ds: Array = []
	for d in _dummies:
		if is_instance_valid(d):
			ds.append(d)
	var BL: GDScript = load("res://scripts/balance_log.gd")
	var per := func(label: String, c: Callable) -> void:
		var r: Array = _t_us(c, 30)
		print("PG HITP %-44s total=%7.1f us  per_enemy=%6.2f us" % [label, r[0], r[0] / float(maxi(1, ds.size()))])
	per.call("get_first_node_in_group(player)", func() -> void:
		for d in ds:
			d.get_tree().get_first_node_in_group("player"))
	per.call("'match_damage_dealt' in player", func() -> void:
		for d in ds:
			var _x: bool = "match_damage_dealt" in pl)
	per.call("BalanceLog.take_src", func() -> void:
		for d in ds:
			BL.take_src())
	per.call("BalanceLog.on_hit", func() -> void:
		for d in ds:
			BL.on_hit("", 5.0, false))
	per.call("player.on_dealer_hit(5, true)", func() -> void:
		for d in ds:
			pl.on_dealer_hit(5.0, true))
	per.call("enemy._attacker_has_savas_sevki", func() -> void:
		for d in ds:
			d._attacker_has_savas_sevki())
	per.call("enemy._broadcast_hit_flash", func() -> void:
		for d in ds:
			d._broadcast_hit_flash())
	per.call("enemy._post_direct_hit(5)", func() -> void:
		for d in ds:
			d._post_direct_hit(5.0))
	per.call("enemy._pre_direct_hit(5)", func() -> void:
		for d in ds:
			d._pre_direct_hit(5.0))
	per.call("enemy._show_overhead_bar", func() -> void:
		for d in ds:
			d._show_overhead_bar())
	per.call("enemy._flash (cooldown-blocked)", func() -> void:
		for d in ds:
			d._flash())
	per.call("enemy._record_assist_damage", func() -> void:
		for d in ds:
			d._record_assist_damage(5.0))
	per.call("enemy._show_hit_number", func() -> void:
		for d in ds:
			d._show_hit_number(5.0, false))
	per.call("health_changed.emit", func() -> void:
		for d in ds:
			d.health_changed.emit(d.health, d.max_health))
	per.call("PhysicsInterp.visual_position", func() -> void:
		var PI_: GDScript = load("res://scripts/physics_interp.gd")
		for d in ds:
			PI_.visual_position(d))
	per.call("take_damage FULL", func() -> void:
		for d in ds:
			d.take_damage(5.0, false, 0.0, true))


## Silahlar açık/kapalı ardışık A/B (sürüklenme gürültüsünü ortalar): savaş senaryosunda silah düğümlerinin process_mode'unu 8 kez açıp kapatır.
func _ab_weapons() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(true)
	_enemy_target = _n
	_walk = true
	await _wait(float(_env_int("PG_SETTLE", 25)))
	var weapons: Array = (_player.get("owned_weapon_nodes") as Array).duplicate()
	var cycles: int = _env_int("PG_CYCLES", 8)
	var acc := {"on": [], "off": []}
	for c in range(cycles):
		for state in ["on", "off"]:
			for w in weapons:
				if is_instance_valid(w):
					w.process_mode = Node.PROCESS_MODE_INHERIT if state == "on" else Node.PROCESS_MODE_DISABLED
			await _wait(0.7)
			var m: Dictionary = await _measure(2.3)
			acc[state].append([float(m["logic"]), float(m["mean"]), float(m["p95"])])
		print("PG AB cycle %d: on logic=%.2f mean=%.2f | off logic=%.2f mean=%.2f" % [c, acc["on"][c][0], acc["on"][c][1], acc["off"][c][0], acc["off"][c][1]])
	var sums := {}
	for state in ["on", "off"]:
		var l: float = 0.0
		var fm: float = 0.0
		var p: float = 0.0
		for r in acc[state]:
			l += r[0]
			fm += r[1]
			p += r[2]
		sums[state] = [l / cycles, fm / cycles, p / cycles]
	print("PG AB RESULT weapons: on logic=%.2f mean=%.2f p95=%.2f | off logic=%.2f mean=%.2f p95=%.2f | delta logic=%+.2f mean=%+.2f" % [sums["on"][0], sums["on"][1], sums["on"][2], sums["off"][0], sums["off"][1], sums["off"][2], sums["on"][0] - sums["off"][0], sums["on"][1] - sums["off"][1]])


## Yağmur açık/kapalı ardışık A/B (boş harita, sadece hava): yağmur düğümünün process_mode + visible'ını açıp kapatır.
func _ab_rain() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	_enemy_target = 0
	_walk = false
	await _clear_weapons()
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	var atmo: Node = get_first_node_in_group("atmosphere")
	var rain: Node = atmo.get_node_or_null("Rain") if atmo != null else null
	if rain == null:
		print("PG RAIN yok")
		return
	await _wait(float(_env_int("PG_SETTLE", 14))) ## yağmurun tam şiddete çıkması (9 sn)
	print("PG RAIN intensity=%.2f storm=%.2f drops=%d" % [float(rain.get("intensity")), float(rain.get("storm")), (rain.get("_ground") as PackedVector2Array).size()])
	var cycles: int = _env_int("PG_CYCLES", 8)
	var acc := {"on": [], "off": []}
	for c in range(cycles):
		for state in ["on", "off"]:
			rain.process_mode = Node.PROCESS_MODE_INHERIT if state == "on" else Node.PROCESS_MODE_DISABLED
			rain.visible = state == "on"
			await _wait(0.6)
			var m: Dictionary = await _measure(2.0)
			acc[state].append([float(m["logic"]), float(m["mean"]), float(m["rcpu"])])
	var sums := {}
	for state in ["on", "off"]:
		var a: float = 0.0
		var b: float = 0.0
		var d: float = 0.0
		for r in acc[state]:
			a += r[0]
			b += r[1]
			d += r[2]
		sums[state] = [a / cycles, b / cycles, d / cycles]
	print("PG AB RESULT rain: on logic=%.2f mean=%.2f rcpu=%.2f | off logic=%.2f mean=%.2f rcpu=%.2f | delta logic=%+.2f mean=%+.2f rcpu=%+.2f" % [sums["on"][0], sums["on"][1], sums["on"][2], sums["off"][0], sums["off"][1], sums["off"][2], sums["on"][0] - sums["off"][0], sums["on"][1] - sums["off"][1], sums["on"][2] - sums["off"][2]])


## Her silahın İLK ateşinde yüklenenler (MARK/MARKEND arası --verbose günlüğüne bak) + o andaki en yavaş kare.
func _firstweapon() -> void:
	if not await _boot(_char, "dagger"):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	_enemy_target = 0
	_walk = false
	await _clear_weapons()
	await _spawn_dummies(_n)
	_do_preload()
	await _wait(3.0)
	for k in ALL_WEAPONS:
		await _clear_weapons()
		await _wait(1.0)
		print("PG MARK weapon=%s rep=1" % k)
		_player.call("buy_weapon_copy", k, 1)
		var frames: Array = []
		var last: int = Time.get_ticks_usec()
		for f in range(240):
			await process_frame
			var now: int = Time.get_ticks_usec()
			frames.append(float(now - last) / 1000.0)
			last = now
		var mx: float = 0.0
		var mi: int = 0
		for i in range(frames.size()):
			if float(frames[i]) > mx:
				mx = float(frames[i])
				mi = i
		print("PG FIRST weapon=%s rep=1 max=%.1f ms @frame %d" % [k, mx, mi])
		print("PG MARKEND")


func _do_preload() -> void:
	if OS.get_environment("PG_PRELOAD_FILE") == "":
		return
	var held: Array = []
	var t_pl: int = Time.get_ticks_usec()
	for pth0 in FileAccess.get_file_as_string(OS.get_environment("PG_PRELOAD_FILE")).split("
", false):
		var pth: String = pth0.strip_edges()
		if pth != "" and ResourceLoader.exists(pth):
			held.append(load(pth))
	set_meta("held_resources_%d" % Time.get_ticks_usec(), held)
	print("PG PRELOAD %d kaynak, %.1f ms" % [held.size(), float(Time.get_ticks_usec() - t_pl) / 1000.0])


## Yağmur görünümü karşılaştırması: aynı sahnede yağmur açık/kapalı iki yakalama (oyun duraklatılmış), fark = yağmur pikselleri.
func _rain_shot() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	_enemy_target = 0
	_walk = false
	await _clear_weapons()
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	var atmo: Node = get_first_node_in_group("atmosphere")
	var rain: Node = atmo.get_node_or_null("Rain") if atmo != null else null
	if rain == null:
		print("PG RAIN yok")
		return
	seed(1234)
	await _wait(float(_env_int("PG_SETTLE", 16)))
	var tag: String = OS.get_environment("PG_TAG") if OS.get_environment("PG_TAG") != "" else "x"
	var outdir: String = OS.get_environment("PG_SHOTDIR") if OS.get_environment("PG_SHOTDIR") != "" else "."
	for n in range(int(_env_int("PG_SHOTS", 2))):
		await _wait(0.7)
		paused = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var a: Image = root.get_texture().get_image()
		rain.visible = false
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var b: Image = root.get_texture().get_image()
		rain.visible = true
		paused = false
		var w: int = a.get_width()
		var h: int = a.get_height()
		var mask := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var cnt: int = 0
		for y in range(h):
			for x in range(w):
				var pa: Color = a.get_pixel(x, y)
				var pb: Color = b.get_pixel(x, y)
				var d: float = maxf(absf(pa.r - pb.r), maxf(absf(pa.g - pb.g), absf(pa.b - pb.b)))
				if d > 0.03:
					cnt += 1
					mask.set_pixel(x, y, Color(1, 1, 1, 1))
				else:
					mask.set_pixel(x, y, Color(0, 0, 0, 1))
		print("PG RAINSHOT %s shot=%d size=%dx%d rain_pixels=%d (%.2f%%) drops=%s" % [tag, n, w, h, cnt, 100.0 * float(cnt) / float(w * h), str(rain.get("_n")) if rain.get("_n") != null else str((rain.get("_ground") as PackedVector2Array).size())])
		a.save_png("%s/rain_%s_%d_on.png" % [outdir, tag, n])
		mask.save_png("%s/rain_%s_%d_mask.png" % [outdir, tag, n])
		## yakın plan: ekranın ortasından 240x135 piksel, 4 kat büyütülmüş (piksel şekillerini görmek için)
		var cx: int = w / 2
		var cy: int = h / 2
		var crop: Image = a.get_region(Rect2i(cx - 120, cy - 68, 240, 136))
		crop.resize(960, 544, Image.INTERPOLATE_NEAREST)
		crop.save_png("%s/rain_%s_%d_zoom.png" % [outdir, tag, n])


## Alan hasarı adaylarını bulma: ESKİ (tüm "enemies" grubunu GDScript'te tara) <-> YENİ (EnemyQuery.candidates + aynı süzgeç). Aynı küme + süre.
func _micro_splash() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	_enemy_target = 0
	_walk = false
	await _clear_weapons()
	_spawn_crowd(_n)
	await _wait(float(_env_int("PG_SETTLE", 14)))
	var eq: GDScript = load("res://scripts/enemy_world/enemy_query.gd")
	var pp: Vector2 = _player.global_position
	var radius: float = 79.2
	var centers: Array = []
	for i in range(8):
		centers.append(pp + Vector2(randf_range(-120, 120), randf_range(-120, 120)))
	var old_hits: Array = []
	var new_hits: Array = []
	var old_fn := func(c: Vector2) -> Array:
		var out: Array = []
		for e in get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.get("is_dead") == true:
				continue
			if not e.has_method("take_damage"):
				continue
			if c.distance_to(e.global_position) <= radius:
				out.append(e)
		return out
	var new_fn := func(c: Vector2) -> Array:
		var out: Array = []
		for e in eq.call("candidates", self, c, radius):
			if not is_instance_valid(e) or e.get("is_dead") == true:
				continue
			if not e.has_method("take_damage"):
				continue
			if c.distance_to(e.global_position) <= radius:
				out.append(e)
		return out
	var same: int = 0
	var total: int = 0
	for c in centers:
		var a: Array = old_fn.call(c)
		var b: Array = new_fn.call(c)
		total += a.size()
		var bs: Dictionary = {}
		for e in b:
			bs[e] = true
		var ok: bool = a.size() == b.size()
		for e in a:
			if not bs.has(e):
				ok = false
		if ok:
			same += 1
	print("PG SPLASH ayni kume: %d / %d merkez (ortalama %.1f hedef)" % [same, centers.size(), float(total) / centers.size()])
	var cand0: Array = eq.call("candidates", self, centers[0], radius)
	print("PG SPLASH candidates(r=%.1f)=%d  group=%d" % [radius, cand0.size(), get_nodes_in_group("enemies").size()])
	_pr("query only: candidates", _t_us(func() -> void: eq.call("candidates", self, centers[0], radius), 40))
	_pr("group fetch only: get_nodes_in_group", _t_us(func() -> void: get_nodes_in_group("enemies"), 40))
	_pr("old: group scan x%d enemies" % get_nodes_in_group("enemies").size(), _t_us(func() -> void: old_fn.call(centers[0]), 40))
	_pr("new: EnemyQuery.candidates", _t_us(func() -> void: new_fn.call(centers[0]), 40))


func _prof_fog() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(true)
	_enemy_target = _n
	_walk = true
	await _wait(float(_env_int("PG_SETTLE", 25)))
	var fog: Node = get_first_node_in_group("vision_fog")
	var groups: Dictionary = {}
	for g in ["enemies", "enemy_projectiles", "xp_orbs", "gold_drops", "food_drops", "chest_drops", "magnet_drops", "shield_orb_drops"]:
		groups[g] = get_nodes_in_group(g).size()
	print("PG FOG group sizes: ", str(groups))
	_pr("fog.update_fog (tum)", _t_us(func() -> void: fog.call("update_fog", 0.016), 40))
	_pr("fog._apply_enemy_visibility(true)", _t_us(func() -> void: fog.call("_apply_enemy_visibility", true, 0.016), 40))
	_pr("fog._collect_source_positions", _t_us(func() -> void: fog.call("_collect_source_positions"), 40))
	_pr("fog._push_mask_uniforms", _t_us(func() -> void: fog.call("_push_mask_uniforms", 0.016), 40))
	_pr("fog._ensure_occluders", _t_us(func() -> void: fog.call("_ensure_occluders"), 40))
	_pr("fog._atmosphere_vision_multiplier", _t_us(func() -> void: fog.call("_atmosphere_vision_multiplier"), 40))
	_pr("fog._local_player_indoors", _t_us(func() -> void: fog.call("_local_player_indoors"), 40))
	for g in ["enemy_projectiles", "xp_orbs", "gold_drops"]:
		_pr("get_nodes_in_group(%s) x%d" % [g, int(groups[g])], _t_us(func() -> void: get_nodes_in_group(g), 40))


func _cap() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _region_diff(a: Image, b: Image, r: Rect2i) -> int:
	var n: int = 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var pa: Color = a.get_pixel(x, y)
			var pb: Color = b.get_pixel(x, y)
			if maxf(absf(pa.r - pb.r), maxf(absf(pa.g - pb.g), absf(pa.b - pb.b))) > 0.02:
				n += 1
	return n


func _warm_vis() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(false, false)
	await _wait(10.0)
	var fw: GDScript = load("res://scripts/fx_warmup.gd")
	var names: Array = ["hit_flash", "lightning_yellow", "matthew_fox_shield", "assasin_ghost", "melek_bond", "shield_dome"]
	var region := Rect2i(0, 0, 60, 60) ## köşe (2,2)'deki 3x3 birimlik dörtgen = ~6x6 ekran pikseli
	for layer_val in [100, -100]:
		var out: PackedStringArray = []
		for nm in names:
			var sh: Shader = load("res://shaders/%s.gdshader" % nm) as Shader
			paused = true
			var a: Image = await _cap()
			var a2: Image = await _cap()
			var noise: int = _region_diff(a, a2, region)
			fw.call("_warm_shader", self, sh)
			if fw.get("_layer") != null:
				(fw.get("_layer") as CanvasLayer).layer = layer_val
			var b: Image = await _cap()
			var d: int = _region_diff(a, b, region)
			out.append("%s=%d(noise %d)" % [nm, d, noise])
			paused = false
			await _wait(0.4)
		print("PG WARMVIS layer=%d -> %s" % [layer_val, ", ".join(out)])


## FPS turu 3 (2026-10-18): çizim komutu / render-CPU dökümü - ayrıntı draw_sweep.gd başlığında. Headless'ta yalnız sayım (census) çalışır.
func _draw_sweep() -> void:
	if not await _boot(_char, _loadout[0]):
		print("PG BOOTFAIL")
		return
	await _prepare(true)
	## PG_POS="x,y" (madde 371): oyuncuyu haritanın o HÜCRESİNE ışınla (bölge karşılaştırması: orta bölge / Kuzey / Batı / Doğu / Güney). Harita kökü (-2, 21).
	var pos_env: String = OS.get_environment("PG_POS")
	if pos_env != "":
		var pp: PackedStringArray = pos_env.split(",")
		_player.global_position = Vector2(-2.0, 21.0) + (Vector2(float(pp[0]), float(pp[1])) + Vector2(0.5, 0.5)) * 16.0
	## PG_MASK_OFF=1: bölge maskesi (derin_orman_maske) boş dokuyla değiştirilir -> shader'daki bölge renk ayarı erken çıkışa düşer (hesap maliyeti ayrıştırma)
	if OS.get_environment("PG_MASK_OFF") == "1":
		RenderingServer.global_shader_parameter_set("derin_orman_maske", ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8)))
	## PG_NO_DFX=1: derin orman ruh ışıkları + duyurular kapatılır (DeepForestFx / DeepForestLore); PG_HIDE=zemin,olu,nesne,suslu: bölge katmanları görünmez (madde 371, ayrıştırma A/B)
	if OS.get_environment("PG_NO_DFX") == "1":
		for nm in ["DeepForestFx", "DeepForestLore"]:
			var nd: Node = _main.find_child(nm, true, false)
			if nd:
				nd.queue_free()
	var hide_alias: Dictionary = {"zemin": ["Derin orman zemini"], "olu": ["Ağaç ölü", "Ağaç ölü ön"], "nesne": ["Derin orman nesneleri", "Derin orman nesneleri ön"], "suslu": ["Derin orman süsleri"]}
	for tok in OS.get_environment("PG_HIDE").split(",", false):
		for lname: String in hide_alias.get(tok, []):
			for nd in _main.find_children(lname, "TileMapLayer", true, false):
				(nd as CanvasItem).visible = false
	if OS.get_environment("PG_INDOOR") != "1":
		_enemy_target = _n
		_walk = true
	await _wait(float(_env_int("PG_SETTLE", 25)))
	print("PG MEM static=%.0f MB tex=%.0f MB video=%.0f MB nodes=%d objects=%d" % [Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT))])
	var sweep = load("res://tools/fps_micro/draw_sweep.gd").new()
	await sweep.run(self)
