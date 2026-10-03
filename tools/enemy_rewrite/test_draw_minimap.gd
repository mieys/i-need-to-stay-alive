extends SceneTree

## Aşama 3 - C++ çizim sırası (main.gd _update_creature_draw_order_ew -> EnemyWorld.draw_order) ve minimap noktaları
## (minimap.gd _draw -> EnemyWorld.minimap_points) eski GDScript kurallarıyla aynı mı (yeni yol, gerçek oyun, headless).
##   powershell -File tools/enemy_rewrite/run_godot.ps1 -Script res://tools/enemy_rewrite/test_draw_minimap.gd -Env "ENEMY_WORLD=1"
## Ortam: DRAW_N (600) yaratık oyuncunun çevresinde (toplanırlar), boss + elit + 15 ölmekte olan.
## Kontroller ("DRAW ..." satırları, sonda "DRAW_RESULT PASS|FAIL"):
##  1) çizim sırası: C++'ın sıraladığı düğüm kümesi = eski kuralın kümesi (Main'in çocuğu + görünür, 3 grup); ayak y'leri
##     (main.gd _creature_foot_y ile ölçülür) sıra boyunca azalmıyor; verilen draw index'ler = o düğümlerin ağaç indeksleri
##     kümesi, sıra boyunca artan. 5 farklı anda.
##  2) minimap: C++ noktaları = eski kuralın (ölü değil, boss değil, is_ability_invisible değil, sis >= 0,5, |ofset| <= 76)
##     yuvarlanmış harita pikseli kümesi; 5 farklı anda.
##  3) süre: draw_order yolu (GDScript ekstralar dahil) ve minimap_points çağrı başına ms.

var _gm: Node
var _player: Node2D
var _spawner: Node
var _next_id: int = 800000
var _fail: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_gm = root.get_node("GameManager")
	_gm.set("debug_immortal", true)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _until(func(): return current_scene != null and current_scene.has_method("_on_start_pressed"), 10.0)
	current_scene.call("_on_start_pressed")
	await _until(func(): return current_scene != null and current_scene.has_method("_on_character_pressed"), 10.0)
	current_scene.call("_on_character_pressed", 9)
	current_scene.call("_on_start_pressed")
	await _until(func(): return current_scene != null and current_scene.name == "Main", 30.0)
	await _wait(1.0)
	var ws: Node = _find_by_method(current_scene, "_auto_pick_random_card")
	if ws:
		ws.call("_auto_pick_random_card")
	await _wait(0.5)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(1.0)
	_player = current_scene.get_node_or_null("Player") as Node2D
	_spawner = current_scene.get_node_or_null("EnemySpawner")
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.3)
	var bridge_script: GDScript = load("res://scripts/enemy_world/enemy_world_bridge.gd")
	seed(777)
	var n: int = int(OS.get_environment("DRAW_N")) if OS.get_environment("DRAW_N") != "" else 600
	var roster: Array = _spawner.call("_spawnable_roster", 6)
	for i in n:
		var pos: Vector2 = _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(120.0, 900.0)
		if _gm.call("is_position_blocked_by_forest", pos):
			continue
		var e: Node = _spawn(roster[i % roster.size()], 6, pos)
		e.set("max_health", 1.0e12); e.set("health", 1.0e12)
	_spawner.call("_spawn_boss_group", ["golem1"], 6)
	var el: Node = _spawn("ork1", 6, _player.global_position + Vector2(-200, 80))
	el.call("make_elite")
	await _wait(2.0)
	var killed: int = 0
	for e in get_nodes_in_group("enemies"):
		if killed >= 15 or e.is_in_group("boss"):
			continue
		e.set("health", 1.0)
		e.call("take_damage", 1.0e9)
		killed += 1
	await _wait(0.05)
	var ew: Object = bridge_script.call("fog_world", self)
	print("DRAW yol: ", "YENİ" if ew != null else "ESKİ (bu test yeni yolu ister)")
	if ew == null:
		print("DRAW_RESULT FAIL (yeni yol yok)")
		quit()
		return
	var main: Node = current_scene
	var mm: Node = _find_by_script(root, "minimap.gd")
	for round_i in 5:
		await _wait(0.4)
		_check_draw(main, ew, round_i)
		_check_minimap(ew, mm, round_i)
	## süre
	var t0: int = Time.get_ticks_usec()
	for k in 20:
		main.call("_update_creature_draw_order_ew", ew)
	var t1: int = Time.get_ticks_usec()
	for k in 20:
		ew.call("minimap_points", mm.get("_view_center") if mm else _player.global_position, 16.0, 76.0, 0.5)
	var t2: int = Time.get_ticks_usec()
	print("DRAW sure yaratik=%d draw_order=%.3f ms/cagri minimap_points=%.3f ms/cagri" % [get_nodes_in_group("enemies").size(),
			float(t1 - t0) / 20000.0, float(t2 - t1) / 20000.0])
	print("DRAW_RESULT ", "PASS" if _fail == 0 else "FAIL (%d)" % _fail)
	quit()


func _check_draw(main: Node, ew: Object, round_i: int) -> void:
	main.call("_update_creature_draw_order_ew", ew)
	var order: Array = ew.call("get_last_draw_order")
	## eski kuralın kümesi
	var ref: Dictionary = {}
	for g in ["enemies", "player_ally", "player_allies"]:
		for nd in get_nodes_in_group(g):
			var n2 := nd as Node2D
			if n2 != null and n2.get_parent() == main and n2.visible:
				ref[n2] = true
	var got: Dictionary = {}
	var bad_order: int = 0
	var bad_idx: int = 0
	var prev_y: float = -INF
	var prev_idx: int = -1
	var idxs: Array = []
	for pair in order:
		var nd: Node2D = pair[0]
		got[nd] = true
		var fy: float = float(main.call("_creature_foot_y", nd))
		if fy < prev_y - 0.01:
			bad_order += 1
		prev_y = fy
		if int(pair[1]) <= prev_idx:
			bad_idx += 1
		prev_idx = int(pair[1])
		idxs.append(nd.get_index(true))
	idxs.sort()
	var given: Array = order.map(func(p): return int(p[1]))
	var same_set: bool = got.size() == ref.size() and ref.keys().all(func(k): return got.has(k))
	var idx_set_ok: bool = idxs == given
	print("DRAW sira tur=%d dugum=%d eski_kume=%d ayni_kume=%s ayak_sirasi_bozuk=%d indeks_kumesi=%s indeks_artmayan=%d" % [
			round_i, got.size(), ref.size(), str(same_set), bad_order, str(idx_set_ok), bad_idx])
	if not same_set or bad_order > 0 or not idx_set_ok or bad_idx > 0:
		_fail += 1


func _check_minimap(ew: Object, mm: Node, round_i: int) -> void:
	var center: Vector2 = mm.get("_view_center") if mm else _player.global_position
	var pts: PackedVector2Array = ew.call("minimap_points", center, 16.0, 76.0, 0.5)
	var got: Dictionary = {}
	for p in pts:
		got[Vector2i(p)] = true
	var ref: Dictionary = {}
	for e in get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true or e.get("is_ability_invisible") == true:
			continue
		if e.get("is_boss") == true or int(e.get("_ew_slot")) < 0:
			continue
		if float(e.get_meta("vision_fog_vis", 1.0)) < 0.5:
			continue
		var off: Vector2 = ((e as Node2D).global_position - center) / 16.0
		if off.length() > 76.0:
			continue
		ref[Vector2i(off.round())] = true
	var same: bool = got.size() == ref.size() and ref.keys().all(func(k): return got.has(k))
	print("DRAW minimap tur=%d nokta=%d eski=%d ayni=%s" % [round_i, got.size(), ref.size(), str(same)])
	if not same:
		_fail += 1


func _spawn(id: String, tier: int, pos: Vector2) -> Node:
	_next_id += 1
	var e: Node = _spawner.call("_spawn_creature", id, pos, _next_id)
	e.set_meta("spawn_tier", tier)
	e.call("apply_tier_scaling", tier)
	_spawner.call("_apply_global_buff", e)
	return e


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		var sp: Node = current_scene.get_node_or_null("EnemySpawner") if current_scene else null
		if sp:
			sp.set("_spawn_timer", 1.0e9)
		await process_frame


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


func _find_by_script(n: Node, file: String) -> Node:
	if n.get_script() != null and String(n.get_script().resource_path).ends_with(file):
		return n
	for c in n.get_children():
		var r: Node = _find_by_script(c, file)
		if r:
			return r
	return null
