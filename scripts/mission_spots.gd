extends RefCounted

## GÖREV KONUMLARI ZİNDAN HARİTASINDA (madde 496, 2026-11-08; kullanıcı: "oyunda zindanla uyumlu görevlerin de zindanlarda çalışmasını istiyorum
## uygun pozisyonlarda"). Ana haritada görev noktası haritanın dikdörtgeninden rastgele seçilip engelsizliğe bakılıyor (world_event_manager.gd
## _random_map_position) - zindan biçimli haritada bu yetmez: dikdörtgenin çoğu kaya (duvar hücresi), duvarların arkasında kapalı ceplerde de
## boş hücreler var, nesneler (lahit, sandık, su) GameManager.is_position_blocked_by_terrain'e görünmez. Burada:
##  - doğuş noktasından (map_profiles.gd spawn_position) YÜRÜYEREK ulaşılabilen zemin hücreleri bir kez taşma (flood fill) ile bulunur
##    (duvar / nesne / su geçilmez; kapılar geçilir - oyuncu kapıyı yalnız geçici indirir, madde 449);
##  - görev noktası bu kümeden, çevresi `clearance` yarıçapında TAMAMEN açık zemin olan bir hücre (koridor yerine salon/oda) seçilir;
##    kapı hücresi açık zemin sayılmaz (görev nesnesi indirilen parmaklığın altına düşmesin).
## Ana haritada `active()` false -> çağıran eski yolu kullanır (davranış birebir aynı).
## Önbellek harita verisine bağlı (yeni koşuda aynı harita = aynı küme); testler `build_from` ile harita sahnesi olmadan kurar.

const DungeonWorldScript := preload("res://scripts/dungeon/dungeon_world.gd")
const DungeonDataScript := preload("res://scripts/dungeon/dungeon_data.gd")
const MapProfilesScript := preload("res://scripts/map_profiles.gd")

const CELL := 16.0
const OPEN := 1 ## ulaşılabilir zemin
const GATE := 2 ## ulaşılabilir kapı hücresi (geçilir ama üstüne görev konmaz)
const PICK_ATTEMPTS := 160
const NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static var _key: String = ""
static var _data_id: int = 0 ## kayıtlı harita verisinin örnek kimliği (her sorguda metin biçimlemeden karşılaştırılır)
static var _mask: PackedByteArray = PackedByteArray()
static var _cells: PackedInt32Array = PackedInt32Array() ## OPEN hücrelerin dizinleri (rastgele seçim)
static var _w: int = 0
static var _h: int = 0
static var _origin: Vector2 = Vector2.ZERO ## (0,0) hücresinin sol üst dünya konumu


## Zindan biçimli harita mı (görev konumları buradan seçilmeli).
static func active() -> bool:
	return DungeonWorldScript.map_mode()


static func reset() -> void:
	_key = ""
	_data_id = 0
	_mask = PackedByteArray()
	_cells = PackedInt32Array()
	_w = 0
	_h = 0


## Kaçan Hazine her karede onlarca kez sorar: yalnız tamsayı karşılaştırması (eskiden her çağrıda "%s:%d" anahtarı biçimleniyordu).
static func _ensure() -> bool:
	if not DungeonWorldScript.map_mode():
		return false
	var data: Resource = DungeonWorldScript.map_entry().get("data")
	if data == null:
		return false
	var did: int = data.get_instance_id()
	if did != _data_id:
		var origin: Vector2 = DungeonWorldScript.cell_center(Vector2i.ZERO) - Vector2(CELL, CELL) * 0.5
		build_from(data, origin, MapProfilesScript.spawn_position())
		_data_id = did
		_key = str(did)
	return not _cells.is_empty()


static func _walkable(code: int) -> bool:
	return code == DungeonDataScript.CELL_EMPTY or code == DungeonDataScript.CELL_HIDE or code == DungeonDataScript.CELL_GATE


## Ulaşılabilir hücre kümesini kurar (testler doğrudan çağırır). start_world INF ise haritanın ortasına en yakın yürünür hücre.
static func build_from(data: Resource, origin: Vector2, start_world: Vector2) -> void:
	_w = int(data.size.x)
	_h = int(data.size.y)
	_origin = origin
	_wide_key = ""
	_mask = PackedByteArray()
	_mask.resize(_w * _h)
	_cells = PackedInt32Array()
	if _w <= 0 or _h <= 0:
		return
	var codes: PackedByteArray = data.cells
	var start := Vector2i(_w / 2, _h / 2)
	if start_world != Vector2.INF:
		start = Vector2i(floori((start_world.x - origin.x) / CELL), floori((start_world.y - origin.y) / CELL))
	start = _nearest_walkable(codes, start)
	if start.x < 0:
		return
	var queue := PackedInt32Array()
	var head: int = 0
	var si: int = start.y * _w + start.x
	_mask[si] = GATE if codes[si] == DungeonDataScript.CELL_GATE else OPEN
	queue.append(si)
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var x: int = i % _w
		var y: int = i / _w
		for d: Vector2i in NEIGHBORS:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or ny < 0 or nx >= _w or ny >= _h:
				continue
			var ni: int = ny * _w + nx
			if _mask[ni] != 0:
				continue
			var code: int = codes[ni]
			if not _walkable(code):
				continue
			_mask[ni] = GATE if code == DungeonDataScript.CELL_GATE else OPEN
			queue.append(ni)
	for i in queue:
		if _mask[i] == OPEN:
			_cells.append(i)


static func _nearest_walkable(codes: PackedByteArray, c: Vector2i) -> Vector2i:
	for r in range(0, 24):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x: int = c.x + dx
				var y: int = c.y + dy
				if x < 0 or y < 0 or x >= _w or y >= _h:
					continue
				var code: int = codes[y * _w + x]
				if code == DungeonDataScript.CELL_EMPTY or code == DungeonDataScript.CELL_HIDE:
					return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _cell_of(world: Vector2) -> Vector2i:
	return Vector2i(floori((world.x - _origin.x) / CELL), floori((world.y - _origin.y) / CELL))


static func _center_of(i: int) -> Vector2:
	return _origin + (Vector2(i % _w, i / _w) + Vector2(0.5, 0.5)) * CELL


static func _mask_at(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= _w or c.y >= _h:
		return 0
	return _mask[c.y * _w + c.x]


## Bu dünya noktası doğuştan yürüyerek ulaşılabilir zemin mi (kapı dahil).
static func is_reachable_world(world: Vector2) -> bool:
	if not _ensure() and _cells.is_empty():
		return false
	return _mask_at(_cell_of(world)) != 0


## world merkezli `clearance` yarıçaplı daire tamamen ulaşılabilir açık zemin mi (kapı hücresi yok).
static func is_area_open(world: Vector2, clearance: float) -> bool:
	if not _ensure() and _cells.is_empty():
		return false
	return _open_around(_cell_of(world), int(ceil(maxf(clearance, 0.0) / CELL)))


## Dizin aritmetiğiyle (Vector2i / işlev çağrısı yok): r 7'de 150 hücre, pick'in 160 denemesinde bile birkaç ms.
static func _open_around(c: Vector2i, r: int) -> bool:
	if c.x - r < 0 or c.y - r < 0 or c.x + r >= _w or c.y + r >= _h:
		return false ## harita kenarı zaten kaya
	var base: int = c.y * _w + c.x
	if _mask[base] != OPEN:
		return false
	var r2: int = r * r
	for dy in range(-r, r + 1):
		var row: int = base + dy * _w
		var span: int = int(sqrt(float(r2 - dy * dy)))
		for dx in range(-span, span + 1):
			if _mask[row + dx] != OPEN:
				return false
	return true


## Rastgele uygun görev noktası (bulunamazsa Vector2.ZERO - çağıran ana haritadaki gibi "bu tur görev yok" der).
static func pick(rng: RandomNumberGenerator, clearance: float) -> Vector2:
	if not _ensure() and _cells.is_empty():
		return Vector2.ZERO
	var r: int = int(ceil(maxf(clearance, 0.0) / CELL))
	for _attempt in range(PICK_ATTEMPTS):
		var i: int = _cells[rng.randi() % _cells.size()]
		if _open_around(Vector2i(i % _w, i / _w), r):
			return _center_of(i)
	return Vector2.ZERO


## Merkezin çevresine YÜRÜME mesafesiyle `count` nokta (Yuvaları Kapat / Ritüel kristalleri, madde 496): merkezden BFS (4 komşu, en çok
## max_d x 1,3 adım), yürüme uzaklığı min_d..max_d x 1,3 olan ve çevresi `clearance` açık hücreler, birbirinden en az `spacing` (dünya).
## Düz çizgi halkası dar tünelli haritada (Lağım Ağı) sığmıyordu (tek yuvaya düşüyordu); yürüme mesafesi tünel dönse de yakın + ulaşılabilir.
static func spots_around(rng: RandomNumberGenerator, center_world: Vector2, count: int, min_d: float, max_d: float, clearance: float,
		spacing: float, reject: Callable = Callable()) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not _ensure() and _cells.is_empty():
		return out
	var s: Vector2i = _cell_of(center_world)
	if _mask_at(s) == 0:
		return out
	var n: int = _w * _h
	var max_steps: int = int(ceil(max_d * 1.3 / CELL))
	var min_steps: int = int(min_d / CELL)
	var r: int = int(ceil(maxf(clearance, 0.0) / CELL))
	var dist := {} ## seyrek: yalnız ziyaret edilenler (küçük yarıçap)
	var si: int = s.y * _w + s.x
	dist[si] = 0
	var queue := PackedInt32Array([si])
	var head: int = 0
	var cands := PackedInt32Array()
	var offs := PackedInt32Array([1, -1, _w, -_w])
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var di: int = int(dist[i])
		if di >= min_steps and _open_around(Vector2i(i % _w, i / _w), r):
			cands.append(i)
		if di >= max_steps:
			continue
		for o: int in offs:
			var ni: int = i + o
			if ni < 0 or ni >= n or dist.has(ni) or _mask[ni] == 0:
				continue
			dist[ni] = di + 1
			queue.append(ni)
	## karıştır, aralığa uyanları açgözlü seç
	for k in range(cands.size() - 1, 0, -1):
		var j: int = rng.randi() % (k + 1)
		var tmp: int = cands[k]
		cands[k] = cands[j]
		cands[j] = tmp
	for i in cands:
		var p: Vector2 = _center_of(i)
		if reject.is_valid() and bool(reject.call(p)):
			continue
		var ok := true
		for q: Vector2 in out:
			if q.distance_to(p) < spacing:
				ok = false
				break
		if ok:
			out.append(p)
			if out.size() >= count:
				break
	return out


static func reachable_count() -> int:
	return _cells.size()


## ROTA (Gezici Işık, madde 496): start'tan yürüyerek gidilen, duvardan en az bir hücre uzak ("geniş": 8 komşusu da ulaşılabilir, _ensure_wide) hücrelerde
## BFS; yol uzunluğu min_len..max_len olan rastgele bir açık hücreye en kısa yol, görüş hattıyla sadeleştirilmiş kırık çizgi (dünya). Yoksa boş.
static func route_from(rng: RandomNumberGenerator, start_world: Vector2, min_len: float, max_len: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not _ensure() and _cells.is_empty():
		return out
	var s: Vector2i = _cell_of(start_world)
	if _mask_at(s) == 0:
		return out
	_ensure_wide()
	var n: int = _w * _h
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var parent := PackedInt32Array()
	parent.resize(n)
	var si: int = s.y * _w + s.x
	dist[si] = 0
	parent[si] = -1
	var max_steps: int = int(ceil(max_len * 1.5 / CELL))
	var min_steps: int = int(min_len / CELL)
	var queue := PackedInt32Array()
	queue.resize(n)
	queue[0] = si
	var tail: int = 1
	var head: int = 0
	var cands := PackedInt32Array()
	var offs := PackedInt32Array([1, -1, _w, -_w])
	## Dizin aritmetiğiyle BFS (Vector2i / işlev çağrısı yok - 214x214 haritada ~10 kat hızlı); geniş maske kenar hücrelerinde 0, taşma olmaz.
	while head < tail:
		var i: int = queue[head]
		head += 1
		var di: int = dist[i]
		if di >= max_steps:
			continue
		for o: int in offs:
			var ni: int = i + o
			if ni < 0 or ni >= n or dist[ni] >= 0 or _wide_mask[ni] == 0:
				continue
			dist[ni] = di + 1
			parent[ni] = i
			queue[tail] = ni
			tail += 1
			if di + 1 >= min_steps:
				cands.append(ni)
	if cands.is_empty():
		return out
	## Önce sadeleşmiş uzunluğu aralıkta olan, çevresi açık bir hedef ara (4 komşulu BFS adımı köşegende uzar), olmazsa ilk adayın yolu.
	var fallback := PackedVector2Array()
	var tries: int = 0
	while tries < 40:
		tries += 1
		var goal: int = cands[rng.randi() % cands.size()]
		if not _open_around(Vector2i(goal % _w, goal / _w), 2):
			continue
		var cells: Array[Vector2i] = []
		var k: int = goal
		while k >= 0:
			cells.append(Vector2i(k % _w, k / _w))
			k = parent[k]
		cells.reverse()
		var poly: PackedVector2Array = _simplify(cells)
		var length: float = 0.0
		for j in range(poly.size() - 1):
			length += poly[j].distance_to(poly[j + 1])
		if length >= min_len and length <= max_len * 1.2:
			return poly
		if fallback.is_empty():
			fallback = poly
	return fallback


static var _wide_mask: PackedByteArray = PackedByteArray()
static var _wide_key: String = ""


## "Geniş" hücre maskesi (kendisi + 8 komşusu ulaşılabilir) - harita başına bir kez.
static func _ensure_wide() -> void:
	var key: String = "%s:%d:%d" % [_key, _w, _cells.size()]
	if key == _wide_key and _wide_mask.size() == _w * _h:
		return
	_wide_key = key
	_wide_mask = PackedByteArray()
	_wide_mask.resize(_w * _h)
	for i in range(_w * _h):
		if _mask[i] == 0:
			continue
		var x: int = i % _w
		var y: int = i / _w
		if x < 1 or y < 1 or x >= _w - 1 or y >= _h - 1:
			continue
		if _mask[i - 1] != 0 and _mask[i + 1] != 0 and _mask[i - _w] != 0 and _mask[i + _w] != 0 				and _mask[i - _w - 1] != 0 and _mask[i - _w + 1] != 0 and _mask[i + _w - 1] != 0 and _mask[i + _w + 1] != 0:
			_wide_mask[i] = 1


## Hücre zinciri -> görüş hattıyla sadeleşmiş kırık çizgi (her parça geniş hücrelerden geçer).
static func _simplify(cells: Array[Vector2i]) -> PackedVector2Array:
	var out := PackedVector2Array()
	if cells.is_empty():
		return out
	var i: int = 0
	out.append(_center_of(cells[0].y * _w + cells[0].x))
	## İleri doğru açgözlü + dörtnala: görülebilen son hücreyi 16'lık sıçramalarla, sonra yarılayarak bul (her parça az sayıda hat yoklaması).
	while i < cells.size() - 1:
		var j: int = i + 1
		var step: int = 16
		while step >= 1:
			while j + step < cells.size() and _line_wide(cells[i], cells[j + step]):
				j += step
			step /= 2
		out.append(_center_of(cells[j].y * _w + cells[j].x))
		i = j
	return out


static func _line_wide(a: Vector2i, b: Vector2i) -> bool:
	var ax: float = a.x + 0.5
	var ay: float = a.y + 0.5
	var dx: float = b.x - a.x
	var dy: float = b.y - a.y
	var steps: int = maxi(1, int(ceil(sqrt(dx * dx + dy * dy) * 2.0)))
	for k in range(steps + 1):
		var t: float = float(k) / float(steps)
		var idx: int = floori(ay + dy * t) * _w + floori(ax + dx * t)
		if idx < 0 or idx >= _wide_mask.size() or _wide_mask[idx] == 0:
			return false
	return true
