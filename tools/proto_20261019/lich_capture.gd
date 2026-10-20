extends SceneTree

## Madde 280 gerçek çizici yakalaması: Lich 1 (büyü) + Lich 3 (normal atış) sağdaki oyuncuya ateş eder; kamera zoom 2 (1080p oyun ölçeği).
## Atışlar elle tetiklenir (_fire_ranged_attack / _fire_homing_attack) - yapay zekâ zamanlaması beklenmez. Kareler LICH_CAP_DIR'e.
## Çalıştırma (gizli masaüstü): tools/fps_micro/hidden_launch.ps1 Invoke-GodotHidden ile '--path . -s res://tools/proto_20261019/lich_capture.gd'

var _dir: String = OS.get_environment("LICH_CAP_DIR")
var _cam: Camera2D = null


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
	var rect := Rect2i(int(c.x) - 450, int(c.y) - 200, 900, 400)
	rect = rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join(name))
	print("SHOT %s %s (pencere %dx%d)" % [name, str(rect.size), img.get_width(), img.get_height()])


func _lich(scene: Node2D, path: String, pos: Vector2) -> Node2D:
	var e: Node2D = (load(path) as PackedScene).instantiate()
	scene.add_child(e)
	e.global_position = pos
	e.set("speed", 0.0)
	e.max_health = 600000.0
	e.health = 600000.0
	return e


func _run() -> void:
	await process_frame
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
	var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.scale = Vector2(0.5, 0.5)
	scene.add_child(player)
	player.global_position = Vector2(3100, 3010)
	player.set_physics_process(false)
	player.collision_layer = 2 ## main.tscn'deki Player katmanı (player.tscn'de 0) - mermiler isabet etsin
	if "max_health" in player:
		player.set("max_health", 100000.0)
		player.set("health", 100000.0)
	_cam = Camera2D.new()
	_cam.zoom = Vector2(2, 2)
	scene.add_child(_cam)
	_cam.global_position = Vector2(3000, 3000)
	_cam.make_current()
	var l1 := _lich(scene, "res://scenes/creatures/enemy_lich1.tscn", Vector2(2900, 2965))
	var l3 := _lich(scene, "res://scenes/creatures/enemy_lich3.tscn", Vector2(2900, 3045))
	await _wait(0.6)
	for e in [l1, l3]:
		e.call("_update_facing", Vector2.RIGHT)
	await _wait(0.3)
	l1.call("_fire_ranged_attack", (player.global_position - l1.global_position).normalized(), player)
	l3.call("_fire_homing_attack")
	await _shot("cap_0.png")
	for i in range(1, 4):
		await _wait(0.22)
		await _shot("cap_%d.png" % i)
	for i in range(4, 12):
		await _wait(0.06)
		await _shot("cap_%d.png" % i)
	quit()
