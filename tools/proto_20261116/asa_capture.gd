extends SceneTree

## Madde 749 doğrulaması GERÇEK MAIN'de: Buz (yavaşlayan slime mavi ton), Arcane "C - Kaos Yarığı" (mermi, isabet, her 3. isabette
## yarık + patlama), Zehir "B - Kabarcık" (mermi + puf, isabet, zehirli ölümde bulut + sıçrayan kabarcık). Oyuncu durur, önünde 3 slime.
## Kareler AC_DIR'e oyuncu merkezli kırpılmış (<asa>_<n>.png). Koşturucu: tools/proto_20261116/asa_run.ps1 (gizli masaüstü).

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
	var img: Image = root.get_texture().get_image()
	var w: int = img.get_width()
	var h: int = img.get_height()
	## oyuncu ekranın ortasında (kamera kilitli): sağa doğru geniş kırpma (slime'lar sağda)
	var r := Rect2i(int(w * 0.36), int(h * 0.30), int(w * 0.40), int(h * 0.36))
	img.get_region(r).save_png(_dir.path_join(name))


func _slime(pos: Vector2, hp: float) -> Node2D:
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	e.set("speed", 0.0)
	e.set("max_health", hp)
	_main.add_child(e)
	e.global_position = pos
	e.set("health", hp)
	return e


func _set_weapons(player: Node, keys: Array) -> void:
	for n in player.get("owned_weapon_nodes"):
		if is_instance_valid(n):
			n.queue_free()
	(player.get("owned_weapon_nodes") as Array).clear()
	await process_frame
	## özellik kaydı GameManager girdisinde (oyundaki alım yolu gibi; yoksa asa özelliksiz kalır - Arcane yarığı açılmaz)
	var ed: GDScript = load("res://scripts/enchant_defs.gd")
	var entries: Array = []
	for k in keys:
		entries.append(ed.new_weapon_entry(k, 1, 0))
	_gm.set("owned_weapons", entries)
	for k in keys:
		print("buy ", k, " ", player.call("buy_weapon_copy", k, 1))


func _clear_enemies() -> void:
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.3)


func _burst(prefix: String, n: int, gap: float) -> void:
	for i in n:
		await _shot("%s_%02d.png" % [prefix, i])
		await _wait(gap)


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
	var spot: Vector2 = player.global_position
	await _wait(1.0)
	await _clear_enemies()
	var offs: Array = [Vector2(118.0, -6.0), Vector2(142.0, -26.0), Vector2(150.0, 16.0)]
	## --- BUZ: yavaşlayan slime hafif buz mavisi
	await _set_weapons(player, ["buz_asasi"])
	var buz_sl: Array = []
	for o in offs:
		buz_sl.append(_slime(spot + o, 1.0e9))
	await _wait(0.4)
	for i in 36:
		await _shot("buz_%02d.png" % i)
		var s0: Node = buz_sl[0]
		var spr: CanvasItem = s0.get("anim_sprite") if s0.get("anim_sprite") != null else s0.get("frame_sprite")
		print("BUZDBG %d chill=%s mod=%s slow=%s spr=%s" % [i, str(s0.call("_frost_chill_active")), str(spr.modulate if spr else null),
				str(s0.get("_slow_timer")), str(spr.get_class() if spr else "-")])
		await _wait(0.06)
	await _clear_enemies()
	if OS.get_environment("AC_ONLY") == "buz":
		quit()
		return
	## --- ARCANE C: her 3. isabette yarık
	await _set_weapons(player, ["arcane"])
	for o in offs:
		_slime(spot + o, 1.0e9)
	await _wait(0.2)
	await _burst("arcane", 80, 0.05)
	await _clear_enemies()
	## --- ZEHİR B: ana hedef birkaç atışta ölür (zehirli) -> bulut + kabarcık sıçrar
	await _set_weapons(player, ["tuftuf"])
	var s1: Node2D = _slime(spot + offs[0], 60.0)
	_slime(spot + offs[1], 1.0e9)
	_slime(spot + offs[2], 1.0e9)
	await _wait(0.2)
	await _burst("zehir", 80, 0.05)
	print("s1 dead=", (not is_instance_valid(s1)) or s1.get("is_dead"))
	print("BITTI")
	quit()
