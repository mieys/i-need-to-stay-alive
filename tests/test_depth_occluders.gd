extends Node

## Derinlik ön katmanları (y-sıralama) - kullanıcı isteği (2026-10-08): "bir şeyin arkasındayken karakter onun altında, önündeyken üstünde görünsün".
## Kapsam: nesne kökü (yere değdiği çizgi) hesabı - ağaç/bina/maden/çalı, bina çatı+duvarın TEK kök paylaşması, kopya katmanların kurulumu, karakter
## uniform'larının güncellenmesi, ağaç kopyasının sallanma gücünü asıldan alması. Pikselin gerçekten örtülüp örtülmediği GPU'da çözülür - o kısım
## gerçek pencereli ekran görüntüsüyle (scratchpad shot_depth*.gd) doğrulandı, burada yok.

const DepthScript := preload("res://scripts/depth_occluders.gd")
const TreeSwayScript := preload("res://scripts/tree_sway.gd")

var _spawned: Array = []


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


## 2x2 atlas: (0,0)/(1,0) tamamen opak, (0,1)/(1,1) sadece ilk 10 satır opak (son opak satır 9).
func _make_tileset() -> TileSet:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):
			var opaque: bool = y < 16 or (y - 16) < 10
			img.set_pixel(x, y, Color(0.6, 0.4, 0.2, 1.0) if opaque else Color(0, 0, 0, 0))
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(16, 16)
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		src.create_tile(c)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_source(src, 0)
	return ts


func _layer(parent: Node, name: String, ts: TileSet, cells: Dictionary) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = name
	l.tile_set = ts
	for c: Vector2i in cells:
		l.set_cell(c, 0, cells[c])
	parent.add_child(l)
	return l


func _make_map() -> Node2D:
	var ts: TileSet = _make_tileset()
	var harita := Node2D.new()
	harita.name = "Harita"
	harita.position = Vector2(3, 7)
	var ev := Node2D.new()
	ev.name = "ev"
	harita.add_child(ev)
	## Bina A: duvar (5,10),(6,10) tam karo, çatı (5..6, 8..9) tam karo - çatı duvara bitişik. Bina B: uzakta (30,30), kısa karo (son opak satır 9).
	_layer(ev, "Ev", ts, {Vector2i(5, 10): Vector2i(0, 0), Vector2i(6, 10): Vector2i(1, 0)})
	_layer(ev, "Ev Çatı 1", ts, {Vector2i(5, 8): Vector2i(0, 0), Vector2i(6, 8): Vector2i(1, 0), Vector2i(5, 9): Vector2i(0, 0), Vector2i(6, 9): Vector2i(1, 0),
		Vector2i(30, 30): Vector2i(0, 1)})
	var et := Node2D.new()
	et.name = "Etkileşimler"
	harita.add_child(et)
	## Maden: (0,0) atlas'ın 2x2 bloğu tek nesne (kök = alt satırın son opak satırı); (10,5)'teki tek karo ayrı nesne.
	_layer(et, "Maden", ts, {Vector2i(0, 0): Vector2i(0, 0), Vector2i(1, 0): Vector2i(1, 0), Vector2i(0, 1): Vector2i(0, 1), Vector2i(1, 1): Vector2i(1, 1),
		Vector2i(10, 5): Vector2i(0, 1)})
	return harita


func _base_of(f: Dictionary, cell: Vector2i) -> float:
	return float((f["bases"] as Dictionary).get(cell, -1.0))


func _front_named(dep: Node, layer_name: String) -> Dictionary:
	for f: Dictionary in dep.fronts:
		if String((f["layer"] as Node).name) == layer_name:
			return f
	return {}


func test_buildings_share_one_root_per_building_across_layers() -> void:
	var harita: Node2D = _track(_make_map()) as Node2D
	add_child(harita)
	var dep: Node = DepthScript.new()
	dep.setup(harita)
	var wall: Dictionary = _front_named(dep, "Ev")
	var roof: Dictionary = _front_named(dep, "Ev Çatı 1")
	assert(not wall.is_empty() and not roof.is_empty(), "bina katmanlarının kopyaları kurulmalı")
	## Duvarın alt kenarı: harita y'si 7 + hücre 10 * 16 + tam karo (16) = 183.
	assert(is_equal_approx(_base_of(wall, Vector2i(5, 10)), 7.0 + 160.0 + 16.0), "duvar kökü: %s" % str(_base_of(wall, Vector2i(5, 10))))
	assert(is_equal_approx(_base_of(roof, Vector2i(5, 8)), _base_of(wall, Vector2i(5, 10))), "ÇATI duvarla AYNI kökü paylaşmalı (kafa/gövde farklı yönde örtülmesin)")
	assert(is_equal_approx(_base_of(roof, Vector2i(6, 9)), _base_of(wall, Vector2i(6, 10))))
	## Uzak ikinci bina kendi kökünü alır: 7 + 30*16 + (son opak satır 9 + 1) = 497.
	assert(is_equal_approx(_base_of(roof, Vector2i(30, 30)), 7.0 + 480.0 + 10.0), "ikinci bina kendi kökü: %s" % str(_base_of(roof, Vector2i(30, 30))))
	dep.free()
	_cleanup()


func test_object_layers_split_objects_by_atlas_adjacency() -> void:
	var harita: Node2D = _track(_make_map()) as Node2D
	add_child(harita)
	var dep: Node = DepthScript.new()
	dep.setup(harita)
	var mine: Dictionary = _front_named(dep, "Maden")
	assert(not mine.is_empty(), "Maden kopyası")
	## 2x2 blok: alt satır atlas (0,1)/(1,1) -> son opak satır 9 -> kök = 7 + 1*16 + 10 = 33; üstteki hücre de AYNI nesne.
	var base_block: float = 7.0 + 16.0 + 10.0
	assert(is_equal_approx(_base_of(mine, Vector2i(0, 1)), base_block) and is_equal_approx(_base_of(mine, Vector2i(1, 1)), base_block), "blok alt satırı")
	assert(is_equal_approx(_base_of(mine, Vector2i(0, 0)), base_block) and is_equal_approx(_base_of(mine, Vector2i(1, 0)), base_block), "bloğun üst satırı AYNI kökü paylaşır")
	var lone: float = 7.0 + 5.0 * 16.0 + 10.0
	assert(is_equal_approx(_base_of(mine, Vector2i(10, 5)), lone), "ayrı nesne kendi kökü: %s" % str(_base_of(mine, Vector2i(10, 5))))
	dep.free()
	_cleanup()


func test_front_copies_sit_above_players_and_match_the_original_transform() -> void:
	var harita: Node2D = _track(_make_map()) as Node2D
	add_child(harita)
	var dep: Node = DepthScript.new()
	dep.setup(harita)
	var root_node: Node2D = harita.get_node("DerinlikOnKatman") as Node2D
	assert(root_node != null and root_node.z_index == 2, "kopyalar oyuncuların (z 1) üstünde, z_index 2")
	assert(dep.fronts.size() == 3, "Ev + Ev Çatı + Maden: %d" % dep.fronts.size())
	for f: Dictionary in dep.fronts:
		var layer: TileMapLayer = f["layer"]
		var front: TileMapLayer = f["front"]
		assert(front.get_parent() == root_node)
		assert(front.global_position.is_equal_approx(layer.global_position), "kopya asılla aynı konumda")
		assert(front.get_used_cells().size() == layer.get_used_cells().size(), "kopyada aynı hücreler")
		var mat := front.material as ShaderMaterial
		assert(mat != null and mat.shader.resource_path == DepthScript.SHADER_PATH, "kopya derinlik shader'ıyla çizilir")
		assert(mat.get_shader_parameter("hucre_ofset") == Vector2(3, 7), "hücre (0,0)'ın dünya sol-üstü: %s" % str(mat.get_shader_parameter("hucre_ofset")))
		layer.visible = false
		assert(not front.visible, "asıl gizlenince kopya da gizlenir")
		layer.visible = true
	dep.free()
	_cleanup()


func test_characters_are_pushed_to_every_front_material() -> void:
	var harita: Node2D = _track(_make_map()) as Node2D
	add_child(harita)
	var dep: Node = DepthScript.new()
	dep.setup(harita)
	var player := Node2D.new()
	player.add_to_group("player")
	player.global_position = Vector2(100, 200)
	_track(player)
	add_child(player)
	var other := Node2D.new()
	other.add_to_group("remote_players")
	other.global_position = Vector2(300, 400)
	_track(other)
	add_child(other)
	var dead := Node2D.new()
	dead.add_to_group("remote_players")
	dead.global_position = Vector2(500, 500)
	dead.visible = false ## görünmeyen (ölü/gizli) kukla sayılmaz
	_track(dead)
	add_child(dead)
	dep._process(0.016)
	for f: Dictionary in dep.fronts:
		var mat := (f["front"] as TileMapLayer).material as ShaderMaterial
		assert(int(mat.get_shader_parameter("karakter_sayisi")) == 2, "yerel + uzak oyuncu: %s" % str(mat.get_shader_parameter("karakter_sayisi")))
		var arr: Array = mat.get_shader_parameter("karakterler")
		assert(arr.size() == 8, "shader dizisi 8 uzunlukta")
		assert(arr[0] == Vector4(100, 200 + DepthScript.FEET_OFFSET, DepthScript.BODY_HALF_WIDTH, DepthScript.BODY_HEIGHT), "ayak/gövde: %s" % str(arr[0]))
		assert(arr[1] == Vector4(300, 400 + DepthScript.FEET_OFFSET, DepthScript.BODY_HALF_WIDTH, DepthScript.BODY_HEIGHT))
	player.global_position = Vector2(150, 260)
	dep._process(0.016)
	var arr2: Array = ((dep.fronts[0]["front"] as TileMapLayer).material as ShaderMaterial).get_shader_parameter("karakterler")
	assert(arr2[0].x == 150.0 and arr2[0].y == 260.0 + DepthScript.FEET_OFFSET, "oyuncu hareket edince güncellenir")
	dep.free()
	_cleanup()


## GERÇEK harita: ağaç + bina + maden + çalı kopyaları kurulur; Blacksmith ve ev çatıları duvarlarıyla aynı kökü paylaşır; ağaç kopyası asılla
## aynı hücre verisini kullanır ve sallanma gücünü (rüzgar) asıldan alır.
func test_real_map_front_layers_roots_and_tree_sway_sync() -> void:
	var main := Node2D.new()
	main.name = "Main"
	_track(main)
	add_child(main)
	var harita: Node = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	harita.name = "Harita"
	main.add_child(harita)
	var tree_sway: Node = TreeSwayScript.new()
	tree_sway.setup(harita)
	var dep: Node = DepthScript.new()
	dep.setup(harita)
	var modes: Dictionary = {}
	for f: Dictionary in dep.fronts:
		modes[f["mode"]] = int(modes.get(f["mode"], 0)) + 1
	assert(int(modes.get("tree", 0)) == 3, "Ağaç 0/1/2 kopyaları: %s" % str(modes))
	assert(int(modes.get("building", 0)) == 6, "bina katmanları (Blacksmith, kapı, ayrıntı, Ev, ev kapı, çatı): %s" % str(modes))
	assert(int(modes.get("object", 0)) >= 3, "maden/çalı/üs nesne katmanları: %s" % str(modes))
	## Blacksmith: çatı ve duvar hücrelerinin tümü TEK kök (iki bina var: Blacksmith + ev; çatı katmanında iki farklı değer olabilir ama duvarlarla eşleşmeli).
	var wall_bases: Dictionary = {}
	for name in ["Blacksmith", "blacksmith kapı", "Ev", "ev kapı"]:
		var f: Dictionary = _front_named(dep, name)
		assert(not f.is_empty(), "%s kopyası bulunamadı" % name)
		for c in (f["bases"] as Dictionary):
			wall_bases[int(round(float(f["bases"][c])))] = true
	var roof: Dictionary = _front_named(dep, "Ev Çatı 1")
	for c in (roof["bases"] as Dictionary):
		assert(wall_bases.has(int(round(float(roof["bases"][c])))), "çatı kökü hiçbir duvar köküyle eşleşmiyor: %s" % str(roof["bases"][c]))
	for f: Dictionary in dep.fronts:
		if f["mode"] != "tree":
			continue
		var src_mat := (f["layer"] as TileMapLayer).material as ShaderMaterial
		var front_mat := (f["front"] as TileMapLayer).material as ShaderMaterial
		assert(front_mat.get_shader_parameter("on_katman") == true and src_mat.get_shader_parameter("on_katman") != true, "sadece kopya on_katman")
		assert(front_mat.get_shader_parameter("veri") == src_mat.get_shader_parameter("veri"), "ağaç kopyası asılla aynı hücre verisini kullanmalı")
	var first_tree: Dictionary = _front_named(dep, "Ağaç 0")
	((first_tree["layer"] as TileMapLayer).material as ShaderMaterial).set_shader_parameter("strength", 3.25)
	dep._process(0.016)
	assert(float(((first_tree["front"] as TileMapLayer).material as ShaderMaterial).get_shader_parameter("strength")) == 3.25, "sallanma gücü asıldan kopyaya taşınmalı")
	dep.free()
	tree_sway.free()
	_cleanup()
