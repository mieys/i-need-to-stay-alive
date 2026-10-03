extends SceneTree

## Yaratık yeniden yazımı - GÖRSEL gösterim (pencereli, kullanıcı izler). Gerçek menü akışı -> Main (Korsan), oyuncu
## ölümsüz, silahları açık; DEMO_N yaratık (kademe DEMO_TIER, canları çok yüksek ki sayı sabit kalsın) oyuncunun etrafında.
## Önce DEMO_SECS sn ESKİ yol (enemy.gd), sonra yaratıklar silinip aynı yerlere yeniden doğar ve DEMO_SECS sn YENİ yol
## (C++ EnemyWorld). Üstteki etiket: hangi yol, yaratık sayısı, FPS, fizik adımı (ms). Oyuncu kare çizerek dolaşır.
##   Godot --path <proje> --windowed --resolution 1600x900 -s res://tools/enemy_rewrite/demo_world.gd
## Ortam: DEMO_N (300), DEMO_TIER (6), DEMO_SECS (25)

var _n: int = int(OS.get_environment("DEMO_N")) if OS.get_environment("DEMO_N") != "" else 300
var _tier: int = int(OS.get_environment("DEMO_TIER")) if OS.get_environment("DEMO_TIER") != "" else 6
var _secs: float = float(OS.get_environment("DEMO_SECS")) if OS.get_environment("DEMO_SECS") != "" else 25.0

var _tick_start_us: int = 0
var _ticks := PackedFloat64Array()
var _label: Label
var _mode_text: String = ""
var _player: Node2D
var _results: Array = []


class Probe extends Node:
	var demo: Object
	var is_start: bool = false
	func _physics_process(_d: float) -> void:
		if is_start:
			demo.set("_tick_start_us", Time.get_ticks_usec())
		else:
			var arr: PackedFloat64Array = demo.get("_ticks")
			arr.append(float(Time.get_ticks_usec() - int(demo.get("_tick_start_us"))) / 1000.0)
			demo.set("_ticks", arr)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.get_node("GameManager").set("debug_immortal", true)
	root.get_node("UISound").set("show_fps", true) ## sadece bu çalıştırma (ayar dosyasına yazılmaz)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _until(func(): return current_scene != null and current_scene.has_method("_on_start_pressed"), 10.0)
	current_scene.call("_on_start_pressed")
	await _until(func(): return current_scene != null and current_scene.has_method("_on_character_pressed"), 10.0)
	current_scene.call("_on_character_pressed", 9)
	current_scene.call("_on_start_pressed")
	await _until(func(): return current_scene != null and current_scene.name == "Main", 30.0)
	await _wait(1.0, false)
	var ws: Node = _find_by_method(current_scene, "_auto_pick_random_card")
	if ws:
		ws.call("_auto_pick_random_card")
	await _wait(0.5, false)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(1.0, false)
	_player = current_scene.get_node_or_null("Player") as Node2D
	for k in ["tufek", "yay"]:
		_player.call("buy_weapon_copy", k, 3)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	_label = Label.new()
	_label.position = Vector2(20, 60)
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(1, 1, 0.4))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(_label)
	var pa := Probe.new(); pa.demo = self; pa.is_start = true; pa.process_physics_priority = -1000000
	var pb := Probe.new(); pb.demo = self; pb.process_physics_priority = 1000000
	root.add_child(pa); root.add_child(pb)
	var cfg: GDScript = load("res://scripts/enemy_world/enemy_world_config.gd")
	for phase in [false, true]:
		cfg.call("set_enabled_for_tests", phase)
		_mode_text = "YENİ yol: C++ EnemyWorld" if phase else "ESKİ yol: enemy.gd"
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		await _wait(0.5, false)
		_spawn()
		await _wait(2.0, true) ## ısınma
		_ticks = PackedFloat64Array()
		var f0: int = Engine.get_process_frames()
		var t0: int = Time.get_ticks_msec()
		await _wait(_secs, true)
		var fps: float = float(Engine.get_process_frames() - f0) / (float(Time.get_ticks_msec() - t0) / 1000.0)
		_results.append("%s: ort. FPS %.0f, fizik adımı %.2f ms" % [_mode_text, fps, _avg(_ticks)])
		print("DEMO ", _results[-1])
	_mode_text = "BİTTİ - " + " | ".join(_results)
	_label.text = _mode_text.replace(" | ", "\n")
	await _wait(8.0, false)
	quit()


func _spawn() -> void:
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	var roster: Array = spawner.call("_spawnable_roster", _tier)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var gm: Node = root.get_node("GameManager")
	var placed: int = 0
	var guard: int = 0
	while placed < _n and guard < _n * 5:
		guard += 1
		var pos: Vector2 = _player.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(250.0, 800.0)
		if gm.call("is_position_blocked_by_forest", pos):
			continue
		var e: Node = spawner.call("_spawn_creature", roster[rng.randi() % roster.size()], pos, 300000 + placed)
		if e == null:
			continue
		e.set_meta("spawn_tier", _tier)
		e.call("apply_tier_scaling", _tier)
		spawner.call("_apply_global_buff", e)
		e.set("max_health", 1.0e12)
		e.set("health", 1.0e12)
		placed += 1


func _wait(sec: float, walk: bool) -> void:
	var t0: int = Time.get_ticks_msec()
	var last_label: int = 0
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		var sp: Node = current_scene.get_node_or_null("EnemySpawner") if current_scene else null
		if sp:
			sp.set("_spawn_timer", 1.0e9)
		if walk and _player != null:
			var dv: Vector2 = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][int((Time.get_ticks_msec() - t0) / 2500) % 4]
			var np: Vector2 = _player.global_position + dv * 2.0
			if not root.get_node("GameManager").call("is_position_blocked_by_forest", np):
				_player.global_position = np
		if _label != null and _mode_text != "" and Time.get_ticks_msec() - last_label > 250:
			last_label = Time.get_ticks_msec()
			var recent: float = _avg(_ticks.slice(maxi(0, _ticks.size() - 30)))
			_label.text = "%s\nyaratık: %d   FPS: %d   fizik adımı: %.1f ms" % [_mode_text,
					get_nodes_in_group("enemies").size(), Engine.get_frames_per_second(), recent]
		await process_frame


func _avg(a: PackedFloat64Array) -> float:
	if a.is_empty():
		return 0.0
	var s: float = 0.0
	for v in a:
		s += v
	return s / a.size()


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
