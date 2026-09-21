extends Node

## Kamera haritanın dışını göstermesin (kullanıcı isteği 2026-09-21): GameManager.get_map_world_rect()
## karolardan doğru dünya dikdörtgenini bulmalı, CameraMapLimits kamerayı o dikdörtgene kilitlemeli,
## ev içi gibi haritadan çok uzak bir konumda limiti kaldırmalı.

const CameraMapLimitsScript: GDScript = preload("res://scripts/camera_map_limits.gd")


func _make_layer(cells: Array, pos: Vector2 = Vector2.ZERO) -> TileMapLayer:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(16, 16)
	src.create_tile(Vector2i(0, 0))
	ts.add_source(src, 0)
	var layer := TileMapLayer.new()
	layer.tile_set = ts
	layer.position = pos
	for c in cells:
		layer.set_cell(c, 0, Vector2i(0, 0))
	return layer


func _make_main() -> Node2D:
	var main := Node2D.new()
	main.name = "TestMain"
	var harita := Node2D.new()
	harita.name = "Harita"
	harita.position = Vector2(-2, 21) ## gerçek main.tscn'deki Harita kayması
	main.add_child(harita)
	var group := Node2D.new()
	harita.add_child(group)
	group.add_child(_make_layer([Vector2i(0, 0), Vector2i(3, 2)]))
	group.add_child(_make_layer([Vector2i(1, 1), Vector2i(9, 4)]))
	group.add_child(_make_layer([])) ## boş katman sayılmamalı
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	GameManager._map_world_rect_searched = false
	GameManager._map_world_rect = Rect2()
	return main


func test_map_world_rect_is_union_of_layers_with_offset() -> void:
	var main := _make_main()
	await get_tree().process_frame
	var rect: Rect2 = GameManager.get_map_world_rect()
	## hücre (0,0) sol-üst = (-2,21)+(0,0); hücre (9,4) sağ-alt = (-2,21)+(10*16, 5*16)
	assert(rect.position.is_equal_approx(Vector2(-2, 21)), "sol-ust: %s" % rect.position)
	assert(rect.end.is_equal_approx(Vector2(158, 101)), "sag-alt: %s" % rect.end)
	main.queue_free()
	get_tree().current_scene = null
	GameManager._map_world_rect_searched = false


func test_no_map_returns_empty_and_is_not_cached() -> void:
	GameManager._map_world_rect_searched = false
	get_tree().current_scene = null
	assert(GameManager.get_map_world_rect().size == Vector2.ZERO)
	assert(not GameManager._map_world_rect_searched, "harita yokken sonuc onbellege alinmamali")


func test_apply_limits_static() -> void:
	var cam := Camera2D.new()
	CameraMapLimitsScript.apply_limits(cam, Rect2(-2, 21, 4096, 4096))
	assert(cam.limit_left == -2 and cam.limit_top == 21)
	assert(cam.limit_right == 4094 and cam.limit_bottom == 4117)
	CameraMapLimitsScript.apply_limits(cam, Rect2())
	assert(cam.limit_left == -CameraMapLimitsScript.NO_LIMIT and cam.limit_right == CameraMapLimitsScript.NO_LIMIT)
	cam.free()


func test_limits_follow_camera_position_inside_and_house_interior() -> void:
	var main := _make_main()
	var limits: Node = CameraMapLimitsScript.new()
	main.add_child(limits)
	var cam := Camera2D.new()
	main.add_child(cam)
	cam.global_position = Vector2(60, 50)
	cam.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(cam.limit_left == -2 and cam.limit_top == 21, "harita ustunde limit kilitli olmali")
	assert(cam.limit_right == 158 and cam.limit_bottom == 101)
	## Ev ici (haritadan 20000 birim uzakta): limit kalkmali
	cam.global_position = Vector2(20160, 200)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(cam.limit_left == -CameraMapLimitsScript.NO_LIMIT, "ev icinde limit kalkmali")
	assert(cam.limit_right == CameraMapLimitsScript.NO_LIMIT)
	## Eve dis dunyaya geri donunce yine kilitlenmeli
	cam.global_position = Vector2(80, 60)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(cam.limit_left == -2 and cam.limit_bottom == 101, "disari cikinca limit geri gelmeli")
	main.queue_free()
	get_tree().current_scene = null
	GameManager._map_world_rect_searched = false
