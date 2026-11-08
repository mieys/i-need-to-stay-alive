extends SceneTree
## Harita seçimi arayüz görüntüsü (madde 444): oda listesi ekranı (ODA KUR formu, Harita satırı) + tek oyunculu karakter seçimi (HARİTA kutusu).
## Gizli masaüstünde (hidden_launch.ps1), APPDATA yalıtılı; CAP_OUT = PNG klasörü.

var _out: String = OS.get_environment("CAP_OUT")


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	img.save_png(_out.path_join(name + ".png"))
	print("CAP ", name)


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var sec: String = OS.get_environment("CAP_HARITA") ## seçili gösterilecek harita (boşsa batik_nekropol)
	root.get_node("GameManager").set("selected_map", sec if sec != "" else "batik_nekropol")
	change_scene_to_file("res://scenes/room_browser.tscn")
	await _wait(3.0)
	await _shot("secim_oda_kur")
	change_scene_to_file("res://scenes/character_select.tscn")
	await _wait(3.0)
	await _shot("secim_tek_oyunculu")
	quit(0)
