extends SceneTree

## TELEFON MENÜLERİ gerçek oyunda (2026-10-19): ana menü ve ondan açılan ekranlar, tek oyunculu karakter seçimi, oda listesi.
## Ekran listesi MOBIL_MENU ortam değişkeninden (virgüllü): ana, ayar, rekor, ruh, karakter, oda (bkz. _open).
## Kullanım: $env:MOBIL_MENU="ana,oda"; Godot --path . --windowed --resolution 2400x1080 -s tools/proto_20261018/mobil_menu_capture.gd -- --mobile-ui
## Çıktı: tools/proto_20261018/out/mobil/oyun_menu_<ekran>.png

const OUT := "res://tools/proto_20261018/out/mobil/"


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(ProjectSettings.globalize_path(OUT + n + ".png"))
	print("SHOT ", n, " ", img.get_size())


func _goto(path: String, node_name: String) -> void:
	change_scene_to_file(path)
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != node_name) and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
	await _wait(1.2)


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	root.get_node("UISound").set("show_fps", false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	await _wait(0.8)
	var list: String = OS.get_environment("MOBIL_MENU")
	if list == "":
		list = "ana"
	for scr: String in list.split(",", false):
		scr = scr.strip_edges()
		match scr:
			"ana":
				await _goto("res://scenes/main_menu.tscn", "MainMenu")
			"ayar", "rekor", "ruh":
				await _goto("res://scenes/main_menu.tscn", "MainMenu")
				current_scene.call({"ayar": "_on_settings_pressed", "rekor": "_on_records_pressed", "ruh": "_on_soul_shop_pressed"}[scr])
				await _wait(1.4)
			"karakter":
				await _goto("res://scenes/character_select.tscn", "CharacterSelect")
			"oda":
				await _goto("res://scenes/room_browser.tscn", "RoomBrowser")
			_:
				print("MOBIL_MENU bilinmeyen ekran: ", scr)
				continue
		await _shot("oyun_menu_" + scr)
	quit()
