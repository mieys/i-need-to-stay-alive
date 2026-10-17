extends SceneTree

## Şovalye E "Yankı Darbesi" (fx_sovalye_echo.gd) + Melek E kalkan kırıntıları (fx_shard_stream.gd) GERÇEK ÇİZİCİDE, oyundaki
## ölçekle (oyuncu kökü 0,5, oyuncunun kamerası, zoom 2): düz çimen + Assasin (dost, baloncuklu) + Şovalye/Melek kuklası.
## SE_CAP_DIR'e iki oyuncunun ortasından kırpılmış PNG'ler yazar. Kullanım (kendi penceresini birkaç saniye açar):
##   Godot --path . -s tools/proto_20261014/sovalye_echo_capture.gd

var _dir: String = OS.get_environment("SE_CAP_DIR")
var _player: Node2D = null
var _other: Node2D = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var mid: Vector2 = (_player.global_position + _other.global_position) * 0.5
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * mid)
	var rect := Rect2i(int(c.x) - 150, int(c.y) - 90, 300, 160).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join(name + ".png"))
	print("SHOT %s %s" % [name, str(rect.size)])


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 4
	gm.selected_character = 4
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(112, 160, 78)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	var harita := Node2D.new()
	harita.name = "Harita"
	scene.add_child(harita)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_player.scale = Vector2(0.5, 0.5)
	scene.add_child(_player)
	_player.global_position = Vector2(3000, 3000)
	_player.set_physics_process(false)
	var link := Node2D.new()
	link.set_script(load("res://scripts/fx_paladin_barrier_link.gd"))
	_player.add_child(link)
	_other = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(_other)
	_other.setup(77, 7, "Sovalye")
	_other.global_position = Vector2(3080, 2988)
	_other._target_position = _other.global_position ## kukla ağ hedefine kayar
	await _wait(0.6)
	var echo_script: GDScript = load("res://scripts/fx_sovalye_echo.gd")
	var fx: Node2D = echo_script.new()
	scene.add_child(fx)
	fx.setup(_player, _other, PI, false)
	await _wait(0.03)
	await _shot("1_yanki_a")
	await _wait(0.1)
	await _shot("1_yanki_b")
	await _wait(0.12)
	await _shot("1_yanki_c")
	await _wait(0.4)
	fx = echo_script.new()
	scene.add_child(fx)
	fx.setup(_player, _other, PI + 0.3, true)
	await _wait(0.05)
	await _shot("2_buyuk_yanki")
	await _wait(0.5)
	## Melek E: Melek kuklası (id 10) -> dost (yerel oyuncu) kalkan kırıntıları
	link.queue_free()
	_other.queue_free()
	_other = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(_other)
	_other.setup(78, 10, "Melek")
	_other.global_position = Vector2(2915, 3010)
	_other._target_position = _other.global_position
	await _wait(0.5)
	var stream: Node2D = (load("res://scripts/fx_shard_stream.gd") as GDScript).new()
	scene.add_child(stream)
	stream.setup(_other.global_position, _player, "melek_shield")
	await _wait(0.15)
	await _shot("3_melek_a")
	await _wait(0.15)
	await _shot("3_melek_b")
	await _wait(0.2)
	await _shot("3_melek_c")
	print("BITTI")
	quit()
