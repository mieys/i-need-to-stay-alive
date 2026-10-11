extends Node

## Geniş çalılar rüzgarda karo sınırlarından bölünmesin (2026-10-09, bkz. grass_sway.gd _write_cell_data + sallanan ot.gdshader):
## atlasta bitişik karolar tek bitki grubu - ortak faz/kök/boy, komşu bitleri; tek karo ve dikey ot eskisi gibi (faz 0).
## Shader'ın kendisi ekransızda derlenmez; gerçek renderer'da eski/yeni karşılaştırmalı ekran görüntüsüyle doğrulandı.

const GrassSwayScript: GDScript = preload("res://scripts/grass_sway.gd")

var _spawned: Array[Node] = []


func _layer(cells: Array, atlas: Array, flips: Array = []) -> TileMapLayer:
	var image := Image.create(16 * 6, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.7, 0.2, 1.0))
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(16, 16)
	for x in 6:
		for y in 2:
			source.create_tile(Vector2i(x, y))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	var sid: int = tile_set.add_source(source)
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	add_child(layer)
	_spawned.append(layer)
	for i in cells.size():
		layer.set_cell(cells[i], sid, atlas[i])
	return layer


func _data(layer: TileMapLayer) -> Array:
	var gs: Node = GrassSwayScript.new()
	_spawned.append(gs)
	var mat := ShaderMaterial.new()
	var st: Dictionary = gs._write_cell_data(mat, layer)
	return [st["data"], st["rect"]]


func _px(d: Array, cell: Vector2i) -> Array:
	var img: Image = d[0]
	var p: Vector2i = cell - (d[1] as Rect2i).position
	var c: Color = img.get_pixel(p.x, p.y)
	return [roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0), roundi(c.a * 255.0)]


func _cleanup() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func test_atlas_adjacent_tiles_share_phase_root_and_neighbor_bits() -> void:
	var layer: TileMapLayer = _layer([Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(12, 5)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(4, 0)])
	var d: Array = _data(layer)
	var a: Array = _px(d, Vector2i(5, 5))
	var b: Array = _px(d, Vector2i(6, 5))
	var c: Array = _px(d, Vector2i(7, 5))
	var single: Array = _px(d, Vector2i(12, 5))
	assert(a[2] > 0 and a[2] == b[2] and b[2] == c[2], "Geniş çalının karoları aynı fazı almalı: %s %s %s" % [a, b, c])
	assert(a[3] == 2 and b[3] == 3 and c[3] == 1, "Komşu bitleri (sağda / iki yanda / solda) yanlış: %d %d %d" % [a[3], b[3], c[3]])
	assert(a[0] == b[0] and b[0] == c[0] and a[1] == b[1], "Aynı satırdaki karolar aynı kök/boyu almalı")
	assert(single[2] == 0 and single[3] == 0, "Tek karolu ot eski yolda kalmalı (faz 0, komşu yok): %s" % str(single))
	_cleanup()


func test_two_row_wide_bush_is_one_group_with_a_common_root() -> void:
	var layer: TileMapLayer = _layer([Vector2i(5, 4), Vector2i(6, 4), Vector2i(5, 5), Vector2i(6, 5)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])
	var d: Array = _data(layer)
	var top_l: Array = _px(d, Vector2i(5, 4))
	var top_r: Array = _px(d, Vector2i(6, 4))
	var bot_l: Array = _px(d, Vector2i(5, 5))
	assert(top_l[2] > 0 and top_l[2] == top_r[2] and top_l[2] == bot_l[2], "İki satırlı çalı TEK grup olmalı (faz eşit)")
	assert(top_l[0] == top_r[0] and top_l[0] == bot_l[0] + 16, "Üst satırın kökü alt satırın 16 px aşağısında: %s / %s" % [top_l, bot_l])
	_cleanup()


func test_generic_links_group_non_atlas_adjacent_tiles_and_touch_bends_whole_group() -> void:
	## Çiçekler (2026-10-11): haritada yan yana ama atlasta yan yana OLMAYAN karolar da (piksel devamı varsa) tek bitki; dokunma tüm grubu eğer.
	var layer: TileMapLayer = _layer([Vector2i(5, 5), Vector2i(6, 5)], [Vector2i(1, 0), Vector2i(4, 1)])
	var gs: Node = GrassSwayScript.new()
	_spawned.append(gs)
	var plain: Dictionary = gs._write_cell_data(ShaderMaterial.new(), layer, false)
	var linked: Dictionary = gs._write_cell_data(ShaderMaterial.new(), layer, true)
	assert((plain["rep_of"] as Dictionary).is_empty(), "Atlas komşusu olmayan karolar eski yolda ayrı bitki")
	var rep_of: Dictionary = linked["rep_of"]
	assert(rep_of.size() == 2 and rep_of.values()[0] == rep_of.values()[1], "Haritada bitişik + piksel devamlı karolar tek grup olmalı: %s" % str(rep_of))
	var nb: Image = (linked["data"] as Image) # veri dokusu da yazıldı
	assert(nb != null)
	var rect: Rect2i = linked["rect"]
	var feet: Vector2 = (linked["ofset"] as Vector2) + Vector2(5.0 * 16.0 + 14.0, 5.0 * 16.0 + 12.0)
	for i in 6:
		gs._update_touch(linked, [[feet, Vector2(60.0, 0.0)]], 0.016)
	var bend: Image = linked["bend_img"]
	var p0: Vector2i = Vector2i(5, 5) - rect.position
	var p1: Vector2i = Vector2i(6, 5) - rect.position
	assert(bend.get_pixel(p0.x, p0.y).r != 128.0 / 255.0, "Dokunulan karo eğilmeli")
	assert(is_equal_approx(bend.get_pixel(p0.x, p0.y).r, bend.get_pixel(p1.x, p1.y).r), "Grubun komşu karosu AYNI eğilmeyi almalı (bölünme olmasın)")
	_cleanup()
