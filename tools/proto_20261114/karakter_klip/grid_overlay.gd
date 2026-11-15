extends Node2D

## Keşif çekimi için dünya koordinat ızgarası (karakter_klip_capture.gd KK_MODE=survey): her `step` dünya biriminde çizgi + "x,y" etiketi.
var rect := Rect2()
var step: float = 256.0
var zoom: float = 1.0


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var w: float = 1.5 / zoom
	var fs: int = int(14.0 / zoom)
	var x0: float = floorf(rect.position.x / step) * step
	var y0: float = floorf(rect.position.y / step) * step
	var x: float = x0
	while x <= rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(1, 1, 1, 0.45), w)
		x += step
	var y: float = y0
	while y <= rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(1, 1, 1, 0.45), w)
		y += step
	x = x0
	while x <= rect.end.x:
		y = y0
		while y <= rect.end.y:
			var p := Vector2(x + 4.0 / zoom, y + 16.0 / zoom)
			draw_string_outline(font, p, "%d,%d" % [int(x), int(y)], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(4.0 / zoom), Color.BLACK)
			draw_string(font, p, "%d,%d" % [int(x), int(y)], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 0.6))
			y += step
		x += step
