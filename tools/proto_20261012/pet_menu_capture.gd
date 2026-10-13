extends SceneTree

## Evcil hayvan seçicisinin (menu_pet_picker.gd) karakter seçim ekranı + lobi yerleşiminde GERÇEK çizici görüntüsü.
## Kullanım: Godot --path . -s tools/proto_20261012/pet_menu_capture.gd   (PET_CAP_DIR ortam değişkeni; PET_CAP_SCENE = character_select | lobby_menu)

var _dir: String = OS.get_environment("PET_CAP_DIR")
var _scene_name: String = OS.get_environment("PET_CAP_SCENE")


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _run() -> void:
	if OS.get_environment("PET_CAP_MOBILE") == "1":
		load("res://scripts/mobile_ui.gd").enabled = true
	if OS.get_environment("PET_CAP_PET") != "": ## seçili gelsin (açıklamasının sığdığını görmek için)
		root.get_node("GameManager").selected_pet = OS.get_environment("PET_CAP_PET")
	if _scene_name == "lobby_menu":
		root.get_node("NetworkManager").host_lan(7791, "Test", 1)
		await _wait(0.5)
	var sc: Node = (load("res://scenes/%s.tscn" % _scene_name) as PackedScene).instantiate()
	root.add_child(sc)
	await _wait(1.5)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(_dir.path_join("%s_%d%s.png" % [_scene_name, img.get_width(), OS.get_environment("PET_CAP_MOBILE")]))
	print("SHOT %s %dx%d pet=%s" % [_scene_name, img.get_width(), img.get_height(), root.get_node("GameManager").selected_pet])
	quit()
