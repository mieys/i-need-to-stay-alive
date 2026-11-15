extends SceneTree

## Silah stat çubukları (2026-11-13) görsel kontrolü: gerçek character_select.tscn, SİLAH sekmesi, 2 farklı silah -> tam ekran + sağ panel kırpıntısı.

func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _run() -> void:
	await process_frame
	var dir: String = OS.get_environment("SS_OUT")
	DirAccess.make_dir_recursive_absolute(dir)
	AudioServer.set_bus_mute(0, true)
	load("res://scripts/meta_progress.gd").set_unlock_all(true)
	change_scene_to_file("res://scenes/character_select.tscn")
	await _wait(2.5)
	var desk: Node = current_scene.get("_desk")
	desk.call("_set_tab", "weapon")
	for k: String in ["kalkan", "makineli"]:
		desk.call("_on_option_pressed", k)
		await _wait(0.4)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_png(dir.path_join(k + "_tam.png"))
		img.get_region(Rect2i(1250, 0, 670, 1080)).save_png(dir.path_join(k + ".png"))
		print("SS SHOT %s %s" % [k, str(img.get_size())])
	load("res://scripts/meta_progress.gd").set_unlock_all(false)
	quit(0)
