extends Node

## ZİNDAN BİÇİMLİ HARİTALAR (madde 444/449; madde 463'den beri ana haritada zindan YOK - eski üç zindanın testleri bu haritalara taşındı):
## seçilebilir üç haritanın (Batık Nekropol / Taşkın Hisar / Lağım Ağı) pişmiş verisi + dünya kaydı + kaçış kuralı + yönetici etkileşimleri.
##  - veri: boyut ana haritanın (256x256) ~%70'i, doğuş, sunak, avcı, kaynak, sandık, tuzak, sakinler, ışık;
##  - KAÇIŞ: tüm yürünür hücreler doğuşa bağlı; tek bir kapı (ya da bir kolun indirdiği kapı grubu) kapanınca hiçbir oda doğuştan kopmuyor;
##  - dünya kaydı + AYAK KURALI (dungeon_world.gd, madde 460): hareket ayaktan (kök = ayak - FEET_SHIFT), görüş/mermi kaymaz, nesne yalnız hareket,
##    saklanma hücresi = çalılık kuralı, yol ızgarasında hareket hücresi bir satır yukarı (MOVE_SHIFT), sis yerinde, kapı aç/kapa;
##  - DungeonManager (harita kipi): kapı kapanır ve süresi dolunca açılır, kaynak toplama (ikinci kez yok), sunak alımı kart statı verir ve bedeli artar.

const MapProfiles: GDScript = preload("res://scripts/map_profiles.gd")
const TerrainCollisionScript := preload("res://scripts/terrain_collision.gd")
const EnemyPathingScript := preload("res://scripts/enemy_pathing.gd")
const DungeonDefsScript := preload("res://scripts/dungeon/dungeon_defs.gd")
const DungeonWorldScript := preload("res://scripts/dungeon/dungeon_world.gd")
const DungeonDataScript := preload("res://scripts/dungeon/dungeon_data.gd")
const DungeonManagerScript := preload("res://scripts/dungeon/dungeon_manager.gd")
const HideBrushScript := preload("res://scripts/hide_brush.gd")
const MAPS: Array[String] = ["batik_nekropol", "taskin_hisar", "lagim_agi"]
const MAP_CELLS := 256 * 256

var _main: Node2D = null


class FakePlayer extends Node2D:
	var in_dungeon: String = ""
	var is_dead: bool = false
	var is_chat_typing: bool = false
	var max_health: float = 100.0
	var upgrades: Array = []

	func apply_upgrade(id: String, tier: int = 1) -> void:
		upgrades.append([id, tier])


func _skip() -> bool:
	return OS.get_environment("HARITA") != "" ## ortam değişkeni harita seçimini ezer (geliştirme)


func _data(id: String) -> Resource:
	return load(str(MapProfiles.get_profile(id)["veri"]))


func _reset_caches() -> void:
	GameManager._terrain_su_layer = null
	GameManager._terrain_ev_layer = null
	GameManager._terrain_forest_layer = null
	GameManager._terrain_layers_searched = false
	GameManager._map_world_rect_searched = false
	TerrainCollisionScript.reset()
	DungeonWorldScript.reset()
	EnemyPathingScript.reset()


## Seçili haritayı sahte bir Main'e kurar (MapProfiles.install: pişmiş sahne + görünmez duvar katmanı), sahneyi current_scene yapar.
func _load_map(id: String) -> void:
	GameManager.selected_map = id
	_main = Node2D.new()
	_main.name = "TestMain"
	var h := Node2D.new()
	h.name = "Harita"
	_main.add_child(h)
	assert(MapProfiles.install(_main), "harita kurulmadı: " + id)
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_reset_caches()


func _unload_map() -> void:
	if is_instance_valid(_main):
		_main.free()
	_main = null
	get_tree().current_scene = null
	_reset_caches()
	GameManager.selected_map = "ana"


static func _count(data: Resource, typ: String) -> int:
	return data.objects_of(typ).size()


func test_data_size_and_contents() -> void:
	for id: String in MAPS:
		var data: Resource = _data(id)
		assert(data != null, "veri yok: " + id)
		var pct: float = float(data.size.x * data.size.y) / float(MAP_CELLS)
		assert(pct >= 0.6 and pct <= 0.8, "%s boyutu ana haritanın %%%.1f'i (~%%70 olmalı)" % [id, pct * 100.0])
		assert(_count(data, "dogus") == 1, id + ": doğuş")
		assert(_count(data, "sunak") == 1, id + ": sunak")
		assert(_count(data, "avci") == 1, id + ": avcı")
		assert(_count(data, "kaynak") >= 4, "%s: kaynak %d" % [id, _count(data, "kaynak")])
		assert(_count(data, "tuzak") >= 3, "%s: tuzak %d" % [id, _count(data, "tuzak")])
		assert(_count(data, "sandik") >= 2, "%s: sandık %d" % [id, _count(data, "sandik")])
		assert(_count(data, "sakin") >= 6, "%s: sakin grubu %d" % [id, _count(data, "sakin")])
		assert(_count(data, "isik") >= 15, "%s: ışık %d" % [id, _count(data, "isik")])
		assert(_count(data, "cikis") == 0, id + ": haritada zindandan çıkış olmamalı")
		## etkileşim nesnelerinin teması bilinen bir zindan tanımı (sunak teklifleri / kaynak / görsel tablo)
		for o: Dictionary in data.objects:
			if ["kapi", "kaynak", "sandik", "sunak", "tuzak", "kol", "fici", "sakin", "avci"].has(str(o["type"])):
				var tema: String = str((o["props"] as Dictionary).get("tema", ""))
				var did: String = str(DungeonManagerScript.MAP_THEME_DUNGEON.get(tema, ""))
				assert(not DungeonDefsScript.by_id(did).is_empty(), "%s: %s nesnesinin teması bilinmiyor (%s)" % [id, o["type"], tema])
		var walkable: int = 0
		for c: int in data.cells:
			if c == DungeonDataScript.CELL_EMPTY or c == DungeonDataScript.CELL_HIDE or c == DungeonDataScript.CELL_GATE:
				walkable += 1
		assert(walkable > 10000, "%s: yürünür alan küçük (%d)" % [id, walkable])
	## Taşkın Hisar köprü kolları, Lağım Ağı gaz fıçıları (haritaya özgü etkileşimler)
	assert(_count(_data("taskin_hisar"), "kol") == 2, "Taşkın Hisar: iki köprü kolu")
	assert(_count(_data("lagim_agi"), "fici") >= 8, "Lağım Ağı: gaz fıçıları")


## Kaçış kuralı: yürünür = boş / saklanma / (açık) kapı. Hızlı: yürünür maskesi bayt dizisi, BFS dizinle.
static func _walk_mask(data: Resource) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(data.cells.size())
	for i in range(data.cells.size()):
		var c: int = data.cells[i]
		m[i] = 1 if (c == DungeonDataScript.CELL_EMPTY or c == DungeonDataScript.CELL_HIDE or c == DungeonDataScript.CELL_GATE) else 0
	return m


static func _bfs(w: int, mask: PackedByteArray, sources: PackedInt32Array) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(mask.size())
	var q := PackedInt32Array()
	q.resize(mask.size())
	var tail: int = 0
	for i: int in sources:
		if mask[i] != 0 and seen[i] == 0:
			seen[i] = 1
			q[tail] = i
			tail += 1
	var head: int = 0
	while head < tail:
		var i: int = q[head]
		head += 1
		var x: int = i % w
		for j: int in [i + 1 if x + 1 < w else -1, i - 1 if x > 0 else -1, i + w, i - w]:
			if j >= 0 and j < mask.size() and mask[j] != 0 and seen[j] == 0:
				seen[j] = 1
				q[tail] = j
				tail += 1
	return seen


static func _rect_idx(r: Rect2, w: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y in range(int(r.position.y / 16.0), int(r.end.y / 16.0)):
		for x in range(int(r.position.x / 16.0), int(r.end.x / 16.0)):
			out.append(y * w + x)
	return out


func test_escape_routes_always_exist() -> void:
	for id: String in MAPS:
		var data: Resource = _data(id)
		var w: int = data.size.x
		var mask: PackedByteArray = _walk_mask(data)
		var spawn: PackedInt32Array = _rect_idx(data.objects_of("dogus")[0]["rect"], w)
		var rooms: Array = [] ## oda (sakin grubu / sunak) başına yürünür hücre dizinleri
		for o: Dictionary in data.objects_of("sakin") + data.objects_of("sunak"):
			var cells := PackedInt32Array()
			for i: int in _rect_idx(o["rect"], w):
				if mask[i] != 0:
					cells.append(i)
			if not cells.is_empty():
				rooms.append(cells)
		var base: PackedByteArray = _bfs(w, mask, spawn)
		var unreached: int = 0
		for i in range(mask.size()):
			if mask[i] != 0 and base[i] == 0:
				unreached += 1
		assert(unreached == 0, "%s: doğuşa bağlı olmayan %d yürünür hücre" % [id, unreached])
		## tek kapı ya da bir kolun grubu (Taşkın Hisar: kol çekilince gruptaki TÜM parmaklıklar iner) kapanınca hiçbir oda kopmaz
		var groups: Dictionary = {} ## grup adı ("" = tek başına) -> [kapı dikdörtgeni]
		var n: int = 0
		for o: Dictionary in data.objects_of("kapi"):
			var g: String = str((o["props"] as Dictionary).get("grup", ""))
			var key: String = g if g != "" else "tek_%d" % n
			n += 1
			if not groups.has(key):
				groups[key] = []
			(groups[key] as Array).append(o["rect"])
		for key: String in groups:
			var m2: PackedByteArray = mask.duplicate()
			for r: Rect2 in groups[key]:
				for i: int in _rect_idx(r, w):
					m2[i] = 0
			var seen: PackedByteArray = _bfs(w, m2, spawn)
			for cells: PackedInt32Array in rooms:
				var any_free: bool = false
				var ok: bool = false
				for i: int in cells:
					if m2[i] == 0:
						continue
					any_free = true
					if seen[i] != 0:
						ok = true
						break
				if any_free:
					assert(ok, "%s: kapı %s bir odayı doğuştan koparıyor (%d,%d)" % [id, key, cells[0] % w, cells[0] / w])


## Dünya kaydı + AYAK KURALI: kök = ayak - FEET_SHIFT; görüş/mermi (forest) kaymaz; yol ızgarasında hareket bir satır yukarı, sis yerinde.
func test_world_registration_feet_rule_and_gates() -> void:
	if _skip():
		return
	var id: String = "batik_nekropol" ## saklanma (açık lahit) + kapı + nesne hepsi var
	_load_map(id)
	assert(DungeonWorldScript.ensure(), "kayıt")
	assert(DungeonWorldScript.dungeons().is_empty(), "harita kipinde zindan listesi boş olmalı")
	assert(DungeonWorldScript.map_mode() and not DungeonWorldScript.map_entry().is_empty(), "harita kaydı yok")
	var data: Resource = DungeonWorldScript.map_entry()["data"]
	var wall := Vector2i(-1, -1)
	var solid := Vector2i(-1, -1)
	var hide := Vector2i(-1, -1)
	for i in range(data.cells.size()):
		var c := Vector2i(i % data.size.x, i / data.size.x)
		match int(data.cells[i]):
			DungeonDataScript.CELL_WALL:
				if wall.x < 0 and c.y > 2 and data.cell_at(c + Vector2i(0, 1)) == DungeonDataScript.CELL_EMPTY \
						and data.cell_at(c + Vector2i(0, 2)) == DungeonDataScript.CELL_EMPTY:
					wall = c
			DungeonDataScript.CELL_SOLID:
				if solid.x < 0 and data.cell_at(c + Vector2i(0, -1)) == DungeonDataScript.CELL_EMPTY:
					solid = c
			DungeonDataScript.CELL_HIDE:
				if hide.x < 0:
					hide = c
	assert(wall.x >= 0 and solid.x >= 0 and hide.x >= 0, "örnek hücre bulunamadı")
	var lift := Vector2(0.0, DungeonWorldScript.FEET_SHIFT)
	var wp: Vector2 = DungeonWorldScript.cell_center(wall)
	assert(GameManager.is_position_blocked_by_forest(wp), "duvar görüşü/mermiyi kesmiyor")
	assert(GameManager.is_position_blocked_by_walls(wp - lift), "ayağı duvarda olan kök engellenmiyor")
	assert(not GameManager.is_position_blocked_by_walls(wp), "duvarın alt satırındaki kök (ayağı zeminde) engelli")
	var below: Vector2 = DungeonWorldScript.cell_center(wall + Vector2i(0, 1))
	assert(not GameManager.is_position_blocked_by_walls(below - lift), "zemin engelli")
	var sp: Vector2 = DungeonWorldScript.cell_center(solid)
	assert(GameManager.is_position_blocked_by_walls(sp - lift) and not GameManager.is_position_blocked_by_forest(sp), "nesne yalnız hareketi kesmeli")
	assert(HideBrushScript.contains(get_tree(), DungeonWorldScript.cell_center(hide)), "saklanma hücresi çalılık sayılmıyor")
	## yol ızgarası: hareket hücresi bir satır yukarı (MOVE_SHIFT), sis yerinde; nesne görüşü kesmez
	EnemyPathingScript._build(GameManager.get_forest_layer())
	assert(EnemyPathingScript._fog_blocked[_grid_idx(wall)] == 1, "yol ızgarası duvarda sis kesmiyor")
	assert(EnemyPathingScript._blocked[_grid_idx(wall + DungeonWorldScript.MOVE_SHIFT)] == 1, "yol ızgarası duvarı görmüyor")
	assert(EnemyPathingScript._blocked[_grid_idx(wall)] == 0, "duvarın alt satırı (ayağı zemindeki kök) yol ızgarasında engelli")
	assert(EnemyPathingScript._blocked[_grid_idx(solid + DungeonWorldScript.MOVE_SHIFT)] == 1, "yol ızgarası nesneyi görmüyor")
	assert(EnemyPathingScript._fog_blocked[_grid_idx(solid)] == 0, "nesne görüşü kesmemeli")
	## kapı aç/kapa: hareket + yol ızgarası
	var g: Dictionary = data.objects_of("kapi")[0]
	var key: String = str(g["gate_key"])
	var cells: Array = DungeonWorldScript.gate_cells(key)
	var gp: Vector2 = DungeonWorldScript.cell_center(cells[0]) - lift
	assert(not GameManager.is_position_blocked_by_walls(gp), "açık kapı engelli")
	EnemyPathingScript.sync_cells(DungeonWorldScript.set_gate_closed(key, true))
	assert(GameManager.is_position_blocked_by_walls(gp), "kapalı kapı geçiliyor")
	var gidx: int = _grid_idx(cells[0] + DungeonWorldScript.MOVE_SHIFT)
	assert(EnemyPathingScript._blocked[gidx] == 1, "kapalı kapı yol ızgarasında açık")
	EnemyPathingScript.sync_cells(DungeonWorldScript.set_gate_closed(key, false))
	assert(not GameManager.is_position_blocked_by_walls(gp) and EnemyPathingScript._blocked[gidx] == 0, "kapı geri açılmadı")
	_unload_map()


func _grid_idx(c: Vector2i) -> int:
	return (c.y - EnemyPathingScript._origin.y) * EnemyPathingScript._size.x + (c.x - EnemyPathingScript._origin.x)


## Ana harita: zindan yok (madde 463) - kayıt boş, DungeonManager kurulmaz.
func test_main_map_has_no_dungeons() -> void:
	if _skip():
		return
	GameManager.selected_map = "ana"
	assert(not MapProfiles.feature("zindan_etkilesim"), "ana haritada DungeonManager kurulmamalı")
	DungeonWorldScript.test_origin_px = Vector2.ZERO
	DungeonWorldScript.reset()
	assert(DungeonWorldScript.ensure())
	assert(DungeonWorldScript.dungeons().is_empty() and DungeonWorldScript.map_entry().is_empty(), "ana haritada zindan kaydı var")
	assert(not DungeonWorldScript.feet_rule_at(Vector2(100, 100)), "ana haritada ayak kuralı olmamalı")
	assert(DungeonWorldScript.region_rects().is_empty(), "C++ bölge dikdörtgeni kalmış")
	DungeonWorldScript.test_origin_px = null
	DungeonWorldScript.reset()


func test_manager_interactions() -> void:
	if _skip():
		return
	var id: String = "taskin_hisar"
	_load_map(id)
	GameManager.reset()
	GameManager.selected_map = id
	_reset_caches()
	var p := FakePlayer.new()
	p.add_to_group("player")
	_main.add_child(p)
	var dm: Node = DungeonManagerScript.new()
	_main.add_child(dm)
	await get_tree().process_frame
	assert(str(dm.get("_map_id")) == id, "harita kipi kurulmadı")
	var data: Resource = DungeonWorldScript.map_entry()["data"]
	p.global_position = MapProfiles.spawn_position()
	assert(not GameManager.is_position_blocked_by_walls(p.global_position), "doğuş engelli")
	## kapı: kapanır, süre dolunca açılır, beklemede tekrar kapanmaz
	var key: String = str(data.objects_of("kapi")[0]["gate_key"])
	assert(dm.call("host_close_gate", key), "kapı kapanmadı")
	assert(DungeonWorldScript.is_gate_closed(key), "kapı kayıtta açık")
	assert(not dm.call("host_close_gate", key), "kapalı kapı yeniden kapandı")
	GameManager.game_time += DungeonManagerScript.GATE_CLOSED_SEC + 0.1
	dm.call("_host_tick")
	assert(not DungeonWorldScript.is_gate_closed(key), "kapı süresi dolunca açılmadı")
	assert(not dm.call("host_close_gate", key), "bekleme süresinde kapandı")
	GameManager.game_time += DungeonManagerScript.GATE_COOLDOWN_SEC
	assert(dm.call("host_close_gate", key), "bekleme sonrası kapanmadı")
	## kaynak (temanın kaynağı)
	var node: Dictionary = data.objects_of("kaynak")[0]
	var nkey: String = str(node["node_key"])
	var res: String = str(dm.call("_resource_of", id, node))
	assert(res != "", "kaynak türü yok")
	var before: int = GameManager.get_dungeon_resource(res)
	assert(dm.call("host_harvest", nkey, 1), "toplanmadı")
	assert(GameManager.get_dungeon_resource(res) > before, "kaynak verilmedi")
	assert(not dm.call("host_harvest", nkey, 1), "tükenen düğüm yeniden toplandı")
	## sunak (temanın teklifleri): yetmezse almaz; yetince kart statı + bedel artar
	var altar_id: String = str(dm.call("_offer_id", id, data.objects_of("sunak")[0]))
	var ares: String = str(DungeonDefsScript.by_id(altar_id)["resource"])
	var stat_idx: int = 0
	for i in range((DungeonManagerScript.ALTAR_OFFERS[altar_id] as Array).size()):
		if (DungeonManagerScript.ALTAR_OFFERS[altar_id][i] as Dictionary).has("upgrade"):
			stat_idx = i
			break
	GameManager.dungeon_resources[ares] = 0
	assert(not dm.call("buy_altar", altar_id, stat_idx), "kaynaksız alım")
	var cost: int = int(dm.call("altar_cost", altar_id, stat_idx))
	GameManager.add_dungeon_resource(ares, cost)
	assert(dm.call("buy_altar", altar_id, stat_idx), "alım olmadı")
	assert(p.upgrades.size() == 1, "kart statı verilmedi")
	assert(GameManager.get_dungeon_resource(ares) == 0, "bedel düşmedi")
	assert(int(dm.call("altar_cost", altar_id, stat_idx)) == cost + 2, "bedel artmadı")
	GameManager.reset()
	_unload_map()


func test_scenes_load() -> void:
	for id: String in MAPS:
		var root: Node2D = (load(str(MapProfiles.get_profile(id)["sahne"])) as PackedScene).instantiate()
		assert(root.get_node_or_null("Zemin") != null and root.get_node_or_null("Duvar") != null, id + ": katmanlar")
		assert(root.get_node_or_null("Engel") == null, id + ": Engel katmanı pişmiş sahnede kalmamalı")
		root.free()


func test_cpp_region_rects() -> void:
	if not ClassDB.class_exists("EnemyWorld"):
		return
	var w: Node = ClassDB.instantiate("EnemyWorld")
	assert(w.has_method("set_region_rects"), "C++ kütüphanesi eski (bölge yok) - yeniden derle")
	w.call("set_region_rects", PackedFloat32Array([100.0, 100.0, 50.0, 50.0, 300.0, 0.0, 20.0, 20.0]))
	assert(int(w.call("get_region_of", Vector2(120, 120))) == 1, "bölge 1")
	assert(int(w.call("get_region_of", Vector2(305, 5))) == 2, "bölge 2")
	assert(int(w.call("get_region_of", Vector2(10, 10))) == 0, "ana harita")
	w.free()


## TUZAKLAR (madde 492): eskiden 3,6 sn'de bir, %14 can. Artık her tür en çok 2,6 sn'de bir, en az %25 can; ejder alevi 8 hücre.
func test_trap_timing_is_frequent_and_dangerous() -> void:
	var mgr: Node = DungeonManagerScript.new()
	for tur: String in ["diken", "ejder", "giyotin"]:
		var tm: Dictionary = DungeonManagerScript.trap_timing(tur)
		assert(float(tm["cycle"]) <= 2.6)
		assert(float(tm["player"]) >= 0.25)
		assert(float(tm["creature"]) >= 0.5)
		var rise: Array = tm["rise"]
		assert(float(rise[0]) < float(rise[1]) and float(rise[1]) < float(rise[2]) and float(rise[2]) < float(rise[3]) and float(rise[3]) <= float(tm["cycle"]))
		var full: float = 0.0
		var off: float = DungeonManagerScript.trap_offset("k", tm)
		for i in range(int(float(tm["cycle"]) * 100.0)):
			var t: float = float(i) * 0.01 - off
			if mgr.trap_level("k", t, tur) >= DungeonManagerScript.TRAP_HIT_LEVEL:
				full += 0.01
		assert(full >= 0.4) ## vurma penceresi en az 0,4 sn
	assert(DungeonWorldScript.EJDER_ROWS >= 8)
	mgr.free()
