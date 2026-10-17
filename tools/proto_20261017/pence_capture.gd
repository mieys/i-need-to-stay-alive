extends SceneTree

## Pençe "Kanca Çekiş" (madde 237) GERÇEK ÇİZİCİDE, oyundaki ölçekte (oyuncu kökü 0,5, kamera zoom 2):
##   üstte yerel oyuncu + pençe (gerçek weapon.gd atışı, sağdaki slime'a; yanında alan içinde ikinci slime), altta uzak kukla
##   (remote_player.gd) SOLA vurur (dikey aynalama) - ağdan gelecek "weapon_fire" verisiyle (MP yolu). Kareler BC_CAP_DIR'e f_<ms>.png.
## Kullanım (pencere açar, ~4 sn): Godot --path . -s tools/proto_20261017/pence_capture.gd   (BC_CAP_DIR ortam değişkeni)
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok - _run'da load edilir.

var _dir: String = OS.get_environment("BC_CAP_DIR")
var _player: Node2D = null
var _puppet: Node2D = null


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
	_puppet = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(_puppet)
	_puppet.setup(77, 5, "Dost")
	_puppet.global_position = _player.global_position + Vector2(150, 110)
	_puppet.set("_target_position", _puppet.global_position)
	_puppet.call("update_weapon_visuals", ["pence"])
	var e2: Node2D = _slime(scene, _puppet.global_position + Vector2(-80, 14))
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = _player.global_position + Vector2(70, 60)
	cam.make_current()
	await _wait(1.0)
	var t0: int = Time.get_ticks_msec()
	var puppet_fired := false
	while Time.get_ticks_msec() - t0 < 3400:
		var ms: int = Time.get_ticks_msec() - t0
		if not puppet_fired and ms > 500:
			puppet_fired = true
			var icons: Array = _puppet.get("_weapon_icons")
			var from: Vector2 = (icons[0] as Node2D).global_position if icons.size() > 0 else _puppet.global_position
			var d: Vector2 = (e2.global_position - from).normalized()
			_puppet.call("_animate_weapon_fire_full", {"slot_index": 0, "direction_x": d.x, "direction_y": d.y,
				"target_pos_x": e2.global_position.x, "target_pos_y": e2.global_position.y, "hold_duration": 0.0,
				"pence_size": 1.0, "pence_speed": 1.0})
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var c := Vector2(img.get_width(), img.get_height()) * 0.5
		var rect := Rect2i(int(c.x) - 330, int(c.y) - 230, 660, 460).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		img.get_region(rect).save_png(_dir.path_join("f_%05d.png" % ms))
		await process_frame
	print("BITTI")
	quit()
