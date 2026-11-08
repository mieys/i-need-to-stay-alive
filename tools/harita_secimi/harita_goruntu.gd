extends SceneTree
## Kullanım: gizli masaüstünde (tools/fps_micro/hidden_launch.ps1 Invoke-GodotHidden), APPDATA yalıtılı, HARITA + CAP_OUT (PNG klasörü) ortam değişkenleri.
## Kadim Derinlikler gerçek çizici görüntüsü: Main (HARITA ortam değişkeni), doğuş + bir küme odası, 960x540 PNG.

var _gm: Node = null
var _out: String = OS.get_environment("CAP_OUT")
var _tag: String = OS.get_environment("HARITA") ## dosya adı öneki
var _room: String = OS.get_environment("CAP_ODA") if OS.get_environment("CAP_ODA") != "" else "lab" ## ikinci görüntünün oda sakini profili


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _measure(label: String, sec: float = 3.0) -> void:
	var t0: int = Time.get_ticks_usec()
	var f0: int = Engine.get_process_frames()
	await _wait(sec)
	var frames: int = Engine.get_process_frames() - f0
	print("CAP %s ort kare %.2f ms (%d kare)" % [label, float(Time.get_ticks_usec() - t0) / 1000.0 / maxf(1.0, float(frames)), frames])


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	img.save_png(_out.path_join(_tag + "_" + name + ".png"))
	print("CAP ", name)


func _run() -> void:
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", 1)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(1).get("skill", 1))
	_gm.set("selected_start_weapon", "sword")
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(5.0)
	for c in root.get_children():
		_close_popups(c)
	await _wait(1.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _measure("doğuş")
	await _shot("dogus")
	var p: Node2D = main.get_node("Player")
	var mp: GDScript = load("res://scripts/map_profiles.gd")
	var d: Resource = mp.call("data")
	for o: Dictionary in d.objects:
		if str(o.get("type", "")) == "sakin" and str(o.get("name", "")) == _room:
			p.global_position = (o["rect"] as Rect2).get_center()
			p.reset_physics_interpolation()
			break
	await _wait(3.0)
	await _measure("küme")
	await _shot("kume")
	quit(0)


## Başlangıç silah seçimi gibi açılan pencereleri kapatmaya çalışma (yalnız görüntü için): duraklatma bayrağı _wait'te kaldırılıyor.
func _close_popups(_n: Node) -> void:
	pass
