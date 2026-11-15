extends SceneTree
## AYAZ DAĞI KAR ZEMİNİ PROTOTİPLERİ yakalaması (2026-11-12, oyuna bağlı DEĞİL): kış haritasında verilen hücrelerde zemin malzemesini
## sırayla ŞU AN / A / B / C / D yapıp gerçek çizici görüntüsü alır. Prototip malzemesi oyunun 4 zemin katmanına ("Yer/Zemin Toprak",
## "Yer/Zemin Çimen", "Yer/Patika", "Su/Su ayrıntılar 2") + iki süs katmanına ("Yer/Leke", "Yer/Kar süsleri" - bugün malzemesiz, kar
## lekeleri beyaz kalmasın diye) takılır. Öğle ışığı (en parlak an), açık hava, yaratık doğuşu kapalı.
## Çıktı tools/proto_20261112/kar_zemin/out/<nokta>_<varyant>.png (merkez 960x540) + _yakin (merkez 240x135, 4x).
## Gizli masaüstünde: powershell -ExecutionPolicy Bypass -File tools/kis/kis_tur.ps1 -Betik res://tools/proto_20261112/kar_zemin/kar_capture.gd
## KZ_NOKTALAR="ad:x,y;..." noktaları, KZ_VARYANT="A,B" varyantları, KZ_SAAT=<sn> saati değiştirir.

const POINTS := [["kamp", Vector2i(160, 251)], ["ova", Vector2i(93, 208)], ["patika", Vector2i(155, 218)], ["gol", Vector2i(165, 158)],
	["koru", Vector2i(199, 48)]]
const VARIANTS := ["su_an", "A", "B", "C", "D"]
const DIR := "res://tools/proto_20261112/kar_zemin/"
const LAYERS := ["Yer/Zemin Toprak", "Yer/Zemin Çimen", "Yer/Patika", "Su/Su ayrıntılar 2", "Yer/Leke", "Yer/Kar süsleri"]

var _out: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _points() -> Array:
	var spec: String = OS.get_environment("KZ_NOKTALAR")
	if spec == "":
		return POINTS
	var out: Array = []
	for item: String in spec.split(";", false):
		var kv: PackedStringArray = item.split(":")
		var xy: PackedStringArray = kv[1].split(",")
		out.append([kv[0], Vector2i(int(xy[0]), int(xy[1]))])
	return out


func _variants() -> Array:
	var spec: String = OS.get_environment("KZ_VARYANT")
	return VARIANTS if spec == "" else Array(spec.split(",", false))


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
		var saat: String = OS.get_environment("KZ_SAAT")
		atmo.set("cycle_time", 150.0 if saat == "" else float(saat)) ## öğle: gün ışığı rengi nötr, en parlak an
		atmo.call("debug_set_weather", 0)
		var hedef: Vector3 = (load("res://scripts/atmosphere_math.gd") as GDScript).call("weather_targets", 0)
		atmo.set("rain_intensity", hedef.x)
		atmo.set("wind_intensity", hedef.y)
	var harita: Node = main.get_node("Harita")
	var layers: Array[TileMapLayer] = []
	var originals: Array = []
	for path: String in LAYERS:
		var l := harita.get_node_or_null(path) as TileMapLayer
		if l == null:
			print("CAP katman yok: %s" % path)
		layers.append(l)
		originals.append(l.material if l != null else null)
	var mats: Dictionary = {}
	var variants: Array = _variants()
	for v: String in variants:
		if v == "su_an":
			continue
		var m := ShaderMaterial.new()
		m.shader = load(DIR + "zemin_%s.gdshader" % v)
		mats[v] = m
	var p: Node2D = main.get_node("Player")
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.process_mode = Node.PROCESS_MODE_DISABLED
	var sv: Node = p.get_node_or_null("ShieldVisual")
	for pt: Array in _points():
		var cell: Vector2i = pt[1]
		p.global_position = Vector2(cell.x * 16 + 8, cell.y * 16 + 8)
		p.reset_physics_interpolation()
		for e in get_nodes_in_group("enemies"):
			if is_instance_valid(e):
				(e as Node).queue_free()
		await _wait(2.0)
		if sv is CanvasItem:
			(sv as CanvasItem).visible = false
		for v: String in variants:
			for i in range(layers.size()):
				if layers[i] == null:
					continue
				layers[i].material = originals[i] if v == "su_an" else mats[v]
				layers[i].use_parent_material = false
			await _wait(0.35)
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			var w: int = img.get_width()
			var h: int = img.get_height()
			var mid: Image = img.get_region(Rect2i(w / 2 - 480, h / 2 - 270, 960, 540))
			mid.save_png(_out.path_join("%s_%s.png" % [pt[0], v]))
			var z: Image = img.get_region(Rect2i(w / 2 + 30, h / 2 - 100, 240, 135))
			z.resize(960, 540, Image.INTERPOLATE_NEAREST)
			z.save_png(_out.path_join("%s_%s_yakin.png" % [pt[0], v]))
		print("CAP %s tamam" % pt[0])
	quit(0)
