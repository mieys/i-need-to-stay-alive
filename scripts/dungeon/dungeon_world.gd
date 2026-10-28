extends RefCounted
class_name DungeonWorld

## ZİNDAN DÜNYA KAYDI (madde 373): zindan haritalarının çarpışma/görüş/saklanma/kapı hücreleri ORMAN KATMANININ hücre ızgarasında
## (GameManager.get_forest_layer, 16 px) - ana haritanın doğusunda, aynı dünya koordinatlarında (dungeon_defs.gd `origin`).
## Tüketenler (tek kaynak burası):
##  - GameManager.is_position_blocked_by_forest: zindan DUVARI (hareket + görüş + yaratık mermisi), is_position_blocked_by_walls: + nesne/kapalı kapı;
##  - EnemyPathing._build / sync_cells: duvarlar orman hücresi gibi (hareket + sis), nesne + kapalı kapı yalnız hareket -> C++ EnemyWorld.set_grid;
##  - vision_fog.gd (VisionOccluders.build extra_cells): oyuncunun görüş sisi zindan duvarında kesilir;
##  - hide_brush.gd contains: saklanma hücreleri (açık lahit, gölge nişi...) = saklanma çalılığı kuralları.
## Kayıt tembel: ilk sorguda orman katmanı varsa üç zindanın verisi yüklenir (scenes/zindan/<id>_data.tres). Yeni koşuda GameManager.reset -> reset().

const DungeonDefsScript := preload("res://scripts/dungeon/dungeon_defs.gd")
const DungeonDataScript := preload("res://scripts/dungeon/dungeon_data.gd")

static var _registered: bool = false
static var _layer_id: int = 0
static var _origin_px: Vector2 = Vector2.ZERO ## orman katmanının (0,0) hücresinin sol üst dünya konumu
static var _cell_px: float = 16.0
static var _dungeons: Array[Dictionary] = [] ## {id, index, def, data, origin: Vector2i, rect: Rect2 (dünya)}
static var _walls: Dictionary = {} ## Vector2i -> true
static var _solid: Dictionary = {} ## Vector2i -> true (nesne / su)
static var _hide: Dictionary = {} ## Vector2i -> true
static var _gate_of_cell: Dictionary = {} ## Vector2i -> kapı anahtarı ("<id>:<n>")
static var _gate_cells: Dictionary = {} ## kapı anahtarı -> Array[Vector2i]
static var _gate_closed: Dictionary = {} ## kapı anahtarı -> true
## Testler: harita olmadan kayıt (orman katmanı yoksa bu köken/hücre kullanılır).
static var test_origin_px: Variant = null


static func reset() -> void:
	_registered = false
	_layer_id = 0
	_dungeons.clear()
	_walls.clear()
	_solid.clear()
	_hide.clear()
	_gate_of_cell.clear()
	_gate_cells.clear()
	_gate_closed.clear()


## Kayıt (gerekirse). Orman katmanı yoksa (menü/test) false.
static func ensure() -> bool:
	var layer: TileMapLayer = GameManager.get_forest_layer()
	if layer == null:
		if test_origin_px == null:
			return false
		if not _registered:
			_register(test_origin_px, 16.0)
		return true
	if _registered and _layer_id == layer.get_instance_id():
		return true
	reset()
	_layer_id = layer.get_instance_id()
	var o: Vector2 = layer.to_global(Vector2.ZERO)
	var cw: float = layer.to_global(Vector2(float(layer.tile_set.tile_size.x) if layer.tile_set != null else 16.0, 0.0)).x - o.x
	_register(o, cw)
	return true


static func _register(origin_px: Vector2, cell_px: float) -> void:
	_registered = true
	_origin_px = origin_px
	_cell_px = cell_px
	for i in range(DungeonDefsScript.DUNGEONS.size()):
		var def: Dictionary = DungeonDefsScript.DUNGEONS[i]
		var path: String = DungeonDefsScript.DATA_PATH % str(def["id"])
		if not ResourceLoader.exists(path):
			continue
		var data: Resource = load(path)
		if data == null:
			continue
		var org: Vector2i = def["origin"]
		var rect := Rect2(_origin_px + Vector2(org) * _cell_px, Vector2(data.size) * _cell_px)
		_dungeons.append({"id": str(def["id"]), "index": i, "def": def, "data": data, "origin": org, "rect": rect})
		var w: int = data.size.x
		var cells: PackedByteArray = data.cells
		var gate_n: int = 0
		var counters: Dictionary = {}
		for o: Dictionary in data.objects:
			var typ: String = str(o.get("type", ""))
			var field: String = {"kaynak": "node_key", "sandik": "chest_key", "tuzak": "trap_key", "sunak": "altar_key"}.get(typ, "")
			if field != "":
				var n: int = int(counters.get(typ, 0))
				counters[typ] = n + 1
				o[field] = "%s:%s%d" % [def["id"], typ.substr(0, 1), n]
			if typ != "kapi":
				continue
			var key: String = "%s:%d" % [def["id"], gate_n]
			gate_n += 1
			var r: Rect2 = o["rect"]
			var list: Array[Vector2i] = []
			for yy in range(int(r.position.y / 16.0), int(r.end.y / 16.0)):
				for xx in range(int(r.position.x / 16.0), int(r.end.x / 16.0)):
					var gc := Vector2i(xx, yy) + org
					list.append(gc)
					_gate_of_cell[gc] = key
			_gate_cells[key] = list
			o["gate_key"] = key
		for idx in range(cells.size()):
			var code: int = cells[idx]
			if code == 0:
				continue
			var c := Vector2i(idx % w, idx / w) + org
			match code:
				DungeonDataScript.CELL_WALL:
					_walls[c] = true
				DungeonDataScript.CELL_SOLID, DungeonDataScript.CELL_WATER:
					_solid[c] = true
				DungeonDataScript.CELL_HIDE:
					_hide[c] = true


static func cell_of(world: Vector2) -> Vector2i:
	return Vector2i(floori((world.x - _origin_px.x) / _cell_px), floori((world.y - _origin_px.y) / _cell_px))


static func cell_center(c: Vector2i) -> Vector2:
	return _origin_px + (Vector2(c) + Vector2(0.5, 0.5)) * _cell_px


static func is_wall_world(world: Vector2) -> bool:
	if not ensure() or _walls.is_empty():
		return false
	return _walls.has(cell_of(world))


## Hareket engeli: duvar + nesne + KAPALI kapı.
static func is_move_blocked_world(world: Vector2) -> bool:
	if not ensure() or _dungeons.is_empty():
		return false
	return is_move_blocked_cell(cell_of(world))


## Hızlı yollar (GameManager hücreyi zaten orman katmanından hesapladı - aynı ızgara).
static func has_wall_cell(c: Vector2i) -> bool:
	if not _registered and not ensure():
		return false
	return _walls.has(c)


static func is_move_blocked_cell(c: Vector2i) -> bool:
	if not _registered and not ensure():
		return false
	if _walls.has(c) or _solid.has(c):
		return true
	var k: Variant = _gate_of_cell.get(c)
	return k != null and _gate_closed.has(k)


static func is_hide_world(world: Vector2) -> bool:
	if not ensure() or _hide.is_empty():
		return false
	return _hide.has(cell_of(world))


static func wall_cells() -> Array[Vector2i]:
	ensure()
	var out: Array[Vector2i] = []
	out.assign(_walls.keys())
	return out


## Yalnız hareketi kesen hücreler (nesne + şu an kapalı kapılar).
static func solid_cells() -> Array[Vector2i]:
	ensure()
	var out: Array[Vector2i] = []
	out.assign(_solid.keys())
	for k: String in _gate_closed.keys():
		out.append_array(_gate_cells.get(k, []))
	return out


static func dungeons() -> Array[Dictionary]:
	ensure()
	return _dungeons


static func entry(id: String) -> Dictionary:
	ensure()
	for d: Dictionary in _dungeons:
		if str(d["id"]) == id:
			return d
	return {}


## Dünya konumu hangi zindanda ("" = ana harita).
static func dungeon_at(world: Vector2) -> String:
	if not ensure():
		return ""
	for d: Dictionary in _dungeons:
		if (d["rect"] as Rect2).has_point(world):
			return str(d["id"])
	return ""


static func rect_of(id: String) -> Rect2:
	var e: Dictionary = entry(id)
	return e["rect"] if not e.is_empty() else Rect2()


## Zindan yerel px (TMX nesne koordinatı) -> dünya.
static func local_to_world(id: String, local_px: Vector2) -> Vector2:
	var e: Dictionary = entry(id)
	if e.is_empty():
		return local_px
	return (e["rect"] as Rect2).position + local_px * (_cell_px / 16.0)


## C++ EnemyWorld.set_region_rects biçimi: [x, y, w, h] * n (bölge = dizin + 1).
static func region_rects() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for d: Dictionary in dungeons():
		var r: Rect2 = d["rect"]
		out.append_array([r.position.x, r.position.y, r.size.x, r.size.y])
	return out


static func gate_cells(key: String) -> Array:
	return _gate_cells.get(key, [])


static func is_gate_closed(key: String) -> bool:
	return _gate_closed.has(key)


## Kapıyı aç/kapa: değişen hücreler döner (çağıran yol ızgarasını eşitler: EnemyPathing.sync_cells + köprü reload_grid).
static func set_gate_closed(key: String, closed: bool) -> Array:
	if closed == _gate_closed.has(key):
		return []
	if closed:
		_gate_closed[key] = true
	else:
		_gate_closed.erase(key)
	return _gate_cells.get(key, [])
