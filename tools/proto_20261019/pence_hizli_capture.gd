extends SceneTree

## Pençe hızlı vuruş teşhisi (2026-10-19): gerçek weapon.gd atışı, saldırı hızı BC_RATE kat (set_fire_rate_mult(1/BC_RATE)); kareler bellekte
## toplanır (disk yazımı kare hızını bozmasın), sonda AC_DIR'e f_<ms>.png olarak yazılır. pence_hizli_run.ps1 gizli masaüstünde koşar.

var _dir: String = OS.get_environment("AC_DIR")
var _rate: float = float(OS.get_environment("BC_RATE")) if OS.get_environment("BC_RATE") != "" else 6.0
var _player: Node2D = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _slime(scene: Node2D, pos: Vector2) -> Node2D:
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	scene.add_child(e)
	e.global_position = pos
	e.set("speed", 0.0)
	e.max_health = 600000.0
	e.health = 600000.0
	return e


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 5
	gm.selected_character = 16
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
	_player.scale = Vector2(0.5, 0.5)
	_player.z_index = 1
	scene.add_child(_player)
	_player.global_position = Vector2(3000, 3000)
	_player.set_physics_process(false)
	_player.call("buy_weapon_copy", "pence", 1)
	var e1: Node2D = _slime(scene, _player.global_position + Vector2(80, 14))
	_slime(scene, e1.global_position + Vector2(40, -20))
	for w in _player.get_children():
		if w.has_method("set_fire_rate_mult") and "_is_pence" in w and w._is_pence:
			w.set_fire_rate_mult(1.0 / _rate)
			print("RATE ", _rate, " fire_rate=", w.fire_rate, " speed_scale=", w._melee_effect_speed_scale(), " wait=", w._effective_fire_wait())
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = _player.global_position + Vector2(50, 10)
	cam.make_current()
	await _wait(1.0)
	var frames: Array = []
	var stamps: Array = []
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1300:
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var c := Vector2(img.get_width(), img.get_height()) * 0.5
		var rect := Rect2i(int(c.x) - 170, int(c.y) - 120, 340, 240).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		frames.append(img.get_region(rect))
		stamps.append(Time.get_ticks_msec() - t0)
	for i in range(frames.size()):
		(frames[i] as Image).save_png(_dir.path_join("f_%03d_%04d.png" % [i, int(stamps[i])]))
	print("BITTI frames=", frames.size())
	quit()
