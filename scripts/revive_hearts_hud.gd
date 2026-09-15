extends Control
class_name ReviveHeartsHUD

## Mini heart-shaped Revive display on the left edge.
## Shows 3 retro pixel-art hearts, lighting up red when available, gray when consumed.

const MAX_REVIVES := 3
var revives_remaining: int = 3

func _ready() -> void:
	custom_minimum_size = Vector2(90, 32)
	size = Vector2(90, 32)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_revives(count: int) -> void:
	revives_remaining = clamp(count, 0, MAX_REVIVES)
	queue_redraw()

func _draw() -> void:
	var start_x: float = 4.0
	var spacing: float = 26.0
	var heart_size: float = 20.0
	
	for i in range(MAX_REVIVES):
		var active: bool = i < revives_remaining
		var pos := Vector2(start_x + i * spacing, 6.0)
		_draw_pixel_heart(pos, active)

func _draw_pixel_heart(pos: Vector2, active: bool) -> void:
	# 7x7 pixel grid scaled by 2.6
	var scale_factor: float = 2.6
	var rows: Array[String] = [
		".XX.XX.",
		"XXXXXXX",
		"XXXXXXX",
		".XXXXX.",
		"..XXX..",
		"...X..."
	]
	
	var fill_color: Color = Color(0.95, 0.22, 0.28, 1.0) if active else Color(0.28, 0.28, 0.32, 0.7)
	var shine_color: Color = Color(1.0, 0.75, 0.8, 1.0) if active else Color(0.45, 0.45, 0.5, 0.8)
	var border_color: Color = Color(0.08, 0.04, 0.05, 0.95)
	
	# Draw drop shadow
	for y in range(rows.size()):
		var line: String = rows[y]
		for x in range(line.length()):
			if line[x] == 'X':
				draw_rect(Rect2(pos.x + x * scale_factor + 1.5, pos.y + y * scale_factor + 1.5, scale_factor, scale_factor), Color(0, 0, 0, 0.4))
				
	# Draw border / fill
	for y in range(rows.size()):
		var line: String = rows[y]
		for x in range(line.length()):
			if line[x] == 'X':
				var c := fill_color
				# Highlight dot on top left
				if (x == 1 or x == 2) and y == 1:
					c = shine_color
				draw_rect(Rect2(pos.x + x * scale_factor, pos.y + y * scale_factor, scale_factor, scale_factor), c)
