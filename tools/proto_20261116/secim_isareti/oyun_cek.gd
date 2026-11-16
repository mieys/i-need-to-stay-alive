extends SceneTree

## OYUNDAKİ seçim işareti (madde 759, D + B: altın çerçeve + zıplayan ok) yakalaması - prototip değil, oyun kodu olduğu gibi.
## Oakley seçili, Matthew üstünde (fare); sağda EVCİL sekmesi, seçili evcil + bir sonrakinin üstünde. Okun iki karesi (yukarı / aşağı).
## Çıktı SS_OUT/oyun_tam.png, oyun_kar_0.png / oyun_kar_1.png (ilk 2 satır), oyun_karo.png, oyun_silah.png.

const SEL := 2
const HOV := 3


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


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
	desk.call("show_character", SEL, false)
	var cards: Dictionary = desk.get("_cards")
	for id in cards: ## açılışta klavye odağı ilk kartta olabilir; yalnız HOV üstünde görünsün
		cards[id]["foc"] = false
		desk.call("_set_card_hover", int(id), "hov", int(id) == HOV)
	desk.call("_set_tab", "pet")
	await _wait(0.4)
	var tg: Control = desk.get("_tab_grid")
	for b: Button in tg.get_children():
		if not bool(b.get_meta("tile_on", false)):
			b.mouse_entered.emit()
			break
	var grid: Control = (cards[SEL]["btn"] as Control).get_parent()
	var gr: Rect2 = grid.get_global_rect()
	var r_kar := Rect2(gr.position.x - 14.0, gr.position.y - 16.0, gr.size.x + 28.0, 138.0 * 2.0 + 16.0 + 26.0)
	var arrow: Object = cards[SEL]["arrow"]
	## okun iki karesi: _time'ı yarım periyodun iki yanına koy
	for k in 2:
		arrow.set("_time", 0.05 if k == 0 else 0.6)
		await process_frame
		await process_frame
		var img: Image = await _shot()
		_crop(img, r_kar, dir.path_join("oyun_kar_%d.png" % k))
		if k == 0:
			_crop(img, Rect2(488, 24, 1400, 1024), dir.path_join("oyun_tam.png"))
			var tr: Rect2 = tg.get_global_rect()
			_crop(img, Rect2(tr.position.x - 12.0, tr.position.y - 16.0, 604.0, 124.0 + 22.0), dir.path_join("oyun_karo.png"))
	desk.call("_set_tab", "weapon")
	await _wait(0.4)
	var img2: Image = await _shot()
	var tr2: Rect2 = tg.get_global_rect()
	_crop(img2, Rect2(tr2.position.x - 12.0, tr2.position.y - 16.0, 604.0, 124.0 + 22.0), dir.path_join("oyun_silah.png"))
	load("res://scripts/meta_progress.gd").set_unlock_all(false)
	print("BITTI")
	quit(0)
