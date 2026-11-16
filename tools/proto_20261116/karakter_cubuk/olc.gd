extends SceneTree

## Karakter stat çubukları (madde 748) yerleşim ölçümü: orta panelde ad sütunu / temel stat ızgarası genişliği, karakter başına.
## SS_SHOTS=1 ise her karakter için orta panel kırpıntısı da kaydedilir (SS_OUT klasörüne).

func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _run() -> void:
	await process_frame
	var dir: String = OS.get_environment("SS_OUT")
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	AudioServer.set_bus_mute(0, true)
	load("res://scripts/meta_progress.gd").set_unlock_all(true)
	change_scene_to_file("res://scenes/character_select.tscn")
	await _wait(2.5)
	var desk: Node = current_scene.get("_desk")
	var ids: Array = Characters.DEFS.keys()
	ids.sort()
	for id in ids:
		desk.call("show_character", int(id), false)
		await _wait(0.25)
		var nm: Control = desk.get("_char_name")
		var ti: Control = desk.get("_char_title")
		var st: Control = desk.get("_stats")
		var row: Control = st.get_parent()
		var bars: Control = desk.get("_char_bars")
		print("OLC %d %s ad=%.0f lakap=%.0f stat=%.0f satir=%.0f satir_h=%.0f cubuk=%s" % [int(id), str(Characters.get_def(int(id)).get("name", "")),
			nm.get_combined_minimum_size().x, ti.get_combined_minimum_size().x if ti.visible else 0.0, st.size.x, row.size.x, row.size.y,
			str(bars.get_global_rect()) if bars != null else "-"])
		if OS.get_environment("SS_SHOTS") == "1" and dir != "":
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			var s: float = img.get_width() / 1920.0
			img.get_region(Rect2i(int(488 * s), int(560 * s), int(760 * s), int(488 * s))).save_png(dir.path_join("orta_%02d.png" % int(id)))
			img.get_region(Rect2i(int(1264 * s), int(24 * s), int(624 * s), int(260 * s))).save_png(dir.path_join("sag_%02d.png" % int(id)))
	load("res://scripts/meta_progress.gd").set_unlock_all(false)
	quit(0)
