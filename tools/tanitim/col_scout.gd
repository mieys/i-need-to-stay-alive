extends SceneTree

## TANITIM SAHNE 1 keşfi (çöl): tek oyunculu Main (HARITA=col), adayların üstünde 1920x1080 kök viewport'tan PNG alır (arayüz gizli).
## Ortam: SC_SPOTS="x,y;x,y", SC_TIMES="150,352", SC_ZOOM=2.4, TN_DIR. Çıktı: <TN_DIR>/scout_<n>_<t>.png

const KEEP_LAYER_SCRIPTS: Array = ["atmosphere_overlay.gd", "vision_fog.gd", "sun_clouds.gd"]

var _dir: String = OS.get_environment("TN_DIR")


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(1920, 1080)
	_run.call_deferred()


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


func _run() -> void:
	await process_frame
	var gm: Node = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	gm.call("reset")
	gm.set("selected_char_id", 4)
	var chars: GDScript = load("res://scripts/characters.gd")
	gm.set("selected_character", chars.get_def(4).get("skill", 1))
	gm.set("debug_immortal", true)
	gm.set("debug_mode_unlocked", true)
	gm.set("run_record_suppressed", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	var mb: int = AudioServer.get_bus_index("Music")
	if mb >= 0:
		AudioServer.set_bus_mute(mb, true)
	t0 = Time.get_ticks_msec()
	while get_first_node_in_group("loading_overlay") != null and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	await _wait(1.0)
	var house: Node = main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	var intro: Node = main.get_node_or_null("HouseInterior/HouseIntro")
	if intro and intro.has_method("_set_phase"):
		intro.call("_set_phase", 3, 0.0)
	gm.set("invasion_pending", false)
	await _wait(1.5)
	var player: Node2D = main.get_node_or_null("Player") as Node2D
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	var zoom: float = float(OS.get_environment("SC_ZOOM")) if OS.get_environment("SC_ZOOM") != "" else 2.4
	var spots: PackedStringArray = OS.get_environment("SC_SPOTS").split(";")
	var times: PackedStringArray = OS.get_environment("SC_TIMES").split(",")
	var n: int = 0
	for s in spots:
		var xy: PackedStringArray = s.split(",")
		if xy.size() < 2:
			continue
		for tt in times:
			player.global_position = Vector2(float(xy[0]), float(xy[1]))
			var atmo: Node = get_first_node_in_group("atmosphere")
			if atmo:
				atmo.call("debug_set_time", float(tt))
				atmo.call("debug_set_weather", 0)
			_hide_ui()
			if cam:
				cam.zoom = Vector2(zoom, zoom)
				cam.drag_horizontal_enabled = false
				cam.drag_vertical_enabled = false
				cam.reset_smoothing()
			await _wait(2.0)
			_hide_ui()
			await _wait(0.5)
			var img: Image = root.get_texture().get_image()
			var path: String = _dir.path_join("scout_%d_%s.png" % [n, tt])
			img.save_png(path)
			print("SCOUT %s %dx%d" % [path, img.get_width(), img.get_height()])
		n += 1
	print("SCOUT bitti")
	quit()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame
