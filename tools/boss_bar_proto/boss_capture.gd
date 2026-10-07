extends SceneTree

## Gerçek oyundan (SP, ana sahne) boss'lu kareler yakalar: BOSS_CAP_DIR'e PNG + frames.json yazar.
##   current_single.png : mevcut can/kalkan çubuğuyla tek boss
##   single.png         : çubuksuz tek boss (prototiplerin üstüne yerleştirileceği gerçek kare)
##   multi.png          : çubuksuz 3 boss (çoklu boss durumu)
## frames.json: her kare için ekran boyutu + her bossun ekran konumu / çubuk ofseti / can / kalkan.

var _dir: String = OS.get_environment("BOSS_CAP_DIR")
const CHAR_ID := 2


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _screen_pos(n: Node2D) -> Vector2:
	var vp: Viewport = root
	return vp.get_final_transform() * (vp.get_canvas_transform() * n.global_position)


func _shot(name: String) -> Vector2i:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(_dir.path_join(name))
	print("SHOT %s %dx%d" % [name, img.get_width(), img.get_height()])
	return Vector2i(img.get_width(), img.get_height())


func _boss_info(b: Node) -> Dictionary:
	var sp: Vector2 = _screen_pos(b as Node2D)
	return {
		"id": str(b.get_meta("creature_id", "")),
		"screen": [sp.x, sp.y],
		"bar_offset": float(b.call("get_overhead_bar_offset")),
		"max_health": float(b.get("max_health")),
		"max_shield": float(b.get("item_shield_max")),
		"zoom": root.get_final_transform().get_scale().x * root.get_canvas_transform().get_scale().x,
	}


func _spawn_bosses(spawner: Node, player: Node2D, ids: Array, offsets: Array, tier: int) -> Array:
	var list: Array = spawner.call("_spawn_boss_group", ids, tier)
	for i in list.size():
		var b: Node2D = list[i]
		b.global_position = player.global_position + offsets[i]
	return list


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", CHAR_ID)
	var def: Dictionary = load("res://scripts/characters.gd").get_def(CHAR_ID)
	gm.set("selected_character", def.get("skill", 1))
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(2.5)
	## Kayıtlı ayarlar tam ekrana zorluyor olabilir: 1920x1080 pencereli (ölçek 1:1, piksel birebir). Ayarlar KAYDEDİLMEZ.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.5)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	spawner.set("_spawn_timer", 1.0e9)
	player.set("max_health", 1.0e9)
	player.set("health", 1.0e9)
	var frames: Dictionary = {}

	## --- 1) mevcut çubukla tek boss ---
	var single: Array = _spawn_bosses(spawner, player, ["golem3"], [Vector2(240, -70)], 12)
	await _wait(0.4)
	for b in single:
		b.global_position = player.global_position + Vector2(240, -70)
	Engine.time_scale = 0.0
	await _wait(0.3)
	var sz: Vector2i = await _shot("current_single.png")
	frames["current_single"] = {"size": [sz.x, sz.y], "bosses": single.map(func(b): return _boss_info(b))}
	## --- 2) çubuksuz tek boss ---
	for b in single:
		var ob: Node = b.get("_overhead_bar")
		if ob:
			ob.visible = false
	await _wait(0.2)
	sz = await _shot("single.png")
	frames["single"] = {"size": [sz.x, sz.y], "bosses": single.map(func(b): return _boss_info(b))}
	for b in single:
		b.queue_free()
	Engine.time_scale = 1.0
	await _wait(0.5)

	## --- 3) çubuksuz 3 boss ---
	var multi: Array = _spawn_bosses(spawner, player, ["golem3", "agac3", "lich3"],
			[Vector2(250, -60), Vector2(-260, -100), Vector2(-20, 150)], 12)
	await _wait(0.4)
	var offs: Array = [Vector2(250, -60), Vector2(-260, -100), Vector2(-20, 150)]
	for i in multi.size():
		multi[i].global_position = player.global_position + offs[i]
	Engine.time_scale = 0.0
	await _wait(0.3)
	for b in multi:
		var ob2: Node = b.get("_overhead_bar")
		if ob2:
			ob2.visible = false
	await _wait(0.2)
	sz = await _shot("multi.png")
	frames["multi"] = {"size": [sz.x, sz.y], "bosses": multi.map(func(b): return _boss_info(b))}

	var f := FileAccess.open(_dir.path_join("frames.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(frames, "  "))
	f.close()
	print("CAPTURE_DONE")
	Engine.time_scale = 1.0
	quit()
