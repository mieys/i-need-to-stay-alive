extends RefCounted

## Testler için: verilen hücrelerin dolu olduğu, gerçek bir TileSet'li TileMapLayer üretir
## (bkz. vision_occluders.gd, test_vision_occluders.gd, test_vision_fog.gd). `parent` altına
## eklenir; çağıran temizlemekten sorumlu (free()).

static func make_layer(parent: Node, cells: Array[Vector2i], layer_pos: Vector2 = Vector2.ZERO) -> TileMapLayer:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(16, 16)
	source.create_tile(Vector2i.ZERO)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	var source_id: int = tile_set.add_source(source)
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	layer.position = layer_pos
	parent.add_child(layer)
	for cell: Vector2i in cells:
		layer.set_cell(cell, source_id, Vector2i.ZERO)
	return layer


## x0..x1, y0..y1 (dahil) dikdörtgenindeki tüm hücreler.
static func rect_cells(x0: int, y0: int, x1: int, y1: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			cells.append(Vector2i(x, y))
	return cells
