extends Node2D
class_name ElaraDoubleFx

var color_main: Color = Color(1.0, 0.8, 0.2) # Golden yellow
var color_wind: Color = Color(0.9, 0.9, 0.9) # Light wind white
var duration: float = 1.6
var elapsed: float = 0.0

var wings_progress: float = 0.0
var particles: Array[Dictionary] = []
var max_particles: int = 35
var spawn_timer: float = 0.0
var spawn_rate: float = 0.03

func _ready() -> void:
	# Center it on player
	position = Vector2(0, 0)
	
	# Play arrow fire sound
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(0.95, 1.05)
		s.play()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
		
	# Animate wings expanding outward
	wings_progress = min(1.0, wings_progress + delta * 2.5)
	
	# Update particles (feathers/leaves swirling in a cyclone)
	var active_particles: Array[Dictionary] = []
	for p in particles:
		p.life += delta
		if p.life < p.max_life:
			# Swirl angle increases over time
			p.angle += p.rot_speed * delta
			# Radius shrinks/expands to create vortex
			p.radius += p.radius_speed * delta
			# Drift upwards
			p.y_offset += p.y_vel * delta
			
			p.pos = Vector2(cos(p.angle), sin(p.angle) * 0.5) * p.radius + Vector2(0.0, p.y_offset)
			active_particles.append(p)
	particles = active_particles
	
	# Spawn feathers
	if elapsed < duration - 0.4:
		spawn_timer += delta
		while spawn_timer >= spawn_rate:
			spawn_timer -= spawn_rate
			if particles.size() < max_particles:
				_spawn_particle()
				
	queue_redraw()

func _spawn_particle() -> void:
	var angle: float = randf() * TAU
	var radius: float = randf_range(15.0, 45.0)
	particles.append({
		"pos": Vector2.ZERO,
		"angle": angle,
		"radius": radius,
		"radius_speed": randf_range(-15.0, 25.0),
		"rot_speed": randf_range(3.0, 6.0),
		"y_offset": randf_range(-5.0, 10.0),
		"y_vel": randf_range(-30.0, -70.0),
		"life": 0.0,
		"max_life": randf_range(0.6, 1.0),
		"size": randf_range(3.0, 6.0),
		"color": color_main if randf() < 0.7 else color_wind,
		"spin": randf() * TAU,
		"spin_speed": randf_range(-4.0, 4.0)
	})

func _draw() -> void:
	var progress: float = elapsed / duration
	var fade: float = 1.0 - progress if progress > 0.6 else 1.0
	
	# 1. Draw Golden Wings expanding from back (drawn as elegant lines)
	var wing_color: Color = color_main
	wing_color.a = 0.65 * fade * (1.0 - wings_progress * 0.3)
	var w_scale: float = wings_progress * 45.0
	
	# Left Wing Polyline
	var left_wing := PackedVector2Array([
		Vector2(0, -10),
		Vector2(-w_scale * 0.4, -20),
		Vector2(-w_scale * 0.8, -15),
		Vector2(-w_scale, -5),
		Vector2(-w_scale * 0.7, 5),
		Vector2(-w_scale * 0.4, 0),
		Vector2(0, -10)
	])
	
	# Right Wing Polyline
	var right_wing := PackedVector2Array([
		Vector2(0, -10),
		Vector2(w_scale * 0.4, -20),
		Vector2(w_scale * 0.8, -15),
		Vector2(w_scale, -5),
		Vector2(w_scale * 0.7, 5),
		Vector2(w_scale * 0.4, 0),
		Vector2(0, -10)
	])
	
	draw_polyline(left_wing, wing_color, 2.0, true)
	draw_polyline(right_wing, wing_color, 2.0, true)
	
	# Draw wing feathers detail
	var detail_color: Color = color_wind
	detail_color.a = 0.45 * fade * (1.0 - wings_progress * 0.3)
	draw_line(Vector2(0, -10), Vector2(-w_scale * 0.75, -5), detail_color, 1.5, true)
	draw_line(Vector2(0, -10), Vector2(w_scale * 0.75, -5), detail_color, 1.5, true)
	
	# 2. Draw cyclone particles (floating golden feathers/leaves)
	for p in particles:
		var p_p: float = p.life / p.max_life
		var p_color: Color = p.color
		p_color.a = (1.0 - p_p) * fade
		var sz: float = p.size * (1.0 - p_p * 0.2)
		var p_spin: float = p.spin + p.spin_speed * p.life
		
		# Draw a leafy/feather shape (elongated diamond)
		var center: Vector2 = p.pos
		var pts := PackedVector2Array([
			center + Vector2(0.0, -sz * 1.5).rotated(p_rot_offset(p_spin)),
			center + Vector2(sz * 0.4, 0.0).rotated(p_rot_offset(p_spin)),
			center + Vector2(0.0, sz * 0.4).rotated(p_rot_offset(p_spin)),
			center + Vector2(-sz * 0.4, 0.0).rotated(p_rot_offset(p_spin))
		])
		draw_colored_polygon(pts, p_color)

func p_rot_offset(angle: float) -> float:
	return angle
