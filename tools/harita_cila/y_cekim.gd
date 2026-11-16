extends SceneTree
## Y SIRASI ÇEKİMİ (2026-11-15, kullanıcı: "Y ekseni sorunlarına çok özen göster, saçma sapan şeyler altta ya da üstte kalıyor"): seçili haritada
## (HARITA) oyuncuyu verilen DÜNYA px AYAK noktalarına koyar (kök = ayak - DepthOccluders.FEET_OFFSET), gerçek çiziciyle görüntü alır ve oyuncunun
## ekran konumu çevresinden KIRP x KIRP px kırpar -> <CAP_OUT>/<ad>.png. Gizli masaüstünde koşar: tools/harita_cila/y_cekim.ps1.
## CAP_NOKTALAR="ad:x,y;ad2:x,y" (ayak, dünya px). CAP_SAAT gündüz saati (varsayılan 120).

const KIRP := 360

var _gm: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


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
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(5.0)
	var atmo: Node = main.get_node_or_null("Atmosphere")
	if atmo:
		atmo.set("cycle_time", float(OS.get_environment("CAP_SAAT")) if OS.get_environment("CAP_SAAT") != "" else 120.0)
	## yaratık doğmasın / görüntüyü kapatmasın
	var sp: Node = main.get_node_or_null("EnemySpawner")
	if sp:
		sp.process_mode = Node.PROCESS_MODE_DISABLED
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
		await _wait(1.3)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var sc: Vector2 = root.get_canvas_transform() * p.global_position
		## pencere ölçeği (içerik ölçeği) varsa doku piksel = görünüm px * oran
		var ratio: float = float(img.get_width()) / float(root.get_visible_rect().size.x)
		var c := Vector2i(roundi(sc.x * ratio), roundi(sc.y * ratio))
		var r := Rect2i(c - Vector2i(KIRP / 2, KIRP * 3 / 5), Vector2i(KIRP, KIRP)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img.get_region(r).save_png(out.path_join(kv[0] + ".png"))
	print("YCEKIM bitti")
	quit(0)
