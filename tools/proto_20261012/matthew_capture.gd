extends SceneTree

## Matthew şimşek kitinin (madde 98) GERÇEK ÇİZİCİDE, oyundaki GERÇEK ölçekle (oyuncu kökü 0,5, kamera zoom) görüntü doğrulaması:
## düz çimen renginde boş sahne + Matthew + iki yaratık. MT_CAP_DIR'e PNG yazar (oyuncu çevresinden kırpılmış):
##   kalkan.png : Yıldırım Kalkanı (%70 yıpranmış -> parıltı)      iz.png  : güçlenmiş + normal yıldırım izi
##   top.png    : Elektrik Topu + isabet                            q.png   : Şimşek Hücumu (kalın evre)
## Kullanım (pencere açar, birkaç saniye): Godot --path . -s tools/proto_20261012/matthew_capture.gd   (MT_CAP_DIR ortam değişkeni)

## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar (GameManager, NetworkManager) henüz yok - _run'da load edilir.
var PlayerScene: PackedScene = null
var EnemyScene: PackedScene = null

var _dir: String = OS.get_environment("MT_CAP_DIR")
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
	var rect := Rect2i(int(c.x) - 330, int(c.y) - 230, 660, 460).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
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
	gm.selected_char_id = 3
	gm.selected_character = 43
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
	await _wait(0.4)
	## 1) kalkan + parıltı
	_player._skill_shield_dome()
	_player.matthew_dome_hp = _player.matthew_dome_max * 0.3
	_player._matthew_update_glow()
	await _wait(0.9)
	await _shot("kalkan.png")
	_player._pop_matthew_dome(false)
	_player._matthew_update_glow()
	await _wait(0.6)
	## 2) iz: önce normal, sonra güçlenmiş (sağa doğru gerçek hızla yürür)
	_player._process_matthew_lightning(0.016)
	var trail: Node = _player.get("_matthew_trail")
	var speed: float = _player.get_effective_move_speed()
	for pass_i in range(2):
		trail.set("level", 1 + pass_i)
		trail.set("intensity", 0.5 + 0.5 * pass_i)
		var t0: int = Time.get_ticks_msec()
		var last: int = t0
		while Time.get_ticks_msec() - t0 < 1300:
			await process_frame
			var now: int = Time.get_ticks_msec()
			_player.global_position.x += speed * float(now - last) / 1000.0
			last = now
		await _shot("iz_%d.png" % (pass_i + 1))
		trail.set("level", 0)
		await _wait(1.2)
	## 3) top + isabet
	var a: Node2D = _enemy(scene, _player.global_position + Vector2(26, -2))
	_enemy(scene, _player.global_position + Vector2(110, -2))
	_player._skill_matthew_ball()
	_player.velocity = Vector2(120, 0)
	await _wait(0.35)
	_player._process_matthew_ball(0.016)
	await _wait(0.07)
	await _shot("top.png")
	await _wait(0.5)
	_player._end_matthew_ball()
	_player.velocity = Vector2.ZERO
	await _wait(0.5)
	## 4) Q
	a.global_position = _player.global_position + Vector2(120, -60)
	_player._skill_matthew_lightning_strike()
	await _wait(0.07)
	await _shot("q.png")
	await _wait(0.3)
	print("BITTI hiz=%s" % speed)
	quit()
