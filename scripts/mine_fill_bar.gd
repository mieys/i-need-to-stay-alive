extends Control

var progress: float = 0.0


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.22, 0.15, 0.08), true)
	draw_rect(Rect2(2, 2, w - 4, h - 4), Color(0.1, 0.07, 0.04), true)
	var fw: float = (w - 4) * progress
	if fw > 0:
		draw_rect(Rect2(2, 2, fw, h - 4), Color(1.0, 0.83, 0.25), true)
		draw_rect(Rect2(2, 2, fw, (h - 4) * 0.4), Color(1.0, 0.95, 0.6), true)
