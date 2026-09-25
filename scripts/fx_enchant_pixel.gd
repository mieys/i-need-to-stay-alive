extends Node2D

## Efsun tek seferlik pixel efektleri (bkz. enchant_fx.gd spawn): hepsi PixelDraw ızgarasında, yumuşak çizgi yok.
##   ring       - genişleyip sönen ince halka (tepkime/bulaşma/ışık alanı)
##   wave       - yere vuran şok dalgası: iki halka + kesik iç halka (Topuz Deprem)
##   slam       - dev darbe: kalın halka + toprak parçaları (Tektonik Darbe)
##   holy       - altın halka + dışa uzanan ışık çizgileri (Kutsal Topuz)
##   spark_ring - sarı kıvılcımlı kesik halka (şok patlaması, kovan)

const PixelDraw := preload("res://scripts/pixel_draw.gd")

var kind: String = "ring"
var radius: float = 80.0
var color: Color = Color.WHITE
var duration: float = 0.45
var _t: float = 0.0
var _seed: int = 0


func _ready() -> void:
	z_index = 8
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_seed = randi()
	if kind == "slam":
		duration = maxf(duration, 0.6)


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = clampf(_t / maxf(0.01, duration), 0.0, 1.0)
	var grow: float = 1.0 - pow(1.0 - k, 3.0) ## ease-out
	var a: float = 1.0 - k
	match kind:
		"ring":
			PixelDraw.ring(self, Vector2.ZERO, radius * (0.35 + 0.65 * grow), Color(color, color.a * a), 2)
			PixelDraw.ring(self, Vector2.ZERO, radius * (0.25 + 0.5 * grow), Color(color, color.a * a * 0.45), 1, 3, 2, _t * 20.0)
		"wave":
			var r: float = radius * (0.2 + 0.8 * grow)
			PixelDraw.ring(self, Vector2.ZERO, r, Color(color, a), 2)
			PixelDraw.ring(self, Vector2.ZERO, r * 0.82, Color(color.darkened(0.25), a * 0.7), 1, 4, 3, _t * 30.0)
			for i in range(10):
				var ang: float = TAU * float(i) / 10.0 + PixelDraw.hash01(_seed + i) * 0.4
				PixelDraw.px(self, Vector2(cos(ang), sin(ang)) * r * 0.95, 2, Color(0.55, 0.45, 0.32, a))
		"slam":
			var rs: float = radius * (0.15 + 0.85 * grow)
			PixelDraw.ring(self, Vector2.ZERO, rs, Color(color, a), 3)
			PixelDraw.ring(self, Vector2.ZERO, rs * 0.7, Color(color.darkened(0.3), a * 0.8), 2, 5, 3, _t * 24.0)
			for i in range(18):
				var ang2: float = TAU * PixelDraw.hash01(_seed + i * 7)
				var d: float = rs * (0.4 + 0.6 * PixelDraw.hash01(_seed + i * 13))
				var lift: float = sin(k * PI) * 10.0 * PixelDraw.hash01(_seed + i)
				PixelDraw.px(self, Vector2(cos(ang2), sin(ang2)) * d - Vector2(0.0, lift), 2, Color(0.5, 0.4, 0.28, a))
		"holy":
			var rh: float = radius * (0.3 + 0.7 * grow)
			PixelDraw.ring(self, Vector2.ZERO, rh, Color(color, a), 2)
			for i in range(12):
				var ang3: float = TAU * float(i) / 12.0
				var dir := Vector2(cos(ang3), sin(ang3))
				PixelDraw.line(self, dir * rh * 0.55, dir * rh * (0.55 + 0.3 * a), Color(1.0, 0.97, 0.75, a * 0.9), 1)
			PixelDraw.px(self, Vector2.ZERO, 3, Color(1.0, 1.0, 0.85, a))
		"spark_ring":
			var rk: float = radius * (0.3 + 0.7 * grow)
			PixelDraw.ring(self, Vector2.ZERO, rk, Color(color, a), 2, 3, 2, _t * 40.0)
			for i in range(8):
				var ang4: float = TAU * PixelDraw.hash01(_seed + i * 3 + int(_t * 20.0))
				PixelDraw.px(self, Vector2(cos(ang4), sin(ang4)) * rk * randf_range(0.5, 1.0), 1, Color(1.0, 1.0, 0.8, a))
