extends SceneTree

## GÜN IŞIĞI x4 + SİSLİ HAVA x3 prototipleri (madde 282) GERÇEK ÇİZİCİDE: gerçek harita (harita_baked, (-2, 21) ofset) + main.gd'nin harita
## görselleri + GERÇEK Atmosphere (gün saati, renk geçişi, gece ışıkları; saat dondurulur) + GERÇEK SunClouds (bulut gölgesi + şu anki huzme).
## Katman sırası main.gd ile aynı (hepsi layer 1, ağaç sırası): dünya -> bulut gölgesi -> [ÖN: C] -> renk geçişi -> [ARKA: A/B/D/S1-3] -> güneş huzmesi.
## Yerel oyuncu kamerayla sağa yürür (5 dünya px / kare = 60 px/sn, kare = 1/12 sn), 2 dost kuklası; sis etiketlerinde 3 yaratık (hızı 0).
## Kullanım: Godot --path . --windowed --resolution 1280x720 -s tools/proto_20261019/gunes_sis/gunes_sis_capture.gd
##   GS_TAGS  "simdi,A,B,C,D,acik,S1,S2,S3" (etiket@saat: "S2@465" = gece; varsayılan saat 150 = öğle)
##   GS_FRAMES kare sayısı (varsayılan 36), GS_SPOT "x,y" (başlangıç kamera merkezi), GS_OUT çıktı klasörü (mutlak)
##   GS_EXPLORE=1: haritayı tarar, ağaç oranı uygun 4 nokta için "simdi" fotoğrafı (GS_OUT/nokta_<i>.png) + konsola liste
## Sahneler preload EDİLMEZ (-s betiği autoload'lardan önce derlenir) - _run'da load edilir.

const DIR := "res://tools/proto_20261019/gunes_sis/"
const SHADERS := {"A": "gunes_A_perde", "B": "gunes_B_agac", "C": "gunes_C_bulut", "D": "gunes_D_pus",
	"S1": "sis_1_yer", "S2": "sis_2_pus", "S3": "sis_3_ruh"}
const PRE_TAGS := ["C"]
const FOG_TAGS := ["acik", "S1", "S2", "S3"]
const STEP := 5.0
const DT := 1.0 / 12.0

var _out: String = OS.get_environment("GS_OUT")
var _scene: Node2D
var _harita: Node2D
var _cam: Camera2D
var _player: Node2D
var _extras: Array[Node2D] = []
var _atm: Node
var _sc: CanvasLayer
var _pre: ColorRect
var _post: ColorRect
var _mask_tex: ImageTexture
var _mask_origin := Vector2.ZERO
var _mask_size := Vector2.ONE
var _mask_cell := 16.0
var _mask_img: Image
var _gm: Node


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _tree_layers(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is TileMapLayer:
			var nm: String = c.name
			if nm.begins_with("Ağaç") or nm.begins_with("Orman parçaları") or nm.begins_with("Dış orman") or nm.begins_with("orman parçaları"):
				out.append(c)
		_tree_layers(c, out)


## Ağaç maskesi: 1 piksel = 1 hücre (16 dünya px), ağaç/orman katmanı dolu hücreler 1.
func _build_tree_mask() -> void:
	var layers: Array = []
	_tree_layers(_harita, layers)
	var pts: Array[Vector2] = []
	for l: TileMapLayer in layers:
		_mask_cell = float(l.tile_set.tile_size.x)
		for c: Vector2i in l.get_used_cells():
			pts.append(l.to_global(l.map_to_local(c)))
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	_mask_origin = (mn - Vector2.ONE * _mask_cell * 0.5).floor()
	var sz := Vector2i(((mx - _mask_origin) / _mask_cell).ceil()) + Vector2i(2, 2)
	_mask_img = Image.create(sz.x, sz.y, false, Image.FORMAT_L8)
	for p in pts:
		var q := Vector2i(((p - _mask_origin) / _mask_cell).floor())
		_mask_img.set_pixelv(q, Color.WHITE)
	_mask_size = Vector2(sz)
	_mask_tex = ImageTexture.create_from_image(_mask_img)
	print("maske ", sz, " katman=", layers.size(), " hucre=", pts.size())


func _tree_frac(center: Vector2) -> float:
	var half := Vector2(320, 180)
	var a := Vector2i(((center - half - _mask_origin) / _mask_cell).floor())
	var b := Vector2i(((center + half - _mask_origin) / _mask_cell).ceil())
	var n := 0
	var tot := 0
	for y in range(a.y, b.y):
		for x in range(a.x, b.x):
			tot += 1
			if x >= 0 and y >= 0 and x < _mask_img.get_width() and y < _mask_img.get_height() and _mask_img.get_pixel(x, y).r > 0.5:
				n += 1
	return float(n) / maxf(float(tot), 1.0)


func _free_spot(want: Vector2) -> Vector2:
	for r in [0.0, 16.0, 32.0, 48.0, 64.0]:
		for a in range(8):
			var p: Vector2 = want + Vector2.from_angle(float(a) * PI / 4.0) * r
			if not bool(_gm.call("is_position_blocked_by_walls", p)):
				return p
	return want


func _remote(id: int, ch: int, pos: Vector2) -> Node2D:
	var r: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	_scene.add_child(r)
	r.setup(id, ch, "")
	r.global_position = _free_spot(pos)
	r.set("_target_position", r.global_position)
	return r


func _enemy(path: String, pos: Vector2) -> Node2D:
	var e: Node2D = (load(path) as PackedScene).instantiate()
	_scene.add_child(e)
	e.global_position = _free_spot(pos)
	e.set("speed", 0.0)
	e.max_health = 600000.0
	e.health = 600000.0
	return e


func _overlay_rect(parent: CanvasLayer) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.visible = false
	return r


func _set_uniforms(m: ShaderMaterial, t: float) -> void:
	var vp: Viewport = root
	var inv: Transform2D = vp.get_canvas_transform().affine_inverse()
	var size: Vector2 = vp.get_visible_rect().size
	var tl: Vector2 = inv * Vector2.ZERO
	var br: Vector2 = inv * size
	m.set_shader_parameter("dunya_sol_ust", tl)
	m.set_shader_parameter("dunya_boyut", br - tl)
	m.set_shader_parameter("kamera", (tl + br) * 0.5)
	m.set_shader_parameter("oyuncu", _player.global_position)
	m.set_shader_parameter("zaman", t)
	m.set_shader_parameter("ruzgar_ofset", Vector2(-9.0, -3.5) * t + Vector2(1234.0, 567.0))
	m.set_shader_parameter("karanlik", float(load("res://scripts/atmosphere_math.gd").darkness(float(_atm.get("cycle_time")))))


func _place_cast(start: Vector2, fog: bool) -> void:
	for n in _extras:
		n.queue_free()
	_extras.clear()
	_player.global_position = _free_spot(start)
	_extras.append(_remote(77, 8, start + Vector2(120, -38)))
	_extras.append(_remote(78, 3, start + Vector2(50, 46)))
	if fog:
		_extras.append(_enemy("res://scenes/creatures/enemy_iskelet1.tscn", start + Vector2(250, 20)))
		_extras.append(_enemy("res://scenes/creatures/enemy_hayalet1.tscn", start + Vector2(330, -62)))
		_extras.append(_enemy("res://scenes/creatures/enemy_slime1.tscn", start + Vector2(-140, 64)))


func _capture_tag(spec: String, start: Vector2, frames: int) -> void:
	var parts: PackedStringArray = spec.split("@")
	var tag: String = parts[0]
	var saat: float = float(parts[1]) if parts.size() > 1 else 150.0
	var fog: bool = tag in FOG_TAGS
	_atm.call("debug_set_time", saat)
	var dark: float = float(load("res://scripts/atmosphere_math.gd").darkness(saat))
	var day: float = 1.0 - dark
	## şu anki güneş + bulut: "simdi"/"acik"ta açık, sis etiketlerinde kapalı (sisli hava = kapalı gökyüzü), C kendi bulutunu çizer
	_sc.visible = not (tag in ["C", "S1", "S2", "S3"])
	_sc.light_layer.visible = tag in ["simdi", "acik"]
	_sc.set("_sun_k", day * day)
	_sc.set("_cloud_k", day)
	_pre.visible = false
	_post.visible = false
	var mat: ShaderMaterial = null
	if SHADERS.has(tag):
		mat = ShaderMaterial.new()
		mat.shader = load(DIR + SHADERS[tag] + ".gdshader")
		if tag == "B":
			mat.set_shader_parameter("agac_maske", _mask_tex)
			mat.set_shader_parameter("maske_koken", _mask_origin)
			mat.set_shader_parameter("maske_boyut", _mask_size)
			mat.set_shader_parameter("hucre", _mask_cell)
		var rect: ColorRect = _pre if tag in PRE_TAGS else _post
		rect.material = mat
		rect.visible = true
	_place_cast(start, fog)
	var anim: AnimatedSprite2D = _player.get("anim") as AnimatedSprite2D
	if anim and anim.sprite_frames.has_animation("walk_right"):
		anim.play("walk_right")
	_cam.global_position = _player.global_position
	var t: float = 0.0
	if mat:
		_set_uniforms(mat, t)
	await _frames(20)
	var dir: String = _out.path_join(tag if parts.size() == 1 else "%s_t%d" % [tag, int(saat)])
	DirAccess.make_dir_recursive_absolute(dir)
	for i in range(frames):
		if mat:
			_set_uniforms(mat, t)
		await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		if img.get_width() > 1280:
			img.resize(1280, 720, Image.INTERPOLATE_NEAREST)
		img.save_png(dir.path_join("f_%03d.png" % i))
		t += DT
		_player.global_position += Vector2(STEP, 0)
		_cam.global_position = _player.global_position
	print("SHOT ", spec, " -> ", dir, " (", frames, " kare)")


func _explore() -> void:
	var rect: Rect2 = _gm.call("get_map_world_rect")
	var cands: Array = []
	var y: float = rect.position.y + 240.0
	while y < rect.end.y - 240.0:
		var x: float = rect.position.x + 360.0
		while x < rect.end.x - 360.0:
			var c := Vector2(x, y)
			if not bool(_gm.call("is_position_blocked_by_walls", c)):
				var f: float = _tree_frac(c)
				cands.append([absf(f - 0.22), c, f])
			x += 320.0
		y += 240.0
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var picked: Array = []
	for c: Array in cands:
		var ok := true
		for p: Vector2 in picked:
			if p.distance_to(c[1]) < 900.0:
				ok = false
		if ok:
			picked.append(c[1])
			print("NOKTA ", picked.size() - 1, " ", c[1], " agac=", snappedf(c[2], 0.01))
		if picked.size() >= 4:
			break
	DirAccess.make_dir_recursive_absolute(_out)
	for i in range(picked.size()):
		_player.global_position = picked[i]
		_cam.global_position = picked[i]
		await _frames(12)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("nokta_%d.png" % i))
	print("SHOT kesif ", picked)


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	_gm = root.get_node("GameManager")
	_gm.selected_char_id = 1
	_gm.selected_character = 1
	var ui: Node = root.get_node_or_null("UISound")
	if ui:
		ui.set("gfx_sun_clouds", true)
	_scene = Node2D.new()
	root.add_child(_scene)
	current_scene = _scene
	_harita = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	_harita.name = "Harita"
	_harita.position = Vector2(-2, 21)
	_scene.add_child(_harita)
	await process_frame
	load("res://scripts/grass_sway.gd").new().setup(_harita)
	load("res://scripts/tree_sway.gd").new().setup(_harita)
	load("res://scripts/depth_occluders.gd").new().setup(_harita)
	load("res://scripts/forest_canopy.gd").new().setup(_harita)
	load("res://scripts/map_shadows.gd").attach(_harita)
	load("res://scripts/map_color_grade.gd").attach(_harita)
	load("res://scripts/water_fx.gd").attach(_harita)
	load("res://scripts/ground_texel_pass.gd").attach(_harita)
	_build_tree_mask()

	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_player.scale = Vector2(0.5, 0.5)
	_scene.add_child(_player)
	_player.set_physics_process(false)
	var own_cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if own_cam:
		own_cam.enabled = false
	_player.facing = "right"
	_cam = Camera2D.new()
	_cam.zoom = Vector2(2, 2)
	_scene.add_child(_cam)
	_cam.make_current()

	## main.gd sırası: bulut gölgesi -> renk geçişi -> (sis) -> güneş huzmesi; prototip ön/arka katmanları araya
	_atm = load("res://scripts/atmosphere.gd").new()
	_atm.name = "Atmosphere"
	_scene.add_child(_atm)
	var overlay: CanvasLayer = _atm.call("create_overlay_layer")
	_sc = load("res://scripts/sun_clouds.gd").new()
	_sc.name = "SunClouds"
	_scene.add_child(_sc)
	var pre_layer := CanvasLayer.new()
	pre_layer.layer = 1
	_scene.add_child(pre_layer)
	_pre = _overlay_rect(pre_layer)
	_scene.add_child(overlay)
	var post_layer := CanvasLayer.new()
	post_layer.layer = 1
	_scene.add_child(post_layer)
	_post = _overlay_rect(post_layer)
	_scene.add_child(_sc.light_layer)
	await process_frame
	_atm.call("debug_set_weather", 0)
	_atm.call("debug_set_time_scale", 0.0)
	_atm.call("debug_set_time", 150.0)

	var spot_s: String = OS.get_environment("GS_SPOT")
	var start := Vector2(2912, 1390)
	if spot_s != "":
		var sp: PackedStringArray = spot_s.split(",")
		start = Vector2(float(sp[0]), float(sp[1]))
	_player.global_position = start
	_cam.global_position = start
	await _frames(60)
	if OS.get_environment("GS_EXPLORE") != "":
		await _explore()
		quit()
		return
	var frames: int = int(OS.get_environment("GS_FRAMES")) if OS.get_environment("GS_FRAMES") != "" else 36
	var tags: PackedStringArray = (OS.get_environment("GS_TAGS") if OS.get_environment("GS_TAGS") != "" else "simdi,A,B,C,D").split(",")
	for spec in tags:
		await _capture_tag(spec, start, frames)
	quit()
