extends SceneTree
## YENİ GÖREVLER gerçek çizici görüntüsü (madde 496): Yuvaları Kapat / Ritüeli Boz / Kaçan Hazine / Gezici Işık, oyuncunun yanında birer kare.
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/gorev_goruntu/run.ps1 [-Harita batik_nekropol]  -> tools/gorev_goruntu/out/*.png
## Gizli masaüstünde (tools/fps_micro/hidden_launch.ps1), HARITA + CAP_OUT ortam değişkenleri. Yaratık doğuşu kapalı, ölümsüz.

var _gm: Node = null
var _out: String = OS.get_environment("CAP_OUT")
var _tag: String = OS.get_environment("HARITA") if OS.get_environment("HARITA") != "" else "ana"


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(_out.path_join(_tag + "_" + name + ".png"))
	print("SHOT ", name)


func _end_active(wem: Node) -> void:
	for s: Dictionary in wem.get("_slots"):
		if str(s.get("state", "")) == "active":
			s["timer"] = 0.01


func _run() -> void:
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", 1)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(1).get("skill", 1))
	_gm.set("selected_start_weapon", "sword")
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(5.0)
	var ws: Node = _find_by_method(main, "_auto_pick_random_card")
	if ws:
		ws.call("_auto_pick_random_card")
	var house: Node = main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	var intro: Node = main.get_node_or_null("HouseInterior/HouseIntro")
	if intro and intro.has_method("_set_phase"):
		intro.call("_set_phase", 3, 0.0)
	_gm.set("invasion_pending", false)
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	await _wait(2.0)
	var wem: Node = main.get_node_or_null("WorldEventManager")
	var p: Node2D = main.get_node("Player")
	if wem == null:
		print("SHOT HATA gorev yoneticisi yok")
		quit(1)
		return
	## ana haritada açık bir çayıra; zindanda doğuşta kal
	if _tag == "ana":
		p.global_position += Vector2(0, 260)
		p.reset_physics_interpolation()
		await _wait(1.0)
	var base: Vector2 = p.global_position
	wem.call("debug_force_start_mission", "close_nests", base)
	await _wait(2.5)
	await _shot("yuva")
	_end_active(wem)
	await _wait(2.0)
	wem.call("debug_force_start_mission", "break_ritual", base + Vector2(0, -70))
	await _wait(2.5)
	await _shot("rituel")
	_end_active(wem)
	await _wait(3.5)
	wem.call("debug_force_start_mission", "treasure_runner", base + Vector2(150, 30))
	await _wait(0.3)
	for n: Node in get_nodes_in_group("mission_targets"):
		n.call("apply_stun", 20.0)
	await _wait(1.5)
	await _shot("hazine")
	_end_active(wem)
	await _wait(2.0)
	wem.call("debug_force_start_mission", "wandering_light", base)
	await _wait(2.5)
	await _shot("isik")
	quit(0)


func _find_by_method(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var r: Node = _find_by_method(c, method)
		if r:
			return r
	return null
