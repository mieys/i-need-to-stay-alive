extends SceneTree

## Cadı Q (Zehirli Duman) GERÇEK ÇİZİCİ doğrulaması, 4 yön + yerinde durma (2026-10-13 yeniden tasarım: temiz "Kabaran
## Duman", yaratıkların ÜSTÜNDE %50, şişe her yönde cadının tam arkasında). cadi_capture.gd ile aynı kurulum.
## CADI_CAP_DIR'e q_<yon>.png + q_idle.png yazar (oyuncu çevresinden kırpılmış).
##   Godot --path . --windowed --resolution 1280x720 -s tools/proto_20261013/cadi_q_capture.gd
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok - _run'da load edilir.

var _dir: String = OS.get_environment("CADI_CAP_DIR")
var _player: Node2D = null
var _enemy_scene: PackedScene = null


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String, w: int = 420, h: int = 320) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * _player.global_position)
	var rect := Rect2i(int(c.x) - w / 2, int(c.y) - h / 2, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join(name))
	print("SHOT %s %s" % [name, str(rect.size)])


func _enemy(scene: Node, pos: Vector2) -> void:
	var e: Node2D = _enemy_scene.instantiate()
	scene.add_child(e)
	e.global_position = pos
	e.set("speed", 0.0)
	e.max_health = 600000.0
	e.health = 600000.0


## Oyuncunun fizik karesi kapalı (kendi kendine yürümesin): görsel güncellemeleri elle sürülür.
func _drive(sec: float, move: Vector2 = Vector2.ZERO) -> void:
	var t0: int = Time.get_ticks_msec()
	var last: int = t0
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame
		var now: int = Time.get_ticks_msec()
		var dt: float = float(now - last) / 1000.0
		last = now
		_player.global_position += move * dt
		_player._update_animation(move.length() > 0.1)
		_player._process_cadi_visuals(dt)
		_player._process_cadi_q(dt)


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	_enemy_scene = load("res://scenes/creatures/enemy_agac1.tscn") as PackedScene
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 15
	gm.selected_character = 51
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.name = "Harita"
	bg.color = Color8(126, 176, 84)
	bg.size = Vector2(12000, 12000)
	bg.position = Vector2(-1000, -1000)
	scene.add_child(bg)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_player.scale = Vector2(0.5, 0.5) ## main.tscn'deki gerçek ölçek
	_player.z_index = 1 ## main.tscn'deki gerçek katman (duman z 1 + ağaçta oyuncudan önce = oyuncunun altında)
	scene.add_child(_player)
	_player.global_position = Vector2(3000, 1000)
	_player.set_physics_process(false)
	_player.max_health = 1000000.0 ## yanındaki yaratıklar çekim sırasında öldürmesin (ölünce duman kapanır)
	_player.health = 1000000.0
	_player.item_shield_max = 50000.0
	_player.item_shield_hp = 50000.0
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 400:
		await process_frame
	_player.skill_state = "ready"
	_player._cadi_toggle_q()
	var speed: float = _player.get_effective_move_speed()
	var dirs: Dictionary = {"right": Vector2.RIGHT, "left": Vector2.LEFT, "up": Vector2.UP, "down": Vector2.DOWN}
	var i: int = 0
	for f: String in dirs:
		var d: Vector2 = dirs[f]
		var start := Vector2(3000, 1000 + 900 * i)
		i += 1
		_player.global_position = start
		_player.facing = f
		var perp := Vector2(-d.y, d.x)
		## Yolun üstünde iki yaratık: cadı geçince dumanın içinde kalırlar (duman üstlerinde %50 görünmeli).
		_enemy(scene, start + d * 45.0 + perp * 5.0)
		_enemy(scene, start + d * 85.0 - perp * 9.0)
		## Dikey izde sütunun tamamı görünsün: daha uzun yürüyüş + uzun kırpma.
		var vertical: bool = d.x == 0.0
		await _drive(2.6 if vertical else 1.7, d * speed)
		if vertical:
			await _shot("q_%s.png" % f, 300, 560)
		else:
			await _shot("q_%s.png" % f)
	## Yerinde durma: 4 sn boyunca aynı noktaya dökülür - TEK bulut kalmalı (yığılıp cadıyı kapatmamalı).
	_player.global_position = Vector2(3000, 1000 + 900 * i)
	_player.facing = "down"
	await _drive(4.0)
	await _shot("q_idle.png", 300, 560)
	print("BITTI hiz=%s bulut=%d" % [speed, get_nodes_in_group("cadi_smokes").size()])
	quit()
