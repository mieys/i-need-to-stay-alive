extends Node2D
class_name PaladinCastFx

var color_holy: Color = Color(1.0, 0.9, 0.4) # Bright gold
var color_blue: Color = Color(0.2, 0.65, 1.0) # Radiant shield blue
var duration: float = 1.6
var elapsed: float = 0.0

var cross_scale: float = 0.0
var particles: Array[Dictionary] = []
var max_particles: int = 30
var spawn_timer: float = 0.0
var spawn_rate: float = 0.04

func _ready() -> void:
	# Center it on player
	position = Vector2(0, 0)
	
	# Play heroic cast sound
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(0.8, 0.92) # Pitched down for heroic sound
		s.play()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
		
	cross_scale = min(1.0, cross_scale + delta * 3.0)
	
	# Update particles (rising holy sparkles)
	var active_particles: Array[Dictionary] = []
	for p in particles:
		p.life += delta
		if p.life < p.max_life:
			p.pos += p.vel * delta
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
	var angle: float = randf() * TAU
	var dist: float = randf_range(5.0, 35.0)
	var pos := Vector2(cos(angle), sin(angle)) * dist
	var vel := Vector2(randf_range(-12.0, 12.0), randf_range(-60.0, -100.0))
	particles.append({
		"pos": pos,
		"vel": vel,
		"life": 0.0,
		"max_life": randf_range(0.5, 0.9),
		"size": randf_range(3.0, 6.0),
		"color": color_holy if randf() < 0.7 else color_blue
	})

func _draw() -> void:
	var progress: float = elapsed / duration
	var fade: float = 1.0 - progress if progress > 0.6 else 1.0
	
	# 1. Radiant ground shield/cross (drawn as vertical/horizontal intersecting bars)
	var cross_color: Color = color_holy
	cross_color.a = 0.55 * fade
	var scale_val: float = cross_scale * 50.0
	
	# Draw cross bars
	draw_rect(Rect2(-scale_val, -8.0, scale_val * 2.0, 16.0), cross_color, true)
	draw_rect(Rect2(-8.0, -scale_val, 16.0, scale_val * 2.0), cross_color, true)
	
	# Draw inner shield/cross core
	var core_color: Color = Color.WHITE
	core_color.a = 0.8 * fade
	var core_scale: float = scale_val * 0.7
	draw_rect(Rect2(-core_scale, -4.0, core_scale * 2.0, 8.0), core_color, true)
	draw_rect(Rect2(-4.0, -core_scale, 8.0, core_scale * 2.0), core_color, true)
	
	# 2. Expanding shield shockwave ring
	var ring_radius: float = 30.0 + progress * 90.0
	var ring_color: Color = color_blue
	ring_color.a = 0.45 * (1.0 - progress) * fade
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, ring_color, 4.0, true)
	
	# 3. Draw particles (rising holy crosses)
	for p in particles:
		var p_p: float = p.life / p.max_life
		var p_color: Color = p.color
		p_color.a = (1.0 - p_p) * fade
		var sz: float = p.size * (1.0 - p_p * 0.2)
		var center: Vector2 = p.pos
		
		# Draw a small '+' cross
		draw_line(center - Vector2(0.0, sz), center + Vector2(0.0, sz), p_color, 1.5, true)
		draw_line(center - Vector2(sz, 0.0), center + Vector2(sz, 0.0), p_color, 1.5, true)
