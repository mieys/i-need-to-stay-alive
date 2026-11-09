extends SceneTree

## Karakter üstü can/kalkan çubuğu prototipleri yakalayıcısı (2026-11-08, oyuna bağlı DEĞİL). Gerçek SP main.tscn, gündüz açık hava,
## kuzey ağaçlığı yanındaki çayır; yerel oyuncu Oakley + iki uzak kukla (Büyücü Kız, Korsan; main._spawn_remote_player).
## Her stil (simdi = bugünkü overhead_bar.gd, A..D = ust_bar_proto.gd) için üç çubuğa betik takılır, değerler her karede yeniden yazılır:
##   Oakley 375/520 can (%72, 12 çizgi) + 90/150 kalkan | Büyücü 105/300 (%35) + 200/200 kalkan | Korsan 140/900 (%16, 20 çizgi), kalkansız.
## Çıktı: UB_OUT (varsayılan out/) içine ub_<stil>.png (pencere boyunda, 1:1) + ub_konum.json (çubuk ekran konumları).
## Koşturucu: ust_bar_run.ps1 (gizli masaüstü). Sahneler preload EDİLMEZ: -s betiği autoload'lardan önce derlenir.

const SPOT := Vector2(1410, 720)
const STATES := [
	[375.0, 520.0, 90.0, 150.0],
	[105.0, 300.0, 200.0, 200.0],
	[140.0, 900.0, 0.0, 0.0],
]

var _dir: String = ""
var _bars: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _apply_values() -> void:
	for i in _bars.size():
		var b: Node2D = _bars[i]
		if b == null or not is_instance_valid(b):
			continue
		var st: Array = STATES[i]
		b.call("set_offset", -68.0)
		b.call("set_health", st[0], st[1])
		b.call("set_shield", st[2], st[3])
		b.visible = true


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		_apply_values()
		await process_frame


func _run() -> void:
	await process_frame
	_dir = OS.get_environment("UB_OUT")
	if _dir == "":
		_dir = ProjectSettings.globalize_path("res://tools/proto_20261108/ust_bar/out")
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
	## Gizli pencere 1920x1080 olmayabilir: içerik ölçeği kapalı -> dünya hep 1080p'deki gibi 1:1 (1 çubuk birimi = 1 ekran px).
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
		atmo.call("debug_set_time", 150.0) ## gündüz, açık hava
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
	_bars = [player.get("overhead_bar")]
	for rp in rps:
		_bars.append(rp.get("overhead_bar"))
	await _wait(2.0)
	var proto: Script = load("res://tools/proto_20261108/ust_bar/ust_bar_proto.gd")
	var base: Script = load("res://scripts/overhead_bar.gd")
	var only: String = OS.get_environment("UB_ONLY")
	var styles: PackedStringArray = (only if only != "" else "simdi,A,B,C,D").split(",")
	var pos_info: Dictionary = {}
	for st: String in styles:
		for b in _bars:
			b.set_script(base if st == "simdi" else proto)
			if st != "simdi":
				b.set("proto_style", st)
		await _wait(0.4)
		for i in rps.size():
			rps[i].call("snap_to_network_position", SPOT + offs[i])
		await _wait(0.2)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_png(_dir.path_join("ub_%s.png" % st))
		var bl: Array = []
		for b in _bars:
			var p: Vector2 = (b as Node2D).get_global_transform_with_canvas() * Vector2(0.0, -68.0)
			bl.append([p.x, p.y])
		pos_info[st] = {"size": [img.get_width(), img.get_height()], "bars": bl}
		print("UB SHOT %s %s" % [st, str(img.get_size())])
	var f := FileAccess.open(_dir.path_join("ub_konum.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(pos_info))
	f.close()
	print("UB BITTI")
	quit()
