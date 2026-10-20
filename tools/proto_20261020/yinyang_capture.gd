extends SceneTree

## Madde 334 gerçek çizici yakalaması: Yin Yang Kitabı (gerçek oyuncu + gerçek kitap L3 + gerçek slime, kamera zoom 2 = 1080p oyun ölçeği).
## Üç atış: A kendine (mana kalkanı %20 -> Yang), B dosta (kukla remote_player.tscn, kalkanı %10; sahibi dolu), C Yin (herkes dolu ->
## ak küre de düşmana). Atış elle (_fire_at), her atıştan sonra 0,03-1,05 sn kareler YY_CAP_DIR'e.
## Çalıştırma: tools/proto_20261020/yinyang_run.ps1 (gizli masaüstü).

var _dir: String = OS.get_environment("YY_CAP_DIR")
var _cam: Camera2D = null
var _gm: Node = null ## -s betiği autoload'lardan önce derlenir: GameManager adıyla erişilemez


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * _cam.global_position)
	var rect := Rect2i(int(c.x) - 420, int(c.y) - 220, 840, 440)
	rect = rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join(name))


func _slime(scene: Node2D, pos: Vector2) -> Node2D:
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	scene.add_child(e)
	e.global_position = pos
	e.set("speed", 0.0)
	e.max_health = 600000.0
	e.health = 600000.0
	return e


func _burst(tag: String, w: Node, target: Node2D) -> void:
	w.call("_fire_at", target)
	var t0: int = Time.get_ticks_msec()
	var i: int = 0
	for at in [0.03, 0.08, 0.13, 0.18, 0.23, 0.29, 0.35, 0.42, 0.5, 0.58, 0.66, 0.75, 0.85, 0.95, 1.05]:
		while Time.get_ticks_msec() - t0 < int(at * 1000.0):
			await process_frame
		await _shot("%s_%02d.png" % [tag, i])
		i += 1


func _run() -> void:
	await process_frame
	_gm = root.get_node("GameManager")
	AudioServer.set_bus_mute(0, true)
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(108, 152, 88)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	root.get_node("NetworkManager").set("is_multiplayer_active", false)
	var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.scale = Vector2(0.5, 0.5)
	scene.add_child(player)
	player.global_position = Vector2(3000, 3030)
	player.set_physics_process(false)
	player.set("max_health", 100000.0)
	player.set("health", 100000.0)
	for w0 in player.owned_weapon_nodes.duplicate():
		if is_instance_valid(w0):
			w0.queue_free()
	player.owned_weapon_nodes.clear()
	_gm.owned_weapons = [{"key": "yinyang", "level": 1}]
	player.call("buy_weapon_copy", "yinyang", 1)
	_gm.owned_weapons[0]["enchant"] = {"id": "denge", "ups": [0, 1]}
	player.call("_apply_enchant_to_weapon", 0)
	var w: Node = player.owned_weapon_nodes[0]
	(w.get("fire_timer") as Timer).stop()
	w.set("crit_chance", 0.0)
	_cam = Camera2D.new()
	_cam.zoom = Vector2(2, 2)
	scene.add_child(_cam)
	_cam.global_position = Vector2(3050, 3010)
	_cam.make_current()
	var s1 := _slime(scene, Vector2(3120, 2975))
	await _wait(1.0)
	## A) kendine (Yang: %20)
	player.set("item_shield_max", 100.0)
	player.set("item_shield_hp", 20.0)
	await _burst("a_kendine", w, s1)
	print("A kalkan=%.1f" % float(player.get("item_shield_hp")))
	await _wait(1.4)
	## B) dosta: kukla
	var rp: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(rp)
	rp.set_process(false) ## ağ konumu gelmeyen kukla kendi hedef konumuna (0,0) kayıyordu - yakalamada yerinde dursun
	rp.set_physics_process(false)
	rp.global_position = Vector2(2950, 3075)
	rp.set("peer_id", 7)
	rp.set("item_shield_max", 100.0)
	rp.set("item_shield_hp", 10.0)
	player.set("item_shield_hp", 100.0)
	await _wait(0.4)
	await _burst("b_dosta", w, s1)
	print("B kukla kalkan=%.1f" % float(rp.get("item_shield_hp")))
	await _wait(1.4)
	## C) Yin: herkes dolu
	rp.set("item_shield_hp", 100.0)
	player.set("item_shield_hp", 100.0)
	await _burst("c_yin", w, s1)
	## D) düşman yok (kitap içe çekilir): hedefsiz zamanlayıcı -> yalnız ak küre (YinYangBook.idle_shot)
	s1.queue_free()
	rp.queue_free()
	await _wait(1.6)
	player.set("item_shield_hp", 30.0)
	w.call("_on_fire_timer_timeout")
	var t0: int = Time.get_ticks_msec()
	var i: int = 0
	for at in [0.03, 0.08, 0.13, 0.18, 0.23, 0.29, 0.35, 0.42, 0.5, 0.58, 0.66, 0.75, 0.85, 0.95, 1.05]:
		while Time.get_ticks_msec() - t0 < int(at * 1000.0):
			await process_frame
		await _shot("d_bos_%02d.png" % i)
		i += 1
	print("D kalkan=%.1f" % float(player.get("item_shield_hp")))
	print("BITTI")
	quit()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame
