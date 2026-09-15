extends Node2D
class_name WaveBeamFx

## Magic energy wave travelling from origin to target.
## type: "heal" (green magical wave energy) or "shield" (blue thin-line wave pulses)

var start_pos: Vector2 = Vector2.ZERO
var target_node: Node2D = null
var target_pos: Vector2 = Vector2.ZERO
## Işını yayan karakter (ör. Oakley) - verilirse start_pos HER karede bu
## node'un konumunu takip eder (bkz. kullanıcı bildirimi: "efekt oakleyi
## takip etmiyor sadece takım arkadaşına doğru gidiyor"). Eskiden start_pos
## sadece setup() anında tek seferlik alınıyordu, caster hareket edince ışın
## havada asılı kalmış gibi görünüyordu.
var caster_node: Node2D = null
var fx_type: String = "heal" ## "heal" or "shield"
var duration: float = 0.8
var elapsed: float = 0.0

func setup(p_from: Vector2, p_target: Node2D, p_type: String, p_caster: Node2D = null) -> void:
	start_pos = p_from
	target_node = p_target
	caster_node = p_caster
	fx_type = p_type
	global_position = Vector2.ZERO
	if target_node and is_instance_valid(target_node):
		target_pos = target_node.global_position
	else:
		target_pos = start_pos

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	if caster_node and is_instance_valid(caster_node):
		start_pos = caster_node.global_position
	if target_node and is_instance_valid(target_node):
		target_pos = target_node.global_position
	queue_redraw()

func _draw() -> void:
	if start_pos.distance_to(target_pos) < 2.0:
		return
	
	var progress: float = clamp(elapsed / duration, 0.0, 1.0)
	var fade: float = 1.0
	if progress > 0.6:
		fade = (1.0 - progress) / 0.4
	
	var dir: Vector2 = (target_pos - start_pos).normalized()
	var normal: Vector2 = Vector2(-dir.y, dir.x)
	var total_dist: float = start_pos.distance_to(target_pos)
	
	if fx_type == "heal":
		# Green magical energy wave with lush sparkles
		var main_color := Color(0.25, 0.95, 0.45, 0.85 * fade)
		var inner_color := Color(0.85, 1.0, 0.8, 0.95 * fade)
		var glow_color := Color(0.15, 0.8, 0.35, 0.35 * fade)
		
		# Draw wavy ribbon
		var segments: int = max(16, int(total_dist / 14.0))
		var wave_pts_top := PackedVector2Array()
		var wave_pts_bot := PackedVector2Array()
		var center_pts := PackedVector2Array()
		
		for i in range(segments + 1):
			var t: float = float(i) / float(segments)
			var base_p: Vector2 = start_pos.lerp(target_pos, t)
			# Wave motion moving forward
			var wave_phase: float = t * 16.0 - elapsed * 22.0
			var wave_amp: float = sin(wave_phase) * (6.0 * sin(t * PI))
			var wave_p: Vector2 = base_p + normal * wave_amp
			center_pts.append(wave_p)
			wave_pts_top.append(wave_p + normal * (3.0 * sin(t * PI)))
			wave_pts_bot.append(wave_p - normal * (3.0 * sin(t * PI)))
			
		# Glow & Center line
		draw_polyline(center_pts, glow_color, 10.0, true)
		draw_polyline(center_pts, main_color, 4.0, true)
		draw_polyline(center_pts, inner_color, 1.5, true)
		
		# Sparkle pulses travelling along the beam
		for p_idx in range(4):
			var pulse_t: float = fmod(elapsed * 1.8 + float(p_idx) * 0.25, 1.0)
			var p_center: Vector2 = start_pos.lerp(target_pos, pulse_t) + normal * (sin(pulse_t * 16.0 - elapsed * 22.0) * 6.0 * sin(pulse_t * PI))
			draw_circle(p_center, 4.5 * sin(pulse_t * PI), inner_color)
			draw_circle(p_center, 7.0 * sin(pulse_t * PI), glow_color)
			
	else:
		# Shield: blue thin-line wave pulses travelling towards target
		var blue_core := Color(0.7, 0.9, 1.0, 0.95 * fade)
		var blue_outer := Color(0.2, 0.65, 1.0, 0.8 * fade)
		var blue_glow := Color(0.1, 0.4, 0.9, 0.3 * fade)
		
		var segments: int = max(20, int(total_dist / 10.0))
		var center_pts := PackedVector2Array()
		
		for i in range(segments + 1):
			var t: float = float(i) / float(segments)
			var base_p: Vector2 = start_pos.lerp(target_pos, t)
			# High frequency sharp thin wave
			var wave_phase: float = t * 24.0 - elapsed * 30.0
			var wave_amp: float = sin(wave_phase) * (4.5 * sin(t * PI))
			center_pts.append(base_p + normal * wave_amp)
			
		# Thin lines
		draw_polyline(center_pts, blue_glow, 6.0, true)
		draw_polyline(center_pts, blue_outer, 2.5, true)
		draw_polyline(center_pts, blue_core, 1.0, true)
		
		# Thin shockwave arcs moving along the path
		for p_idx in range(3):
			var pulse_t: float = fmod(elapsed * 2.2 + float(p_idx) * 0.33, 1.0)
			var arc_center: Vector2 = start_pos.lerp(target_pos, pulse_t)
			var arc_r: float = 12.0 * sin(pulse_t * PI)
			if arc_r > 1.0:
				var a_dir: float = dir.angle()
				draw_arc(arc_center, arc_r, a_dir - PI*0.4, a_dir + PI*0.4, 12, blue_core, 1.5, true)
				draw_arc(arc_center, arc_r * 1.3, a_dir - PI*0.3, a_dir + PI*0.3, 8, blue_outer, 1.0, true)
