extends Node2D

var color: Color = Color(1.0, 0.9, 0.2, 0.8) # Yellow spark color
var length: float = 12.0
var width: float = 2.0
var direction: Vector2 = Vector2.LEFT
var lifetime: float = 0.22
var elapsed: float = 0.0


func setup(dir: Vector2, col: Color = Color(1.0, 0.9, 0.2, 0.8)) -> void:
	direction = dir.normalized()
	color = col
	length = randf_range(8.0, 18.0)
	width = randf_range(1.5, 3.0)


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha: float = 1.0 - (elapsed / lifetime)
	var draw_col := color
	draw_col.a *= alpha
	var start := Vector2.ZERO
	var end := -direction * length
	draw_line(start, end, draw_col, width)
