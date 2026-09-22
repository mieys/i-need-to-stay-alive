extends Node2D

## Shaman totemlerinin tek seferlik pixel efektleri - SIFIRDAN (eski hali sprite sheet'ti, eski fx_totem_burst.gd silindi).
## Üç tür, sahneye gömülü `kind` ile (ağ kopyaları aynı sahneyi kurduğu için görünüm her istemcide aynı):
##   plant    : totem dikilirken tabanından fışkırıp geri düşen toprak parçaları + genişleyen toz halkası
##   collapse : süre dolunca çöken taş parçaları + yayılan toz bulutu
##   rune     : yetenek renginde rün parlaması (setup_tint ile totem rengi): genişleyen halka + dönen 6 rün + kıvılcım
## Hepsi 1 texel detay (bkz. hafıza "Pixel density 48x48"), kendini bitince siler.

const PixelDraw := preload("res://scripts/pixel_draw.gd")

@export var kind: String = "plant"

const SOIL := [Color(0.24, 0.16, 0.1), Color(0.4, 0.28, 0.17), Color(0.55, 0.4, 0.25)]
const STONE := [Color(0.24, 0.22, 0.28), Color(0.4, 0.38, 0.46), Color(0.58, 0.56, 0.66)]
const DUST := Color(0.72, 0.64, 0.52)

var tint: Color = Color(0.6, 0.8, 1.0)
var _t: float = 0.0
var _life: float = 0.7
var _chunks: Array = [] ## [pos, vel, size, color_idx, spin]


func setup_tint(c: Color) -> void:
	tint = c


func _ready() -> void:
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	match kind:
		"plant":
			_life = 0.65
			for i in range(12):
				var a: float = randf_range(-PI * 0.95, -PI * 0.05)
				_chunks.append([Vector2(randf_range(-6.0, 6.0), 2.0), Vector2(cos(a), sin(a)) * randf_range(40.0, 95.0), randi_range(1, 2), randi() % 3, 0.0])
		"collapse":
			_life = 0.9
			for i in range(16):
				_chunks.append([Vector2(randf_range(-14.0, 14.0), randf_range(-38.0, -4.0)), Vector2(randf_range(-30.0, 30.0), randf_range(-20.0, 10.0)), randi_range(1, 3), randi() % 3, 0.0])
		_:
			_life = 0.75


func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
	for c in _chunks:
		c[0] = (c[0] as Vector2) + (c[1] as Vector2) * delta
		c[1] = (c[1] as Vector2) + Vector2(0, 260.0 if kind == "plant" else 150.0) * delta
		## Zemine (y = 4) çarpınca durur / kayar
		if (c[0] as Vector2).y > 4.0:
			c[0] = Vector2((c[0] as Vector2).x, 4.0)
			c[1] = Vector2((c[1] as Vector2).x * 0.4, 0.0)
	queue_redraw()


func _draw() -> void:
	var k: float = _t / _life
	var fade: float = 1.0 - k
	match kind:
		"plant", "collapse":
			var pal: Array = SOIL if kind == "plant" else STONE
			## Toz halkası (yere paralel elips)
			var rx: float = 6.0 + (34.0 if kind == "plant" else 46.0) * k
			var ry: float = rx * 0.4
			var count: int = int(TAU * rx / (PixelDraw.TEXEL * 1.8))
			for i in range(count):
				var a: float = TAU * float(i) / float(maxi(count, 1))
				if (i + int(_t * 20.0)) % 3 == 0:
					continue
				PixelDraw.px(self, Vector2(cos(a) * rx, 3.0 + sin(a) * ry), 1, Color(DUST.r, DUST.g, DUST.b, 0.6 * fade))
			for c in _chunks:
				var col: Color = pal[int(c[3])]
				PixelDraw.px(self, c[0], int(c[2]), Color(col.r, col.g, col.b, minf(1.0, fade * 2.2)))
			## Collapse: yükselen toz bulutu (dither)
			if kind == "collapse":
				PixelDraw.disc_dither(self, Vector2(0, -14.0 - 12.0 * k), 12.0 + 22.0 * k, Color(DUST.r, DUST.g, DUST.b, 0.28 * fade), int(_t * 14.0), 1)
		_:
			var c_main := Color(tint.r, tint.g, tint.b, 1.0)
			var c_light := c_main.lerp(Color(1, 1, 1, 1), 0.6)
			var r: float = 6.0 + 46.0 * k
			PixelDraw.ring(self, Vector2.ZERO, r, Color(c_main.r, c_main.g, c_main.b, 0.95 * fade), 1)
			PixelDraw.ring(self, Vector2.ZERO, r * 0.62, Color(c_light.r, c_light.g, c_light.b, 0.6 * fade), 1, 3, 3, _t * 22.0)
			if _t < 0.1:
				PixelDraw.disc_dither(self, Vector2.ZERO, 18.0, Color(c_light.r, c_light.g, c_light.b, 0.8), int(_t * 60.0), 1)
			for i in range(6):
				var a2: float = _t * 2.4 + float(i) * TAU / 6.0
				var p: Vector2 = Vector2(cos(a2), sin(a2)) * r * 0.85
				PixelDraw.px(self, p, 1, c_light)
				PixelDraw.px(self, p + Vector2(PixelDraw.TEXEL, 0), 1, Color(c_main.r, c_main.g, c_main.b, fade))
				PixelDraw.px(self, p - Vector2(PixelDraw.TEXEL, 0), 1, Color(c_main.r, c_main.g, c_main.b, fade))
				PixelDraw.px(self, p + Vector2(0, PixelDraw.TEXEL), 1, Color(c_main.r, c_main.g, c_main.b, fade))
				PixelDraw.px(self, p - Vector2(0, PixelDraw.TEXEL), 1, Color(c_main.r, c_main.g, c_main.b, fade))
			for i in range(8):
				var ph: float = fmod(_t * 1.8 + float(i) * 0.19, 1.0)
				var a3: float = float(i) * 2.399
				PixelDraw.px(self, Vector2(cos(a3), sin(a3)) * r * 0.5 + Vector2(0, -ph * 20.0), 1, Color(c_light.r, c_light.g, c_light.b, (1.0 - ph) * fade))
