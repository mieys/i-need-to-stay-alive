extends Node2D
class_name ShieldActiveFx

var color_main: Color = Color(0.3, 0.6, 1.0) # Electric blue
var color_accent: Color = Color(0.8, 0.9, 1.0) # White-blue glow
var duration: float = 1.4
var elapsed: float = 0.0

var ring_scale: float = 0.0
var particles: Array[Dictionary] = []
var max_particles: int = 25
var spawn_timer: float = 0.0
var spawn_rate: float = 0.04

func _ready() -> void:
	# Center it on player
	position = Vector2(0, 0)
	
	# Play shield regen sound
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(1.02, 1.15)
		s.play()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
		
	ring_scale = min(1.0, ring_scale + delta * 3.5)
	
	# Update particles (rising blue shield sparks)
	var active_particles: Array[Dictionary] = []
	for p in particles:
		p.life += delta
		if p.life < p.max_life:
			p.pos += p.vel * delta
			active_particles.append(p)
	particles = active_particles
	
	# Spawn sparkles
	if elapsed < duration - 0.4:
		spawn_timer += delta
		while spawn_timer >= spawn_rate:
			spawn_timer -= spawn_rate
			if particles.size() < max_particles:
				_spawn_particle()
				
	queue_redraw()

func _spawn_particle() -> void:
	var angle: float = randf() * TAU
	var dist: float = randf_range(5.0, 25.0)
	var pos := Vector2(cos(angle), sin(angle)) * dist
	var vel := Vector2(randf_range(-10.0, 10.0), randf_range(-50.0, -80.0))
	particles.append({
		"pos": pos,
		"vel": vel,
		"life": 0.0,
		"max_life": randf_range(0.4, 0.8),
		"size": randf_range(2.0, 5.0),
		"color": color_main if randf() < 0.7 else color_accent
	})

func _draw() -> void:
	var progress: float = elapsed / duration
	var fade: float = 1.0 - progress if progress > 0.6 else 1.0
	
	# 1. Ground shield polygon (hexagon barrier outline)
	var shape_color: Color = color_main
	shape_color.a = 0.5 * fade
	var radius: float = ring_scale * 36.0
	
	var pts := PackedVector2Array()
	var sides := 6
	for i in range(sides):
		var a: float = i * (TAU / sides)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	pts.append(pts[0]) # close loop
	
	draw_polyline(pts, shape_color, 2.0, true)
	
	# Draw concentric inner hexagon
	var inner_color: Color = color_accent
	inner_color.a = 0.3 * fade
	var inner_pts := PackedVector2Array()
	for i in range(sides):
		var a: float = i * (TAU / sides)
		inner_pts.append(Vector2(cos(a), sin(a)) * (radius * 0.7))
	inner_pts.append(inner_pts[0])
	draw_polyline(inner_pts, inner_color, 1.0, true)
	
	# 2. Draw sparkles (tiny square bits)
	for p in particles:
		var p_p: float = p.life / p.max_life
		var p_color: Color = p.color
		p_color.a = (1.0 - p_p) * fade
		var sz: float = p.size * (1.0 - p_p * 0.2)
		draw_rect(Rect2(p.pos.x - sz/2.0, p.pos.y - sz/2.0, sz, sz), p_color, true)
