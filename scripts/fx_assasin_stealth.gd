extends Node2D
class_name AssasinStealthFx

var color_main: Color = Color(0.5, 0.2, 0.9) # Dark purple
var color_shadow: Color = Color(0.1, 0.05, 0.2) # Deep shadow violet
var duration: float = 1.4
var elapsed: float = 0.0

var puffs: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var max_particles: int = 30

func _ready() -> void:
	# Center it on player
	position = Vector2(0, 0)
	
	# Spawn initial dark smoke puffs expanding outwards
	var count: int = 6
	for i in range(count):
		var angle: float = i * (TAU / count) + randf_range(-0.3, 0.3)
		var speed: float = randf_range(30.0, 60.0)
		puffs.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"radius": randf_range(8.0, 15.0),
			"life": 0.0,
			"max_life": randf_range(0.5, 0.8)
		})
		
	# Play dark magic woosh sound
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(0.85, 1.0)
		s.play()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
		
	# Update puffs
	for p in puffs:
		p.life += delta
		p.pos += p.vel * delta
		p.vel *= 0.9 # slow down
		
	# Update particles
	var active_particles: Array[Dictionary] = []
	for p in particles:
		p.life += delta
		if p.life < p.max_life:
			p.pos += p.vel * delta
			active_particles.append(p)
	particles = active_particles
	
	# Spawn dark shadow wisps
	if elapsed < duration - 0.4:
		if randf() < 0.22 and particles.size() < max_particles:
			_spawn_particle()
			
	queue_redraw()

func _spawn_particle() -> void:
	var angle: float = randf() * TAU
	var dist: float = randf_range(2.0, 20.0)
	var pos := Vector2(cos(angle), sin(angle)) * dist
	var vel := Vector2(randf_range(-8.0, 8.0), randf_range(-40.0, -70.0))
	particles.append({
		"pos": pos,
		"vel": vel,
		"life": 0.0,
		"max_life": randf_range(0.4, 0.7),
		"radius": randf_range(2.0, 5.5),
		"color": color_main if randf() < 0.6 else color_shadow
	})

func _draw() -> void:
	var progress: float = elapsed / duration
	var fade: float = 1.0 - progress if progress > 0.6 else 1.0
	
	# 1. Dark Shadow Pool under feet
	var pool_radius: float = 28.0 * (1.0 - progress * 0.3)
	var pool_color: Color = color_shadow
	pool_color.a = 0.65 * fade
	draw_circle(Vector2.ZERO, pool_radius, pool_color)
	
	# Draw a secondary ring around the pool
	var ring_color: Color = color_main
	ring_color.a = 0.3 * fade
	draw_arc(Vector2.ZERO, pool_radius + 4.0, 0.0, TAU, 32, ring_color, 1.5, true)
	
	# 2. Draw initial smoke puffs
	for p in puffs:
		var p_p: float = p.life / p.max_life
		if p_p >= 1.0:
			continue
		var puff_color: Color = color_shadow.lerp(color_main, 0.3)
		puff_color.a = 0.45 * (1.0 - p_p) * fade
		draw_circle(p.pos, p.radius * (1.0 + p_p * 0.5), puff_color)
		
	# 3. Draw shadow particles (rising wisps)
	for p in particles:
		var p_p: float = p.life / p.max_life
		var p_color: Color = p.color
		p_color.a = (1.0 - p_p) * fade * 0.7
		var r: float = p.radius * (1.0 - p_p * 0.3)
		
		# Draw shadow wisp as a soft blob
		draw_circle(p.pos, r, p_color)
		# Draw a small core to give it form
		var core_color := Color.BLACK
		core_color.a = 0.3 * (1.0 - p_p) * fade
		draw_circle(p.pos, r * 0.5, core_color)
