extends Node

## DIŞ ÇERÇEVE (2026-10-13, madde 119): harita eski 256x256 oyun alanının DIŞINA geçilmez orman + su çerçevesi aldı (kenarda kamera kilitlenmesin diye).
## GERÇEK baked haritada: iki dikdörtgen (oyun alanı / kamera), çerçevenin her hücresi engel, kamera oyuncu eski kenardayken bile sınıra değmiyor,
## eski oyun alanındaki orman duvarı hücreleri aynen duruyor.

const HaritaScene: PackedScene = preload("res://scenes/harita_baked.tscn")
const TerrainCollisionScript := preload("res://scripts/terrain_collision.gd")
const CameraMapLimitsScript: GDScript = preload("res://scripts/camera_map_limits.gd")

## Masaüstü kamerası: tuval 1920x1080, zoom 2,0 (player.tscn; DESKTOP_CAMERA_CLOSER 1,0) -> yarı görüş 480x270 px. Oyuncu eski kenardan MAP_EDGE_INSET (16 px) içeride durur.
const HALF_VIEW := Vector2(480.0, 270.0)
const PLAYER_INSET := 16.0

var _main: Node2D = null
var _harita: Node2D = null


func _load_map() -> void:
	_main = Node2D.new()
	_main.name = "TestMain"
	_harita = HaritaScene.instantiate()
	_harita.name = "Harita"
	_harita.position = Vector2(-2.0, 21.0) ## gerçek oyundaki konum (main.tscn)
	_main.add_child(_harita)
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	GameManager._terrain_layers_searched = false
	GameManager._map_world_rect_searched = false
	TerrainCollisionScript.reset()


func _unload_map() -> void:
	if is_instance_valid(_main):
		_main.free()
	_main = null
	_harita = null
	get_tree().current_scene = null
	GameManager._terrain_su_layer = null
	GameManager._terrain_ev_layer = null
	GameManager._terrain_forest_layer = null
	GameManager._terrain_layers_searched = false
	GameManager._map_world_rect_searched = false
	TerrainCollisionScript.reset()


func test_two_rects_play_area_and_camera() -> void:
	_load_map()
	var play: Rect2 = GameManager.get_map_world_rect()
	var cam: Rect2 = GameManager.get_camera_world_rect()
	assert(play.position.is_equal_approx(Vector2(-2.0, 21.0)) and play.size.is_equal_approx(Vector2(4096.0, 4096.0)), "oyun alani eski 256x256 hucre olmali: %s" % str(play))
	assert(cam.position.is_equal_approx(Vector2(-514.0, -299.0)), "kamera dikdortgeni sol-ust: %s" % str(cam.position))
	assert(cam.size.is_equal_approx(Vector2(5120.0, 4736.0)), "kamera dikdortgeni boyut: %s" % str(cam.size))
	assert(cam.encloses(play))
	_unload_map()


func test_camera_never_reaches_limit_while_player_is_inside_play_area() -> void:
	_load_map()
	var play: Rect2 = GameManager.get_map_world_rect().grow(-PLAYER_INSET) ## oyuncunun gidebildigi en uc
	var cam: Rect2 = GameManager.get_camera_world_rect()
	assert(play.position.x - HALF_VIEW.x >= cam.position.x, "sol: kamera sinira degerdi")
	assert(play.end.x + HALF_VIEW.x <= cam.end.x, "sag: kamera sinira degerdi")
	assert(play.position.y - HALF_VIEW.y >= cam.position.y, "ust: kamera sinira degerdi")
	assert(play.end.y + HALF_VIEW.y <= cam.end.y, "alt: kamera sinira degerdi")
	_unload_map()


func test_every_frame_cell_blocks_and_play_walls_unchanged() -> void:
	_load_map()
	var forest: TileMapLayer = _harita.get_node("Orman parçaları/Orman parçaları")
	var play := Rect2i(0, 0, 256, 256)
	var ring_total := 0
	var ring_blocked := 0
	var open_cells: Array[Vector2i] = []
	var rect: Rect2i = forest.get_used_rect()
	assert(rect.position == Vector2i(-32, -20) and rect.size == Vector2i(320, 296), "orman katmani alani: %s" % str(rect))
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if play.has_point(Vector2i(x, y)):
				continue
			ring_total += 1
			if forest.get_cell_source_id(Vector2i(x, y)) != -1:
				ring_blocked += 1
			else:
				open_cells.append(Vector2i(x, y))
	## KASITLI açıklık (madde 122, Tiled'da doğu kenarı duvarı silindi): vadi köprüsünün sağ ucu - halkanın ilk sütunu x=256, y=98..114
	## (17 hücre) boş; ötesi (x >= 257) dolu, yani sadece 1 hücrelik çıkmaz cep. Başka hiçbir halka hücresi boş olmamalı.
	var known_gap: Array[Vector2i] = []
	for gy in range(98, 115):
		known_gap.append(Vector2i(256, gy))
	assert(ring_total == 320 * 296 - 256 * 256 and open_cells == known_gap, "halka hucreleri engel degil: %d/%d, bos: %s" % [ring_blocked, ring_total, str(open_cells.slice(0, 20))])
	var in_play := 0
	for c: Vector2i in forest.get_used_cells():
		if play.has_point(c):
			in_play += 1
	assert(in_play == 5447, "eski oyun alanindaki orman duvari hucre sayisi degismemeli (5510 -> 5447: doğu kenarı açıklığı, madde 122): %d" % in_play)
	## oyunun kendi sorgusu: halkada engel, haritanin ortasindaki acik cimende degil
	for p: Vector2 in [Vector2(-300.0, 2000.0), Vector2(4350.0, 2000.0), Vector2(2000.0, -150.0), Vector2(2000.0, 4350.0), Vector2(-100.0, -100.0), Vector2(4200.0, 4300.0)]:
		assert(GameManager.is_position_blocked_by_walls(p), "halka engel olmali: %s" % str(p))
	_unload_map()


func test_camera_limits_use_camera_rect() -> void:
	_load_map()
	var limits: Node = CameraMapLimitsScript.new()
	_main.add_child(limits)
	var cam := Camera2D.new()
	_main.add_child(cam)
	cam.global_position = Vector2(100.0, 100.0)
	cam.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	var r: Rect2 = GameManager.get_camera_world_rect()
	assert(cam.limit_left == int(floor(r.position.x)) and cam.limit_top == int(floor(r.position.y)), "kamera limiti cerceve dahil dikdortgen olmali")
	assert(cam.limit_right == int(ceil(r.end.x)) and cam.limit_bottom == int(ceil(r.end.y)))
	assert(cam.limit_left < GameManager.get_map_world_rect().position.x, "limit eski kenarin DISINDA olmali")
	_unload_map()
