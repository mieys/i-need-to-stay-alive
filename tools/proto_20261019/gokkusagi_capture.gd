extends SceneTree

## Madde 306 gerçek çizici yakalaması: Gökkuşağı Asası (gerçek oyuncu + gerçek silah + gerçek slime, kamera zoom 2 = 1080p oyun ölçeği).
## 1. bölüm: temel (L3: Uzun Kamaşma + Kör Nokta) tek slime - ışın tuttukça kalınlaşır, 3 sn'de kamaşma. 2. bölüm: final (L5) hatta 3 slime -
## ışın delip geçer, 2 sn'de (Hızlı Kamaşma) hepsi kamaşır. Kareler GK_CAP_DIR'e. Çalıştırma: tools/proto_20261019/gokkusagi_run.ps1 (gizli masaüstü).

var _dir: String = OS.get_environment("GK_CAP_DIR")
var _cam: Camera2D = null
var _gm: Node = null ## -s betiği autoload'lardan önce derlenir: GameManager adıyla erişilemez (hafıza)


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * _cam.global_position)
	var rect := Rect2i(int(c.x) - 470, int(c.y) - 190, 940, 380)
	rect = rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join(name))
	print("SHOT %s %s (pencere %dx%d)" % [name, str(rect.size), img.get_width(), img.get_height()])


func _slime(scene: Node2D, pos: Vector2) -> Node2D:
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	scene.add_child(e)
	e.global_position = pos
	e.set("speed", 0.0)
	e.max_health = 600000.0
	e.health = 600000.0
	return e


func _set_ench(player: Node, ench: Dictionary) -> void:
	_gm.owned_weapons[0]["enchant"] = ench
	player.call("_apply_enchant_to_weapon", 0)


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
	if "max_health" in player:
		player.set("max_health", 100000.0)
		player.set("health", 100000.0)
	for w in player.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	player.owned_weapon_nodes.clear()
	_gm.owned_weapons = [{"key": "gokkusagi", "level": 1}]
	player.call("buy_weapon_copy", "gokkusagi", 1)
	_set_ench(player, {"id": "goz_kamastiran", "ups": [1, 2]})
	_cam = Camera2D.new()
	_cam.zoom = Vector2(2, 2)
	scene.add_child(_cam)
	_cam.global_position = Vector2(3080, 2990)
	_cam.make_current()
	## 1) temel
	var s1 := _slime(scene, Vector2(3120, 3020))
	var t0: int = Time.get_ticks_msec()
	for at in [0.5, 1.6, 2.7, 3.12, 3.5, 4.4]:
		while Time.get_ticks_msec() - t0 < int(at * 1000.0):
			await process_frame
		await _shot("temel_%04d.png" % int(at * 1000.0))
		print("Z t=%.2f stun=%s frz=%.2f elite=%s boss=%s kids=%s" % [at, str(s1.get("is_stunned")), float(s1.get("_freeze_timer")), str(s1.get("is_elite")), str(s1.get("is_boss")), str(s1.get_children().map(func(c): return c.name))])
	s1.queue_free()
	await _wait(0.4)
	## 2) final: uçtan geçen hatta 3 slime
	_set_ench(player, {"id": "goz_kamastiran", "ups": [0, 1, 2, 3], "final": true})
	var w: Node = player.owned_weapon_nodes[0]
	var tip: Vector2 = (w.get("muzzle") as Node2D).global_position if w.get("muzzle") != null else w.global_position
	var dir := Vector2(1.0, 0.25).normalized()
	for d in [60.0, 100.0, 140.0]:
		_slime(scene, tip + dir * d + Vector2(0, 8))
	t0 = Time.get_ticks_msec()
	for at in [0.6, 1.4, 2.12, 2.5]:
		while Time.get_ticks_msec() - t0 < int(at * 1000.0):
			await process_frame
		await _shot("final_%04d.png" % int(at * 1000.0))
	print("BITTI")
	quit()
