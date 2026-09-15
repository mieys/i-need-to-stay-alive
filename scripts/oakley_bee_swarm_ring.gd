extends Node2D

## oakley_bee_swarm.gd'nin alan göstergesi - gerçek bir "arı" sanat eseri
## yok, sarı-siyah (arı teması) prosedürel bir dolgu+halka çiziyor.

var _radius: float = 130.0
var _t: float = 0.0


func setup(radius: float) -> void:
	_radius = radius


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, Color(1.0, 0.85, 0.2, 0.10))
	draw_arc(Vector2.ZERO, _radius, 0, TAU, 48, Color(1.0, 0.85, 0.2, 0.5), 3.0, true)
	## Hafifçe dönen küçük "arı" noktaları - salt görsel geri bildirim.
	const DOT_COUNT := 8
	for i in range(DOT_COUNT):
		var a: float = TAU * float(i) / float(DOT_COUNT) + _t * 1.5
		var r: float = _radius * (0.4 + 0.5 * fmod(float(i) / float(DOT_COUNT) + _t * 0.1, 1.0))
		draw_circle(Vector2.RIGHT.rotated(a) * r, 3.0, Color(0.15, 0.1, 0.02, 0.85))
