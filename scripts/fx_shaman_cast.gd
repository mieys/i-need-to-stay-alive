extends Node2D

## Shaman totem yeteneklerinin CAST (atma) efekti - PIXEL tarzı, SIFIRDAN (kullanıcı isteği, 2026-09-21: "shamanın skill totemlerinin
## efektlerini, ikonlarını ve seslerini sıfırdan tasarla, pixel tarzda 48x48"). Eskiden 6 karelik sprite sheet'ti; artık 1 texel detaylı
## prosedürel çizim (bkz. hafıza "Pixel density 48x48"). Üç yetenek AYNI script'i kullanır, farkı sahneye gömülü `kind` belirler
## (ağ yayını sadece sahne YOLUNU taşıdığı için yetenek görünümü sahnede olmalı - bkz. CLAUDE.md):
##   shield (Kalkan Totemi, mavi)  : zemin rün çemberi + yükselen mavi ışık sütunu + yukarı süzülen küçük pixel kalkanlar
##   attack (Saldırı Totemi, ateş) : çember çevresinde yukarı fışkıran pixel alev dilleri + kor
##   area   (Alan Totemi, mor)     : dönen girdap çemberi + merkeze çekilen boşluk parçacıkları + genişleyen şok halkası
## Player/RemotePlayer'ın ÇOCUĞU olarak doğar (ayak seviyesi y≈26), ömrü sabittir (DURATION).

const PixelDraw := preload("res://scripts/pixel_draw.gd")

@export var kind: String = "shield"

const DURATION := 1.0
const FADE_START := 0.65
const GROUND := Vector2(0, 26)

const SHIELD_ART := [
	"kkkkkk",
	"kbbbbk",
	"kbwwbk",
	"kbbbbk",
	".kbbk.",
	"..kk..",
]

var _t: float = 0.0
var _main: Color = Color(0.35, 0.65, 1.0)
var _light: Color = Color(0.78, 0.93, 1.0)
var _dark: Color = Color(0.14, 0.3, 0.68)


func _ready() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	match kind:
		"attack":
			_main = Color(1.0, 0.55, 0.2)
			_light = Color(1.0, 0.92, 0.55)
			_dark = Color(0.68, 0.16, 0.08)
		"area":
			_main = Color(0.65, 0.35, 0.9)
			_light = Color(0.93, 0.78, 1.0)
			_dark = Color(0.28, 0.1, 0.5)


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _fade() -> float:
	return clampf((DURATION - _t) / (DURATION - FADE_START), 0.0, 1.0) if _t > FADE_START else 1.0


func _ellipse_ring(rx: float, ry: float, col: Color, dash_on: int, dash_off: int, phase: float) -> void:
	var texel: float = PixelDraw.TEXEL
	var count: int = maxi(24, int(TAU * maxf(rx, ry) / texel))
	var period: int = dash_on + dash_off
	for i in range(count):
		if period > 0 and (int(float(i) + phase) % period) >= dash_on:
			continue
		var a: float = TAU * float(i) / float(count)
		PixelDraw.px(self, GROUND + Vector2(cos(a) * rx, sin(a) * ry), 1, col)


## Çemberin üstündeki kısa yay işaretleri (rün): yetenek türüne göre biçim.
func _glyph(pos: Vector2, col: Color, a: float) -> void:
	var t: float = PixelDraw.TEXEL
	match kind:
		"attack": ## küçük üçgen alev
			PixelDraw.px(self, pos, 1, col)
			PixelDraw.px(self, pos + Vector2(0, -t), 1, col)
			PixelDraw.px(self, pos + Vector2(-t, 0), 1, col)
			PixelDraw.px(self, pos + Vector2(t, 0), 1, col)
			PixelDraw.px(self, pos + Vector2(0, -t * 2.0), 1, _light)
		"area": ## sarmal nokta çifti
			PixelDraw.px(self, pos + Vector2(cos(a), sin(a)) * t, 1, col)
			PixelDraw.px(self, pos - Vector2(cos(a), sin(a)) * t, 1, col)
			PixelDraw.px(self, pos, 1, _light)
		_: ## kalkan: küçük artı
			PixelDraw.px(self, pos, 1, _light)
			PixelDraw.px(self, pos + Vector2(t, 0), 1, col)
			PixelDraw.px(self, pos - Vector2(t, 0), 1, col)
			PixelDraw.px(self, pos + Vector2(0, t), 1, col)
			PixelDraw.px(self, pos - Vector2(0, t), 1, col)


func _draw() -> void:
	var fade: float = _fade()
	var grow: float = clampf(_t / 0.25, 0.0, 1.0)
	grow = grow * grow * (3.0 - 2.0 * grow)
	var texel: float = PixelDraw.TEXEL
	## --- Zemin rün çemberi (perspektifli elips) ---
	var rx: float = 46.0 * grow
	var ry: float = 20.0 * grow
	_ellipse_ring(rx, ry, Color(_main.r, _main.g, _main.b, 0.95 * fade), 5, 1, _t * 10.0)
	_ellipse_ring(rx - 3.0, ry - 1.4, Color(_dark.r, _dark.g, _dark.b, 0.75 * fade), 3, 2, -_t * 8.0)
	_ellipse_ring(rx * 0.55, ry * 0.55, Color(_light.r, _light.g, _light.b, 0.6 * fade), 2, 3, _t * 14.0)
	for k in range(8):
		var a: float = float(k) * TAU / 8.0 + _t * 0.7
		_glyph(GROUND + Vector2(cos(a) * rx * 0.8, sin(a) * ry * 0.8), Color(_main.r, _main.g, _main.b, fade), a)
	## Başlangıç parlaması
	if _t < 0.12:
		PixelDraw.disc_dither(self, GROUND + Vector2(0, -6), 26.0, Color(_light.r, _light.g, _light.b, 0.7), int(_t * 60.0), 1)
	match kind:
		"attack":
			_draw_attack(fade, grow, texel)
		"area":
			_draw_area(fade, grow, texel)
		_:
			_draw_shield(fade, grow, texel)


func _draw_shield(fade: float, grow: float, texel: float) -> void:
	## Yükselen mavi ışık sütunu (dither)
	var col_h: float = 92.0 * clampf(_t / 0.35, 0.0, 1.0)
	var rows: int = int(col_h / texel)
	var flick: int = int(_t * 24.0)
	for iy in range(rows):
		var y: float = GROUND.y - float(iy) * texel
		var hw: int = maxi(1, int(round(7.0 * (1.0 - float(iy) / maxf(float(rows), 1.0) * 0.6))))
		for ix in range(-hw, hw + 1):
			if ((ix + iy + flick) & 1) == 0:
				continue
			PixelDraw.px(self, Vector2(float(ix) * texel, y), 1, Color(_main.r, _main.g, _main.b, 0.42 * fade))
	## Yukarı süzülen küçük pixel kalkanlar
	var pal := {"k": Color(_dark.r, _dark.g, _dark.b, fade), "b": Color(_main.r, _main.g, _main.b, fade), "w": Color(_light.r, _light.g, _light.b, fade)}
	for i in range(6):
		var ph: float = clampf((_t - 0.05 * float(i)) / 0.75, 0.0, 1.0)
		if ph <= 0.0:
			continue
		var a: float = float(i) * TAU / 6.0 + ph * 2.0
		var pos: Vector2 = GROUND + Vector2(cos(a) * 26.0 * (1.0 - ph * 0.5), sin(a) * 11.0 * (1.0 - ph * 0.5) - ph * 62.0)
		PixelDraw.art(self, pos, SHIELD_ART, pal, 1.0)


func _draw_attack(fade: float, grow: float, texel: float) -> void:
	## Çember çevresinde yukarı fışkıran alev dilleri (pixel sütunlar, sivri uçlu)
	for i in range(9):
		var a: float = float(i) * TAU / 9.0 + 0.3
		var base: Vector2 = GROUND + Vector2(cos(a) * 40.0, sin(a) * 17.5) * grow
		var burst: float = clampf((_t - 0.04 * float(i % 4)) / 0.5, 0.0, 1.0)
		var h: float = (14.0 + 16.0 * absf(sin(a * 1.7))) * sin(burst * PI) * fade
		var rows: int = int(h / texel)
		for r in range(rows):
			var k: float = float(r) / maxf(float(rows), 1.0)
			var wob: float = sin(_t * 18.0 + float(i) * 2.0 + float(r) * 0.6) * texel * (0.5 + k)
			var w: int = 2 if k < 0.45 else 1
			PixelDraw.px(self, base + Vector2(wob, -float(r) * texel), w, PixelDraw.fire_color(0.05 + k * 0.85))
	## Kor
	for i in range(14):
		var ph: float = fmod(_t * 1.6 + float(i) * 0.137, 1.0)
		var a2: float = float(i) * 2.4
		var p: Vector2 = GROUND + Vector2(cos(a2) * 30.0, sin(a2) * 13.0) + Vector2(sin(ph * 6.0 + float(i)) * 4.0, -ph * 48.0)
		PixelDraw.px(self, p, 1, Color(PixelDraw.fire_color(0.1 + ph * 0.6), (1.0 - ph) * fade))


func _draw_area(fade: float, grow: float, texel: float) -> void:
	## Dönen girdap kolları (zemin perspektifinde sarmal)
	for arm in range(3):
		var a0: float = _t * 2.2 + float(arm) * TAU / 3.0
		for i in range(30):
			var f: float = float(i) / 29.0
			var r: float = lerpf(4.0, 40.0, f) * grow
			var a: float = a0 + f * 2.6
			var p: Vector2 = GROUND + Vector2(cos(a) * r, sin(a) * r * 0.44)
			PixelDraw.px(self, p, 1, Color(_main.r, _main.g, _main.b, (0.35 + 0.6 * (1.0 - f)) * fade))
	## Merkeze çekilen boşluk parçacıkları
	for i in range(14):
		var ph: float = clampf((_t - 0.02 * float(i)) / 0.7, 0.0, 1.0)
		if ph <= 0.0:
			continue
		var a: float = float(i) * 2.399 + ph * 3.0
		var r: float = 60.0 * (1.0 - ph)
		var p: Vector2 = GROUND + Vector2(cos(a) * r, sin(a) * r * 0.44 - ph * 16.0)
		PixelDraw.px(self, p, 1 if ph < 0.6 else 2, Color(_light.r, _light.g, _light.b, (1.0 - ph * 0.5) * fade))
	## Genişleyen şok halkası
	var sk: float = clampf((_t - 0.1) / 0.55, 0.0, 1.0)
	if sk > 0.0 and sk < 1.0:
		_ellipse_ring(10.0 + 100.0 * sk, 4.4 + 44.0 * sk, Color(_main.r, _main.g, _main.b, (1.0 - sk) * 0.85), 6, 2, 0.0)
