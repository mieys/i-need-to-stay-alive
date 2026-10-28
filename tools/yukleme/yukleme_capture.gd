extends SceneTree

## YÜKLEME EKRANI "Mühürlü Kapı" (madde 370) - arka plan çekimi GERÇEK çiziciden: Kemik Mahzeni önü, oyuncusuz, derin orman ışıkları
## KAPALI (ruh ışıkları + kapı halesi yükleme ekranında canlı çizilir). Kurulum tools/derin_orman/final_capture.gd ile aynı.
## 1 dünya px = 4 ekran px (gizli masaüstü 2560x1440) -> en yakın komşuyla 640x360 = yükleme tuvali (1 dünya px = 1 tuval px).
## Çıktı tools/yukleme/cekim/: mahzen.png (tuval), alev_kareleri.png (kapı çevresi KIRPIM_W x KIRPIM_H, art arda N kare - kapı alevinin
## Tiled animasyonu her karede yakalanır, üretici kareleri atlas karelerine eşler), meta.json (kamera, kapı ağzı tuvalde, kırpım).
## Çalıştır: tools/yukleme/yukleme_capture.ps1 ; sonra python tools/gen_yukleme_bg.py

const GATE := 0 ## deep_forest_places.gd GATES[0] = Kemik Mahzeni
const FOOT_AT := Vector2(546, 200) ## kapı ayak hücresinin merkezi tuvalde (kahraman bar %97'de bu x'te: loading_screen.gd PATH_RECT)
const CROP := Rect2i(482, 72, 128, 144) ## alev kareleri için kapı çevresi
const N_FRAMES := 90

var _out: String = ProjectSettings.globalize_path("res://").path_join("tools/yukleme/cekim")


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.resize(640, 360, Image.INTERPOLATE_NEAREST)
	return img


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
	var fx_script: GDScript = load("res://scripts/deep_forest_fx.gd")
	var fx: Node2D = fx_script.attach(harita)
	fx.visible = false
	fx.set_process(false)
	var ref: TileMapLayer = harita.get_node("Orman parçaları/Orman parçaları")
	var places: GDScript = load("res://scripts/deep_forest_places.gd")
	var cell: Vector2i = places.GATES[GATE]["cell"]
	var foot: Vector2 = ref.to_global(ref.map_to_local(cell))
	var cam := Camera2D.new()
	scene.add_child(cam)
	cam.make_current()
	await _frames(2)
	var s0: float = root.get_final_transform().get_scale().x
	cam.zoom = Vector2.ONE * 4.0 / s0
	cam.global_position = (foot + Vector2(320, 180) - FOOT_AT).round()
	await _frames(40)
	var base: Image = await _grab()
	base.save_png(_out.path_join("mahzen.png"))
	var strip := Image.create(CROP.size.x * N_FRAMES, CROP.size.y, false, base.get_format())
	var stamps: Array = []
	for k in range(N_FRAMES):
		await process_frame
		var img: Image = await _grab()
		strip.blit_rect(img, CROP, Vector2i(k * CROP.size.x, 0))
		stamps.append(Time.get_ticks_msec())
	strip.save_png(_out.path_join("alev_kareleri.png"))
	var to_canvas := func(w: Vector2) -> Vector2: return w - cam.global_position + Vector2(320, 180)
	var meta := {
		"cam": [cam.global_position.x, cam.global_position.y],
		"foot": [to_canvas.call(foot).x, to_canvas.call(foot).y],
		"mouth": [to_canvas.call(fx_script.gate_mouth(GATE)).x, to_canvas.call(fx_script.gate_mouth(GATE)).y],
		"crop": [CROP.position.x, CROP.position.y, CROP.size.x, CROP.size.y],
		"frames": N_FRAMES,
		"msec": stamps,
	}
	var f := FileAccess.open(_out.path_join("meta.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	print("CEKIM tamam cam=", cam.global_position, " mouth=", meta["mouth"], " sure=", int(stamps[-1]) - int(stamps[0]), " ms")
	quit()
