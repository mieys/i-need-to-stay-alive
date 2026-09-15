extends Node2D
class_name OykuHealFx

var color_magic: Color = Color(0.2, 1.0, 0.4) # Green magic
var color_gold: Color = Color(1.0, 0.9, 0.3) # Gold sparkle
var duration: float = 1.8
var elapsed: float = 0.0

var star_rotation: float = 0.0
var star_rot_speed: float = 2.0 # rad/sec

var particles: Array[Dictionary] = []
var max_particles: int = 40
var spawn_timer: float = 0.0
var spawn_rate: float = 0.03 # spawn every 0.03 seconds

func _ready() -> void:
	# Center it under the player's feet (offset a bit downwards to cover the ground/legs)
	position = Vector2(0, 0)
	
	# Play sound if present
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(0.95, 1.05)
		s.play()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
		
	# Rotate the star
	star_rotation += star_rot_speed * delta
	
	# Update existing particles
	var active_particles: Array[Dictionary] = []
	for p in particles:
		p.life += delta
		if p.life < p.max_life:
			p.pos += p.vel * delta
			# Add a bit of horizontal sway
			p.vel.x += sin(elapsed * 10.0 + p.pos.y * 0.1) * 30.0 * delta
			active_particles.append(p)
	particles = active_particles
	
	# Spawn new particles
	if elapsed < duration - 0.5: # stop spawning near the end
		spawn_timer += delta
		while spawn_timer >= spawn_rate:
			spawn_timer -= spawn_rate
			if particles.size() < max_particles:
				_spawn_one_particle()
				
	queue_redraw()

func _spawn_one_particle() -> void:
	# Random angle and radius for start position (within magic circle)
	var angle: float = randf() * TAU
	var dist: float = randf_range(5.0, 30.0)
	var start_pos := Vector2(cos(angle), sin(angle)) * dist
	
	# Healing cross or sparkles
	var is_cross: bool = randf() < 0.6
	var max_life: float = randf_range(0.6, 1.1)
	var size: float = randf_range(3.0, 6.0)
	var p_color: Color = color_magic if randf() < 0.7 else color_gold
	
	var vel := Vector2(randf_range(-15.0, 15.0), randf_range(-70.0, -110.0))
	
	particles.append({
		"pos": start_pos,
		"vel": vel,
		"life": 0.0,
		"max_life": max_life,
		"size": size,
		"is_cross": is_cross,
		"color": p_color
	})

func _draw() -> void:
	var progress: float = elapsed / duration
	var fade: float = 1.0
	if progress > 0.7:
		fade = (1.0 - progress) / 0.3
		
	# 1. Glowing background aura under feet
	var aura_color: Color = color_magic
	aura_color.a = 0.12 * fade * (1.0 - progress * 0.5)
	draw_circle(Vector2.ZERO, 40.0 * (1.0 + progress * 0.3), aura_color)
	
	# 2. Main Magic Circle ring
	var ring_radius: float = 35.0 * (1.0 + progress * 0.2)
	var ring_color: Color = color_magic
	ring_color.a = 0.6 * fade
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 40, ring_color, 2.0, true)
	
	# 3. Outer dotted ring
	var outer_color: Color = color_gold
	outer_color.a = 0.4 * fade
	var dots: int = 12
	for i in range(dots):
		var a: float = star_rotation * 0.5 + i * (TAU / dots)
		draw_circle(Vector2(cos(a), sin(a)) * (ring_radius + 6.0), 1.5, outer_color)
		
	# 4. Inner hexagram star
	var star_color: Color = color_gold
	star_color.a = 0.5 * fade
	var angle_step: float = TAU / 6.0
	var star_radius: float = ring_radius * 0.8
	for i in range(6):
		var a1: float = i * angle_step + star_rotation
		var a2: float = (i + 2) * angle_step + star_rotation
		var p1 := Vector2(cos(a1), sin(a1)) * star_radius
		var p2 := Vector2(cos(a2), sin(a2)) * star_radius
		draw_line(p1, p2, star_color, 1.5, true)
		
	# 5. Expanding secondary pulse ring
	if progress < 0.5:
		var pulse_p: float = progress / 0.5
		var pulse_radius: float = ring_radius * pulse_p
		var pulse_color: Color = color_magic
		pulse_color.a = 0.5 * (1.0 - pulse_p)
		draw_arc(Vector2.ZERO, pulse_radius, 0.0, TAU, 32, pulse_color, 1.0, true)

	# 6. Draw particles (healing crosses & star sparkles)
	for p in particles:
		var p_fade: float = 1.0 - (p.life / p.max_life)
		var p_color: Color = p.color
		p_color.a = p_fade * fade
		var center: Vector2 = p.pos
		var sz: float = p.size
		
		if p.is_cross:
			# Draw '+' shape
			draw_line(center - Vector2(0.0, sz), center + Vector2(0.0, sz), p_color, 1.5, true)
			draw_line(center - Vector2(sz, 0.0), center + Vector2(sz, 0.0), p_color, 1.5, true)
		else:
			# Draw diamond sparkle
			var pts: PackedVector2Array = PackedVector2Array([
				center - Vector2(0.0, sz),
				center + Vector2(sz * 0.6, 0.0),
				center + Vector2(0.0, sz),
				center - Vector2(sz * 0.6, 0.0)
			])
			draw_colored_polygon(pts, p_color)
