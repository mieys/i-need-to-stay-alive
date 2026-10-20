extends SceneTree

## Asa ucu partikülleri GERÇEK MAIN'de (madde 299): oyun açılır, yaratıklar temizlenir, oyuncuya Ateş + Buz + Arcane asası verilir,
## görüşte ama menzil dışında 1 slime (silahlar açık), oyuncu sağa yürür (gerçek girdi) -> ac_yuru_<n>.png; sonra Yıldırım asası,
## slime menzile alınır (ışın) ve oyuncu yukarı-aşağı kayar -> ac_isin_<n>.png. Çekimler AC_DIR'e (tam pencere).
## Koşturucu: tools/proto_20261019/asa_run.ps1 (gizli masaüstü, APPDATA yalıtılır).

var _dir: String = OS.get_environment("AC_DIR")
var _gm: Node = null
var _main: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join(name))
	print("SHOT ", name)


func _slime(pos: Vector2) -> Node2D:
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	e.set("speed", 0.0)
	e.set("max_health", 1.0e9)
	_main.add_child(e)
	e.global_position = pos
	e.set("health", 1.0e9)
	return e


func _set_weapons(player: Node, keys: Array) -> void:
	for n in player.get("owned_weapon_nodes"):
		if is_instance_valid(n):
			n.queue_free()
	(player.get("owned_weapon_nodes") as Array).clear()
	await process_frame
	for k in keys:
		print("buy ", k, " ", player.call("buy_weapon_copy", k, 1))


func _run() -> void:
	await process_frame
	_gm = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", 2)
	_gm.set("selected_character", (load("res://scripts/characters.gd") as GDScript).get_def(2).get("skill", 1))
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true)
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
	var player: Node2D = _main.get_node("Player")
	player.set("_oakley_flower_auto_timer", 1.0e9)
	## Evden çıkış noktası (avlu, açık çimen). 3616,2000 saklanma çalılığının içiydi (silahlar içe çekili); 3560,1805 plato tepesinin
	## (Orman parçaları 2, karakterlerin üstünde) altı.
	var spot: Vector2 = player.global_position
	await _wait(1.0)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.5)
	await _set_weapons(player, ["fire_staff", "buz_asasi", "arcane"])
	var sl: Node2D = _slime(spot + Vector2(290.0, -40.0)) ## görüşte (350 x 250 elips), asa menzili dışında
	await _wait(1.5)
	Input.action_press("move_right")
	for i in 4:
		await _wait(0.25)
		await _shot("ac_yuru_%d.png" % i)
	Input.action_release("move_right")
	await _wait(0.3)
	await _shot("ac_dur.png")
	Input.action_press("move_left")
	await _wait(0.45)
	await _shot("ac_sola.png")
	Input.action_release("move_left")
	# Yıldırım
	await _set_weapons(player, ["lightning_staff"])
	sl.global_position = player.global_position + Vector2(120.0, 10.0)
	await _wait(1.6)
	for i in 3:
		await _wait(0.15)
		await _shot("ac_isin_%d.png" % i)
	Input.action_press("move_up")
	await _wait(0.35)
	await _shot("ac_isin_yuru.png")
	Input.action_release("move_up")
	print("BITTI")
	quit()
