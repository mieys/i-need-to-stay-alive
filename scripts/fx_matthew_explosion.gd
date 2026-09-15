extends Node2D
class_name MatthewExplosionFx

var color_glass: Color = Color(0.95, 0.55, 0.2) # Warm fox orange glass shards
var color_gold: Color = Color(1.0, 0.75, 0.35) # Soft amber sparkles
var duration: float = 1.6
var elapsed: float = 0.0

var shards: Array = []
var shockwaves: Array = []

func _ready() -> void:
	# Center it on player/dome position
	position = Vector2(0, 0)
	
	# Generate 35 glass shards flying out
	var count: int = 35
	for i in range(count):
		var angle: float = randf() * TAU
		var speed: float = randf_range(150.0, 360.0)
		var rot_speed: float = randf_range(-6.0, 6.0)
		var shard_size: float = randf_range(5.0, 10.0)
		
		shards.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"rot": randf() * TAU,
			"rot_speed": rot_speed,
			"size": shard_size,
			"life": 0.0,
			"max_life": randf_range(0.5, 1.1)
		})
		
	# Add main explosion wave (starts at radius 20, expands to 220px)
	shockwaves.append({
		"radius": 20.0,
		"max_radius": 220.0,
		"life": 0.0,
		"max_life": 0.45,
		"width": 8.0,
		"color": color_glass
	})
	
	# Add secondary wave
	shockwaves.append({
		"radius": 10.0,
		"max_radius": 180.0,
		"life": 0.0,
		"max_life": 0.55,
		"width": 3.0,
		"color": color_gold
	})

	# Play shield shattering glass sound
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(0.85, 1.0)
		s.play()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
		
	# Update shards
	for sh_item in shards:
		var sh: Dictionary = sh_item
		sh.life += delta
		sh.pos += sh.vel * delta
		sh.rot += sh.rot_speed * delta
		sh.vel *= 0.95 # air resistance
		
	# Update waves
	for w_item in shockwaves:
		var w: Dictionary = w_item
		w.life += delta
		if w.life < w.max_life:
			w.radius = lerp(20.0, w.max_radius, w.life / w.max_life)
			
	queue_redraw()

func _draw() -> void:
	var progress: float = elapsed / duration
	var fade: float = 1.0 - progress if progress > 0.6 else 1.0
	const PIXEL: float = 3.5 # Size of each retro pixel
	
	# 1. Draw expanding pixelated shockwave rings
	for w_item in shockwaves:
		var w: Dictionary = w_item
		var p: float = w.life / w.max_life
		if p >= 1.0:
			continue
		var w_color: Color = w.color
		w_color.a = 0.85 * (1.0 - p) * fade
		
		# Draw pixelated circle ring
		var current_radius: float = w.radius
		var steps: int = int(max(16, round(2.0 * PI * current_radius / PIXEL)))
		var ring_pixels: Array = []
		for i in range(steps):
			var angle: float = i * (TAU / steps)
			var raw_pos: Vector2 = Vector2(cos(angle), sin(angle)) * current_radius
			var snap_pos: Vector2 = Vector2(
				round(raw_pos.x / PIXEL) * PIXEL,
				round(raw_pos.y / PIXEL) * PIXEL
			)
			if not ring_pixels.has(snap_pos):
				ring_pixels.append(snap_pos)
		for px_item in ring_pixels:
			var px: Vector2 = px_item
			draw_rect(Rect2(px - Vector2(PIXEL/2.0, PIXEL/2.0), Vector2(PIXEL, PIXEL)), w_color)
		
	# 2. Draw shattered glass shards as pixel-art shards
	for sh_item in shards:
		var sh: Dictionary = sh_item
		var p: float = sh.life / sh.max_life
		if p >= 1.0:
			continue
			
		var s_color: Color = color_glass if randf() < 0.8 else Color.WHITE
		s_color.a = 0.9 * (1.0 - p) * fade
		
		var shard_pos: Vector2 = sh.pos
		var snap_pos: Vector2 = Vector2(
			round(shard_pos.x / PIXEL) * PIXEL,
			round(shard_pos.y / PIXEL) * PIXEL
		)
		
		var sz: float = sh.size
		var half: float = sz / 2.0
		var dir_rot: Vector2 = Vector2(cos(sh.rot), sin(sh.rot))
		var start: Vector2 = snap_pos - dir_rot * half
		var end: Vector2 = snap_pos + dir_rot * half
		
		draw_pixel_line(start, end, PIXEL, s_color)

func draw_pixel_line(start: Vector2, end: Vector2, pixel_size: float, color: Color) -> void:
	var dist: float = start.distance_to(end)
	var steps: int = int(max(1, round(dist / (pixel_size * 0.8))))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var raw: Vector2 = start.lerp(end, t)
		var p: Vector2 = Vector2(
			round(raw.x / pixel_size) * pixel_size,
			round(raw.y / pixel_size) * pixel_size
		)
		draw_rect(Rect2(p - Vector2(pixel_size/2.0, pixel_size/2.0), Vector2(pixel_size, pixel_size)), color)
