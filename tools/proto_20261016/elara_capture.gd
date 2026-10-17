extends SceneTree

## Elara Q/E/R efektlerinin (madde 178) GERÇEK ÇİZİCİDE, oyundaki GERÇEK ölçekle (oyuncu kökü 0,5, kamera zoom) görüntü doğrulaması:
## düz çimen renginde boş sahne + Elara (Yay/Tabanca/Tüfek) + sağda iki yaratık. EL_CAP_DIR'e PNG yazar (oyuncu çevresinden kırpılmış).
## Kullanım (ayrı bir Godot penceresi açar, ~15 sn): Godot --path . -s tools/proto_20261016/elara_capture.gd   (EL_CAP_DIR ortam değişkeni)
## matthew_capture.gd ile aynı kurulum; sahneler preload EDİLMEZ (autoload'lar -s derlenirken yok).

var PlayerScene: PackedScene = null
var EnemyScene: PackedScene = null

var _dir: String = OS.get_environment("EL_CAP_DIR")
var _player: Node2D = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


## Oyundaki gibi FİZİK adımında yürütür (oyuncu interpolasyonlu çizilir) ve player.gd _physics_process başındaki gibi
## _interp_prev_pos/_interp_prev_frame'i doldurur (PhysicsInterp.visual_position); koşu klibi oynar.
func _move(sec: float, vx: float) -> void:
	var anim: AnimatedSprite2D = _player.get("anim")
	anim.play("run_right" if vx > 0.0 else "run_left")
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await physics_frame
		_player._interp_prev_pos = _player.global_position
		_player._interp_prev_frame = Engine.get_physics_frames()
		_player.global_position.x += vx / float(Engine.physics_ticks_per_second)
		_player.velocity = Vector2(vx, 0.0)
	_player.velocity = Vector2.ZERO
	anim.play("idle_right")


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * _player.global_position)
	var rect := Rect2i(int(c.x) - 330, int(c.y) - 260, 660, 420).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
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
	gm.selected_char_id = 8
	gm.selected_character = 12
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
	for k in ["yay", "tabanca", "tufek"]:
		if not _player.call("buy_weapon_copy", k, 1):
			print("silah eklenemedi: ", k)
	await _wait(0.5)
	print("silahlar: ", _player.owned_weapon_nodes.size())
	## 1) Q Sıvışma: girdap, koşu (ardıl görüntü + çizgiler), bitiş esintisi
	_player._skill_elara_evasion()
	await _move(0.12, 95.0)
	await _shot("q_baslangic.png")
	await _move(0.5, 95.0)
	await _shot("q_kosu.png")
	_player._elara_evasion_timer = 0.0
	await _wait(0.12)
	await _shot("q_bitis.png")
	await _wait(0.6)
	## yaratıklar menzile (silahlar ateş etsin)
	_enemy(scene, _player.global_position + Vector2(150, -40))
	_enemy(scene, _player.global_position + Vector2(170, 30))
	await _wait(0.6)
	## 2) E: kilit (silah parantezleri), sürerken (halka + parıltı + kehribar iz)
	_player._skill_elara_true_damage()
	await _wait(0.2)
	await _shot("e_kilit.png")
	await _wait(1.1)
	await _shot("e_surer.png")
	await _wait(0.45)
	await _shot("e_surer2.png")
	_player.elara_true_damage_active = false
	await _wait(0.8)
	## 3) R: çapraz oklar, sürerken (ikiz oklar + silah ikizleri + turkuaz ikinci tetik)
	_player._skill_elara_double_fire()
	await _wait(0.12)
	await _shot("r_capraz.png")
	await _wait(1.2)
	await _shot("r_surer.png")
	await _wait(0.4)
	await _shot("r_surer2.png")
	_player.elara_double_fire_active = false
	await _wait(1.3)
	await _shot("r_bitis.png")
	print("BITTI")
	quit()
