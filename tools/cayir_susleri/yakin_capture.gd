extends SceneTree

## BAŞLANGIÇ ÇAYIRI SÜSLERİ (madde 383) görünüm yakalaması: GERÇEK çizici - harita_baked (main.tscn'deki (-2, 21) ofset) + main.gd'nin harita
## görselleri (GrassSway, TreeSway, DepthOccluders, ForestCanopy, MapShadows, MapColorGrade, WaterFx, GroundTexelPass), oyun kamerası (zoom 2 =
## 960x540 dünya px) + ölçek için bir oyuncu -> out/gercek/<ad>.png. Gizli masaüstünde: tools/cayir_susleri/yakin_run.ps1
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok - _run'da load edilir.

const SHOTS := [
	{"name": "ev_cikisi", "center": Vector2i(124, 88), "player": Vector2i(120, 85)},
	{"name": "kavsak_nehir", "center": Vector2i(122, 104), "player": Vector2i(121, 100)},
	{"name": "guneydogu_cayir", "center": Vector2i(156, 146), "player": Vector2i(152, 150)},
	{"name": "avci_kampi", "center": Vector2i(152, 160), "player": Vector2i(147, 163)},
	{"name": "guneybati", "center": Vector2i(118, 146), "player": Vector2i(116, 150)},
]

var _out: String = ProjectSettings.globalize_path("res://").path_join("tools/cayir_susleri/out/gercek")


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
	var ref: TileMapLayer = harita.get_node("Orman parçaları/Orman parçaları")
	var to_world := func(c: Vector2i) -> Vector2: return ref.to_global(ref.map_to_local(c))
	var cam := Camera2D.new()
	scene.add_child(cam)
	cam.zoom = Vector2(2, 2)
	var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.scale = Vector2(0.5, 0.5)
	scene.add_child(player)
	player.set_physics_process(false)
	var own_cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if own_cam:
		own_cam.enabled = false
	cam.make_current()
	player.facing = "down"
	for shot: Dictionary in SHOTS:
		player.global_position = to_world.call(shot["player"])
		cam.global_position = to_world.call(shot["center"])
		await _frames(30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("%s.png" % shot["name"]))
		print("SHOT ", shot["name"])
	quit()
