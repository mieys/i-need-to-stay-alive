extends SceneTree
## PANEL DOKUSU 3. set + MENÜ BULANIKLIĞI yakalaması (2026-11-16). Oyunun kendi pixel_box.gd'si; yalnız `grain_tex` karo geçici değişir.
## CAP_SET = "simdi,r1,r2,r3,r4" (simdi = oyundaki karo), CAP_SCENES = "room_browser,character_select", CAP_EXTRA=1 -> ana menü ayarlar +
## Ruh Mağazası (bulanıklık denetimi). Çıktı CAP_OUT/<varyant>_<sahne>.png. Çalıştır: run.ps1

var _out: String = OS.get_environment("CAP_OUT")
var _tiles: String = OS.get_environment("CAP_TILES")


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("SHOT ", name, " ", img.get_size())


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var pb: GDScript = load("res://scripts/pixel_box.gd")
	var original: Texture2D = pb.get("grain_tex")
	var scenes: PackedStringArray = OS.get_environment("CAP_SCENES").split(",", false)
	if scenes.is_empty():
		scenes = PackedStringArray(["room_browser"])
	for v: String in OS.get_environment("CAP_SET").split(",", false):
		if v == "simdi":
			pb.set("grain_tex", original)
		else:
			var img := Image.load_from_file(_tiles.path_join(v + "_x3.png"))
			pb.set("grain_tex", ImageTexture.create_from_image(img))
		for sc: String in scenes:
			change_scene_to_file("res://scenes/%s.tscn" % sc)
			await _wait(2.5)
			await _shot("%s_%s" % [v, sc])
	if OS.get_environment("CAP_EXTRA") == "1":
		pb.set("grain_tex", original)
		change_scene_to_file("res://scenes/main_menu.tscn")
		await _wait(2.5)
		await _shot("menu_ana")
		current_scene.call("_on_settings_pressed")
		await _wait(1.0)
		await _shot("menu_ayarlar")
		current_scene.call("_on_settings_closed")
		for c: Node in current_scene.get_children():
			if c.name == "SettingsScreen":
				c.queue_free()
		await _wait(0.3)
		current_scene.call("_on_soul_shop_pressed")
		await _wait(1.5)
		await _shot("menu_ruh_magazasi")
	quit(0)
