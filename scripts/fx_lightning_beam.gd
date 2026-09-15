extends Node2D

## Şimşek Asası'nın (2026 güncellemesi) kesintisiz cızırdayan şimşek efekti.
## Eski statik dokuyu gerdirmek yerine, her karede dinamik zikzak çizen,
## yanlardan küçük kollar (branch) fırlatan gerçekçi ve piksel stiliyle
## uyumlu bir elektrik ışını çizer. Hedefte sürekli elektrik kıvılcımları (particle) üretir.

@onready var bolt: AnimatedSprite2D = get_node_or_null("Bolt")
@onready var spark: AnimatedSprite2D = get_node_or_null("Spark")
@onready var sfx: AudioStreamPlayer2D = get_node_or_null("Sfx")

var _origin: Node2D = null
var _target: Node2D = null

## Ağ (remote) modu: uzak oyuncularda gerçek bir Enemy node referansımız yok,
## broadcast_player_vfx RPC'siyle sadece hedefin pozisyonu (Vector2) geliyor
## (bkz. remote_player.gd _start_beam_vfx/_update_beam_vfx ve
## network_manager.gd broadcast_player_vfx "beam_start"/"beam_update").
## BUG FIX: bu iki fonksiyon (setup_network/update_target) hiç yoktu, bu
## yüzden uzak oyuncularda ışın _origin/_target'sız (ikisi de null) kalıp
## sıfır uzunlukta (görünmez) çiziliyordu - ışın sadece silahı ateşleyen
## oyuncunun kendi ekranında görünüyordu.
var _use_network_target: bool = false
var _network_target_pos: Vector2 = Vector2.ZERO
var _network_origin_pos: Vector2 = Vector2.ZERO

# Zikzak noktaları ve cızırdayarak yer değiştirme (flicker) zamanlayıcısı
var _zigzag_points: Array[Vector2] = []
var _flicker_timer: float = 0.0
const FLICKER_INTERVAL := 0.045 # Şimşeğin yön değiştirme sıklığı

# Elektrik parçacıkları (sparks) listesi
var _particles: Array[Dictionary] = []
var _particle_timer: float = 0.0


func _ready() -> void:
	# Eski sprite nesnelerinin görünürlüğünü kapatıp kendi çizimimizi kullanıyoruz
	if bolt:
		bolt.visible = false
	if spark:
		spark.visible = false
		
	if sfx:
		sfx.finished.connect(sfx.play)
		sfx.play()


func setup(origin: Node2D, target: Node2D) -> void:
	_origin = origin
	_target = target
	_use_network_target = false
	queue_redraw()


## Uzak oyuncularda çağrılır. Orijin olarak silahın gerçek namlu konumu,
## hedef olarak da ağdan gelen hedef konumu kullanılır; eksik eski paketlerde
## RemotePlayer konumu güvenli geri dönüş olarak korunur.
func setup_network(target_pos: Vector2, extra_data: Dictionary) -> void:
	_origin = null
	_target = null
	_use_network_target = true
	_network_target_pos = target_pos
	var fallback_origin: Vector2 = get_parent().global_position if get_parent() is Node2D else target_pos
	_network_origin_pos = Vector2(extra_data.get("from_pos", fallback_origin))
	queue_redraw()


## Uzak oyuncularda hedef ve silah namlusu pozisyonunu tazeler.
func update_target(target_pos: Vector2, origin_pos: Vector2 = Vector2.ZERO) -> void:
	_network_target_pos = target_pos
	if origin_pos != Vector2.ZERO:
		_network_origin_pos = origin_pos


func _process(delta: float) -> void:
	var from: Vector2
	if _use_network_target:
		from = _network_origin_pos
	elif _origin and is_instance_valid(_origin):
		from = _origin.global_position
	else:
		from = global_position
	var to: Vector2
	if _use_network_target:
		to = _network_target_pos
	elif _target and is_instance_valid(_target):
		to = _target.global_position
	else:
		to = global_position
	
	# Biz hedefin (isabet ucu) üzerinde duruyoruz, çizimi relative yapacağız
	global_position = to
	
	# Cızırdayarak titreme (Flicker) güncellemesi
	_flicker_timer -= delta
	if _flicker_timer <= 0.0 or _zigzag_points.is_empty():
		_flicker_timer = FLICKER_INTERVAL
		_recalculate_lightning_path(from - to)
		
	# Parçacık üretimi ve güncellemesi
	_update_particles(delta)
	
	# Dinamik elektrik cızırtısı/humming ses efekti tasarımı
	if sfx and sfx.playing:
		sfx.pitch_scale = lerp(sfx.pitch_scale, randf_range(0.94, 1.08), 0.4)
		sfx.volume_db = lerp(sfx.volume_db, -7.5 + randf_range(-1.5, 1.5), 0.4)
	
	queue_redraw()


func _recalculate_lightning_path(relative_start: Vector2) -> void:
	_zigzag_points.clear()
	var segments := 10
	var start := relative_start
	var end := Vector2.ZERO # Kökümüz hedefin (0,0) noktası
	
	_zigzag_points.append(start)
	
	var dir := (end - start).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var length := start.distance_to(end)
	
	for i in range(1, segments):
		var t := i / float(segments)
		var base_pos := start.lerp(end, t)
		
		# Ortaya doğru zikzak genliği artar, uçlarda azalır (sine envelope)
		var envelope := sin(t * PI)
		var offset := normal * randf_range(-12.0, 12.0) * envelope
		_zigzag_points.append(base_pos + offset)
		
	_zigzag_points.append(end)


func _update_particles(delta: float) -> void:
	# Parçacık süresini ilerlet ve ölenleri sil
	var i := _particles.size() - 1
	while i >= 0:
		var p: Dictionary = _particles[i]
		p["life"] -= delta
		if p["life"] <= 0.0:
			_particles.remove_at(i)
		else:
			p["pos"] += (p["vel"] as Vector2) * delta
			# Yerçekimi veya yavaşlama
			p["vel"] = (p["vel"] as Vector2) * 0.92
		i -= 1
		
	# Yeni elektrik parçacıkları üret
	_particle_timer -= delta
	if _particle_timer <= 0.0:
		_particle_timer = 0.05
		for j in range(randi_range(2, 4)):
			var angle := randf() * TAU
			var speed := randf_range(80.0, 180.0)
			_particles.append({
				"pos": Vector2.ZERO, # Hit noktasından fırlar (0,0)
				"vel": Vector2(cos(angle), sin(angle)) * speed,
				"life": randf_range(0.15, 0.32),
				"max_life": 0.3,
				"color": Color(1.0, 0.9, 0.2) if randf() < 0.7 else Color(1.0, 1.0, 1.0)
			})


func _draw() -> void:
	if _zigzag_points.size() < 2:
		return
		
	# 1. Şimşek Işınını Çiz (Çift katmanlı parıltı)
	var yellow_glow := Color(1.0, 0.75, 0.1, 0.8)
	var white_core := Color(1.0, 1.0, 1.0, 1.0)
	
	# Dış sarı aydınlatma
	for i in range(_zigzag_points.size() - 1):
		draw_line(_zigzag_points[i], _zigzag_points[i + 1], yellow_glow, 3.2, true)
		
	# İç beyaz çekirdek
	for i in range(_zigzag_points.size() - 1):
		draw_line(_zigzag_points[i], _zigzag_points[i + 1], white_core, 1.2, true)
		
	# Rastgele küçük elektrik kolları (branches) fırlat
	for i in range(1, _zigzag_points.size() - 2):
		if (i % 4 == 0) and randf() < 0.4:
			var branch_start := _zigzag_points[i]
			var next_pt := _zigzag_points[i + 1]
			var diff := next_pt - branch_start
			var angle := diff.angle() + randf_range(-0.6, 0.6)
			var branch_end := branch_start + Vector2(cos(angle), sin(angle)) * randf_range(10.0, 20.0)
			
			draw_line(branch_start, branch_end, yellow_glow, 2.0, true)
			draw_line(branch_start, branch_end, white_core, 0.8, true)
			
	# 2. Elektrik Kıvılcımlarını Çiz (Particle çizimi)
	for p in _particles:
		var alpha: float = (p["life"] as float) / (p["max_life"] as float)
		var c: Color = p["color"]
		c.a = alpha
		# Kıvılcımları küçük piksel çizgileri olarak çiz
		var vel: Vector2 = p["vel"]
		var start: Vector2 = p["pos"]
		var end: Vector2 = start - vel.normalized() * min(4.0, vel.length() * 0.05)
		draw_line(start, end, c, 1.5, true)
