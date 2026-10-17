extends SceneTree

## HARİTA RENK AYARI PROTOTİPLERİ (2026-10-16, oyuna bağlı DEĞİL) - gerçek çizicide.
## Harita (çimen/toprak/su shader'ları + sallanma + pişmiş gölgeler) 3 noktada bir kez yakalanır; aynı kare üzerine
## Mevcut + A-D renk ayarı (harita_renk.gdshader) uygulanır, karakterler ayarın ÜSTÜNE (tam renk), en üste oyundaki vinyet.
## 960x540 = oyunun 1920x1080 / kamera x2 görüş alanı, 1 piksel = 1 dünya pikseli.
## Çalıştır: Godot --path . --windowed --resolution 480x270 -s tools/proto_20261016/harita_renk/harita_renk_capture.gd
## Çıktı: tools/proto_20261016/harita_renk/out/<nokta>_<ayar>.png
## 2026-10-16: A oyuna bağlandı (madde 181) - harita shader'ları artık ayarı KENDİSİ uyguluyor. Prototipleri yeniden üretmek için önce
## shaders/harita_renk.gdshaderinc HR_GUC = 0.0. HR_MODE=oyun ortam değişkeniyle oyunun kendi yolu (MapColorGrade.attach, ekran ayarı
## yok) yakalanır -> out/<nokta>_oyun_A.png (prototip A ile karşılaştırma).

const OUT := "res://tools/proto_20261016/harita_renk/out/"
const VIEW := Vector2i(960, 540)

const PRESETS := {
	"0_mevcut": {},
	## A: en yakını - yeşil biraz daha gerçek yeşile döner ve %12 koyulaşır, parlak yüzeyler sakinleşir; kontrast aynı.
	"A_derin_cayir": {
		"green_hue": 0.02, "green_val": 0.88, "green_sat": 0.92, "hi_desat": 0.85, "knee": 0.7, "knee_strength": 1.2,
		"calm": 0.25, "shadow_tint": Vector3(0.0, 0.003, 0.01),
	},
	## B: yumuşak ışık - A kadar koyulaşmaz, kontrast hafif iner, parlaklar en çok burada bastırılır; doku en çok burada
	## sakinleşir (çiçek/yonca/ot benekleri), hafif sıcak ışık.
	"B_yumusak_isik": {
		"contrast": 0.94, "green_hue": 0.015, "green_val": 0.92, "green_sat": 0.93, "hi_desat": 0.82, "warm_sat": 0.92,
		"blue_sat": 0.92, "knee": 0.66, "knee_strength": 1.6, "calm": 0.5, "highlight_tint": Vector3(0.014, 0.01, 0.0),
	},
	## C: sıcak, samimi RPG - yeşil zeytine yakın ve koyu, ışık altın, gölgeler hafif mor (yeşilin tamamlayıcısı).
	"C_altin_hasat": {
		"green_val": 0.87, "green_sat": 0.9, "hi_desat": 0.85, "warm_sat": 1.05, "blue_sat": 0.92,
		"knee": 0.7, "knee_strength": 1.3, "calm": 0.3,
		"shadow_tint": Vector3(0.01, -0.002, 0.012), "highlight_tint": Vector3(0.024, 0.012, -0.014),
	},
	## D: serin ve loş - genel %10 karanlık, yeşil zümrüde döner, toprak sakin; karakterler en çok bu zeminde öne çıkar.
	"D_serin_golge": {
		"exposure": 0.9, "contrast": 1.02, "saturation": 0.95, "green_hue": 0.04, "green_val": 0.88, "green_sat": 0.85,
		"hi_desat": 0.85, "warm_sat": 0.85, "knee": 0.62, "knee_strength": 1.5, "calm": 0.35,
		"shadow_tint": Vector3(-0.004, 0.004, 0.02), "highlight_tint": Vector3(0.0, 0.004, 0.008),
	},
}


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _grab(vp: SubViewport) -> Image:
	await RenderingServer.frame_post_draw
	var im: Image = vp.get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	return im


func _make_vp(transparent: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = VIEW
	vp.transparent_bg = transparent
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	return vp


func _layer_center(harita: Node, path: String) -> Vector2:
	var l: TileMapLayer = harita.get_node_or_null(path)
	if l == null:
		push_error("katman yok: " + path)
		return Vector2(2048, 2048)
	## Kullanılan hücrelerin ortancası (dağınık katmanda dikdörtgen ortası boşluğa/suya düşebiliyor).
	var xs: Array = []
	var ys: Array = []
	for c in l.get_used_cells():
		xs.append(c.x)
		ys.append(c.y)
	xs.sort()
	ys.sort()
	return l.to_global(l.map_to_local(Vector2i(xs[xs.size() / 2], ys[ys.size() / 2])))


func _add_char(parent: Node, frames: String, scale_val: float, pos: Vector2, anim: String) -> void:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = load(frames)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * scale_val * float(load("res://scripts/entity_scale.gd").SIZE) * 0.5
	s.position = pos
	parent.add_child(s)
	s.play(anim)


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	# --- harita
	var mvp := _make_vp(false)
	var harita: Node2D = load("res://scenes/harita_baked.tscn").instantiate()
	mvp.add_child(harita)
	await process_frame
	var gs: Node = load("res://scripts/grass_sway.gd").new()

	gs.setup(harita)
	var ts: Node = load("res://scripts/tree_sway.gd").new()

	ts.setup(harita)
	load("res://scripts/map_shadows.gd").attach(harita)
	var oyun_modu: bool = OS.get_environment("HR_MODE") == "oyun"
	var presets: Dictionary = PRESETS
	if oyun_modu:
		## HR_TAG=once: madde 184 öncesi (sakin doku + başıboş çimen gizleme KAPALI, sadece renk ayarı).
		var yeni: bool = OS.get_environment("HR_TAG") != "once"
		print("zeminin altina alinan hucre: ", load("res://scripts/map_color_grade.gd").attach(harita, yeni, yeni))
		## HR_PLATO=0: madde 186 öncesi plato tepeleri (orman_parcalari_doku cim_efekt 0 = eski desen).
		if OS.get_environment("HR_PLATO") == "0":
			var orman := harita.get_node("Orman parçaları/Orman parçaları 2") as TileMapLayer
			(orman.material as ShaderMaterial).set_shader_parameter("cim_efekt", 0.0)
		## HR_TAG: çıktı adı (madde 184 önce/sonra karşılaştırması için).
		var tag: String = OS.get_environment("HR_TAG")
		presets = {(tag if tag != "" else "oyun_A"): {}}
	## HR_CANOPY=1: oyundaki gibi "Orman parçaları 2" karakterlerin/köprünün üstünde (z 2, forest_canopy.gd).
	if OS.get_environment("HR_CANOPY") == "1":
		load("res://scripts/forest_canopy.gd").new().setup(harita)
	var mcam := Camera2D.new()
	mvp.add_child(mcam)
	mcam.make_current()

	# --- karakterler (saydam katman, ayarın üstüne)
	var cvp := _make_vp(true)
	var cholder := Node2D.new()
	cvp.add_child(cholder)
	_add_char(cholder, "res://assets/characters/matthew_frames.tres", 1.968417, Vector2(-46, 6), "idle_down")
	_add_char(cholder, "res://assets/characters/sovalye_frames.tres", 2.2368375, Vector2(22, -4), "idle_down")
	_add_char(cholder, "res://assets/characters/cadi_frames.tres", 2.2368375, Vector2(-8, 44), "idle_down")
	var ccam := Camera2D.new()
	ccam.position = Vector2.ZERO
	cvp.add_child(ccam)
	ccam.make_current()

	# --- birleştirme + renk ayarı
	var gvp := _make_vp(false)
	var base := TextureRect.new()
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gvp.add_child(base)
	var grade := ColorRect.new()
	grade.size = Vector2(VIEW)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://tools/proto_20261016/harita_renk/harita_renk.gdshader")
	mat.set_shader_parameter("texel", Vector2(1.0 / VIEW.x, 1.0 / VIEW.y))
	grade.material = mat
	gvp.add_child(grade)
	var chars := TextureRect.new()
	chars.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chars.texture = cvp.get_texture()
	gvp.add_child(chars)
	gvp.add_child(load("res://scenes/vignette_overlay.tscn").instantiate())

	var spots := {
		"koy": _layer_center(harita, "ev/Ev") + Vector2(0, 40),
		"kopru": _layer_center(harita, "Köprü/Köprü alt"),
		"guneydogu": Vector2(3440, 3280),
		## madde 184: başıboş düz çimen karolarının (Orman parçaları 2 ...) en yoğun olduğu ekran
		"orman2": Vector2(3616, 2000),
		## madde 184: Su/Çimler'e boyanmış başıboş düz çimen karolarının en yoğun olduğu ekran
		"su_kenari": Vector2(2960, 1392),
		## kullanıcı: "köprünün üstünde bitki görünüyor" - batıdaki halat köprü (hücre x 43-65, y 120-121)
		"kopru_bati": Vector2(872, 1936),
	}
	## HR_SPOT=<ad>: sadece o nokta
	var only: String = OS.get_environment("HR_SPOT")
	if only != "":
		spots = {only: spots[only]}
	## Shader'daki varsayılanlarla aynı (ayarda olmayan değer sıfırlansın).
	var defaults := {
		"exposure": 1.0, "contrast": 1.0, "pivot": 0.45, "knee": 1.0, "knee_strength": 0.0, "saturation": 1.0,
		"green_sat": 1.0, "green_hue": 0.0, "green_val": 1.0, "hi_desat": 1.0, "warm_sat": 1.0, "blue_sat": 1.0, "shadow_tint": Vector3.ZERO,
		"highlight_tint": Vector3.ZERO, "lift": Vector3.ZERO, "calm": 0.0, "calm_edge": 0.12,
	}
	print("spots: ", spots)

	for spot in spots:
		mcam.position = spots[spot]
		await _wait(1.0)
		var map_img := await _grab(mvp)
		base.texture = ImageTexture.create_from_image(map_img)
		for preset in presets:
			var p: Dictionary = presets[preset]
			grade.visible = not p.is_empty()
			for k in defaults:
				mat.set_shader_parameter(k, p.get(k, defaults[k]))
			for i in 3:
				await process_frame
			var out := await _grab(gvp)
			out.save_png(ProjectSettings.globalize_path(OUT + "%s_%s.png" % [spot, preset]))
			print("yazildi ", spot, " ", preset)
	quit()
