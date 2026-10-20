extends SceneTree

## Mızrak "Işık Hattı" + cirit (madde 305) GERÇEK ÇİZİCİDE, oyundaki ölçekte (oyuncu kökü 0,5, kamera zoom 2):
##   üstte yerel oyuncu + mızrak (gerçek weapon.gd atışı; sağda hedef + hattında 2 slime + hattın yanında 1), Cirit gösterim için her
##   2. saplamada; altta uzak kukla (remote_player.gd) SOLA saplar, sonra fırlatır - ağdan gelecek "weapon_fire" verisiyle (MP yolu).
##   Kareler MZ_CAP_DIR'e f_<ms>.png.
## Kullanım (gizli masaüstünde): tools/fps_micro/hidden_launch.ps1 Invoke-GodotHidden ile -s tools/proto_20261019/mizrak_capture.gd
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok - _run'da load edilir.

var _dir: String = OS.get_environment("MZ_CAP_DIR")
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


func _puppet_fire(e2: Node2D, extra: Dictionary) -> void:
	var d: Vector2 = (e2.global_position - _puppet.global_position).normalized() ## kaster yönü karakterden hedefe gönderir
	var data: Dictionary = {"slot_index": 0, "direction_x": d.x, "direction_y": d.y, "target_pos_x": e2.global_position.x,
		"target_pos_y": e2.global_position.y, "hold_duration": 0.0, "mizrak_size": 1.0, "mizrak_speed": 1.0}
	data.merge(extra, true)
	_puppet.call("_animate_weapon_fire_full", data)


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 1
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(108, 152, 88)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	var ed: GDScript = load("res://scripts/enchant_defs.gd")
	gm.set("owned_weapons", [ed.call("new_weapon_entry", "mizrak", 1, 0)])
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_player.scale = Vector2(0.5, 0.5)
	_player.z_index = 1
	scene.add_child(_player)
	_player.global_position = Vector2(3000, 3000)
	_player.set_physics_process(false)
	for w in (_player.get("owned_weapon_nodes") as Array).duplicate():
		if is_instance_valid(w):
			w.queue_free()
	(_player.get("owned_weapon_nodes") as Array).clear()
	_player.call("buy_weapon_copy", "mizrak", 1)
	var w: Node = (_player.get("owned_weapon_nodes") as Array)[0]
	var beh: Node = w.get("enchant_behavior")
	if beh:
		(beh.get("stats") as Dictionary)["cirit_every"] = 2 ## gösterim: her 2. saplama cirit (oyunda 4.)
	var e1: Node2D = _slime(scene, _player.global_position + Vector2(95, 12))
	var dirv: Vector2 = (e1.global_position - _player.global_position).normalized()
	_slime(scene, e1.global_position + dirv * 36.0)
	_slime(scene, e1.global_position + dirv * 70.0)
	_slime(scene, e1.global_position + dirv * 26.0 + dirv.orthogonal() * 32.0)
	_puppet = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(_puppet)
	_puppet.setup(77, 5, "Dost")
	_puppet.global_position = _player.global_position + Vector2(260, 120)
	_puppet.set("_target_position", _puppet.global_position)
	_puppet.call("update_weapon_visuals", ["mizrak"])
	var e2: Node2D = _slime(scene, _puppet.global_position + Vector2(-95, 12))
	var dl: Vector2 = (e2.global_position - _puppet.global_position).normalized()
	_slime(scene, e2.global_position + dl * 40.0)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = _player.global_position + Vector2(140, 70)
	cam.make_current()
	await _wait(0.8)
	var t0: int = Time.get_ticks_msec()
	var fired: int = 0
	while Time.get_ticks_msec() - t0 < 4200:
		var ms: int = Time.get_ticks_msec() - t0
		if fired == 0 and ms > 300:
			fired = 1
			_puppet_fire(e2, {})
		elif fired == 1 and ms > 1900:
			fired = 2
			_puppet_fire(e2, {"mizrak_travel": 230.0, "mizrak_fly": 760.0})
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var c := Vector2(img.get_width(), img.get_height()) * 0.5
		var rect := Rect2i(int(c.x) - 560, int(c.y) - 260, 1120, 520).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		img.get_region(rect).save_png(_dir.path_join("f_%05d.png" % ms))
		await process_frame
	print("BITTI")
	quit()
