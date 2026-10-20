extends SceneTree

## SAKLANMA (madde 283) GERÇEK ÇİZİCİDE: gerçek harita + harita görselleri (calilik_capture.gd ile aynı kurulum), gerçek Player (Tabanca + Yay), 3 slime, HideBrushManager.
## Oyuncu kovalanırken bir çalılığa ışınlanır -> A: saklı (halka, arayanların başında "?", silahlar içe çekili) -> bir slime halkaya taşınır -> B: görüldü ("!", kırmızı halka, silahlar dışarı).
## Kullanım (gizli masaüstünde): Godot --path . --windowed --resolution 1280x720 -s tools/proto_20261019/saklanma_capture.gd   ortam: SAK_OUT (klasör), SAK_AT ("x,y" çalılık hücresi)

var _out: String = OS.get_environment("SAK_OUT")


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String, center: Vector2, half: Vector2) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var xf: Transform2D = root.get_final_transform() * root.get_canvas_transform()
	var a: Vector2 = xf * (center - half)
	var b: Vector2 = xf * (center + half)
	var rect := Rect2i(Vector2i(a), Vector2i(b - a)).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_out.path_join(name))
	print("SHOT ", name)


func _comp(cells: Dictionary, start: Vector2i) -> Array:
	var comp: Array = []
	var seen: Dictionary = {start: true}
	var st: Array = [start]
	while not st.is_empty():
		var p: Vector2i = st.pop_back()
		comp.append(p)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if cells.has(q) and not seen.has(q):
				seen[q] = true
				st.append(q)
	return comp


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
	var hb: GDScript = load("res://scripts/hide_brush.gd")
	var layer: TileMapLayer = hb.find_layer(harita)
	var cells: Dictionary = {}
	for c: Vector2i in layer.get_used_cells():
		cells[c] = true
	var at_s: PackedStringArray = (OS.get_environment("SAK_AT") if OS.get_environment("SAK_AT") != "" else "129,26").split(",")
	var comp: Array = _comp(cells, Vector2i(int(at_s[0]), int(at_s[1])))
	var cen := Vector2.ZERO
	for c: Vector2i in comp:
		cen += Vector2(c)
	cen /= float(comp.size())
	var deep: Vector2i = comp[0]
	for c: Vector2i in comp:
		if Vector2(c).distance_to(cen) < Vector2(deep).distance_to(cen):
			deep = c
	var bottom: int = deep.y
	for c: Vector2i in comp:
		if c.x == deep.x:
			bottom = maxi(bottom, c.y)
	var to_world := func(c: Vector2i) -> Vector2: return layer.to_global(layer.map_to_local(c))
	var feet_off: float = float(hb.FEET_OFFSET)
	var mgr: Node = load("res://scripts/hide_brush_manager.gd").new()
	mgr.name = "HideBrushManager"
	scene.add_child(mgr)
	var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.scale = Vector2(0.5, 0.5)
	scene.add_child(player)
	player.set_physics_process(false)
	var own_cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if own_cam:
		own_cam.enabled = false
	player.max_health = 100000.0
	player.health = 100000.0
	player.buy_weapon_copy("tabanca", 1)
	player.buy_weapon_copy("yay", 1)
	var out_pos: Vector2 = to_world.call(Vector2i(deep.x, bottom + 4)) - Vector2(0, feet_off)
	player.global_position = out_pos
	var slimes: Array = []
	for off: Vector2 in [Vector2(-70, 60), Vector2(30, 80), Vector2(100, 50)]:
		var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
		scene.add_child(e)
		e.global_position = out_pos + off
		e.max_health = 600000.0
		e.health = 600000.0
		e.set("damage", 0.0)
		slimes.append(e)
	var in_pos: Vector2 = to_world.call(deep) - Vector2(0, feet_off)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = in_pos + Vector2(0, 70)
	cam.make_current()
	await _wait(0.8) ## slime'lar kovalıyor, silahlar dışarıda
	await _shot("sak_0_kovalaniyor.png", cam.global_position, Vector2(230, 150))
	player.global_position = in_pos
	await _wait(1.4)
	await _shot("sak_1_sakli.png", cam.global_position, Vector2(230, 150))
	## en yakın slime halkaya (RING_RADIUS 36) girer
	var near: Node2D = slimes[0]
	for s: Node2D in slimes:
		if s.global_position.distance_to(player.global_position) < near.global_position.distance_to(player.global_position):
			near = s
	var world: Object = load("res://scripts/enemy_world/enemy_world_bridge.gd").fog_world(self)
	var p2: Vector2 = player.global_position + Vector2(26, feet_off)
	near.global_position = p2
	if world != null and int(near.get("_ew_slot")) >= 0:
		world.set_position(int(near.get("_ew_slot")), p2)
	await _wait(0.35)
	await _shot("sak_2_goruldu.png", cam.global_position, Vector2(230, 150))
	print("BITTI state=", player.get("brush_state"))
	quit()
