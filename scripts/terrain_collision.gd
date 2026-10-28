extends RefCounted

## HARİTA NESNELERİNİN ENGEL HÜCRELERİ (collision "her şey için yeniden hesaplandı") - kullanıcı isteği 2026-10-08: "oyundaki collision shapeleri yeniden
## hesapla herşey için"; soruyla netleşti: OYUNCU + YARATIKLAR (yol bulma dahil), su + evler/demirci + ağaç gövdeleri + maden/düşman üssü.
## Haritada gerçek CollisionShape2D YOK (bkz. player.gd _block_movement_into_terrain notu): hareket engeli bir hücre sorgusu. Bu dosya onu orman duvarının
## (GameManager.is_position_blocked_by_forest) ÜSTÜNE bu nesnelerle genişletir; hepsi oyun başında haritadaki karolardan HESAPLANIR - harita Tiled'da
## değişip yeniden bake edilince kendiliğinden güncel kalır (TileSet'e dokunulmaz).
##
## Yöntem (hücre = orman katmanının ızgarası, 16 px): bir nesnenin yere değdiği ALT BANT (karoların son satırlarından, depth_occluders.gd'nin nesne KÖKÜNE göre
## - object_bases/building_bases) piksel piksel taranır; opak pikseller ayak izidir. Hareket engeli oyuncunun/yaratığın KÖK noktasıyla (gövde ortası) sorgulanır,
## ayağı kökün ~15 px aşağısında olduğundan ayak izi 15 px YUKARI kaydırılır (FEET_SHIFT) - böylece AYAK nesneye değince durulur. Bir hücre ancak içine
## MIN_PIXELS piksel düşerse engel olur (ağaç gövdesi ~2 hücre, bina duvarı bandı ~2 hücre kalınlığında). Su: "Su/Su" katmanının hücreleri (1 hücre yukarı
## kaydırılmış); "Köprü/Köprü alt" altındaki su hücreleri açık (köprüden yürünür).
## Su/bina/maden görüşü KESMEZ: sis/görüş orman duvarı + (2026-10-09) ağaç katmanlarıdır (vision_occluders.gd, enemy_pathing.gd _fog_blocked -> C++ set_grid fog_blocked); mermiler orman/uçurum duvarı hariç geçer.
## Kategori başına açma/kapama sabitleri aşağıda (hepsi açık).
## Tuzaklar: Tiled'da bu katman adları değişirse sabitler güncellenmeli (bulunamayan katman sessizce atlanır; test_terrain_collision hepsinin bulunduğunu sınar);
## yassı/zemine serili bir katmanı nesne katmanlarına ekleme (ayak izi olarak yürünmez bir şerit çıkar); Düşman üssü ve maden bandı kalınlıkları gözle ayarlıydı.

const DepthScript := preload("res://scripts/depth_occluders.gd")
const MapFrameScript := preload("res://scripts/map_frame.gd")

const ENABLE_WATER := true
const ENABLE_HOUSES := true
const ENABLE_TREES := true
const ENABLE_MINES := true
const ENABLE_ENEMY_BASE := true
const ENABLE_DEEP_FOREST := true
const ENABLE_PROPS := true

const FEET_SHIFT := 15.0
const MIN_PIXELS := 20
const TREE_BAND := 9.0
const HOUSE_BAND := 28.0
const MINE_BAND := 14.0
const BASE_BAND := 12.0
## Derin orman set parçaları (kemik taht, dev iskelet, harabe, kafa yığını, kök tümseği...; madde 359/364): bant nesnenin boyuyla orantılı
## (boy x DEEP_FOREST_BAND_RATIO, en az / en çok) - eskiden sabit 12 px'ti, büyük kayaların/heykelin gövdesine yürünüyordu.
const DEEP_FOREST_BAND := 12.0
const DEEP_FOREST_BAND_RATIO := 0.4
const DEEP_FOREST_BAND_MAX := 36.0

const WATER_LAYER := "Su/Su"
## 2026-10-11 (collision analizi, madde 85): Su katmanı düz mavi + hücre bazlı; kıyıyı bu "ayrıntı" katmanları çimenle örtüyor ve Su katmanına
## kara olarak boyanmış yeşil çimen karoları da var. Hücre ancak GÖRÜNEN su pikseli (kıyı çimeni/kara karoları düşülünce) WATER_MIN_PIXELS'ten
## fazlaysa engel olur (eskiden ~%14'ü görünür su olmayan hayalet hücreydi).
const WATER_DETAIL_LAYERS: Array = ["Su/Su ayrıntılar 2", "Su/Su ayrıntılar 3", "Su/Su ayrıntıları 4"]
const WATER_MIN_PIXELS := 100
const BRIDGE_LAYER := "Köprü/Köprü alt"
## Bina DUVARI + kapısı (çatı/ayrıntı değil): ayak izi duvarın tabanı. Yürünüp kapıya etkileşimle girilir (yakınlık tabanlı), kapı hücreleri de engel.
const HOUSE_WALL_LAYERS: Array = ["ev/Blacksmith", "ev/blacksmith kapı", "ev/Ev", "ev/ev kapı"]
const TREE_PARENT := "Shader Eklenecek"
const TREE_PREFIX := "Ağaç"
const MINE_LAYERS: Array = ["Etkileşimler/Maden", "Etkileşimler/Maden 1"]
const BASE_LAYERS: Array = ["Düşman Üssü/Düşman üssü", "Düşman Üssü/Özel maden"]
## Derin orman: ölü ağaçlar "Ağaç ölü" (Ağaç önekli -> ağaç gövdesi kuralı), set parçaları burada; düz süsler ("Derin orman süsleri") sahne
## nesnesi kuralıyla (PROP_LAYERS, madde 364): katı görünenler engel, ot/kemik kırıntısı/kristal sapı değil.
const DEEP_FOREST_LAYERS: Array = ["Shader Eklenecek/Derin orman nesneleri"]
## Zemine gömülü derin orman parçaları (madde 361: Batı zindan girişi "Et Kuyusu", dişli çukur) - karakterin altında çizilir, ayak izinin TAMAMI
## engel (çukurun üstünden yürünmesin): bant parçanın boyundan uzun.
const DEEP_FOREST_PIT_LAYERS: Array = ["Shader Eklenecek/Derin orman çukurları"]
const DEEP_FOREST_PIT_BAND := 96.0
## SAHNE NESNELERİ (madde 364, kullanıcı: "engeller var kaya obje v.b ama engel oluşturmuyorlar üstlerine gidebiliyoruz"): bu katmanlardaki kaya,
## kütük, devrik ağaç, kemik yığını gibi KATI görünen nesneler engel olur; mantar, ot, çiçek, sarmaşık, çakıl, çalı (yeşil) olmaz. Sınıflama
## nesne başına (atlasta komşu karolar = bir nesne, depth_occluders kuralı), karolardan oyun başında: opak alanın sınırı en az PROP_MIN_W x
## PROP_MIN_H px, en az PROP_MIN_PIXELS opak piksel, sınır kutusu doluluğu >= PROP_MIN_DENSITY, yeşil (yaprak) piksel payı < PROP_MAX_GREEN.
## Zemin/leke karoları (PROP_SKIP_TEXTURES dokularından) hiç sayılmaz (uçurum katmanlarında zemin şeritleri de var).
## Ayak izi: y-sıralı katmanda (depth_occluders OBJECT_LAYERS - karakter nesnenin arkasına geçebilir) boyun PROP_DEPTH_RATIO'su, diğerlerinde
## (nesne hep karakterin altında çizilir) nesnenin TAMAMI (en çok PROP_FULL_MAX) - yoksa karakter kayanın üstünde duruyormuş gibi görünür.
const PROP_LAYERS: Array = ["Shader Eklenecek/Animasyonsuz çalılar", "Orman parçaları/Orman parçaları 3", "Orman parçaları/Orman parçaları 4",
	"Orman parçaları/orman parçaları -1", "Shader Eklenecek/Derin orman süsleri"]
const PROP_SKIP_TEXTURES: Array[String] = ["Ground_grass", "derin_orman_zemin", "spots_lianas", "Flowers", "Yol par", "Water"]
const PROP_MIN_W := 18
const PROP_MIN_H := 14
const PROP_MIN_PIXELS := 220
const PROP_MIN_DENSITY := 0.35
const PROP_MAX_GREEN := 0.4
## Küçük nesnede (sınır kutusu <= PROP_SMALL_AREA px²) yaprak + kırmızı mantar şapkası payı bunu geçerse engel değil (mantar öbekleri).
const PROP_SMALL_AREA := 700.0
const PROP_SMALL_MAX_SOFT := 0.15
const PROP_DEPTH_RATIO := 0.5
const PROP_DEPTH_MAX := 24.0
const PROP_FULL_MAX := 48.0
const PROP_MIN_BAND := 8.0

static var _cells: Dictionary = {} ## orman katmanı hücre koordinatı (Vector2i) -> true
static var _layer_id: int = 0
static var _inv: Transform2D = Transform2D.IDENTITY
static var _cell_px: float = 16.0
## Kategori -> engel hücre sayısı ve hücreleri (testler/hata ayıklama): stats["trees"] = 137, by_category["trees"] = [Vector2i, ...]
static var stats: Dictionary = {}
static var by_category: Dictionary = {}


## Testler ve yeni harita yükleyen kod için: kurulu hücreleri at (bir sonraki sorguda yeniden hesaplanır).
static func reset() -> void:
	_cells = {}
	_layer_id = 0
	stats = {}
	by_category = {}


## Orman katmanına göre hücre kümesi (yoksa bir kez hesaplanır). Orman katmanı yoksa boş.
static func ensure(forest: TileMapLayer) -> Dictionary:
	if forest == null or not is_instance_valid(forest):
		return {}
	var id: int = forest.get_instance_id()
	if id != _layer_id:
		_build(forest)
	return _cells


## Ağaç gövdesi hücrelerinin (by_category["trees"]) DÜNYA konumu: hücre merkezi + ayak kaydırması = ağacın dibi (papağan gagalama hedefi, madde 203).
static func cell_world_base(cell: Vector2i) -> Vector2:
	return _inv.affine_inverse() * ((Vector2(cell) + Vector2(0.5, 0.5)) * _cell_px) + Vector2(0.0, FEET_SHIFT)


## world_pos'ta (orman duvarı DEĞİL, bu dosyanın nesneleri) engel hücresi var mı. GameManager.is_position_blocked_by_walls kullanır.
static func is_blocked(forest: TileMapLayer, world_pos: Vector2) -> bool:
	if ensure(forest).is_empty():
		return false
	var local: Vector2 = _inv * world_pos
	return _cells.has(Vector2i(floori(local.x / _cell_px), floori(local.y / _cell_px)))


static func _find_harita(forest: TileMapLayer) -> Node:
	var n: Node = forest.get_parent()
	for i in range(4):
		if n == null:
			return null
		if n.name == &"Harita" or (n.get_node_or_null("Su") != null and n.get_node_or_null("ev") != null):
			return n
		n = n.get_parent()
	return forest.get_parent().get_parent() if forest.get_parent() != null else null


static func _build(forest: TileMapLayer) -> void:
	_layer_id = forest.get_instance_id()
	_cells = {}
	stats = {}
	by_category = {}
	_inv = forest.global_transform.affine_inverse()
	_cell_px = float(forest.tile_set.tile_size.x) if forest.tile_set != null else 16.0
	var harita: Node = _find_harita(forest)
	if harita == null:
		return
	var helper: Node = DepthScript.new() ## sahneye eklenmez: sadece saf hesap işlevleri (object_bases / building_bases / opaque_pixels)
	var g0: Vector2 = helper.cell_origin(forest)
	if ENABLE_WATER:
		_add_water(helper, harita, g0)
	if ENABLE_HOUSES:
		var layers: Array[TileMapLayer] = []
		for path: String in HOUSE_WALL_LAYERS:
			var l := harita.get_node_or_null(path) as TileMapLayer
			if l != null and l.tile_set != null and not l.get_used_cells().is_empty():
				layers.append(l)
		if not layers.is_empty():
			var per_layer: Dictionary = helper.building_bases(layers)
			var counts: Dictionary = {}
			for l in layers:
				_add_band(helper, l, per_layer.get(l, {}), HOUSE_BAND, g0, counts)
			_commit("houses", counts)
	if ENABLE_TREES:
		var counts_t: Dictionary = {}
		var parent: Node = harita.get_node_or_null(TREE_PARENT)
		if parent != null:
			for child in parent.get_children():
				var l := child as TileMapLayer
				if l != null and l.tile_set != null and String(l.name).begins_with(TREE_PREFIX):
					_add_band(helper, l, helper.object_bases(l), TREE_BAND, g0, counts_t)
		_commit("trees", counts_t)
	if ENABLE_MINES:
		_add_object_layers(helper, harita, MINE_LAYERS, MINE_BAND, g0, "mines")
	if ENABLE_ENEMY_BASE:
		_add_object_layers(helper, harita, BASE_LAYERS, BASE_BAND, g0, "enemy_base")
	if ENABLE_DEEP_FOREST:
		var counts_d: Dictionary = {}
		for path: String in DEEP_FOREST_LAYERS:
			var l := harita.get_node_or_null(path) as TileMapLayer
			if l != null and l.tile_set != null:
				for grp: Dictionary in object_groups(helper, l, false):
					var band: float = clampf(float(grp["h"]) * DEEP_FOREST_BAND_RATIO, DEEP_FOREST_BAND, DEEP_FOREST_BAND_MAX)
					_add_band(helper, l, grp["bases"], band, g0, counts_d)
		for path: String in DEEP_FOREST_PIT_LAYERS:
			var l := harita.get_node_or_null(path) as TileMapLayer
			if l != null and l.tile_set != null and not l.get_used_cells().is_empty():
				_add_band(helper, l, helper.object_bases(l), DEEP_FOREST_PIT_BAND, g0, counts_d)
		_commit("deep_forest", counts_d)
	if ENABLE_PROPS:
		var counts_p: Dictionary = {}
		var solid: int = 0
		for path: String in PROP_LAYERS:
			var l := harita.get_node_or_null(path) as TileMapLayer
			if l == null or l.tile_set == null:
				continue
			var depth_sorted: bool = DepthScript.OBJECT_LAYERS.has(path)
			for grp: Dictionary in object_groups(helper, l):
				if not is_solid_prop(grp):
					continue
				solid += 1
				var h: float = float(grp["h"])
				var band: float = clampf(h * PROP_DEPTH_RATIO, PROP_MIN_BAND, PROP_DEPTH_MAX) if depth_sorted else clampf(h, PROP_MIN_BAND, PROP_FULL_MAX)
				_add_band(helper, l, grp["bases"], band, g0, counts_p)
		_commit("props", counts_p)
		stats["props_objects"] = solid
	helper.free()


## Katmanın nesneleri (depth_occluders.object_bases ile AYNI birleştirme: atlasta sağ/alt komşu karo = aynı nesne). Her biri:
## {"bases": hücre -> kök y, "w"/"h": opak sınır kutusu (px), "px": opak piksel, "green": yaprak / "red": kırmızı mantar şapkası piksel payı,
## "skip": zemin/leke dokusu}.
static func object_groups(helper: Node, layer: TileMapLayer, with_colors: bool = true) -> Array:
	var bases: Dictionary = helper.object_bases(layer)
	var by_base: Dictionary = {} ## kök y + bağlantı -> hücreler (aynı kökü paylaşan bitişik hücreler)
	var parent: Dictionary = {}
	for c: Vector2i in bases:
		parent[c] = c
	for c: Vector2i in bases:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n: Vector2i = c + d
			if bases.has(n) and is_equal_approx(float(bases[n]), float(bases[c])):
				helper._union(parent, c, n)
	for c: Vector2i in bases:
		var r: Vector2i = helper._find(parent, c)
		if not by_base.has(r):
			by_base[r] = []
		(by_base[r] as Array).append(c)
	var ofs: Vector2 = helper.cell_origin(layer)
	var color_cache: Dictionary = {}
	var skip_by_sid: Dictionary = {} ## kaynak -> "zemin/leke dokusu mu" (karo başına altı metin aramasından kurtarır)
	var out: Array = []
	for r: Vector2i in by_base:
		var cells: Array = by_base[r]
		var sub: Dictionary = {}
		var x0: float = 1.0e9
		var y0: float = 1.0e9
		var x1: float = -1.0e9
		var y1: float = -1.0e9
		var px: int = 0
		var skip: bool = false
		for c: Vector2i in cells:
			sub[c] = bases[c]
			var sid: int = layer.get_cell_source_id(c)
			var src := layer.tile_set.get_source(sid) as TileSetAtlasSource
			if src == null or src.texture == null:
				continue
			if not skip_by_sid.has(sid):
				var tex_path: String = src.texture.resource_path
				var sk: bool = false
				for k: String in PROP_SKIP_TEXTURES:
					if tex_path.contains(k):
						sk = true
				skip_by_sid[sid] = sk
			if skip_by_sid[sid]:
				skip = true
			## karo başına opak sınır (çevirme dahil) önbellekte: (sayı, min x, min y, max x, max y)
			var tb: Array = helper.opaque_bounds(layer, c) ## karo başına (sayı, min x, min y, max x, max y), helper'da önbellekli
			if int(tb[0]) > 0:
				var cx0: float = ofs.x + float(c.x) * 16.0
				var cy0: float = ofs.y + float(c.y) * 16.0
				x0 = minf(x0, cx0 + float(tb[1]))
				y0 = minf(y0, cy0 + float(tb[2]))
				x1 = maxf(x1, cx0 + float(tb[3]))
				y1 = maxf(y1, cy0 + float(tb[4]))
				px += int(tb[0])
		var w: float = x1 - x0 + 1.0 if px > 0 else 0.0
		var h: float = y1 - y0 + 1.0 if px > 0 else 0.0
		var grp := {"bases": sub, "w": w, "h": h, "px": px, "green": 0.0, "red": 0.0, "skip": skip}
		## renk payı yalnız boyut eşiklerini geçen nesnede (yükleme süresi; çoğu ot/çakıl burada elenir)
		if with_colors and _passes_size(grp):
			var green: int = 0
			var red: int = 0
			for c: Vector2i in cells:
				var sid: int = layer.get_cell_source_id(c)
				var src := layer.tile_set.get_source(sid) as TileSetAtlasSource
				if src == null or src.texture == null:
					continue
				var region: Rect2i = src.get_tile_texture_region(layer.get_cell_atlas_coords(c))
				var key := Vector3i(sid, region.position.x, region.position.y)
				if not color_cache.has(key):
					color_cache[key] = _tile_colors(helper._image_of(src.texture), region)
				green += (color_cache[key] as Vector2i).x
				red += (color_cache[key] as Vector2i).y
			grp["green"] = float(green) / maxf(float(px), 1.0)
			grp["red"] = float(red) / maxf(float(px), 1.0)
		out.append(grp)
	return out


## Karonun (yaprak, kırmızı mantar şapkası) piksel sayısı - çevirmeden bağımsız.
static func _tile_colors(img: Image, region: Rect2i) -> Vector2i:
	var g := Vector2i.ZERO
	if img == null:
		return g
	for yy in range(region.size.y):
		for xx in range(region.size.x):
			var col: Color = img.get_pixel(region.position.x + xx, region.position.y + yy)
			if col.a <= 0.5:
				continue
			if col.g > col.r + 0.05 and col.g > col.b + 0.05:
				g.x += 1
			elif col.r > 0.55 and col.r > col.g + 0.3 and col.r > col.b + 0.3:
				g.y += 1
	return g


static func _passes_size(grp: Dictionary) -> bool:
	if bool(grp["skip"]):
		return false
	var w: float = float(grp["w"])
	var h: float = float(grp["h"])
	if w < PROP_MIN_W or h < PROP_MIN_H or int(grp["px"]) < PROP_MIN_PIXELS:
		return false
	return float(grp["px"]) / maxf(w * h, 1.0) >= PROP_MIN_DENSITY


## Nesne katı mı (kaya, kütük, devrik ağaç, kemik yığını...) - mantar, ot, çiçek, sarmaşık, çakıl, yeşil çalı, zemin şeridi DEĞİL.
static func is_solid_prop(grp: Dictionary) -> bool:
	if not _passes_size(grp):
		return false
	var w: float = float(grp["w"])
	var h: float = float(grp["h"])
	if w * h <= PROP_SMALL_AREA and float(grp["green"]) + float(grp.get("red", 0.0)) >= PROP_SMALL_MAX_SOFT:
		return false
	return float(grp["green"]) < PROP_MAX_GREEN


## extra: [[yollar, bant], ...] aynı kategoriye farklı bantla eklenen katmanlar (tek _commit).
static func _add_object_layers(helper: Node, harita: Node, paths: Array, band: float, g0: Vector2, category: String, extra: Array = []) -> void:
	var counts: Dictionary = {}
	var groups: Array = [[paths, band]] + extra
	for grp: Array in groups:
		for path: String in grp[0]:
			var l := harita.get_node_or_null(path) as TileMapLayer
			if l != null and l.tile_set != null and not l.get_used_cells().is_empty():
				_add_band(helper, l, helper.object_bases(l), float(grp[1]), g0, counts)
	_commit(category, counts)


## Su: katmanın her hücresi -> 1 hücre yukarı kaydırılmış engel (ayak izi kaydırması, 15 px ~ 1 hücre); köprü güvertesinin hücreleri açılır.
static func _add_water(helper: Node, harita: Node, g0: Vector2) -> void:
	var water := harita.get_node_or_null(WATER_LAYER) as TileMapLayer
	if water == null or water.tile_set == null:
		return
	var wofs: Vector2 = helper.cell_origin(water)
	var shift := Vector2i(roundi((wofs.x - g0.x) / 16.0), roundi((wofs.y - g0.y) / 16.0) - 1)
	var found: Dictionary = {}
	var details: Array = [] ## [{layer, shift}]: Su hücresinin üstünü örten katmanlar (çizim sırasıyla)
	for path: String in WATER_DETAIL_LAYERS:
		var dl := harita.get_node_or_null(path) as TileMapLayer
		if dl != null and dl.tile_set != null and not dl.get_used_cells().is_empty():
			var dofs: Vector2 = helper.cell_origin(dl)
			details.append({"layer": dl, "shift": Vector2i(roundi((dofs.x - wofs.x) / 16.0), roundi((dofs.y - wofs.y) / 16.0))})
	var mask_cache: Dictionary = {}
	for cell in water.get_used_cells():
		if not MapFrameScript.PLAY_CELLS.has_point(cell):
			continue ## dış çerçevedeki su (madde 119): hücre zaten orman katmanında dolu = engel; yüzlerce hücreyi taramak yükleme süresini uzatırdı
		if _visible_water_pixels(helper, water, cell, details, mask_cache) >= WATER_MIN_PIXELS:
			found[cell + shift] = true
	var bridge := harita.get_node_or_null(BRIDGE_LAYER) as TileMapLayer
	if bridge != null and bridge.tile_set != null:
		var bofs: Vector2 = helper.cell_origin(bridge)
		var bshift := Vector2i(roundi((bofs.x - g0.x) / 16.0), roundi((bofs.y - g0.y) / 16.0) - 1)
		for cell in bridge.get_used_cells():
			found.erase(cell + bshift)
	for c: Vector2i in found:
		_cells[c] = true
	stats["water"] = found.size()
	by_category["water"] = found.keys()


## bases: katmandaki hücre -> nesne kökü (dünya y). Her hücrenin köke yakın BAND px'lik bandındaki opak pikselleri ayak izine (kaydırılmış) sayar.
static func _add_band(helper: Node, layer: TileMapLayer, bases: Dictionary, band: float, g0: Vector2, counts: Dictionary) -> void:
	var ofs: Vector2 = helper.cell_origin(layer)
	## Hücre piksel (x, y) -> ayak izi hücresi: aynı ifade (aynı kayan nokta sırası) sütun / satır başına BİR kez hesaplanıp tabloda tutulur (eskiden her pikselde, madde 372)
	var xtab: Dictionary = {} ## hücrenin sol x'i -> 16 sütunun ayak izi hücre x'i
	var ytab: Dictionary = {} ## hücrenin üst y'si -> 16 satırın ayak izi hücre y'si
	for cell: Vector2i in bases:
		var base: float = float(bases[cell])
		var top: float = ofs.y + float(cell.y) * 16.0
		var left: float = ofs.x + float(cell.x) * 16.0
		var r0: int = maxi(0, ceili(base - band - top))
		var r1: int = mini(15, ceili(base - top) - 1)
		if r1 < r0:
			continue
		if not xtab.has(left):
			var xt := PackedInt32Array()
			for i in range(16):
				var wx: float = left + float(i) + 0.5
				xt.append(floori((wx - g0.x) / 16.0))
			xtab[left] = xt
		if not ytab.has(top):
			var yt := PackedInt32Array()
			for i in range(16):
				var wy: float = top + float(i) + 0.5 - FEET_SHIFT
				yt.append(floori((wy - g0.y) / 16.0))
			ytab[top] = yt
		var gxs: PackedInt32Array = xtab[left]
		var gys: PackedInt32Array = ytab[top]
		for px: Vector2i in helper.opaque_pixels(layer, cell, r0, r1):
			var gc := Vector2i(gxs[px.x], gys[px.y])
			counts[gc] = int(counts.get(gc, 0)) + 1


static func _commit(category: String, counts: Dictionary) -> void:
	var list: Array = []
	for gc: Vector2i in counts:
		if int(counts[gc]) >= MIN_PIXELS:
			_cells[gc] = true
			list.append(gc)
	stats[category] = list.size()
	by_category[category] = list


## Bir kategorinin hücrelerini (maden kırılınca/yeniden doğunca, bkz. mine_world.gd) açar/kapar. Başka bir kategorinin (su/bina/ağaç/üs) hücresi AÇILMAZ.
## `by_category[category]` listesi (testler/hata ayıklama) değişmez: o her zaman "tam doğmuş" ayak izidir.
static func set_category_cells_blocked(category: String, cells: Array, blocked: bool) -> void:
	var others: Dictionary = {}
	for key: String in by_category:
		if key != category:
			for gc: Vector2i in by_category[key]:
				others[gc] = true
	for gc: Vector2i in cells:
		if blocked:
			_cells[gc] = true
		elif not others.has(gc):
			_cells.erase(gc)


## Su hücresinde GÖRÜNEN su pikseli sayısı: Su karosunun mavi pikselleri - üstündeki ayrıntı katmanlarının (kıyı çimeni vb.) mavi OLMAYAN opak pikselleri.
## Su karosu mavi değilse (kara olarak boyanmış çimen karosu) 0.
static func _visible_water_pixels(helper: Node, water: TileMapLayer, cell: Vector2i, details: Array, cache: Dictionary) -> int:
	var base: PackedByteArray = _class_mask(helper, water, cell, cache)
	if base.is_empty():
		return 0
	var visible: PackedByteArray = base.duplicate()
	for d: Dictionary in details:
		var dl: TileMapLayer = d["layer"]
		var dc: Vector2i = cell - (d["shift"] as Vector2i)
		if dl.get_cell_source_id(dc) == -1:
			continue
		var over: PackedByteArray = _class_mask(helper, dl, dc, cache)
		for i in range(over.size()):
			if over[i] == 2:
				visible[i] = 0
	var n := 0
	for i in range(visible.size()):
		if visible[i] == 1:
			n += 1
	return n


## 16x16 karo maskesi (satır satır): 0 saydam, 1 opak mavi (su gibi), 2 opak mavi olmayan (çimen/kıyı/toprak). Çevirme/döndürme uygulanır; boş karo = boş dizi.
static func _class_mask(helper: Node, layer: TileMapLayer, cell: Vector2i, cache: Dictionary) -> PackedByteArray:
	var sid: int = layer.get_cell_source_id(cell)
	var src := layer.tile_set.get_source(sid) as TileSetAtlasSource
	if src == null or src.texture == null:
		return PackedByteArray()
	var coords: Vector2i = layer.get_cell_atlas_coords(cell)
	if not src.has_tile(coords):
		return PackedByteArray()
	var td: TileData = layer.get_cell_tile_data(cell)
	var fh: bool = td != null and td.flip_h
	var fv: bool = td != null and td.flip_v
	var tr: bool = td != null and td.transpose
	var key := Vector4i(src.texture.get_instance_id() & 0x7fffffff, coords.x * 4096 + coords.y, int(fh) + 2 * int(fv) + 4 * int(tr), 0)
	if cache.has(key):
		return cache[key]
	var out := PackedByteArray()
	out.resize(256)
	var img: Image = helper._image_of(src.texture)
	if img == null:
		return PackedByteArray()
	var region: Rect2i = src.get_tile_texture_region(coords)
	for y in range(16):
		for x in range(16):
			var sx: int = 15 - x if fh else x
			var sy: int = 15 - y if fv else y
			if tr:
				var t: int = sx
				sx = sy
				sy = t
			var c: Color = img.get_pixel(region.position.x + clampi(sx, 0, region.size.x - 1), region.position.y + clampi(sy, 0, region.size.y - 1))
			var cls := 0
			if c.a > 0.5:
				cls = 1 if (c.b > c.g + 0.03 and c.b > c.r + 0.1) else 2
			out[y * 16 + x] = cls
	cache[key] = out
	return out
