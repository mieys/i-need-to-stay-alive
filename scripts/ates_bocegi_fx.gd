extends CanvasLayer

## ANA HARİTA GECE ATEŞ BÖCEKLERİ (madde 761, kullanıcı 2026-11-16: "ana haritanın gece vaktinde etrafta bazı yerlerde ana menüdeki sahnede
## olduğu gibi ateş böceği parıltıları olsun, gece hiç ışık kaynağı olmuyor nerdeyse"). main.gd kurar (MapProfiles "ates_bocekleri" bayrağı).
##  - GÖRÜNÜM ana menünün Fireflies'ı (menu_camp_scene.gd): açık öz + üç DÜZ alfa bandı sarı-yeşil hale (benek / titreşim yok), toplamalı
##    karışım, yavaşça süzülür ve yavaşça yanıp söner. 1 hale hücresi = 1 dünya pikseli (harita karolarıyla aynı ızgara, kamera 2x'te 2 ekran px).
##  - KATMAN: dünya -> gün/gece renk geçişi (AtmosphereOverlay) -> BU KATMAN -> görüş sisi -> HUD (main.gd sıralar, aynı layer=1, ağaç sırası).
##    Böcekler karartmanın ÜSTÜNDE çizilir (menüdeki gibi kendi ışıkları, karanlıkta parlar); sis onları da örter. follow_viewport: katman
##    kameraya bağlı, çizim dünya koordinatında.
##  - ZEMİN IŞIĞI: yanan her böcek altına küçük, böcekle birlikte gezen soluk bir ışık düşürür - atmosphere_overlay.gd LIGHT_PROVIDER_GROUP'taki
##    düğümlerin get_night_lights()'ını ışık haritasına ekler (böcek başına düğüm yok).
##  - Alanlar scripts/ana_harita_bocek_meta.gd (tools/ates_bocegi/gen_ana_bocek.py üretir: nehir / gölet kıyısı + orman açıklığı).
##  - Tamamen kozmetik + yerel: ağ yok (gün saati zaten eşitli), durum yok (konum = zamanın fonksiyonu), yalnız görüntüdeki alanlar,
##    30 kare/sn yeniden çizim; gündüz katman gizli. Yağmurda azalır, sağanakta saklanırlar.

const MetaScript := preload("res://scripts/ana_harita_bocek_meta.gd")
const AtmosphereMathScript := preload("res://scripts/atmosphere_math.gd")

const LIGHT_PROVIDER_GROUP := &"night_light_provider" ## atmosphere_overlay.gd ile AYNI
const GLOW_N := 15 ## hale dokusu hücre sayısı (merkez 7) - menu_camp_scene.gd Fireflies ile aynı
const GLOW_C := 7
const BUGS_MIN := 6
const BUGS_MAX := 8
const DARK_MIN := 0.25 ## bu karanlığın altında (gündüz / ikindi) hiç görünmez
const DARK_SPAN := 0.4 ## DARK_MIN + bu karanlıkta tam görünür
const FADE_SPEED := 0.5 ## görünürlük değişimi / sn (alacakaranlıkta yavaşça çıkar)
const REDRAW_INTERVAL := 1.0 / 30.0
const RAIN_MULT := 0.45 ## yağmurda daha az / soluk
## Zemin ışığı (night_glow profili gibi: yarıçap dünya birimi, güç 0..1 -> overlay GLOW_* ölçekleri uygular)
const LIGHT_COLOR := Color(0.84, 1.0, 0.4)
const LIGHT_RADIUS := 46.0
const LIGHT_ENERGY := 0.75
const LIGHT_MIN_B := 0.2 ## bu parlaklığın altındaki böcek ışık vermez (ışık haritasına boşuna leke düşmesin)

var _zones: Array = [] ## [Rect2 dünya sınırı, Array böcekler]
var _drawer: Node2D = null
var _glow: ImageTexture = null
var _atmosphere: Node = null
var _alpha: float = 0.0
var _t: float = 0.0
var _redraw_acc: float = 0.0
var _visible_zones: PackedInt32Array = PackedInt32Array()


## harita: alan koordinatları bu düğümün yerel koordinatında (main.tscn'de Harita (-2, 21)'de).
func setup(harita: Node) -> void:
	var xf: Transform2D = (harita as Node2D).global_transform if harita is Node2D else Transform2D.IDENTITY
	_zones = build_zones(MetaScript.FIREFLY_ZONES, xf)


## Alan listesinden böcek verisi (sabit tohum: her açılışta aynı yerleşim). Test de çağırır.
static func build_zones(src: Array, xf: Transform2D) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 760
	for z: Array in src:
		var c: Vector2 = xf * Vector2(z[0])
		var r: float = float(z[1])
		var bugs: Array = []
		for i in range(rng.randi_range(BUGS_MIN, BUGS_MAX)):
			var a: float = rng.randf_range(0.0, TAU)
			var d: float = sqrt(rng.randf()) * r * 0.75
			bugs.append({
				"pos": c + Vector2(cos(a), sin(a) * 0.7) * d,
				"ax": rng.randf_range(6.0, 16.0), "ay": rng.randf_range(4.0, 11.0),
				"sx": rng.randf_range(0.04, 0.09), "sy": rng.randf_range(0.05, 0.11), "ph": rng.randf_range(0.0, TAU),
				"per": rng.randf_range(2.8, 5.4), "off": rng.randf_range(0.0, 5.4),
			})
		var bound := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0).grow(24.0)
		out.append([bound, bugs])
	return out


func _ready() -> void:
	layer = 1
	follow_viewport_enabled = true
	visible = false
	add_to_group(LIGHT_PROVIDER_GROUP)
	_glow = make_glow()
	_drawer = Node2D.new()
	_drawer.name = "Bocekler"
	_drawer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_drawer.material = m
	_drawer.draw.connect(_draw_bugs)
	add_child(_drawer)


## Menüdeki hale ile birebir: üç düz alfa bandı (r 1,5 / 3,5 / 6) + açık öz.
static func make_glow() -> ImageTexture:
	var img := Image.create(GLOW_N, GLOW_N, false, Image.FORMAT_RGBA8)
	var c := Vector2(GLOW_C, GLOW_C)
	for y in range(GLOW_N):
		for x in range(GLOW_N):
			var d: float = Vector2(x, y).distance_to(c)
			var a: float = 0.0
			if d <= 1.5:
				a = 0.45
			elif d <= 3.5:
				a = 0.2
			elif d <= 6.0:
				a = 0.08
			img.set_pixel(x, y, Color(0.84, 1.0, 0.40, a))
	img.set_pixel(GLOW_C, GLOW_C, Color(1.0, 1.0, 0.82, 1.0))
	return ImageTexture.create_from_image(img)


## Böceğin t anındaki parlaklığı (0..1; menüdeki zarf: yavaş yanar, kısa tepe, yavaş söner) ve konumu (dünya pikseline oturtulmuş).
static func bug_brightness(f: Dictionary, t: float) -> float:
	var per: float = f["per"]
	var s: float = fmod(t + float(f["off"]), per) / per
	return smoothstep(0.0, 0.25, s) * (1.0 - smoothstep(0.5, 0.8, s))


static func bug_position(f: Dictionary, t: float) -> Vector2:
	var ph: float = f["ph"]
	var p: Vector2 = f["pos"] + Vector2(sin(t * float(f["sx"]) * TAU + ph) * float(f["ax"]),
		sin(t * float(f["sy"]) * TAU + ph * 1.7) * float(f["ay"]))
	return p.floor()


func _process(delta: float) -> void:
	_t += delta
	_alpha = move_toward(_alpha, _target_alpha(), delta * FADE_SPEED)
	var on: bool = _alpha > 0.01
	if visible != on:
		visible = on
		if not on:
			_visible_zones = PackedInt32Array()
	if not on:
		return
	_redraw_acc += delta
	if _redraw_acc < REDRAW_INTERVAL:
		return
	_redraw_acc = 0.0
	var view: Rect2 = _view_rect()
	var vis := PackedInt32Array()
	for i in range(_zones.size()):
		if view.intersects(_zones[i][0]):
			vis.append(i)
	if vis.is_empty() and _visible_zones.is_empty():
		return
	_visible_zones = vis
	_drawer.queue_redraw()


func _target_alpha() -> float:
	if _atmosphere == null or not is_instance_valid(_atmosphere):
		var scene: Node = get_tree().current_scene
		_atmosphere = scene.get_node_or_null("Atmosphere") if scene != null else null
		if _atmosphere == null:
			return 0.0
	var dark: float = float(_atmosphere.call("get_darkness"))
	var k: float = clampf((dark - DARK_MIN) / DARK_SPAN, 0.0, 1.0)
	var w: int = int(_atmosphere.get("weather"))
	if w == AtmosphereMathScript.Weather.STORM:
		return 0.0
	if w == AtmosphereMathScript.Weather.RAINY:
		k *= RAIN_MULT
	return k


func _view_rect() -> Rect2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Rect2()
	var inv: Transform2D = vp.get_canvas_transform().affine_inverse()
	var size: Vector2 = vp.get_visible_rect().size
	return Rect2(inv * Vector2.ZERO, Vector2.ZERO).expand(inv * size).grow(16.0)


func _draw_bugs() -> void:
	if _alpha <= 0.01:
		return
	var gs := Vector2(GLOW_N, GLOW_N)
	var half := Vector2(GLOW_C, GLOW_C)
	for zi in _visible_zones:
		for f: Dictionary in _zones[zi][1]:
			var b: float = bug_brightness(f, _t)
			if b <= 0.02:
				continue
			_drawer.draw_texture_rect(_glow, Rect2(bug_position(f, _t) - half, gs), false, Color(1, 1, 1, b * 0.9 * _alpha))


## atmosphere_overlay.gd çağırır (yalnız gece ışık haritası güncellenirken): [dünya konumu, yarıçap (dünya), renk, güç 0..1].
func get_night_lights() -> Array:
	var out: Array = []
	if not visible or _alpha <= 0.01:
		return out
	for zi in _visible_zones:
		for f: Dictionary in _zones[zi][1]:
			var b: float = bug_brightness(f, _t)
			if b < LIGHT_MIN_B:
				continue
			out.append([bug_position(f, _t) + Vector2(0.5, 0.5), LIGHT_RADIUS, LIGHT_COLOR, LIGHT_ENERGY * b * _alpha])
	return out
