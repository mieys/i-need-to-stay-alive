extends SceneTree

## Madde 296 gerçek çizici yakalaması: kukla (remote_player.tscn) Tüfek + Tabanca ile ateş eder (boş kovanlar) ve doldurur (poz, düşen
## şarjör, parıltı). Kaster ile kukla AYNI GunReloadFx / ShellCasingFx'i kullanır. Kamera zoom 2 (1080p oyun ölçeği).
## Çalıştırma (gizli masaüstü): tools/fps_micro/hidden_launch.ps1 Invoke-GodotHidden ile '--path . -s res://tools/proto_20261019/sarjor_capture.gd'
## Kareler SARJOR_CAP_DIR'e.

var _dir: String = OS.get_environment("SARJOR_CAP_DIR")
var _cam: Camera2D = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * _cam.global_position)
	var rect := Rect2i(int(c.x) - 200, int(c.y) - 190, 400, 300)
	rect = rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join(name))
	print("SHOT %s %s (pencere %dx%d)" % [name, str(rect.size), img.get_width(), img.get_height()])


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(108, 152, 88)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	var puppet: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(puppet)
	puppet.call("setup", 78, 5, "Dost")
	puppet.call("snap_to_network_position", Vector2(3000.0, 3000.0))
	puppet.call("update_weapon_visuals", ["tufek", "tabanca"])
	var foe := Node2D.new()
	foe.add_to_group("enemies")
	scene.add_child(foe)
	foe.global_position = Vector2(3300.0, 2985.0)
	_cam = Camera2D.new()
	_cam.zoom = Vector2(2, 2)
	scene.add_child(_cam)
	_cam.global_position = Vector2(3000.0, 2985.0)
	_cam.make_current()
	await _wait(1.2)
	await _shot("a_idle.png")
	## 3 hızlı atış (kovanlar)
	for k in 3:
		puppet.call("_animate_weapon_fire_full", {"slot_index": 0, "direction_x": 1.0, "direction_y": 0.0})
		puppet.call("_animate_weapon_fire_full", {"slot_index": 1, "direction_x": 1.0, "direction_y": 0.0})
		await _wait(0.12)
	await _shot("b_fire_0.png")
	await _wait(0.2)
	await _shot("b_fire_1.png")
	await _wait(0.35)
	await _shot("b_fire_2.png")
	await _wait(0.8)
	await _shot("b_fire_3.png")
	## doldurma 1,6 sn (iki silah)
	puppet.call("_start_weapon_reload", 0, 1.6)
	puppet.call("_start_weapon_reload", 1, 1.6)
	var marks: Array = [0.08, 0.26, 0.4, 0.55, 0.62, 0.74, 0.84, 0.97, 1.04, 1.12]
	var t0: int = Time.get_ticks_msec()
	for i in marks.size():
		var target_ms: int = int(float(marks[i]) * 1.6 * 1000.0)
		while Time.get_ticks_msec() - t0 < target_ms:
			await process_frame
		await _shot("c_reload_%02d.png" % i)
	await _wait(0.6)
	await _shot("d_after.png")
	quit()
