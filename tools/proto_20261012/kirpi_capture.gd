extends SceneTree

## Kirpi'nin (madde 109) GERÇEK ÇİZİCİDE, oyundaki gerçek ölçekle doğrulaması: düz çimen + Matthew.
## KIRPI_CAP_DIR'e TEK PNG yazar (kirpi.png): 4 yön x (dikenler kapalı | açık), yan yana.
## Kullanım (pencere açar, birkaç saniye): Godot --path . -s tools/proto_20261012/kirpi_capture.gd   (KIRPI_CAP_DIR ortam değişkeni)

const TILE := Vector2i(200, 200)

var _dir: String = OS.get_environment("KIRPI_CAP_DIR")
var _player: Node2D = null
var _tiles: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _grab() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * (_player.global_position + Vector2(0, -20)))
	var rect := Rect2i(Vector2i(int(c.x), int(c.y)) - TILE / 2, TILE).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	_tiles.append(img.get_region(rect))


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 3
	gm.selected_character = 43
	gm.selected_pet = "kirpi"
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(126, 176, 84)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_player.scale = Vector2(0.5, 0.5) ## main.tscn'deki gerçek ölçek
	_player.z_index = 1
	scene.add_child(_player)
	_player.global_position = Vector2(3000, 3000)
	_player.set_physics_process(false)
	var k: Node2D = _player.get_node_or_null("Kirpi")
	print("KIRPI dugum=%s olcek=%s" % [k != null, k.global_scale if k else Vector2.ZERO])
	k.is_puppet = true ## diken kararını biz verelim (yaratık taraması kapanışı bozmasın)
	_player.get_node("AnimatedSprite2D").play("idle_down")
	for open in [false, true]:
		for d in ["down", "up", "left", "right"]:
			k.set_open(open)
			k._dir = d
			k._apply_clip()
			await _wait(0.5)
			await _grab()
	var out := Image.create(TILE.x * _tiles.size(), TILE.y, false, Image.FORMAT_RGBA8)
	for i in _tiles.size():
		var t: Image = _tiles[i]
		t.convert(Image.FORMAT_RGBA8)
		out.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i(i * TILE.x, 0))
	out.save_png(_dir.path_join("kirpi.png"))
	print("BITTI kare=%d" % _tiles.size())
	quit()
