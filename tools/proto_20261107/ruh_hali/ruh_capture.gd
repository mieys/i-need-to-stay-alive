extends SceneTree

## Ruh hâli (madde 438) görsel kontrolü: gerçek Main, tek oyunculu, level ekranı açılır ve ekranın kendisi kenara itilir (okuma klibi
## sürsün diye görünür kalır) - karakter normal / ruh hâlinde yakalanır. Çıktı RH_OUT klasörü. Koşturucu: ruh_run.ps1 (gizli masaüstü).

var _out: String = OS.get_environment("RH_OUT")
var _gm: Node


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _wait_unpaused(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var sz: Vector2i = img.get_size()
	var crop := Vector2i(360, 220)
	img = img.get_region(Rect2i(sz / 2 - crop / 2 + Vector2i(0, -20), crop))
	img.resize(crop.x * 2, crop.y * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(_out.path_join(nm + ".png"))
	print("RH shot ", nm)


func _run() -> void:
	await process_frame
	_gm = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	var chars: PackedStringArray = OS.get_environment("RH_CHARS").split(",")
	for cs in chars:
		await _one(int(cs))
	quit()


func _one(char_id: int) -> void:
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", char_id)
	_gm.set("selected_character", load("res://scripts/characters.gd").get_def(char_id).get("skill", 1))
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	await _wait_unpaused(2.5)
	var ws: Node = _find(main, "_auto_pick_random_card")
	if ws:
		ws.call("_auto_pick_random_card")
	await _wait_unpaused(1.0)
	var house: Node = main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	var intro: Node = main.get_node_or_null("HouseInterior/HouseIntro")
	if intro and intro.has_method("_set_phase"):
		intro.call("_set_phase", 3, 0.0)
	_gm.set("invasion_pending", false)
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 150.0)
		atmo.call("debug_set_weather", 0)
	await _wait_unpaused(2.0)
	await _shot("c%d_normal" % char_id)
	main.call("_show_level_up_screen", int(_gm.get("team_level")))
	await _wait(0.2)
	for c in main.get_children():
		if c is CanvasLayer and (String(c.name).begins_with("LevelUpScreen") or String(c.name).begins_with("LevelMarket")):
			(c as CanvasLayer).offset = Vector2(100000, 0) ## ekran görünür kalsın (okuma klibi), ama kadrajda olmasın
	var hud: Node = main.get_node_or_null("HUD")
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = false
	await _wait(1.2)
	for i in 3:
		await _shot("c%d_ruh_%d" % [char_id, i])
		await _wait(0.35)


func _find(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var r: Node = _find(c, method)
		if r:
			return r
	return null
