extends SceneTree
## KARA BATAKLIK ÇİMEN PROTOTİPLERİ yakalaması (2026-11-09, oyuna bağlı DEĞİL): bataklık haritasında verilen hücrelerde zemin malzemesini
## sırayla ŞU AN / A / B / C / D yapıp gerçek çizici görüntüsü alır. Prototip malzemesi çamur değerlerini oyundaki zemin malzemesinden kopyalar
## (yalnız çimen değişir); prototipler kıyı karolarının çimenine ("Su/Su ayrıntılar 2") de uygulanır - bugün kıyı çimeni düz kalıyor.
## Çıktı tools/proto_20261109/bataklik_cimen/out/<nokta>_<varyant>.png (merkez 960x540) + _yakin (merkez 240x135, 4x).
## Gizli masaüstünde: tools/bataklik/bataklik_tur.ps1 -Betik res://tools/proto_20261109/bataklik_cimen/cimen_capture.gd

const POINTS := [["kamp", Vector2i(128, 184)], ["cayir", Vector2i(152, 152)], ["bati", Vector2i(70, 100)]]
const VARIANTS := ["su_an", "A", "B", "C", "D"]
const DIR := "res://tools/proto_20261109/bataklik_cimen/"
const LAYERS := ["Yer/Zemin Çimen", "Yer/Zemin Toprak", "Su/Su ayrıntılar 2"]

var _out: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _run() -> void:
	_out = ProjectSettings.globalize_path(DIR + "out")
	DirAccess.make_dir_recursive_absolute(_out)
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", 1)
	gm.set("selected_start_weapon", "sword")
	gm.set("debug_immortal", true)
	gm.set("debug_mode_unlocked", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	gm.set("run_record_suppressed", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(6.0)
	var atmo: Node = main.get_node_or_null("Atmosphere")
	if atmo:
		atmo.set("cycle_time", 150.0) ## öğle: gün ışığı rengi nötr
	var harita: Node = main.get_node("Harita")
	var layers: Array[TileMapLayer] = []
	var originals: Array = []
	for path: String in LAYERS:
		var l := harita.get_node_or_null(path) as TileMapLayer
		layers.append(l)
		originals.append(l.material if l != null else null)
	var ground: ShaderMaterial = originals[0] as ShaderMaterial
	var mats: Dictionary = {}
	for v: String in VARIANTS:
		if v == "su_an":
			continue
		var sh: Shader = load(DIR + "cimen_%s.gdshader" % v)
		var m := ShaderMaterial.new()
		m.shader = sh
		if ground != null and ground.shader != null:
			for u: Dictionary in sh.get_shader_uniform_list():
				var nm2: String = u["name"]
				if nm2 == "cim_taban":
					continue
				var val: Variant = ground.get_shader_parameter(nm2)
				if val != null:
					m.set_shader_parameter(nm2, val)
		mats[v] = m
	var p: Node2D = main.get_node("Player")
	## temiz karşılaştırma: yaratık doğuşu durur, var olanlar silinir, oyuncunun koruma baloncuğu gizli
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.process_mode = Node.PROCESS_MODE_DISABLED
	var sv: Node = p.get_node_or_null("ShieldVisual")
	for pt: Array in POINTS:
		var cell: Vector2i = pt[1]
		p.global_position = Vector2(cell.x * 16 + 8, cell.y * 16 + 8)
		p.reset_physics_interpolation()
		for e in get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				(e as Node).queue_free()
		await _wait(2.0)
		if sv is CanvasItem:
			(sv as CanvasItem).visible = false
		for v: String in VARIANTS:
			for i in range(layers.size()):
				if layers[i] == null:
					continue
				layers[i].material = originals[i] if v == "su_an" else mats[v]
			await _wait(0.35)
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			var w: int = img.get_width()
			var h: int = img.get_height()
			var mid: Image = img.get_region(Rect2i(w / 2 - 480, h / 2 - 300, 960, 540))
			mid.save_png(_out.path_join("%s_%s.png" % [pt[0], v]))
			var z: Image = img.get_region(Rect2i(w / 2 + 40, h / 2 - 120, 240, 135))
			z.resize(960, 540, Image.INTERPOLATE_NEAREST)
			z.save_png(_out.path_join("%s_%s_yakin.png" % [pt[0], v]))
		print("CAP %s tamam" % pt[0])
	quit(0)
