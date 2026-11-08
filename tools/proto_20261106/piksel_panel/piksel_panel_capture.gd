extends SceneTree
## PİKSEL KENARLI PANEL prototipi yakalaması (2026-11-06, oyuna bağlı DEĞİL). Gerçek oyunda Level Pazarı + Oyun Bitti açılır,
## pencerelerdeki StyleBoxFlat kutular çalışma anında pixel_box.gd ile AYNI renkte piksel kenarlı kutulara çevrilir.
## Çıktı: PIKSEL_PANEL_DIR/<ekran>_<simdi|A|B|C|D>.png. Koşu: piksel_panel_run.ps1 (gizli masaüstü).

const PB := preload("res://tools/proto_20261106/piksel_panel/pixel_box.gd")
const CHAR_ID := 2
const LEVEL := 13
const SEED := 20261106
const VARIANTS := ["simdi", "A", "B", "C", "D"]

var GM: Node = null
var main: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _out() -> String:
	var d: String = OS.get_environment("PIKSEL_PANEL_DIR")
	if d == "":
		d = ProjectSettings.globalize_path("res://tools/proto_20261106/piksel_panel/out")
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.get_width() != 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	img.save_png(_out().path_join(name))
	print("SHOT %s" % name)


func _variants(prefix: String, sub: Node, extra: Callable = Callable()) -> void:
	var entries: Array = PB.collect(sub)
	print("VERI %s kutu=%d" % [prefix, entries.size()])
	var only: String = OS.get_environment("PIKSEL_PANEL_ONLY")
	var vs: Array = VARIANTS if only == "" else Array(only.split(","))
	for v: String in vs:
		var n: int = PB.apply(entries, v)
		if extra.is_valid():
			extra.call(v)
		for c in sub.find_children("*", "Control", true, false):
			(c as Control).queue_redraw()
		await _wait(0.4)
		print("  %s %s degisen=%d" % [prefix, v, n])
		await _shot("%s_%s.png" % [prefix, v])
	PB.apply(entries, "simdi")


func _run() -> void:
	await process_frame
	GM = root.get_node("GameManager")
	AudioServer.set_bus_mute(0, true)
	root.get_node("NetworkManager").call("disconnect_from_room")
	root.get_node("UISound").set("show_fps", false)
	GM.call("reset")
	GM.set("selected_char_id", CHAR_ID)
	GM.set("selected_character", (load("res://scripts/characters.gd") as GDScript).call("get_def", CHAR_ID).get("skill", 1))
	GM.set("selected_start_weapon", "uzunkilic")
	GM.set("selected_pet", "kirpi")
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(2.5)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	main = current_scene
	## gerçek kayıtlara yazılmasın
	main.set("_run_end_recorded", true)
	GM.set("run_record_suppressed", true)
	var house: Node = main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	for n in main.find_children("*", "", true, false):
		var s: Script = n.get_script()
		if s and s.resource_path.ends_with("house_intro.gd"):
			n.set_process(false)
	await _wait(2.0)
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var p: Node2D = main.get_node_or_null("Player") as Node2D
	p.global_position += Vector2(40, 170)
	var Logic: GDScript = load("res://scripts/weapon_shop_logic.gd")
	(load("res://scripts/meta_progress.gd") as GDScript).call("set_unlock_all", true)
	GM.gold = 99999
	GM.call("add_weapon_shards", 999 - int(GM.weapon_shards))
	Logic.call("buy_weapon", p, "fire_staff")
	p.set("max_item_slots", 9)
	for key: String in ["kanli_yakut", "ceviklik_yuzugu"]:
		p.call("buy_item", key)
	GM.set("game_time", 1350.0)
	GM.set("free_rerolls_per_card", 1)
	GM.gold = 1480
	GM.call("add_weapon_shards", 17 - int(GM.weapon_shards))
	p.set("level", LEVEL)
	await _wait(1.0)

	## ---- 1) Level Pazarı
	seed(SEED)
	main.call("_show_level_up_screen", LEVEL)
	await _wait(1.4)
	var screen: Node = main.get_node_or_null("LevelUpScreen")
	if screen:
		var view: Control = screen.get("_market_view")
		if view:
			view.set("_hover", 1)
			view.call("_refresh_detail")
		await _wait(0.3)
		await _variants("pazar", screen)
		screen.queue_free()
		await _wait(0.5)
	else:
		print("!! level ekranı yok")
	paused = false

	## ---- 2) Oyun Bitti
	GM.set("run_clock_origin", float(GM.get("game_time")) - 1350.0)
	main.call("_show_death_overlay", true)
	await _wait(1.2)
	var dl: Node = main.get("_death_overlay_layer")
	if dl:
		var board_script: GDScript = load("res://scripts/game_over_board.gd")
		var well0: StyleBox = board_script.get("_well_sb")
		var set_well := func(v: String) -> void:
			if well0 is StyleBoxFlat:
				board_script.set("_well_sb", PB.to_pixel(well0, v, Vector2(200, 200)))
		await _variants("bitti", dl, set_well)
	else:
		print("!! oyun bitti katmanı yok")
	## ---- 3) Ana menü + Ruh Mağazası (menu_dark_kit / soul_shop kutuları; yalnız oyundaki hâl)
	if OS.get_environment("PIKSEL_PANEL_ONLY") == "simdi":
		root.get_node("NetworkManager").call("disconnect_from_room")
		change_scene_to_file("res://scenes/main_menu.tscn")
		var t1: int = Time.get_ticks_msec()
		while (current_scene == null or current_scene.name == "Main") and Time.get_ticks_msec() - t1 < 20000:
			await process_frame
		await _wait(2.0)
		if current_scene and current_scene.has_method("_on_soul_shop_pressed"):
			current_scene.call("_on_soul_shop_pressed")
			await _wait(1.5)
			await _shot("ruh_simdi.png")
		## tek oyunculu karakter seçimi (menu_dark_kit kutuları)
		change_scene_to_file("res://scenes/main_menu.tscn")
		await _wait(2.0)
		if current_scene and current_scene.has_method("_on_start_pressed"):
			current_scene.call("_on_start_pressed")
			await _wait(2.5)
			await _shot("secim_simdi.png")
	quit()
