extends SceneTree
## KARA BATAKLIK ZEMİN PROTOTİPLERİ 2. tur (yol + çimen) yakalaması (2026-11-11, oyuna bağlı DEĞİL): bataklık haritasında verilen hücrelerde
## zemin malzemesini sırayla ŞU AN / A / B / C / D yapıp gerçek çizici görüntüsü alır ("Yer/Zemin Toprak", "Yer/Zemin Çimen" ve kıyı karoları
## "Su/Su ayrıntılar 2" - oyundaki gibi aynı malzeme). Prototipler suya yakınlığı (A) ikili + mipmap'li su maskesinden okur.
## Çıktı tools/proto_20261111/bataklik_zemin/out/<nokta>_<varyant>.png (merkez 960x540) + _yakin (merkez 240x135, 4x).
## Gizli masaüstünde: tools/bataklik/bataklik_tur.ps1 -Betik res://tools/proto_20261111/bataklik_zemin/zemin_capture.gd
## ZP_NOKTALAR="ad:x,y;..." ile noktalar, ZP_VARYANT="A,B" ile varyantlar değiştirilebilir.

const POINTS := [["kamp", Vector2i(135, 196)], ["yol_su", Vector2i(83, 196)], ["cayir", Vector2i(152, 152)], ["koru", Vector2i(179, 32)]]
const VARIANTS := ["su_an", "A", "B", "C", "D"]
const DIR := "res://tools/proto_20261111/bataklik_zemin/"
const LAYERS := ["Yer/Zemin Çimen", "Yer/Zemin Toprak", "Su/Su ayrıntılar 2"]
const MASK := "res://assets/map/bataklik_su_derinlik.png"

var _out: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _points() -> Array:
	var spec: String = OS.get_environment("ZP_NOKTALAR")
	if spec == "":
		return POINTS
	var out: Array = []
	for item: String in spec.split(";", false):
		var kv: PackedStringArray = item.split(":")
		var xy: PackedStringArray = kv[1].split(",")
		out.append([kv[0], Vector2i(int(xy[0]), int(xy[1]))])
	return out


func _variants() -> Array:
	var spec: String = OS.get_environment("ZP_VARYANT")
	return VARIANTS if spec == "" else Array(spec.split(",", false))


const WET_RANGE := 160.0 ## dünya px: bu uzaklıkta ıslaklık 0
const WET_CELL := 4 ## maske tekseli (2 px) x 4 = 8 dünya px / hücre


## Suya yakınlık alanı: su hücresi 255, kıyıdan WET_RANGE'e doğrusal azalır (8 px hücrede iki geçişli chamfer uzaklığı).
func _water_texture() -> ImageTexture:
	var src: Image = (load(MASK) as Texture2D).get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_L8)
	var data: PackedByteArray = src.get_data()
	for i in range(data.size()):
		if data[i] > 0:
			data[i] = 255
	var bin := Image.create_from_data(src.get_width(), src.get_height(), false, Image.FORMAT_L8, data)
	var gw: int = src.get_width() / WET_CELL
	var gh: int = src.get_height() / WET_CELL
	bin.resize(gw, gh, Image.INTERPOLATE_LANCZOS)
	var g: PackedByteArray = bin.get_data()
	var n: int = gw * gh
	var d := PackedFloat32Array()
	d.resize(n)
	for i in range(n):
		d[i] = 0.0 if g[i] > 110 else 1e6
	const DG := 1.41421
	for y in range(gh):
		for x in range(gw):
			var i: int = y * gw + x
			var v: float = d[i]
			if v == 0.0:
				continue
			if x > 0:
				v = minf(v, d[i - 1] + 1.0)
			if y > 0:
				v = minf(v, d[i - gw] + 1.0)
				if x > 0:
					v = minf(v, d[i - gw - 1] + DG)
				if x < gw - 1:
					v = minf(v, d[i - gw + 1] + DG)
			d[i] = v
	for y in range(gh - 1, -1, -1):
		for x in range(gw - 1, -1, -1):
			var i: int = y * gw + x
			var v: float = d[i]
			if v == 0.0:
				continue
			if x < gw - 1:
				v = minf(v, d[i + 1] + 1.0)
			if y < gh - 1:
				v = minf(v, d[i + gw] + 1.0)
				if x < gw - 1:
					v = minf(v, d[i + gw + 1] + DG)
				if x > 0:
					v = minf(v, d[i + gw - 1] + DG)
			d[i] = v
	var out := PackedByteArray()
	out.resize(n)
	var cell_px: float = 2.0 * float(WET_CELL)
	for i in range(n):
		out[i] = int(clampf(1.0 - d[i] * cell_px / WET_RANGE, 0.0, 1.0) * 255.0)
	var img := Image.create_from_data(gw, gh, false, Image.FORMAT_L8, out)
	img.save_png(_out.path_join("islaklik.png"))
	return ImageTexture.create_from_image(img)


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
	var wtex: ImageTexture = _water_texture()
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
	var variants: Array = _variants()
	for v: String in variants:
		if v == "su_an":
			continue
		var sh: Shader = load(DIR + "zemin_%s.gdshader" % v)
		var m := ShaderMaterial.new()
		m.shader = sh
		if ground != null and ground.shader != null:
			for u: Dictionary in sh.get_shader_uniform_list():
				var nm2: String = u["name"]
				if nm2 == "cim_taban" or nm2 == "su_maske":
					continue
				var val: Variant = ground.get_shader_parameter(nm2)
				if val != null:
					m.set_shader_parameter(nm2, val)
		m.set_shader_parameter("su_maske", wtex)
		m.set_shader_parameter("su_maske_boyut", Vector2(wtex.get_size()))
		mats[v] = m
	var p: Node2D = main.get_node("Player")
	## temiz karşılaştırma: yaratık doğuşu durur, var olanlar silinir, oyuncunun koruma baloncuğu gizli
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
