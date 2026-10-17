extends SceneTree

## Assasin pasifi "Bıçak Uzmanlığı" görselinin (2026-10-16) GERÇEK ÇİZİCİDE, oyun ölçeğinde (kök 0,5, kamera zoom 2) doğrulaması.
## Pasif iki kez tetiklenir (bekleme pozunda, sonra koşu klibinde); 3,3 sn boyunca her 2 karede bir ASSASIN_CAP_DIR/p_###.png.
## Kullanım (pencere açar, ~8 sn): Godot --path . -s tools/proto_20261016/assasin_passive_capture.gd   (ASSASIN_CAP_DIR ortam değişkeni)

const CROP := Vector2i(220, 220)
const ORIGIN := Vector2(3000, 3000)

var _dir: String = OS.get_environment("ASSASIN_CAP_DIR")
var _player: Node2D = null
var _n: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _grab() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * ORIGIN)
	var rect := Rect2i(Vector2i(int(c.x), int(c.y)) - CROP / 2, CROP).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join("p_%03d.png" % _n))
	_n += 1


func _record(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame
		await _grab()


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 5
	gm.selected_character = 5
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(108, 156, 74)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_player.scale = Vector2(0.5, 0.5)
	_player.z_index = 1
	scene.add_child(_player)
	_player.global_position = ORIGIN
	_player.set_physics_process(false)
	var own_cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if own_cam:
		own_cam.enabled = false
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = ORIGIN
	cam.make_current()
	var spr: AnimatedSprite2D = _player.get_node("AnimatedSprite2D")
	spr.play("idle_down")
	for _i in range(10):
		await process_frame
	_player.call("_assasin_passive_on_skill_used")
	await _record(1.2)
	spr.play("run_right")
	_player.call("_assasin_passive_on_skill_used")
	await _record(3.3)
	print("BITTI kare=%d" % _n)
	quit()
