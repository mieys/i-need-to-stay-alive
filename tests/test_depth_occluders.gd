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
	assert(root_node != null and root_node.z_index == DepthScript.FRONT_Z and DepthScript.FRONT_Z > 2, "kopyalar oyuncuların (z 1) VE öne alınmış yaratıkların (z 2) üstünde, z_index 3")
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


# ------------------------------------------------------------------ yaratıklar (2026-10-09: "yaratıklar ağaçların ve evlerin üstünde yürüyor")

class DeadCreature extends Node2D:
	var is_dead: bool = true


func _creature(pos: Vector2, size: Vector2i = Vector2i(32, 48), dead: bool = false) -> Node2D:
	var e: Node2D = DeadCreature.new() if dead else Node2D.new()
	e.add_to_group("enemies")
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.2, 0.2, 1.0))
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture = ImageTexture.create_from_image(img)
	e.add_child(spr)
	_track(e)
	add_child(e)
	e.global_position = pos
	return e


func _setup_creature_world() -> Array:
	var harita: Node2D = _track(_make_map()) as Node2D
	add_child(harita)
	var dep: Node = DepthScript.new()
	dep.setup(harita)
	var player := Node2D.new()
	player.add_to_group("player")
	player.global_position = Vector2(91, 300)
	_track(player)
	add_child(player)
	dep._process(0.016) ## karakter listesi (kamera yok: görüntü çemberi ilk karakterin çevresi)
	return [harita, dep]


func _material_creature_count(dep: Node) -> int:
	var f: Dictionary = dep.fronts[0]
	return int(((f["front"] as TileMapLayer).material as ShaderMaterial).get_shader_parameter("yaratik_sayisi"))


## Bina A'nın (hücre 5-6 x 8-10, harita kayması (3,7): x 83-115, y 71-183, kök 183) ARKASINDA ve hemen önünde duran yaratıklar kaba ızgarada yakalanır, uzaktakiler yakalanmaz;
## gövde ölçüsü sprite karesinin opak alanından (x1,15 pay) gelir ve değerler her kopya katmanın materyaline yazılır.
func test_creatures_touching_an_object_get_a_mask_entry_and_far_ones_do_not() -> void:
	var w: Array = _setup_creature_world()
	var dep: Node = w[1]
	assert(dep._creatures_on, "nesne hücreleri olan haritada yaratık maskesi açık")
	var behind: Node2D = _creature(Vector2(91, 150)) ## ayak 150 < kök 183: binanın arkasında
	var just_in_front: Node2D = _creature(Vector2(91, 200)) ## ayak 200 > kök 183 ama görseli binaya değiyor (önündeki yaratık da shader'a bildirilir)
	var far_front: Node2D = _creature(Vector2(91, 500)) ## binadan uzak
	var far_side: Node2D = _creature(Vector2(900, 150))
	var dead: Node2D = _creature(Vector2(91, 140), Vector2i(32, 48), true) ## ölüm animasyonu: örtülmez
	assert(far_front != null and far_side != null and just_in_front != null and dead != null)
	dep.update_creatures()
	var entries: Array = dep._creature_entries
	assert(entries.size() == 2, "arkadaki + hemen öndeki yaratık: %s" % str(entries))
	var body: Vector2 = dep.creature_body(behind)
	assert(is_equal_approx(body.x, 16.0 * DepthScript.BODY_MARGIN) and is_equal_approx(body.y, 48.0 * DepthScript.BODY_MARGIN), "gövde = opak alan 32x48 x pay: %s" % str(body))
	var found_behind: bool = false
	for e: Vector4 in entries:
		if is_equal_approx(e.x, 91.0) and is_equal_approx(e.y, 150.0):
			found_behind = true
			assert(is_equal_approx(e.z, body.x) and is_equal_approx(e.w, body.y), "dizi girdisi (ayak x, ayak y, yarım genişlik, boy)")
	assert(found_behind, "arkadaki yaratığın girdisi var")
	for f: Dictionary in dep.fronts:
		var mat := (f["front"] as TileMapLayer).material as ShaderMaterial
		assert(int(mat.get_shader_parameter("yaratik_sayisi")) == 2, "her kopya katman aynı yaratık listesini alır")
		var arr: Array = mat.get_shader_parameter("yaratiklar")
		assert(arr.size() == DepthScript.MAX_CREATURES, "shader dizisi %d uzunlukta" % DepthScript.MAX_CREATURES)
	## yaratık binadan uzaklaşınca girdi kalkar
	behind.global_position = Vector2(700, 150)
	just_in_front.global_position = Vector2(700, 600)
	dep.update_creatures()
	assert(dep._creature_entries.is_empty() and _material_creature_count(dep) == 0, "açık arazide dizi boş (shader döngüsü çalışmaz)")
	dep.free()
	_cleanup()


## 40 yaratık aynı binanın arkasında: shader dizisi MAX_CREATURES ile sınırlı ve görüntü merkezine (karakter) EN YAKIN olanlar kalır.
func test_creature_entries_are_capped_and_keep_the_nearest() -> void:
	var w: Array = _setup_creature_world()
	var dep: Node = w[1]
	for i in range(40):
		_creature(Vector2(86.0 + float(i) * 0.5, 150.0 + float(i) * 0.5)) ## hepsi binaya (y 135-183) değiyor
	dep.update_creatures()
	assert(dep._creature_entries.size() == DepthScript.MAX_CREATURES, "en çok %d girdi: %d" % [DepthScript.MAX_CREATURES, dep._creature_entries.size()])
	assert(_material_creature_count(dep) == DepthScript.MAX_CREATURES)
	## oyuncu (91,300): ayağı en aşağıdaki (y büyük) yaratıklar en yakın - en küçük y'li olanlar elenmiş olmalı
	var min_y: float = 1.0e9
	for e: Vector4 in dep._creature_entries:
		min_y = minf(min_y, e.y)
	assert(min_y >= 150.0 + 8.0 * 0.5 - 0.01, "en uzak 8 yaratık elendi: en küçük ayak y %.1f" % min_y)
	dep.free()
	_cleanup()


## GERÇEK harita: gerçek bir ağacın kökünün hemen ARKASINA konan yaratık maske girdisi alır, kökten çok uzaktaki almaz.
func test_real_map_creature_behind_a_tree_gets_a_mask_entry() -> void:
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
	var tree_front: Dictionary = _front_named(dep, "Ağaç 0")
	var layer: TileMapLayer = tree_front["layer"]
	var bases: Dictionary = tree_front["bases"]
	var pick: Vector2 = Vector2.ZERO
	var base: float = 0.0
	for cell: Vector2i in bases:
		var wp: Vector2 = layer.to_global(layer.map_to_local(cell))
		if absf(float(bases[cell]) - (wp.y + 8.0)) < 3.0:
			pick = wp
			base = float(bases[cell])
			break
	assert(base > 0.0, "gerçek haritada bir ağaç kökü bulundu")
	var player := Node2D.new()
	player.add_to_group("player")
	player.global_position = pick + Vector2(0, 200)
	_track(player)
	add_child(player)
	dep._process(0.016)
	var behind: Node2D = _creature(Vector2(pick.x, base - 10.0))
	dep.update_creatures()
	var hit: bool = false
	for e: Vector4 in dep._creature_entries:
		if is_equal_approx(e.x, pick.x) and is_equal_approx(e.y, base - 10.0):
			hit = true
	assert(hit, "ağacın arkasındaki yaratık shader'a bildirildi: %s" % str(dep._creature_entries))
	behind.global_position = Vector2(pick.x, base + 500.0)
	dep.update_creatures()
	for e: Vector4 in dep._creature_entries:
		assert(not is_equal_approx(e.x, pick.x) or e.y < base + 300.0, "ağaçtan çok uzaktaki yaratık bildirilmedi")
	dep.free()
	tree_sway.free()
	_cleanup()
