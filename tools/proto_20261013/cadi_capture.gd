extends SceneTree

## Cadı kitinin GERÇEK ÇİZİCİDE, oyundaki GERÇEK ölçekle (oyuncu kökü 0,5, kamera zoom) görüntü doğrulaması: düz çimen
## renginde boş sahne + Cadı + yaratıklar. CADI_CAP_DIR'e PNG yazar (oyuncu çevresinden kırpılmış):
##   q.png      : Zehirli Duman - eğik şişe + ağızdan dökülen duman + arkada kalan bulutlar (yaratıklar bulutun ÜSTÜNDE)
##   e_<yon>.png: Uçan Süpürge 4 yön (süpürge karakterle aynı piksel yoğunluğunda, oturuş 2 px aşağıda)
##   r.png      : Delilik / Don / Şifa / Korku alanları - ZEMİNDE, yaratıkların ALTINDA (kullanıcı isteği) + patlama
## Kullanım (pencere açar, birkaç saniye):
##   Godot --path . --windowed --resolution 1280x720 -s tools/proto_20261013/cadi_capture.gd   (CADI_CAP_DIR ortam değişkeni)
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar (GameManager, NetworkManager) henüz yok - _run'da load edilir.

var PlayerScene: PackedScene = null
var EnemyScene: PackedScene = null

var _dir: String = OS.get_environment("CADI_CAP_DIR")
var _player: Node2D = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String, w: int = 660, h: int = 460) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * _player.global_position)
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


## Oyuncunun fizik karesi kapalı (kendi kendine yürümesin): görsel güncellemeleri elle sürülür.
func _drive(sec: float, move: Vector2 = Vector2.ZERO, q: bool = false) -> void:
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
		if q:
			_player._process_cadi_q(dt)


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	PlayerScene = load("res://scenes/player.tscn") as PackedScene
	EnemyScene = load("res://scenes/creatures/enemy_agac1.tscn") as PackedScene
	var cm: GDScript = load("res://scripts/cadi_math.gd") as GDScript
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 15
	gm.selected_character = 51
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	## Adı "Harita": zemin efektleri (EnemyAbilities.place_on_ground) oyundaki gibi bunun hemen arkasına yerleşir.
	var bg := ColorRect.new()
	bg.name = "Harita"
	bg.color = Color8(126, 176, 84)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	scene.add_child(bg)
	_player = PlayerScene.instantiate()
	_player.scale = Vector2(0.5, 0.5) ## main.tscn'deki gerçek ölçek
	scene.add_child(_player)
	_player.global_position = Vector2(3000, 3000)
	_player.set_physics_process(false)
	_player.damage_bonus = 100.0
	_player.max_health = 1000000.0 ## yanındaki yaratıklar çekim sırasında öldürmesin (ölünce duman/süpürge kapanır)
	_player.health = 1000000.0
	_player.item_shield_max = 5000.0
	_player.item_shield_hp = 5000.0
	await _wait(0.4)
	## 1) Q: sağa gerçek hızla yürür; yolunda iki yaratık (bulut yaratıkların ALTINDA kalmalı)
	_enemy(scene, _player.global_position + Vector2(60, 14))
	_enemy(scene, _player.global_position + Vector2(20, 22))
	_player.facing = "right"
	_player.skill_state = "ready"
	_player._cadi_toggle_q()
	var speed: float = _player.get_effective_move_speed()
	await _drive(2.2, Vector2(speed, 0.0), true)
	await _shot("q.png", 900, 320)
	_player._cadi_end_q()
	await _drive(0.2)
	## 2) E: 4 yön
	_player.global_position += Vector2(0, 500)
	_player._skill_cadi_broom()
	for f: String in ["down", "left", "right", "up"]:
		_player.facing = f
		await _drive(0.45)
		await _shot("e_%s.png" % f, 240, 220)
	_player._end_cadi_broom()
	await _drive(0.2)
	## 3) R: dört alan + içlerinde yaratık
	_player.global_position += Vector2(0, 500)
	_player.facing = "down"
	await _drive(0.1)
	var opts: Dictionary = {"duration": 4.0, "size": 1.0}
	var base: Vector2 = _player.global_position
	var spots: Dictionary = {0: Vector2(-170, -60), 1: Vector2(-55, -60), 3: Vector2(60, -60), 4: Vector2(175, -60)}
	for kind: int in spots:
		var p: Vector2 = base + spots[kind]
		if kind != 3:
			_enemy(scene, p + Vector2(0, 4))
		_player._on_cadi_bottle_land(kind, p, opts)
	_player.global_position = base + Vector2(60, -52) ## şifa alanının içinde dursun
	await _drive(1.3)
	_player.global_position = base
	await _shot("r.png", 1360, 640)
	_player._on_cadi_bottle_land(2, base + Vector2(0, 70), opts)
	await _wait(0.28)
	await _shot("boom.png", 640, 560)
	await _wait(0.2)
	print("BITTI hiz=%s texel=%s" % [speed, cm.WORLD_TEXEL])
	quit()
