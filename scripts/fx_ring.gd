extends Node2D

var color: Color = Color.WHITE
var radius: float = 6.0
var max_radius: float = 55.0
var life: float = 0.5
var t: float = 0.0


func _process(delta: float) -> void:
	t += delta
	var p: float = t / life
	if p >= 1.0:
		queue_free()
		return
	radius = lerp(6.0, max_radius, p)
	modulate.a = 1.0 - p
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, color, 4.0, true)
