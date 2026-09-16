extends Node2D
class_name MatthewSacrificeFx

var color_main: Color = Color(0.95, 0.55, 0.2) # Warm fox orange
var color_accent: Color = Color(1.0, 0.75, 0.35) # Soft amber peach
var duration: float = 1.5
var elapsed: float = 0.0

var rotation_angle: float = 0.0
var rot_speed: float = 2.2

var particles: Array[Dictionary] = []
var max_particles: int = 30
var spawn_timer: float = 0.0
var spawn_rate: float = 0.04

func _ready() -> void:
	# Center it on player
	position = Vector2(0, 0)
	
	# Play sacrifice soul sound
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(0.95, 1.05)
		s.play()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
		
	rotation_angle += rot_speed * delta
	
	# Update particles
	var active_particles: Array[Dictionary] = []
	for p in particles:
		p.life += delta
		if p.life < p.max_life:
			p.pos += p.vel * delta
			# Swirling breeze motion
			p.pos = p.pos.rotated(delta * 1.5)
			active_particles.append(p)
	particles = active_particles
	
	# Spawn feather particles
	if elapsed < duration - 0.4:
		spawn_timer += delta
		while spawn_timer >= spawn_rate:
			spawn_timer -= spawn_rate
			if particles.size() < max_particles:
				_spawn_particle()
				
	queue_redraw()

func _spawn_particle() -> void:
	var angle: float = randf() * TAU
	var dist: float = randf_range(5.0, 28.0)
	var pos := Vector2(cos(angle), sin(angle)) * dist
	var vel := Vector2(0.0, randf_range(-50.0, -90.0))
	particles.append({
		"pos": pos,
		"vel": vel,
		"life": 0.0,
		"max_life": randf_range(0.6, 1.0),
		"size": randf_range(3.0, 6.0),
		"color": color_main if randf() < 0.7 else color_accent,
		"rot": randf() * TAU,
		"rot_speed": randf_range(-2.0, 2.0)
	})

func _draw() -> void:
	var progress: float = elapsed / duration
	var fade: float = 1.0 - progress if progress > 0.6 else 1.0
	
	# 1. Glowing ground ring
	var radius: float = 30.0 * (1.0 + progress * 0.2)
	var ring_color: Color = color_main
	ring_color.a = 0.55 * fade
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, ring_color, 1.5, true)
	
	# 2. Concentric inner triangle (shield indicator)
	var tri_color: Color = color_accent
	tri_color.a = 0.4 * fade
	var steps := 3
	var tri_pts := PackedVector2Array()
	for i in range(steps):
		var a: float = rotation_angle + i * (TAU / steps)
		tri_pts.append(Vector2(cos(a), sin(a)) * (radius * 0.75))
	tri_pts.append(tri_pts[0]) # close loop
	draw_polyline(tri_pts, tri_color, 2.0, true)
	
	# 3. Draw particles (swirling blue soul feathers)
	for p in particles:
		var p_p: float = p.life / p.max_life
		var p_color: Color = p.color
		p_color.a = (1.0 - p_p) * fade
		var sz: float = p.size * (1.0 - p_p * 0.3)
		var p_rot: float = p.rot + p.rot_speed * p.life
		
		# Draw feather-like diamond shape
		var center: Vector2 = p.pos
		var pts := PackedVector2Array([
			center + Vector2(0.0, -sz * 1.5).rotated(p_rot),
			center + Vector2(sz * 0.6, 0.0).rotated(p_rot),
			center + Vector2(0.0, sz * 0.6).rotated(p_rot),
			center + Vector2(-sz * 0.6, 0.0).rotated(p_rot)
		])
		draw_colored_polygon(pts, p_color)
