extends Node2D

## Düşmanlar arası sıçrayan (chain) elektrik arkı efekti.
## Kısa süreli cızırdayan sarı-beyaz bir elektrik yayı çizer ve hedefe ulaştığında
## elektrik kıvılcımları saçar. 0.18 saniye sonra otomatik silinir.

var _from_node: Node2D = null
var _to_node: Node2D = null
var _from_pos: Vector2 = Vector2.ZERO
var _to_pos: Vector2 = Vector2.ZERO

var _zigzag_points: Array[Vector2] = []
var _flicker_timer: float = 0.0
const FLICKER_INTERVAL := 0.03

var _lifetime: float = 0.18
var _elapsed: float = 0.0

var _particles: Array[Dictionary] = []


func setup(from_node: Node2D, to_node: Node2D) -> void:
	_from_node = from_node
	_to_node = to_node
	_from_pos = from_node.global_position if is_instance_valid(from_node) else global_position
	_to_pos = to_node.global_position if is_instance_valid(to_node) else global_position
	_finish_setup()


## Uzak (remote) oyuncularda çağrılır - gerçek Enemy node referansımız yok,
## broadcast_player_vfx RPC'siyle sadece iki sabit pozisyon (Vector2) geliyor
## (bkz. weapon.gd _spawn_chain_lightning_fx, network_manager.gd
## broadcast_player_vfx "chain_lightning" case'i). Efekt zaten çok kısa ömürlü
## (0.18sn) olduğu için pozisyonların hareket eden node'ları takip etmemesi
## görsel olarak fark edilmez.
func setup_positions(from_pos: Vector2, to_pos: Vector2) -> void:
	_from_node = null
	_to_node = null
	_from_pos = from_pos
	_to_pos = to_pos
	_finish_setup()


func _finish_setup() -> void:
	# Biz hedefin (sıçranan yaratık) üzerinde duruyoruz, çizimi relative yapacağız
	global_position = _to_pos
	
	# Başlangıç zikzak hattını oluştur
	_recalculate_path()
	
	# Sıçranan hedefte 4-6 adet elektrik kıvılcımı oluştur
	for i in range(randi_range(4, 6)):
		var angle := randf() * TAU
		var speed := randf_range(90.0, 220.0)
		_particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": randf_range(0.12, 0.28),
			"max_life": 0.25
		})
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime:
		queue_free()
		return
		
	# Konumları güncelle (yaratıklar hareket ediyorsa ark da takip etsin)
	if is_instance_valid(_from_node):
		_from_pos = _from_node.global_position
	if is_instance_valid(_to_node):
		_to_pos = _to_node.global_position
		global_position = _to_pos
		
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		_flicker_timer = FLICKER_INTERVAL
		_recalculate_path()
		
	# Parçacık güncelleme
	for p in _particles:
		p["life"] -= delta
		p["pos"] += (p["vel"] as Vector2) * delta
		p["vel"] = (p["vel"] as Vector2) * 0.9
		
	queue_redraw()


func _recalculate_path() -> void:
	_zigzag_points.clear()
	var start := _from_pos - _to_pos
	var end := Vector2.ZERO
	var segments := 6
	
	_zigzag_points.append(start)
	
	var dir := (end - start).normalized()
	var normal := Vector2(-dir.y, dir.x)
	
	for i in range(1, segments):
		var t := i / float(segments)
		var base_pos := start.lerp(end, t)
		var envelope := sin(t * PI)
		var offset := normal * randf_range(-10.0, 10.0) * envelope
		_zigzag_points.append(base_pos + offset)
		
	_zigzag_points.append(end)


func _draw() -> void:
	if _zigzag_points.size() < 2:
		return
		
	var fade_alpha := 1.0 - (_elapsed / _lifetime)
	var yellow_glow := Color(1.0, 0.75, 0.1, 0.8 * fade_alpha)
	var white_core := Color(1.0, 1.0, 1.0, fade_alpha)
	
	# 1. Zikzak sıçrama çizimi
	for i in range(_zigzag_points.size() - 1):
		draw_line(_zigzag_points[i], _zigzag_points[i + 1], yellow_glow, 2.5, true)
	for i in range(_zigzag_points.size() - 1):
		draw_line(_zigzag_points[i], _zigzag_points[i + 1], white_core, 1.0, true)
		
	# 2. İsabet kıvılcımları çizimi
	for p in _particles:
		if p["life"] <= 0.0:
			continue
		var alpha: float = (p["life"] as float) / (p["max_life"] as float)
		var c := Color(1.0, 0.85, 0.2, alpha * fade_alpha)
		var vel: Vector2 = p["vel"]
		var start: Vector2 = p["pos"]
		var end: Vector2 = start - vel.normalized() * min(3.0, vel.length() * 0.05)
		draw_line(start, end, c, 1.2, true)
