extends CanvasLayer

## Gün-gece + hava durumunun EKRAN renk geçişi ve gece ışıkları (bkz. atmosphere.gd dosya başı,
## shaders/atmosphere_grade.gdshader). atmosphere.gd her karede apply() ile renk ayarını verir; bu düğüm:
##  1) ışık kaynaklarını (her oyuncunun etrafı + "night_glow" grubundaki yetenek/mermi/namlu/görev ışıkları, bkz.
##     night_glow.gd) ekranın 1/4 çözünürlüğündeki bir SubViewport'a yumuşak, renkleri toplanan lekeler olarak çizer
##     (vision_fog.gd'nin maske SubViewport'uyla AYNI dünya->ekran dönüşümü),
##  2) tüm ekranı kaplayan ColorRect ile sahneye renk ayarı + ışıkları uygular.
## main.gd bu katmanı VisionFog'un hemen ÖNCESİNE taşır (aynı layer=1'deki CanvasLayer'ların çizim sırasını ağaç
## sırası belirliyor, bkz. main.gd'deki sis notu): dünya -> BU geçiş -> sis -> HUD. HUD etkilenmez.
##
## PERF: tam gündüz + açık havada (renk ayarı birim) geçiş, ekran kopyası ve ışık haritası HİÇ çalışmaz; ışık kazancı
## ~0 iken (gündüz yağmur/rüzgar) sadece renk geçişi çalışır, ışık haritası çizilmez.

const GradeShader: Shader = preload("res://shaders/atmosphere_grade.gdshader")
const AtmosphereMathRef: GDScript = preload("res://scripts/atmosphere_math.gd")
const NightGlowScript: GDScript = preload("res://scripts/night_glow.gd")
const PhysicsInterpScript: GDScript = preload("res://scripts/physics_interp.gd")

const LIGHT_DOWNSCALE := 4
const LIGHT_TEX_SIZE := 64

## Kullanıcı isteği: "hava karardığında ve gece olduğunda karakterin etrafı hafif daha aydınlık görünecek" - her
## oyuncunun (yerel + uzak kuklalar; ölü değil ya da yerde yatıyor) etrafında nötr, hafif bir ışık havuzu.
## Yarıçap DÜNYA birimi (karakter ~30 birim boyunda).
## DENGE (kullanıcı geri bildirimi 2026-09-25: "karakterden çıkan parıltı efektinin sırıtmaması gerekiyor, özellikle onu
## dengelemen lazım"): ilk sürüm 100 birim/0.4 güç/sıcak sarı (1, 0.9, 0.74) idi - karakterin etrafında belirgin, renkli
## bir leke gibi duruyordu. Artık daha geniş (kenar geçişi daha yumuşak), yarı güçte ve neredeyse nötr beyaz; ayrıca
## gücü parıltı eşiğinin (atmosphere_grade.gdshader bloom_threshold) ALTINDA kalıyor - sadece karanlığı biraz açar, hale yapmaz.
const PLAYER_LIGHT_RADIUS := 125.0
const PLAYER_LIGHT_ENERGY := 0.2
const PLAYER_LIGHT_COLOR := Color(1.0, 0.97, 0.92)
## Yetenek/mermi/namlu/görev ışıklarının genel gücü (kullanıcı: "parıltıları %20 azalt").
## Kullanıcı isteği (2026-09-25): "Oyundaki tüm parıltı efektlerinin gücünü %30 azalt" - 0.8 -> 0.56 (x0.7). Oyuncunun
## kendi etrafındaki ışık (PLAYER_LIGHT_*) bir "parıltı efekti" değil, dokunulmadı; bloom tarafı atmosphere_math.gd
## GLOW_GAIN_MAX'ta aynı oranda.
const GLOW_ENERGY_SCALE := 0.56
## Kullanıcı bildirimi (2026-09-25, ikinci tur): "parıltılar hala çok kamaştırıcı ve yoğun (bazıları) yoğun olanları
## zayıflatman ve genel olarak parıltıların daha ufak olması gerekiyor çok genişler" - (1) HER yetenek/mermi/efekt
## ışığının yarıçapı x0.65 (katalogdaki tek tek değerlere dokunmadan, tek yerden); (2) tek bir ışığın gücü
## GLOW_ENERGY_CAP'te kırpılır: zaten zayıf olanlar aynen kalır, en yoğunlar (patlama, namlu, meteor, flaşlar) tavana
## iner. Oyuncunun kendi etrafındaki ışık (PLAYER_LIGHT_*) bu değildir, dokunulmadı. Bloom: atmosphere_math GLOW_GAIN_MAX.
const GLOW_RADIUS_SCALE := 0.65
const GLOW_ENERGY_CAP := 0.4
## PERF (kullanıcı bildirimi 2026-09-25: "hava durumları fpsi düşürüyor"): yağmurlu/sağanak gündüzde bile ışık kazancı
## > 0 olduğu için ışık haritası (tüm night_glow düğümlerinin toplanması + 1/4 çözünürlüklü SubViewport çizimi) HER
## karede çalışıyordu. Artık LIGHT_MAP_EVERY karede bir güncellenir (arada son harita kullanılır) - yumuşak, 1/4
## çözünürlüklü ışık lekelerinde bir karelik gecikme fark edilmez.
const LIGHT_MAP_EVERY := 2
## Karakter kökü gövdenin ortasına yakın; ışık ayakların biraz üstünde dursun (zemine düşen ışık).
const PLAYER_LIGHT_OFFSET := Vector2(0.0, 6.0)
const PLAYER_GROUPS: Array[String] = ["player", "remote_players"]
## Çizgi ışıklarında (şimşek ışını, lazer) leke aralığı / yarıçap ve tek çizgideki en fazla leke.
const SEGMENT_SPACING := 0.6
const SEGMENT_MAX_DOTS := 48
## Işık kazancı bunun altındaysa ışık haritası hiç güncellenmez.
const MIN_LIGHT_GAIN := 0.01

var _rect: ColorRect = null
var _copy: BackBufferCopy = null
var _material: ShaderMaterial = null
var _light_viewport: SubViewport = null
var _drawer: LightMapDrawer = null
var _light_gain: float = 0.0
var _active: bool = false


## Işık haritasını çizen düğüm - SubViewport'un içinde, kendi (birim) tuvalinde ekran/4 piksel koordinatıyla çizer.
class LightMapDrawer extends Node2D:
	var light_tex: Texture2D = null
	## [merkez (px), yarıçap (px), renk (güç çarpılmış)]
	var lights: Array = []

	func _draw() -> void:
		for l: Array in lights:
			var c: Vector2 = l[0]
			var r: float = l[1]
			draw_texture_rect(light_tex, Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0), false, l[2])


func _ready() -> void:
	layer = 1
	process_priority = 999 ## hareket eden her şeyden (ve kameradan) sonra - sisle (1000) aynı mantık

	_light_viewport = SubViewport.new()
	_light_viewport.name = "LightMap"
	_light_viewport.disable_3d = true
	_light_viewport.transparent_bg = true ## (0,0,0,0)'a temizlenir; ışıklar RGB'de toplanır
	_light_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_light_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_fit_light_map(get_viewport().get_visible_rect().size)
	add_child(_light_viewport)

	_drawer = LightMapDrawer.new()
	_drawer.name = "Lights"
	_drawer.light_tex = _make_light_texture()
	_drawer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR ## proje varsayılanı NEAREST - ışık yumuşak olmalı
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_drawer.material = add_mat
	_light_viewport.add_child(_drawer)

	_material = ShaderMaterial.new()
	_material.shader = GradeShader
	_material.set_shader_parameter("light_map", _light_viewport.get_texture())

	## Ekranı okuyan (hint_screen_texture) iki geçiş (bu + sis) art arda çizildiğinde Godot ekranı sadece İLK okuyan için
	## kopyalayabilir; bu kopya garantisi dünya çizimi bittikten SONRAKİ hâli okumamızı sağlar (sis de kendi kopyasını
	## alıyor, bkz. vision_fog.gd).
	_copy = BackBufferCopy.new()
	_copy.name = "ScreenCopy"
	_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_copy.visible = false
	add_child(_copy)

	_rect = ColorRect.new()
	_rect.name = "Grade"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	_rect.visible = false
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Yumuşak ışık lekesi: beyaz, alfa = (1 - d^2)^2 (merkez düz, kenar yavaşça sıfıra iner - sert çember yok).
static func _make_light_texture() -> ImageTexture:
	var img := Image.create(LIGHT_TEX_SIZE, LIGHT_TEX_SIZE, false, Image.FORMAT_RGBA8)
	var half: float = LIGHT_TEX_SIZE * 0.5
	for y in range(LIGHT_TEX_SIZE):
		for x in range(LIGHT_TEX_SIZE):
			var d: float = Vector2(float(x) + 0.5 - half, float(y) + 0.5 - half).length() / half
			var a: float = 0.0
			if d < 1.0:
				var k: float = 1.0 - d * d
				a = k * k
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _fit_light_map(size: Vector2) -> void:
	var wanted := Vector2i(
		maxi(1, ceili(size.x / float(LIGHT_DOWNSCALE))),
		maxi(1, ceili(size.y / float(LIGHT_DOWNSCALE))))
	if _light_viewport.size != wanted:
		_light_viewport.size = wanted


## atmosphere.gd her karede çağırır. suppressed = yerel oyuncu evin içinde (ev içi her zaman aydınlık/havasız).
func apply(grade: Dictionary, suppressed: bool) -> void:
	if _material == null:
		return
	var identity: bool = AtmosphereMathRef.is_identity(grade)
	_active = not suppressed and not identity
	_rect.visible = _active
	_copy.visible = _active
	if not _active:
		_light_gain = 0.0
		_light_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_light_gain = float(grade["light_gain"])
	var a: Color = grade["ambient"]
	var l: Color = grade["lift"]
	_material.set_shader_parameter("ambient", Vector3(a.r, a.g, a.b))
	_material.set_shader_parameter("saturation", float(grade["saturation"]))
	_material.set_shader_parameter("lift", Vector3(l.r, l.g, l.b))
	_material.set_shader_parameter("light_gain", _light_gain)
	_material.set_shader_parameter("glow_gain", float(grade["glow_gain"]))


func is_active() -> bool:
	return _active


func _process(_delta: float) -> void:
	if not _active or _light_gain < MIN_LIGHT_GAIN:
		if _light_viewport:
			_light_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var vp: Viewport = get_viewport()
	var size: Vector2 = vp.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if Engine.get_process_frames() % LIGHT_MAP_EVERY != 0:
		_light_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_fit_light_map(size)
	_light_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_drawer.lights = _gather_lights(vp.get_canvas_transform(), Vector2(_light_viewport.size))
	_drawer.queue_redraw()


func _gather_lights(xf: Transform2D, map_size: Vector2) -> Array:
	var out: Array = []
	var inv: float = 1.0 / float(LIGHT_DOWNSCALE)
	var zoom: float = absf(xf.get_scale().x)
	var tree: SceneTree = get_tree()

	for group_name: String in PLAYER_GROUPS:
		for n: Node in tree.get_nodes_in_group(group_name):
			var body := n as Node2D
			if body == null or not body.is_visible_in_tree():
				continue
			if body.get("is_indoors") == true:
				continue
			if body.get("is_dead") == true and body.get("is_downed") != true:
				continue
			var wp: Vector2 = PhysicsInterpScript.visual_position(body) + PLAYER_LIGHT_OFFSET
			_push(out, (xf * wp) * inv, PLAYER_LIGHT_RADIUS * zoom * inv, PLAYER_LIGHT_COLOR * PLAYER_LIGHT_ENERGY, map_size)

	var fog: Node = tree.get_first_node_in_group("vision_fog")
	var fog_active: bool = fog != null and fog.has_method("is_active") and bool(fog.call("is_active"))
	for n: Node in tree.get_nodes_in_group(NightGlowScript.GROUP):
		var glow := n as Node2D
		if glow == null or glow.get_canvas_layer_node() != null:
			continue ## arayüzdeki (CanvasLayer altındaki) önizlemeler dünyaya ışık saçmaz
		var e: float = minf(float(glow.call("current_energy")) * GLOW_ENERGY_SCALE, GLOW_ENERGY_CAP)
		if e <= 0.01:
			continue
		if bool(glow.get("hide_in_fog")) and fog_active and not bool(fog.call("is_world_pos_visible", glow.global_position)):
			continue
		var col: Color = glow.call("current_color")
		col = Color(col.r * e, col.g * e, col.b * e, 1.0)
		var r_px: float = float(glow.get("radius")) * GLOW_RADIUS_SCALE * zoom * inv
		if bool(glow.call("is_segment_light")):
			var seg: Array = glow.call("current_segment")
			if seg.size() >= 2:
				_push_segment(out, (xf * Vector2(seg[0])) * inv, (xf * Vector2(seg[1])) * inv, r_px, col, map_size)
		else:
			_push(out, (xf * glow.global_position) * inv, r_px, col, map_size)
	return out


func _push(out: Array, center: Vector2, r: float, col: Color, map_size: Vector2) -> void:
	if r < 0.5:
		return
	if center.x < -r or center.y < -r or center.x > map_size.x + r or center.y > map_size.y + r:
		return
	col.a = 1.0
	out.append([center, r, col])


## Çizgi ışık: çizgi boyunca eşit aralıklı lekeler. Lekeler üst üste bindiği için her birinin gücü, çizginin ortası tek
## bir noktasal ışıkla aynı parlaklıkta kalacak şekilde ölçeklenir ((1-u^2)^2'nin integrali 16/15).
func _push_segment(out: Array, a: Vector2, b: Vector2, r: float, col: Color, map_size: Vector2) -> void:
	var length: float = a.distance_to(b)
	var spacing: float = maxf(r * SEGMENT_SPACING, 1.0)
	var dots: int = clampi(int(ceil(length / spacing)) + 1, 1, SEGMENT_MAX_DOTS)
	if dots == 1:
		_push(out, a, r, col, map_size)
		return
	var step: float = length / float(dots - 1)
	var k: float = clampf(step / (r * 16.0 / 15.0), 0.15, 1.0)
	var c := Color(col.r * k, col.g * k, col.b * k, 1.0)
	for i in range(dots):
		_push(out, a.lerp(b, float(i) / float(dots - 1)), r, c, map_size)
