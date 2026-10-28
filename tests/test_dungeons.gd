extends Node

## ZİNDANLAR (madde 373): üç zindanın pişmiş verisi + dünya kaydı + kaçış kuralı + yönetici etkileşimleri.
##  - boyut ana haritanın (256x256 hücre) %15-30'u, her zindanda 3 çıkış (1 ana), doğuş, sunak, kaynak, saklanma, kapı, tuzak, sandık, avcı, sakinler;
##  - KAÇIŞ: tüm yürünür hücreler çıkışlara bağlı, tek bir kapı kapanınca ya da koridorun herhangi bir yerini 5x5 bir yaratık grubu tıkayınca
##    hiçbir oda çıkışlardan kopmuyor (üretecinin repair_escape kuralının oyun verisinde tekrarı);
##  - dünya kaydı: zindan duvarı hareket + görüş (is_position_blocked_by_forest), nesne yalnız hareket, kapı aç/kapa, saklanma hücresi = çalılık kuralı,
##    yol ızgarası (EnemyPathing) duvarları ve kapıyı görüyor, C++ bölge dikdörtgenleri;
##  - DungeonManager: iniş/çıkış, kapı kapanır ve süresi dolunca açılır, kaynak toplama (ikinci kez yok), sunak alımı kart statı verir ve bedeli artar.

const HaritaScene: PackedScene = preload("res://scenes/harita_baked.tscn")
const TerrainCollisionScript := preload("res://scripts/terrain_collision.gd")
const EnemyPathingScript := preload("res://scripts/enemy_pathing.gd")
const DungeonDefsScript := preload("res://scripts/dungeon/dungeon_defs.gd")
const DungeonWorldScript := preload("res://scripts/dungeon/dungeon_world.gd")
const DungeonDataScript := preload("res://scripts/dungeon/dungeon_data.gd")
const DungeonManagerScript := preload("res://scripts/dungeon/dungeon_manager.gd")
const DungeonPropsScript := preload("res://scripts/dungeon/dungeon_props.gd")
const GuardCampsScript := preload("res://scripts/guard_camps.gd")
const HideBrushScript := preload("res://scripts/hide_brush.gd")
const KOKU := Vector2(-2.0, 21.0)
const MAP_CELLS := 256 * 256

var _main: Node2D = null
var _harita: Node2D = null


class FakePlayer extends Node2D:
	var in_dungeon: String = ""
	var is_dead: bool = false
	var is_chat_typing: bool = false
	var max_health: float = 100.0
	var upgrades: Array = []

	func apply_upgrade(id: String, tier: int = 1) -> void:
		upgrades.append([id, tier])


func _load_map() -> void:
	_main = Node2D.new()
	_main.name = "TestMain"
	_harita = HaritaScene.instantiate()
	_harita.name = "Harita"
	_harita.position = KOKU
	_main.add_child(_harita)
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	GameManager._terrain_layers_searched = false
	GameManager._map_world_rect_searched = false
	TerrainCollisionScript.reset()
	DungeonWorldScript.reset()
	EnemyPathingScript.reset()


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
	DungeonWorldScript.reset()
	EnemyPathingScript.reset()


func _data(id: String) -> Resource:
	return load(DungeonDefsScript.DATA_PATH % id)


static func _count(data: Resource, typ: String) -> int:
	return data.objects_of(typ).size()


func test_data_size_and_contents() -> void:
	var names: Dictionary = {}
	for def: Dictionary in DungeonDefsScript.DUNGEONS:
		var id: String = def["id"]
		var data: Resource = _data(id)
		assert(data != null, "veri yok: " + id)
		var area: int = data.size.x * data.size.y
		var pct: float = float(area) / float(MAP_CELLS)
		assert(pct >= 0.15 and pct <= 0.30, "%s boyutu ana haritanın %%%.1f'i (%%15-30 olmalı)" % [id, pct * 100.0])
		var exits: Array = data.objects_of("cikis")
		assert(exits.size() >= 3, "%s: en az 3 çıkış (%d)" % [id, exits.size()])
		assert(exits.filter(func(o: Dictionary) -> bool: return str((o["props"] as Dictionary).get("ana", "0")) == "1").size() == 1, "%s: tek ana çıkış" % id)
		assert(_count(data, "dogus") == 1, id + ": doğuş")
		assert(_count(data, "sunak") == 1, id + ": sunak")
		assert(_count(data, "avci") == 1, id + ": avcı")
		assert(_count(data, "kaynak") >= 4, "%s: kaynak %d" % [id, _count(data, "kaynak")])
		assert(_count(data, "saklanma") >= 2, "%s: saklanma %d" % [id, _count(data, "saklanma")])
		assert(_count(data, "kapi") >= 4, "%s: kapı %d" % [id, _count(data, "kapi")])
		assert(_count(data, "tuzak") >= 3, "%s: tuzak %d" % [id, _count(data, "tuzak")])
		assert(_count(data, "sandik") >= 2, "%s: sandık %d" % [id, _count(data, "sandik")])
		assert(_count(data, "sakin") >= 6, "%s: sakin grubu %d" % [id, _count(data, "sakin")])
		assert(_count(data, "isik") >= 15, "%s: ışık %d" % [id, _count(data, "isik")])
		## kapı tarzları zindana özgü (aynı şeyleri içermesin)
		for o: Dictionary in data.objects_of("kapi"):
			var st: String = str((o["props"] as Dictionary).get("stil", ""))
			assert(not names.has(st) or names[st] == id, "kapı tarzı iki zindanda: " + st)
			names[st] = id
		var walkable: int = 0
		for c: int in data.cells:
			if c == DungeonDataScript.CELL_EMPTY or c == DungeonDataScript.CELL_HIDE or c == DungeonDataScript.CELL_GATE:
				walkable += 1
		assert(walkable > 3000, "%s: yürünür alan küçük (%d)" % [id, walkable])


## Kaçış kuralı: yürünür = boş / saklanma / (açık) kapı. Hızlı: yürünür maskesi bayt dizisi, BFS dizinle.
static func _walk_mask(data: Resource) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(data.cells.size())
	for i in range(data.cells.size()):
		var c: int = data.cells[i]
		m[i] = 1 if (c == DungeonDataScript.CELL_EMPTY or c == DungeonDataScript.CELL_HIDE or c == DungeonDataScript.CELL_GATE) else 0
	return m


static func _bfs(w: int, h: int, mask: PackedByteArray, sources: PackedInt32Array) -> PackedByteArray:
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
		if x + 1 < w and mask[i + 1] != 0 and seen[i + 1] == 0:
			seen[i + 1] = 1
			q[tail] = i + 1
			tail += 1
		if x > 0 and mask[i - 1] != 0 and seen[i - 1] == 0:
			seen[i - 1] = 1
			q[tail] = i - 1
			tail += 1
		if i + w < mask.size() and mask[i + w] != 0 and seen[i + w] == 0:
			seen[i + w] = 1
			q[tail] = i + w
			tail += 1
		if i - w >= 0 and mask[i - w] != 0 and seen[i - w] == 0:
			seen[i - w] = 1
			q[tail] = i - w
			tail += 1
	return seen


static func _rect_idx(r: Rect2, w: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y in range(int(r.position.y / 16.0), int(r.end.y / 16.0)):
		for x in range(int(r.position.x / 16.0), int(r.end.x / 16.0)):
			out.append(y * w + x)
	return out


func test_escape_routes_always_exist() -> void:
	for def: Dictionary in DungeonDefsScript.DUNGEONS:
		var id: String = def["id"]
		var data: Resource = _data(id)
		var w: int = data.size.x
		var h: int = data.size.y
		var mask: PackedByteArray = _walk_mask(data)
		var exits := PackedInt32Array()
		for o: Dictionary in data.objects_of("cikis"):
			exits.append_array(_rect_idx(o["rect"], w))
		var rooms: Array = [] ## oda başına yürünür hücre dizinleri
		for o: Dictionary in data.objects_of("sakin") + data.objects_of("dogus") + data.objects_of("sunak"):
			var cells := PackedInt32Array()
			for i: int in _rect_idx(o["rect"], w):
				if mask[i] != 0:
					cells.append(i)
			if not cells.is_empty():
				rooms.append(cells)
		var base: PackedByteArray = _bfs(w, h, mask, exits)
		var unreached: int = 0
		for i in range(mask.size()):
			if mask[i] != 0 and base[i] == 0:
				unreached += 1
		assert(unreached == 0, "%s: çıkışa bağlı olmayan %d yürünür hücre" % [id, unreached])
		for o: Dictionary in data.objects_of("kapi"):
			var m2: PackedByteArray = mask.duplicate()
			for i: int in _rect_idx(o["rect"], w):
				m2[i] = 0
			_assert_rooms_reach(id, w, h, m2, exits, rooms, "kapı " + str(o["rect"]))
		## koridor tıkanması (koridor = 7x7 çevresinde yürünür oran düşük): her 6. koridor hücresine 5x5 grup
		var n: int = 0
		for i in range(mask.size()):
			if mask[i] == 0:
				continue
			var x: int = i % w
			var y: int = i / w
			if x < 3 or y < 3 or x >= w - 3 or y >= h - 3:
				continue
			var walk: int = 0
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					walk += mask[(y + dy) * w + x + dx]
			if walk > 28:
				continue
			n += 1
			if n % 6 != 0:
				continue
			var m3: PackedByteArray = mask.duplicate()
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					m3[(y + dy) * w + x + dx] = 0
			_assert_rooms_reach(id, w, h, m3, exits, rooms, "tıkanma (%d,%d)" % [x, y])


func _assert_rooms_reach(id: String, w: int, h: int, mask: PackedByteArray, exits: PackedInt32Array, rooms: Array, label: String) -> void:
	var seen: PackedByteArray = _bfs(w, h, mask, exits)
	for cells: PackedInt32Array in rooms:
		var any_free: bool = false
		var ok: bool = false
		for i: int in cells:
			if mask[i] == 0:
				continue
			any_free = true
			if seen[i] != 0:
				ok = true
				break
		if any_free:
			assert(ok, "%s: %s bir odayı çıkışlardan koparıyor (%d,%d)" % [id, label, cells[0] % w, cells[0] / w])


func test_world_registration_blocks_and_hides() -> void:
	_load_map()
	assert(DungeonWorldScript.ensure(), "kayıt")
	assert(DungeonWorldScript.dungeons().size() == 3, "üç zindan")
	var rects := DungeonWorldScript.region_rects()
	assert(rects.size() == 12, "bölge dikdörtgenleri")
	var map_rect: Rect2 = GameManager.get_camera_world_rect()
	for e: Dictionary in DungeonWorldScript.dungeons():
		var r: Rect2 = e["rect"]
		assert(not r.intersects(map_rect), "zindan ana haritayla çakışıyor: " + str(e["id"]))
		var data: Resource = e["data"]
		var wall := Vector2i(-1, -1)
		var solid := Vector2i(-1, -1)
		var hide := Vector2i(-1, -1)
		for i in range(data.cells.size()):
			var c := Vector2i(i % data.size.x, i / data.size.x)
			match int(data.cells[i]):
				DungeonDataScript.CELL_WALL:
					if wall.x < 0 and data.cell_at(c + Vector2i(0, 1)) == DungeonDataScript.CELL_EMPTY:
						wall = c
				DungeonDataScript.CELL_SOLID:
					if solid.x < 0:
						solid = c
				DungeonDataScript.CELL_HIDE:
					if hide.x < 0:
						hide = c
		var org: Vector2i = e["origin"]
		var wp: Vector2 = DungeonWorldScript.cell_center(org + wall)
		assert(GameManager.is_position_blocked_by_forest(wp), "duvar görüşü/hareketi kesmiyor: " + str(e["id"]))
		assert(GameManager.is_position_blocked_by_walls(wp), "duvar hareketi kesmiyor")
		var below: Vector2 = DungeonWorldScript.cell_center(org + wall + Vector2i(0, 1))
		assert(not GameManager.is_position_blocked_by_walls(below), "zemin engelli")
		var sp: Vector2 = DungeonWorldScript.cell_center(org + solid)
		assert(GameManager.is_position_blocked_by_walls(sp) and not GameManager.is_position_blocked_by_forest(sp), "nesne yalnız hareketi kesmeli")
		assert(HideBrushScript.contains(get_tree(), DungeonWorldScript.cell_center(org + hide)), "saklanma hücresi çalılık sayılmıyor")
		assert(DungeonWorldScript.dungeon_at(wp) == str(e["id"]), "dungeon_at")
		## yol ızgarası: duvar hareket + sis, nesne yalnız hareket
		EnemyPathingScript._build(GameManager.get_forest_layer())
		var gc: Vector2i = org + wall
		var idx: int = (gc.y - EnemyPathingScript._origin.y) * EnemyPathingScript._size.x + (gc.x - EnemyPathingScript._origin.x)
		assert(EnemyPathingScript._blocked[idx] == 1 and EnemyPathingScript._fog_blocked[idx] == 1, "yol ızgarası zindan duvarını görmüyor")
		var sc: Vector2i = org + solid
		var sidx: int = (sc.y - EnemyPathingScript._origin.y) * EnemyPathingScript._size.x + (sc.x - EnemyPathingScript._origin.x)
		assert(EnemyPathingScript._blocked[sidx] == 1 and EnemyPathingScript._fog_blocked[sidx] == 0, "zindan nesnesi görüşü kesmemeli")
		## kapı aç/kapa: hareket + yol ızgarası
		var g: Dictionary = data.objects_of("kapi")[0]
		var key: String = str(g["gate_key"])
		var cells: Array = DungeonWorldScript.gate_cells(key)
		var gp: Vector2 = DungeonWorldScript.cell_center(cells[0])
		assert(not GameManager.is_position_blocked_by_walls(gp), "açık kapı engelli")
		EnemyPathingScript.sync_cells(DungeonWorldScript.set_gate_closed(key, true))
		assert(GameManager.is_position_blocked_by_walls(gp), "kapalı kapı geçiliyor")
		var gidx: int = (cells[0].y - EnemyPathingScript._origin.y) * EnemyPathingScript._size.x + (cells[0].x - EnemyPathingScript._origin.x)
		assert(EnemyPathingScript._blocked[gidx] == 1, "kapalı kapı yol ızgarasında açık")
		EnemyPathingScript.sync_cells(DungeonWorldScript.set_gate_closed(key, false))
		assert(not GameManager.is_position_blocked_by_walls(gp) and EnemyPathingScript._blocked[gidx] == 0, "kapı geri açılmadı")
	_unload_map()


func test_manager_enter_exit_and_interactions() -> void:
	_load_map()
	GameManager.reset()
	_load_map() ## reset katman önbelleklerini sildi
	var p := FakePlayer.new()
	p.add_to_group("player")
	_main.add_child(p)
	var dm: Node = DungeonManagerScript.new()
	_main.add_child(dm)
	await get_tree().process_frame
	var id: String = "kemik_mahzeni"
	dm.set("_player", p)
	dm.call("_do_enter", id)
	assert(p.in_dungeon == id, "inmedi")
	assert(DungeonWorldScript.dungeon_at(p.global_position) == id, "doğuş zindanda değil")
	assert(not GameManager.is_position_blocked_by_walls(p.global_position), "doğuş engelli")
	var data: Resource = DungeonWorldScript.entry(id)["data"]
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
	## kaynak
	var res: String = str(DungeonDefsScript.by_id(id)["resource"])
	var nkey: String = str(data.objects_of("kaynak")[0]["node_key"])
	var before: int = GameManager.get_dungeon_resource(res)
	assert(dm.call("host_harvest", nkey, 1), "toplanmadı")
	assert(GameManager.get_dungeon_resource(res) > before, "kaynak verilmedi")
	assert(not dm.call("host_harvest", nkey, 1), "tükenen düğüm yeniden toplandı")
	## sunak: yetmezse almaz; yetince kart statı + bedel artar
	GameManager.dungeon_resources[res] = 0
	assert(not dm.call("buy_altar", id, 0), "kaynaksız alım")
	var cost: int = int(dm.call("altar_cost", id, 0))
	GameManager.add_dungeon_resource(res, cost)
	assert(dm.call("buy_altar", id, 0), "alım olmadı")
	assert(p.upgrades.size() == 1, "kart statı verilmedi")
	assert(GameManager.get_dungeon_resource(res) == 0, "bedel düşmedi")
	assert(int(dm.call("altar_cost", id, 0)) == cost + 2, "bedel artmadı")
	## çıkış: yüzeye, kapının ağzının yanına, engelsiz
	dm.call("_do_exit")
	assert(p.in_dungeon == "", "çıkmadı")
	assert(DungeonWorldScript.dungeon_at(p.global_position) == "", "yüzeye çıkmadı")
	assert(not GameManager.is_position_blocked_by_walls(p.global_position), "çıkış noktası engelli")
	GameManager.reset()
	_unload_map()


func test_guard_camps_build_dungeon_camps() -> void:
	_load_map()
	var gc: Node = GuardCampsScript.new()
	_main.add_child(gc)
	gc.call("_ensure_dungeon_camps")
	var camps: Array = gc.get("_camps")
	var per: Dictionary = {}
	var hunters: Dictionary = {}
	for c: Dictionary in camps:
		var d: Dictionary = c["def"]
		if not d.has("dungeon"):
			continue
		per[d["dungeon"]] = int(per.get(d["dungeon"], 0)) + 1
		if bool(d.get("hunter", false)):
			hunters[d["dungeon"]] = int(hunters.get(d["dungeon"], 0)) + 1
		assert(not bool(c["active"]), "kimse yokken kamp dolmamalı")
		assert((d["ids"] as Array).size() > 0, "kamp türsüz")
	for def: Dictionary in DungeonDefsScript.DUNGEONS:
		assert(int(per.get(def["id"], 0)) >= 6, "zindan kampı az: " + str(def["id"]))
		assert(int(hunters.get(def["id"], 0)) == 1, "avcı yok: " + str(def["id"]))
	## zindanda oyuncu varken YALNIZ yakınındaki kamplar + avcı etkinleşir (madde 376: tüm zindan birden doğuyordu)
	var p := FakePlayer.new()
	p.in_dungeon = "et_kuyusu"
	var dm_tmp: Node = (load("res://scripts/dungeon/dungeon_manager.gd") as GDScript).new()
	var spawn: Vector2 = dm_tmp.call("spawn_point", "et_kuyusu")
	dm_tmp.free()
	p.global_position = spawn
	gc.call("_update_dungeon_activity", [p], 0.2)
	var near_on: int = 0
	var far_off: int = 0
	for c: Dictionary in camps:
		var d2: Dictionary = c["def"]
		if not d2.has("dungeon"):
			continue
		if str(d2["dungeon"]) != "et_kuyusu":
			assert(not bool(c["active"]), "boş zindanın kampı doldu")
			continue
		var dist: float = (c["center"] as Vector2).distance_to(spawn)
		if bool(d2.get("hunter", false)):
			assert(bool(c["active"]), "avcı zindan doluyken hep açık olmalı")
		elif dist < GuardCampsScript.DUNGEON_WAKE_DIST:
			assert(bool(c["active"]) and int(c["queue"]) > 0, "yakın kamp dolmuyor")
			near_on += 1
		elif dist > GuardCampsScript.DUNGEON_SLEEP_DIST:
			assert(not bool(c["active"]), "uzak kamp boşuna doldu")
			far_off += 1
	assert(near_on >= 1 and far_off >= 1, "yakın/uzak kamp ayrımı sınanmadı (%d/%d)" % [near_on, far_off])
	## oyuncu uzaklaşınca SLEEP_AFTER sonra uyur
	p.global_position = spawn + Vector2(0, 5000)
	gc.set("_clock", float(gc.get("_clock")) + 1.0)
	gc.call("_update_dungeon_activity", [p], 0.2)
	gc.set("_clock", float(gc.get("_clock")) + GuardCampsScript.DUNGEON_SLEEP_AFTER + 1.0)
	gc.call("_update_dungeon_activity", [p], 0.2)
	for c: Dictionary in camps:
		var d3: Dictionary = c["def"]
		if d3.has("dungeon") and str(d3["dungeon"]) == "et_kuyusu" and not bool(d3.get("hunter", false)):
			assert(not bool(c["active"]), "uzaklaşan oyuncunun arkasında kamp uyumadı")
	p.free()
	_unload_map()


func test_scenes_and_props_load() -> void:
	for def: Dictionary in DungeonDefsScript.DUNGEONS:
		var id: String = def["id"]
		var root: Node2D = (load(DungeonDefsScript.SCENE_PATH % id) as PackedScene).instantiate()
		assert(root.get_node_or_null("Zemin") != null and root.get_node_or_null("Duvar") != null, id + ": katmanlar")
		assert(root.get_node_or_null("Engel") == null, id + ": Engel katmanı pişmiş sahnede kalmamalı")
		var data: Resource = _data(id)
		DungeonWorldScript.test_origin_px = Vector2.ZERO
		DungeonWorldScript.reset()
		DungeonWorldScript.ensure()
		var props: Node2D = DungeonPropsScript.new()
		props.setup(id, DungeonWorldScript.entry(id)["data"])
		var expected: int = data.objects_of("kapi").size() + data.objects_of("kaynak").size() + data.objects_of("sandik").size() + data.objects_of("tuzak").size()
		var sprites: int = 0
		for c: Node in props.get_children():
			if c is Sprite2D:
				sprites += 1
		assert(sprites >= expected, "%s: etkileşim görseli eksik (%d < %d)" % [id, sprites, expected])
		props.free()
		root.free()
	DungeonWorldScript.test_origin_px = null
	DungeonWorldScript.reset()


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
