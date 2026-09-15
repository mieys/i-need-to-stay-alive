extends Node2D
class_name PaladinShatterFx

var color_glass: Color = Color(0.35, 0.78, 1.0) # Radiant shield blue
var color_accent: Color = Color(0.85, 0.96, 1.0) # Glowing white-blue
var duration: float = 1.6
var elapsed: float = 0.0

var shards: Array[Dictionary] = []
var shockwaves: Array[Dictionary] = []

func _ready() -> void:
	# Generate 45 glass shards flying out in a circular pattern (top-down view)
	var count := 45
	var radius_start := 126.0
	for i in range(count):
		# Angles distributed around the circle
		var angle := (i / float(count)) * TAU + randf_range(-0.1, 0.1)
		
		# Starting position on the kalkan perimeter
		var start_pos := Vector2(cos(angle), sin(angle)) * radius_start
		
		# Outward push velocity
		var speed := randf_range(80.0, 220.0)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		
		# Shard geometry
		var shard_size := randf_range(2.0, 5.0)
		var rot := randf() * TAU
		var rot_speed := randf_range(-8.0, 8.0)
		
		shards.append({
			"pos": start_pos,
			"vel": vel,
			"size": shard_size,
			"rot": rot,
			"rot_speed": rot_speed,
			"life": 0.0,
			"max_life": randf_range(0.4, 0.8),
			"color": color_glass if randf() < 0.75 else color_accent
		})
		
	# Add the expanding shatter shockwave ring (radius 126 to 200)
	shockwaves.append({
		"radius": 126.0,
		"max_radius": 200.0,
		"life": 0.0,
		"max_life": 0.40,
		"width": 6.0,
		"color": color_glass
	})
	
	# Play sound if present
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(0.82, 0.95) # Deep shatter sound
		s.play()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
		
	# Update glass shards (friction slowing them down, no gravity)
	var active_shards: Array[Dictionary] = []
	for sh in shards:
		sh.life += delta
		if sh.life < sh.max_life:
			sh.pos += sh.vel * delta
			sh.vel *= 0.90 # Sürtünme yavaşlaması
			sh.rot += sh.rot_speed * delta
			active_shards.append(sh)
	shards = active_shards
	
	# Update shockwave rings
	for w in shockwaves:
		w.life += delta
		if w.life < w.max_life:
			w.radius = lerp(126.0, w.max_radius, w.life / w.max_life)
			
	queue_redraw()

# Snap coordinates to a 2.0 pixel grid for modern pixel art appearance
func _snap_vec(v: Vector2) -> Vector2:
	return Vector2(round(v.x / 2.0) * 2.0, round(v.y / 2.0) * 2.0)

func _draw() -> void:
	var progress: float = elapsed / duration
	var fade: float = 1.0 - progress if progress > 0.6 else 1.0
	
	# 1. Draw expanding shockwave rings (pikselli halka)
	for w in shockwaves:
		var p: float = w.life / w.max_life
		if p >= 1.0:
			continue
		var w_color: Color = w.color
		w_color.a = 0.7 * (1.0 - p) * fade
		
		# Draw pikselli circle outline using lines
		var steps := 64
		var points := PackedVector2Array()
		for i in range(steps + 1):
			var a: float = i * (TAU / steps)
			points.append(_snap_vec(Vector2(cos(a), sin(a)) * w.radius))
		draw_polyline(points, w_color, w.width * (1.0 - p), false)
		
	# 2. Draw shattered glass shards (pikselli kıymıklar)
	for sh in shards:
		var p: float = sh.life / sh.max_life
		if p >= 1.0:
			continue
			
		var s_color: Color = sh.color
		s_color.a = (1.0 - p) * fade
		
		var rot: float = sh.rot
		var sz: float = sh.size
		var p0 := _snap_vec(sh.pos + Vector2(0.0, -sz).rotated(rot))
		var p1 := _snap_vec(sh.pos + Vector2(sz * 0.6, sz * 0.5).rotated(rot))
		var p2 := _snap_vec(sh.pos + Vector2(-sz * 0.6, sz * 0.5).rotated(rot))
		
		var pts := PackedVector2Array([p0, p1, p2])
		draw_colored_polygon(pts, s_color)
		
		var glow := Color.WHITE
		glow.a = (1.0 - p) * fade * 0.5
		draw_polyline(PackedVector2Array([p0, p1]), glow, 1.0, false)
