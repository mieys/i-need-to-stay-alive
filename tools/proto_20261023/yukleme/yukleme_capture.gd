extends SceneTree

## YÜKLEME EKRANI prototipleri (madde 366) - A "Mühürlü Kapı" ve B "Dört Bölge" için GERÇEK çiziciden oyuncusuz harita çekimleri.
## Kurulum tools/derin_orman/final_capture.gd ile aynı (harita_baked + main.gd harita görselleri + derin orman ışıkları).
## 1 dünya px = 4 ekran px (gizli masaüstü 2560x1440 -> 640x360 dünya px = yükleme tuvali 640x360); kaydetmeden önce 640x360'a
## en yakın komşuyla küçültülür (her dünya pikseli 4x4 aynı blok). Çıktı out/raw/<çekim>_<kare>.png
## Gizli masaüstünde: tools/proto_20261023/yukleme/yukleme_run.ps1 ; birleştirme: python tools/proto_20261023/yukleme/yukleme_proto.py

## "foot" = parçanın ayak hücresi (deep_forest_places.gd), "at" = o hücre merkezinin 640x360 tuvalde duracağı yer.
## "boost" = kapı halesi (deep_forest_fx set_gate_boost): [kapı, başlangıç, bitiş] - kareler boyunca ilerlemeyle artar.
const SHOTS := [
	{"name": "a_mahzen", "foot": Vector2i(207, 17), "at": Vector2(546, 200), "frames": 48, "boost": [0, 0.0, 1.0]},
	{"name": "b_kuzey", "foot": Vector2i(142, 24), "at": Vector2(320, 196), "frames": 12},
	{"name": "b_bati", "foot": Vector2i(22, 57), "at": Vector2(320, 196), "frames": 12},
	{"name": "b_dogu", "foot": Vector2i(241, 53), "at": Vector2(320, 196), "frames": 12, "boost": [2, 0.6, 0.6]},
	{"name": "b_guney", "foot": Vector2i(106, 234), "at": Vector2(320, 196), "frames": 12},
]

var _out: String = ProjectSettings.globalize_path("res://").path_join("tools/proto_20261023/yukleme/out/raw")


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(_out)
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var harita: Node2D = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	harita.name = "Harita"
	harita.position = Vector2(-2, 21)
	scene.add_child(harita)
	await process_frame
	load("res://scripts/grass_sway.gd").new().setup(harita)
	load("res://scripts/tree_sway.gd").new().setup(harita)
	load("res://scripts/depth_occluders.gd").new().setup(harita)
	load("res://scripts/forest_canopy.gd").new().setup(harita)
	load("res://scripts/map_shadows.gd").attach(harita)
	load("res://scripts/map_color_grade.gd").attach(harita)
	load("res://scripts/water_fx.gd").attach(harita)
	load("res://scripts/ground_texel_pass.gd").attach(harita)
	var fx: Node2D = load("res://scripts/deep_forest_fx.gd").attach(harita)
	var ref: TileMapLayer = harita.get_node("Orman parçaları/Orman parçaları")
	var cam := Camera2D.new()
	scene.add_child(cam)
	cam.make_current()
	await _frames(2)
	var s0: float = root.get_final_transform().get_scale().x
	cam.zoom = Vector2.ONE * 4.0 / s0
	var vis: Vector2 = Vector2(root.get_visible_rect().size) / cam.zoom
	print("VIS ", vis, " s0=", s0)
	for shot: Dictionary in SHOTS:
		var foot: Vector2 = ref.to_global(ref.map_to_local(shot["foot"]))
		cam.global_position = (foot + Vector2(320, 180) - (shot["at"] as Vector2)).round()
		fx.call("clear_motes")
		for gi in range(3):
			fx.call("set_gate_boost", gi, 0.0)
		await _frames(30)
		for _k in range(80):
			fx._process(0.1)
		var n: int = int(shot["frames"])
		for k in range(n):
			if shot.has("boost"):
				var b: Array = shot["boost"]
				fx.call("set_gate_boost", int(b[0]), lerpf(float(b[1]), float(b[2]), float(k) / maxf(1.0, n - 1.0)))
			await _frames(6)
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			img.resize(640, 360, Image.INTERPOLATE_NEAREST)
			img.save_png(_out.path_join("%s_%02d.png" % [shot["name"], k]))
		print("SHOT ", shot["name"], " cam=", cam.global_position, " foot=", foot)
	quit()
