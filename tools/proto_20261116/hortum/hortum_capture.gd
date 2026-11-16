extends SceneTree

## Madde 728: Büyücü hortumu "C Toz Şeytanı" GERÇEK ÇİZİCİDE (oyuncu kökü 0,5 + Camera2D zoom 2 = oyundaki ölçek), düz çimen + 4 yaratık.
## tools/proto_20261016/buyucu_capture.gd'nin yalnız hortum kısmı. HR_CAP_DIR'e PNG yazar.
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/proto_20261116/hortum/hortum_run.ps1  (GİZLİ masaüstü, pencere görünmez)

var PlayerScene: PackedScene = null
var EnemyScene: PackedScene = null

var _dir: String = OS.get_environment("HR_CAP_DIR")
var _player: Node2D = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String, w: int = 1100, h: int = 640) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * (_player.global_position + Vector2(90, 0)))
	var rect := Rect2i(int(c.x) - w / 2, int(c.y) - h / 2, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join(name))
	print("SHOT %s %s (pencere %dx%d)" % [name, str(rect.size), img.get_width(), img.get_height()])


func _enemy(scene: Node, pos: Vector2) -> Node2D:
	var e: Node2D = EnemyScene.instantiate()
	scene.add_child(e)
	e.global_position = pos
	e.set("speed", 0.0)
	e.max_health = 600000.0
	e.health = 600000.0
	return e


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	PlayerScene = load("res://scenes/player.tscn") as PackedScene
	EnemyScene = load("res://scenes/creatures/enemy_agac1.tscn") as PackedScene
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 4
	gm.selected_character = 3
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(126, 176, 84)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	_player = PlayerScene.instantiate()
	_player.scale = Vector2(0.5, 0.5) ## main.tscn'deki gerçek ölçek
	_player.z_index = 1
	scene.add_child(_player)
	_player.global_position = Vector2(3000, 3000)
	_player.set_physics_process(false)
	_player.damage_bonus = 100.0
	_player.get("anim").play("idle_right")
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.global_position = _player.global_position + Vector2(90, 0)
	scene.add_child(cam)
	cam.make_current()
	await _wait(0.5)
	var p: Vector2 = _player.global_position
	for off in [Vector2(110, -50), Vector2(170, 40), Vector2(230, -30), Vector2(40, 90)]:
		_enemy(scene, p + off)
	await _wait(0.8)
	_player._skill_buyucu_tornado()
	await _wait(0.13)
	await _shot("oyun_dokum.png")
	await _wait(0.35)
	await _shot("oyun_dogus.png")
	await _wait(1.3)
	await _shot("oyun_1.png")
	await _wait(0.5)
	await _shot("oyun_2.png")
	await _wait(0.9)
	await _shot("oyun_3.png")
	for t in _player.get("_buyucu_active_tornadoes"):
		if is_instance_valid(t):
			t.set("lifetime", float(t.get("_elapsed")) + 0.05)
	await _wait(0.35)
	await _shot("oyun_bitis.png")
	print("BITTI")
	quit()
