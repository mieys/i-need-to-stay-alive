extends Node

## Kullanıcı bildirimi: "evden çıkınca eski konumundan çıkıyor, evin konumu
## değişti" - house_interior.gd eskiden dışarıdaki evin konumunu SABİT
## koordinatlarla (3032,1912 / 3016,1950) tutuyordu; ev Tiled'da taşınınca (şimdi
## x:[1854,2030] y:[1237,1365]) giriş tetikleyicisi ve oyun başı dönüş noktası eski
## yerde kaldı. Artık ikisi de haritadaki "ev/Ev" katmanından çözülüyor.
##
## Testler sabit YENİ koordinatlara bağlanmıyor (ev yine taşınırsa bayatlamasın):
## gerçek haritada "giriş evin dolu bir hücresinde ve alt kenarında, eski evin
## yerinde DEĞİL" gibi özellikleri, sentetik haritada ise ev nereye konursa oraya
## uyulduğunu doğruluyorlar.

const HouseInteriorScript: GDScript = preload("res://scripts/house_interior.gd")
const HaritaScene: PackedScene = preload("res://scenes/harita_baked.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const WallLayerFactory: GDScript = preload("res://tests/wall_layer_factory.gd")

## Eski (artık yanlış) sabit konum - yeni giriş buradan çok uzak olmalı.
const OLD_ENTRANCE_POS := Vector2(3032.0, 1912.0)

var _spawned: Array[Node] = []


func _track(node: Node) -> Node:
	_spawned.append(node)
	return node


func _cleanup() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


## Gerçek haritayı main.tscn'deki gibi (-2,21) kaydırıp yanına HouseInterior koyar.
func _make_real_world() -> Node2D:
	var harita: Node2D = HaritaScene.instantiate()
	harita.name = "Harita"
	harita.position = Vector2(-2.0, 21.0)
	add_child(harita)
	_track(harita)
	var house: Node2D = HouseInteriorScript.new()
	house.name = "HouseInterior"
	add_child(house)
	_track(house)
	return house


func test_entrance_follows_the_house_layer_on_the_real_map() -> void:
	var house: Node2D = _make_real_world()
	var ev: TileMapLayer = get_node("Harita/ev/Ev")
	var entrance: Vector2 = house.get("_exterior_entrance_pos")
	var cell: Vector2i = ev.local_to_map(ev.to_local(entrance))
	assert(ev.get_cell_source_id(cell) != -1, "Giriş evin dolu bir hücresinde olmalı: %s" % str(cell))
	assert(ev.get_cell_source_id(cell + Vector2i(0, 1)) == -1, "Giriş evin ALT (güney) kenarındaki hücre olmalı")
	assert(entrance.distance_to(OLD_ENTRANCE_POS) > 500.0,
		"Giriş hâlâ eski evin yerinde (%s) - ev taşındı" % str(entrance))
	assert(house.get("_entrance_area").position == entrance, "Giriş tetikleyicisi çözülen konumda olmalı")
	_cleanup()


func test_safe_return_is_free_south_of_the_house_and_inside_entrance_radius() -> void:
	var house: Node2D = _make_real_world()
	var entrance: Vector2 = house.get("_exterior_entrance_pos")
	var safe: Vector2 = house.get("_exterior_safe_return_pos")
	assert(safe.y > entrance.y, "Güvenli dönüş noktası evin güneyinde olmalı: %s / %s" % [str(safe), str(entrance)])
	assert(safe.distance_to(entrance) <= HouseInteriorScript.EXTERIOR_ENTRANCE_RADIUS,
		"Güvenli dönüş noktası giriş yarıçapı içinde kalmalı: %s" % str(safe.distance_to(entrance)))
	for path: String in ["Harita/ev/Ev", "Harita/Su/Su", "Harita/Orman parçaları/Orman parçaları"]:
		var layer: TileMapLayer = get_node(path)
		assert(layer.get_cell_source_id(layer.local_to_map(layer.to_local(safe))) == -1,
			"Güvenli dönüş noktası %s katmanında dolu bir hücreye denk geliyor" % path)
	_cleanup()


## Oyun başında oyuncu otomatik eve alınır; dışarı çıkınca YENİ evin güneyine düşmeli.
func test_exit_after_game_start_lands_at_the_new_house() -> void:
	GameManager.selected_char_id = 1
	GameManager.selected_character = 1
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_track(player)
	var house: Node2D = _make_real_world()
	assert(bool(player.get("is_indoors")), "Oyun başında oyuncu evin içinde olmalı")
	house._do_exit_house()
	assert(not bool(player.get("is_indoors")), "Çıkınca is_indoors false olmalı")
	var pos: Vector2 = player.global_position
	assert(pos.distance_to(house.get("_exterior_entrance_pos")) <= HouseInteriorScript.EXTERIOR_ENTRANCE_RADIUS,
		"Oyuncu yeni evin girişinin yakınında çıkmalı, çıktığı yer: %s" % str(pos))
	assert(pos.distance_to(OLD_ENTRANCE_POS) > 500.0, "Oyuncu eski evin yerinde çıktı: %s" % str(pos))
	_cleanup()


## Ev bir daha taşınırsa (sentetik harita) kod değişikliği gerekmeden takip etmeli;
## ev dışında kalmış tek tük artık karo yok sayılmalı.
func test_entrance_follows_a_moved_house_and_ignores_stray_cells() -> void:
	var harita := Node2D.new()
	harita.name = "Harita"
	harita.position = Vector2(-2.0, 21.0)
	add_child(harita)
	_track(harita)
	var ev_group := Node2D.new()
	ev_group.name = "ev"
	harita.add_child(ev_group)
	var cells: Array[Vector2i] = WallLayerFactory.rect_cells(40, 30, 50, 37) ## 11x8 ev
	cells.append(Vector2i(90, 90)) ## geride kalmış tek karo
	var layer: TileMapLayer = WallLayerFactory.make_layer(ev_group, cells)
	layer.name = "Ev"
	var house: Node2D = HouseInteriorScript.new()
	house.name = "HouseInterior"
	add_child(house)
	_track(house)
	## Evin alt sırası y=37, orta hücre x=45 -> hücre merkezi + harita kayması
	var expected: Vector2 = harita.to_global(Vector2(45.0 * 16.0 + 8.0, 37.0 * 16.0 + 8.0))
	assert(house.get("_exterior_entrance_pos").is_equal_approx(expected),
		"Giriş taşınan evin alt-orta hücresinde olmalı: %s / beklenen %s" % [str(house.get("_exterior_entrance_pos")), str(expected)])
	assert(house.get("_exterior_safe_return_pos").y > expected.y, "Güvenli dönüş taşınan evin güneyinde olmalı")
	_cleanup()


func test_without_a_map_the_fallback_positions_are_used() -> void:
	var house: Node2D = HouseInteriorScript.new()
	add_child(house)
	_track(house)
	assert(house.get("_exterior_entrance_pos") == HouseInteriorScript.FALLBACK_EXTERIOR_ENTRANCE_POS,
		"Harita yokken giriş için yedek konum kullanılmalı")
	assert(house.get("_exterior_safe_return_pos") == HouseInteriorScript.FALLBACK_EXTERIOR_SAFE_RETURN_POS,
		"Harita yokken dönüş için yedek konum kullanılmalı")
	_cleanup()
