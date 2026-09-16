extends Node2D
class_name AssasinShadowHitFx

var elapsed: float = 0.0
const LIFETIME := 0.22

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= LIFETIME:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress: float = elapsed / LIFETIME
	var alpha: float = 1.0 - progress
	var dark: Color = Color(0.16, 0.03, 0.28, alpha * 0.9)
	var violet: Color = Color(0.72, 0.28, 1.0, alpha)
	var white: Color = Color(0.9, 0.72, 1.0, alpha * 0.85)
	var length: float = 30.0 + progress * 10.0
	var width: float = max(2.0, 7.0 * (1.0 - progress * 0.45))
	# Two crossing shadow-dagger cuts, not the regular weapon slash.
	draw_line(Vector2(-length, -length * 0.35), Vector2(length, length * 0.35), dark, width + 5.0)
	draw_line(Vector2(-length, -length * 0.35), Vector2(length, length * 0.35), violet, width)
	draw_line(Vector2(-length * 0.8, length * 0.45), Vector2(length * 0.8, -length * 0.45), dark, width + 4.0)
	draw_line(Vector2(-length * 0.8, length * 0.45), Vector2(length * 0.8, -length * 0.45), white, max(2.0, width * 0.42))
	# Small shadow shards trailing off the impact.
	for i in range(4):
		var x: float = -length * 0.6 + float(i) * 11.0
		draw_rect(Rect2(Vector2(x, -length * 0.7 + i * 3.0), Vector2(4.0, 4.0)), violet)
