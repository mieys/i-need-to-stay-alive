extends Node

## Kullanıcı isteği doğrulaması: "orman parçaları layerı ... görüş alanını da
## kısıtlayacak, bunun ardındaki hiçbir şeyi görememeliyiz" - bkz.
## scripts/vision_occluders.gd. Bu testler CPU tarafındaki ışın kuralını doğrular
## (GLSL karşılığı vision_fog_mask.gdshader ray_blocked() AYNI kuralı uygular ve
## gerçek renderer'da ekran görüntüsüyle kontrol edilir):
##  - duvarın ARKASI görünmez, ÖNÜ ve duvarın KENDİ yüzü görünür (kalınlığı önemsiz),
##  - duvardaki boşluktan görüş geçer,
##  - kaynağın kendi karosu yok sayılır,
##  - katman kaydırılmış (harita sahnede (-2,21)'de) olsa da dünya konumları doğru.

const VisionOccludersScript: GDScript = preload("res://scripts/vision_occluders.gd")
const WallLayerFactory: GDScript = preload("res://tests/wall_layer_factory.gd")

const CELL := 16.0

var _spawned: Array[Node] = []


func _layer(cells: Array[Vector2i], pos: Vector2 = Vector2.ZERO) -> TileMapLayer:
	var layer: TileMapLayer = WallLayerFactory.make_layer(self, cells, pos)
	_spawned.append(layer)
	return layer


func _occluders(layer: TileMapLayer) -> RefCounted:
	var occ: RefCounted = VisionOccludersScript.new()
	occ.build(layer)
	return occ


## Hücre koordinatı (kesirli, ör. 10.5 = karonun ortası) -> dünya konumu.
func _world(layer: TileMapLayer, cell_pos: Vector2) -> Vector2:
	return layer.to_global(cell_pos * CELL)


func _cleanup() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func test_empty_or_null_layer_blocks_nothing() -> void:
	var occ: RefCounted = VisionOccludersScript.new()
	occ.build(null)
	assert(occ.is_empty(), "null katmandan boş ızgara beklenirdi")
	assert(not occ.is_ray_blocked(Vector2.ZERO, Vector2(500.0, 500.0)), "Boş ızgara ışını engelledi")
	assert(occ.make_texture() == null, "Boş ızgara texture üretmemeli")

	var empty_layer: TileMapLayer = _layer([])
	var occ2: RefCounted = _occluders(empty_layer)
	assert(occ2.is_empty(), "Hücresiz katmandan boş ızgara beklenirdi")
	assert(not occ2.is_ray_blocked(Vector2.ZERO, Vector2(500.0, 500.0)), "Hücresiz katman ışını engelledi")
	_cleanup()


func test_blocks_cell_matches_painted_cells_with_layer_offset() -> void:
	## Ana harita main.tscn'de (-2, 21)'e kaydırılmış: dünya konumları katman dönüşümüne göre olmalı.
	var offset := Vector2(-2.0, 21.0)
	var layer: TileMapLayer = _layer(WallLayerFactory.rect_cells(5, 7, 9, 7), offset)
	var occ: RefCounted = _occluders(layer)
	assert(occ.blocks_world_pos(_world(layer, Vector2(7.5, 7.5))), "Boyalı hücre engel sayılmadı")
	assert(occ.blocks_world_pos(_world(layer, Vector2(5.1, 7.9))), "Boyalı hücrenin köşesi engel sayılmadı")
	assert(not occ.blocks_world_pos(_world(layer, Vector2(7.5, 6.5))), "Üstteki boş hücre engel sayıldı")
	assert(not occ.blocks_world_pos(_world(layer, Vector2(10.5, 7.5))), "Yandaki boş hücre engel sayıldı")
	assert(not occ.blocks_world_pos(Vector2(100000.0, 100000.0)), "Izgara dışı engel sayıldı")
	assert(is_equal_approx(occ.get_cell_size(), CELL), "Karo boyu 16 olmalı: %s" % occ.get_cell_size())
	assert(occ.get_world_origin().is_equal_approx(offset), "Izgara kökeni katman konumu olmalı: %s" % occ.get_world_origin())
	_cleanup()


func test_thin_wall_hides_behind_but_not_front_or_face() -> void:
	var layer: TileMapLayer = _layer(WallLayerFactory.rect_cells(0, 10, 20, 10))
	var occ: RefCounted = _occluders(layer)
	var source: Vector2 = _world(layer, Vector2(10.5, 12.5))
	assert(occ.is_ray_blocked(source, _world(layer, Vector2(10.5, 8.5))), "Duvarın ARKASI görünür kaldı")
	assert(occ.is_ray_blocked(source, _world(layer, Vector2(10.5, 5.5))), "Duvarın uzak arkası görünür kaldı")
	assert(not occ.is_ray_blocked(source, _world(layer, Vector2(10.5, 14.5))), "Duvarın ÖNÜ (kaynağın arkası) engellendi")
	assert(not occ.is_ray_blocked(source, _world(layer, Vector2(10.5, 11.5))), "Duvarın önündeki açık hücre engellendi")
	assert(not occ.is_ray_blocked(source, _world(layer, Vector2(10.5, 10.5))), "Duvarın KENDİ yüzü engellendi (duvar görünür kalmalı)")
	_cleanup()


func test_thick_wall_is_fully_visible_only_the_back_is_hidden() -> void:
	## 3 karo kalınlığında duvar (saçak + kaya + kaya): TÜM kalınlığı görünür, ardı görünmez.
	var layer: TileMapLayer = _layer(WallLayerFactory.rect_cells(0, 10, 20, 12))
	var occ: RefCounted = _occluders(layer)
	var source: Vector2 = _world(layer, Vector2(10.5, 14.5))
	for y: float in [12.5, 11.5, 10.5]:
		assert(not occ.is_ray_blocked(source, _world(layer, Vector2(10.5, y))), "Kalın duvarın y=%.1f satırı engellendi" % y)
	assert(occ.is_ray_blocked(source, _world(layer, Vector2(10.5, 9.5))), "Kalın duvarın hemen arkası görünür kaldı")
	assert(occ.is_ray_blocked(source, _world(layer, Vector2(10.5, 5.5))), "Kalın duvarın uzak arkası görünür kaldı")
	_cleanup()


func test_gap_in_wall_lets_sight_through() -> void:
	var cells: Array[Vector2i] = WallLayerFactory.rect_cells(0, 10, 9, 10)
	cells.append_array(WallLayerFactory.rect_cells(11, 10, 20, 10))
	var layer: TileMapLayer = _layer(cells)
	var occ: RefCounted = _occluders(layer)
	assert(not occ.is_ray_blocked(_world(layer, Vector2(10.5, 12.5)), _world(layer, Vector2(10.5, 8.5))),
		"Duvardaki boşluktan görüş geçmeliydi")
	assert(occ.is_ray_blocked(_world(layer, Vector2(8.5, 12.5)), _world(layer, Vector2(8.5, 8.5))),
		"Boşluğun yanındaki duvar görüşü kesmeliydi")
	_cleanup()


func test_far_wall_face_at_grazing_angle_stays_visible() -> void:
	## Duvarın boyunca uzağa, sığ açıyla bakmak: yüzü (duvarın kendisi) hâlâ görünür olmalı.
	var layer: TileMapLayer = _layer(WallLayerFactory.rect_cells(0, 10, 40, 10))
	var occ: RefCounted = _occluders(layer)
	var source: Vector2 = _world(layer, Vector2(2.5, 12.5))
	assert(not occ.is_ray_blocked(source, _world(layer, Vector2(18.5, 10.5))), "Uzaktaki duvar yüzü sığ açıda karardı")
	assert(not occ.is_ray_blocked(source, _world(layer, Vector2(30.5, 10.5))), "Çok uzaktaki duvar yüzü sığ açıda karardı")
	_cleanup()


func test_sources_own_cell_is_ignored() -> void:
	var layer: TileMapLayer = _layer(WallLayerFactory.rect_cells(0, 10, 20, 10))
	var occ: RefCounted = _occluders(layer)
	## Kaynak duvar karosunun İÇİNDE (ör. sınırda ezilmiş konum): kendi karosu yok sayılır,
	## açık tarafa bakış engellenmez.
	var source: Vector2 = _world(layer, Vector2(10.5, 10.5))
	assert(not occ.is_ray_blocked(source, _world(layer, Vector2(10.5, 8.5))), "Kaynağın kendi karosu görüşü kesti")
	assert(not occ.is_ray_blocked(source, _world(layer, Vector2(10.5, 13.5))), "Kaynağın kendi karosu görüşü kesti (ön taraf)")
	_cleanup()


func test_same_cell_and_zero_length_rays_are_never_blocked() -> void:
	var layer: TileMapLayer = _layer(WallLayerFactory.rect_cells(0, 10, 20, 10))
	var occ: RefCounted = _occluders(layer)
	var p: Vector2 = _world(layer, Vector2(10.5, 12.5))
	assert(not occ.is_ray_blocked(p, p), "Sıfır uzunluklu ışın engellendi")
	assert(not occ.is_ray_blocked(p, p + Vector2(3.0, 2.0)), "Aynı karo içindeki ışın engellendi")
	_cleanup()


func test_ray_direction_all_octants_behind_thin_wall() -> void:
	## Yatay/dikey/çapraz, her yönden bir duvarın arkası kesilmeli (DDA işaret hataları için).
	var layer: TileMapLayer = _layer(WallLayerFactory.rect_cells(10, 10, 10, 10)) ## tek karo
	var occ: RefCounted = _occluders(layer)
	var center: Vector2 = _world(layer, Vector2(10.5, 10.5))
	var dirs: Array[Vector2] = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
	for dir: Vector2 in dirs:
		var near_side: Vector2 = center - dir.normalized() * 3.0 * CELL
		var far_side: Vector2 = center + dir.normalized() * 3.0 * CELL
		assert(occ.is_ray_blocked(near_side, far_side), "Tek karonun arkası kesilmedi, yön %s" % str(dir))
		assert(not occ.is_ray_blocked(near_side, center), "Tek karonun yüzü engellendi, yön %s" % str(dir))
	_cleanup()


func test_grazing_a_wall_corner_does_not_block_but_crossing_the_body_does() -> void:
	## Kullanıcı bildirimi: "duvarda çok keskin çizgiler var, anormal gözüküyor" - basamaklı
	## duvar kenarındaki tek karoluk çıkıntının KÖŞESİNE sürtünen ışın görüşü kesmemeli.
	var layer: TileMapLayer = _layer([Vector2i(10, 10)])
	var occ: RefCounted = _occluders(layer)
	## Işın (10,10) karosunun sağ-üst köşesinden içeri girip hemen çıkıyor (~0.28 karo yol).
	var graze_from: Vector2 = _world(layer, Vector2(9.0, 12.8))
	var graze_to: Vector2 = _world(layer, Vector2(13.0, 8.8))
	assert(not occ.is_ray_blocked(graze_from, graze_to), "Duvar köşesine sürtünen ışın görüşü kesti")
	## Aynı karonun ortasından geçen ışın (1 karo yol) hâlâ keser.
	assert(occ.is_ray_blocked(_world(layer, Vector2(8.5, 10.5)), _world(layer, Vector2(13.5, 10.5))),
		"Duvar gövdesinin ortasından geçen ışın görüşü kesmedi")
	assert(VisionOccludersScript.MIN_WALL_CROSSING > 0.0 and VisionOccludersScript.MIN_WALL_CROSSING <= 1.0,
		"MIN_WALL_CROSSING 1 karolık duvarı da kesebilecek kadar küçük, köşe sürtünmesini eleyecek kadar büyük olmalı")
	_cleanup()


func test_small_clusters_are_filtered_only_when_asked() -> void:
	var cells: Array[Vector2i] = WallLayerFactory.rect_cells(0, 10, 20, 10) ## 21 hücrelik uzun duvar
	cells.append_array(WallLayerFactory.rect_cells(5, 20, 7, 22)) ## 3x3 = 9 hücrelik dekor
	cells.append(Vector2i(30, 30)) ## tek hücre
	## Köşegen zincir: 8 komşulukla TEK küme sayılmalı (12 hücre).
	for i: int in range(12):
		cells.append(Vector2i(40 + i, 40 + i))
	var layer: TileMapLayer = _layer(cells)

	var all_cells: RefCounted = VisionOccludersScript.new()
	all_cells.build(layer)
	var filtered: RefCounted = VisionOccludersScript.new()
	filtered.build(layer, 10)

	var blob_source: Vector2 = _world(layer, Vector2(6.5, 24.5))
	var blob_behind: Vector2 = _world(layer, Vector2(6.5, 18.5))
	assert(all_cells.is_ray_blocked(blob_source, blob_behind), "Filtresiz ızgara dekorun arkasını kesmeliydi")
	assert(not filtered.is_ray_blocked(blob_source, blob_behind), "Küçük dekor (9 hücre) filtreyle görüşü kesmemeli")
	assert(not filtered.blocks_cell(Vector2i(30, 30)), "Tek hücre filtreyle engel olmamalı")
	assert(filtered.blocks_cell(Vector2i(10, 10)), "Uzun duvar filtreyle de engel kalmalı")
	assert(filtered.is_ray_blocked(_world(layer, Vector2(10.5, 12.5)), _world(layer, Vector2(10.5, 8.5))),
		"Uzun duvar filtreyle de görüşü kesmeli")
	assert(filtered.blocks_cell(Vector2i(45, 45)), "Köşegen zincir 8 komşulukla tek küme sayılıp korunmalıydı")
	assert(filtered.blocks_cell(Vector2i(6, 21)) == false, "Dekorun hücresi filtreyle engel olmamalı")
	## Hepsi elenirse ızgara boş.
	var none: RefCounted = VisionOccludersScript.new()
	none.build(_layer([Vector2i(1, 1), Vector2i(50, 50)]), 5)
	assert(none.is_empty(), "Tüm kümeler elenince ızgara boş olmalı")
	_cleanup()


func test_texture_matches_grid() -> void:
	var cells: Array[Vector2i] = WallLayerFactory.rect_cells(3, 4, 6, 4)
	cells.append(Vector2i(20, 30))
	var layer: TileMapLayer = _layer(cells)
	var occ: RefCounted = _occluders(layer)
	var texture: ImageTexture = occ.make_texture()
	assert(texture != null, "Dolu ızgara texture üretmeli")
	assert(Vector2i(texture.get_size()) == occ.get_grid_size(), "Texture boyu ızgara boyuna eşit olmalı: %s / %s" % [texture.get_size(), occ.get_grid_size()])
	assert(occ.make_texture() == texture, "Texture bir kere üretilip önbelleğe alınmalı")
	var image: Image = texture.get_image()
	var origin: Vector2i = occ.get_grid_origin()
	var filled := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var has_pixel: bool = image.get_pixel(x, y).r > 0.5
			assert(has_pixel == occ.blocks_cell(origin + Vector2i(x, y)), "Texture ile blocks_cell uyuşmuyor: (%d,%d)" % [x, y])
			if has_pixel:
				filled += 1
	assert(filled == cells.size(), "Texture'daki dolu texel sayısı hücre sayısına eşit olmalı: %d / %d" % [filled, cells.size()])
	_cleanup()
