extends SceneTree

## Ruh hâli görünüş PROTOTİPLERİ yakalaması (oyuna bağlı DEĞİL): gerçek Main, tek oyunculu; karakter normal -> ŞU AN (oyundaki limbo_fx)
## -> A/B/C/D (ruh_proto_fx.gd) aynı sahnede, her biri 24 kare (~2 sn). Çıktı RH_OUT/<c>_<etiket>_<nn>.png (karakter çevresi 128x128).
## Koşturucu: ruh_proto_run.ps1 (gizli masaüstü), birleştirme: ruh_proto_gif.py.

const ProtoFx := preload("res://tools/proto_20261107/ruh_hali/ruh_proto_fx.gd")
const FRAMES := 24
const STEP := 1.0 / 12.0
const CROP := 150

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


func _frames(anim: AnimatedSprite2D, tag: String) -> void:
	for i in FRAMES:
		var t0: int = Time.get_ticks_msec()
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		## tuval -> pencere pikseli: kök görüntü alanının ölçekleme (stretch) dönüşümü de çarpılır
		var c: Vector2 = root.get_final_transform() * (anim.get_global_transform_with_canvas() * anim.offset)
		if i == 0:
			print("RH merkez ", c, " görüntü ", img.get_size())
		var r := Rect2i(Vector2i(c) - Vector2i(CROP / 2, CROP / 2 + 18), Vector2i(CROP, CROP))
		img.get_region(r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))).save_png(_out.path_join("%s_%02d.png" % [tag, i]))
		var left: float = STEP - float(Time.get_ticks_msec() - t0) / 1000.0
		if left > 0.0:
			await _wait(left)
	print("RH frames ", tag)


func _run() -> void:
	await process_frame
	_gm = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	for cs in OS.get_environment("RH_CHARS").split(","):
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
	var player: Node2D = main.get_node("Player") as Node2D
	var anim: AnimatedSprite2D = player.get("anim")
	var shield: Node = player.get_node_or_null("ShieldVisual")
	if shield is CanvasItem:
		(shield as CanvasItem).visible = false ## kalkan baloncuğu karşılaştırmayı örtmesin
	var hud: Node = main.get_node_or_null("HUD")
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = false
	await _frames(anim, "c%d_0normal" % char_id)
	main.call("_show_level_up_screen", int(_gm.get("team_level")))
	await _wait(0.2)
	for c in main.get_children():
		if c is CanvasLayer and (String(c.name).begins_with("LevelUpScreen") or String(c.name).begins_with("LevelMarket")):
			(c as CanvasLayer).offset = Vector2(100000, 0) ## ekran görünür kalsın (okuma klibi), kadrajda olmasın
	if shield is CanvasItem:
		(shield as CanvasItem).visible = false
	await _wait(1.2)
	await _frames(anim, "c%d_1suan" % char_id)
	load("res://scripts/limbo_fx.gd").detach(player)
	await _wait(0.1)
	var tags: Array = ["2A", "3B", "4C", "5D"]
	for st in 4:
		var fx := Node2D.new()
		fx.set_script(ProtoFx)
		fx.set("style", st)
		fx.set("src", anim)
		player.add_child(fx)
		await _wait(0.4)
		await _frames(anim, "c%d_%s" % [char_id, tags[st]])
		fx.queue_free()
		await process_frame


func _find(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var r: Node = _find(c, method)
		if r:
			return r
	return null
