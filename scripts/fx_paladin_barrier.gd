extends Node2D

## Şovalye (Paladin) ultisi ("Koruma Baloncuğu") aktifken oyuncuya eklenen
## kalıcı, BÜYÜK koruma alanı baloncuğu - bkz. player.gd _skill_paladin_ulti/
## _end_paladin_ulti.
##
## z_index MUTLAKA absolute olmalı (z_as_relative = false) - Player'ın kendi
## z_index'i main.tscn'de 1 olarak ayarlı, göreceli negatif bir değer
## (ör. -5) zemin TileMapLayer'larının (z_index=0, absolute) ARKASINDA
## kalıp baloncuğu tamamen görünmez yapıyordu.
##
## Görünüm modern piksel sanatı (high-res pixel art) standartlarına uygun olarak
## yüksek çözünürlüklü bir piksellenme ile güncellendi.
## Kalkan hasar aldığında, darbenin geldiği yönde sihirli dairesel cam çatlakları
## (örümcek ağı şeklinde kırıklar) ve yerçekimiyle aşağı dökülen pikselli cam
## parçaları (shards) oluşur.

var radius: float = 126.0 ## player.gd _skill_paladin_ulti() PALADIN_ULTI_ZONE_RADIUS ile üzerine yazar - bu sadece varsayılan
var color: Color = Color(0.35, 0.78, 1.0, 0.95)
var active: bool = true

var _pulse_t: float = 0.0
var _flash_t: float = 0.0
const FLASH_DURATION := 0.22

var rect: ColorRect
var mat: ShaderMaterial
var overlay: Node2D

# Çatlama ve parça dökülme verileri
var cracks: Array[Dictionary] = []
var shards: Array[Dictionary] = []

func _ready() -> void:
	z_as_relative = false
	z_index = 20 ## zeminin (0) kesinlikle üstünde, kalıcı/güvenilir görünürlük

	# Karakterin kendi ölçeğinden bağımsız global boyutu korurken,
	# kalkanın dikeyde basık olmaması (tam yuvarlak olması) sağlanır.
	var parent_scale: Vector2 = Vector2.ONE
	var p := get_parent()
	if p is Node2D:
		parent_scale = p.scale
	if parent_scale.x != 0.0 and parent_scale.y != 0.0:
		scale = Vector2(1.0 / parent_scale.x, 1.0 / parent_scale.y)

	# Shader'ı çalıştıracak ColorRect çocuğunu oluşturuyoruz.
	rect = ColorRect.new()
	rect.size = Vector2(radius * 2.0, radius * 2.0)
	rect.position = Vector2(-radius, -radius)
	add_child(rect)

	# Shader material yükleme ve atama
	var shader := load("res://shaders/shield_dome.gdshader") as Shader
	mat = ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat

	# Başlangıç parametrelerini veriyoruz (Modern piksel art için 200.0 yapıldı)
	mat.set_shader_parameter("shield_color", color)
	mat.set_shader_parameter("pixel_size", 200.0) 
	mat.set_shader_parameter("time_speed", 2.0)

	# Üst katman çizim overlay'i (çatlakları ve dökülen parçaları kalkanın üstüne çizmek için)
	overlay = Node2D.new()
	overlay.set_script(load("res://scripts/fx_paladin_overlay.gd"))
	add_child(overlay)


## Kullanıcı bildirimi: "Şovalye adamın kalkan baloncuğuna vurulduğu andaki
## çatlama ve kalkanın hasar alma efekti şovalye adam haricinde kimseye
## görünmüyor... diğer oyuncuların host/katılımcı farketmeksizin aynı
## efektleri görmesi gerekiyor." Kök neden: flash() sadece kalkan sahibinin
## KENDİ client'ında (player.gd flash_paladin_barrier() üzerinden) çağrılıyordu,
## uzak client'lardaki RemotePlayer kuklasının kendi _barrier_visual kopyasında
## (bkz. remote_player.gd _ensure_barrier_visual) hiçbir zaman tetiklenmiyordu.
## Artık network_manager.gd broadcast_player_vfx() "paladin_barrier_flash"
## RPC'siyle bu fonksiyon uzak kopyalarda da çağrılıyor - saldıranın gerçek
## Node2D referansı uzak client'ta anlamlı olmadığı için (farklı network id'ler)
## sadece hazır hesaplanmış açı gönderiliyor.
func flash_from_angle(angle: float) -> void:
	_flash_t = FLASH_DURATION
	_spawn_crack(angle)
	_spawn_shards_at(angle)


func flash(attacker: Node2D = null) -> void:
	_flash_t = FLASH_DURATION
	
	# Eğer saldıran düşman belirtildiyse direkt onun açısını kullan
	if attacker and is_instance_valid(attacker):
		var parent = get_parent()
		if parent:
			var dir = (attacker.global_position - parent.global_position).normalized()
			_spawn_crack(dir.angle())
			_spawn_shards_at(dir.angle())
	else:
		# Belirtilmediyse en yakın düşmanı tara (fallback)
		var parent = get_parent()
		if parent:
			var closest_enemy: Node2D = null
			var min_dist := 99999.0
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and e.get("is_dead") != true:
					var d = parent.global_position.distance_to(e.global_position)
					if d < min_dist:
						min_dist = d
						closest_enemy = e
			
			if closest_enemy:
				var dir = (closest_enemy.global_position - parent.global_position).normalized()
				_spawn_crack(dir.angle())
				_spawn_shards_at(dir.angle())
			else:
				# Kimse yoksa rastgele bir açıda çatlak ve parça oluştur
				var rand_angle = randf_range(0.0, TAU)
				_spawn_crack(rand_angle)
				_spawn_shards_at(rand_angle)


## Kullanıcı isteği (2026-09-21): "kalkanların hasar alma efektleri pixel tarzı, mavi ve yarı saydam bir bariyer hasarı efekti
## olsun" - eskiden burada düzgün çizgili çatlak + cam kırığı çiziliyordu; artık oyuncu kalkanıyla AYNI pixel efekt
## (fx_shield_hit.gd, bu bariyerin kendi yarıçapıyla) doğuyor. Eski çatlak/kırık kodu aşağıda kullanılmıyor (erken dönüş).
func _spawn_pixel_hit(angle: float) -> void:
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/fx_shield_hit.gd"))
	add_child(fx)
	fx.call("setup", angle, radius)


func _spawn_crack(angle: float) -> void:
	_spawn_pixel_hit(angle)
	return
	var dir := Vector2(cos(angle), sin(angle))
	
	# Darbenin merkez vuruş noktası (çeperin üzerinde)
	var c_pt := dir * radius
	
	var lines: Array[PackedVector2Array] = []
	
	# 1. Tamamen Randomize Edilmiş Radyal Çatlak Çizgileri
	var num_radials := randi_range(2, 4)
	for i in range(num_radials):
		# Her kırık çizgisi için farklı yön sapması
		var a_dev := randf_range(-0.45, 0.45)
		var r_dir := dir.rotated(a_dev)
		var r_perp := Vector2(-r_dir.y, r_dir.x)
		
		# Zikzaklı kırık segmentleri
		var p1 := c_pt - r_dir * randf_range(12.0, 22.0) + r_perp * randf_range(-6.0, 6.0)
		var p2 := p1 - r_dir * randf_range(10.0, 18.0) + r_perp * randf_range(-4.0, 4.0)
		
		lines.append(PackedVector2Array([c_pt, p1, p2]))
		
		# Rastgele yan dal uzantısı
		if randf() < 0.5:
			var branch_dir := r_dir.rotated(randf_range(-0.6, 0.6))
			var p3 := p1 - branch_dir * randf_range(8.0, 14.0)
			lines.append(PackedVector2Array([p1, p3]))
			
	# 2. Tamamen Randomize Edilmiş Konsantrik Cam Kırık Yayları (Örümcek Ağı Hissiyatı)
	var num_arcs := randi_range(1, 3)
	for i in range(num_arcs):
		var dist_mult := randf_range(6.0, 10.0) if i == 0 else randf_range(14.0, 24.0)
		var arc_pts := PackedVector2Array()
		var steps := randi_range(4, 7)
		var spread := randf_range(0.5, 0.9)
		
		for j in range(steps + 1):
			var f := (j / float(steps)) - 0.5
			var a = angle + f * spread
			var pt_dir := Vector2(cos(a), sin(a))
			var pt := c_pt - pt_dir * dist_mult + pt_dir.rotated(PI/2.0) * randf_range(-2.0, 2.0)
			arc_pts.append(pt)
			
		lines.append(arc_pts)
		
	cracks.append({
		"lines": lines,
		"life": 0.0,
		"max_life": 0.42
	})


func _spawn_shards_at(_angle: float) -> void:
	return
	var angle: float = _angle
	# Darbenin merkez vuruş noktası
	var start_pos := Vector2(cos(angle), sin(angle)) * radius
	
	# 5-9 adet kırık cam parçası spawn et
	var count := randi_range(5, 9)
	for i in range(count):
		# Kuşbakışı oyun için yerçekimsiz patlama: Dışarı doğru dairesel saçılma
		var spread_angle = angle + randf_range(-0.7, 0.7)
		var speed = randf_range(60.0, 140.0)
		var vel = Vector2(cos(spread_angle), sin(spread_angle)) * speed
		
		# Keskin cam parçası özellikleri
		var shard_size = randf_range(1.8, 3.8)
		var rot = randf_range(0.0, TAU)
		var rot_speed = randf_range(-8.0, 8.0)
		
		shards.append({
			"pos": start_pos,
			"vel": vel,
			"size": shard_size,
			"rot": rot,
			"rot_speed": rot_speed,
			"life": 0.0,
			"max_life": randf_range(0.35, 0.65),
			"color": Color(0.65, 0.88, 1.0) if randf() < 0.75 else Color.WHITE
		})


func _process(delta: float) -> void:
	if not active:
		queue_free()
		return
	_pulse_t += delta
	if _flash_t > 0.0:
		_flash_t = max(0.0, _flash_t - delta)

	# Çatlak sürelerini güncelle
	var active_cracks: Array[Dictionary] = []
	for c in cracks:
		c.life += delta
		if c.life < c.max_life:
			active_cracks.append(c)
	cracks = active_cracks

	# Yerçekimsiz sürtünmeli dökülme/savrulma (Top-down drift & friction)
	var active_shards: Array[Dictionary] = []
	for s in shards:
		s.life += delta
		if s.life < s.max_life:
			s.pos += s.vel * delta
			s.vel *= 0.91 # Sürtünme (yavaşlayıp durma hissi)
			s.rot += s.rot_speed * delta
			active_shards.append(s)
	shards = active_shards

	# Shader parametrelerini güncelliyoruz
	if mat:
		var pulse: float = sin(_pulse_t * 2.2)
		var flash_amount: float = _flash_t / FLASH_DURATION if _flash_t > 0.0 else 0.0
		mat.set_shader_parameter("pulse", pulse)
		mat.set_shader_parameter("flash_amount", flash_amount)

	if overlay and is_instance_valid(overlay):
		overlay.queue_redraw()

	queue_redraw()


# Pikselli sert görünüm için koordinatları 2.0 piksel ızgaraya oturtan yardımcı fonksiyonlar
func _snap_vec(v: Vector2) -> Vector2:
	return Vector2(round(v.x / 2.0) * 2.0, round(v.y / 2.0) * 2.0)

func _snap_polyline(points: PackedVector2Array) -> PackedVector2Array:
	var snapped := PackedVector2Array()
	for pt in points:
		snapped.append(_snap_vec(pt))
	return snapped


# Overlay tarafından kalkan üstü çizimlerin yapılması
func _draw_overlay(overlay_node: Node2D) -> void:
	# 1. Pikselli Cam Çatlakları Çizimi
	for c in cracks:
		var progress: float = c.life / c.max_life
		var alpha: float = 1.0 - progress
		
		# Dış parlayan mavi kontur (Kalın, sert pikselli hat)
		var glow_color := Color(0.2, 0.75, 1.0, alpha * 0.55)
		for line in c.lines:
			var snapped_line = _snap_polyline(line)
			# antialiased = false verilerek kenarların yumuşaması engellenir, sert piksel kalır
			overlay_node.draw_polyline(snapped_line, glow_color, 3.0, false)
			
		# Net sert pikselli beyaz çekirdek kırığı
		var core_color := Color(1.0, 1.0, 1.0, alpha * 0.95)
		for line in c.lines:
			var snapped_line = _snap_polyline(line)
			overlay_node.draw_polyline(snapped_line, core_color, 1.0, false)
			
	# 2. Savrulan Cam Parçacıkları Çizimi (Top-down fragments)
	for s in shards:
		var progress: float = s.life / s.max_life
		var alpha: float = 1.0 - progress
		var s_color = s.color
		s_color.a = alpha * 0.95
		
		# Üçgen pikselli sert cam parçası çizimi
		var rot = s.rot
		var sz = s.size
		var p0 = _snap_vec(s.pos + Vector2(0.0, -sz).rotated(rot))
		var p1 = _snap_vec(s.pos + Vector2(sz * 0.6, sz * 0.5).rotated(rot))
		var p2 = _snap_vec(s.pos + Vector2(-sz * 0.6, sz * 0.5).rotated(rot))
		
		var pts := PackedVector2Array([p0, p1, p2])
		overlay_node.draw_colored_polygon(pts, s_color)
		
		# Sert beyaz parıltı çizgisi
		var glow = Color.WHITE
		glow.a = alpha * 0.6
		overlay_node.draw_polyline(PackedVector2Array([p0, p1]), glow, 1.0, false)
