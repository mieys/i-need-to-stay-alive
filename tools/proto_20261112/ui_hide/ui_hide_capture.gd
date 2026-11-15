extends SceneTree

## ARAYÜZÜ GİZLE (F3, madde 612) gerçek render doğrulaması (oyuna bağlı DEĞİL). Gerçek SP main.tscn, gündüz açık hava; yerel oyuncu Oakley + iki uzak kukla.
## Üç görüntü (pencere boyunda, 1:1): ui_1_acik.png (normal), ui_2_gizli.png (F3 gerçek tuş olayıyla; gizliyken yeni bildirim de doğurulur),
## ui_3_geri.png (F3 tekrar). Çıktı UH_OUT (varsayılan out/). Konsola "UH ..." satırları: katman/çubuk durumları.
## Koşturucu: ui_hide_run.ps1 (gizli masaüstü). Sahneler preload EDİLMEZ: -s betiği autoload'lardan önce derlenir.

const SPOT := Vector2(1410, 720)

var _dir: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _press_f3() -> void:
	for down: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_F3
		ev.physical_keycode = KEY_F3
		ev.pressed = down
		Input.parse_input_event(ev)
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(_dir.path_join(name))
	print("UH SHOT %s %s" % [name, str(img.get_size())])


func _state(tag: String, main: Node, bars: Array) -> void:
	var hud: CanvasLayer = main.get_node("HUD") as CanvasLayer
	var layers: Array = []
	for n in get_nodes_in_group(&"hideable_ui"):
		layers.append("%s=%s" % [n.name, str(n.get("visible"))])
	var vl: Array = []
	for b in bars:
		vl.append(int((b as CanvasItem).visibility_layer))
	print("UH %s hud.visible=%s bars.visibility_layer=%s hidden=%s layers=%s" % [
		tag, str(hud.visible), str(vl), str(root.get_node("UISound/UiHide").get_script().get("hidden")), str(layers)])


func _run() -> void:
	await process_frame
	_dir = OS.get_environment("UH_OUT")
	if _dir == "":
		_dir = ProjectSettings.globalize_path("res://tools/proto_20261112/ui_hide/out")
	DirAccess.make_dir_recursive_absolute(_dir)
	AudioServer.set_bus_mute(0, true)
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	root.get_node("UISound").set("show_fps", false)
	gm.call("reset")
	gm.set("selected_char_id", 2)
	gm.set("selected_character", (load("res://scripts/characters.gd") as GDScript).call("get_def", 2).get("skill", 1))
	gm.set("debug_immortal", true)
	gm.set("debug_mode_unlocked", true) ## kayıt yazılmasın
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	gm.set("run_record_suppressed", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(2.5)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var house: Node = main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	for n in main.find_children("*", "", true, false):
		var s: Script = n.get_script()
		if s and s.resource_path.ends_with("house_intro.gd"):
			n.set_process(false)
	await _wait(1.5)
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 150.0)
		atmo.call("debug_set_weather", 0)
	var player: Node2D = main.get_node_or_null("Player") as Node2D
	player.global_position = SPOT
	main.call("_spawn_remote_player", 901, 4, "Mira")
	main.call("_spawn_remote_player", 902, 9, "Kerem")
	var rps: Array = []
	for n in get_nodes_in_group("remote_players"):
		rps.append(n)
	await _wait(0.5)
	var offs := [Vector2(-72, 6), Vector2(72, 6)]
	for i in rps.size():
		rps[i].call("snap_to_network_position", SPOT + offs[i])
	var bars: Array = [player.get("overhead_bar")]
	for rp in rps:
		bars.append(rp.get("overhead_bar"))
	for b in bars:
		b.call("set_offset", -68.0)
		b.call("set_health", 300.0, 520.0)
		b.call("set_shield", 90.0, 150.0)
	await _wait(1.5)
	main.call("_show_notice", "ok", "BILDIRIM ACIKKEN", "", 2.8)
	await _wait(0.6)
	_state("acik", main, bars)
	await _shot("ui_1_acik.png")
	await _press_f3()
	await _wait(0.3)
	main.call("_show_notice", "warn", "GIZLIYKEN DOGAN BILDIRIM", "", 2.8)
	await _wait(0.5)
	_state("gizli", main, bars)
	await _shot("ui_2_gizli.png")
	await _press_f3()
	await _wait(0.3)
	main.call("_show_notice", "ok", "GERI ACILDI", "", 2.8)
	await _wait(0.5)
	_state("geri", main, bars)
	await _shot("ui_3_geri.png")
	print("UH BITTI")
	quit()
