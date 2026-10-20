extends Node2D
class_name CozyEvLight

## COZY EV İÇ IŞIĞI (madde 311, kullanıcı önizlemeyi seçti: "ışıklandırma olarak bunu seçiyorum, en doğalı bu oldu").
## Tek kaynak tools/proto_20261019/cozy_ev/gen_cozy_ev.py (IŞIK_KIPLERI, EMIT, light_map, _huzme); buradaki sayılar oradan.
##  - ORTAM: CanvasModulate (gece 0,42/0,37/0,48, gündüz 0,72/0,68/0,66), atmosferin EŞİTLENEN saatinden AtmosphereMath.darkness
##    ile aradaki geçiş. Bu düğüm iç mekanın çocuğu: iç mekan gizlenince (oyuncu dışarı çıkınca) CanvasModulate ve ışıklar kendiliğinden
##    kapanır, dış dünya hiç etkilenmez (dışarıda CanvasModulate / Light2D yok - gün-gece orada atmosphere_overlay shader'ı).
##  - KAYNAKLAR: PointLight2D + yumuşak (1-d)^2.2 hale dokusu (basamaksız; "ışıkların piksel piksel olmasını istemiyorum"), elips =
##    düğümün dikey ölçeği (basıklık). Yerler pişmiş sahnenin karolarından (babaanne_npc.gd _find_spots yöntemi: doku adı + bloğun
##    kesin dolu bir karosu): şömine + kazan ocağı (farklı evrede titrer), mumlar, duvar fenerleri, ayaklı lambalar. Gündüz şiddet x0,6.
##  - PENCERELER: gündüz kuzey pencerelerinden düz öne yumuşak YELPAZE + camın çevresinde küçük ılık aydınlık, alt duvardaki görünmeyen
##    pencerelerden yukarı geniş yelpaze (dokular tools/gen_cozy_ev_isik.py); gece yelpazeler kapalı, pencerelerde soğuk ay halesi.
##  - IŞIKSIZ EŞYALAR: ışık veren eşyaların karoları (ve gündüz pencere camı karesi) LIGHT_MODE_UNSHADED malzemeyle çizilir - önizlemedeki
##    "emissive" (unshaded öğeye ne CanvasModulate ne Light2D işler). İç mekanın TileSet'i ortak kaynak: malzeme karoya bir kez yazılır.
##  - Oyuncu başındaki isim / can çubuğu / sohbet balonu gece karartılmasın: içerideyken bunlara da aynı unshaded malzeme (dışarıda
##    ışık ve CanvasModulate olmadığından görünüşe etkisi yok).
## FPS A/B: EV_ISIK=0 ortam değişkeni ışığı hiç kurmaz (house_interior.gd; tools/fps_micro/proc_ab.ps1).

const AtmosphereMath := preload("res://scripts/atmosphere_math.gd")
const HALO_TEX: Texture2D = preload("res://assets/fx/cozy_ev_isik/hale.png")
const FAN_TEX: Texture2D = preload("res://assets/fx/cozy_ev_isik/pencere_yelpaze.png")
const BOTTOM_FAN_TEX: Texture2D = preload("res://assets/fx/cozy_ev_isik/alt_yelpaze.png")
const HALO_TEX_RADIUS := 256.0 ## hale.png 512 px: yarıçap R için düğüm ölçeği R / 256
const FAN_TEX_SCALE := 0.5 ## yelpaze dokuları 2 doku pikseli / dünya pikseli
const TILE := 16.0

## IŞIK_KIPLERI["gece" / "gunduz"]["ortam"] ve ["kaynak"]
const AMBIENT_NIGHT := Color(0.42, 0.37, 0.48)
const AMBIENT_DAY := Color(0.72, 0.68, 0.66)
const SOURCE_DAY_MULT := 0.6

## EMIT: eşya -> doku + bloğun kesin dolu karosu (atlas) + o karonun bloktaki yeri (rel) + ışıksız çizilecek blok karoları +
## blok sol üstüne göre ışık noktası (at), yarıçap, renk, şiddet, basıklık (dikey/yatay), titreme evresi (yoksa NAN).
const WARM := Color(1.0, 0.68, 0.38)
const SOURCES: Array[Dictionary] = [
	{"key": "somine", "tex": "Fireplace.png", "atlas": Vector2i(0, 0), "rel": Vector2i(0, 3), "block": Rect2i(0, 0, 1, 1),
		"at": Vector2(24.0, 48.0), "radius": 178.0, "color": Color(1.0, 0.64, 0.34), "energy": 1.3, "squash": 0.72, "phase": 0.0},
	{"key": "kazan_ocak", "tex": "Kazan_ocak.png", "atlas": Vector2i(0, 0), "rel": Vector2i(0, 0), "block": Rect2i(0, 0, 2, 3),
		"at": Vector2(16.0, 36.0), "radius": 140.0, "color": Color(1.0, 0.56, 0.28), "energy": 1.3, "squash": 0.78, "phase": 2.1},
	{"key": "mum", "tex": "Candles.png", "atlas": Vector2i(0, 0), "rel": Vector2i(0, 0), "block": Rect2i(0, 0, 2, 2),
		"at": Vector2(12.0, 14.0), "radius": 46.0, "color": WARM, "energy": 0.85, "squash": 0.85, "phase": NAN},
	{"key": "fener", "tex": "Interior_objects.png", "atlas": Vector2i(30, 6), "rel": Vector2i(0, 0), "block": Rect2i(30, 6, 2, 2),
		"at": Vector2(16.0, 13.0), "radius": 60.0, "color": WARM, "energy": 0.95, "squash": 0.85, "phase": NAN},
	{"key": "lamba", "tex": "Interior_objects.png", "atlas": Vector2i(5, 4), "rel": Vector2i(0, 0), "block": Rect2i(5, 4, 3, 3),
		"at": Vector2(22.0, 16.0), "radius": 74.0, "color": Color(1.0, 0.72, 0.42), "energy": 0.95, "squash": 0.85, "phase": NAN},
]

## Pencere (Pencere.png karo 0 gece / 1 gündüz, house_interior.gd _setup_windows). Noktalar pencere hücresinin sol üstüne göre.
const WINDOW_TEX := "Pencere.png"
const WINDOW_DAY_ATLAS := Vector2i(1, 0) ## gündüz camı kendi parlaklığında (önizlemede cam ışıksız)
const MOON := {"at": Vector2(8.0, 22.0), "radius": 34.0, "color": Color(0.55, 0.66, 0.95), "energy": 0.45, "squash": 1.6}
const WINDOW_GLOW := {"at": Vector2(8.0, 8.0), "radius": 20.0, "color": Color(1.0, 0.95, 0.85), "energy": 0.45, "squash": 1.0}
## huzme: pencerenin ortasından, hücre tepesinin 10 px altından (önizlemede bas 74 = satır 4) aşağı 100 px.
const FAN := {"x": 8.0, "start": 10.0, "length": 100.0, "color": Color(1.0, 0.94, 0.78), "energy": 0.6}
## alt_huzme: alt duvardaki görünmeyen pencereler (ALT_PENCERE), BOTTOM * 16 + 8'den yukarı 92 px.
const BOTTOM_WINDOW_X: Array[float] = [112.0, 296.0, 462.0, 552.0]
const BOTTOM_WINDOW_Y := 328.0
const BOTTOM_FAN := {"length": 92.0, "color": Color(1.0, 0.94, 0.78), "energy": 0.42}

## Godot 2D bir çizim öğesini (karo katmanında bir dörtgen) en fazla 16 ışıkla aydınlatır, fazlası sessizce düşer (dörtgen sınırında
## ışık kesilir). Varsayılan 16 karoluk (256 px) dörtgende alacakaranlıkta (gündüz + gece pencere ışıkları birlikte açık) 18 ışık
## düşüyordu -> iç mekan katmanları 8 karoluk dörtgen (en kötü 12; tests/test_cozy_ev_isik.gd bütçeyi denetler).
const LIGHT_QUADRANT := 8
const MAX_LIGHTS_PER_ITEM := 15

const OVERLAY_GROUPS: Array[StringName] = [&"player", &"remote_players", &"npc_actors"]
const OVERLAY_NAMES: Array[String] = ["NameLabel", "OverheadBar", "DownedTimerLabel"]
const OVERLAY_CHECK := 0.5

static var _unlit: CanvasItemMaterial = null

var ambient: CanvasModulate = null
var darkness: float = 0.0 ## son uygulanan (test)
var clock_override: float = -1.0 ## test / yakalama: >= 0 iken atmosfer yerine bu gün saati
var _sources: Array[Dictionary] = [] ## {"light", "energy", "phase", "key"}
var _day: Array[Dictionary] = [] ## gündüz pencere ışıkları {"light", "energy"}
var _night: Array[Dictionary] = [] ## gece ay haleleri
var _t: float = 0.0
var _overlay_check: float = 0.0


static func unlit_material() -> CanvasItemMaterial:
	if _unlit == null:
		_unlit = CanvasItemMaterial.new()
		_unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unlit


## house_interior.gd çağırır (bu düğüm interior'un çocuğu olarak eklendikten sonra).
func setup(interior: Node2D) -> void:
	name = "EvIciIsik"
	ambient = CanvasModulate.new()
	ambient.name = "EvIciOrtam"
	add_child(ambient)
	for child: Node in interior.get_children():
		if child is TileMapLayer:
			(child as TileMapLayer).rendering_quadrant_size = LIGHT_QUADRANT
	_mark_emissive(interior)
	_place_lights(interior)
	_apply(_current_darkness())


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_apply(_current_darkness())
	_overlay_check -= delta
	if _overlay_check <= 0.0:
		_overlay_check = OVERLAY_CHECK
		_keep_overlays_unlit()


func _current_darkness() -> float:
	if clock_override >= 0.0:
		return AtmosphereMath.darkness(clock_override)
	var atmo: Node = get_tree().get_first_node_in_group("atmosphere") if is_inside_tree() else null
	if atmo != null and "cycle_time" in atmo:
		return AtmosphereMath.darkness(float(atmo.get("cycle_time")))
	return 0.0


## Gün-gece karışımı: ortam rengi, kaynak şiddeti (gündüz x0,6), pencere yelpazeleri (gündüz) / ay haleleri (gece), ateş titremesi.
func _apply(dark: float) -> void:
	darkness = dark
	ambient.color = AMBIENT_DAY.lerp(AMBIENT_NIGHT, dark)
	var mult: float = lerpf(SOURCE_DAY_MULT, 1.0, dark)
	var ms: float = _t * 1000.0
	for s: Dictionary in _sources:
		var l: PointLight2D = s["light"]
		var e: float = float(s["energy"]) * mult
		var ph: float = s["phase"]
		if not is_nan(ph): ## ateş: yavaş + hızlı iki dalga, yarıçap ve şiddet birlikte (light_map)
			var f: float = 0.06 * sin(ms / 260.0 + ph) + 0.04 * sin(ms / 97.0 + 1.3 + ph * 1.7)
			l.texture_scale = 1.0 + f
			e *= 1.0 + 1.4 * f
		l.energy = e
	for w: Dictionary in _day:
		_set_level(w, 1.0 - dark)
	for w: Dictionary in _night:
		_set_level(w, dark)


static func _set_level(w: Dictionary, k: float) -> void:
	var l: PointLight2D = w["light"]
	l.energy = float(w["energy"]) * k
	l.enabled = k > 0.001


## Işık veren eşyaların karolarına (ve gündüz camına) unshaded malzeme: TileSet'teki atlas kaynağı doku adından bulunur.
func _mark_emissive(interior: Node2D) -> void:
	var sets: Dictionary = {}
	for child: Node in interior.get_children():
		var layer := child as TileMapLayer
		if layer != null and layer.tile_set != null:
			sets[layer.tile_set] = true
	for ts: TileSet in sets:
		for i in ts.get_source_count():
			var src := ts.get_source(ts.get_source_id(i)) as TileSetAtlasSource
			if src == null or src.texture == null:
				continue
			var tex_name: String = src.texture.resource_path.get_file()
			if tex_name == WINDOW_TEX:
				if not src.has_tile(WINDOW_DAY_ATLAS):
					src.create_tile(WINDOW_DAY_ATLAS)
				_set_tile_unlit(src, WINDOW_DAY_ATLAS)
				continue
			for s: Dictionary in SOURCES:
				if s["tex"] != tex_name:
					continue
				var block: Rect2i = s["block"]
				for y in range(block.position.y, block.end.y):
					for x in range(block.position.x, block.end.x):
						if src.has_tile(Vector2i(x, y)):
							_set_tile_unlit(src, Vector2i(x, y))


static func _set_tile_unlit(src: TileSetAtlasSource, coords: Vector2i) -> void:
	for k in src.get_alternative_tiles_count(coords):
		var td: TileData = src.get_tile_data(coords, src.get_alternative_tile_id(coords, k))
		if td != null:
			td.material = unlit_material()


func _place_lights(interior: Node2D) -> void:
	_sources.clear()
	_day.clear()
	_night.clear()
	for child: Node in interior.get_children():
		var layer := child as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		for c: Vector2i in layer.get_used_cells():
			var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
			if src == null or src.texture == null:
				continue
			var tex_name: String = src.texture.resource_path.get_file()
			var cell_pos: Vector2 = layer.position + Vector2(c) * TILE
			if tex_name == WINDOW_TEX:
				_add_window(cell_pos)
				continue
			var atlas: Vector2i = layer.get_cell_atlas_coords(c)
			if layer.get_cell_alternative_tile(c) != 0:
				continue
			for s: Dictionary in SOURCES:
				if tex_name == s["tex"] and atlas == s["atlas"]:
					var origin: Vector2 = cell_pos - Vector2(s["rel"] as Vector2i) * TILE
					var l := _halo(origin + (s["at"] as Vector2), s["radius"], s["squash"], s["color"])
					l.name = "Isik_%s_%d" % [s["key"], _sources.size()]
					_sources.append({"light": l, "energy": s["energy"], "phase": s["phase"], "key": s["key"]})
	for x: float in BOTTOM_WINDOW_X:
		var l := _fan(BOTTOM_FAN_TEX, Vector2(x, BOTTOM_WINDOW_Y - float(BOTTOM_FAN["length"]) * 0.5), BOTTOM_FAN["color"])
		l.name = "AltPencere_%d" % _day.size()
		_day.append({"light": l, "energy": BOTTOM_FAN["energy"]})


func _add_window(cell_pos: Vector2) -> void:
	var fan := _fan(FAN_TEX, cell_pos + Vector2(FAN["x"], float(FAN["start"]) + float(FAN["length"]) * 0.5), FAN["color"])
	fan.name = "PencereYelpaze_%d" % _day.size()
	_day.append({"light": fan, "energy": FAN["energy"]})
	var glow := _halo(cell_pos + (WINDOW_GLOW["at"] as Vector2), WINDOW_GLOW["radius"], WINDOW_GLOW["squash"], WINDOW_GLOW["color"])
	glow.name = "PencereParilti_%d" % _day.size()
	_day.append({"light": glow, "energy": WINDOW_GLOW["energy"]})
	var moon := _halo(cell_pos + (MOON["at"] as Vector2), MOON["radius"], MOON["squash"], MOON["color"])
	moon.name = "AyIsigi_%d" % _night.size()
	_night.append({"light": moon, "energy": MOON["energy"]})


func _halo(pos: Vector2, radius: float, squash: float, color: Color) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = HALO_TEX
	l.position = pos
	l.scale = Vector2(radius, radius * squash) / HALO_TEX_RADIUS
	l.color = color
	add_child(l)
	return l


func _fan(tex: Texture2D, center: Vector2, color: Color) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = tex
	l.texture_scale = FAN_TEX_SCALE
	l.position = center
	l.color = color
	add_child(l)
	return l


## İçerideki oyuncu / kukla / NPC başındaki yazı ve çubuklar ışıksız (okunur kalsın).
func _keep_overlays_unlit() -> void:
	for g: StringName in OVERLAY_GROUPS:
		for n: Node in get_tree().get_nodes_in_group(g):
			for c: Node in n.get_children():
				var ci := c as CanvasItem
				if ci == null or ci.has_meta(&"cozy_unlit"):
					continue
				var sc: Script = ci.get_script() as Script
				if not (OVERLAY_NAMES.has(String(ci.name)) or (sc != null and sc.resource_path.ends_with("chat_bubble.gd"))):
					continue
				ci.set_meta(&"cozy_unlit", true)
				if ci.material == null:
					ci.material = unlit_material()
				_inherit_material(ci)


static func _inherit_material(n: Node) -> void:
	for c: Node in n.get_children():
		var ci := c as CanvasItem
		if ci != null and ci.material == null:
			ci.use_parent_material = true
		_inherit_material(c)


func light_count() -> int:
	return _sources.size()


func source_lights() -> Array[Dictionary]:
	return _sources


func window_day_lights() -> Array[Dictionary]:
	return _day


func window_night_lights() -> Array[Dictionary]:
	return _night
