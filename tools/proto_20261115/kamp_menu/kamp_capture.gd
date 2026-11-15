extends SceneTree

## ANA MENÜ "Nehir Kenarı Kampı" arka planı için ANA HARİTADAN gerçek çizici yakalaması (2026-11-15).
## tools/cayir_susleri/yakin_capture.gd deseni: harita_baked (main.tscn'deki (-2, 21) ofset) + main.gd'nin harita görselleri, oyuncu YOK.
## Her kadraj DÜNYA pikselinde (1 dünya px = 1 png px) kaydedilir: ekran görüntüsü kamera zoom'uyla alınır, sonra dünya pikseli
## merkezlerinden örneklenir (gizli masaüstünde kök doku x2 gelebiliyor; oran görüntü genişliğinden hesaplanır).
## Çıktı: tools/proto_20261115/kamp_menu/out/<ad>.png. Gizli masaüstünde: tools/proto_20261115/kamp_menu/kamp_run.ps1
## KAMP_SHOTS="ad:x,y:w,h|..." (hücre merkezi, dünya px boyutu) ile kadrajlar değiştirilebilir.

const DEFAULT_SHOTS := "aday1:138,106:480,270|aday2:128,113:480,270|aday3:150,98:480,270"

var _out: String = ProjectSettings.globalize_path("res://").path_join("tools/proto_20261115/kamp_menu/out")


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
	var ref: TileMapLayer = harita.get_node("Orman parçaları/Orman parçaları")
	var cam := Camera2D.new()
	scene.add_child(cam)
	cam.make_current()
	var spec: String = OS.get_environment("KAMP_SHOTS")
	if spec.is_empty():
		spec = DEFAULT_SHOTS
	for part: String in spec.split("|", false):
		var f: PackedStringArray = part.split(":")
		var c: PackedStringArray = f[1].split(",")
		var wh: PackedStringArray = f[2].split(",")
		var world := Vector2(float(wh[0]), float(wh[1]))
		var cell := Vector2(float(c[0]), float(c[1]))
		## kesirli hücre: hücre merkezi + kesir * 16
		var base := Vector2i(floori(cell.x), floori(cell.y))
		var center: Vector2 = ref.to_global(ref.map_to_local(base)) + (cell - Vector2(base)) * 16.0
		var vis: Vector2 = root.get_visible_rect().size
		var z: float = minf(vis.x / world.x, vis.y / world.y)
		cam.zoom = Vector2(z, z)
		cam.global_position = center.round()
		await _frames(30)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var k: float = float(img.get_width()) / (vis.x / z) ## görüntü px / dünya px
		var out := Image.create(int(world.x), int(world.y), false, Image.FORMAT_RGBA8)
		var ox: float = img.get_width() * 0.5 - world.x * 0.5 * k
		var oy: float = img.get_height() * 0.5 - world.y * 0.5 * k
		for y in range(int(world.y)):
			for x in range(int(world.x)):
				var sx: int = clampi(int(ox + (x + 0.5) * k), 0, img.get_width() - 1)
				var sy: int = clampi(int(oy + (y + 0.5) * k), 0, img.get_height() - 1)
				out.set_pixel(x, y, img.get_pixel(sx, sy))
		out.save_png(_out.path_join("%s.png" % f[0]))
		print("SHOT ", f[0], " k=", k, " center=", center)
	quit()
