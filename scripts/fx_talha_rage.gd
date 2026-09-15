extends Node2D
class_name TalonRageFx

var color_main: Color = Color(1.0, 0.1, 0.0) # Blood red
var color_accent: Color = Color(0.4, 0.0, 0.0) # Dark crimson
var duration: float = 1.5
var elapsed: float = 0.0

var spikes: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var max_particles: int = 35

func _ready() -> void:
	# Center it on player
	position = Vector2(0, 0)
	
	# Spawn initial explosive spikes shooting outwards
	var count: int = 8
	for i in range(count):
		var angle: float = i * (TAU / count) + randf_range(-0.2, 0.2)
		spikes.append({
			"angle": angle,
			"length": 0.0,
			"max_length": randf_range(40.0, 75.0),
			"width": randf_range(8.0, 16.0),
			"speed": randf_range(250.0, 400.0)
		})
	
	# Play sound if present
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(0.6, 0.75) # Deep beastly roar/slam
		s.play()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
		
	# Update spikes
	for sp in spikes:
		if sp.length < sp.max_length:
			sp.length = min(sp.max_length, sp.length + sp.speed * delta)
			
	# Update particles
	var active_particles: Array[Dictionary] = []
	for p in particles:
		p.life += delta
		if p.life < p.max_life:
			p.pos += p.vel * delta
			active_particles.append(p)
	particles = active_particles
	
	# Spawn steam/fire particles
	if elapsed < duration - 0.4:
		if randf() < 0.25 and particles.size() < max_particles:
			_spawn_particle()
			
	queue_redraw()

func _spawn_particle() -> void:
	var angle: float = randf() * TAU
	var dist: float = randf_range(5.0, 25.0)
	var pos := Vector2(cos(angle), sin(angle)) * dist
	var vel := Vector2(randf_range(-10.0, 10.0), randf_range(-50.0, -90.0))
	particles.append({
		"pos": pos,
		"vel": vel,
		"life": 0.0,
		"max_life": randf_range(0.5, 0.9),
		"size": randf_range(2.0, 5.0),
		"color": color_main if randf() < 0.6 else color_accent
	})

func _draw() -> void:
	var progress: float = elapsed / duration
	var fade: float = 1.0 - progress if progress > 0.6 else 1.0
	
	# 1. Shockwave ground rings
	var wave_radius: float = 20.0 + progress * 60.0
	var wave_color: Color = color_main
	wave_color.a = 0.4 * (1.0 - progress)
	draw_arc(Vector2.ZERO, wave_radius, 0.0, TAU, 32, wave_color, 4.0, true)
	draw_arc(Vector2.ZERO, wave_radius * 0.7, 0.0, TAU, 24, wave_color, 2.0, true)
	
	# 2. Draw ground spikes (cracked earth)
	for sp in spikes:
		var p_color: Color = color_main
		p_color.a = 0.8 * fade
		var angle: float = sp.angle
		var length: float = sp.length
		var w: float = sp.width * (1.0 - length / sp.max_length)
		
		# Tip point
		var p_tip := Vector2(cos(angle), sin(angle)) * length
		# Base points
		var left_angle: float = angle - PI/2
		var right_angle: float = angle + PI/2
		var p_left := Vector2(cos(left_angle), sin(left_angle)) * w
		var p_right := Vector2(cos(right_angle), sin(right_angle)) * w
		
		var points := PackedVector2Array([Vector2.ZERO, p_left, p_tip, p_right])
		draw_colored_polygon(points, p_color)
		
	# 3. Draw particles
	for p in particles:
		var p_fade: float = 1.0 - (p.life / p.max_life)
		var p_color: Color = p.color
		p_color.a = p_fade * fade
		var size: float = p.size * p_fade
		
		# Draw rising flames/steam as jagged diamonds
		var center: Vector2 = p.pos
		var pts := PackedVector2Array([
			center - Vector2(0.0, size * 1.5),
			center + Vector2(size * 0.7, 0.0),
			center + Vector2(0.0, size * 0.7),
			center - Vector2(size * 0.7, 0.0)
		])
		draw_colored_polygon(pts, p_color)
