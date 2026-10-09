extends Node

## Köprü katı (2026-10-09, kullanıcı: "buranın altından geçen insanların üstünde köprü görünmeli ... soldaki dağdan insanlar bu köprüden geçebilmeli").
## Kapsam: bridge_deck.gd saf mantığı (dikdörtgen bileşenleri, hangi kenardan girildi, durum makinesi) + depth_occluders.gd köprü kurulumu (kopya
## katmanlar, yaratık/kaba ızgaradan hariç, karakter listesi SADECE zemin katındakilere gider, uzaktaki karakter listeye girmez) + gerçek haritada
## köprünün sağ ucundaki görünmez duvarın açıldığı. Pikselin GPU'da gerçekten örtülmesi (kopya shader'ı) mevcut derinlik testleriyle aynı yol, burada yok.

const DepthScript := preload("res://scripts/depth_occluders.gd")
const DeckScript := preload("res://scripts/bridge_deck.gd")

var _spawned: Array = []


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


## Köprü dikdörtgeni: x 100..300, y 200..232 (200x32), yatay.
func _rect() -> Rect2:
	return Rect2(100, 200, 200, 32)


func test_component_rects_merge_adjacent_cells_and_split_far_ones() -> void:
	var cells: Dictionary = {}
	for x in range(6, 12):
		cells[Vector2i(x, 20)] = Vector2(x * 16.0, 320.0)
		cells[Vector2i(x, 21)] = Vector2(x * 16.0, 336.0)
	cells[Vector2i(40, 3)] = Vector2(640.0, 48.0)
	var rects: Array[Rect2] = DeckScript.component_rects(cells, 16.0)
	assert(rects.size() == 2, "iki ayrı köprü: %d" % rects.size())
	var big: Rect2 = rects[0] if rects[0].size.x > 20.0 else rects[1]
	assert(big.is_equal_approx(Rect2(96, 320, 96, 32)), "6x2 hücre: %s" % str(big))


func test_entry_side_decides_deck_or_under() -> void:
	var r: Rect2 = _rect()
	assert(DeckScript.entered_from_end(Vector2(90, 216), r), "soldan (yamaçtan) gelen -> güverte")
	assert(DeckScript.entered_from_end(Vector2(310, 216), r), "sağdan gelen -> güverte")
	assert(not DeckScript.entered_from_end(Vector2(200, 190), r), "kuzeyden (vadi zemini) -> altından")
	assert(not DeckScript.entered_from_end(Vector2(200, 240), r), "güneyden -> altından")
	## Köşe: uç taşması yan taşmadan küçükse yan sayılır.
	assert(not DeckScript.entered_from_end(Vector2(95, 150), r), "köşeden ama kuzeye uzak -> altından")
	assert(DeckScript.entered_from_end(Vector2(60, 195), r), "köşeden ama uca uzak -> güverte")
	## Dikey köprüde eksenler döner.
	var tall := Rect2(100, 200, 32, 200)
	assert(DeckScript.entered_from_end(Vector2(116, 190), tall), "dikey köprü: üst uçtan -> güverte")
	assert(not DeckScript.entered_from_end(Vector2(90, 300), tall), "dikey köprü: yandan -> altından")


func test_state_machine_walk_across_vs_walk_under() -> void:
	var rects: Array = [_rect()]
	## Soldaki yamaçtan köprüye çık, karşıya geç.
	var st: Dictionary = {}
	st = DeckScript.step_state(st, Vector2(90, 216), rects)
	assert(not st["deck"] and st["idx"] == -1, "dışarıda güverte değil")
	st = DeckScript.step_state(st, Vector2(102, 216), rects)
	assert(st["deck"], "uçtan girdi -> güvertede")
	for x in range(110, 290, 10):
		st = DeckScript.step_state(st, Vector2(x, 216), rects)
		assert(st["deck"], "güvertede yürürken durum korunur (x=%d)" % x)
	st = DeckScript.step_state(st, Vector2(310, 216), rects)
	assert(not st["deck"] and st["idx"] == -1, "sağ uçtan inince güverte biter")
	## Vadiden kuzey->güney köprünün altından geç.
	st = {}
	st = DeckScript.step_state(st, Vector2(200, 195), rects)
	st = DeckScript.step_state(st, Vector2(200, 203), rects)
	assert(not st["deck"] and st["idx"] == 0, "yandan girdi -> altında (zemin katı)")
	st = DeckScript.step_state(st, Vector2(200, 220), rects)
	assert(not st["deck"], "altında kalır")
	st = DeckScript.step_state(st, Vector2(200, 240), rects)
	assert(st["idx"] == -1 and not st["deck"])


func test_unknown_origin_inside_counts_as_ground_floor() -> void:
	## Köprünün içinde belirmek (ışınlanma / doğuş / ilk görülme): önceki nokta yok -> zemin katı.
	var st: Dictionary = DeckScript.step_state({}, Vector2(200, 216), [_rect()])
	assert(st["idx"] == 0 and not st["deck"])


## --- depth_occluders.gd köprü kurulumu -----------------------------------------------------------------------------------------------------------

func _make_tileset() -> TileSet:
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.4, 0.2, 1.0))
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(16, 16)
	src.create_tile(Vector2i(0, 0))
	src.create_tile(Vector2i(1, 0))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_source(src, 0)
	return ts


func _make_map() -> Node2D:
	var ts: TileSet = _make_tileset()
	var harita := Node2D.new()
	harita.name = "Harita"
	var kopru := Node2D.new()
	kopru.name = "Köprü"
	harita.add_child(kopru)
	var alt := TileMapLayer.new()
	alt.name = "Köprü alt"
	alt.tile_set = ts
	var ust := TileMapLayer.new()
	ust.name = "Köprü üst"
	ust.tile_set = ts
	## Köprü: hücre x 10..19, y 20..21 (160x32 px, dünya (160,320)-(320,352)). Alt güverte iki satır, üst sadece üst satır.
	for x in range(10, 20):
		alt.set_cell(Vector2i(x, 20), 0, Vector2i(0, 0))
		alt.set_cell(Vector2i(x, 21), 0, Vector2i(1, 0))
		ust.set_cell(Vector2i(x, 20), 0, Vector2i(0, 0))
	kopru.add_child(alt)
	kopru.add_child(ust)
	## Köprüyle ilgisiz bir bina katmanı değil, yalnız Köprü grubu: kaba ızgaraya köprünün girmediğini görmek için ayrıca bir Maden.
	var et := Node2D.new()
	et.name = "Etkileşimler"
	harita.add_child(et)
	var maden := TileMapLayer.new()
	maden.name = "Maden"
	maden.tile_set = ts
	maden.set_cell(Vector2i(40, 40), 0, Vector2i(0, 0))
	et.add_child(maden)
	return harita


func _player(parent: Node, pos: Vector2, grp: String = "player") -> Node2D:
	var p := Node2D.new()
	p.global_position = pos
	p.add_to_group(grp)
	parent.add_child(p)
	_track(p)
	return p


func _feet(pos_y: float) -> float:
	return pos_y + DepthScript.FEET_OFFSET


func test_bridge_setup_makes_two_bridge_fronts_not_covering_creatures() -> void:
	var harita: Node2D = _track(_make_map()) as Node2D
	add_child(harita)
	var dep: Node = DepthScript.new()
	dep.setup(harita)
	var modes: Dictionary = {}
	for f: Dictionary in dep.fronts:
		modes[f["mode"]] = int(modes.get(f["mode"], 0)) + 1
	assert(int(modes.get("bridge", 0)) == 2, "Köprü alt + üst iki kopya: %s" % str(modes))
	assert(dep.bridge_rects.size() == 1 and dep.bridge_rects[0].is_equal_approx(Rect2(160, 320, 160, 32)), "köprü dikdörtgeni: %s" % str(dep.bridge_rects))
	## Köprü kopyaları yaratıkların kaba ızgarasına GİRMEZ: köprüye yakın bir yaratık değerlendirilmez (sadece Maden hücresi girer).
	assert(dep.max_base_in(160.0, 320.0, 320.0, 352.0) < -1.0e8, "köprü hücreleri kaba ızgarada yok")
	assert(dep.max_base_in(640.0, 640.0, 656.0, 656.0) > 0.0, "Maden hâlâ kaba ızgarada")
	## Alt + üst TEK kökü paylaşır (bina gibi): üst satırdaki üst-katman hücresinin kökü = güvertenin alt kenarı (352).
	for f: Dictionary in dep.fronts:
		if f["mode"] == "bridge":
			assert(is_equal_approx(float((f["bases"] as Dictionary).get(Vector2i(12, 20), -1.0)), 352.0), "köprü kökü tek: %s" % str(f["bases"].get(Vector2i(12, 20))))
	dep.free()
	_cleanup()


func test_walk_onto_deck_is_excluded_and_walk_under_is_included() -> void:
	var harita: Node2D = _track(_make_map()) as Node2D
	add_child(harita)
	var dep: Node = DepthScript.new()
	dep.setup(harita)
	var front_mat: ShaderMaterial = null
	for f: Dictionary in dep.fronts:
		if f["mode"] == "bridge":
			front_mat = (f["front"] as TileMapLayer).material as ShaderMaterial
			break
	var deck_walker: Node2D = _player(harita, Vector2(150.0, 340.0 - DepthScript.FEET_OFFSET))
	var under_walker: Node2D = _player(harita, Vector2(240.0, 305.0 - DepthScript.FEET_OFFSET), "remote_players")
	dep._process(0.0)
	## Ikisi de köprü dikdörtgeninin DIŞINDA başladı (güverteci x 150 < 160; altından geçen y 305 < 320).
	assert(not dep.is_on_deck(deck_walker) and not dep.is_on_deck(under_walker))
	deck_walker.global_position = Vector2(170.0, 340.0 - DepthScript.FEET_OFFSET)   ## sol uçtan içeri
	under_walker.global_position = Vector2(240.0, 325.0 - DepthScript.FEET_OFFSET)  ## kuzeyden içeri
	dep._process(0.0)
	assert(dep.is_on_deck(deck_walker), "uçtan girdi -> güvertede")
	assert(not dep.is_on_deck(under_walker), "yandan girdi -> altında")
	assert(int(front_mat.get_shader_parameter("karakter_sayisi")) == 1, "köprü kopyasına sadece altındaki karakter gider: %s" % str(front_mat.get_shader_parameter("karakter_sayisi")))
	var arr: Array = front_mat.get_shader_parameter("karakterler")
	assert(absf(arr[0].x - 240.0) < 0.01 and absf(arr[0].y - 325.0) < 0.01, "listedeki karakter altındaki: %s" % str(arr[0]))
	## Altından geçen güneyden çıkınca ve uzaklaşınca liste boşalır; güverteci karşı uçtan inince durum sıfırlanır.
	under_walker.global_position = Vector2(240.0, 700.0)
	deck_walker.global_position = Vector2(330.0, 340.0 - DepthScript.FEET_OFFSET)
	dep._process(0.0)
	assert(not dep.is_on_deck(deck_walker))
	assert(int(front_mat.get_shader_parameter("karakter_sayisi")) == 1, "karşı yamaçtaki (köprüye yakın, güverte değil) zemin katı sayılır")
	deck_walker.global_position = Vector2(900.0, 900.0)
	dep._process(0.0)
	assert(int(front_mat.get_shader_parameter("karakter_sayisi")) == 0, "köprüden uzak kimse listede yok")
	dep.free()
	_cleanup()


func test_far_characters_do_not_rewrite_the_bridge_uniforms() -> void:
	var harita: Node2D = _track(_make_map()) as Node2D
	add_child(harita)
	var dep: Node = DepthScript.new()
	dep.setup(harita)
	var p: Node2D = _player(harita, Vector2(1200.0, 1200.0))
	dep._process(0.0)
	var before: Array[Vector4] = dep._last_bridge_chars.duplicate()
	p.global_position = Vector2(1300.0, 1250.0)
	dep._process(0.0)
	assert(dep._last_bridge_chars == before and before.is_empty(), "uzaktaki karakterin hareketi köprü listesini değiştirmez")
	dep.free()
	_cleanup()


## --- gerçek harita: köprünün sağ ucundaki görünmez duvar açık ------------------------------------------------------------------------------------

const HaritaScene: PackedScene = preload("res://scenes/harita_baked.tscn")


func test_real_map_bridge_right_end_is_walkable_onto_the_right_hill() -> void:
	var harita: Node = HaritaScene.instantiate()
	add_child(harita)
	var forest: TileMapLayer = harita.get_node("Orman parçaları/Orman parçaları")
	## Köprü güvertesi x 43..65, y 120..121. Sağ uçtan sonra (66-67 serbest) x 68-69 sütunu eskiden görünmez bir orman dolgusuydu (y 110..126):
	## güverteden karşı yamaca çıkış kapalıydı. Şimdi köprü hizasındaki 4 satır (y 119..122) açık, kapının kuzey/güneyindeki dolgu duruyor.
	for y in [119, 120, 121, 122]:
		for x in [66, 67, 68, 69, 70]:
			assert(forest.get_cell_source_id(Vector2i(x, y)) == -1 or (x == 70 and y == 119), "köprü ucu geçidi açık olmalı: (%d,%d)" % [x, y])
	assert(forest.get_cell_source_id(Vector2i(68, 118)) != -1 and forest.get_cell_source_id(Vector2i(69, 118)) != -1, "geçidin kuzeyindeki dolgu yerinde")
	assert(forest.get_cell_source_id(Vector2i(68, 123)) != -1 and forest.get_cell_source_id(Vector2i(69, 123)) != -1, "geçidin güneyindeki dolgu yerinde")
	## Güverte hücreleri ve sol uç da engelsiz (sol yamaçtan çıkış).
	for x in range(40, 68):
		for y in [120, 121]:
			assert(forest.get_cell_source_id(Vector2i(x, y)) == -1, "güverte/sol uç serbest: (%d,%d)" % [x, y])
	harita.free()
