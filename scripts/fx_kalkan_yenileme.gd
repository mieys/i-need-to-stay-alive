extends Node2D
class_name KalkanYenilemeFx

var color_shield: Color = Color(0.2, 0.65, 1.0) # Shield blue
var color_glow: Color = Color(0.7, 0.9, 1.0) # Light blue glow
var duration: float = 1.6
var elapsed: float = 0.0

var ring_rotation: float = 0.0
var ring_rot_speed: float = -2.5

var particles: Array[Dictionary] = []
var max_particles: int = 30
var spawn_timer: float = 0.0
var spawn_rate: float = 0.04

func _ready() -> void:
	# Center on player
	position = Vector2(0, 0)
	
	# Play sound if present
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(1.0, 1.12)
		s.play()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
		
	ring_rotation += ring_rot_speed * delta
	
	# Update particles (gathering from outer area towards player)
	var active_particles: Array[Dictionary] = []
	for p in particles:
		p.life += delta
		if p.life < p.max_life:
			# Move towards center (implode effect)
			var progress: float = p.life / p.max_life
			p.pos = p.start_pos.lerp(Vector2.ZERO, progress)
			active_particles.append(p)
	particles = active_particles
	
	# Spawn particles
	if elapsed < duration - 0.4:
		spawn_timer += delta
		while spawn_timer >= spawn_rate:
			spawn_timer -= spawn_rate
			if particles.size() < max_particles:
				_spawn_particle()
				
	queue_redraw()

func _spawn_particle() -> void:
	# Spawn at a distance and float inwards
	var angle: float = randf() * TAU
	var start_dist: float = randf_range(45.0, 75.0)
	var start_pos := Vector2(cos(angle), sin(angle)) * start_dist
	
	particles.append({
		"start_pos": start_pos,
		"pos": start_pos,
		"life": 0.0,
		"max_life": randf_range(0.5, 0.8),
		"size": randf_range(3.0, 6.0),
		"color": color_shield if randf() < 0.6 else color_glow
	})

func _draw() -> void:
	var progress: float = elapsed / duration
	var fade: float = 1.0 - progress if progress > 0.6 else 1.0
	
	# 1. Rotating shield barrier hex-ring on the ground
	var r: float = 28.0 * (1.0 + progress * 0.1)
	var ring_color: Color = color_shield
	ring_color.a = 0.6 * fade
	
	# Draw outer hexagon
	var sides := 6
	var pts := PackedVector2Array()
	for i in range(sides):
		var a: float = ring_rotation + i * (TAU / sides)
		pts.append(Vector2(cos(a), sin(a)) * r)
	pts.append(pts[0])
	draw_polyline(pts, ring_color, 2.0, true)
	
	# 2. Draw little shield icons inside the vertices of the hexagon
	var icon_color: Color = color_glow
	icon_color.a = 0.5 * fade
	for i in range(sides):
		var a: float = ring_rotation + i * (TAU / sides)
		var p_vertex := Vector2(cos(a), sin(a)) * r
		draw_circle(p_vertex, 2.0, icon_color)
		
	# 3. Draw imploding shield spark particles
	for p in particles:
		var p_p: float = p.life / p.max_life
		var p_color: Color = p.color
		p_color.a = (1.0 - p_p) * fade
		var sz: float = p.size * (1.0 - p_p * 0.3)
		var center: Vector2 = p.pos
		
		# Draw a small shield crest (diamond with flat top)
		var d_pts := PackedVector2Array([
			center - Vector2(0, sz),
			center + Vector2(sz * 0.7, -sz * 0.3),
			center + Vector2(0, sz),
			center - Vector2(sz * 0.7, -sz * 0.3)
		])
		draw_colored_polygon(d_pts, p_color)
