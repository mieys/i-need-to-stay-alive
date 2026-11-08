extends Node

## HARİTA SEÇİMİ 1. adım (madde 444): profil kaydı, seçim önceliği, Main'deki harita değişimi. Ana harita seçiliyken HİÇBİR şey değişmemeli.

const MapProfiles: GDScript = preload("res://scripts/map_profiles.gd")
const ALT := "kadim_derinlikler"
const DD := preload("res://scripts/dungeon/dungeon_data.gd")


func _set_map(id: String) -> void:
	GameManager.selected_map = id


func _fake_main() -> Node:
	var main := Node2D.new()
	main.name = "TestMain"
	for nm: String in ["Once", "Harita", "Sonra"]:
		var n := Node2D.new()
		n.name = nm
		main.add_child(n)
	return main


func test_default_is_main_map() -> void:
	_set_map("ana")
	if OS.get_environment("HARITA") != "":
		return ## ortam değişkeni ezer (geliştirme), bu testi koşturan ortamda olmamalı
	assert(MapProfiles.current_id() == "ana")
	assert(MapProfiles.is_main_map())
	assert(MapProfiles.feature("orman_gorselleri"))
	assert(MapProfiles.feature("ev_acilisi"))
	assert(MapProfiles.feature("tanimsiz_bayrak")) ## tanımsız bayrak ana haritada açık
	assert(MapProfiles.preload_paths().is_empty())


func test_invalid_selection_falls_back_to_main() -> void:
	_set_map("yok_boyle_harita")
	if OS.get_environment("HARITA") == "":
		assert(MapProfiles.current_id() == "ana")
	_set_map("ana")


func test_alternative_profile_flags_and_files() -> void:
	if OS.get_environment("HARITA") != "":
		return
	_set_map(ALT)
	assert(MapProfiles.current_id() == ALT)
	assert(not MapProfiles.is_main_map())
	assert(not MapProfiles.feature("orman_gorselleri"))
	assert(not MapProfiles.feature("tanimsiz_bayrak")) ## tanımsız bayrak diğer haritalarda kapalı
	var paths: Array = MapProfiles.preload_paths()
	assert(paths.size() == 2)
	for p: String in paths:
		assert(ResourceLoader.exists(p))
	assert(not MapProfiles.is_selectable(ALT) and MapProfiles.is_selectable("ana")) ## madde 445: karışık harita seçimden kalktı
	assert(MapProfiles.selectable_ids() == ["ana", "batik_nekropol", "taskin_hisar", "lagim_agi"]) ## madde 449: Batık Nekropol, Kemik Katakombu'nun yerine
	_set_map("ana")


func test_install_keeps_main_map_untouched() -> void:
	if OS.get_environment("HARITA") != "":
		return
	_set_map("ana")
	var main: Node = _fake_main()
	var before: Node = main.get_node("Harita")
	assert(not MapProfiles.install(main))
	assert(main.get_node("Harita") == before)
	assert(before.get_index() == 1)
	main.free()


func test_install_swaps_map_in_place() -> void:
	if OS.get_environment("HARITA") != "":
		return
	_set_map(ALT)
	var main: Node = _fake_main()
	assert(MapProfiles.install(main))
	var h: Node = main.get_node("Harita")
	assert(h.get_index() == 1) ## çizim sırası korunur
	assert(h.scene_file_path == str(MapProfiles.get_profile(ALT)["sahne"]))
	assert(main.get_child_count() == 3)
	assert(h.find_children("*", "TileMapLayer", true, false).size() >= 8)
	main.free()
	_set_map("ana")


## 2. adım: zindan haritası görünmez duvar katmanı (= orman katmanı yolu), doğuş zeminde, kapalı bayrakların düğümleri kaldırılır.
func test_dungeon_map_wall_layer_spawn_and_stripped_nodes() -> void:
	if OS.get_environment("HARITA") != "":
		return
	_set_map(ALT)
	var main: Node = _fake_main()
	for nm: String in ["HouseInterior", "TravelingMerchant", "WorldEventManager", "EnemySpawner"]:
		var n := Node2D.new()
		n.name = nm
		main.add_child(n)
	assert(MapProfiles.install(main))
	var layer: TileMapLayer = main.get_node("Harita/" + MapProfiles.WALL_LAYER_PARENT + "/" + MapProfiles.WALL_LAYER_NAME)
	assert(layer != null and not layer.visible)
	var d: Resource = MapProfiles.data()
	var walls: int = 0
	for c: int in d.cells:
		if c == DD.CELL_WALL:
			walls += 1
	assert(layer.get_used_cells().size() == walls)
	var sp: Vector2 = MapProfiles.spawn_position()
	assert(sp != Vector2.INF)
	var cell := Vector2i(int(sp.x / 16.0), int(sp.y / 16.0))
	assert(d.cell_at(cell) == DD.CELL_EMPTY) ## doğuş yürünür zeminde
	assert(layer.get_cell_source_id(cell) == -1)
	assert(layer.get_cell_source_id(Vector2i(0, 0)) != -1) ## harita kenarı kaya
	for nm: String in ["HouseInterior", "TravelingMerchant", "WorldEventManager"]:
		assert(main.get_node_or_null(nm) == null)
	assert(main.get_node_or_null("EnemySpawner") != null)
	main.free()
	_set_map("ana")


## Zindan kaydı: zindan haritasında haritanın nesne/saklanma hücreleri köken (0,0)'da, zindan listesi boş; ana haritada da zindan YOK (madde 463).
func test_dungeon_world_registers_map_cells() -> void:
	if OS.get_environment("HARITA") != "":
		return
	var DW: GDScript = load("res://scripts/dungeon/dungeon_world.gd")
	DW.set("test_origin_px", Vector2.ZERO)
	_set_map(ALT)
	DW.call("reset")
	assert(DW.call("ensure"))
	assert((DW.call("dungeons") as Array).is_empty())
	var d: Resource = MapProfiles.data()
	var solid := Vector2i(-1, -1)
	var hide := Vector2i(-1, -1)
	for i in range(d.cells.size()):
		if d.cells[i] == DD.CELL_SOLID and solid.x < 0:
			solid = Vector2i(i % d.size.x, i / d.size.x)
		if d.cells[i] == DD.CELL_HIDE and hide.x < 0:
			hide = Vector2i(i % d.size.x, i / d.size.x)
	assert(solid.x >= 0 and bool(DW.call("is_move_blocked_cell", solid)))
	assert(hide.x >= 0 and bool(DW.call("is_hide_world", (Vector2(hide) + Vector2(0.5, 0.5)) * 16.0)))
	_set_map("ana")
	DW.call("reset")
	assert(DW.call("ensure"))
	assert((DW.call("dungeons") as Array).is_empty() and (DW.call("map_entry") as Dictionary).is_empty())
	assert(not MapProfiles.feature("zindan_etkilesim"))
	DW.call("reset")
	DW.set("test_origin_px", null)
