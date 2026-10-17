extends SceneTree

## Melek Q/E SİHİRLİ BAĞ (madde 212) GERÇEK ÇİZİCİDE, oyundaki ölçekte (oyuncu kökü 0,5, oyuncunun kamerası zoom 2):
## düz çimen + Melek (yerel Player) + dost kuklası (Şovalye). MB_CAP_DIR'e oyuncu çevresinden kırpılmış PNG yazar:
##   q_kurulus / q_bag / q_dalga / q_varis : Can Basma (baş koşuyor, bağ + halka + yeşil hale, tikte yoldaki paket, varış)
##   e_bag / e_dalga / e_sol               : Kalkan Yenileme (mavi), dost solda-yukarıda (halenin SOL pikselinden çıkmalı)
## Kullanım (pencere açar, ~8 sn): Godot --path . -s tools/proto_20261017/melek_bond_capture.gd   (MB_CAP_DIR ortam değişkeni)
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok - _run'da load edilir.

var _dir: String = OS.get_environment("MB_CAP_DIR")
var _player: Node2D = null
var _ally: Node2D = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	## kamera iki karakterin ortasında -> görüntü merkezi
	var c := Vector2(img.get_width(), img.get_height()) * 0.5
	var rect := Rect2i(int(c.x) - 330, int(c.y) - 170, 660, 340).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join(name))
	print("SHOT %s %s" % [name, str(rect.size)])


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 10
	gm.selected_character = 1
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
	scene.add_child(_player)
	_player.global_position = Vector2(3000, 3000)
	_player.set_physics_process(false)
	_player.damage_bonus = 60.0
	_ally = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(_ally)
	_ally.setup(77, 7, "Dost")
	_ally.global_position = _player.global_position + Vector2(100, 8)
	_ally.set("_target_position", _ally.global_position) ## kukla ağ hedefine kayar - yerinde dursun
	_ally.set("health", 30.0)
	_ally.set("item_shield_max", 100.0)
	_ally.set("item_shield_hp", 10.0)
	var cam := Camera2D.new() ## oyuncunun kamerası gibi zoom 2, ikisinin ortasında
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = (_player.global_position + _ally.global_position) * 0.5 + Vector2(0, -20)
	cam.make_current()
	await _wait(0.5)
	## Q
	_player.skill_state = "active"
	_player.skill_timer = 6.0
	_player._skill_heal()
	await _wait(0.22)
	await _shot("q_kurulus.png")
	await _wait(0.5)
	await _shot("q_bag.png")
	await _wait(0.28)
	_player._spawn_wave_beam_to_ally(_ally, "heal") ## tik (fizik kapalı - gerçek tik yolunu elle çağır)
	await _wait(0.27)
	await _shot("q_dalga.png")
	await _wait(0.42)
	await _shot("q_varis.png")
	_player._end_skill_effects()
	_player.skill_state = "cooldown"
	await _wait(0.9)
	## E
	_player.skill2_state = "active"
	_player.skill2_timer = 6.0
	_player._skill_kalkan_yenileme()
	await _wait(0.7)
	await _shot("e_bag.png")
	await _wait(0.2)
	_player._spawn_wave_beam_to_ally(_ally, "shield")
	await _wait(0.3)
	await _shot("e_dalga.png")
	_ally.global_position = _player.global_position + Vector2(-95, -34)
	_ally.set("_target_position", _ally.global_position)
	cam.global_position = (_player.global_position + _ally.global_position) * 0.5 + Vector2(0, -20)
	await _wait(0.5)
	await _shot("e_sol.png")
	print("BITTI")
	quit()
