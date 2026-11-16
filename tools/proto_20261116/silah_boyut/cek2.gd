extends SceneTree

## Madde 759 son tur ölçüm + yakalama (oyun kodu olduğu gibi):
##   - sağ panelin her sekmedeki boyu / en küçük boyu (sekme değişince damar dokusu kayıyor muydu: PixelBox grain_offset kutu BOYUNA bağlı)
##   - her karakterde orta panel en küçük boyu (sınır 1024) + 2 satıra sığmayıp "…" ile kırpılan yetenek kısa metni
## Çıktı SS_OUT/silah_ust.png, silah_alt.png, yetenek.png (Matthew), sag_<sekme>.png.

func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _panel_of(desk: Node, n: Node) -> Control:
	while n != null and n.get_parent() != desk:
		n = n.get_parent()
	return n as Control


func _shot() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _crop(img: Image, r: Rect2, path: String) -> void:
	var s: float = img.get_width() / 1920.0
	img.get_region(Rect2i(int(r.position.x * s), int(r.position.y * s), int(r.size.x * s), int(r.size.y * s))).save_png(path)


func _run() -> void:
	await process_frame
	var dir: String = OS.get_environment("SS_OUT")
	DirAccess.make_dir_recursive_absolute(dir)
	AudioServer.set_bus_mute(0, true)
	load("res://scripts/meta_progress.gd").set_unlock_all(true)
	change_scene_to_file("res://scenes/character_select.tscn")
	await _wait(2.5)
	var desk: Node = current_scene.get("_desk")
	var tg: Control = desk.get("_tab_grid")
	var right: Control = _panel_of(desk, tg)
	for tab: String in ["weapon", "pet", "spirit"]:
		desk.call("_set_tab", tab)
		await _wait(0.3)
		print("OLC sag %s boy=%s en_kucuk=%s" % [tab, str(right.size), str(right.get_combined_minimum_size())])
		var img: Image = await _shot()
		_crop(img, Rect2(right.position.x, right.position.y, right.size.x, 420.0), dir.path_join("sag_%s.png" % tab))
	var skills: VBoxContainer = desk.get("_skills")
	var mid: Control = _panel_of(desk, skills)
	var worst: float = 0.0
	var wid: int = 0
	var ids: Array = Characters.DEFS.keys()
	ids.sort()
	var loc = load("res://scripts/localization.gd")
	var start_lang: String = TranslationServer.get_locale()
	for code: String in ["tr", "en", "de", "es", "fr", "it", "pl", "pt", "ru", "zh"]:
		loc.apply(code)
		var kirpik: int = 0
		for id in ids:
			desk.call("show_character", int(id), false)
			await process_frame
			await process_frame
			var m: float = mid.get_combined_minimum_size().y
			if m > worst:
				worst = m
				wid = int(id)
			for row: Node in skills.get_children():
				for lb: Label in row.find_children("*", "Label", true, false):
					if lb.max_lines_visible > 0 and lb.get_line_count() > lb.max_lines_visible:
						kirpik += 1
						print("OLC kirpik %s %d '%s' satir=%d" % [code, int(id), lb.text.left(30), lb.get_line_count()])
		print("OLC dil %s kirpik=%d" % [code, kirpik])
	loc.apply(start_lang.left(2))
	print("OLC orta en_kotu=%.0f (id %d)" % [worst, wid])
	desk.call("show_character", 3, false)
	await _wait(0.3)
	var img2: Image = await _shot()
	var sr: Rect2 = skills.get_global_rect()
	_crop(img2, Rect2(sr.position.x - 8.0, sr.position.y - 8.0, 760.0, sr.size.y + 16.0), dir.path_join("yetenek.png"))
	desk.call("_set_tab", "weapon")
	await _wait(0.3)
	var sc: ScrollContainer = null
	var n: Node = tg
	while n != null and not (n is ScrollContainer):
		n = n.get_parent()
	sc = n as ScrollContainer
	for part in 2:
		sc.scroll_vertical = 0 if part == 0 else 100000
		await _wait(0.3)
		var img3: Image = await _shot()
		var r: Rect2 = sc.get_global_rect()
		_crop(img3, Rect2(r.position.x - 4.0, r.position.y - 4.0, r.size.x + 8.0, r.size.y + 8.0), dir.path_join("silah_%s.png" % ("ust" if part == 0 else "alt")))
	load("res://scripts/meta_progress.gd").set_unlock_all(false)
	print("BITTI")
	quit(0)
