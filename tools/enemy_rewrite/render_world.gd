extends SceneTree

## Aşama 3 - görsel kontrol + sürü çizim ölçümü (PENCERELİ, gerçek GPU; headless'ta shader/GPU ölçülmez - PLAN §6).
##   Godot --path <proje> --windowed --resolution 1920x1080 -s res://tools/enemy_rewrite/render_world.gd
## Ortam: ENEMY_WORLD (1), RENDER_SHOT_DIR (ekran görüntüleri; boşsa alınmaz), RENDER_COUNTS ("500,1000,2000"), RENDER_SECS (6)
## 1) 300 yaratık + boss + elit + yanan/donmuş/zehirli/hasar alan yaratıklar -> ekran görüntüsü (shot_visual.png)
## 2) her RENDER_COUNTS değeri için: ort. FPS, ort. kare ms, GPU ms, fizik adımı ms -> "RENDER n=.. fps=.. ..." satırı
##    (+ shot_<n>.png). Oyuncu kare çizerek dolaşır, yaratık canları çok yüksek (sayı sabit), silahlar kapalı.

var _shot_dir: String = OS.get_environment("RENDER_SHOT_DIR")
var _counts: PackedStringArray = (OS.get_environment("RENDER_COUNTS") if OS.get_environment("RENDER_COUNTS") != "" else "500,1000,2000").split(",")
var _secs: float = float(OS.get_environment("RENDER_SECS")) if OS.get_environment("RENDER_SECS") != "" else 6.0
var _player: Node2D
var _spawner: Node
var _gm: Node
var _tick_start_us: int = 0
var _ticks := PackedFloat64Array()
var _next_id: int = 700000


class Probe extends Node:
	var owner_script: Object
	var is_start: bool = false
	func _physics_process(_d: float) -> void:
		if is_start:
			owner_script.set("_tick_start_us", Time.get_ticks_usec())
		else:
			var arr: PackedFloat64Array = owner_script.get("_ticks")
			arr.append(float(Time.get_ticks_usec() - int(owner_script.get("_tick_start_us"))) / 1000.0)
			owner_script.set("_ticks", arr)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_gm = root.get_node("GameManager")
	_gm.set("debug_immortal", true)
	root.get_node("UISound").set("show_fps", true)
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
	_spawner = current_scene.get_node_or_null("EnemySpawner")
	## silahları SİLME (silah yoksa oyun seçim ekranını yeniden açıyor) - sustur
	if OS.get_environment("RENDER_WEAPONS") == "1": ## gerçekçi: silahlar açık (tüfek + yay + tabanca eklenir)
		for k in ["tufek", "yay", "tabanca"]:
			_player.call("buy_weapon_copy", k, 3)
	for w in (_player.get("owned_weapon_nodes") if OS.get_environment("RENDER_WEAPONS") != "1" else []):
		if is_instance_valid(w):
			w.set_process(false)
			w.set_physics_process(false)
			w.visible = false
	var pa := Probe.new(); pa.owner_script = self; pa.is_start = true; pa.process_physics_priority = -1000000
	var pb := Probe.new(); pb.owner_script = self; pb.process_physics_priority = 1000000
	root.add_child(pa); root.add_child(pb)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)

	## 1) görsel kontrol
	_clear()
	await _wait(0.3, false)
	var es: Array = _spawn_ring(300, 6, 200.0, 650.0)
	_spawner.call("_spawn_boss_group", ["golem1"], 6)
	var elite: Node = _spawn("ork1", 6, _player.global_position + Vector2(-140, -60))
	elite.call("make_elite")
	await _wait(2.0, false)
	for i in range(0, 40):
		var e: Node = es[i]
		match i % 4:
			0: e.call("apply_burn", 1.0, 30.0)
			1: e.call("apply_freeze_full", 30.0)
			2: e.call("apply_poison", 1.0, 5.0, 30.0)
			3: e.call("take_damage", 1.0, false, 0.0)
	await _wait(1.5, false)
	await _shot("shot_visual.png")
	print("RENDER görsel: yaratık %d, köprü %s" % [get_nodes_in_group("enemies").size(),
			str(current_scene.get_node_or_null("EnemyWorldBridge") != null)])

	## 2) sürü ölçümü
	for cs in _counts:
		var n: int = int(cs)
		_clear()
		await _wait(0.5, false)
		_spawn_ring(n, 6, 150.0, 900.0)
		await _wait(2.0, true)
		_ticks = PackedFloat64Array()
		var f0: int = Engine.get_process_frames()
		var t0: int = Time.get_ticks_usec()
		var gpu_sum: float = 0.0
		var gpu_n: int = 0
		var t_end: int = Time.get_ticks_msec() + int(_secs * 1000.0)
		while Time.get_ticks_msec() < t_end:
			await _wait(0.0, true)
			gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			gpu_n += 1
		var frames: int = Engine.get_process_frames() - f0
		var secs: float = float(Time.get_ticks_usec() - t0) / 1.0e6
		var tick: float = 0.0
		for v in _ticks:
			tick += v
		tick /= maxf(1.0, float(_ticks.size()))
		print("RENDER n=%d fps=%.0f kare_ms=%.2f gpu_ms=%.2f fizik_adimi_ms=%.2f" % [get_nodes_in_group("enemies").size(),
				float(frames) / secs, secs * 1000.0 / maxf(1.0, float(frames)), gpu_sum / maxf(1.0, float(gpu_n)), tick])
		await _shot("shot_%d.png" % n)
		if OS.get_environment("RENDER_TOGGLES") == "1" and n == (int(OS.get_environment("RENDER_TOGGLES_N")) if OS.get_environment("RENDER_TOGGLES_N") != "" else 1000):
			await _toggles()
		if OS.get_environment("RENDER_PROFILE") == "1":
			await _profile_calls()
	quit()


## Şüpheli kare-başı fonksiyonları DOĞRUDAN çağırıp süresini ölç (çağrı başına ms, 20 çağrı ortalaması).
func _profile_calls() -> void:
	var fog: Node = _find_by_script(current_scene, "vision_fog.gd")
	var mm: Node = _find_by_script(root, "minimap.gd")
	var calls: Dictionary = {
		"main._update_creature_draw_order (çift kare)": func(): if Engine.get_process_frames() % 2 == 0: current_scene.call("_update_creature_draw_order"),
		"sis._apply_enemy_visibility": func(): if fog: fog.call("_apply_enemy_visibility", true, 0.016),
		"minimap tarama (_process, 0.2sn'de bir)": func(): if mm: mm.set("_enemy_refresh_timer", 1.0); mm.call("_process", 0.016),
	}
	await process_frame
	if Engine.get_process_frames() % 2 != 0:
		await process_frame ## y-sıralaması çift karelerde çalışır
	for k in calls:
		var c: Callable = calls[k]
		var t0: int = Time.get_ticks_usec()
		for i in 20:
			Engine.set_meta("_dummy", i) ## kare sayacı değişmez; y-sıralaması 2 karede bir kuralını aşmak için aşağıda ayrıca
			c.call()
		print("RENDER profil %s: %.3f ms/çağrı" % [k, float(Time.get_ticks_usec() - t0) / 1000.0 / 20.0])


## 1000 yaratıkta şüpheli kare-başı sistemleri tek tek kapatıp kare süresini ölç (hangisi ne kadar yiyor).
func _toggles() -> void:
	var cands: Dictionary = {"main.gd (y-sıralama vb.)": current_scene, "görüş sisi": _find_by_script(current_scene, "vision_fog.gd"),
			"minimap": _find_by_script(root, "minimap.gd")}
	print("RENDER kapatma_taban kare_ms=%.2f" % await _measure(3.0))
	for k in cands:
		var node: Node = cands[k]
		if node == null:
			print("RENDER kapatma %s: düğüm yok" % k); continue
		node.set_process(false)
		var ms: float = await _measure(3.0)
		node.set_process(true)
		print("RENDER kapatma %s: kare_ms=%.2f" % [k, ms])
	## yaratık başına canvas item sayısı + çizim tarafının payı
	var ci_total: int = 0
	var es: Array = get_nodes_in_group("enemies")
	for e in es:
		ci_total += _count_canvas_items(e)
	print("RENDER canvas_item yaratık_başına=%.2f toplam=%d" % [float(ci_total) / maxf(1.0, float(es.size())), ci_total])
	var hidden: Array = []
	for e in es:
		for c in e.get_children():
			if (c is CollisionShape2D or c is Area2D) and (c as CanvasItem).visible:
				(c as CanvasItem).visible = false
				hidden.append(c)
	print("RENDER deney çarpışma_düğümleri_gizli kare_ms=%.2f" % await _measure(3.0))
	for c in hidden:
		if is_instance_valid(c):
			(c as CanvasItem).visible = true
	var sprites: Array = []
	for e in es:
		for c in e.get_children():
			if (c is Sprite2D or c is AnimatedSprite2D) and (c as CanvasItem).visible:
				(c as CanvasItem).visible = false
				sprites.append(c)
	print("RENDER deney sprite_gizli kare_ms=%.2f" % await _measure(3.0))
	for c in sprites:
		if is_instance_valid(c):
			(c as CanvasItem).visible = true


func _count_canvas_items(n: Node) -> int:
	var c: int = 1 if n is CanvasItem else 0
	for ch in n.get_children():
		c += _count_canvas_items(ch)
	return c


func _measure(sec: float) -> float:
	await _wait(0.5, true)
	var f0: int = Engine.get_process_frames()
	var t0: int = Time.get_ticks_usec()
	await _wait(sec, true)
	return float(Time.get_ticks_usec() - t0) / 1000.0 / maxf(1.0, float(Engine.get_process_frames() - f0))


func _find_by_script(n: Node, file: String) -> Node:
	if n.get_script() != null and String(n.get_script().resource_path).ends_with(file):
		return n
	for c in n.get_children():
		var r: Node = _find_by_script(c, file)
		if r:
			return r
	return null


func _spawn_ring(n: int, tier: int, rmin: float, rmax: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var roster: Array = _spawner.call("_spawnable_roster", tier)
	var out: Array = []
	var guard: int = 0
	while out.size() < n and guard < n * 6:
		guard += 1
		var pos: Vector2 = _player.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(rmin, rmax)
		if _gm.call("is_position_blocked_by_forest", pos):
			continue
		var e: Node = _spawn(roster[rng.randi() % roster.size()], tier, pos)
		e.set("max_health", 1.0e12)
		e.set("health", 1.0e12)
		out.append(e)
	return out


func _spawn(id: String, tier: int, pos: Vector2) -> Node:
	_next_id += 1
	var e: Node = _spawner.call("_spawn_creature", id, pos, _next_id)
	e.set_meta("spawn_tier", tier)
	e.call("apply_tier_scaling", tier)
	_spawner.call("_apply_global_buff", e)
	return e


func _clear() -> void:
	for e in get_nodes_in_group("enemies"):
		e.queue_free()


func _shot(name: String) -> void:
	if _shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_shot_dir.path_join(name))


func _wait(sec: float, walk: bool) -> void:
	var t0: int = Time.get_ticks_msec()
	while true:
		paused = false
		var sp: Node = current_scene.get_node_or_null("EnemySpawner") if current_scene else null
		if sp:
			sp.set("_spawn_timer", 1.0e9)
		if walk and _player != null:
			var dv: Vector2 = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][int(Time.get_ticks_msec() / 2500) % 4]
			var np: Vector2 = _player.global_position + dv * 2.0
			if not _gm.call("is_position_blocked_by_forest", np):
				_player.global_position = np
		await process_frame
		if Time.get_ticks_msec() - t0 >= int(sec * 1000.0):
			break


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
