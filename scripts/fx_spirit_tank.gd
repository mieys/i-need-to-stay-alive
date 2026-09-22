extends Node2D

## Ruhani Yetenek "Tank" (F): 10sn boyunca gövdeyi saran yarı saydam ÇELİK-MAVİ + ALTIN pixel bariyer (altıgen kalkan aurası).
## (1 texel detay, bkz. hafıza "Pixel density 48x48"):
##  - açılış: metalik beyaz-mavi şok halkası + içe toplanan 6 çizgi
##  - süre boyunca: yavaş dönen ince altıgen çerçeve + köşelerinde altın perçinler + üstünden geçen parlak şerit + ince dither dolgu
##  - pulse(): hasar yansıtıldığında (player.gd _spirit_tank_on_hit) çerçeve kısa süre parlar
## Player/RemotePlayer'ın ÇOCUĞU, sabit ömürlü (DURATION = spiritual_skills.gd TANK_DURATION).

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")

const BODY_CENTER := Vector2(0, -4)
const FADE_OUT := 0.5
const RADIUS := 36.0

var _t: float = 0.0
var _duration: float = SpiritualSkillsScript.TANK_DURATION
var _pulse: float = 0.0


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Hasar yansıyınca çağrılır: çerçeve ~0.25sn parlar.
func pulse() -> void:
	_pulse = 0.25


func _process(delta: float) -> void:
	_t += delta
	_pulse = maxf(0.0, _pulse - delta)
	if _t >= _duration + FADE_OUT:
		queue_free()
		return
	queue_redraw()


func _hex_points(radius: float, rot: float) -> Array:
	var pts: Array = []
	for k in range(6):
		var a: float = rot + float(k) * TAU / 6.0
		pts.append(BODY_CENTER + Vector2(cos(a) * radius, sin(a) * radius * 0.92))
	return pts


func _draw() -> void:
	var fade: float = clampf((_duration + FADE_OUT - _t) / FADE_OUT, 0.0, 1.0)
	var open: float = clampf(_t / 0.25, 0.0, 1.0) * fade
	## Açılış: metalik şok halkası + içe toplanan çizgiler
	if _t < 0.55:
		var pk: float = _t / 0.55
		PixelDraw.ring(self, BODY_CENTER, 8.0 + pk * 84.0, Color(0.8, 0.92, 1.0, 1.0 - pk), 1)
		PixelDraw.ring(self, BODY_CENTER, 4.0 + pk * 56.0, Color(1.0, 0.85, 0.4, 0.8 * (1.0 - pk)), 1, 3, 3, _t * 20.0)
		for k in range(6):
			var a: float = float(k) * TAU / 6.0 + 0.3
			var r1: float = 70.0 * (1.0 - pk) + 14.0
			PixelDraw.line(self, BODY_CENTER + Vector2(cos(a), sin(a)) * r1, BODY_CENTER + Vector2(cos(a), sin(a)) * (r1 + 14.0), Color(0.75, 0.9, 1.0, 1.0 - pk), 1)
	if open <= 0.0:
		return
	var bright: float = 1.0 + (_pulse / 0.25) * 0.8
	var rot: float = _t * 0.35
	var outer: Array = _hex_points(RADIUS * open, rot)
	var inner: Array = _hex_points((RADIUS - 3.0) * open, -rot * 0.8)
	## Dither dolgu (ince)
	PixelDraw.disc_dither(self, BODY_CENTER, (RADIUS - 2.0) * open, Color(0.55, 0.78, 1.0, 0.2 * bright), int(_t * 6.0), 1)
	## Altıgen çerçeve (dış: çelik, iç: soluk)
	for i in range(6):
		var a_pt: Vector2 = outer[i]
		var b_pt: Vector2 = outer[(i + 1) % 6]
		var edge_col := Color(0.72, 0.88, 1.0, minf(1.0, 0.95 * open * bright))
		PixelDraw.line(self, a_pt, b_pt, edge_col, 1)
		var inward: Vector2 = (BODY_CENTER - (a_pt + b_pt) * 0.5).normalized() * PixelDraw.TEXEL
		PixelDraw.line(self, a_pt + inward, b_pt + inward, Color(0.45, 0.65, 0.95, 0.75 * open), 1)
		PixelDraw.line(self, inner[i], inner[(i + 1) % 6], Color(0.55, 0.72, 0.95, 0.4 * open), 1)
	## Köşe perçinleri (altın)
	for i in range(6):
		PixelDraw.px(self, outer[i], 3, Color(1.0, 0.86, 0.4, open))
		PixelDraw.px(self, outer[i], 1, Color(1.0, 0.98, 0.8, open))
	## Kenarlardan geçen parlak şerit
	var sweep: float = fmod(_t * 0.9, 1.0) * 6.0
	var edge: int = int(sweep) % 6
	var f: float = sweep - floorf(sweep)
	var s_a: Vector2 = outer[edge]
	var s_b: Vector2 = outer[(edge + 1) % 6]
	var s_p: Vector2 = s_a.lerp(s_b, f)
	PixelDraw.px(self, s_p, 1, Color(1.0, 1.0, 1.0, open))
	PixelDraw.px(self, s_a.lerp(s_b, clampf(f - 0.08, 0.0, 1.0)), 1, Color(0.85, 0.95, 1.0, 0.7 * open))
	PixelDraw.px(self, s_a.lerp(s_b, clampf(f - 0.16, 0.0, 1.0)), 1, Color(0.75, 0.9, 1.0, 0.4 * open))
