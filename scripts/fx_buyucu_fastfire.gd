extends Node2D
class_name BuyucuFastfireFx

var color_main: Color = Color(1.0, 0.9, 0.1) # Glowing yellow
var color_magic: Color = Color(1.0, 0.6, 0.0) # Golden orange
var duration: float = 1.6
var elapsed: float = 0.0

var ring_rotation: float = 0.0
var ring_rot_speed: float = 3.0 # fast rotation

var particles: Array[Dictionary] = []
var max_particles: int = 35
var spawn_timer: float = 0.0
var spawn_rate: float = 0.03

func _ready() -> void:
	# Center it on player
	position = Vector2(0, 0)
	
	# Play magic casting sweep sound
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(0.95, 1.08)
		s.play()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
		
	# Rotate magic ring
	ring_rotation += ring_rot_speed * delta
	
	# Update particles
	var active_particles: Array[Dictionary] = []
	for p in particles:
		p.life += delta
		if p.life < p.max_life:
			p.pos += p.vel * delta
			# Spiral/attraction motion
			p.pos = p.pos.rotated(delta * 2.5)
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
	# Spawn on a circle, drifting upwards
	var angle: float = randf() * TAU
	var radius: float = randf_range(10.0, 32.0)
	var pos := Vector2(cos(angle), sin(angle)) * radius
	var vel := Vector2(0.0, randf_range(-60.0, -100.0))
	particles.append({
		"pos": pos,
		"vel": vel,
		"life": 0.0,
		"max_life": randf_range(0.5, 0.9),
		"size": randf_range(2.0, 4.0),
		"color": color_main if randf() < 0.6 else color_magic
	})

func _draw() -> void:
	var progress: float = elapsed / duration
	var fade: float = 1.0 - progress if progress > 0.6 else 1.0
	
	# 1. Outer Magic Ring
	var radius: float = 34.0 * (1.0 + progress * 0.15)
	var ring_color: Color = color_magic
	ring_color.a = 0.6 * fade
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, ring_color, 1.5, true)
	
	# 2. Haste Speed Chevrons inside the ring (rotating)
	var chevron_color: Color = color_main
	chevron_color.a = 0.5 * fade
	var count: int = 4
	for i in range(count):
		var a: float = ring_rotation + i * (TAU / count)
		# Draw a speed arrow (chevron) pointing outward
		var p_center := Vector2(cos(a), sin(a)) * (radius * 0.6)
		# Chevron shape
		var d_forward := Vector2(cos(a), sin(a)) * 6.0
		var d_side := Vector2(-sin(a), cos(a)) * 5.0
		
		var pt1 := p_center + d_forward
		var pt2 := p_center - d_forward * 0.5 + d_side
		var pt3 := p_center - d_forward * 0.5 - d_side
		
		draw_line(pt2, pt1, chevron_color, 2.0, true)
		draw_line(pt3, pt1, chevron_color, 2.0, true)
		
	# 3. Clock/Hourglass shape in the exact center (rotating opposite direction)
	var glass_color: Color = color_main
	glass_color.a = 0.4 * fade
	var glass_rotation := -ring_rotation * 0.4
	var sz := 8.0
	var pts := PackedVector2Array([
		Vector2(-sz, -sz).rotated(glass_rotation),
		Vector2(sz, -sz).rotated(glass_rotation),
		Vector2(0.0, 0.0),
		Vector2(sz, sz).rotated(glass_rotation),
		Vector2(-sz, sz).rotated(glass_rotation),
		Vector2(0.0, 0.0)
	])
	draw_colored_polygon(pts, glass_color)
	
	# 4. Particles (sparkles & speed streaks)
	for p in particles:
		var p_fade: float = 1.0 - (p.life / p.max_life)
		var p_color: Color = p.color
		p_color.a = p_fade * fade
		var size: float = p.size
		
		# Speed streak (vertical line)
		draw_line(p.pos - Vector2(0.0, size * 2.0), p.pos, p_color, 1.5, true)
		# Core dot
		draw_circle(p.pos, size * 0.5, Color.WHITE)
