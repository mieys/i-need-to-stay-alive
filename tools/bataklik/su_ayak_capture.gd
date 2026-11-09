extends SceneTree
## SUYA GİREN AYAK yakalaması (madde 525): Kara Bataklık'ta oyuncuyu karadan gölcüğe yürütür (konum her kare ilerler -> halka sıklığı hareketle),
## sonra suda bekletir (yaratıklar gelip suya girer). Görüntüler oyuncunun çevresinden kırpılıp 2x büyütülür: tools/bataklik/out/su_ayak_<n>.png.
## Gizli masaüstünde koş: tools/bataklik/bataklik_tur.ps1 ile aynı düzen (-Betik res://tools/bataklik/su_ayak_capture.gd).
## SA_BASLA="x,y" (dünya px, kara), SA_BITIS="x,y" (su), SA_BEKLE=sn.

var _out: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _shot(name: String, center: Vector2) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var vp: Viewport = root
	var screen: Vector2 = vp.get_canvas_transform() * center
	var s: float = float(img.get_width()) / vp.get_visible_rect().size.x
	var r := Rect2i(Vector2i(int(screen.x * s) - 200, int(screen.y * s) - 170), Vector2i(400, 300))
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var c: Image = img.get_region(r)
	c.resize(c.get_width() * 2, c.get_height() * 2, Image.INTERPOLATE_NEAREST)
	c.save_png(_out.path_join("su_ayak_%s.png" % name))


func _vec(env: String, def: Vector2) -> Vector2:
	var s: String = OS.get_environment(env)
	if s == "":
		return def
	var p: PackedStringArray = s.split(",")
	return Vector2(float(p[0]), float(p[1]))


func _run() -> void:
	_out = ProjectSettings.globalize_path("res://tools/bataklik/out")
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", 1)
	gm.set("selected_start_weapon", "sword")
	gm.set("debug_immortal", true)
	gm.set("debug_mode_unlocked", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	gm.set("run_record_suppressed", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(6.0)
	var p: Node2D = main.get_node("Player")
	var sv: Node = p.get_node_or_null("ShieldVisual")
	var a: Vector2 = _vec("SA_BASLA", Vector2(2226, 3588))
	var b: Vector2 = _vec("SA_BITIS", Vector2(2306, 3588))
	p.global_position = a
	p.reset_physics_interpolation()
	await _wait(1.0)
	var dur: float = 2.6
	var t: float = 0.0
	var shots := [0.45, 1.1, 1.8, 2.55]
	var k := 0
	while t < dur:
		if sv is CanvasItem:
			(sv as CanvasItem).visible = false
		var dt: float = get_root().get_process_delta_time()
		t += dt
		p.global_position = a.lerp(b, clampf(t / dur, 0.0, 1.0))
		paused = false
		await process_frame
		if k < shots.size() and t >= float(shots[k]):
			await _shot("yuru_%d" % k, p.global_position)
			k += 1
	var wait_s: float = float(OS.get_environment("SA_BEKLE")) if OS.get_environment("SA_BEKLE") != "" else 8.0
	var t1: int = Time.get_ticks_msec()
	var n := 0
	while Time.get_ticks_msec() - t1 < int(wait_s * 1000.0):
		if sv is CanvasItem:
			(sv as CanvasItem).visible = false
		p.global_position = b
		paused = false
		await process_frame
		if Time.get_ticks_msec() - t1 > (n + 1) * int(wait_s * 1000.0 / 3.0):
			await _shot("bekle_%d" % n, p.global_position)
			n += 1
	var wade: Node = main.get_node_or_null("WadeFx")
	var vis := 0
	if wade != null:
		for ov in (wade.get("_overlays") as Dictionary).values():
			if is_instance_valid(ov) and (ov as CanvasItem).visible:
				vis += 1
	print("SA ortu gorunur=%d toplam=%d" % [vis, (wade.get("_overlays") as Dictionary).size() if wade else -1])
	quit(0)
