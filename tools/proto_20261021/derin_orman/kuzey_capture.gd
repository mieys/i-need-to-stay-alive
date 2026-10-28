extends SceneTree

## DERİN ORMAN prototipi - KUZEY bölgesi (oyuna bağlı DEĞİL; kullanıcı: "tepelerin arkası daha farklı, gizemli, daha derin ve tehlikeli bir orman olmalı").
## GERÇEK ÇİZİCİ: harita_baked + main.gd'nin harita görselleri (calilik_capture.gd ile aynı kurulum). Bölge hücreleri kuzey_zone.py'den (out/kuzey_zone.txt).
## Çeşitler (KZ_VARIANT):
##   simdi = haritanın bugünkü hâli
##   a     = "Solgun Orman": bölgedeki TÜM yeşil ağaçlar silinir, yerlerine Yarı Ölü setinin ölü ağaçları; çiçekler silinir; kuru ot, kemik, diken, kütük,
##           kaya, mezar taşı serpilir
##   b     = "Kadim Kara Orman": yeşil orman gürültü desenine göre SIKLAŞIR (haritanın kendi 4x5 ağaç karoları basılır -> sallanma/derinlik/renk ayarı aynen),
##           ağaçların ~%25'i ölü ağaç, dibinde Parlayan Mağara mantarları, ışıyan bitkiler, diken, kütük
##   a ve b ortak: kemik taht + yerden çıkan eller + dev iskelet (derin çekim), harabe + kafa yığını (geçit çekimi), 3 iskelet (yaratık sprite'ı, duruk)
## Renk ayarı / sis / ruh ışıkları burada YOK - kuzey_sheet.py ekran görüntüsüne bölge maskesiyle ekler (karakter pikselleri ayrı yakalanıp üstte kalır).
## Her çekim iki kare: base_<çekim>.png (karakterler gizli) + char_<çekim>.png (karakterler görünür) + meta_<çekim>.txt (hücre (0,0) sol üst köşesinin ekran konumu).
## Kullanım: kuzey_run.ps1 (gizli masaüstü). Ortam: KZ_VARIANT, KZ_OUT (klasör), KZ_ZONE (kuzey_zone.txt).
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok - _run'da load edilir.

const ART := "../Harita içerikleri/"
const YO_ANIM := "Yari Olu Tileseti/Tiled_files/Objects_animated.png"
const YO_OBJ := "Yari Olu Tileseti/Tiled_files/Objects.png"
const PM_OBJ := "Parlayan Magara Tileseti/Tiled_files/Objects.png"
const SKELETON := "res://visuals/Yaratıklar/Tüm Yaratıklar/İskelet 1/PNG/Skeleton1/With_shadow/Skeleton1_Walk_with_shadow.png"

## sayfa, x, y, w, h (sayfa pikseli). Ölü ağaç/taht animasyonlu sayfada 6 kare, kare aralığı 112 px.
const SPR := {
	"olu_agac_b": [YO_ANIM, 23, 18, 100, 124], "olu_agac_o": [YO_ANIM, 21, 148, 70, 89], "olu_agac_k": [YO_ANIM, 17, 246, 62, 56],
	"taht_b": [YO_ANIM, 22, 316, 83, 100],
	"harabe_b": [YO_OBJ, 16, 16, 80, 95], "harabe_kemer": [YO_OBJ, 112, 49, 79, 62], "harabe_o": [YO_OBJ, 213, 51, 55, 54], "harabe_k": [YO_OBJ, 289, 65, 47, 46],
	"kuru_cali_b": [YO_OBJ, 19, 117, 59, 74], "kuru_cali_o": [YO_OBJ, 86, 128, 49, 63], "kuru_cali_k": [YO_OBJ, 151, 148, 32, 41],
	"kaya_b": [YO_OBJ, 18, 197, 57, 56], "kaya_o": [YO_OBJ, 82, 210, 45, 44], "kaya_k": [YO_OBJ, 134, 217, 34, 33],
	"kemik_1": [YO_OBJ, 243, 229, 26, 22], "kemik_2": [YO_OBJ, 290, 233, 25, 22], "kemik_3": [YO_OBJ, 320, 227, 32, 29], "kemik_4": [YO_OBJ, 353, 228, 22, 28],
	"kutuk_b": [YO_OBJ, 27, 275, 84, 39], "kutuk_k": [YO_OBJ, 176, 273, 30, 29], "kutuk_o": [YO_OBJ, 212, 273, 41, 31], "kutuk_2": [YO_OBJ, 259, 277, 42, 26],
	"iskelet_yigin": [YO_OBJ, 16, 336, 48, 48], "dev_iskelet": [YO_OBJ, 69, 323, 150, 113], "kaburga": [YO_OBJ, 258, 320, 30, 64], "dev_kafa": [YO_OBJ, 297, 328, 31, 47],
	"kemikler_k": [YO_OBJ, 21, 390, 34, 35], "hayvan_kafa": [YO_OBJ, 195, 388, 43, 39], "kafa_yigini": [YO_OBJ, 23, 439, 71, 51],
	"kuru_ot_b": [YO_OBJ, 208, 452, 64, 58], "kuru_ot_o": [YO_OBJ, 274, 471, 42, 37], "kuru_ot_k": [YO_OBJ, 321, 481, 30, 28],
	"solgun_agac_b": [YO_OBJ, 17, 499, 63, 89], "solgun_agac_o": [YO_OBJ, 85, 516, 59, 69], "solgun_agac_k": [YO_OBJ, 145, 545, 46, 45],
	"el_b": [YO_OBJ, 209, 530, 61, 62], "el_mavi": [YO_OBJ, 274, 533, 45, 57], "el_yesil": [YO_OBJ, 321, 534, 31, 53], "el_k": [YO_OBJ, 355, 546, 28, 43],
	"diken_b": [YO_OBJ, 16, 592, 110, 80], "diken_o": [YO_OBJ, 146, 615, 94, 53], "diken_k": [YO_OBJ, 257, 626, 58, 46],
	"mezar_1": [YO_OBJ, 16, 694, 16, 18], "mezar_2": [YO_OBJ, 80, 694, 16, 19], "mezar_3": [YO_OBJ, 112, 694, 16, 21], "mezar_4": [YO_OBJ, 280, 690, 16, 28],
	"mantar_b": [PM_OBJ, 23, 134, 50, 89], "mantar_o": [PM_OBJ, 86, 163, 37, 60], "mantar_k": [PM_OBJ, 133, 180, 22, 43],
	"cam_mantar_b": [PM_OBJ, 208, 159, 47, 65], "cam_mantar_k": [PM_OBJ, 256, 178, 32, 46],
	"isik_bitki_b": [PM_OBJ, 25, 308, 50, 66], "isik_bitki_o": [PM_OBJ, 83, 339, 37, 43], "isik_bitki_k": [PM_OBJ, 165, 358, 20, 25],
	"mor_mantar_b": [PM_OBJ, 209, 356, 45, 60], "mor_mantar_k": [PM_OBJ, 293, 377, 22, 39],
	"turuncu_mantar": [PM_OBJ, 19, 385, 44, 47], "turuncu_mantar_k": [PM_OBJ, 101, 405, 23, 27],
	"mavi_ot_1": [PM_OBJ, 238, 260, 21, 32], "mavi_ot_2": [PM_OBJ, 224, 307, 27, 38], "mavi_ot_3": [PM_OBJ, 183, 308, 32, 36],
}
const ANIMATED := ["olu_agac_b", "olu_agac_o", "olu_agac_k", "taht_b"]
## B'nin orman kümeleri (kaliplar.png'den seçildi): koyu iğne yapraklı / koyu yuvarlak ağaç grupları + haritanın kendi 2 ölü ağacı. Palmiye, sarı-yeşil, pembe yok.
const B_PICK := "13,131,138,52,144,228,164,227,22,172,230,65,234,104,238,81,249,102,25,79,3,18,36,2,37,223,41,1,61,100,73,102,76,249,67,251,238,111,248,120,237,58,83,35,202,228,224,242"

## Çekimler: ad, kamera merkez hücresi, oyuncu hücresi (yukarı bakar)
const SHOTS := [
	{"name": "gecit", "center": Vector2i(124, 36), "player": Vector2i(124, 41)},
	{"name": "derin", "center": Vector2i(125, 18), "player": Vector2i(122, 29)},
]
## Ağaç/süs basılmayan alanlar: taht açıklığı, geçit koridoru, dev iskelet
const RESERVED := [Rect2i(112, 12, 16, 15), Rect2i(119, 26, 10, 20), Rect2i(135, 15, 15, 11)]

var _out: String = OS.get_environment("KZ_OUT")
var _variant: String = OS.get_environment("KZ_VARIANT")
var _rng := RandomNumberGenerator.new()
var _sheets: Dictionary = {}
var _mat: ShaderMaterial
var _zone: Dictionary = {}
var _decor_root: Node2D
var _placed: Array[Vector2] = []
var _layers: Dictionary = {}
var _harita: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _sheet(rel: String) -> Texture2D:
	if not _sheets.has(rel):
		var p: String = ProjectSettings.globalize_path("res://").path_join(ART + rel).simplify_path()
		var img := Image.load_from_file(p)
		_sheets[rel] = ImageTexture.create_from_image(img)
	return _sheets[rel]


func _cell_world(c: Vector2i) -> Vector2:
	var l: TileMapLayer = _layers["zemin"]
	return l.to_global(l.map_to_local(c))


## Hücrenin ALT kenarına (ayak) oturan süs; y-sıralama düğüm konumuyla (ayak) yapılır.
func _put(kind: String, c: Vector2i, jitter: bool = true, flip: bool = false) -> Sprite2D:
	var d: Array = SPR[kind]
	var at := AtlasTexture.new()
	at.atlas = _sheet(d[0])
	var fx: int = int(d[1])
	if kind in ANIMATED:
		fx += 112 * _rng.randi_range(0, 5)
	at.region = Rect2(fx, d[2], d[3], d[4])
	var s := Sprite2D.new()
	s.texture = at
	s.centered = false
	s.offset = Vector2(-float(d[3]) * 0.5, -float(d[4]))
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.material = _mat
	s.flip_h = flip
	var p: Vector2 = _cell_world(c) + Vector2(0, 7)
	if jitter:
		p += Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-3, 3))
	s.position = p.round()
	_decor_root.add_child(s)
	_placed.append(p)
	return s


func _is_tree(c: Vector2i) -> bool:
	for k in ["agac0", "agac1", "agac2"]:
		if (_layers[k] as TileMapLayer).get_cell_source_id(c) != -1:
			return true
	return false


func _reserved(c: Vector2i) -> bool:
	for r: Rect2i in RESERVED:
		if r.has_point(c):
			return true
	return false


## Süs/ağaç konamayan hücre: bölge dışı, uçurum, plato, su, saklanma çalılığı, yol (çimen yok), ağaç.
func _blocked(c: Vector2i, allow_path: bool = false) -> bool:
	if not _zone.has(c):
		return true
	for k in ["orman", "plato", "su", "cali"]:
		if (_layers[k] as TileMapLayer).get_cell_source_id(c) != -1:
			return true
	if not allow_path and (_layers["cimen"] as TileMapLayer).get_cell_source_id(c) == -1:
		return true
	return _is_tree(c)


func _far(p: Vector2, d: float) -> bool:
	for q: Vector2 in _placed:
		if q.distance_squared_to(p) < d * d:
			return false
	return true


func _scatter(kinds: Array, count: int, min_px: float, allow_path: bool = false) -> void:
	var cells: Array = _zone.keys()
	_rng_shuffle(cells)
	var n: int = 0
	for c: Vector2i in cells:
		if n >= count:
			break
		if _blocked(c, allow_path) or _reserved(c) or not _far(_cell_world(c), min_px):
			continue
		_put(kinds[_rng.randi() % kinds.size()], c, true, _rng.randf() < 0.5)
		n += 1


func _rng_shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


## Bölgedeki ağaç hücrelerinin 4-komşu parçaları (üç ağaç katmanı birlikte).
func _tree_components() -> Array:
	var cells: Dictionary = {}
	for c: Vector2i in _zone:
		if _is_tree(c):
			cells[c] = true
	var seen: Dictionary = {}
	var out: Array = []
	for c: Vector2i in cells:
		if seen.has(c):
			continue
		var comp: Array[Vector2i] = []
		var stack: Array[Vector2i] = [c]
		seen[c] = true
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			comp.append(p)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				if cells.has(q) and not seen.has(q):
					seen[q] = true
					stack.append(q)
		out.append(comp)
	return out


## Bir ağaç parçasının taban noktaları: önce alt kenar hücreleri, aralarında en az 3,5 hücre.
func _tree_bases(comp: Array) -> Array[Vector2i]:
	var set_: Dictionary = {}
	for c: Vector2i in comp:
		set_[c] = true
	var cand: Array = []
	for c: Vector2i in comp:
		cand.append([0 if not set_.has(c + Vector2i(0, 1)) else 1, _rng.randf(), c])
	cand.sort()
	var bases: Array[Vector2i] = []
	for e: Array in cand:
		var c: Vector2i = e[2]
		var ok: bool = true
		for b: Vector2i in bases:
			if Vector2(b - c).length() < 3.5:
				ok = false
				break
		if ok:
			bases.append(c)
	return bases


func _erase_zone_trees() -> void:
	for c: Vector2i in _zone:
		for k in ["agac0", "agac1", "agac2"]:
			(_layers[k] as TileMapLayer).erase_cell(c)


func _dead_tree(c: Vector2i) -> void:
	var r: float = _rng.randf()
	var kind: String = "olu_agac_b" if r < 0.3 else ("olu_agac_o" if r < 0.75 else ("solgun_agac_b" if r < 0.88 else "solgun_agac_o"))
	_put(kind, c, true, _rng.randf() < 0.5)


## Haritanın kendi ORMAN KÜMELERİ (bölge dışından): üç ağaç katmanının birleşik 4-komşu parçaları, 20-260 hücre, kutu <= 16x18.
## Kalıp = [{"cells": [[ofs, katman, kaynak, atlas, alt], ...], "size": Vector2i, "key": "x,y"}]. KZ_PICK verilirse sadece o anahtarlı kalıplar.
func _tree_templates() -> Array:
	var cells: Dictionary = {}
	for k in ["agac0", "agac1", "agac2"]:
		for c: Vector2i in (_layers[k] as TileMapLayer).get_used_cells():
			if not _zone.has(c):
				cells[c] = true
	var seen: Dictionary = {}
	var out: Array = []
	var pick := PackedStringArray()
	if OS.get_environment("KZ_DUMP") == "":
		var raw: PackedStringArray = B_PICK.split(",")
		for i in range(0, raw.size() - 1, 2):
			pick.append(raw[i] + "," + raw[i + 1])
	for c: Vector2i in cells:
		if seen.has(c):
			continue
		var comp: Array[Vector2i] = []
		var stack: Array[Vector2i] = [c]
		seen[c] = true
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			comp.append(p)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				if cells.has(q) and not seen.has(q):
					seen[q] = true
					stack.append(q)
		var bb := Rect2i(comp[0], Vector2i.ONE)
		for p: Vector2i in comp:
			bb = bb.expand(p).expand(p + Vector2i.ONE)
		if comp.size() < 20 or comp.size() > 260 or bb.size.x > 16 or bb.size.y > 18:
			continue
		var key := "%d,%d" % [bb.position.x, bb.position.y]
		if not pick.is_empty() and not (key in pick):
			continue
		var t: Array = []
		for p: Vector2i in comp:
			for k in ["agac0", "agac1", "agac2"]:
				var l: TileMapLayer = _layers[k]
				if l.get_cell_source_id(p) != -1:
					t.append([p - bb.position, k, l.get_cell_source_id(p), l.get_cell_atlas_coords(p), l.get_cell_alternative_tile(p)])
		out.append({"cells": t, "size": bb.size, "key": key})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["key"] < b["key"])
	return out


## KZ_DUMP=1: kalıpları tek sayfaya çizer (out/kaliplar.png + kaliplar.txt), seçim için.
func _dump_templates(templates: Array) -> void:
	var cols: int = 8
	var cw: int = 16 * 16 + 8
	var chh: int = 18 * 16 + 14
	var rows: int = int(ceil(float(templates.size()) / cols))
	var sheet := Image.create(cols * cw, rows * chh, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.25, 0.32, 0.22))
	var lines := PackedStringArray()
	for i in range(templates.size()):
		var t: Dictionary = templates[i]
		var ox: int = (i % cols) * cw + 4
		var oy: int = (i / cols) * chh + 12
		for k in ["agac0", "agac1", "agac2"]:
			for e: Array in t["cells"]:
				if e[1] != k:
					continue
				var src := (_layers[k] as TileMapLayer).tile_set.get_source(e[2]) as TileSetAtlasSource
				var reg: Rect2i = src.get_tile_texture_region(e[3])
				var timg: Image = src.texture.get_image()
				timg.convert(Image.FORMAT_RGBA8)
				var tile: Image = timg.get_region(reg)
				sheet.blend_rect(tile, Rect2i(Vector2i.ZERO, reg.size), Vector2i(ox, oy) + (e[0] as Vector2i) * 16)
		lines.append("%d %s %dx%d %d" % [i, t["key"], t["size"].x, t["size"].y, t["cells"].size()])
	sheet.save_png(_out.path_join("kaliplar.png"))
	var f := FileAccess.open(_out.path_join("kaliplar.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("SHOT dump ", templates.size())


## B: haritanın kendi orman kümelerini gürültü desenine göre bölgeye bas (kümeler sığdığı yere; ağaç/uçurum/çalılık/yol/ayrılmış alanla çakışmaz).
## Kümelerin ~%18'i yerine ölü ağaç öbeği (kümenin taban noktalarında). Kümelerin dibine küçük ışıyan mantar.
func _densify(templates: Array) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.05
	var cells: Array = []
	for _pass in range(4):
		var once: Array = _zone.keys()
		_rng_shuffle(once)
		cells.append_array(once)
	var stamped: int = 0
	var dead: int = 0
	for c: Vector2i in cells:
		var t: Dictionary = templates[_rng.randi() % templates.size()]
		var sz: Vector2i = t["size"]
		if noise.get_noise_2d(c.x + sz.x * 0.5, c.y + sz.y * 0.5) < -0.3:
			continue
		var ok: bool = true
		for e: Array in t["cells"]:
			var q: Vector2i = c + e[0]
			if _blocked(q) or _reserved(q):
				ok = false
				break
		if not ok:
			continue
		var comp: Array = []
		for e: Array in t["cells"]:
			comp.append(c + e[0])
		if _rng.randf() < 0.18:
			for b: Vector2i in _tree_bases(comp):
				_dead_tree(b)
			dead += 1
			continue
		for e: Array in t["cells"]:
			(_layers[e[1]] as TileMapLayer).set_cell(c + e[0], e[2], e[3], e[4])
		stamped += 1
		var bases: Array[Vector2i] = _tree_bases(comp)
		for b: Vector2i in bases:
			if _rng.randf() < 0.25:
				var mc := b + Vector2i(_rng.randi_range(-1, 1), 1)
				if not _blocked(mc) and not _reserved(mc):
					var mk: Array = ["mantar_k", "turuncu_mantar_k", "mor_mantar_k", "isik_bitki_k"]
					_put(mk[_rng.randi() % mk.size()], mc)
	print("b: basilan kume=", stamped, " olu oek=", dead)


func _set_pieces() -> void:
	## derin çekim: kemik taht açıklığı
	_put("taht_b", Vector2i(120, 17), false)
	_put("el_b", Vector2i(116, 21))
	_put("el_mavi", Vector2i(124, 21))
	_put("el_yesil", Vector2i(118, 23))
	_put("el_k", Vector2i(126, 23))
	_put("kafa_yigini", Vector2i(114, 17))
	_put("diken_o", Vector2i(113, 14), false)
	_put("diken_k", Vector2i(128, 15), false)
	_put("kemikler_k", Vector2i(121, 25))
	_put("dev_iskelet", Vector2i(142, 24), false)
	_put("kaburga", Vector2i(134, 20))
	## geçit çekimi: harabe + kafa yığını uçurum ağzında
	_put("harabe_b", Vector2i(116, 31), false)
	_put("harabe_k", Vector2i(133, 34), false, true)
	_put("kafa_yigini", Vector2i(120, 33))
	_put("kemik_3", Vector2i(127, 32))
	_put("dev_kafa", Vector2i(130, 31))


func _skeleton(c: Vector2i, frame: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(SKELETON)
	s.hframes = 6
	s.vframes = 4
	s.frame = frame
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * 1.28925 * 0.8075
	s.position = _cell_world(c) + Vector2(0, -14)
	return s


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	_rng.seed = 20261021
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 1
	gm.selected_character = 1
	var scene := Node2D.new()
	scene.y_sort_enabled = true
	root.add_child(scene)
	current_scene = scene
	_harita = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	_harita.name = "Harita"
	_harita.position = Vector2(-2, 21)
	scene.add_child(_harita)
	for pair in [["zemin", "Yer/Zemin Çimen"], ["cimen", "Yer/Zemin Çimen"], ["orman", "Orman parçaları/Orman parçaları"], ["plato", "Orman parçaları/Orman parçaları 2"],
			["su", "Su/Su"], ["cali", "Orman parçaları/Saklanma Çalılığı"], ["agac0", "Shader Eklenecek/Ağaç 0"], ["agac1", "Shader Eklenecek/Ağaç 1"],
			["agac2", "Shader Eklenecek/Ağaç 2"], ["cicek", "Shader Eklenecek/Çiçekler 1"]]:
		var n: TileMapLayer = _harita.get_node_or_null(pair[1]) as TileMapLayer
		if n == null:
			push_error("katman yok: " + pair[1])
			quit(1)
			return
		_layers[pair[0]] = n
	for line in FileAccess.get_file_as_string(OS.get_environment("KZ_ZONE")).split("\n"):
		var xy: PackedStringArray = line.strip_edges().split(",")
		if xy.size() == 2:
			_zone[Vector2i(int(xy[0]), int(xy[1]))] = true
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/harita_renk_duz.gdshader")
	_decor_root = Node2D.new()
	_decor_root.y_sort_enabled = true
	scene.add_child(_decor_root)
	if OS.get_environment("KZ_DUMP") != "":
		DirAccess.make_dir_recursive_absolute(_out)
		_dump_templates(_tree_templates())
		quit()
		return
	if _variant == "a" or _variant == "b":
		for c: Vector2i in _zone:
			(_layers["cicek"] as TileMapLayer).erase_cell(c)
		_set_pieces()
	if _variant == "a":
		var comps: Array = _tree_components()
		var bases: Array[Vector2i] = []
		for comp: Array in comps:
			bases.append_array(_tree_bases(comp))
		_erase_zone_trees()
		for b: Vector2i in bases:
			if not _reserved(b):
				_dead_tree(b)
		print("a: olu agac=", bases.size())
		_scatter(["kuru_ot_o", "kuru_ot_k", "kuru_ot_k"], 70, 70.0, true)
		_scatter(["kemik_1", "kemik_2", "kemik_3", "kemik_4", "kemikler_k", "hayvan_kafa"], 45, 80.0, true)
		_scatter(["diken_b", "diken_o", "diken_k", "kuru_cali_o", "kuru_cali_k"], 45, 80.0)
		_scatter(["kaya_o", "kaya_k", "kutuk_b", "kutuk_k", "kutuk_o", "kutuk_2"], 35, 90.0)
		_scatter(["solgun_agac_k", "olu_agac_k"], 25, 90.0)
		_scatter(["mezar_1", "mezar_2", "mezar_3", "mezar_4", "iskelet_yigin"], 14, 110.0)
	elif _variant == "b":
		_densify(_tree_templates())
		_scatter(["mavi_ot_1", "isik_bitki_k", "isik_bitki_o", "isik_bitki_k"], 30, 100.0)
		_scatter(["mor_mantar_k", "turuncu_mantar_k", "mantar_k"], 30, 90.0)
		_scatter(["diken_b", "diken_o", "diken_k", "kutuk_b", "kutuk_o", "kutuk_2", "kaya_k"], 45, 80.0)
		_scatter(["kemik_1", "kemik_2", "kemikler_k", "kemik_4"], 25, 90.0, true)
	await process_frame
	load("res://scripts/grass_sway.gd").new().setup(_harita)
	load("res://scripts/tree_sway.gd").new().setup(_harita)
	load("res://scripts/depth_occluders.gd").new().setup(_harita)
	load("res://scripts/forest_canopy.gd").new().setup(_harita)
	load("res://scripts/map_shadows.gd").attach(_harita)
	load("res://scripts/map_color_grade.gd").attach(_harita)
	load("res://scripts/water_fx.gd").attach(_harita)
	load("res://scripts/ground_texel_pass.gd").attach(_harita)
	## madde 359: oyundaki ruh ışıkları (sadece simdi = gerçek bake)
	var dfx: Node2D = load("res://scripts/deep_forest_fx.gd").attach(_harita) if _variant == "simdi" else null

	var hb: GDScript = load("res://scripts/hide_brush.gd")
	var feet_off: float = float(hb.FEET_OFFSET)
	var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.scale = Vector2(0.5, 0.5)
	scene.add_child(player)
	player.set_physics_process(false)
	var own_cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if own_cam:
		own_cam.enabled = false
	player.facing = "up"
	var chars: Array[Node2D] = [player]
	if _variant != "simdi":
		for e: Array in [[Vector2i(117, 22), 0], [Vector2i(126, 21), 3], [Vector2i(109, 25), 1]]:
			var sk: Sprite2D = _skeleton(e[0], e[1])
			scene.add_child(sk)
			chars.append(sk)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.make_current()
	DirAccess.make_dir_recursive_absolute(_out)
	for shot: Dictionary in SHOTS:
		var pc: Vector2i = shot["player"]
		player.global_position = _cell_world(pc) + Vector2(0, 7) - Vector2(0, feet_off)
		var anim: AnimatedSprite2D = player.get("anim") as AnimatedSprite2D
		if anim != null and anim.sprite_frames.has_animation("idle_up"):
			anim.play("idle_up")
		cam.global_position = _cell_world(shot["center"])
		for ch: Node2D in chars:
			ch.visible = false
		await _frames(40)
		if dfx != null:
			dfx.call("clear_motes")
			for _k in range(80):
				dfx._process(0.1)
			await _frames(2)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("base_%s.png" % shot["name"]))
		for ch: Node2D in chars:
			ch.visible = true
		await _frames(12)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("char_%s.png" % shot["name"]))
		var xf: Transform2D = root.get_final_transform() * root.get_canvas_transform()
		var o: Vector2 = xf * (_cell_world(Vector2i.ZERO) - Vector2(8, 8))
		var o2: Vector2 = xf * (_cell_world(Vector2i(10, 0)) - Vector2(8, 8))
		var f := FileAccess.open(_out.path_join("meta_%s.txt" % shot["name"]), FileAccess.WRITE)
		f.store_string("%f,%f,%f" % [o.x, o.y, (o2.x - o.x) / 10.0])
		f.close()
		print("SHOT ", _variant, " ", shot["name"], " o=", o, " px/hucre=", (o2.x - o.x) / 10.0)
	quit()
