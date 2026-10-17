extends SceneTree

## Madde 201 gerçek çizici yakalaması: gerçek ölçekli oyuncu (kök 0,5) + gerçek silahlar (buy_weapon_copy) + hareketsiz yaratıklar;
## silahlar kendiliğinden ateş eder (weapon.gd _fire_at: sahip ölçeği, eski çapraz ofset, iz, parçacık) -> uçuş ortasında kareler.
## Çalıştırma: MERMI_CAP_DIR=<klasör> MERMI_SET=0|1|2 Godot --path . -s tools/proto_20261017/mermi_capture.gd
## (set 0: tabanca/tufek/tuftuf, 1: yay/crossbow/arcane, 2: buz_asasi/fisek). Birkaç saniye pencere açar.

const SETS := [["tabanca", "tufek", "tuftuf"], ["yay", "crossbow", "arcane"], ["buz_asasi", "fisek"]]

var _dir: String = OS.get_environment("MERMI_CAP_DIR")
var _set: int = int(OS.get_environment("MERMI_SET"))
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
	var rect := Rect2i(int(c.x) - 120, int(c.y) - 200, 760, 360)
	if _set == 3:
		rect = Rect2i(int(c.x) - 40, int(c.y) - 260, 760, 560)
	rect = rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join(name))
	print("SHOT %s %s (pencere %dx%d)" % [name, str(rect.size), img.get_width(), img.get_height()])


## MERMI_SET=3: yedi mermi sahnesi weapon.gd _fire_at gibi (sahip ölçeği 0,5 + silahın eski çapraz ofseti + yön) AYNI ANDA, alt alta
## şeritlerde fırlatılır; ~0,1 / 0,2 sn sonra tek karede hepsi uçuşta.
const DIRECT := [["tabanca_projectile", -0.005471964169398338], ["tufek_projectile", -0.005471964169398338], ["dart_projectile", -2.351331587385021],
		["arrow_projectile", 0.0], ["arcane_projectile", -2.303834613], ["ice_bolt_projectile", 0.0], ["firework_projectile", 0.0]]


func _direct(scene: Node2D) -> void:
	await _wait(0.4)
	var o: Vector2 = _player.global_position + Vector2(20, -80)
	for i in range(DIRECT.size()):
		var p: Node2D = (load("res://scenes/%s.tscn" % DIRECT[i][0]) as PackedScene).instantiate()
		p.set("impact_sounds", [] as Array[AudioStream])
		scene.add_child(p)
		var dir := Vector2.RIGHT.rotated(-0.35 if i % 2 == 0 else 0.25)
		p.global_position = o + Vector2(0, i * 26)
		p.set("direction", dir)
		if DIRECT[i][0] == "firework_projectile":
			p.set("target_position", p.global_position + Vector2(170, 0))
		else:
			p.rotation = dir.angle() + float(DIRECT[i][1])
		p.scale *= 0.5
	for i in range(4):
		await _wait(0.07)
		await _shot("direct_%d.png" % i)


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 8
	gm.selected_character = 12
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(108, 152, 88)
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
	if _set == 3:
		await _direct(scene)
		quit()
		return
	for k in SETS[_set]:
		if not _player.call("buy_weapon_copy", k, 1):
			print("silah eklenemedi: ", k)
	var es: PackedScene = load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene
	for off in [Vector2(150, -30), Vector2(175, 25), Vector2(130, 60)]:
		var e: Node2D = es.instantiate()
		scene.add_child(e)
		e.global_position = _player.global_position + off
		e.set("speed", 0.0)
		e.max_health = 600000.0
		e.health = 600000.0
	await _wait(1.4)
	for i in range(int(OS.get_environment("MERMI_N")) if OS.get_environment("MERMI_N") != "" else 10):
		await _shot("set%d_%02d.png" % [_set, i])
	quit()
