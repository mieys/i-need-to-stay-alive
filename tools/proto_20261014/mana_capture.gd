extends SceneTree

## Mana Kalkanı "B - Mühür" (madde 148) GERÇEK ÇİZİCİDE, oyundaki gerçek ölçekle (oyuncu kökü 0,5, oyuncunun kamerası):
## düz çimen renginde boş sahne + Assasin. MK_CAP_DIR'e oyuncu çevresinden kırpılmış PNG'ler yazar:
##   1_darbe_sol (Enerji)  2_darbe_kuzey (Standart)  3_kirilma_a / 3_kirilma_b (Savaş)  4_yenilenme (Kale)  5_doldu (Kale)
## Kullanım (kendi penceresini birkaç saniye açar): Godot --path . -s tools/proto_20261014/mana_capture.gd

var _dir: String = OS.get_environment("MK_CAP_DIR")
var _player: Node2D = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * _player.global_position)
	var rect := Rect2i(int(c.x) - 110, int(c.y) - 100, 220, 160).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join(name + ".png"))
	print("SHOT %s %s (pencere %dx%d)" % [name, str(rect.size), img.get_width(), img.get_height()])


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 1
	gm.selected_character = 1
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(112, 160, 78)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	var harita := Node2D.new() ## place_on_ground zemin katmanını "Harita"nın hemen ardına koyar (oyundaki gibi)
	harita.name = "Harita"
	scene.add_child(harita)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_player.scale = Vector2(0.5, 0.5) ## main.tscn'deki gerçek ölçek
	scene.add_child(_player)
	_player.global_position = Vector2(3000, 3000)
	_player.set_physics_process(false)
	var fx: Node2D = _player.get_node("ManaShieldFx")
	await _wait(0.5)
	fx.set_shield_type("shield_enerji")
	fx.hit(PI, false)
	await _wait(0.2)
	await _shot("1_darbe_sol")
	await _wait(0.6)
	fx.set_shield_type("shield_standart")
	fx.hit(-PI / 2.0, false)
	await _wait(0.2)
	await _shot("2_darbe_kuzey")
	await _wait(0.6)
	fx.set_shield_type("shield_savas")
	fx.hit(0.0, true)
	await _wait(0.13)
	await _shot("3_kirilma_a")
	await _wait(0.2)
	await _shot("3_kirilma_b")
	_player.global_position += Vector2(24, 0) ## kırıklar kırıldığı yerde kalmalı
	await _wait(0.5)
	await _shot("3_kirilma_c_yerde")
	await _wait(1.3)
	await _shot("3_kirilma_d_soluyor")
	_player.global_position -= Vector2(24, 0)
	await _wait(1.2)
	fx.set_shield_type("shield_kale")
	_player.item_shield_max = 150.0
	_player.item_shield_hp = 40.0
	await _wait(0.1)
	_player.item_shield_hp = 70.0
	await _wait(0.1)
	_player.item_shield_hp = 95.0
	await _wait(0.35)
	await _shot("4_yenilenme")
	_player.item_shield_hp = 150.0
	await _wait(0.16)
	await _shot("5_doldu")
	print("BITTI")
	quit()
