extends Node2D

## Ruhani Yetenek "Adc" (F): 10sn boyunca (saldırı hızı/kalkan delme/can emme) karakteri saran KIZIL-TURUNCU pixel güç aurası
## (1 texel detay, bkz. hafıza "Pixel density 48x48"):
##  - açılış: ince kızıl şok halkası + dışa saçılan 10 ışın
##  - süre boyunca: yerde titreşen dither elips, gövdenin çevresinde hızla dönen 3 küçük elmas (mermi/ok),
##    yukarı yükselen ince kıvılcımlar
## Player/RemotePlayer'ın ÇOCUĞU, sabit ömürlü (DURATION = spiritual_skills.gd ADC_DURATION).

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")

const BODY_CENTER := Vector2(0, -4)
const FADE_OUT := 0.5

var _t: float = 0.0
var _duration: float = SpiritualSkillsScript.ADC_DURATION
var _sparks: Array = [] ## [pos, vel, age, life]
var _acc: float = 0.0


func _ready() -> void:
	show_behind_parent = true ## alevler karakterin ARKASINDA (siblings sonra çizilir)
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	if _t >= _duration + FADE_OUT:
		queue_free()
		return
	if _t < _duration:
		_acc += delta
		while _acc > 0.04:
			_acc -= 0.04
			_sparks.append([BODY_CENTER + Vector2(randf_range(-18.0, 18.0), randf_range(8.0, 28.0)), Vector2(randf_range(-8.0, 8.0), randf_range(-64.0, -30.0)), 0.0, randf_range(0.5, 0.85)])
	for s in _sparks:
		s[2] += delta
		s[0] += s[1] * delta
	_sparks = _sparks.filter(func(s): return float(s[2]) < float(s[3]))
	queue_redraw()


func _draw() -> void:
	var fade: float = clampf((_duration + FADE_OUT - _t) / FADE_OUT, 0.0, 1.0)
	var open: float = clampf(_t / 0.2, 0.0, 1.0) * fade
	var texel: float = PixelDraw.TEXEL
	## Açılış patlaması
	if _t < 0.6:
		var pk: float = _t / 0.6
		PixelDraw.ring(self, BODY_CENTER, 8.0 + pk * 92.0, Color(1.0, 0.35 + 0.4 * pk, 0.12, 1.0 - pk), 1)
		for k in range(10):
			var a: float = float(k) * TAU / 10.0 + 0.1
			var r0: float = 18.0 + pk * 42.0
			PixelDraw.line(self, BODY_CENTER + Vector2(cos(a), sin(a)) * r0, BODY_CENTER + Vector2(cos(a), sin(a)) * (r0 + 18.0 * (1.0 - pk)), Color(1.0, 0.6, 0.2, 1.0 - pk), 1)
	if open <= 0.0:
		return
	## Zemin dither elips (titreşen kızıl-turuncu, 1 texel dama)
	var flick: int = int(_t * 14.0)
	var ground := Vector2(0, 26)
	for iy in range(-6, 7):
		var hw: int = int(round(sqrt(maxf(0.0, 1.0 - pow(float(iy) / 6.5, 2.0))) * 26.0))
		for ix in range(-hw, hw + 1):
			if ((ix + iy + flick) & 1) == 0:
				continue
			PixelDraw.px(self, ground + Vector2(float(ix), float(iy)) * texel, 1, Color(1.0, 0.36, 0.12, 0.5 * open))
	## Karakterin arkasında yalayan kızıl-turuncu güç alevleri (ince, 1 texel genişlik, sivri uçlu)
	for i in range(9):
		var u: float = (float(i) / 8.0) * 2.0 - 1.0
		var x0: float = u * 20.0
		var h: float = (16.0 + 22.0 * (1.0 - absf(u)) + 5.0 * sin(_t * 11.0 + float(i) * 1.9)) * open
		var rows: int = int(h / texel)
		for r in range(rows):
			var k: float = float(r) / maxf(float(rows), 1.0)
			var sway: float = sin(_t * 9.0 + float(i) + float(r) * 0.3) * k * texel * 2.0
			PixelDraw.px(self, Vector2(x0 + sway - u * k * 6.0, 26.0 - float(r) * texel), 1, PixelDraw.fire_color(0.15 + k * 0.7))
	## Dönen 3 küçük elmas (merkez + 4 komşu = 5 texel)
	for k in range(3):
		var a2: float = _t * 5.0 + float(k) * TAU / 3.0
		var p: Vector2 = BODY_CENTER + Vector2(cos(a2) * 26.0, sin(a2) * 18.0 - 2.0)
		var front: bool = sin(a2) > 0.0
		var col: Color = Color(1.0, 0.85, 0.35, open) if front else Color(1.0, 0.45, 0.15, 0.65 * open)
		PixelDraw.px(self, p, 2, col)
		PixelDraw.px(self, p + Vector2(texel * 2.0, 0), 1, col)
		PixelDraw.px(self, p - Vector2(texel * 2.0, 0), 1, col)
		PixelDraw.px(self, p + Vector2(0, texel * 2.0), 1, col)
		PixelDraw.px(self, p - Vector2(0, texel * 2.0), 1, col)
	## Yükselen ince kıvılcımlar
	for s in _sparks:
		var k2: float = float(s[2]) / float(s[3])
		PixelDraw.px(self, s[0], 1, Color(1.0, 0.75 - 0.5 * k2, 0.2, (1.0 - k2) * open))
