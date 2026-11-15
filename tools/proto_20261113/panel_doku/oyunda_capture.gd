extends SceneTree
## Panel dokusu OYUNDA doğrulaması (madde 662): prototip katmanı YOK, doğrudan oyunun pixel_box.gd'si. Oda listesi + karakter seçimi +
## lobi ekranı yakalanır. CAP_OUT = PNG klasörü. Çalıştır: run.ps1 -Script oyunda_capture.gd

var _out: String = OS.get_environment("CAP_OUT")


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
	for sc: String in ["room_browser", "character_select", "lobby_menu"]:
		change_scene_to_file("res://scenes/%s.tscn" % sc)
		await _wait(3.0)
		await _shot("oyunda_" + sc)
	quit(0)
