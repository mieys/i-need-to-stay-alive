extends RefCounted

## Yaratıkların orman katmanı duvarlarını (plato/uçurum kayaları) DOLANIP oyuncuyu
## bulması için yol bulma (kullanıcı bildirimi: "yaratıklar collision shapelerin
## etrafından dolanıp beni bulmayı akıl edemiyor"). Kök neden: yaratıklar oyuncuya
## DÜZ çizgide yürüyor, enemy.gd _block_movement_into_terrain sadece duvara giren
## ekseni iptal ediyor -> içbükey bir kayalığın önünde/cebinde takılıp kalıyorlardı;
## _steer_around_obstacle (rastgele yana dönme) büyük bir duvarın ötesini göremez.
##
## Yöntem: orman katmanından bir engel ızgarası kurulur (vision_occluders.gd /
## GameManager.is_position_blocked_by_forest ile AYNI katman - harita Tiled'da
## değişip yeniden bake edilince otomatik güncel kalır) ve Godot'un YEREL (C++)
## AStarGrid2D'si kullanılır. Ölçüm (gerçek harita, editör derlemesi): yol başına
## ort. ~95 µs (medyan 15 µs, p95 0.4 ms), ızgara kurulumu tek seferlik ~10-30 ms;
## aynı işi GDScript BFS ile "flow field" olarak yapmak 91x91 pencerede 32 ms/hesap
## sürüyordu - o yüzden yerel A* seçildi.
##
## Yaratık tarafı (enemy.gd _route_direction): oyuncuya düz çizgi AÇIKKEN hiçbir şey
## değişmez (bugünkü davranış); sadece bir duvar araya girince ve seyrek aralıklarla
## (bkz. enemy.gd ROUTE_*) find_path çağrılıp dönüş noktalarını izler. Yaratık
## simülasyonu zaten sadece host'ta çalışıyor (bkz. enemy.gd _physics_process), ağ
## tarafına dokunulmaz.
##
## Sınırlar / emniyetler:
##  - Kare başına en fazla MAX_NEW_PATHS_PER_FRAME yeni yol (bkz. can_request).
##  - Yol bulunamazsa (kapalı cep, hedef duvar içinde ve yakında boş hücre yok...)
##    boş dizi döner; yaratık bugünkü davranışa düşer ve bir süre tekrar denemez.
##  - Yaratık zaten duvar hücresinin İÇİNDEYSE yol aranmaz (enemy.gd/player.gd'deki
##    "içerideyse engelleme atlanır" güvenlik ağıyla tutarlı).
##
## Su/ev bilerek DAHİL DEĞİL: onlar şu an yaratıklar için geçilebilir (bkz.
## enemy.gd _block_movement_into_terrain). Onlar yeniden kapatılırsa _build içindeki
## engel kümesine eklenmesi yeterli.

## Aramaya izin verilen en uzak yaratık-hedef mesafesi (dünya birimi). Doğuş halkası
## 480-640 (bkz. enemy_spawner.gd); çok uzaktaki yaratıklar zaten ekran dışı.
const MAX_ROUTE_DISTANCE := 1600.0
## Aynı fizik karesinde başlatılabilecek en fazla yeni A* araması (kare başına maliyet
## tavanı - 80+ yaratık aynı anda yeniden planlasa da sıçrama olmaz).
const MAX_NEW_PATHS_PER_FRAME := 4
## Duvara bitişik (8 komşuluk) boş hücrelerin A* maliyet çarpanı: yol, duvarı sıyırmak
## yerine mümkünse biraz açıktan gider ama dar geçitten de geçebilir.
const WALL_ADJACENT_WEIGHT := 2.0
## Yol sadeleştirmede (string-pulling) bir noktadan en fazla kaç dönüş noktası ileriye
## düz çizgi denenir.
const SMOOTH_LOOKAHEAD := 16
## Hedef duvar hücresinin içindeyse (oyuncu kayalığın üstünde) en yakın boş hücre bu
## yarıçapta (hücre) aranır.
const GOAL_SEARCH_RADIUS := 4
## Izgarayı harita sınırının dışına taşıran pay (hücre): dış kenardan dolanmak için.
const GRID_MARGIN := 24

## Testler kapatabilsin diye (kapalıyken hiç yol/çizgi engeli raporlanmaz). Bir `const`
## ile preload edilmiş script'e doğrudan atama yapılamadığı için set_enabled kullanılır.
static var enabled: bool = true


static func set_enabled(value: bool) -> void:
	enabled = value

static var _astar: AStarGrid2D = null
static var _layer: TileMapLayer = null
static var _blocked: PackedByteArray = PackedByteArray()
static var _origin: Vector2i = Vector2i.ZERO
static var _size: Vector2i = Vector2i.ZERO
static var _frame: int = -1
static var _paths_this_frame: int = 0


## Izgarayı önceden kurar (ilk isteğin maliyeti oyun sırasında hissedilmesin diye
## harita yüklenince çağrılabilir). Katman yoksa/boşsa false.
static func prepare() -> bool:
	return _ensure_grid()


## Testler: kurulu ızgarayı at (bir sonraki çağrıda yeniden kurulur).
static func reset() -> void:
	_astar = null
	_layer = null
	_blocked = PackedByteArray()
	_frame = -1
	_paths_this_frame = 0


## Bu fizik karesinde yeni bir yol araması başlatılabilir mi (bütçe)? Çağıran, gerçekten
## find_path çağırınca bütçeyi tüketir (find_path kendisi sayar).
static func can_request() -> bool:
	_roll_frame()
	return _paths_this_frame < MAX_NEW_PATHS_PER_FRAME


## Testler için: gerçek fizik karesi ilerlemeden bütçeyi sıfırlar.
static func reset_budget() -> void:
	_paths_this_frame = 0


## Dünya konumundaki ızgara hücresi (ızgara yoksa Vector2i.MAX).
static func world_to_cell(world: Vector2) -> Vector2i:
	if not _ensure_grid():
		return Vector2i.MAX
	return _layer.local_to_map(_layer.to_local(world))


## from -> to düz çizgisi bir orman duvarı hücresinden geçiyor mu? Başlangıç ve BİTİŞ
## hücreleri sayılmaz (yaratık/oyuncu duvar kenarındaki/içindeki bir hücredeyse çizgi
## "engelli" sayılmasın - hareket zaten onların üstünde engelleme atlar). Izgara yoksa
## ya da kapalıysa false.
static func line_blocked(from: Vector2, to: Vector2) -> bool:
	if not _ensure_grid() or _astar == null:
		return false
	var a: Vector2 = _world_to_cell_f(from)
	var b: Vector2 = _world_to_cell_f(to)
	return _cells_line_blocked(a, b)


## from -> to için dönüş noktaları (dünya konumları, başlangıç HARİÇ, hedef hücresi
## DAHİL). Yol yok / gerekmiyor / imkânsızsa boş dizi. Kare bütçesini tüketir.
static func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not _ensure_grid() or _astar == null:
		return out
	_roll_frame()
	_paths_this_frame += 1
	var a: Vector2i = _layer.local_to_map(_layer.to_local(from))
	var b: Vector2i = _layer.local_to_map(_layer.to_local(to))
	if not _in_bounds(a) or not _in_bounds(b):
		return out
	if _is_solid(a):
		return out ## zaten duvarın içinde - bkz. dosya başı not
	if _is_solid(b):
		b = _nearest_free_cell(b)
		if b == Vector2i.MAX:
			return out
	if a == b:
		return out
	var ids: Array[Vector2i] = _astar.get_id_path(a, b)
	if ids.size() < 2:
		return out
	return _smooth(ids)


## Hücre merkezi (dünya).
static func cell_to_world(cell: Vector2i) -> Vector2:
	return _layer.to_global(_layer.map_to_local(cell))


# ---------------------------------------------------------------------------


static func _roll_frame() -> void:
	var f: int = Engine.get_physics_frames()
	if f != _frame:
		_frame = f
		_paths_this_frame = 0


static func _ensure_grid() -> bool:
	if not enabled:
		return false
	var layer: TileMapLayer = GameManager.get_forest_layer()
	if layer == null:
		return false
	if _layer == layer and _astar != null:
		return true
	if _layer == layer and _astar == null and _blocked.size() == 0 and _size != Vector2i.ZERO:
		return false ## katman boş - tekrar tekrar kurmaya çalışma
	_build(layer)
	return _astar != null


static func _build(layer: TileMapLayer) -> void:
	_layer = layer
	_astar = null
	_blocked = PackedByteArray()
	var used: Array[Vector2i] = layer.get_used_cells()
	if used.is_empty():
		_size = Vector2i.ONE ## "boş katman" işareti (bkz. _ensure_grid)
		return
	var mn: Vector2i = used[0]
	var mx: Vector2i = used[0]
	for cell: Vector2i in used:
		mn = Vector2i(mini(mn.x, cell.x), mini(mn.y, cell.y))
		mx = Vector2i(maxi(mx.x, cell.x), maxi(mx.y, cell.y))
	var margin := Vector2i(GRID_MARGIN, GRID_MARGIN)
	_origin = mn - margin
	_size = (mx - mn) + Vector2i.ONE + margin * 2
	_blocked.resize(_size.x * _size.y)
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(_origin, _size)
	astar.cell_size = Vector2.ONE
	## Çapraz adım SADECE iki komşu da boşsa: dar köşe/çapraz boşluktan sızma yok (bu
	## mod 4-komşuluk bağlantısını değiştirmez, sadece çaprazları kısıtlar).
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for cell: Vector2i in used:
		astar.set_point_solid(cell, true)
		_blocked[(cell.y - _origin.y) * _size.x + (cell.x - _origin.x)] = 1
	## Duvara bitişik boş hücrelere hafif ek maliyet (her hücre bir kez). Dictionary yerine
	## bayt dizisiyle işaretleniyor: kurulum ~100 ms'den (Dictionary) belirgin şekilde düşüyor.
	var near := PackedByteArray()
	near.resize(_size.x * _size.y)
	for cell: Vector2i in used:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var nx: int = cell.x + dx - _origin.x
				var ny: int = cell.y + dy - _origin.y
				if nx < 0 or ny < 0 or nx >= _size.x or ny >= _size.y:
					continue
				var idx: int = ny * _size.x + nx
				if near[idx] != 0 or _blocked[idx] != 0:
					continue
				near[idx] = 1
				astar.set_point_weight_scale(Vector2i(cell.x + dx, cell.y + dy), WALL_ADJACENT_WEIGHT)
	_astar = astar


static func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= _origin.x and cell.y >= _origin.y \
			and cell.x < _origin.x + _size.x and cell.y < _origin.y + _size.y


static func _is_solid(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return false
	return _blocked[(cell.y - _origin.y) * _size.x + (cell.x - _origin.x)] != 0


## Dünya konumu -> kesirli hücre koordinatı (hücre merkezi = tam sayı + 0.5).
static func _world_to_cell_f(world: Vector2) -> Vector2:
	var local: Vector2 = _layer.to_local(world)
	var ts: Vector2 = Vector2(_layer.tile_set.tile_size)
	return Vector2(local.x / ts.x, local.y / ts.y)


## a -> b (kesirli hücre koordinatları) düz çizgisi engelli bir hücreden geçiyor mu?
## Amanatides-Woo DDA: segmentin dokunduğu HER hücre ziyaret edilir (köşe sızması
## yok). Başlangıç ve bitiş hücreleri sayılmaz.
static func _cells_line_blocked(a: Vector2, b: Vector2) -> bool:
	## PERF: sıcak döngü (A* sadeleştirme + yaratık başına düz-çizgi kontrolü) - _is_solid/
	## _in_bounds çağrıları ve Vector2i geçicileri yerine yerel int'lerle; davranış aynı.
	var d: Vector2 = b - a
	var cx: int = floori(a.x)
	var cy: int = floori(a.y)
	var ex: int = floori(b.x)
	var ey: int = floori(b.y)
	if cx == ex and cy == ey:
		return false
	var sx: int = 1 if d.x > 0.0 else -1
	var sy: int = 1 if d.y > 0.0 else -1
	var inv_x: float = 1.0 / maxf(absf(d.x), 0.000001)
	var inv_y: float = 1.0 / maxf(absf(d.y), 0.000001)
	var t_x: float = ((cx + 1 - a.x) if d.x > 0.0 else (a.x - cx)) * inv_x
	var t_y: float = ((cy + 1 - a.y) if d.y > 0.0 else (a.y - cy)) * inv_y
	var ox: int = _origin.x
	var oy: int = _origin.y
	var w: int = _size.x
	var h: int = _size.y
	var blocked: PackedByteArray = _blocked
	## Üst sınır: çizgi uzunluğu kadar hücre + pay (sonsuz döngüye karşı).
	var max_steps: int = int(absf(d.x) + absf(d.y)) + 4
	for _i: int in range(max_steps):
		if t_x < t_y:
			cx += sx
			t_x += inv_x
		else:
			cy += sy
			t_y += inv_y
		if cx == ex and cy == ey:
			return false
		var lx: int = cx - ox
		var ly: int = cy - oy
		if lx >= 0 and ly >= 0 and lx < w and ly < h and blocked[ly * w + lx] != 0:
			return true
	return false


static func _nearest_free_cell(from_cell: Vector2i) -> Vector2i:
	for r: int in range(1, GOAL_SEARCH_RADIUS + 1):
		var best: Vector2i = Vector2i.MAX
		var best_d: int = 1 << 30
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := Vector2i(from_cell.x + dx, from_cell.y + dy)
				if not _in_bounds(c) or _is_solid(c):
					continue
				var dd: int = dx * dx + dy * dy
				if dd < best_d:
					best_d = dd
					best = c
		if best != Vector2i.MAX:
			return best
	return Vector2i.MAX


## Hücre yolunu, düz çizgiyle erişilebilen en uzak noktaya atlayarak sadeleştirir
## (string-pulling) - basamaklı ızgara zikzağı yerine doğal, az dönüş noktalı bir yol.
static func _smooth(ids: Array[Vector2i]) -> PackedVector2Array:
	var out := PackedVector2Array()
	var i: int = 0
	var last: int = ids.size() - 1
	while i < last:
		var j: int = mini(i + SMOOTH_LOOKAHEAD, last)
		while j > i + 1:
			var pa := Vector2(ids[i]) + Vector2(0.5, 0.5)
			var pb := Vector2(ids[j]) + Vector2(0.5, 0.5)
			if not _cells_line_blocked(pa, pb):
				break
			j -= 1
		out.append(cell_to_world(ids[j]))
		i = j
	return out
