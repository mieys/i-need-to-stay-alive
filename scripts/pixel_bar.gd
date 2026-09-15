extends Control

@export var border_color: Color = Color(0.25, 0.15, 0.08)
@export var bg_color: Color = Color(0.15, 0.05, 0.05)
@export var fill_color_a: Color = Color(0.25, 0.85, 0.35)
@export var fill_color_b: Color = Color(0.45, 0.95, 0.35)
@export var icon_type: String = "heart"

var value: float = 100.0
var max_value: float = 100.0
var display_ratio: float = 1.0


func set_value(v: float, mv: float) -> void:
	value = v
	max_value = max(mv, 0.001)


func _process(delta: float) -> void:
	var target_ratio: float = clamp(value / max_value, 0.0, 1.0)
	if abs(display_ratio - target_ratio) > 0.001:
		display_ratio = move_toward(display_ratio, target_ratio, delta * 1.6)
		queue_redraw()


func _hex_rect(x: float, y: float, w: float, h: float, cut: float) -> PackedVector2Array:
	if w <= cut:
		cut = max(w * 0.5, 0.0)
	return PackedVector2Array([
		Vector2(x, y), Vector2(x + w - cut, y), Vector2(x + w, y + h * 0.5),
		Vector2(x + w - cut, y + h), Vector2(x, y + h)
	])


func _diamond(center: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)
	])


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var icon_w: float = h

	var bar_x: float = icon_w + 6.0
	var bar_w: float = w - bar_x - 2.0
	var cut: float = h * 0.32

	draw_colored_polygon(_hex_rect(bar_x, 1, bar_w, h - 2, cut), border_color)

	var inner_x: float = bar_x + 5.0
	var inner_y: float = 5.0
	var inner_w: float = bar_w - 10.0
	var inner_h: float = h - 10.0
	var inner_cut: float = cut * 0.8
	draw_colored_polygon(_hex_rect(inner_x, inner_y, inner_w, inner_h, inner_cut), bg_color)

	var fill_w: float = inner_w * display_ratio
	if fill_w > 2.0:
		if display_ratio > 0.9:
			draw_colored_polygon(_hex_rect(inner_x, inner_y, fill_w, inner_h, inner_cut), fill_color_a)
		else:
			draw_rect(Rect2(inner_x, inner_y, fill_w, inner_h), fill_color_a)
		draw_rect(Rect2(inner_x, inner_y, fill_w, inner_h * 0.4), fill_color_b)
		if fill_w > 22.0:
			var sx: float = inner_x + fill_w - 14.0
			draw_rect(Rect2(sx, inner_y + inner_h * 0.15, 5, inner_h * 0.55), Color(1, 1, 1, 0.8))

	var mc := Vector2(icon_w * 0.5, h * 0.5)
	var mr: float = icon_w * 0.46

	var leaf_col := Color(0.28, 0.55, 0.22)
	draw_colored_polygon(PackedVector2Array([
		mc + Vector2(-mr - 1, -mr * 0.35), mc + Vector2(-mr - 11, -mr * 0.7), mc + Vector2(-mr + 3, -mr * 0.05)
	]), leaf_col)
	draw_colored_polygon(PackedVector2Array([
		mc + Vector2(-mr - 1, mr * 0.55), mc + Vector2(-mr - 11, mr * 0.85), mc + Vector2(-mr + 3, mr * 0.3)
	]), leaf_col)

	draw_colored_polygon(_diamond(mc, mr + 3.0), border_color)
	draw_colored_polygon(_diamond(mc, mr - 2.0), Color(0.42, 0.3, 0.18))
	draw_colored_polygon(_diamond(mc, mr - 6.0), Color(0.92, 0.87, 0.72))

	if icon_type == "heart":
		_draw_heart(mc)
	elif icon_type == "shield":
		_draw_shield_icon(mc)
	else:
		_draw_star(mc)


func _draw_heart(center: Vector2) -> void:
	var c := Color(0.88, 0.15, 0.28)
	var s: float = size.y * 0.16
	draw_circle(center + Vector2(-s * 0.55, -s * 0.4), s * 0.65, c)
	draw_circle(center + Vector2(s * 0.55, -s * 0.4), s * 0.65, c)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-s * 1.15, -s * 0.05), center + Vector2(s * 1.15, -s * 0.05), center + Vector2(0, s * 1.25)
	]), c)


func _draw_star(center: Vector2) -> void:
	var c := Color(0.45, 0.55, 0.95)
	var pts := PackedVector2Array()
	var r: float = size.y * 0.22
	for i in range(10):
		var angle: float = i * PI / 5.0 - PI / 2.0
		var rr: float = r if i % 2 == 0 else r * 0.42
		pts.append(center + Vector2(cos(angle), sin(angle)) * rr)
	draw_colored_polygon(pts, c)


func _draw_shield_icon(center: Vector2) -> void:
	var c := Color(0.4, 0.7, 1.0)
	var s: float = size.y * 0.24
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-s, -s * 0.7), center + Vector2(s, -s * 0.7), center + Vector2(s, s * 0.1),
		center + Vector2(0, s * 1.1), center + Vector2(-s, s * 0.1)
	]), c)
