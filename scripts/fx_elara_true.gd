extends Node2D
class_name ElaraTrueFx

var color_main: Color = Color(1.0, 0.7, 0.0) # Sharp orange-gold
var color_laser: Color = Color(1.0, 0.95, 0.8) # Piercing white-gold
var duration: float = 1.4
var elapsed: float = 0.0

var target_rotation: float = 0.0
var target_rot_speed: float = 3.5

var lasers: Array[Dictionary] = []

func _ready() -> void:
	# Center it on player
	position = Vector2(0, 0)
	
	# Play piercing arrow shot sound
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(1.05, 1.18)
		s.play()
		
	# Generate vertical piercing lasers
	for i in range(5):
		lasers.append({
			"x_offset": randf_range(-25.0, 25.0),
			"height": 0.0,
			"max_height": randf_range(80.0, 140.0),
			"width": randf_range(1.5, 3.5),
			"speed": randf_range(400.0, 600.0),
			"delay": i * 0.08
		})

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
		
	target_rotation += target_rot_speed * delta
	
	# Update lasers
	for l in lasers:
		if elapsed >= l.delay:
			l.height = min(l.max_height, l.height + l.speed * delta)
			
	queue_redraw()

func _draw() -> void:
	var progress: float = elapsed / duration
	var fade: float = 1.0 - progress if progress > 0.6 else 1.0
	
	# 1. Draw spinning ground crosshairs (Lock-on target)
	var crosshair_radius: float = 24.0
	var c_color: Color = color_main
	c_color.a = 0.65 * fade
	
	# Draw outer ring
	draw_arc(Vector2.ZERO, crosshair_radius, 0.0, TAU, 32, c_color, 1.5, true)
	
	# Draw 4 crosshair ticks rotating
	for i in range(4):
		var a: float = target_rotation + i * (TAU / 4.0)
		var p_start := Vector2(cos(a), sin(a)) * (crosshair_radius - 4.0)
		var p_end := Vector2(cos(a), sin(a)) * (crosshair_radius + 4.0)
		draw_line(p_start, p_end, c_color, 2.0, true)
		
	# 2. Draw vertical lasers/piercing spikes shooting up
	for l in lasers:
		if elapsed < l.delay:
			continue
		var l_progress: float = l.height / l.max_height
		var l_fade: float = 1.0 - l_progress
		var laser_color: Color = color_laser
		laser_color.a = 0.8 * l_fade * fade
		
		# Draw laser beam line
		var p_base := Vector2(l.x_offset, 15.0)
		var p_tip := Vector2(l.x_offset, 15.0 - l.height)
		draw_line(p_base, p_tip, laser_color, l.width, true)
		
		# Draw horizontal core glow
		var glow_color := color_main
		glow_color.a = 0.4 * l_fade * fade
		draw_line(p_base, p_tip, glow_color, l.width * 2.5, true)
