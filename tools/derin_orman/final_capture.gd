extends SceneTree

## DERİN ORMAN son görünüm yakalaması (madde 360): GERÇEK çizici - harita_baked (main.tscn'deki (-2, 21) ofset) + main.gd'nin harita görselleri
## (GrassSway, TreeSway, DepthOccluders, ForestCanopy, MapShadows, MapColorGrade, WaterFx, GroundTexelPass) + bölge ışıkları (deep_forest_fx.gd).
##   1) GENEL: oyun alanı (256x256 hücre) 1 ekran px = 1 dünya px parça parça -> out/final/genel_<i>_<j>.png + genel_meta.txt (sol üst köşe ekran konumu)
##   2) YAKIN: her bölgeden set parçası çekimleri, oyun kamerası (zoom 2 = 960x540 dünya px) + ölçek için bir oyuncu -> out/final/yakin_<ad>.png + meta
## Gizli masaüstünde: tools/derin_orman/final_run.ps1 ; birleştirme: python tools/derin_orman/final_sheet.py
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok - _run'da load edilir.

const SHOTS := [
	{"name": "kuzey_mahzen", "center": Vector2i(203, 19), "player": Vector2i(206, 22)},
	{"name": "kuzey_dev", "center": Vector2i(140, 25), "player": Vector2i(138, 30)},
	## madde 385: Batı/Doğu kaldırıldı -> Kuzey'in kuzeybatı uzantısı (içinde Et Kuyusu), eski haritaya dönen alanlar, yerinde kalan Boynuzlu Kapı
	{"name": "kuzeybati_kuyu", "center": Vector2i(40, 33), "player": Vector2i(39, 36)},
	{"name": "kuzeybati_orman", "center": Vector2i(22, 18), "player": Vector2i(22, 22)},
	{"name": "eski_bati", "center": Vector2i(40, 95), "player": Vector2i(38, 100)},
	{"name": "boynuzlu_kapi", "center": Vector2i(235, 54), "player": Vector2i(240, 56)},
	{"name": "eski_dogu", "center": Vector2i(234, 92), "player": Vector2i(232, 99)},
	{"name": "guney_agac", "center": Vector2i(106, 230), "player": Vector2i(101, 236)},
	{"name": "guney_kulube", "center": Vector2i(135, 228), "player": Vector2i(131, 235)},
	## madde 387: Güney'in batı çayırı uzantısı + toprak kalan yol/açıklık; dikiş (eski güney sınırı) + maden toprağı kenarı sınır kontrolü
	{"name": "guneybati_cayir", "center": Vector2i(62, 228), "player": Vector2i(60, 232)},
	{"name": "guneybati_yol", "center": Vector2i(52, 196), "player": Vector2i(55, 200)},
	{"name": "sinir_gb", "center": Vector2i(90, 222), "player": Vector2i(86, 226)},
	{"name": "sinir_maden", "center": Vector2i(30, 214), "player": Vector2i(34, 218)},
	## sınır kontrolleri (sayfaya girmez): eski kuzey-batı dikişi (artık Kuzey'in içi), kuzeybatının güney kenarı, kuzeyin güney kenarı (nehir batısı)
	{"name": "sinir_kb", "center": Vector2i(80, 26), "player": Vector2i(80, 30)},
	{"name": "sinir_kbg", "center": Vector2i(30, 58), "player": Vector2i(30, 62)},
	{"name": "sinir_kg", "center": Vector2i(200, 52), "player": Vector2i(200, 56)},
]

const GIF_SHOTS := ["kuzey_mahzen", "boynuzlu_kapi", "guney_agac"]

var _out: String = ProjectSettings.globalize_path("res://").path_join("tools/derin_orman/out/final")


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(_out)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 1
	gm.selected_character = 1
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
	var to_world := func(c: Vector2i) -> Vector2: return ref.to_global(ref.map_to_local(c))
	var cam := Camera2D.new()
	scene.add_child(cam)
	cam.make_current()
	await _frames(2)
	## 1) GENEL - ekran px / dünya px = 1
	var s0: float = root.get_final_transform().get_scale().x
	cam.zoom = Vector2.ONE / s0
	fx.visible = false
	var vis: Vector2 = Vector2(root.get_visible_rect().size) / cam.zoom ## dünya px
	var origin: Vector2 = to_world.call(Vector2i.ZERO) - Vector2(8, 8)
	var cols: int = int(ceil(4096.0 / vis.x))
	var rows: int = int(ceil(4096.0 / vis.y))
	var meta := PackedStringArray()
	for j in range(rows):
		for i in range(cols):
			var tl: Vector2 = origin + Vector2(i * vis.x, j * vis.y)
			cam.global_position = tl + vis * 0.5
			await _frames(25)
			await RenderingServer.frame_post_draw
			var xf: Transform2D = root.get_final_transform() * root.get_canvas_transform()
			var o: Vector2 = xf * tl
			root.get_texture().get_image().save_png(_out.path_join("genel_%d_%d.png" % [i, j]))
			meta.append("%d,%d,%f,%f,%f,%f,%f" % [i, j, tl.x - origin.x, tl.y - origin.y, o.x, o.y, (xf * (tl + Vector2(100, 0))).x - o.x])
	var f := FileAccess.open(_out.path_join("genel_meta.txt"), FileAccess.WRITE)
	f.store_string("\n".join(meta))
	f.close()
	print("SHOT genel ", cols, "x", rows, " vis=", vis)
	## 2) YAKIN - oyun kamerası
	cam.zoom = Vector2(2, 2) ## oyun kamerası: 1920x1080 tuvalde 960x540 dünya px
	fx.visible = true
	var hb: GDScript = load("res://scripts/hide_brush.gd")
	var feet_off: float = float(hb.FEET_OFFSET)
	var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.scale = Vector2(0.5, 0.5)
	scene.add_child(player)
	player.set_physics_process(false)
	var own_cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if own_cam:
		own_cam.enabled = false
	cam.make_current()
	player.facing = "up"
	for shot: Dictionary in SHOTS:
		player.global_position = to_world.call(shot["player"]) + Vector2(0, 7) - Vector2(0, feet_off)
		cam.global_position = to_world.call(shot["center"])
		fx.call("clear_motes")
		await _frames(30)
		for _k in range(80):
			fx._process(0.1)
		await _frames(2)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("yakin_%s.png" % shot["name"]))
		if shot["name"] in GIF_SHOTS:
			## madde 361: animasyonlu kapı / yaşlı ağaç / ışıklar - 20 kare, 6 oyun karesi arayla (~0,1 sn); oyuncu yakında -> kapı halesi güçlü
			for gi in range(3):
				fx.call("set_gate_boost", gi, 0.7)
			for k in range(20):
				await _frames(6)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(_out.path_join("gif_%s_%02d.png" % [shot["name"], k]))
		var xf2: Transform2D = root.get_final_transform() * root.get_canvas_transform()
		var o2: Vector2 = xf2 * (to_world.call(Vector2i.ZERO) - Vector2(8, 8))
		var o3: Vector2 = xf2 * (to_world.call(Vector2i(10, 0)) - Vector2(8, 8))
		var f2 := FileAccess.open(_out.path_join("yakin_%s.txt" % shot["name"]), FileAccess.WRITE)
		f2.store_string("%f,%f,%f" % [o2.x, o2.y, (o3.x - o2.x) / 10.0])
		f2.close()
		print("SHOT ", shot["name"], " ", fx.call("debug_state"))
	quit()
