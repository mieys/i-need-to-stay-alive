extends NpcActor
class_name BlacksmithNpc

## DEMİRCİ NPC'si (kullanıcı isteği 2026-10-13, madde 112): demirci dükkanının (weapon_shop.gd iç mekanı) içinde yaşar.
##  - İÇERİDE OYUNCU YOKKEN: raflara bakar gibi dolaşır - SHELF_SPOTS'tan rastgele bir noktaya yürür, rafa dönük durur, sonra bir diğerine geçer.
##  - OYUNCU İÇERİ GİRİNCE: selam verir (konuşma balonu, oyuncuya döner), örse doğru yürür, ÖRSÜN ARKASINDA (kuzeyinde) örse doğru
##    (aşağı) dönüp "strike_down" klibini döngüde oynar (çekiçle örse vurma).
##  - OYUNCU ÇIKIŞ KAPISINA YAKLAŞINCA (örsten uzaklaşıp kapıya dönünce): çekici bırakıp oyuncuya döner, "hoşça kal" der, sonra işine döner.
##  - Herkes çıkınca: iç mekan zaten gizli; demirci rastgele bir raf noktasına geri alınır (bir sonraki girişte örse yürüyüşü görünsün).
## Yol bulma: iç mekanın çarpışma hücrelerinden (weapon_shop.gd _collision_cells) AStarGrid2D - mobilyaların/duvarların içinden geçmez.
## Tamamen yerel/kozmetik (ağ yok): her istemci demircisini kendi başına çalıştırır; "içeride kim var" oyuncu konumlarından türetilir.

const FRAMES: SpriteFrames = preload("res://assets/npc/demirci/demirci_frames.tres")

enum State { REST_LOOK, REST_WALK, GREET, TO_ANVIL, WORK, FAREWELL }

## Dükkanın içinde bulunmak: oyuncu bu kadar yakınsa (iç mekan kökünden) dükkandadır. weapon_shop.gd is_interior_position() ile AYNI eşik
## (iç mekan haritadan 24000 birim uzakta, bkz. INTERIOR_OFFSET).
const INSIDE_RADIUS := 3000.0
## Örsün işaretçi hücresinin merkezinden (weapon_shop _anvil_local) demircinin AYAK noktasına: örsün demir yüzeyinin hemen arkası (kuzey);
## çekiç aşağı-sağa iner, bu yüzden ayak örsün üst kenarına değer (gerçek görüntüde ölçüldü: ayak y ~ -64, demir yüzey ~ -63).
const WORK_OFFSET := Vector2(0.0, 8.0)
## Raf noktaları: iç mekan yerel ayak koordinatı + bakış yönü (rafa/duvara). weapon_shop.gd tüm noktaların yürünebilir olduğunu sınar (test_npc_actors).
const SHELF_SPOTS: Array = [
	{"pos": Vector2(-8.0, 8.0), "face": "down"}, ## zırh standı (güney)
	{"pos": Vector2(40.0, 8.0), "face": "down"}, ## kılıçlı masa
	{"pos": Vector2(104.0, 8.0), "face": "down"}, ## silah rafı (güneydoğu)
	{"pos": Vector2(120.0, -8.0), "face": "right"}, ## doğu rafı
	{"pos": Vector2(24.0, -24.0), "face": "up"}, ## ocak
]
const GREETINGS: Array[String] = ["Hoş geldin, dostum!", "Selam! Buyur, silahlara bak.", "Hoş geldiniz!"]
const FAREWELLS: Array[String] = ["Hoşça kal!", "Güle güle, dostum!", "Yolun açık olsun!"]
const GREET_TIME := 1.3
const FAREWELL_TIME := 1.8
const LOOK_TIME_MIN := 3.0
const LOOK_TIME_MAX := 7.0
## Çıkış kapısı: oyuncu kapıdan en az ARM_DISTANCE uzaklaşmış olmalı (içeri girdiği noktada kapıya zaten yakındır), sonra NEAR_DISTANCE'a
## dönünce vedalaşılır. Mesafeler gövde merkezi - kapı merkezi arası (dünya px).
const DOOR_ARM_DISTANCE := 100.0
const DOOR_NEAR_DISTANCE := 62.0
const FAREWELL_COOLDOWN := 6.0

var state: State = State.REST_LOOK
var _walkable: Dictionary = {} ## Vector2i hücre -> true (yürünebilir)
var _grid: AStarGrid2D = null
var _main_cells: Dictionary = {} ## ilk raf noktasından ulaşılabilen hücreler (8 komşu, köşe kesmeden): yol bulmanın "açık zemin"i
var _tile: Vector2 = Vector2(16.0, 16.0)
var _anvil_local: Vector2 = Vector2.ZERO
var _door_local: Vector2 = Vector2.ZERO
var _timer: float = 0.0
var _spot_index: int = -1
var _was_occupied: bool = false
var _door_armed: Dictionary = {} ## oyuncu düğümü örnek kimliği -> bool
var _farewell_cd: float = 0.0
var _farewell_target: Node2D = null


## weapon_shop.gd çağırır (ebeveyn = iç mekan kökü, yerel koordinatlar iç mekan yereli).
## walkable: yürünebilir hücreler (zemin - çarpışma - kapı), tile: hücre boyu, anvil_local: "Eleman pozisyon" karosunun merkezi,
## door_local: çıkış kapısı hücrelerinin merkezi.
func configure(walkable: Dictionary, tile: Vector2, anvil_local: Vector2, door_local: Vector2) -> void:
	setup(FRAMES)
	name = "BlacksmithNpc"
	_walkable = walkable
	_tile = tile
	_anvil_local = anvil_local
	_door_local = door_local
	_build_grid()
	_spot_index = -1
	_enter_rest(true)


## Örsün arkasındaki çalışma noktası (ayak, iç mekan yereli).
func work_feet() -> Vector2:
	return _anvil_local + WORK_OFFSET


func _build_grid() -> void:
	if _walkable.is_empty():
		_grid = null
		return
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for c: Vector2i in _walkable:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(lo, hi - lo + Vector2i.ONE)
	_grid.cell_size = _tile
	_grid.offset = _tile * 0.5
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			if not _walkable.has(Vector2i(x, y)):
				_grid.set_point_solid(Vector2i(x, y), true)
	_main_cells = _flood_from(_nearest_walkable(cell_of(SHELF_SPOTS[0]["pos"])))


## start'tan ulaşılabilen yürünebilir hücreler (köşegen adım iki dik komşu da açıksa).
func _flood_from(start: Vector2i) -> Dictionary:
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var n := Vector2i(c.x + dx, c.y + dy)
				if seen.has(n) or not _walkable.has(n):
					continue
				if dx != 0 and dy != 0 and (not _walkable.has(Vector2i(c.x + dx, c.y)) or not _walkable.has(Vector2i(c.x, c.y + dy))):
					continue
				seen[n] = true
				queue.append(n)
	return seen


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / _tile.x), floori(p.y / _tile.y))


## En yakın yürünebilir hücre (p'nin hücresi yürünebilirse o).
func _nearest_walkable(c: Vector2i) -> Vector2i:
	return _nearest_in(_walkable, c)


func _nearest_in(cells: Dictionary, c: Vector2i) -> Vector2i:
	if cells.has(c):
		return c
	var best: Vector2i = c
	var best_d: int = 1 << 30
	for w: Vector2i in cells:
		var d: int = (w - c).length_squared()
		if d < best_d:
			best_d = d
			best = w
	return best


## Ayak noktasından hedefe yol (ayak noktaları; ilk nokta = mevcut hücre atlanır, son nokta tam hedef). Izgara yoksa doğrudan çizgi.
## Başlangıç ya da hedef açık zeminden AYRI bir cepteyse (örsün arkası: oyuncu oraya fiziksel olarak giremez, çarpışma ayak izleriyle kapalı)
## cep ile en yakın açık hücre arası düz bir adım dizisi kullanılır (kapalı hücreye en az değen giriş seçilir), açık zeminde A*.
func path_to(target: Vector2) -> PackedVector2Array:
	if _grid == null:
		return PackedVector2Array([target])
	var out := PackedVector2Array()
	var here: Vector2 = feet()
	var start: Vector2i = cell_of(here)
	if not _main_cells.has(start):
		start = _pocket_entry(start, here)
		out.append_array(_line_steps(here, _center_of(start)))
		out.append(_center_of(start))
	var tc: Vector2i = cell_of(target)
	if _main_cells.has(tc):
		var pts: PackedVector2Array = _astar_points(start, tc)
		if not pts.is_empty():
			pts.remove_at(pts.size() - 1)
		out.append_array(pts)
		out.append(target)
		return out
	var entry: Vector2i = _pocket_entry(tc, target)
	out.append_array(_astar_points(start, entry))
	out.append_array(_line_steps(_center_of(entry), target))
	out.append(target)
	return out


## from -> to arasında hücre adımı sıklığında ara noktalar (from ve to hariç).
func _line_steps(from: Vector2, to: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var steps: int = maxi(1, int(ceil(maxf(absf(to.x - from.x) / _tile.x, absf(to.y - from.y) / _tile.y))))
	for i in range(1, steps):
		out.append(from.lerp(to, float(i) / float(steps)))
	return out


## a'dan b'ye hücre merkezleri (a'nın kendisi hariç); yol yoksa boş.
func _astar_points(a: Vector2i, b: Vector2i) -> PackedVector2Array:
	var out := PackedVector2Array()
	var pts: PackedVector2Array = _grid.get_point_path(a, b)
	for i in range(1, pts.size()):
		out.append(pts[i])
	return out


func _center_of(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * _tile


## Cepteki hedefe giriş: hedefe 3 hücre içindeki açık hücreler arasında, hedefe düz çizgide en az kapalı örnek taşıyan (eşitse en yakın).
func _pocket_entry(tc: Vector2i, target: Vector2) -> Vector2i:
	var best: Vector2i = _nearest_in(_main_cells, tc)
	var best_key: Vector2 = Vector2(INF, INF)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var c := Vector2i(tc.x + dx, tc.y + dy)
			if not _main_cells.has(c):
				continue
			var from: Vector2 = _center_of(c)
			var blocked: int = 0
			var n: int = maxi(2, int(from.distance_to(target) / 4.0))
			for i in range(1, n):
				if not _walkable.has(cell_of(from.lerp(target, float(i) / float(n)))):
					blocked += 1
			var key := Vector2(float(blocked), from.distance_squared_to(target))
			if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
				best_key = key
				best = c
	return best


# ------------------------------------------------------------------ davranış

func _behave(delta: float) -> void:
	_farewell_cd = maxf(0.0, _farewell_cd - delta)
	var inside: Array[Node2D] = _players_inside()
	var occupied: bool = not inside.is_empty()
	if occupied and not _was_occupied:
		_on_entered(inside)
	elif not occupied and _was_occupied:
		_enter_rest(not _interior_visible())
	_was_occupied = occupied
	match state:
		State.REST_LOOK:
			_timer -= delta
			if _timer <= 0.0:
				_next_spot()
		State.REST_WALK:
			pass ## varış `arrived` ile
		State.GREET:
			_timer -= delta
			_face_nearest(inside)
			if _timer <= 0.0:
				_go_to_anvil()
		State.TO_ANVIL:
			pass
		State.WORK:
			_check_farewell(inside)
		State.FAREWELL:
			_timer -= delta
			if is_instance_valid(_farewell_target):
				face_point(_to_local_feet(_farewell_target))
			if _timer <= 0.0:
				_resume_work()


func _on_entered(inside: Array[Node2D]) -> void:
	state = State.GREET
	_timer = GREET_TIME
	stop_walking()
	unlock_clip()
	_face_nearest(inside)
	say(GREETINGS[randi() % GREETINGS.size()])
	_door_armed.clear()


func _go_to_anvil() -> void:
	state = State.TO_ANVIL
	var p: PackedVector2Array = path_to(work_feet())
	if not arrived.is_connected(_on_arrived):
		arrived.connect(_on_arrived)
	walk_path(p)


func _on_arrived() -> void:
	match state:
		State.TO_ANVIL:
			_start_work()
		State.REST_WALK:
			state = State.REST_LOOK
			_timer = randf_range(LOOK_TIME_MIN, LOOK_TIME_MAX)
			play_idle(String(SHELF_SPOTS[_spot_index]["face"]) if _spot_index >= 0 else "up")


func _start_work() -> void:
	state = State.WORK
	set_feet(work_feet())
	lock_clip("strike", "down") ## örsün arkasından örse (aşağı) dönük


func _resume_work() -> void:
	if _players_inside().is_empty():
		_enter_rest(false)
		return
	_start_work()


## Boşta: raf noktası seç (snap: gizli iç mekanda anında oraya git; görünürken yürü).
func _enter_rest(snap: bool) -> void:
	unlock_clip()
	if not arrived.is_connected(_on_arrived):
		arrived.connect(_on_arrived)
	state = State.REST_LOOK
	_timer = randf_range(LOOK_TIME_MIN, LOOK_TIME_MAX)
	var i: int = _pick_spot()
	if i < 0:
		return
	_spot_index = i
	var spot: Dictionary = SHELF_SPOTS[i]
	if snap or not _interior_visible():
		stop_walking()
		set_feet(spot["pos"])
		play_idle(String(spot["face"]))
	else:
		state = State.REST_WALK
		walk_path(path_to(spot["pos"]))


func _next_spot() -> void:
	var i: int = _pick_spot()
	if i < 0:
		_timer = randf_range(LOOK_TIME_MIN, LOOK_TIME_MAX)
		return
	_spot_index = i
	state = State.REST_WALK
	walk_path(path_to(SHELF_SPOTS[i]["pos"]))


func _pick_spot() -> int:
	if SHELF_SPOTS.is_empty():
		return -1
	if SHELF_SPOTS.size() == 1:
		return 0
	var i: int = randi() % SHELF_SPOTS.size()
	if i == _spot_index:
		i = (i + 1) % SHELF_SPOTS.size()
	return i


func _check_farewell(inside: Array[Node2D]) -> void:
	var live: Dictionary = {}
	for p: Node2D in inside:
		var id: int = p.get_instance_id()
		live[id] = true
		var d: float = (p.global_position - get_parent().to_global(_door_local)).length()
		if d > DOOR_ARM_DISTANCE:
			_door_armed[id] = true
		elif d < DOOR_NEAR_DISTANCE and _door_armed.get(id, false) and _farewell_cd <= 0.0:
			_door_armed[id] = false
			_say_farewell(p)
			break
	for id in _door_armed.keys():
		if not live.has(id):
			_door_armed.erase(id)


func _say_farewell(to: Node2D) -> void:
	state = State.FAREWELL
	_timer = FAREWELL_TIME
	_farewell_cd = FAREWELL_COOLDOWN
	_farewell_target = to
	unlock_clip()
	face_point(_to_local_feet(to))
	say(FAREWELLS[randi() % FAREWELLS.size()])


# ------------------------------------------------------------------ yardımcılar

func _interior_visible() -> bool:
	var p: Node = get_parent()
	return p is CanvasItem and (p as CanvasItem).is_visible_in_tree()


## Dükkanın içindeki canlı oyuncular (yerel oyuncu + uzak kuklalar), konuma göre.
func _players_inside() -> Array[Node2D]:
	var out: Array[Node2D] = []
	var origin: Vector2 = (get_parent() as Node2D).global_position
	for p: Node2D in NpcActor.live_players(get_tree()):
		if p.global_position.distance_to(origin) < INSIDE_RADIUS:
			out.append(p)
	return out


func _to_local_feet(p: Node2D) -> Vector2:
	return get_parent().to_local(p.global_position) + Vector2(0.0, FEET_OFFSET)


func _face_nearest(players: Array[Node2D]) -> void:
	var best: Node2D = null
	var best_d: float = INF
	for p: Node2D in players:
		var d: float = p.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = p
	if best != null:
		face_point(_to_local_feet(best))
