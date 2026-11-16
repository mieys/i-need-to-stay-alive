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
	## KAMP_AKINTI=1 (2026-11-16, kullanıcı: "haritada nehirde normalde akıntı sprite'ları vardı, burda neden yok?"): harita animasyonlu
	## karoları (kıyı köpüğü, akıntı çizgileri, nilüfer...) yakalamada tek kareye donuyordu. Bu kipte çimen/ağaç sallanması KAPALI (durağan),
	## taban çekildikten sonra harita AYNEN kare kare örneklenir (<ad>_akinti.png); gen_nehir_kamp.py yalnız döngüde DEĞİŞEN pikselleri
	## şeride alır -> önü kapalı yerler (ağaç tepesi vb.) haritadaki gibi örtülü kalır (ilk denemede katmanlar ayrı çekilince kıyı çimeni
	## ağacın tepesini örtüyordu).
	var akinti: bool = OS.get_environment("KAMP_AKINTI") == "1"
	## KAMP_ZEMIN=1 (2026-11-16, kullanıcı: "ağaçlar ve çalılar sallanmıyor, sallanmalıydı ama yavaşça"): menü tabanı durağan yakalama olduğu
	## için bitkiler donuktu. Bu kipte sallanma KAPALI (durağan) iki çekim: <ad>_bitkili.png (her şey) + <ad>_zemin.png (oyunda sallanan
	## ağaç / çalı / çiçek hücreleri silinmiş; geniş durağan çalılar grass_sway.gd STATIC_WIDE_TEXTURES kalır). gen_nehir_kamp.py farktan
	## bitki sprite'larını çıkarır, menu_camp_scene.gd onları kökünden yavaşça sallar.
	var zemin: bool = OS.get_environment("KAMP_ZEMIN") == "1"
	if not akinti and not zemin:
		load("res://scripts/grass_sway.gd").new().setup(harita)
		load("res://scripts/tree_sway.gd").new().setup(harita)
	load("res://scripts/depth_occluders.gd").new().setup(harita)
	load("res://scripts/forest_canopy.gd").new().setup(harita)
	load("res://scripts/map_shadows.gd").attach(harita)
	load("res://scripts/map_color_grade.gd").attach(harita)
	load("res://scripts/water_fx.gd").attach(harita)
	## Dalgacıklar KAPALI (2026-11-16): menü nehrin dalgacıklarını kamp_su.gdshader ile canlı çizer; yakalamada donmuş kalmasınlar.
	var su_katman := harita.get_node_or_null("Su/Su") as TileMapLayer
	if su_katman != null and su_katman.material is ShaderMaterial:
		(su_katman.material as ShaderMaterial).set_shader_parameter("dalgacik_acik", false)
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
		_ornekle(img, world, k).save_png(_out.path_join("%s%s.png" % [f[0], "_bitkili" if zemin else ""]))
		if zemin:
			_sallananlari_sil(harita)
			await _frames(10)
			await RenderingServer.frame_post_draw
			_ornekle(root.get_texture().get_image(), world, k).save_png(_out.path_join("%s_zemin.png" % f[0]))
		## ORIGIN = çıktının (0, 0) pikselinin dünya pikseli (menu_camp_scene.gd WORLD_ORIGIN, kamp_su.gdshader dunya_origin)
		print("SHOT ", f[0], " k=", k, " center=", center, " ORIGIN=", cam.global_position - world * 0.5)
		if akinti:
			await _akinti_cek(harita, scene, cam, f[0], world, k)
	quit()


## Ekran görüntüsünden dünya pikseli merkezlerini örnekler (1 dünya px = 1 png px).
func _ornekle(img: Image, world: Vector2, k: float) -> Image:
	var out := Image.create(int(world.x), int(world.y), false, Image.FORMAT_RGBA8)
	var ox: float = img.get_width() * 0.5 - world.x * 0.5 * k
	var oy: float = img.get_height() * 0.5 - world.y * 0.5 * k
	for y in range(int(world.y)):
		for x in range(int(world.x)):
			var sx: int = clampi(int(ox + (x + 0.5) * k), 0, img.get_width() - 1)
			var sy: int = clampi(int(oy + (y + 0.5) * k), 0, img.get_height() - 1)
			out.set_pixel(x, y, img.get_pixel(sx, sy))
	return out


## Oyunda sallanan hücreleri siler: tree_sway.gd (Shader Eklenecek/Ağaç*) + grass_sway.gd (LAYER_NAMES) katmanları; geniş durağan çalılar
## (grass_sway.gd STATIC_WIDE_TEXTURES dokulu hücreler) oyunda da sallanmadığı için kalır.
func _sallananlari_sil(harita: Node2D) -> void:
	var gs: GDScript = load("res://scripts/grass_sway.gd")
	var parent: Node = harita.get_node_or_null("Shader Eklenecek")
	if parent == null:
		return
	for child in parent.get_children():
		var layer := child as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		var ad: String = String(layer.name)
		var agac: bool = ad.begins_with("Ağaç")
		if not agac and not (gs.LAYER_NAMES as Array).has(ad):
			continue
		var silinen: int = 0
		for c: Vector2i in layer.get_used_cells():
			if not agac:
				var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
				if src != null and src.texture != null and (gs.STATIC_WIDE_TEXTURES as Array).has(src.texture.resource_path.get_file()):
					continue
			layer.erase_cell(c)
			silinen += 1
		print("ZEMIN sil ", ad, " ", silinen)


const AKINTI_ADIM_MS := 50 ## örnekleme aralığı
const AKINTI_SURE_MS := 6000


## Haritayı (taban kadrajı, hiçbir şey gizlenmeden) AKINTI_SURE_MS boyunca kare kare örnekler, AKINTI_ADIM_MS ızgarasına oturtur ve
## <ad>_akinti.png (ham örnek şeridi, kare = dünya px kadraj) yazar; döngü + değişen piksel maskesi gen_nehir_kamp.py akinti_serit'te.
func _akinti_cek(_harita: Node2D, _scene: Node2D, _cam: Camera2D, ad: String, world: Vector2, k: float) -> void:
	await _frames(5)
	var ornek: Array = [] ## [ms, Image]
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < AKINTI_SURE_MS:
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var w: int = int(world.x * k)
		var h: int = int(world.y * k)
		var reg: Image = img.get_region(Rect2i((img.get_width() - w) / 2, (img.get_height() - h) / 2, w, h))
		reg.resize(int(world.x), int(world.y), Image.INTERPOLATE_NEAREST)
		ornek.append([Time.get_ticks_msec() - t0, reg])
		await process_frame
	## ızgara örnekleri
	var izg: Array[Image] = []
	var j: int = 0
	for t in range(0, AKINTI_SURE_MS - 200, AKINTI_ADIM_MS):
		while j + 1 < ornek.size() and absi(int(ornek[j + 1][0]) - t) <= absi(int(ornek[j][0]) - t):
			j += 1
		izg.append(ornek[j][1])
	## ham ızgara örnekleri AKINTI_SUTUN sütunlu ızgara olarak (tek sıra çok geniş PNG olurdu)
	var ww: int = int(world.x)
	var hh: int = int(world.y)
	var satir: int = int(ceil(izg.size() / float(AKINTI_SUTUN)))
	var kilim := Image.create(ww * AKINTI_SUTUN, hh * satir, false, Image.FORMAT_RGBA8)
	for i in range(izg.size()):
		var im: Image = izg[i]
		im.convert(Image.FORMAT_RGBA8)
		kilim.blit_rect(im, Rect2i(0, 0, ww, hh), Vector2i((i % AKINTI_SUTUN) * ww, (i / AKINTI_SUTUN) * hh))
	kilim.save_png(_out.path_join("%s_akinti.png" % ad))
	print("AKINTI ", ad, " ornek=", ornek.size(), " izgara=", izg.size(), " ADIM_MS=", AKINTI_ADIM_MS)


const AKINTI_SUTUN := 12
