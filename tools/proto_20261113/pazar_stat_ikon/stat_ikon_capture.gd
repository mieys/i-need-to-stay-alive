extends SceneTree

## Level pazarı açıklamasında stat ikonları + alt alta statlar (2026-11-13) doğrulama çekimi: gerçek SP main.tscn + gerçek pazar ekranı,
## bir mana kalkanı + bir eşya + bir silah geliştirmesi seçili. dugme_capture.gd'den türedi.
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/proto_20261109/pazar_dugme/dugme_run.ps1 -Script ../../proto_20261113/pazar_stat_ikon/stat_ikon_capture.gd

const CHAR_ID := 2
const LEVEL := 13
const VARIANTS := ["SU_AN", "A", "B", "C", "D"]
var GM: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _out() -> String:
	var d: String = ""
	if d == "":
		d = ProjectSettings.globalize_path("res://tools/proto_20261113/pazar_stat_ikon/out")
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.get_width() != 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_BILINEAR)
	img.save_png(_out().path_join(name))
	print("SHOT %s" % name)


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
	var main: Node = current_scene
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
	GM.gold = 1480
	GM.call("add_weapon_shards", 4 - int(GM.weapon_shards))
	p.set("level", LEVEL)
	await _wait(1.0)

	var MarketScreenScript: GDScript = load("res://scripts/level_market_screen.gd")
	var offers: Dictionary = {"items": [{"type": "shield", "key": "shield_savas"}, {"type": "item", "key": "kan_kapani"}], "upgrades": []}
	paused = true
	var screen: CanvasLayer = MarketScreenScript.new()
	screen.set("player_ref", p)
	screen.set("level", LEVEL)
	screen.set("offers", offers)
	main.add_child(screen)
	await process_frame
	var view: Control = screen.get("view")
	for i in 2:
		view.call("_select", "items", i)
		await _wait(0.6)
		await _shot("sec_%d.png" % i)
	quit()
