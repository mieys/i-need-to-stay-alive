extends SceneTree
## ATEŞ BÖCEĞİ GECE ÇEKİMİ (madde 761): ana haritada gece yarısı + açık hava, oyuncuyu verilen DÜNYA px ayak noktalarına koyar, gerçek çiziciyle
## görüntü alıp oyuncu çevresinden GEN x YUK px kırpar -> <CAP_OUT>/<ad>.png. Gizli masaüstünde koşar: tools/ates_bocegi/gece_cekim.ps1.
## CAP_NOKTALAR="ad:x,y;ad2:x,y". CAP_SAAT gün saati (varsayılan 450 = gece yarısı). tools/harita_cila/y_cekim.gd'den.

const GEN := 960
const YUK := 540


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _run() -> void:
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", 1)
	var chars: GDScript = load("res://scripts/characters.gd")
	gm.set("selected_character", chars.get_def(1).get("skill", 1))
	gm.set("selected_start_weapon", "sword")
	gm.set("debug_immortal", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	gm.set("run_record_suppressed", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(5.0)
	var atmo: Node = main.get_node_or_null("Atmosphere")
	if atmo:
		atmo.call("debug_set_weather", 0)
		atmo.set("cycle_time", float(OS.get_environment("CAP_SAAT")) if OS.get_environment("CAP_SAAT") != "" else 450.0)
	var sp: Node = main.get_node_or_null("EnemySpawner")
	if sp:
		sp.process_mode = Node.PROCESS_MODE_DISABLED
	var ff: Node = main.get_node_or_null("AtesBocekleri")
	print("ATESBOCEK dugum=", ff != null, " sira=", ff.get_index() if ff else -1, " sis=", main.get_node("VisionFog").get_index())
	var feet_ofs: float = float((load("res://scripts/depth_occluders.gd") as GDScript).get("FEET_OFFSET"))
	var p: Node2D = main.get_node("Player")
	var out: String = OS.get_environment("CAP_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	for item: String in OS.get_environment("CAP_NOKTALAR").split(";", false):
		var kv: PackedStringArray = item.split(":")
		var xy: PackedStringArray = kv[1].split(",")
		for e: Node in get_nodes_in_group(&"enemies"):
			(e as Node).queue_free()
		p.global_position = Vector2(float(xy[0]), float(xy[1]) - feet_ofs)
		p.reset_physics_interpolation()
		await _wait(3.0)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var sc: Vector2 = root.get_canvas_transform() * p.global_position
		var ratio: float = float(img.get_width()) / float(root.get_visible_rect().size.x)
		var c := Vector2i(roundi(sc.x * ratio), roundi(sc.y * ratio))
		var r := Rect2i(c - Vector2i(GEN / 2, YUK / 2), Vector2i(GEN, YUK)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img.get_region(r).save_png(out.path_join(kv[0] + ".png"))
		if ff:
			print("ATESBOCEK ", kv[0], " alfa=", ff.get("_alpha"), " gorunen_alan=", (ff.get("_visible_zones") as PackedInt32Array).size(), " isik=", (ff.call("get_night_lights") as Array).size())
	print("ATESBOCEK bitti")
	quit(0)
