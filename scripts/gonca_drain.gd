extends Node2D

## KAN BAĞI GÖRSELİ (madde 682; dünya efekti "gonca_drain", gonca_filiz.gd on_owner_died): öldürülen Filiz'den Zehirli Gonca'ya 3 pembe yaprak süzülür -
## "bu yavruyu kesmek bossu yaraladı" geri bildirimi. Hasarsız; kesinti host'ta drain_boss ile anında işlenir. data.to: bossun gövde noktası.

const C_OUT := Color(0.22, 0.09, 0.20)
const C_MID := Color(0.84, 0.44, 0.72)
const C_LIGHT := Color(0.98, 0.78, 0.92)
const TIME := 0.5
const PETALS := 3

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _t: float = 0.0


func _ready() -> void:
	z_index = 7
	_from = global_position
	_to = Vector2(data.get("to", global_position))
	if source != null and is_instance_valid(source):
		_to = source.global_position + Vector2(0.0, -30.0)
	global_position = Vector2.ZERO
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= TIME + 0.12 * float(PETALS - 1):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var lift := Vector2(0.0, -40.0)
	for i in PETALS:
		var k: float = clampf((_t - 0.12 * float(i)) / TIME, 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			continue
		var s: float = 1.0 - pow(1.0 - k, 2.0)
		## yukarı kavisli yol (ikinci derece Bezier)
		var mid: Vector2 = (_from + _to) * 0.5 + lift
		var p: Vector2 = _from.lerp(mid, s).lerp(mid.lerp(_to, s), s)
		var ang: float = _t * 9.0 + float(i) * 2.1
		var d := Vector2(cos(ang), sin(ang)) * 5.0
		var n := Vector2(-d.y, d.x) * 0.5
		var size: float = 1.0 - 0.4 * k
		var poly := PackedVector2Array([p - d * size, p + n * size, p + d * size, p - n * size])
		draw_colored_polygon(poly, C_OUT)
		var inner := PackedVector2Array([p - d * size * 0.7, p + n * size * 0.6, p + d * size * 0.7, p - n * size * 0.6])
		draw_colored_polygon(inner, C_MID if i % 2 == 0 else C_LIGHT)
