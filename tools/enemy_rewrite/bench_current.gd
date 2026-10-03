extends SceneTree

## Aşama 0 - BUGÜNKÜ yaratık sisteminin ölçümü (docs/yaratik_yeniden_yazim/PLAN.md §5, §6).
##
##   Godot --headless --path <proje> -s res://tools/enemy_rewrite/bench_current.gd
## NOT (2026-10-03): bu tarihten ÖNCEKİ "yürüyüş" ölçümlerinde oyuncu aslında YÜRÜMÜYORDU (headless'ta Input.action_press etkisiz);
## artık oyuncu doğrudan taşınıyor. Önceki satırlar "oyuncu duruyor" senaryosudur.
## Ortam değişkenleri (hepsi isteğe bağlı):
##   BENCH_N      yaratık sayısı (200)          BENCH_TIER   kademe, roster + ölçekleme (8)
##   BENCH_SECS   aktif ölçüm süresi sn (12)     BENCH_WALK   1 = oyuncu kare çizerek yürür (1)
##   BENCH_CHAR   karakter id (9 = Korsan)
##
## Akış: gerçek menü (ana menü -> karakter seçimi -> Main, tek oyunculu yol) -> silah kartı otomatik -> evden çık ->
## oyuncu ölümsüz, silahları kaldırılır (yaratık ölmesin, seviye ekranı açılmasın), doğal doğurma kapalı -> BENCH_N yaratık
## oyuncunun çevresine (300-900 px halka) doğar, canları çok yüksek -> 2 sn ısınma -> BENCH_SECS sn ölçüm (A: yaratıklar
## aktif) -> 4 sn ölçüm (B: yaratıkların _physics_process'i kapalı) -> fark = yaratık simülasyonu.
##
## Fizik adımı süresi: adımın en BAŞINDA (physics_process_priority en düşük) ve en SONUNDA (en yüksek) çalışan iki prob
## düğümü arasındaki duvar saati - tüm düğümlerin _physics_process'leri + içlerindeki move_and_slide. Performance.TIME_*
## monitörleri bu projede güvenilmez (bkz. PLAN §6).
##
## Çıktı: "BENCH ..." satırları. Son satır makinece okunur:
##   BENCH_RESULT n=<N> tier=<T> walk=<0|1> tick_ms_A=<ort> tick_ms_A_p95=<p95> tick_ms_B=<ort> us_per_creature=<µs>
##                frame_ms_A=<ort> ticks_A=<sayı>

var _n: int = int(OS.get_environment("BENCH_N")) if OS.get_environment("BENCH_N") != "" else 200
var _tier: int = int(OS.get_environment("BENCH_TIER")) if OS.get_environment("BENCH_TIER") != "" else 8
var _secs: float = float(OS.get_environment("BENCH_SECS")) if OS.get_environment("BENCH_SECS") != "" else 12.0
var _walk: bool = OS.get_environment("BENCH_WALK") != "0"
var _char: int = int(OS.get_environment("BENCH_CHAR")) if OS.get_environment("BENCH_CHAR") != "" else 9

var _tick_start_us: int = 0
var _ticks: PackedFloat64Array = PackedFloat64Array()
var _recording: bool = false
var _player: Node2D = null ## yürüyüş: headless'ta Input oyuncuyu yürütmüyor (2026-10-03), doğrudan taşınır
var _bridge: Node = null ## ENEMY_WORLD=1 iken EnemyWorldBridge (Aşama 1+)
var _bridge_step := PackedFloat64Array()
var _bridge_tick := PackedFloat64Array()
var _bridge_view := PackedFloat64Array()


class Probe extends Node:
	var bench: Object
	var is_start: bool = false
	func _physics_process(_d: float) -> void:
		if is_start:
			bench.set("_tick_start_us", Time.get_ticks_usec())
		elif bench.get("_recording"):
			var arr: PackedFloat64Array = bench.get("_ticks")
			arr.append(float(Time.get_ticks_usec() - int(bench.get("_tick_start_us"))) / 1000.0)
			bench.set("_ticks", arr)
			var br: Node = bench.get("_bridge")
			if br != null and is_instance_valid(br):
				var s1: PackedFloat64Array = bench.get("_bridge_step"); s1.append(float(br.get("last_step_ms"))); bench.set("_bridge_step", s1)
				var s2: PackedFloat64Array = bench.get("_bridge_tick"); s2.append(float(br.get("last_tick_ms"))); bench.set("_bridge_tick", s2)
				var s3: PackedFloat64Array = bench.get("_bridge_view"); s3.append(float(br.get("last_view_ms"))); bench.set("_bridge_view", s3)


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float, walk: bool = false) -> void:
	var t0: int = Time.get_ticks_msec()
	var dirs: Array[String] = ["move_right", "move_down", "move_left", "move_up"]
	var cur: String = ""
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false ## silah/seviye ekranları ağacı duraklatabilir (bkz. hafıza: runner'da her karede çöz)
		_hold_spawns()
		if walk and _player != null and is_instance_valid(_player):
			var dv: Vector2 = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][int((Time.get_ticks_msec() - t0) / 2000) % 4]
			var np: Vector2 = _player.global_position + dv * 150.0 * minf(get_root().get_process_delta_time(), 0.1) ## gerçek zaman: FPS'ten bağımsız 150 px/sn
			if not root.get_node("GameManager").call("is_position_blocked_by_forest", np):
				_player.global_position = np
		await process_frame
	if cur != "":
		Input.action_release(cur)


func _hold_spawns() -> void:
	var sp: Node = current_scene.get_node_or_null("EnemySpawner") if current_scene else null
	if sp:
		sp.set("_spawn_timer", 1.0e9)


func _run() -> void:
	await process_frame
	var gm: Node = root.get_node("GameManager")
	gm.set("debug_immortal", true)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _until(func(): return current_scene != null and current_scene.has_method("_on_start_pressed"), 10.0)
	current_scene.call("_on_start_pressed")
	await _until(func(): return current_scene != null and current_scene.has_method("_on_character_pressed"), 10.0)
	current_scene.call("_on_character_pressed", _char)
	current_scene.call("_on_start_pressed")
	await _until(func(): return current_scene != null and current_scene.name == "Main", 30.0)
	await _wait(1.0)
	var ws: Node = _find_by_method(current_scene, "_auto_pick_random_card", "weapon_select")
	if ws:
		ws.call("_auto_pick_random_card")
	await _wait(0.5)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(1.0)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player == null:
		print("BENCH HATA: Player yok"); quit(1); return
	_player = player
	for w in player.get("owned_weapon_nodes") if player.get("owned_weapon_nodes") != null else []:
		if is_instance_valid(w):
			w.queue_free()
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.3)
	var roster: Array = spawner.call("_spawnable_roster", _tier)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in _n:
		var id: String = roster[rng.randi() % roster.size()]
		var ang: float = rng.randf() * TAU
		var pos: Vector2 = player.global_position + Vector2.from_angle(ang) * rng.randf_range(300.0, 900.0)
		var e: Node = spawner.call("_spawn_creature", id, pos, 100000 + i)
		if e == null:
			continue
		e.set_meta("spawn_tier", _tier)
		e.call("apply_tier_scaling", _tier)
		spawner.call("_apply_global_buff", e)
		e.set("max_health", 1.0e12)
		e.set("health", 1.0e12)
	var count: int = get_nodes_in_group("enemies").size()
	await process_frame ## köprü ertelenerek eklenir
	_bridge = current_scene.get_node_or_null("EnemyWorldBridge")
	print("BENCH yaratık: ", count, "  kademe: ", _tier, "  yürüyüş: ", _walk, "  EnemyWorld: ", _bridge != null)
	var a := Probe.new(); a.bench = self; a.is_start = true; a.process_physics_priority = -1000000
	var b := Probe.new(); b.bench = self; b.process_physics_priority = 1000000
	root.add_child(a); root.add_child(b)
	await _wait(2.0, _walk)
	# A: yaratıklar aktif
	_ticks = PackedFloat64Array(); _recording = true
	var f0: int = Time.get_ticks_usec(); var fr0: int = Engine.get_process_frames()
	await _wait(_secs, _walk)
	_recording = false
	var frame_ms_a: float = float(Time.get_ticks_usec() - f0) / 1000.0 / maxf(1.0, float(Engine.get_process_frames() - fr0))
	var ta: PackedFloat64Array = _ticks.duplicate()
	# B: yaratık fiziği kapalı (aynı sahne, aynı oyuncu)
	for e in get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	if _bridge != null:
		_bridge.set_physics_process(false)
	var bstep: float = _avg(_bridge_step); var btick: float = _avg(_bridge_tick); var bview: float = _avg(_bridge_view)
	_bridge_step = PackedFloat64Array(); _bridge_tick = PackedFloat64Array()
	await _wait(0.5, _walk)
	_ticks = PackedFloat64Array(); _recording = true
	await _wait(4.0, _walk)
	_recording = false
	var tb: PackedFloat64Array = _ticks.duplicate()
	var avg_a: float = _avg(ta); var avg_b: float = _avg(tb)
	var us_per: float = (avg_a - avg_b) * 1000.0 / maxf(1.0, float(count))
	print("BENCH A (aktif): tik ort %.2f ms  p95 %.2f ms  (%d tik)   B (yaratık fiziği kapalı): %.2f ms" % [avg_a, _p95(ta), ta.size(), avg_b])
	if bstep > 0.0 or btick > 0.0:
		print("BENCH EnemyWorld köprüsü: C++ adım %.3f ms (konum/kare yazma %.3f)  GDScript olay+tik %.3f ms (%.2f µs/yaratık)" % [bstep, bview, btick, btick * 1000.0 / maxf(1.0, float(count))])
	print("BENCH_RESULT n=%d tier=%d walk=%d tick_ms_A=%.3f tick_ms_A_p95=%.3f tick_ms_B=%.3f us_per_creature=%.2f frame_ms_A=%.3f ticks_A=%d" % [
		count, _tier, 1 if _walk else 0, avg_a, _p95(ta), avg_b, us_per, frame_ms_a, ta.size()])
	quit()


func _avg(a: PackedFloat64Array) -> float:
	if a.is_empty():
		return 0.0
	var s: float = 0.0
	for v in a:
		s += v
	return s / a.size()


func _p95(a: PackedFloat64Array) -> float:
	if a.is_empty():
		return 0.0
	var s: Array = Array(a)
	s.sort()
	return float(s[int(floor(0.95 * (s.size() - 1)))])


func _until(cond: Callable, timeout: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(timeout * 1000.0):
		paused = false
		await process_frame


func _find_by_method(n: Node, method: String, name_hint: String) -> Node:
	if n.has_method(method) and (name_hint == "" or n.name.to_lower().contains(name_hint.replace("_", "")) or String(n.get_script().resource_path).contains(name_hint) if n.get_script() else false):
		return n
	for c in n.get_children():
		var r: Node = _find_by_method(c, method, name_hint)
		if r:
			return r
	return null
