extends SceneTree

## DONMUŞ KARE yakalaması (madde 371): shader / çizim değişikliğinin GÖRÜNTÜYÜ değiştirmediğini kanıtlamak için. Engine.time_scale = 0 en başta -> shader TIME = 0, kare süresi 0 (sallanma,
## su, bulut sabit); ruh ışıkları kapalı. Aynı konumlar için PNG yazar; iki sürümde (eski / yeni) koşturup klasörleri karşılaştır (tools/fps_micro/donmus_karsilastir.py).
## Kullanım (gizli masaüstü): ... -s res://tools/fps_micro/donmus_kare.gd -- <çıktı klasörü>

const SHOTS := [
	["kuzey", Vector2i(150, 15)], ["kuzey_agac", Vector2i(140, 25)], ["bati", Vector2i(30, 30)], ["bati_kuyu", Vector2i(40, 33)], ["dogu", Vector2i(235, 60)],
	["dogu_kapi", Vector2i(235, 54)], ["guney", Vector2i(140, 215)], ["guney_agac", Vector2i(106, 230)], ["orta_ev", Vector2i(120, 80)], ["orta_nehir", Vector2i(110, 118)],
	["orta_dag", Vector2i(60, 120)], ["sinir_kb", Vector2i(80, 26)], ["sinir_db", Vector2i(202, 110)],
]


func _initialize() -> void:
	Engine.time_scale = 0.0
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	AudioServer.set_bus_mute(0, true)
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
	fx.visible = false
	fx.set_process(false)
	var ref: TileMapLayer = harita.get_node("Orman parçaları/Orman parçaları")
	var cam := Camera2D.new()
	scene.add_child(cam)
	cam.make_current()
	cam.zoom = Vector2(2, 2)
	await process_frame
	for shot: Array in SHOTS:
		cam.global_position = ref.to_global(ref.map_to_local(shot[1]))
		for _i in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("%s.png" % shot[0]))
	print("DONMUS ", SHOTS.size(), " kare yazıldı: ", out)
	quit()
