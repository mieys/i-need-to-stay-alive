extends RefCounted

## MADEN BÖLGELERİ + KAZMA ÖDÜLÜ + DAYANIKLILIK (kullanıcı isteği 2026-10-14): "oyunun sol ve sağ köşelerinde madenler var; yakınına gelen oyuncu otomatik maden
## toplama (kazma) animasyonuyla toplar, her vuruşta altın kazanır, gri madenler daha çok verir" + "madenlerin dayanıklılığı olup bir süre sonra kırılsın,
## zaman geçince tekrar spawn olsun".
## Bu dosya SADECE hesap + durum verisi: harita katmanlarından (terrain_collision.gd MINE_LAYERS = "Etkileşimler/Maden" + "Maden 1") maden nesnelerini bulur, her
## birinin türünü (bakır/gri), dayanıklılığını, karolarını ve collision hücrelerini tutar, bir noktaya en yakın (kırık olmayan) madeni verir. Kazma durumu/animasyonu/
## altın player.gd `_process_mining`'de; kırılma/yeniden doğma/ağ senkronu/görsel mine_world.gd'de (host karar verir, herkes uygular).
##
## Nesne = madenin opak karolarının 8-komşu bağlı bileşeni (iki katmanın birleşimi; büyük kristal + yanındaki küçükler tek maden sayılır). Sıra: sol-üstten
## (bounds.position.x, y) - İNDEKS ağ üzerinden maden kimliği olarak kullanılır, her istemcide AYNI harita => aynı sıra.
## Tür = karoların ortalama rengi: mavi bileşen > kırmızı bileşen -> GRİ-MAVİ kristal ("gri maden", sağ köşe), değilse BAKIR (turuncu, sol köşe).
## Tuzak: harita Tiled'da değişip yeniden bake edilince kendiliğinden güncellenir (karo piksellerinden okunur); ama tür renkten çıkar - yeni bir maden
## karosu (ör. yeşil) eklenirse `_is_gray` kuralına bakılmalı.

const TerrainCollisionScript := preload("res://scripts/terrain_collision.gd")
const DepthScript := preload("res://scripts/depth_occluders.gd")

## --- DENGE (kullanıcı ayarlar) ---
const GOLD_PER_HIT_COPPER := 5
const GOLD_PER_HIT_GRAY := 10
## Dayanıklılık = madenin opak karo sayısı x HITS_PER_CELL (en az MIN_HITS vuruş): büyük kristal küçüğünden çok dayanır. Tüm oyuncuların vuruşları ortak sayılır.
const HITS_PER_CELL := 1.5
const MIN_HITS := 8
## Kırılan maden bu kadar saniye sonra yeniden doğar (üstünde/yanında oyuncu varken beklenir, bkz. mine_world.gd). Duraklatmada (level atlama ekranı) sayım durur.
const RESPAWN_SECONDS := 120.0
## Karaktere göre ayak noktasından madenin opak karosuna en çok bu kadar (dünya px) uzaklıktayken kazılır.
const REACH := 18.0
## Karoda en az bu kadar opak piksel yoksa (köşedeki boş/gölge karoları) o karo madenin parçası sayılmaz.
const MIN_OPAQUE_PIXELS := 12
## Collision hücresi (orman ızgarası) bir madene bu mesafeden (dünya px) yakınsa o madenin ayak izi sayılır.
const COLLISION_ASSIGN_DISTANCE := 24.0

static var _layer_id: int = 0
## Her eleman (sözlük):
##  "index": int - ağ kimliği | "cells": Array[Rect2] (opak karoların dünya dikdörtgenleri) | "gray": bool | "bounds": Rect2
##  "tiles": Array[Dictionary] - madenin TÜM karoları (opak olmayan gölge karoları dahil): {"layer", "cell", "sid", "atlas", "alt"} (kırılınca silinir, doğunca geri konur)
##  "gcs": Array[Vector2i] - madenin collision hücreleri (TerrainCollision orman ızgarası)
##  "max_hits": int | "hp": int (sadece host/tek oyunculuda anlamlı) | "broken": bool | "respawn_left": float (host)
static var sites: Array = []


static func reset() -> void:
	_layer_id = 0
	sites = []


## Orman katmanına göre madenleri (bir kez) hesaplar; harita yoksa boş liste.
static func ensure(forest: TileMapLayer) -> Array:
	if forest == null or not is_instance_valid(forest):
		return []
	var id: int = forest.get_instance_id()
	if id != _layer_id:
		_build(forest)
	return sites


## feet noktasına REACH içindeki EN YAKIN KIRIK OLMAYAN maden: {"site": Dictionary, "point": Vector2 (madenin en yakın noktası), "dist": float}; yoksa boş sözlük.
static func nearest(forest: TileMapLayer, feet: Vector2, reach: float = REACH) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = reach
	for site: Dictionary in ensure(forest):
		if bool(site["broken"]):
			continue
		var bounds: Rect2 = site["bounds"]
		if not bounds.grow(reach).has_point(feet):
			continue
		for r: Rect2 in site["cells"]:
			var p := Vector2(clampf(feet.x, r.position.x, r.end.x), clampf(feet.y, r.position.y, r.end.y))
			var d: float = feet.distance_to(p)
			if d <= best_d:
				best_d = d
				best = {"site": site, "point": p, "dist": d}
	return best


static func gold_per_hit(site: Dictionary) -> int:
	return GOLD_PER_HIT_GRAY if bool(site.get("gray", false)) else GOLD_PER_HIT_COPPER


static func _build(forest: TileMapLayer) -> void:
	_layer_id = forest.get_instance_id()
	sites = []
	var harita: Node = TerrainCollisionScript._find_harita(forest)
	if harita == null:
		return
	var helper: Node = DepthScript.new() ## sahneye eklenmez: sadece saf hesap işlevleri (terrain_collision.gd ile aynı desen)
	var layers: Array[TileMapLayer] = []
	## hücre (Vector2i) -> [karo dünya dikdörtgeni, gri mi]; katmanlar birleşik (üst katman aynı hücreyi tekrar yazmaz)
	var cells: Dictionary = {}
	for path: String in TerrainCollisionScript.MINE_LAYERS:
		var layer := harita.get_node_or_null(path) as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		layers.append(layer)
		var origin: Vector2 = helper.cell_origin(layer)
		var cell_size: Vector2 = Vector2(layer.tile_set.tile_size)
		var image_cache: Dictionary = {}
		for cell: Vector2i in layer.get_used_cells():
			if cells.has(cell):
				continue
			if helper.opaque_pixels(layer, cell, 0, 15).size() < MIN_OPAQUE_PIXELS:
				continue
			var rect := Rect2(origin + Vector2(cell) * cell_size, cell_size)
			cells[cell] = [rect, _is_gray(layer, cell, image_cache)]
	var g0: Vector2 = helper.cell_origin(forest)
	helper.free()
	var seen: Dictionary = {}
	var comps: Array = [] ## [{"rects", "gray", "bounds", "keys": Array[Vector2i]}]
	for start: Vector2i in cells:
		if seen.has(start):
			continue
		var stack: Array[Vector2i] = [start]
		seen[start] = true
		var rects: Array[Rect2] = []
		var keys: Array[Vector2i] = []
		var gray_votes: int = 0
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			var info: Array = cells[c]
			rects.append(info[0])
			keys.append(c)
			if bool(info[1]):
				gray_votes += 1
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var n := Vector2i(c.x + dx, c.y + dy)
					if cells.has(n) and not seen.has(n):
						seen[n] = true
						stack.append(n)
		var bounds: Rect2 = rects[0]
		for r in rects:
			bounds = bounds.merge(r)
		comps.append({"rects": rects, "gray": gray_votes * 2 > rects.size(), "bounds": bounds, "keys": keys})
	comps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: Vector2 = (a["bounds"] as Rect2).position
		var pb: Vector2 = (b["bounds"] as Rect2).position
		return pa.x < pb.x or (pa.x == pb.x and pa.y < pb.y))
	var cell_site: Dictionary = {} ## opak hücre -> maden indeksi
	for i in range(comps.size()):
		var comp: Dictionary = comps[i]
		var max_hits: int = maxi(MIN_HITS, roundi(float((comp["rects"] as Array).size()) * HITS_PER_CELL))
		sites.append({
			"index": i, "cells": comp["rects"], "gray": comp["gray"], "bounds": comp["bounds"], "tiles": [], "gcs": [],
			"max_hits": max_hits, "hp": max_hits, "broken": false, "respawn_left": 0.0,
		})
		for k: Vector2i in comp["keys"]:
			cell_site[k] = i
	## Madenin TÜM karoları: kendi opak hücreleri + onlara bitişik (8 komşu) opak olmayan karolar (gölge/kenar parçaları) - kırılınca hepsi silinir.
	for layer: TileMapLayer in layers:
		for cell: Vector2i in layer.get_used_cells():
			var idx: int = int(cell_site.get(cell, -1))
			if idx < 0:
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						if idx < 0 and cell_site.has(Vector2i(cell.x + dx, cell.y + dy)):
							idx = int(cell_site[Vector2i(cell.x + dx, cell.y + dy)])
			if idx < 0:
				continue
			(sites[idx]["tiles"] as Array).append({
				"layer": layer, "cell": cell, "sid": layer.get_cell_source_id(cell),
				"atlas": layer.get_cell_atlas_coords(cell), "alt": layer.get_cell_alternative_tile(cell),
			})
	## Collision hücreleri (orman ızgarası): her hücre en yakın madene (COLLISION_ASSIGN_DISTANCE içinde) atanır.
	TerrainCollisionScript.ensure(forest)
	for gc: Vector2i in TerrainCollisionScript.by_category.get("mines", []):
		var grect := Rect2(g0 + Vector2(gc) * 16.0, Vector2(16.0, 16.0))
		var best_i: int = -1
		var best_d: float = COLLISION_ASSIGN_DISTANCE
		for s: Dictionary in sites:
			var b: Rect2 = s["bounds"]
			var d: float = _rect_distance(grect, b)
			if d <= best_d:
				best_d = d
				best_i = int(s["index"])
		if best_i >= 0:
			(sites[best_i]["gcs"] as Array).append(gc)


static func _rect_distance(a: Rect2, b: Rect2) -> float:
	var dx: float = maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy: float = maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return sqrt(dx * dx + dy * dy)


## Karonun opak piksellerinin ortalama rengi mavimsi mi (gri-mavi kristal) yoksa turuncu/bakır mı.
static func _is_gray(layer: TileMapLayer, cell: Vector2i, image_cache: Dictionary) -> bool:
	var sid: int = layer.get_cell_source_id(cell)
	var src := layer.tile_set.get_source(sid) as TileSetAtlasSource
	if src == null or src.texture == null:
		return false
	if not image_cache.has(sid):
		var loaded: Image = src.texture.get_image()
		if loaded != null and loaded.is_compressed():
			loaded.decompress()
		image_cache[sid] = loaded
	var img: Image = image_cache[sid]
	if img == null:
		return false
	var region: Rect2i = src.get_tile_texture_region(layer.get_cell_atlas_coords(cell))
	var red: float = 0.0
	var blue: float = 0.0
	var n: int = 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var col: Color = img.get_pixel(x, y)
			if col.a > 0.8:
				red += col.r
				blue += col.b
				n += 1
	return n > 0 and blue > red
