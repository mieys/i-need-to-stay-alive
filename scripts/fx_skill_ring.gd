extends Node2D
class_name SkillRingFx

## Uzaktaki oyuncu kuklalarında (RemotePlayer) yetenek anında genişleyip
## sönen bir halka çizer - fx_skill_burst.gd ile aynı nedenle (bkz. o
## dosyadaki yorum) eskiden hiç var olmayan bir sahneydi ve host'un
## çökmesine yol açıyordu.

var _radius: float = 80.0
var _color: Color = Color.WHITE
var _elapsed: float = 0.0
const DURATION := 0.6

func setup(radius: float, color: Color) -> void:
	_radius = radius
	_color = color
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = clamp(_elapsed / DURATION, 0.0, 1.0)
	var r: float = _radius * (0.3 + t * 0.7)
	var c: Color = _color
	c.a = (1.0 - t) * _color.a if _color.a > 0.0 else (1.0 - t)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c, 3.0, true)
