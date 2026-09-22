extends Node2D

## Ruhani Yetenek "Taktiksel" (F): ışınlandıktan sonraki 3sn'lik +%30 hareket hızı sırasında karakterin ARKASINDA kalan ince
## turkuaz rüzgâr çizgileri + ayaklarda küçük kıvılcımlar (1 texel detay, bkz. hafıza "Pixel density 48x48").
## Hareket yönü: yerel oyuncuda `velocity`, uzak kuklada `_network_velocity` (varsa) - durağanken sadece ayak kıvılcımları.
## Player/RemotePlayer'ın ÇOCUĞU, sabit ömürlü (DURATION = spiritual_skills.gd TAKTIK_SPEED_TIME).

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")

const BODY_CENTER := Vector2(0, -4)
const FADE_OUT := 0.35

var _t: float = 0.0
var _duration: float = SpiritualSkillsScript.TAKTIK_SPEED_TIME
var _host: Node2D = null
var _streaks: Array = [] ## [offset_from_body, length, age, life]
var _acc: float = 0.0


func _ready() -> void:
	z_index = 0
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host = get_parent() as Node2D


func _move_dir() -> Vector2:
	if _host == null or not is_instance_valid(_host):
		return Vector2.ZERO
	var v: Vector2 = Vector2.ZERO
	if "velocity" in _host:
		v = _host.velocity
	elif "_network_velocity" in _host:
		v = _host._network_velocity
	return v.normalized() if v.length() > 20.0 else Vector2.ZERO


func _process(delta: float) -> void:
	_t += delta
	if _t >= _duration + FADE_OUT:
		queue_free()
		return
	var dir: Vector2 = _move_dir()
	if _t < _duration and dir != Vector2.ZERO:
		_acc += delta
		while _acc > 0.03:
			_acc -= 0.03
			var perp := Vector2(-dir.y, dir.x)
			_streaks.append([BODY_CENTER + perp * randf_range(-16.0, 16.0) - dir * randf_range(4.0, 14.0), randf_range(12.0, 28.0), 0.0, randf_range(0.18, 0.32), -dir])
	for s in _streaks:
		s[2] += delta
	_streaks = _streaks.filter(func(s): return float(s[2]) < float(s[3]))
	queue_redraw()


func _draw() -> void:
	var fade: float = clampf((_duration + FADE_OUT - _t) / FADE_OUT, 0.0, 1.0)
	for s in _streaks:
		var k: float = float(s[2]) / float(s[3])
		var back: Vector2 = s[4]
		var head: Vector2 = s[0] + back * (float(s[1]) * k * 0.5)
		var tail: Vector2 = head + back * float(s[1]) * (1.0 - k * 0.4)
		PixelDraw.line(self, head, tail, Color(0.65, 0.95, 1.0, (1.0 - k) * 0.85 * fade), 1)
	## Ayaklarda küçük kıvılcımlar
	var seed_i: int = int(_t * 20.0)
	for i in range(3):
		var x: float = (PixelDraw.hash01(seed_i * 3 + i) - 0.5) * 30.0
		var y: float = 26.0 - PixelDraw.hash01(seed_i * 7 + i + 5) * 6.0
		PixelDraw.px(self, Vector2(x, y), 1, Color(0.8, 1.0, 1.0, 0.7 * fade))
