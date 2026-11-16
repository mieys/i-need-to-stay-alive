extends SceneTree
## KART DOKUSU seçenekleri (madde 753, 2026-11-16; kullanıcı: "son texture değişiminden sonra silahlar zor okunur hale geldi"): pencere
## zemini R2 kalır, yalnız iç kart dolgusunun (WIN_PANEL2/3) doku gücü değişir: simdi 1,0 / duz 0 / zayif 0,35 (pixel_box grain_card_alpha).
## Karakter seçimi (tüm kilitler açık -> silah ızgarası dolu) + dünya haritası. Çıktı CAP_OUT/kart/<seçenek>_<ekran>.png. run.ps1 -Script kart_capture.gd

const OPTIONS := {"simdi": 1.0, "duz": 0.0, "zayif": 0.35}
var _out: String = OS.get_environment("CAP_OUT").path_join("kart")


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(0, true)
	(load("res://scripts/meta_progress.gd") as GDScript).call("set_unlock_all", true)
	var pb: GDScript = load("res://scripts/pixel_box.gd")
	for k: String in OPTIONS:
		pb.set("grain_card_alpha", float(OPTIONS[k]))
		change_scene_to_file("res://scenes/character_select.tscn")
		await _wait(2.5)
		await _shot(k + "_karakter")
		if int(current_scene.get("selected_char")) < 0:
			current_scene.set("selected_char", 1)
		current_scene.call("_on_start_pressed")
		await _wait(1.5)
		await _shot(k + "_harita")
	quit(0)
