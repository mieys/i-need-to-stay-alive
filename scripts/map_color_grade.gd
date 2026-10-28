extends RefCounted

## HARİTA GÖRÜNÜMÜ - oyun açılışında harita_baked.tscn'e DOKUNMADAN uygulanan ayarlar (açık editör sahneyi yeniden kaydedebilir, bkz.
## CLAUDE.md). main.gd harita kurulumunun EN SONUNDA (ön katman kopyaları + zemin geçişi kurulduktan sonra) `attach` çağırır.
##
## 1) RENK AYARI "A - Derin Çayır" (madde 181). Formül shaders/harita_renk.gdshaderinc'te; haritanın kendi shader'ları (zemin, çimen, su,
##    ot, ağaç, saklanma çalılığı, ön katman kopyaları) onu fragment() sonunda çağırır. Burada kalan boşluklar kapanır:
##    - Kendi shader'ı olmayan TileMapLayer'lar (orman, ev, köprü, maden, dış orman...) ortak harita_renk_duz materyalini alır.
##    - "Orman parçaları 2"nin sahneye GÖMÜLÜ eski shader'ı (Shader_apus4), aynı kodun harita_renk() eklenmiş dosya sürümüyle
##      (scenes/orman_parcalari_doku.gdshader) değişir; parametreler materyalde kalır.
##    Zemin ayrıntısı kapalıyken ground_texel_pass.gd zemin katmanlarına null yerine plain_material() verir.
## 2) SAKİN DOKU (madde 184, görsel karmaşa 1-2): bitki başına renk kayması ve zemin benekleri azaltılır (CALM_PARAMS).
## 3) BAŞIBOŞ DÜZ ÇİMEN KAROLARI (madde 184, görsel karmaşa 3): bkz. _hide_stray_grass.
## 4) PLATO TEPELERİ (madde 186): "Orman parçaları 2"nin çimen pikselleri zeminle AYNI lekeli desende (orman_parcalari_doku.gdshader +
##    shaders/cimen_desen.gdshaderinc); desen değerleri zemin materyalinden kopyalanır (_copy_grass_params) -> zeminle dikişsiz.
## 5) KÖPRÜ ALTINDAKİ BİTKİLER (madde 189, kullanıcı: "köprünün üstünde bitki görünüyor"): bkz. _hide_plants_under_bridges.

const PLAIN_SHADER_PATH := "res://shaders/harita_renk_duz.gdshader"
const FOREST_SHADER_PATH := "res://scenes/orman_parcalari_doku.gdshader"
## Gömülü eski orman shader'ını tanımak için kodunda geçen bir uniform adı.
const FOREST_SHADER_MARK := "dark_grass_color"
const GROUND_GRASS_SHADER_PATH := "res://scenes/çimen yaprak.gdshader"
## Zeminden plato materyaline kopyalanan çimen deseni uniform önekleri (shaders/cimen_desen.gdshaderinc).
const GRASS_PARAM_PREFIXES: Array[String] = ["cim_", "yaprak_", "cicek_", "kume_", "yonca_"]

## Shader yolu -> {parametre: değer}; harita_baked.tscn'deki materyal değerlerini OYUNDA ezer (sahnedeki eski değer parantezde).
## "Göz yoran" ince desen: çimen kümelerinde her bitki ayrı renge kayıyordu (~33°), çayırda çiçek/yonca/yaprak kümesi, toprakta çakıl sıktı.
## Çimen deseni (zemin + plato tepeleri aynı değerler).
const GRASS_CALM := {"cicek_yogunlugu": 0.08, "yonca_yogunlugu": 0.1, "kume_seyrek": 0.06, "kume_sik": 0.3} ## (0,16 / 0,2 / 0,1 / 0,45)
const CALM_PARAMS := {
	"res://scenes/mini çim renk.gdshader": {"hue_shift_amount": 0.03, "sat_shift_amount": 0.05}, ## (0,092 / 0,12)
	"res://scenes/sallanan ot.gdshader": {"hue_shift_amount": 0.03, "sat_shift_amount": 0.06}, ## çalı + çiçek (0,064 / 0,15)
	"res://scenes/çimen yaprak.gdshader": GRASS_CALM,
	"res://scenes/orman_parcalari_doku.gdshader": GRASS_CALM,
	"res://scenes/toprak kir.gdshader": {
		"ince_cakil_seyrek": 0.025, "ince_cakil_sik": 0.16, "iri_cakil_yogunlugu": 0.06, ## (0,05 / 0,32 / 0,12)
	},
}

## BAŞIBOŞ ÇİMEN: zemin katmanı ve atlanan katmanlar (zemin katmanları + plato tepeleri). "Orman parçaları 2"deki ~2.880 düz çimen karosunun
## HEPSİ uçuruma bağlı plato tepesi - GİZLENMEZ (altında toprak/kenar olan ~200 karo ve kenar karoları da var); zemin desenini o katmanın
## kendi shader'ı çizer (madde 186, orman_parcalari_doku.gdshader).
const GROUND_LAYER := "Yer/Zemin Çimen"
const STRAY_SKIP_LAYERS: Array[String] = ["Yer/Zemin Toprak", "Yer/Çimen gölge", "Yer/Zemin Çimen", "Yer/Derin orman zemini", "Orman parçaları/Orman parçaları 2"]
## Düz çimen karosu ADAYLARI (kaynak, atlas x, atlas y) - 2026-10-16 harita_baked.tscn analizinden. Kullanılmadan önce PİKSELLERİ doğrulanır
## (_is_flat_grass): yeniden bake'te kaynak numaraları kayarsa yanlış karo gizlenmez, sadece o karo atlanır (dikdörtgen geri gelir).
const FLAT_GRASS_CANDIDATES: Array[Vector3i] = [Vector3i(0, 1, 7), Vector3i(2, 1, 6), Vector3i(0, 1, 1), Vector3i(16, 1, 5)]
## Düz çimen: piksellerin en az bu oranı opak ve cim_taban'a GRASS_TOL kadar yakın (çimen yaprak.gdshader maskesiyle aynı ölçek).
const GRASS_TOL := 0.047
const GRASS_MIN_RATIO := 0.95
## Zemin materyali bulunamazsa (ayrıntı kapalı) çimen yaprak.gdshader cim_taban varsayılanı.
const DEFAULT_GRASS := Color(0.478, 0.678, 0.333)
## KÖPRÜ: güverte katmanları ve köprüden SONRA çizilen bitki katmanları (+ "<ad> ön" kopyaları: grass_sway.gd / depth_occluders.gd).
const BRIDGE_DECK_LAYERS: Array[String] = ["Köprü/Köprü alt", "Köprü/Köprü üst"]
const BRIDGE_PLANT_LAYERS: Array[String] = [
	"Shader Eklenecek/Çalılar", "Shader Eklenecek/Çalılar1", "Shader Eklenecek/Çiçekler 1", "Shader Eklenecek/Animasyonsuz çalılar",
]
## Gizlenen karonun alternatifi bu z'de (katmana göre) çizilir: opak zemin çiminin ALTINDA kalır.
const STRAY_UNDER_Z := -50

static var _plain: ShaderMaterial = null
static var _outer_forest: ShaderMaterial = null
## Dış çerçeve ormanı katmanları (Dış orman 1-4): outer_forest_material (Batı'da kızıl yaprak, madde 362). Derin orman bölge ZEMİNİ shader'da
## değil, Harita.tmx'te gerçek karolar (madde 363: "Yer/Derin orman zemini" + yerinde değişen kıyı/plato/uçurum karoları).
const OUTER_FOREST_PREFIX := "Dış orman"


static func plain_material() -> ShaderMaterial:
	if _plain == null:
		_plain = ShaderMaterial.new()
		_plain.shader = load(PLAIN_SHADER_PATH)
	return _plain


## Dış çerçeve ormanının düz materyali: renk ayarı + Batı'da kızıl yaprak (harita_renk_duz.gdshader do_dis_orman).
static func outer_forest_material() -> ShaderMaterial:
	if _outer_forest == null:
		_outer_forest = ShaderMaterial.new()
		_outer_forest.shader = load(PLAIN_SHADER_PATH)
		_outer_forest.set_shader_parameter("do_dis_orman", 1.0)
	return _outer_forest


## Materyalin shader'ı CALM_PARAMS'ta varsa değerleri yazar (birden çok kez çağrılabilir). ground_texel_pass.gd ayrıntı materyallerini
## toplarken de çağırır (ayrıntı kapalıyken açılış yapılırsa o materyaller katmanda değildir).
static func apply_calm(mat: Material) -> void:
	var sm := mat as ShaderMaterial
	if sm == null or sm.shader == null:
		return
	var params: Dictionary = CALM_PARAMS.get(sm.shader.resource_path, {})
	for k: String in params:
		sm.set_shader_parameter(k, params[k])


## Döner: zeminin altına alınan hücre sayısı (başıboş çimen + köprü altı bitki; test/yakalama için). calm / hide_strays (başıboş çimen + köprü altı bitki) = false sadece önce-sonra karşılaştırması
## içindir (tools/proto_20261016/harita_renk/harita_renk_capture.gd HR_TAG=once); oyun varsayılanları kullanır.
static func attach(harita: Node, calm: bool = true, hide_strays: bool = true) -> int:
	var forest_shader: Shader = null
	var ground_grass: ShaderMaterial = null
	var ground := harita.get_node_or_null(GROUND_LAYER) as TileMapLayer
	var gm: ShaderMaterial = ground.material as ShaderMaterial if ground else null
	if gm and gm.shader and gm.shader.resource_path == GROUND_GRASS_SHADER_PATH:
		ground_grass = gm
	for n: Node in harita.find_children("*", "TileMapLayer", true, false):
		var layer := n as TileMapLayer
		var sm := layer.material as ShaderMaterial
		if layer.material == null or (sm != null and sm.shader == null):
			if String(layer.name).begins_with(OUTER_FOREST_PREFIX):
				layer.material = outer_forest_material()
			else:
				layer.material = plain_material()
			layer.use_parent_material = false
		elif sm != null and sm.shader.resource_path != FOREST_SHADER_PATH and sm.shader.code.contains(FOREST_SHADER_MARK):
			if forest_shader == null:
				forest_shader = load(FOREST_SHADER_PATH)
			sm.shader = forest_shader
		if sm != null and sm.shader != null and sm.shader.resource_path == FOREST_SHADER_PATH:
			_copy_grass_params(ground_grass, sm)
		if calm:
			apply_calm(layer.material)
	if not hide_strays:
		return 0
	return _hide_plants_under_bridges(harita) + _hide_stray_grass(harita)


## Batı halat köprüsünün altındaki çayıra Tiled'da konmuş bitkiler (Çalılar (58,121) ve iki karoluk (60,119)+(60,120)) "Shader Eklenecek"
## köprüden SONRA çizildiği için güvertenin/korkuluğun ÜSTÜNDE görünüyordu (eski harita sorunu). Güverte hücresine düşen bitki karosu ve
## atlasta ona bitişik olan aynı çok karolu çizimin parçaları (üst yarısı havada kalmasın; yandaki AYRI bitkiler atlas komşusu değil,
## dokunulmaz) başıboş çimen gibi zeminin altına alınır - ön kopyalarında da (köprüdeki oyuncunun üstüne çizilmesin). Döner: gizlenen hücre.
static func _hide_plants_under_bridges(harita: Node) -> int:
	var deck := {}
	for p: String in BRIDGE_DECK_LAYERS:
		var l := harita.get_node_or_null(p) as TileMapLayer
		if l:
			for c: Vector2i in l.get_used_cells():
				deck[c] = true
	if deck.is_empty():
		return 0
	var hidden := 0
	for p: String in BRIDGE_PLANT_LAYERS:
		var layer := harita.get_node_or_null(p) as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		var cells := {}
		for c: Vector2i in layer.get_used_cells():
			if deck.has(c):
				_collect_sprite(layer, c, cells)
		if cells.is_empty():
			continue
		var targets: Array[Node] = [layer]
		targets.append_array(harita.find_children(String(layer.name) + " ön", "TileMapLayer", true, false))
		for t: Node in targets:
			var tl := t as TileMapLayer
			for c: Vector2i in cells:
				var sid: int = tl.get_cell_source_id(c)
				if sid == -1:
					continue
				var co: Vector2i = tl.get_cell_atlas_coords(c)
				tl.set_cell(c, sid, co, _under_alternative(tl.tile_set, sid, co))
		hidden += cells.size()
	return hidden


## start hücresindeki çizimin atlasta bitişik parçaları (komşu hücrenin karosu = aynı kaynak + atlas koordinatı aynı yönde 1 kayık).
static func _collect_sprite(layer: TileMapLayer, start: Vector2i, out: Dictionary) -> void:
	var stack: Array[Vector2i] = [start]
	out[start] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		var sid: int = layer.get_cell_source_id(c)
		var a: Vector2i = layer.get_cell_atlas_coords(c)
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if out.has(n) or layer.get_cell_source_id(n) != sid or layer.get_cell_atlas_coords(n) != a + d:
				continue
			out[n] = true
			stack.append(n)


## Tiled'da üst katmanlara (Su ~139, Çimler ~87, Su ayrıntılar 3 ~24, Dış orman 1 ~10 ...) DÜZ çimen karosu boyanmış: kendi shader'larıyla
## (su tonu + dalga / bitki başına renk kayması) ya da desensiz çizilip zemindeki lekeli çimeni karo şeklinde DİKDÖRTGENLERLE bölüyordu.
## Altında da düz çimen zemini olan bu hücreler, aynı karonun z'si STRAY_UNDER_Z olan bir ALTERNATİFİNE çevrilir: zeminin altında çizilir
## (görünmez, yerinde lekeli zemin görünür). Hücre/kaynak/atlas/çevirme AYNI kalır -> su/orman çarpışması (piksel tabanlı), su sorguları,
## nehir sesi değişmez. Zeminle AYNI materyali paylaşan katman (Su ayrıntılar 2) zaten dikişsiz, atlanır. Döner: gizlenen hücre sayısı.
static func _hide_stray_grass(harita: Node) -> int:
	var ground := harita.get_node_or_null(GROUND_LAYER) as TileMapLayer
	if ground == null or ground.tile_set == null:
		return 0
	var base: Color = DEFAULT_GRASS
	var gm := ground.material as ShaderMaterial
	if gm != null and gm.get_shader_parameter("cim_taban") is Color:
		base = gm.get_shader_parameter("cim_taban")
	var images := {}
	var flat: Array[Vector3i] = []
	for c: Vector3i in FLAT_GRASS_CANDIDATES:
		if _is_flat_grass(ground.tile_set, c, base, images):
			flat.append(c)
	var skip: Array[Node] = []
	for p: String in STRAY_SKIP_LAYERS:
		var s: Node = harita.get_node_or_null(p)
		if s:
			skip.append(s)
	var hidden := 0
	for n: Node in harita.find_children("*", "TileMapLayer", true, false):
		var layer := n as TileMapLayer
		if skip.has(layer) or layer.tile_set == null or (layer.material != null and layer.material == ground.material):
			continue
		for c: Vector3i in flat:
			var coords := Vector2i(c.y, c.z)
			for cell: Vector2i in layer.get_used_cells_by_id(c.x, coords):
				var gcell: Vector2i = ground.local_to_map(ground.to_local(layer.to_global(layer.map_to_local(cell))))
				if not flat.has(Vector3i(ground.get_cell_source_id(gcell), ground.get_cell_atlas_coords(gcell).x, ground.get_cell_atlas_coords(gcell).y)):
					continue
				if layer.tile_set != ground.tile_set and not _is_flat_grass(layer.tile_set, c, base, images):
					continue
				layer.set_cell(cell, c.x, coords, _under_alternative(layer.tile_set, c.x, coords))
				hidden += 1
	return hidden


## Zemindeki çimen deseninin değerlerini plato materyaline yazar (zemin materyali yoksa - ayrıntı kapalı açılış - shader varsayılanları
## kalır; sahnedeki zemin değerleri 2026-10-16 itibarıyla varsayılanlarla aynı).
static func _copy_grass_params(src: ShaderMaterial, dst: ShaderMaterial) -> void:
	if src == null or src.shader == null:
		return
	for u: Dictionary in src.shader.get_shader_uniform_list():
		var n: String = u["name"]
		for pre: String in GRASS_PARAM_PREFIXES:
			if n.begins_with(pre):
				var v: Variant = src.get_shader_parameter(n)
				if v != null:
					dst.set_shader_parameter(n, v)
				break


static func _is_flat_grass(ts: TileSet, c: Vector3i, base: Color, images: Dictionary) -> bool:
	if not ts.has_source(c.x):
		return false
	var src := ts.get_source(c.x) as TileSetAtlasSource
	var coords := Vector2i(c.y, c.z)
	if src == null or src.texture == null or not src.has_tile(coords):
		return false
	var img: Image = images.get(src.texture)
	if img == null:
		img = src.texture.get_image()
		if img == null:
			return false
		if img.is_compressed():
			img.decompress()
		images[src.texture] = img
	var r: Rect2i = src.get_tile_texture_region(coords)
	var ok := 0
	for y in r.size.y:
		for x in r.size.x:
			var p: Color = img.get_pixel(r.position.x + x, r.position.y + y)
			if p.a > 0.5 and Vector3(p.r - base.r, p.g - base.g, p.b - base.b).length() < GRASS_TOL:
				ok += 1
	return ok >= int(r.size.x * r.size.y * GRASS_MIN_RATIO)


## Karonun "zeminin altında" alternatifi (TileSet paylaşılır ve sahne önbelleğinde kalır: ikinci oyunda yenisi açılmaz, meta'dan bulunur).
static func _under_alternative(ts: TileSet, source_id: int, coords: Vector2i) -> int:
	var src := ts.get_source(source_id) as TileSetAtlasSource
	var key := StringName("hr_alt_alti_%d_%d" % [coords.x, coords.y])
	if src.has_meta(key) and src.has_alternative_tile(coords, int(src.get_meta(key))):
		return int(src.get_meta(key))
	var alt: int = src.create_alternative_tile(coords)
	src.get_tile_data(coords, alt).z_index = STRAY_UNDER_Z
	src.set_meta(key, alt)
	return alt
