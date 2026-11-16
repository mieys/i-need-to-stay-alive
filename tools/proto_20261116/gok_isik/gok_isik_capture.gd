extends SceneTree

## GÖK IŞIĞI + YANSIMA prototipleri (2026-11-16, oyuna bağlı DEĞİL) GERÇEK ÇİZİCİDE. Madde 282'nin aracı (tools/proto_20261019/gunes_sis/
## gunes_sis_capture.gd) temel: gerçek harita (harita_baked, (-2, 21) ofset) + main.gd'nin harita görselleri + GERÇEK Atmosphere (gün saati,
## renk geçişi, gece ışıkları; saat dondurulur) + GERÇEK SunClouds (bulut gölgesi; huzme oyunda kapalı -> burada da kapalı).
## Katman sırası: dünya -> bulut gölgesi -> renk geçişi (gece) -> PROTOTİP (A/B/C, sahneyi okur).
## Ek: suyun dokuları (water_fx.gd su_mesafe/su_akis) prototiplere bağlanır + DİK NESNE görünümü: aynı dünyayı yalnız ağaç / çalı / ev /
## karakterleri (görünürlük katmanı 2) çizen 1024x640 SubViewport, 1 texel = 1 dünya px (B aynası + "su üstünde nesne var mı").
## Pencere 1920x1080'e zorlanır (1 dünya px = 2 ekran px, oyun 1080p) ve ortadaki 1280x720 kırpılır (640x360 dünya px).
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261116/gok_isik/gok_isik_capture.gd
##   GI_TAGS   "simdi@150,A@150,B@150,C@150,simdi@465,..." (etiket@saat; 150 = öğle, 465 = gece yarısı)
##   GI_FRAMES kare sayısı (varsayılan 48, kare = 1/12 sn), GI_SPOT "x,y" (başlangıç), GI_OUT çıktı klasörü (mutlak)
##   GI_KESIF  "x,y;x,y;..." -> her nokta için "simdi" gündüz fotoğrafı (GI_OUT/kesif_<i>.png), sonra çık
##   GI_ISIK_X güneş/ay yansımasının kamera merkezinden yatay uzaklığı (dünya px, varsayılan 150; dikeyi suyun ortası aranarak bulunur)
## Sahneler preload EDİLMEZ (-s betiği autoload'lardan önce derlenir) - _run'da load edilir.

const DIR := "res://tools/proto_20261116/gok_isik/"
const SHADERS := {"A": "gi_A_huzme", "B": "gi_B_ayna", "C": "gi_C_kuyu"}
const STEP := 4.0
const DT := 1.0 / 12.0
const DIK_BIT := 2 ## görünürlük katmanı 2
const DIK_SIZE := Vector2i(1024, 640)
const DIK_GROUPS := ["Shader Eklenecek", "Orman parçaları", "ev", "Etkileşimler", "Düşman Üssü"]
const SU_TEX_ORIGIN := Vector2(-576, -384) ## scripts/water_fx.gd TEX_ORIGIN (harita köküne göre)
const SU_TEX_SIZE := Vector2(5248, 4864)
const CROP := Vector2i(1280, 720)

var _out: String = OS.get_environment("GI_OUT")
var _scene: Node2D
var _harita: Node2D
var _cam: Camera2D
var _player: Node2D
var _extras: Array[Node2D] = []
var _atm: Node
var _sc: CanvasLayer
var _post: ColorRect
var _gm: Node
var _dik_vp: SubViewport
var _dik_cam: Camera2D
var _su_mesafe: Texture2D
var _su_akis: Texture2D
var _su_img: Image
var _su_origin := Vector2.ZERO
var _start := Vector2.ZERO
var _isik_ekran := Vector2(150, 70)
var _step := Vector2(4, 0) ## GI_STEP "x,y": kare başına yürüme (konum = başlangıç + yuvarla(adım x kare), kamera tam sayıda kalır)
var _dost1 := Vector2(60, 98) ## GI_DOST1 "dx,dy"
var _dost2_x := -50.0 ## GI_DOST2_X: kıyıdaki dostun başlangıca göre x'i
var _cam_center := Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _dik_isaretle(n: Node) -> void:
	if n is CanvasItem:
		(n as CanvasItem).visibility_layer |= DIK_BIT
	for c in n.get_children():
		_dik_isaretle(c)


## Su mesafe dokusunu CPU'da oku: dünya noktasının kıyıya uzaklığı (shader gi_kiyi ile aynı).
func _kiyi(p: Vector2) -> float:
	var q := Vector2i(((p - _su_origin) / 2.0).floor())
	if q.x < 0 or q.y < 0 or q.x >= _su_img.get_width() or q.y >= _su_img.get_height():
		return -1.0
	return _su_img.get_pixelv(q).r * 64.0 - 1.0


## x sütununda başlangıçtan aşağı ilk su bandı: [kuzey kıyı y, güney kıyı y] (yoksa boş)
func _su_bandi(x: float, y0: float, y1: float) -> Array:
	var ust := -1.0
	var y := y0
	while y < y1:
		var k := _kiyi(Vector2(x, y))
		if ust < 0.0 and k > 0.5:
			ust = y
		elif ust >= 0.0 and k <= 0.5:
			return [ust, y]
		y += 1.0
	return [] if ust < 0.0 else [ust, y1]


func _free_spot(want: Vector2) -> Vector2:
	for r in [0.0, 8.0, 16.0, 32.0, 48.0]:
		for a in range(8):
			var p: Vector2 = want + Vector2.from_angle(float(a) * PI / 4.0) * r
			if not bool(_gm.call("is_position_blocked_by_walls", p)):
				return p
	return want


func _remote(id: int, ch: int, pos: Vector2, facing: String) -> Node2D:
	var r: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	_scene.add_child(r)
	r.setup(id, ch, "")
	r.global_position = pos
	r.set("_target_position", r.global_position)
	if "facing" in r:
		r.set("facing", facing)
	_dik_isaretle(r)
	return r


func _place_cast(start: Vector2) -> void:
	for n in _extras:
		n.queue_free()
	_extras.clear()
	_player.global_position = start
	## birinci dost nehrin öbür yakasında (pembe ağaçlar), ikincisi oyuncunun ARKASINDA kuzey kıyıda (ayakları kıyı çizgisinin ~4 px
	## üstünde): B aynasında yansıması görünsün
	_extras.append(_remote(77, 8, _free_spot(start + _dost1), "left"))
	var bx: float = start.x + _dost2_x
	var band := _su_bandi(bx, start.y - 40.0, start.y + 170.0)
	var bank := start + Vector2(_dost2_x, 46)
	if not band.is_empty():
		bank = Vector2(bx, float(band[0]) - 4.0 - 15.0)
	_extras.append(_remote(78, 3, _free_spot(bank), "right"))


func _set_uniforms(m: ShaderMaterial, t: float) -> void:
	var vp: Viewport = root
	var inv: Transform2D = vp.get_canvas_transform().affine_inverse()
	var size: Vector2 = vp.get_visible_rect().size
	var tl: Vector2 = inv * Vector2.ZERO
	var br: Vector2 = inv * size
	m.set_shader_parameter("dunya_sol_ust", tl)
	m.set_shader_parameter("dunya_boyut", br - tl)
	m.set_shader_parameter("kamera", _cam.global_position)
	m.set_shader_parameter("kamera0", _cam_center)
	m.set_shader_parameter("zaman", t)
	m.set_shader_parameter("ruzgar_ofset", Vector2(-9.0, -3.5) * t + Vector2(1234.0, 567.0))
	m.set_shader_parameter("karanlik", float(load("res://scripts/atmosphere_math.gd").darkness(float(_atm.get("cycle_time")))))
	m.set_shader_parameter("dik_koken", _cam.global_position - Vector2(DIK_SIZE) * 0.5)
	m.set_shader_parameter("dik_boyut", Vector2(DIK_SIZE))


func _material(tag: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(DIR + SHADERS[tag] + ".gdshader")
	var xf: Transform2D = _harita.global_transform
	mat.set_shader_parameter("su_mesafe", _su_mesafe)
	mat.set_shader_parameter("su_akis", _su_akis)
	mat.set_shader_parameter("doku_origin", xf * SU_TEX_ORIGIN)
	mat.set_shader_parameter("doku_size", SU_TEX_SIZE * xf.get_scale())
	mat.set_shader_parameter("dik_doku", _dik_vp.get_texture())
	if tag == "B":
		mat.set_shader_parameter("isik_ekran", _isik_ekran)
	return mat


func _grab() -> Image:
	var img: Image = root.get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	if w == 1920 and h == 1080:
		return img.get_region(Rect2i(Vector2i(320, 180), CROP))
	## başka boyut: aynı dünya bölgesi (ortadaki 640x360 dünya px) en yakın komşuyla 1280x720'ye
	var cw := int(round(float(w) * 2.0 / 3.0))
	var ch := int(round(float(h) * 2.0 / 3.0))
	var r := img.get_region(Rect2i(Vector2i((w - cw) / 2, (h - ch) / 2), Vector2i(cw, ch)))
	r.resize(CROP.x, CROP.y, Image.INTERPOLATE_NEAREST)
	return r


func _capture_tag(spec: String, frames: int) -> void:
	var parts: PackedStringArray = spec.split("@")
	var tag: String = parts[0]
	var saat: float = float(parts[1]) if parts.size() > 1 else 150.0
	## "C#5" = C, tohum 5 (deneme); klasör "C#5" -> "Cx5"
	var tohum := -1.0
	var klasor := tag
	if tag.contains("#"):
		tohum = float(tag.get_slice("#", 1))
		klasor = tag.replace("#", "x")
		tag = tag.get_slice("#", 0)
	_atm.call("debug_set_time", saat)
	var dark: float = float(load("res://scripts/atmosphere_math.gd").darkness(saat))
	var day: float = 1.0 - dark
	_sc.visible = true
	_sc.light_layer.visible = false
	_sc.set("_sun_k", day * day)
	_sc.set("_cloud_k", day)
	_post.visible = false
	var mat: ShaderMaterial = null
	if SHADERS.has(tag):
		mat = _material(tag)
		if tohum >= 0.0:
			mat.set_shader_parameter("tohum_gun", tohum)
			mat.set_shader_parameter("tohum_gece", tohum + 50.0)
		_post.material = mat
		_post.visible = true
	_place_cast(_start)
	var anim: AnimatedSprite2D = _player.get("anim") as AnimatedSprite2D
	if anim and anim.sprite_frames.has_animation("walk_right"):
		anim.play("walk_right")
	## kamera SABİT (yürüyüşün ortası): ışık/yansımanın kendi hareketi okunsun; oyuncu kıyı boyunca kadrajın içinden geçer
	_cam.global_position = _cam_center
	_dik_cam.global_position = _cam.global_position
	var t: float = 0.0
	if mat:
		_set_uniforms(mat, t)
	await _frames(20)
	var dir: String = _out.path_join("%s_t%d" % [klasor, int(saat)])
	DirAccess.make_dir_recursive_absolute(dir)
	for i in range(frames):
		_dik_cam.global_position = _cam.global_position
		if mat:
			_set_uniforms(mat, t)
		await process_frame
		await RenderingServer.frame_post_draw
		_grab().save_png(dir.path_join("f_%03d.png" % i))
		if i == 0 and tag == "B" and OS.get_environment("GI_DIK_DEBUG") != "":
			_dik_vp.get_texture().get_image().save_png(_out.path_join("dik_%d.png" % int(saat)))
		t += DT
		_player.global_position = (_start + _step * float(i + 1)).round()
	print("SHOT ", spec, " -> ", dir, " (", frames, " kare)")


func _kesif(spots: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	_atm.call("debug_set_time", 150.0)
	_sc.light_layer.visible = false
	for i in range(spots.size()):
		var sp: PackedStringArray = spots[i].split(",")
		var p := Vector2(float(sp[0]), float(sp[1]))
		_player.global_position = p
		_cam.global_position = p
		await _frames(12)
		await RenderingServer.frame_post_draw
		var img := _grab()
		img.resize(640, 360, Image.INTERPOLATE_NEAREST)
		img.save_png(_out.path_join("kesif_%d.png" % i))
		print("SHOT kesif ", i, " ", p)


func _run() -> void:
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
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
	await process_frame

	_su_mesafe = load("res://assets/map/su_mesafe.png") as Texture2D
	_su_akis = load("res://assets/map/su_akis.png") as Texture2D
	_su_img = _su_mesafe.get_image()
	if _su_img.is_compressed():
		_su_img.decompress()
	_su_origin = _harita.global_transform * SU_TEX_ORIGIN

	## dik nesne katmanı: sahne kökü + Harita + dik gruplar (alt ağaçlarıyla) + karakterler
	_scene.visibility_layer |= DIK_BIT
	_harita.visibility_layer |= DIK_BIT
	var isaretli: Array[String] = []
	for c in _harita.get_children():
		if str(c.name) in DIK_GROUPS:
			_dik_isaretle(c)
			isaretli.append(str(c.name))
	print("dik gruplar ", isaretli, " | harita cocuklari ", _harita.get_children().map(func(n: Node) -> String: return str(n.name)))

	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_player.scale = Vector2(0.5, 0.5)
	_scene.add_child(_player)
	_player.set_physics_process(false)
	var own_cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if own_cam:
		own_cam.enabled = false
	_player.facing = "right"
	_dik_isaretle(_player)
	_cam = Camera2D.new()
	_cam.zoom = Vector2(2, 2)
	_scene.add_child(_cam)
	_cam.make_current()

	_dik_vp = SubViewport.new()
	_dik_vp.size = DIK_SIZE
	_dik_vp.transparent_bg = true
	_dik_vp.world_2d = root.world_2d
	_dik_vp.canvas_cull_mask = DIK_BIT
	_dik_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_dik_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(_dik_vp)
	_dik_cam = Camera2D.new()
	_dik_vp.add_child(_dik_cam)
	_dik_cam.make_current()

	_atm = load("res://scripts/atmosphere.gd").new()
	_atm.name = "Atmosphere"
	_scene.add_child(_atm)
	var overlay: CanvasLayer = _atm.call("create_overlay_layer")
	_sc = load("res://scripts/sun_clouds.gd").new()
	_sc.name = "SunClouds"
	_scene.add_child(_sc)
	_scene.add_child(overlay)
	var post_layer := CanvasLayer.new()
	post_layer.layer = 1
	_scene.add_child(post_layer)
	_post = ColorRect.new()
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_layer.add_child(_post)
	_post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_post.visible = false
	_scene.add_child(_sc.light_layer)
	await process_frame
	_atm.call("debug_set_weather", 0)
	_atm.call("debug_set_time_scale", 0.0)
	_atm.call("debug_set_time", 150.0)

	var spot_s: String = OS.get_environment("GI_SPOT")
	_start = Vector2(2160, 1756)
	if spot_s != "":
		var sp: PackedStringArray = spot_s.split(",")
		_start = Vector2(float(sp[0]), float(sp[1]))
	if OS.get_environment("GI_STEP") != "":
		var st: PackedStringArray = OS.get_environment("GI_STEP").split(",")
		_step = Vector2(float(st[0]), float(st[1]))
	else:
		_step = Vector2(3.0, -2.6)
	if OS.get_environment("GI_DOST1") != "":
		var d1: PackedStringArray = OS.get_environment("GI_DOST1").split(",")
		_dost1 = Vector2(float(d1[0]), float(d1[1]))
	if OS.get_environment("GI_DOST2_X") != "":
		_dost2_x = float(OS.get_environment("GI_DOST2_X"))
	_player.global_position = _start
	_cam.global_position = _start
	_dik_cam.global_position = _start
	print("pencere ", root.size, " gorunen ", root.get_visible_rect().size)
	await _frames(60)
	var kesif: String = OS.get_environment("GI_KESIF")
	if kesif != "":
		await _kesif(kesif.split(";"))
		quit()
		return
	var frames: int = int(OS.get_environment("GI_FRAMES")) if OS.get_environment("GI_FRAMES") != "" else 48
	var yarim: int = int(OS.get_environment("GI_YURUYUS")) / 2 if OS.get_environment("GI_YURUYUS") != "" else 24
	_cam_center = (_start + _step * float(yarim)).round()
	## güneş/ay yansıması: kamera merkezinden GI_ISIK_X sağda, oradaki ilk su bandının ortasında
	var ix: float = float(OS.get_environment("GI_ISIK_X")) if OS.get_environment("GI_ISIK_X") != "" else 168.0
	var band := _su_bandi(_cam_center.x + ix, _cam_center.y - 170.0, _cam_center.y + 170.0)
	if not band.is_empty():
		_isik_ekran = Vector2(ix, round((float(band[0]) + float(band[1])) * 0.5 - _cam_center.y))
	print("isik_ekran ", _isik_ekran, " su bandi ", band, " kamera ", _cam_center)
	var tags: PackedStringArray = (OS.get_environment("GI_TAGS") if OS.get_environment("GI_TAGS") != "" else "simdi@150,A@150,B@150,C@150").split(",")
	for spec in tags:
		await _capture_tag(spec, frames)
	quit()
