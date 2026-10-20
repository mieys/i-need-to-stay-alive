extends Node2D
class_name HouseDamageFx

## EV HASAR GÖRSELLERİ + SESLERİ (madde 313): "canı azalınca evin tavanından parçalar dökülecek ve duvarlar çatlayacak" + "yaratıklar
## saldırıyormuş gibi boğuk eve saldırma sesleri ... duvarlara vuruyorlarmış gibi".
## Pişmiş iç mekanın ÇOCUĞU (oyuncu dışarıdayken iç mekanla birlikte gizli). Ağ trafiği yok: HouseSiege'in eşitlenen durumunu (can oranı,
## saldırı altında, yıkıldı) okur; vuruş anları her peer'de yerel rastgele (kozmetik).
##  - ÇATLAKLAR: "Duvar yüzü" katmanının 2x2 karoluk bloklarına (önü en az yarı boş olanlar, boşu çok olan önce) kararlı tohumla dağılır;
##    çizim sırası duvar yüzünün HEMEN ARDINDA (ayrı kök düğüm) -> önündeki eşya/süs/pencere çatlağı doğal olarak örter. Can oranı
##    CRACK_AT eşiklerinin altına indikçe sırayla belirir ve iki adım büyür (catlak.png 6 şekil x 3 aşama). Ev onarılınca geri çekilir.
##  - VURUŞ: saldırı altındayken (yerel oyuncu içerideyse) her THUMP_MIN..MAX sn'de bir duvardan boğuk vuruş (konumlu ses -> yön duyulur)
##    + hafif sarsıntı; can düştükçe sıklaşır, şansla tavandan parça + toz akışı (açık zemin hücresine düşer, sekip yerde kalır, söner).
##  - KAPI VURUŞU (kullanıcı: "hasar alırken kapıdan parçalar çıkmalı eve doğru"): vuruşların DOOR_HIT_CHANCE'ı çıkış kapısına - ses
##    kapıdan, "Kapı" katmanı 1 px titrer, kapıdan odaya doğru tahta kıymıkları kavisle fırlar (havada yükseklik + yerde sekme).
##  - GÜÇLÜ SARSINTI (kullanıcı: "içerde arada ev sallanmalı"): saldırı altındayken HEAVY_MIN..MAX sn'de bir (can düştükçe sık) ev
##    sallanır: güçlü kamera sarsıntısı + iki vuruş + her yerden toz/parça + kapı kıymıkları.
##  - quake(): açılış depremi (toz akışları + birkaç parça), collapse_burst(): yıkılış anı.

const CRACK_TEX: Texture2D = preload("res://assets/fx/ev_kusatma/catlak.png")
const DEBRIS_TEX: Texture2D = preload("res://assets/fx/ev_kusatma/dokuntu.png")
const DUST_TEX: Texture2D = preload("res://assets/fx/ev_kusatma/toz.png")
const STREAM_TEX: Texture2D = preload("res://assets/fx/ev_kusatma/toz_akisi.png")
const THUMPS: Array[AudioStream] = [
	preload("res://assets/audio/ev/duvar_vurus_1.wav"), preload("res://assets/audio/ev/duvar_vurus_2.wav"),
	preload("res://assets/audio/ev/duvar_vurus_3.wav"), preload("res://assets/audio/ev/duvar_vurus_4.wav"),
]
const COLLAPSE_SOUND: AudioStream = preload("res://assets/audio/ev/ev_yikilis.wav")
const CameraShakeScript := preload("res://scripts/camera_shake.gd")

const WALL_LAYER := "Duvar yüzü"
## Bu katmanlardaki karolar duvar yüzünün önünde (eşya, süs, pencere, kapı): çatlak bloğunun en az yarısı bunlardan boş olmalı.
const COVER_LAYERS: Array[String] = ["Duvar süsü", "Duvar süsü 2", "ekstra", "ekstra 2", "ekstra 3", "ekstra 4", "Eşya üst",
	"Eşya üst 2", "Eşya alt", "Oda kapıları", "Kapı", "Duvarlar"]
const CRACK_CELL := 32
const CRACK_SHAPES := 6
const CRACK_AT: Array[float] = [0.88, 0.76, 0.64, 0.52, 0.40, 0.28, 0.18, 0.1]
const CRACK_STEP := 0.12 ## eşikten bu kadar aşağıda bir aşama daha büyür
const CRACK_MIN_GAP := 56.0
const THUMP_MIN := 1.4
const THUMP_MAX := 3.2
const THUMP_DB := -5.0
const DEBRIS_CELL := 8
const DEBRIS_KINDS := 8
const DEBRIS_FALL := 56.0 ## parçanın düştüğü yükseklik (dünya px, tavandan yere hissi)
const GRAVITY := 520.0
const DEBRIS_LIFE := 9.0
const MAX_DEBRIS := 48
const DUST_FRAMES := 5
const DOOR_LAYER := "Kapı"
const DOOR_HIT_CHANCE := 0.45
const WOOD_KINDS: Array[int] = [0, 1, 6] ## dokuntu.png tahta parçaları
const SPLINTER_GRAVITY := 320.0
const DOOR_RATTLE := 0.18
const HEAVY_MIN := 7.0
const HEAVY_MAX := 12.0
const STREAM_FRAMES := 6

var _siege: HouseSiege = null
var _house: Node = null
var _walk_cells: Array[Vector2i] = []
var _tile: Vector2 = Vector2(16.0, 16.0)
var _cracks: Array[Sprite2D] = []
var _crack_root: Node2D = null
var _crack_check: float = 0.0
var _thump_t: float = 2.0
var _debris: Array[Dictionary] = [] ## {"s": Sprite2D, "vy", "y0" (yer), "t", "bounced"}
var _anims: Array[Dictionary] = [] ## {"s": Sprite2D, "frames", "fps", "t", "loop_until"}
var _rng := RandomNumberGenerator.new()
var hp_bar: Control = null ## house_hp_bar.gd (HUD): vuruşta kırmızı parlar
var _door_layer: TileMapLayer = null
var _door_base: Vector2 = Vector2.ZERO
var _door_pt: Vector2 = Vector2.INF ## çıkış kapısının ortası (iç mekan yereli)
var _door_rattle: float = 0.0
var _splinters: Array[Dictionary] = [] ## {"s", "g" yer, "v" yer hızı, "z", "vz", "b" sekti, "t"}
var _heavy_t: float = 9.0


func setup(house: Node, siege: HouseSiege, walkable: Dictionary, tile: Vector2) -> void:
	name = "HouseDamageFx"
	_house = house
	_siege = siege
	_tile = tile
	z_index = 0
	_rng.seed = 312
	_walk_cells.clear()
	for c: Vector2i in walkable:
		_walk_cells.append(c)
	_walk_cells.sort()
	_build_cracks()
	_door_layer = _layer(DOOR_LAYER)
	if _door_layer != null and not _door_layer.get_used_cells().is_empty():
		_door_base = _door_layer.position
		var sum := Vector2.ZERO
		for c: Vector2i in _door_layer.get_used_cells():
			sum += _door_layer.position + _door_layer.map_to_local(c)
		_door_pt = sum / float(_door_layer.get_used_cells().size())


# ------------------------------------------------------------------ çatlaklar

func _layer(name_: String) -> TileMapLayer:
	var p: Node = get_parent()
	return p.get_node_or_null(NodePath(name_)) as TileMapLayer if p != null else null


## Duvar yüzünün üstü boş 2x2 bloklarından kararlı seçim (aynı ev -> her peer'de aynı yerler).
func crack_slots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var wall: TileMapLayer = _layer(WALL_LAYER)
	if wall == null:
		return out
	var covered: Dictionary = {}
	for ln: String in COVER_LAYERS:
		var l: TileMapLayer = _layer(ln)
		if l == null:
			continue
		for c: Vector2i in l.get_used_cells():
			covered[c] = true
	var face: Dictionary = {}
	for c: Vector2i in wall.get_used_cells():
		face[c] = true
	var cands: Array[Vector2i] = []
	var free_of: Dictionary = {}
	for c: Vector2i in face:
		var block: Array[Vector2i] = [c, c + Vector2i(1, 0), c + Vector2i(0, 1), c + Vector2i(1, 1)]
		var all_face: bool = true
		var free: int = 0
		for b: Vector2i in block:
			all_face = all_face and face.has(b)
			if not covered.has(b):
				free += 1
		if all_face and free >= 2:
			cands.append(c)
			free_of[c] = free
	cands.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = 31201
	for i in range(cands.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	## önü daha boş bloklar önce (karıştırılmış sıra kararlı kalır)
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return int(free_of[a]) > int(free_of[b]))
	for c: Vector2i in cands:
		var p: Vector2 = wall.position + Vector2(c) * _tile
		var far: bool = true
		for q: Vector2 in out:
			if q.distance_to(p) < CRACK_MIN_GAP:
				far = false
				break
		if far:
			out.append(p)
			if out.size() >= CRACK_AT.size():
				break
	return out


func _build_cracks() -> void:
	for s: Sprite2D in _cracks:
		s.queue_free()
	_cracks.clear()
	if _crack_root == null:
		_crack_root = Node2D.new()
		_crack_root.name = "HouseCracks"
		var p: Node = get_parent()
		var wall: TileMapLayer = _layer(WALL_LAYER)
		if p != null and wall != null:
			p.add_child(_crack_root)
			p.move_child(_crack_root, wall.get_index() + 1) ## duvar yüzünün hemen ardından: önündeki her şey üstüne çizilir
		else:
			add_child(_crack_root)
	var slots: Array[Vector2] = crack_slots()
	for i in slots.size():
		var s := Sprite2D.new()
		s.texture = CRACK_TEX
		s.region_enabled = true
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = slots[i]
		s.visible = false
		s.set_meta("shape", i % CRACK_SHAPES)
		_crack_root.add_child(s)
		_cracks.append(s)


## Can oranına göre i. çatlağın aşaması (-1 = yok).
static func crack_stage(i: int, r: float) -> int:
	if i < 0 or i >= CRACK_AT.size() or r >= CRACK_AT[i]:
		return -1
	if r <= 0.0:
		return 2 ## yıkık ev: hepsi tam boy
	return mini(2, int((CRACK_AT[i] - r) / CRACK_STEP))


func visible_crack_count() -> int:
	var n: int = 0
	for s: Sprite2D in _cracks:
		if s.visible:
			n += 1
	return n


func _update_cracks() -> void:
	var r: float = 0.0 if _siege == null or _siege.collapsed else _siege.ratio()
	if _siege == null:
		r = 1.0
	for i in _cracks.size():
		var st: int = crack_stage(i, r)
		var s: Sprite2D = _cracks[i]
		s.visible = st >= 0
		if st >= 0:
			s.region_rect = Rect2(st * CRACK_CELL, int(s.get_meta("shape")) * CRACK_CELL, CRACK_CELL, CRACK_CELL)


# ------------------------------------------------------------------ kare

func _process(delta: float) -> void:
	_crack_check -= delta
	if _crack_check <= 0.0:
		_crack_check = 0.25
		_update_cracks()
	_step_debris(delta)
	_step_anims(delta)
	_step_splinters(delta)
	if _door_rattle > 0.0 and _door_layer != null:
		_door_rattle -= delta
		_door_layer.position = _door_base + (Vector2(float(_rng.randi_range(-1, 1)), 0.0) if _door_rattle > 0.0 else Vector2.ZERO)
	if _siege == null or not _siege.under_attack or not _local_inside():
		_thump_t = minf(_thump_t, 1.2)
		_heavy_t = maxf(_heavy_t, HEAVY_MIN * 0.6)
		return
	var r: float = _siege.ratio()
	_thump_t -= delta
	if _thump_t <= 0.0:
		_thump_t = _rng.randf_range(THUMP_MIN, THUMP_MAX) * (0.45 + 0.55 * r)
		if _door_pt.is_finite() and _rng.randf() < DOOR_HIT_CHANCE:
			door_hit(r)
		else:
			thump(r)
	_heavy_t -= delta
	if _heavy_t <= 0.0:
		_heavy_t = _rng.randf_range(HEAVY_MIN, HEAVY_MAX) * (0.55 + 0.45 * r)
		heavy_hit(r)


func _local_inside() -> bool:
	var p: Node = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	return HouseSiege.in_house(p)


## Bir duvar vuruşu: boğuk ses (duvar noktasından, yön duyulur) + hafif sarsıntı + can düştükçe tavandan döküntü.
func thump(r: float) -> void:
	var wall_pt: Vector2 = _random_wall_point()
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = THUMPS[_rng.randi() % THUMPS.size()]
	sfx.volume_db = THUMP_DB + _rng.randf_range(-2.0, 1.5)
	sfx.pitch_scale = _rng.randf_range(0.88, 1.08)
	sfx.max_distance = 2000.0
	add_child(sfx)
	sfx.position = wall_pt
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
	CameraShakeScript.add(0.1 + 0.12 * (1.0 - r))
	if hp_bar != null and is_instance_valid(hp_bar):
		hp_bar.call("pulse")
	if _rng.randf() < clampf(1.15 - r, 0.15, 0.95):
		debris_burst(_random_floor_point(), _rng.randi_range(2, 3 + int(4.0 * (1.0 - r))), true)


## Çıkış kapısına vuruş: ses kapıdan, kapı titrer, kıymıklar kapıdan odaya doğru fırlar.
func door_hit(r: float) -> void:
	if not _door_pt.is_finite():
		thump(r)
		return
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = THUMPS[_rng.randi() % THUMPS.size()]
	sfx.volume_db = THUMP_DB + 1.0 + _rng.randf_range(-1.5, 1.5)
	sfx.pitch_scale = _rng.randf_range(0.9, 1.1)
	sfx.max_distance = 2000.0
	add_child(sfx)
	sfx.position = _door_pt
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
	CameraShakeScript.add(0.12 + 0.12 * (1.0 - r))
	if hp_bar != null and is_instance_valid(hp_bar):
		hp_bar.call("pulse")
	_door_rattle = DOOR_RATTLE
	door_splinters(_rng.randi_range(3, 4 + int(4.0 * (1.0 - r))))


## Kapıdan odaya doğru (yukarı, yelpaze) fırlayan tahta kıymıkları: havada yükselip düşer, bir kez seker, yerde kalır, söner.
func door_splinters(count: int, delay: float = 0.0) -> void:
	if not _door_pt.is_finite():
		return
	_spawn_dust(_door_pt + Vector2(0.0, -6.0))
	for i in count:
		if _splinters.size() >= MAX_DEBRIS:
			var old: Dictionary = _splinters.pop_front()
			(old["s"] as Sprite2D).queue_free()
		var s := Sprite2D.new()
		s.texture = DEBRIS_TEX
		s.region_enabled = true
		s.region_rect = Rect2(WOOD_KINDS[_rng.randi() % WOOD_KINDS.size()] * DEBRIS_CELL, 0, DEBRIS_CELL, DEBRIS_CELL)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.flip_h = _rng.randf() < 0.5
		s.z_index = 3
		s.visible = false
		add_child(s)
		var g: Vector2 = _door_pt + Vector2(_rng.randf_range(-14.0, 14.0), -6.0)
		var v := Vector2(_rng.randf_range(-55.0, 55.0), -_rng.randf_range(55.0, 125.0)) ## odaya doğru (yukarı) yelpaze
		_splinters.append({"s": s, "g": g, "v": v, "z": _rng.randf_range(6.0, 14.0), "vz": _rng.randf_range(35.0, 80.0),
			"b": false, "t": -delay - _rng.randf_range(0.0, 0.08), "rest": false})


func _step_splinters(delta: float) -> void:
	var i: int = 0
	while i < _splinters.size():
		var d: Dictionary = _splinters[i]
		var s: Sprite2D = d["s"]
		d["t"] = float(d["t"]) + delta
		var t: float = d["t"]
		if t < 0.0:
			i += 1
			continue
		s.visible = true
		if not d["rest"]:
			d["g"] = (d["g"] as Vector2) + (d["v"] as Vector2) * delta
			d["vz"] = float(d["vz"]) - SPLINTER_GRAVITY * delta
			d["z"] = float(d["z"]) + float(d["vz"]) * delta
			if float(d["z"]) <= 0.0:
				d["z"] = 0.0
				if not d["b"]:
					d["b"] = true
					d["vz"] = -float(d["vz"]) * 0.3
					d["v"] = (d["v"] as Vector2) * 0.35
				else:
					d["rest"] = true
					d["t"] = 0.0
					s.z_index = 0
			if not _walk_ok((d["g"] as Vector2)):
				d["v"] = Vector2.ZERO ## eşyaya/duvara çarptı: olduğu yere düşer
			s.position = ((d["g"] as Vector2) - Vector2(0.0, float(d["z"]))).round()
		elif t > DEBRIS_LIFE:
			s.modulate.a = maxf(0.0, 1.0 - (t - DEBRIS_LIFE))
			if t > DEBRIS_LIFE + 1.0:
				s.queue_free()
				_splinters.remove_at(i)
				continue
		i += 1


var _walk_set: Dictionary = {}


func _walk_ok(p: Vector2) -> bool:
	if _walk_set.is_empty():
		for c: Vector2i in _walk_cells:
			_walk_set[c] = true
	return _walk_set.has(Vector2i(floori(p.x / _tile.x), floori(p.y / _tile.y)))


## Arada ev sallanır: güçlü sarsıntı, iki vuruş, her yerden toz ve parça, kapı kıymıkları.
func heavy_hit(r: float) -> void:
	thump(r)
	if _door_pt.is_finite():
		door_hit(r)
	CameraShakeScript.add(0.45 + 0.2 * (1.0 - r))
	for i in 3:
		debris_burst(_random_floor_point(), _rng.randi_range(2, 4), true, _rng.randf_range(0.05, 0.5))
	door_splinters(_rng.randi_range(3, 5), 0.15)


func splinter_count() -> int:
	return _splinters.size()


func _random_wall_point() -> Vector2:
	if not _cracks.is_empty():
		return _cracks[_rng.randi() % _cracks.size()].position + Vector2(16.0, 16.0)
	return _random_floor_point()


func _random_floor_point() -> Vector2:
	if _walk_cells.is_empty():
		return Vector2(320.0, 200.0)
	var c: Vector2i = _walk_cells[_rng.randi() % _walk_cells.size()]
	return (Vector2(c) + Vector2(_rng.randf_range(0.2, 0.8), _rng.randf_range(0.3, 0.9))) * _tile


## Açılış depremi: tavandan birkaç toz akışı + az parça.
func quake(duration: float) -> void:
	for i in 6:
		_spawn_stream(_random_floor_point(), duration * _rng.randf_range(0.5, 0.9), _rng.randf_range(0.0, duration * 0.4))
	for i in 3:
		debris_burst(_random_floor_point(), 2, false, _rng.randf_range(0.4, duration * 0.8))


## Yıkılış anı: odanın her yerine döküntü + ses + güçlü sarsıntı.
func collapse_burst() -> void:
	if _local_inside():
		var sfx := AudioStreamPlayer.new()
		sfx.stream = COLLAPSE_SOUND
		sfx.volume_db = -2.0
		add_child(sfx)
		sfx.finished.connect(sfx.queue_free)
		sfx.play()
		CameraShakeScript.add(0.9)
	for i in 10:
		debris_burst(_random_floor_point(), _rng.randi_range(3, 5), true, _rng.randf_range(0.0, 0.9))


## Bir noktaya (iç mekan yereli, yer) tavandan düşen parça kümesi; stream = ince toz akışı da.
func debris_burst(ground: Vector2, count: int, stream: bool, delay: float = 0.0) -> void:
	if stream:
		_spawn_stream(ground, 1.2, delay)
	for i in count:
		if _debris.size() >= MAX_DEBRIS:
			var old: Dictionary = _debris.pop_front()
			(old["s"] as Sprite2D).queue_free()
		var s := Sprite2D.new()
		s.texture = DEBRIS_TEX
		s.region_enabled = true
		s.region_rect = Rect2((_rng.randi() % DEBRIS_KINDS) * DEBRIS_CELL, 0, DEBRIS_CELL, DEBRIS_CELL)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.flip_h = _rng.randf() < 0.5
		var g: Vector2 = (ground + Vector2(_rng.randf_range(-7.0, 7.0), _rng.randf_range(-3.0, 3.0))).round()
		s.position = g - Vector2(0.0, DEBRIS_FALL + _rng.randf_range(0.0, 18.0))
		s.z_index = 3 ## düşerken karakterlerin ve eşyaların önünde
		s.visible = delay <= 0.0
		add_child(s)
		_debris.append({"s": s, "vy": 0.0, "y0": g.y, "t": -delay - _rng.randf_range(0.0, 0.25), "bounced": false})


func _step_debris(delta: float) -> void:
	var i: int = 0
	while i < _debris.size():
		var d: Dictionary = _debris[i]
		var s: Sprite2D = d["s"]
		d["t"] = float(d["t"]) + delta
		var t: float = d["t"]
		if t < 0.0:
			i += 1
			continue
		s.visible = true
		if s.z_index == 3:
			d["vy"] = float(d["vy"]) + GRAVITY * delta
			s.position.y += float(d["vy"]) * delta
			if s.position.y >= float(d["y0"]):
				s.position.y = float(d["y0"])
				if not d["bounced"]:
					d["bounced"] = true
					d["vy"] = -float(d["vy"]) * 0.28
					_spawn_dust(s.position)
				else:
					s.z_index = 0 ## yerde: karakterler üstünden geçer
					d["t"] = 0.0
		elif t > DEBRIS_LIFE:
			s.modulate.a = maxf(0.0, 1.0 - (t - DEBRIS_LIFE))
			if t > DEBRIS_LIFE + 1.0:
				s.queue_free()
				_debris.remove_at(i)
				continue
		i += 1


func _spawn_dust(at: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = DUST_TEX
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, 14, 10)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = at + Vector2(0.0, -3.0)
	s.z_index = 2
	add_child(s)
	_anims.append({"s": s, "w": 14, "h": 10, "frames": DUST_FRAMES, "fps": 12.0, "t": 0.0, "until": 0.0})


func _spawn_stream(ground: Vector2, duration: float, delay: float) -> void:
	var s := Sprite2D.new()
	s.texture = STREAM_TEX
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, 6, 40)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.position = (ground - Vector2(3.0, 40.0)).round()
	s.z_index = 3
	s.visible = delay <= 0.0
	add_child(s)
	_anims.append({"s": s, "w": 6, "h": 40, "frames": STREAM_FRAMES, "fps": 10.0, "t": -delay, "until": duration})


func _step_anims(delta: float) -> void:
	var i: int = 0
	while i < _anims.size():
		var a: Dictionary = _anims[i]
		var s: Sprite2D = a["s"]
		a["t"] = float(a["t"]) + delta
		var t: float = a["t"]
		if t < 0.0:
			i += 1
			continue
		s.visible = true
		var f: int = int(t * float(a["fps"]))
		var loop_until: float = a["until"]
		if loop_until > 0.0:
			if t >= loop_until:
				s.modulate.a = maxf(0.0, 1.0 - (t - loop_until) / 0.4)
				if t >= loop_until + 0.4:
					s.queue_free()
					_anims.remove_at(i)
					continue
			f = f % int(a["frames"])
		elif f >= int(a["frames"]):
			s.queue_free()
			_anims.remove_at(i)
			continue
		s.region_rect = Rect2(f * int(a["w"]), 0, int(a["w"]), int(a["h"]))
		i += 1


func debris_count() -> int:
	return _debris.size()
