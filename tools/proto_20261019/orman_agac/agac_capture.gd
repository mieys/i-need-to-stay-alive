extends SceneTree

## Ağaç arkası / önü GERÇEK MAIN'de (2026-10-19, madde 284 (c) devamı): oyuncu AC_POINTS'teki dünya konumlarına (oyuncu kökü, ayak = +FEET_OFFSET)
## sırayla konur, her birinde ekranın ortası (oyuncu çevresi, AC_W x AC_H ekran px) kırpılıp ac_NN.png yazılır; HUD gizli, yaratık yok, gündüz açık hava.
## Ayrıca o noktadaki derinlik ön kopyalarının durumu yazılır (Ağaç katmanı kopyası var mı, ayağın altındaki kök).
## Koşturucu: tools/proto_20261019/orman_agac/agac_run.ps1 -Env "AC_POINTS=4070,2427|4070,2460"

var _dir: String = OS.get_environment("AC_DIR")
var _gm: Node = null
var _main: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _run() -> void:
	await process_frame
	_gm = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	var cid: int = int(OS.get_environment("AC_CHAR")) if OS.get_environment("AC_CHAR") != "" else 2
	_gm.set("selected_char_id", cid)
	_gm.set("selected_character", (load("res://scripts/characters.gd") as GDScript).get_def(cid).get("skill", 1))
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true) ## kayıt yazılmaz (fps_micro._boot ile aynı)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	_main = current_scene
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(2.5)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 150.0)
		atmo.call("debug_set_weather", 0)
	for n in _main.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = false
	var player: Node2D = _main.get_node("Player")
	player.set("_oakley_flower_auto_timer", 1.0e9)
	var feet_off: float = float((load("res://scripts/depth_occluders.gd") as GDScript).get_script_constant_map()["FEET_OFFSET"])
	for c in _main.find_children("*", "", true, false):
		if c.has_method("max_base_in"):
			var modes: Dictionary = {}
			for f: Dictionary in c.get("fronts"):
				modes["%s:%s" % [f["mode"], (f["layer"] as Node).name]] = true
			print("ONKOPYA ", c.get_path(), " ", modes.keys())
	var cw: int = int(OS.get_environment("AC_W")) if OS.get_environment("AC_W") != "" else 360
	var ch: int = int(OS.get_environment("AC_H")) if OS.get_environment("AC_H") != "" else 300
	var i: int = 0
	for s in OS.get_environment("AC_POINTS").split("|", false):
		var xy: PackedStringArray = s.split(",")
		var pos := Vector2(float(xy[0]), float(xy[1]))
		player.global_position = pos
		await _wait(1.0)
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		await _wait(0.4)
		var got: Vector2 = player.global_position
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var vs: Vector2 = Vector2(img.get_size())
		var sp: Vector2 = player.get_global_transform_with_canvas().origin * (vs / root.get_visible_rect().size)
		var r := Rect2i(int(sp.x) - cw / 2, int(sp.y) - ch * 3 / 5, cw, ch).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var name: String = "ac_%02d.png" % i
		img.get_region(r).save_png(_dir.path_join(name))
		print("SHOT ", name, " istenen ", pos, " oyuncu ", got, " ayak ", got.y + feet_off, " ekran ", sp)
		i += 1
	print("BITTI")
	quit()
