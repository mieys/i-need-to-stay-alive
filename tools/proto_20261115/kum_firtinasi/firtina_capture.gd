extends SceneTree

## KUM FIRTINASI görünüm prototipi yakalayıcısı (2026-11-15, oyuna bağlı DEĞİL). Gerçek SP main.tscn Altın Kumlar'da (HARITA=col) açılır,
## yaratık doğumu durur; her varyant için kum_proto.gdshader tam ekran katmanı kurulur, rüzgarlı hava (akıntı + bitki sallanması) açılır,
## ~1.3 sn boyunca kare dizisi kaydedilir. Kullanım: tools/proto_20261115/kum_firtinasi/run.ps1

const SHADER := "res://tools/proto_20261115/kum_firtinasi/kum_proto.gdshader"
const FRAMES := 20
const FRAME_MS := 70
const SLOPE := 0.16

## ad, rüzgarlı hava?, shader parametreleri
## tur 2 (kullanıcı: toz kümeleri "bulut gibi"): eski B referans, yeni 1 = lifli akıntı, yeni 2 = kum yılanları; ikisinde de yuvarlak leke yok
const VARIANTS := [
	["B", true, {"grade_amt": 0.85, "veil_amt": 0.14, "haze_amt": 0.55, "haze_lo": 0.4, "wall_amt": 0.5, "edge_amt": 0.3,
		"streak_amt": 0.85, "streak_density": 0.38, "sand_mul": Vector3(1.0, 0.82, 0.6)}],
	["B1", true, {"grade_amt": 0.85, "veil_amt": 0.14, "edge_amt": 0.3, "streak_amt": 0.7, "streak_density": 0.3, "sand_mul": Vector3(1.0, 0.82, 0.6),
		"fiber_amt": 0.75}],
	["B2", true, {"grade_amt": 0.85, "veil_amt": 0.14, "edge_amt": 0.3, "streak_amt": 0.6, "streak_density": 0.26, "sand_mul": Vector3(1.0, 0.82, 0.6),
		"snake_amt": 0.8}],
	["A1", true, {"grade_amt": 0.5, "veil_amt": 0.05, "streak_amt": 0.55, "streak_density": 0.22, "fiber_amt": 0.5}],
]

var _dir: String = ""


class Driver extends Node:
	var mat: ShaderMaterial
	var t: float = 0.0 ## oyun zamanı (Engine.time_scale ile ölçeklenmiş delta) - kareler arası hareket gerçek hızda

	func _process(delta: float) -> void:
		t += delta
		var vp: Viewport = get_viewport()
		var inv: Transform2D = (vp.get_final_transform() * vp.get_canvas_transform()).affine_inverse()
		mat.set_shader_parameter("cam_origin", inv * Vector2.ZERO)
		mat.set_shader_parameter("world_per_px", inv.get_scale().x)
		mat.set_shader_parameter("t", t)


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _run() -> void:
	await process_frame
	_dir = OS.get_environment("KUM_DIR")
	if _dir == "":
		_dir = ProjectSettings.globalize_path("res://tools/proto_20261115/kum_firtinasi/out")
	DirAccess.make_dir_recursive_absolute(_dir)
	AudioServer.set_bus_mute(0, true)
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	root.get_node("UISound").set("show_fps", false)
	gm.call("reset")
	gm.set("selected_char_id", 2)
	gm.set("selected_character", (load("res://scripts/characters.gd") as GDScript).call("get_def", 2).get("skill", 1))
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	## yaratık doğumu baştan kapalı (karşılaştırma sahnesi temiz kalsın)
	var sp0: Node = current_scene.get_node_or_null("EnemySpawner")
	if sp0:
		sp0.set_process(false)
		sp0.set_physics_process(false)
	await _wait(2.5)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	var main: Node = current_scene
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var player: Node2D = main.get_node_or_null("Player") as Node2D
	var off: String = OS.get_environment("KUM_OFFSET")
	if player and off != "":
		var p: PackedStringArray = off.split(",")
		player.global_position += Vector2(float(p[0]), float(p[1]))
	var hud: Node = main.get_node_or_null("HUD")
	print("HUD layer=", hud.get("layer") if hud else "yok", " player=", player.global_position if player else Vector2.ZERO)
	var atm: Node = get_first_node_in_group(&"atmosphere")
	await _wait(2.0)

	var layer := CanvasLayer.new()
	layer.name = "KumProto"
	layer.layer = 1
	main.add_child(layer)
	if hud:
		main.move_child(layer, hud.get_index()) ## aynı katman (1): ağaçta sisten sonra, HUD'dan önce
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER) as Shader
	mat.set_shader_parameter("slope", SLOPE)
	rect.material = mat
	layer.add_child(rect)
	var drv := Driver.new()
	drv.mat = mat
	layer.add_child(drv)

	var only: String = OS.get_environment("KUM_ONLY")
	for v: Array in VARIANTS:
		var vname: String = str(v[0])
		if only != "" and not (vname in only.split(",")):
			continue
		var windy: bool = bool(v[1])
		if atm:
			atm.call("debug_set_weather", 1 if windy else 0)
			atm.set("wind_angle", atan(SLOPE))
			atm.set("wind_intensity", 1.0 if windy else 0.0)
			atm.set("rain_intensity", 0.0)
		rect.visible = vname != "simdi"
		for k: String in ["grade_amt", "veil_amt", "haze_amt", "wall_amt", "edge_amt", "streak_amt", "fiber_amt", "snake_amt"]:
			mat.set_shader_parameter(k, 0.0)
		var params: Dictionary = v[2]
		for k: String in params:
			mat.set_shader_parameter(k, params[k])
		await _wait(2.5)
		print("yaratik=", get_nodes_in_group(&"enemies").size())
		## PNG kaydı ~240 ms sürdüğü için kareler belleğe alınır, oyun 0.25 hızda yürür: her kare = FRAME_MS oyun zamanı.
		Engine.time_scale = 0.25
		var imgs: Array[Image] = []
		var next_t: float = drv.t
		var start_t: float = drv.t
		for i in FRAMES:
			while drv.t < next_t:
				await process_frame
			next_t += FRAME_MS / 1000.0
			await RenderingServer.frame_post_draw
			imgs.append(root.get_texture().get_image())
		var span: float = drv.t - start_t
		Engine.time_scale = 1.0
		for i in imgs.size():
			imgs[i].save_png(_dir.path_join("%s_%02d.png" % [vname, i]))
		print("SHOT ", vname, " oyun_ms/kare=", span * 1000.0 / FRAMES)
	quit(0)
