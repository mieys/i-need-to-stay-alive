extends SceneTree

## Büyücü Kız yeni efektlerinin (madde 188) GERÇEK ÇİZİCİDE, oyundaki gerçek ölçekle (oyuncu kökü 0,5, kamera zoom) görüntü doğrulaması:
## düz çimen + Büyücü (Ateş Asası / Tabanca / Yay) + çevrede 4 yaratık. BY_CAP_DIR'e PNG yazar (oyuncu çevresinden kırpılmış).
## Kullanım (ayrı bir Godot penceresi açar, ~15 sn): Godot --path . -s tools/proto_20261016/buyucu_capture.gd   (BY_CAP_DIR ortam değişkeni)
## elara_capture.gd ile aynı kurulum; sahneler preload EDİLMEZ (autoload'lar -s derlenirken yok).

var PlayerScene: PackedScene = null
var EnemyScene: PackedScene = null

var _dir: String = OS.get_environment("BY_CAP_DIR")
var _player: Node2D = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String, w: int = 660, h: int = 420) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * _player.global_position)
	var rect := Rect2i(int(c.x) - w / 2, int(c.y) - h / 2 - 40, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
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
	for k in ["fire_staff", "tabanca", "yay"]:
		if not _player.call("buy_weapon_copy", k, 1):
			print("silah eklenemedi: ", k)
	await _wait(0.5)
	var p: Vector2 = _player.global_position
	for off in [Vector2(110, -50), Vector2(170, 40), Vector2(230, -30), Vector2(-120, 60)]:
		_enemy(scene, p + off)
	await _wait(0.8)
	## 1) E Arcane Lanet (Set 1): göz, iz, mühür, lanet ipi
	_player._skill_buyucu_arcane_curse()
	await _wait(0.07)
	await _shot("e_lanet_1.png")
	await _wait(0.12)
	await _shot("e_lanet_2.png")
	await _wait(0.2)
	await _shot("e_lanet_3.png")
	## 2) Pasif: dalga + güçlendirilmiş atış
	_player._buyucu_on_skill_used("skill2", 0)
	await _wait(0.12)
	await _shot("pasif_1.png")
	await _wait(0.12)
	await _shot("pasif_2.png")
	await _wait(0.15)
	await _shot("pasif_3.png")
	await _wait(1.0)
	## 3) Q: Set 2'ye (sıcak)
	_player._skill_buyucu_switch_variation()
	await _wait(0.3)
	await _shot("q_sicak_1.png", 300, 240)
	await _wait(0.3)
	await _shot("q_sicak_2.png", 300, 240)
	await _wait(1.2)
	## 4) E Hortum
	_player._skill_buyucu_tornado()
	await _wait(0.2)
	await _shot("hortum_dogus.png")
	await _wait(1.6)
	await _shot("hortum_1.png")
	await _wait(0.8)
	await _shot("hortum_2.png")
	for t in _player.get("_buyucu_active_tornadoes"):
		if is_instance_valid(t):
			t.set("lifetime", float(t.get("_elapsed")) + 0.05)
	await _wait(0.45)
	await _shot("hortum_bitis.png")
	await _wait(1.0)
	## 5) R Meteor (Set 2): kanal çemberi + korlar, uyarı, düşen kaya, patlama/halka/krater (fizik kapalı - meteorlar elle)
	_player._skill_buyucu_meteor()
	await _wait(0.5)
	await _shot("meteor_kanal.png")
	_player._spawn_buyucu_meteor_strike()
	await _wait(0.25)
	await _shot("meteor_dusus.png")
	_player._spawn_buyucu_meteor_strike()
	await _wait(0.3)
	await _shot("meteor_isabet.png")
	await _wait(0.4)
	await _shot("meteor_krater.png")
	await _wait(1.8)
	await _shot("meteor_bitis.png")
	_player._buyucu_meteor_channel_active = false
	_player.is_buyucu_channeling = false
	await _wait(1.0)
	## 6) Q: Set 1'e (soğuk)
	_player._skill_buyucu_switch_variation()
	await _wait(0.3)
	await _shot("q_soguk.png", 300, 240)
	print("BITTI")
	quit()
