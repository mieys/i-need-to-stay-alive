extends Node

## Seyyar satıcı + demirci (binası dahil) GEÇİCİ kapatma (scripts/shops_flag.gd, kullanıcı isteği 2026-10-28). Kapsam: Main'in iki dükkan
## düğümü silinir, demirci binası katmanları haritadan çıkar (ana ev dokunulmadan), binanın engeli (terrain collision) ve ön kopyası kalkar,
## bayrak açıkken hiçbir şey silinmez. Gerçek harita (scenes/harita_baked.tscn) kullanılır.

const ShopsFlag: GDScript = preload("res://scripts/shops_flag.gd")
const TerrainCollisionScript: GDScript = preload("res://scripts/terrain_collision.gd")
const HaritaScene: PackedScene = preload("res://scenes/harita_baked.tscn")

var _spawned: Array[Node] = []
var _saved_enabled: bool = false
var _saved_merchant_enabled: bool = true


func _track(node: Node) -> Node:
	_spawned.append(node)
	return node


func _cleanup() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()
	TerrainCollisionScript.reset()
	ShopsFlag.set_enabled(_saved_enabled)
	ShopsFlag.set_merchant_enabled(_saved_merchant_enabled)


## Main'in yerine geçen kök: iki dükkan düğümü + gerçek harita (main.tscn'deki gibi -2,21 kaymış).
func _make_fake_main() -> Node2D:
	if _spawned.is_empty():
		_saved_enabled = ShopsFlag.enabled
		_saved_merchant_enabled = ShopsFlag.merchant_enabled
	var main := Node2D.new()
	main.name = "FakeMain"
	for node_name: String in ShopsFlag.SHOP_NODES:
		var shop := Node2D.new()
		shop.name = node_name
		main.add_child(shop)
	var harita: Node2D = HaritaScene.instantiate()
	harita.name = "Harita"
	harita.position = Vector2(-2.0, 21.0)
	main.add_child(harita)
	_track(main)
	return main


func _cells_in_box(layer: TileMapLayer) -> int:
	var n: int = 0
	for cell: Vector2i in layer.get_used_cells():
		if ShopsFlag.BUILDING_CELLS.has_point(cell):
			n += 1
	return n


func test_shop_nodes_are_removed_when_disabled() -> void:
	var main: Node2D = _make_fake_main()
	ShopsFlag.set_enabled(false)
	ShopsFlag.set_merchant_enabled(false)
	ShopsFlag.strip_shops(main)
	for node_name: String in ShopsFlag.SHOP_NODES:
		assert(main.get_node_or_null(node_name) == null, "%s silinmeli" % node_name)
	assert(main.get_node_or_null("Harita") != null, "Harita kalmalı")
	_cleanup()


## Madde 431: bayrak ikiye ayrıldı - şu anki ayar (demirci + bina kapalı, seyyar satıcı açık): satıcı düğümü KALIR, demirci gider.
func test_merchant_stays_while_smithy_and_building_are_off() -> void:
	var main: Node2D = _make_fake_main()
	var harita: Node = main.get_node("Harita")
	ShopsFlag.set_enabled(false)
	ShopsFlag.set_merchant_enabled(true)
	ShopsFlag.strip_shops(main)
	assert(main.get_node_or_null(ShopsFlag.MERCHANT_NODE) != null, "seyyar satıcı açıkken silinmemeli")
	assert(main.get_node_or_null(ShopsFlag.SMITHY_NODE) == null, "demirci kapalıyken silinmeli")
	for path: String in ShopsFlag.BUILDING_LAYERS:
		assert(harita.get_node_or_null(path) == null, "%s (demirci binası) silinmeli" % path)
	_cleanup()


## Tersi: yalnız satıcı kapalı -> demirci düğümü ve binası yerinde kalır.
func test_only_merchant_off_keeps_smithy_and_building() -> void:
	var main: Node2D = _make_fake_main()
	var harita: Node = main.get_node("Harita")
	ShopsFlag.set_enabled(true)
	ShopsFlag.set_merchant_enabled(false)
	ShopsFlag.strip_shops(main)
	assert(main.get_node_or_null(ShopsFlag.MERCHANT_NODE) == null, "satıcı kapalıyken silinmeli")
	assert(main.get_node_or_null(ShopsFlag.SMITHY_NODE) != null, "demirci açıkken silinmemeli")
	for path: String in ShopsFlag.BUILDING_LAYERS:
		assert(harita.get_node_or_null(path) != null, "%s açıkken silinmemeli" % path)
	_cleanup()


## Varsayılanlar (kullanıcı kararı 2026-11-06): satıcı açık, demirci kapalı; satıcı bekleme süreleri bir önceki değerin iki katı.
func test_defaults_and_merchant_spawn_pace() -> void:
	assert(ShopsFlag.merchant_enabled and not ShopsFlag.enabled, "varsayılan: satıcı açık, demirci kapalı")
	var m: GDScript = load("res://scripts/traveling_merchant.gd")
	assert(m.COOLDOWN_MIN == 120.0 and m.COOLDOWN_MAX == 120.0, "ziyaret arası 60 -> 120 sn (spawn %50 yavaş)")
	assert(m.INITIAL_DELAY_MIN == 60.0 and m.INITIAL_DELAY_MAX == 180.0, "ilk ziyaret 30-90 -> 60-180 sn")
	assert(m.VISIT_DURATION == 180.0, "kalma süresi aynı")


func test_building_layers_are_removed_and_shared_layers_lose_only_the_building_area() -> void:
	var main: Node2D = _make_fake_main()
	var harita: Node = main.get_node("Harita")
	var before_ev: int = (harita.get_node("ev/Ev") as TileMapLayer).get_used_cells().size()
	var shared_before: Dictionary = {}
	for path: String in ShopsFlag.SHARED_BUILDING_LAYERS:
		var layer := harita.get_node(path) as TileMapLayer
		var total: int = layer.get_used_cells().size()
		var in_box: int = _cells_in_box(layer)
		assert(in_box > 0, "%s bina alanında hücre taşımalı (kapatmadan önce)" % path)
		assert(in_box < total, "%s ana evin hücrelerini de taşıyor olmalı (sadece bina alanı silinecek)" % path)
		shared_before[path] = total - in_box
	for path: String in ShopsFlag.BUILDING_LAYERS:
		assert(harita.get_node_or_null(path) != null, "%s kapatmadan önce var olmalı" % path)
	ShopsFlag.set_enabled(false)
	ShopsFlag.strip_shops(main)
	for path: String in ShopsFlag.BUILDING_LAYERS:
		assert(harita.get_node_or_null(path) == null, "%s silinmeli" % path)
	for path: String in ShopsFlag.SHARED_BUILDING_LAYERS:
		var layer := harita.get_node(path) as TileMapLayer
		assert(_cells_in_box(layer) == 0, "%s bina alanında hücre kalmamalı" % path)
		assert(layer.get_used_cells().size() == int(shared_before[path]), "%s bina alanı dışındaki hücreler aynı kalmalı" % path)
	assert((harita.get_node("ev/Ev") as TileMapLayer).get_used_cells().size() == before_ev, "ana evin duvar katmanına dokunulmamalı")
	assert(harita.get_node_or_null("ev/ev kapı") != null and harita.get_node_or_null("ev/Ev Çatı 1") != null, "ana ev katmanları duruyor")
	_cleanup()


func test_nothing_is_removed_when_enabled() -> void:
	var main: Node2D = _make_fake_main()
	var harita: Node = main.get_node("Harita")
	var cells_before: int = (harita.get_node("ev/Ev Çatı 1") as TileMapLayer).get_used_cells().size()
	ShopsFlag.set_enabled(true)
	ShopsFlag.set_merchant_enabled(true)
	ShopsFlag.strip_shops(main)
	for node_name: String in ShopsFlag.SHOP_NODES:
		assert(main.get_node_or_null(node_name) != null, "%s açıkken silinmemeli" % node_name)
	for path: String in ShopsFlag.BUILDING_LAYERS:
		assert(harita.get_node_or_null(path) != null, "%s açıkken silinmemeli" % path)
	assert((harita.get_node("ev/Ev Çatı 1") as TileMapLayer).get_used_cells().size() == cells_before, "açıkken hücre silinmemeli")
	_cleanup()


## Binanın çarpışması (HOUSE_WALL_LAYERS) kalkmalı: görünmez duvar kalmasın. Ana evin engeli aynı kalır.
func test_building_collision_is_gone_but_main_house_collision_stays() -> void:
	var main: Node2D = _make_fake_main()
	add_child(main)
	var forest := main.get_node("Harita/Orman parçaları/Orman parçaları") as TileMapLayer
	TerrainCollisionScript.reset()
	TerrainCollisionScript.ensure(forest)
	var houses_before: Array = TerrainCollisionScript.by_category.get("houses", [])
	var smithy_before: int = 0
	for gc: Vector2i in houses_before:
		if ShopsFlag.BUILDING_CELLS.has_point(gc):
			smithy_before += 1
	assert(smithy_before > 0, "kapatmadan önce demirci binasının engel hücreleri olmalı")
	var main_house_before: int = houses_before.size() - smithy_before
	assert(main_house_before > 0, "ana evin engel hücreleri olmalı")
	var main2: Node2D = _make_fake_main() ## ikinci örnek: engel tablosu orman katmanının örnek kimliğine bağlı
	ShopsFlag.set_enabled(false)
	ShopsFlag.strip_shops(main2)
	add_child(main2)
	var forest2 := main2.get_node("Harita/Orman parçaları/Orman parçaları") as TileMapLayer
	TerrainCollisionScript.reset()
	TerrainCollisionScript.ensure(forest2)
	var houses_after: Array = TerrainCollisionScript.by_category.get("houses", [])
	var smithy_after: int = 0
	for gc: Vector2i in houses_after:
		if ShopsFlag.BUILDING_CELLS.has_point(gc):
			smithy_after += 1
	assert(smithy_after == 0, "bina kapalıyken alanında ev engeli kalmamalı (kalan: %d)" % smithy_after)
	assert(houses_after.size() == main_house_before, "ana evin engeli aynı kalmalı (%d -> %d)" % [main_house_before, houses_after.size()])
	_cleanup()
