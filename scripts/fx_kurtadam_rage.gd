extends Node2D
class_name KurtadamRageFx

var color_feral: Color = Color(1.0, 0.05, 0.1) # Bright crimson
var color_shadow: Color = Color(0.2, 0.0, 0.02) # Dark shadow crimson
var duration: float = 1.3
var elapsed: float = 0.0

var slashes: Array[Dictionary] = []
var shockwaves: Array[Dictionary] = []

func _ready() -> void:
	# Center it on player
	position = Vector2(0, 0)
	
	# Generate 3 wild slashes at random angles/offsets
	for i in range(3):
		var angle: float = randf() * TAU
		var radius: float = randf_range(25.0, 50.0)
		slashes.append({
			"angle": angle,
			"radius": radius,
			"width": randf_range(15.0, 30.0),
			"life": 0.0,
			"max_life": randf_range(0.4, 0.7),
			"delay": i * 0.15
		})
		
	# Play feral swipe sound
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(0.85, 1.0)
		s.play()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
		
	# Update slashes
	for sl in slashes:
		if elapsed >= sl.delay:
			sl.life += delta
			
	# Update shockwaves
	if elapsed < 0.8:
		if randf() < 0.12:
			shockwaves.append({
				"radius": 10.0,
				"max_radius": randf_range(60.0, 110.0),
				"life": 0.0,
				"max_life": 0.5,
				"color": color_feral if randf() < 0.7 else Color.WHITE
			})
			
	var active_waves: Array[Dictionary] = []
	for w in shockwaves:
		w.life += delta
		if w.life < w.max_life:
			w.radius = lerp(10.0, w.max_radius, w.life / w.max_life)
			active_waves.append(w)
	shockwaves = active_waves
	
	queue_redraw()

func _draw() -> void:
	var progress: float = elapsed / duration
	var fade: float = 1.0 - progress if progress > 0.6 else 1.0
	
	# 1. Draw expanding shockwaves
	for w in shockwaves:
		var p: float = w.life / w.max_life
		var w_color: Color = w.color
		w_color.a = 0.5 * (1.0 - p) * fade
		draw_arc(Vector2.ZERO, w.radius, 0.0, TAU, 32, w_color, 2.0 + (1.0 - p) * 3.0, true)
		
	# 2. Draw wild slashes
	for sl in slashes:
		if elapsed < sl.delay:
			continue
		var p: float = sl.life / sl.max_life
		if p >= 1.0:
			continue
			
		var slash_fade: float = 1.0 - p
		var s_color: Color = color_feral
		s_color.a = 0.8 * slash_fade * fade
		
		# Draw a curved slash segment (crescent shape)
		var angle: float = sl.angle
		var rad: float = sl.radius
		var width: float = sl.width * slash_fade
		
		var points := PackedVector2Array()
		var steps := 8
		var arc_spread := PI / 3.0 # 60 degrees spread
		
		# Outer arc points
		for j in range(steps + 1):
			var a: float = angle - arc_spread/2.0 + (j / float(steps)) * arc_spread
			points.append(Vector2(cos(a), sin(a)) * (rad + width/2.0))
			
		# Inner arc points (reversed)
		for j in range(steps, -1, -1):
			var a: float = angle - arc_spread/2.0 + (j / float(steps)) * arc_spread
			points.append(Vector2(cos(a), sin(a)) * (rad - width/2.0))
			
		draw_colored_polygon(points, s_color)
		
		# Inner bright core
		var core_color := Color.WHITE
		core_color.a = 0.9 * slash_fade * fade
		var core_points := PackedVector2Array()
		for j in range(steps + 1):
			var a: float = angle - arc_spread/2.3 + (j / float(steps)) * (arc_spread/1.15)
			core_points.append(Vector2(cos(a), sin(a)) * (rad + 1.0))
		draw_polyline(core_points, core_color, 2.0, true)
