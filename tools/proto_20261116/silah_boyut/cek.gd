extends SceneTree

## Silah kuyusu + dengeli boy yakalaması (madde 759). Oyun kodu olduğu gibi; yalnız karşılaştırma için kuyu tonu sırayla değiştirilir:
##   oyun = HT.ITEM_WELL (RIM_LO + damar), koyu = WIN_PANEL2 (STRIPE), orta = WIN_PANEL3. Her tonda tüm silahlar (üst 3 satır + kaydırılmış alt).
## Çıktı SS_OUT/<ton>_ust.png, <ton>_alt.png.

func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _run() -> void:
	await process_frame
	var ht = load("res://scripts/hud_theme.gd")
	var dir: String = OS.get_environment("SS_OUT")
	DirAccess.make_dir_recursive_absolute(dir)
	AudioServer.set_bus_mute(0, true)
	load("res://scripts/meta_progress.gd").set_unlock_all(true)
	change_scene_to_file("res://scenes/character_select.tscn")
	await _wait(2.5)
	var desk: Node = current_scene.get("_desk")
	desk.call("_set_tab", "weapon")
	await _wait(0.5)
	var tg: Control = desk.get("_tab_grid")
	var sc: ScrollContainer = null
	var n: Node = tg
	while n != null and not (n is ScrollContainer):
		n = n.get_parent()
	sc = n as ScrollContainer
	var tones: Array = [["oyun", ht.ITEM_WELL], ["koyu", ht.WIN_PANEL2], ["orta", ht.WIN_PANEL3]]
	for tone: Array in tones:
		for b: Button in tg.get_children():
			var holder: Control = ((b.get_child(0) as Control).get_child(0) as Control).get_child(0)
			var well: Node = holder.get_child(0)
			if well is ColorRect:
				(well as ColorRect).color = tone[1]
		for part in 2:
			sc.scroll_vertical = 0 if part == 0 else 100000
			await _wait(0.3)
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			var s: float = img.get_width() / 1920.0
			var r: Rect2 = sc.get_global_rect()
			img.get_region(Rect2i(int((r.position.x - 4.0) * s), int((r.position.y - 4.0) * s), int((r.size.x + 8.0) * s), int((r.size.y + 8.0) * s))).save_png(
					dir.path_join("%s_%s.png" % [tone[0], "ust" if part == 0 else "alt"]))
	load("res://scripts/meta_progress.gd").set_unlock_all(false)
	print("BITTI")
	quit(0)
