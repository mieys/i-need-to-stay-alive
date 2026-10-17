extends RefCounted

## pixel_draw.gd'nin KARAKTER PİKSELİ yoğunluğundaki eşi: 1 sanat pikseli = TEXEL 0,9 dünya birimi (Şovalye 0,903; pixel_draw.gd
## 1,212 ile ~1,5 kat iridir). Dünyaya konan (sahne kökünün çocuğu) ince efektler için - prototipi karakter pikseliyle çizilen
## efektler (tools/proto_20261014/sovalye_e_emilim_proto.py) oyunda aynı yoğunlukta görünsün. Konumlar bu ızgaraya oturur,
## alfa da prototipteki gibi az seviyeye (q_alpha) yuvarlanır. Tüm fonksiyonlar _draw() içinde, CanvasItem'in YEREL uzayında.
## Kullananlar: fx_sovalye_echo.gd (Şovalye E Yankı Darbesi), fx_shard_stream.gd (Melek E kalkan kırıntıları).

const TEXEL := 0.9


## Pixel dili: 0 / .3 / .55 / .8 / 1.
static func q_alpha(a: float) -> float:
	if a >= 0.88:
		return 1.0
	if a >= 0.68:
		return 0.8
	if a >= 0.43:
		return 0.55
	if a >= 0.18:
		return 0.3
	return 0.0


static func snap(v: Vector2) -> Vector2:
	return (v / TEXEL).round() * TEXEL


## Kare başı yüzlerce kez çağrılır (Şovalye yankı yayı, Melek kırıntı izi): q_alpha/snap/Rect2 çağrıları içe açıldı
## (2026-10-15 FPS: ayrı fonksiyon çağrıları maliyetin çoğuydu).
const _HALF := TEXEL * 0.5
const _SIZE := Vector2(TEXEL, TEXEL)


static func px(ci: CanvasItem, pos: Vector2, col: Color, a: float = 1.0) -> void:
	var qa: float = a * col.a
	if qa < 0.18:
		return
	qa = 1.0 if qa >= 0.88 else (0.8 if qa >= 0.68 else (0.55 if qa >= 0.43 else 0.3))
	ci.draw_rect(Rect2(Vector2(roundf(pos.x / TEXEL) * TEXEL - _HALF, roundf(pos.y / TEXEL) * TEXEL - _HALF), _SIZE), Color(col, qa))


static var _diamond_tex: Dictionary = {} ## [r, kontur mu] -> ImageTexture (beyaz maske; renk/alfa modulate ile)


## Elmas maskesi: kontur=false -> |dx|+|dy| <= r (kenar 2r+1), kontur=true -> |dx|+|dy| == r+1 (kenar 2r+3).
static func _diamond_mask(r: int, outline: bool) -> ImageTexture:
	var key := Vector2i(r, 1 if outline else 0)
	if _diamond_tex.has(key):
		return _diamond_tex[key]
	var n: int = 2 * r + (3 if outline else 1)
	var c: int = n / 2
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for x in range(n):
		for y in range(n):
			var m: int = absi(x - c) + absi(y - c)
			if (m == r + 1) if outline else (m <= r):
				img.set_pixel(x, y, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_diamond_tex[key] = tex
	return tex


## r sanat pikseli yarıçaplı elmas (|dx|+|dy| <= r); out verilirse 1 piksel koyu kontur. Önceden piksel piksel çiziliyordu
## (elmas başına ~30 draw_rect, Melek kırıntı efekti 7 elmas x kare): artık önbellekli maske dokusu, elmas başına 1-2 çizim.
## Dokuyu piksel net çizmek için çağıran düğümde texture_filter = NEAREST olmalı.
## sc: sanat pikseli çarpanı (c çağıranın hazırladığı konumdur, ızgaraya oturtma çağırana ait).
static func diamond(ci: CanvasItem, c: Vector2, r: int, col: Color, a: float = 1.0, out: Color = Color(0, 0, 0, 0), sc: float = 1.0) -> void:
	var o: Vector2 = snap(c) if sc == 1.0 else c
	if out.a > 0.0:
		var qo: float = q_alpha(a * 0.85 * out.a)
		if qo > 0.0:
			var side: float = float(2 * r + 3) * TEXEL * sc
			ci.draw_texture_rect(_diamond_mask(r, true), Rect2(o - Vector2(side, side) * 0.5, Vector2(side, side)), false, Color(out, qo))
	var qf: float = q_alpha(a * col.a)
	if qf > 0.0:
		var side2: float = float(2 * r + 1) * TEXEL * sc
		ci.draw_texture_rect(_diamond_mask(r, false), Rect2(o - Vector2(side2, side2) * 0.5, Vector2(side2, side2)), false, Color(col, qf))


static var _ring_tex: Dictionary = {} ## yarıçap (0,5 sanat pikseli adımı) -> ImageTexture (beyaz maske)


## Tam halka maskesi: piksel = (round(r cos a), round(r sin a)); eskiden her açı örneği ayrı draw_rect'ti (halka başına 20-100).
static func _ring_mask(r2: int) -> ImageTexture:
	if _ring_tex.has(r2):
		return _ring_tex[r2]
	var r: float = float(r2) * 0.5
	var c: int = int(ceilf(r))
	var n: int = 2 * c + 1
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var steps: int = maxi(32, int(TAU * maxf(r, 1.0) * 3.0))
	for i in range(steps):
		var ang: float = TAU * float(i) / float(steps)
		img.set_pixel(c + int(roundf(cos(ang) * r)), c + int(roundf(sin(ang) * r)), Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_ring_tex[r2] = tex
	return tex


## Yarıçapı r sanat pikseli olan halka (isteğe bağlı yay: from_angle'dan sweep kadar). Tam halka önbellekli dokuyla TEK çizimdir
## (çağıran düğümde texture_filter = NEAREST olmalı); yay hâlâ piksel piksel. sc: sanat pikseli çarpanı (tam halka için).
static func ring(ci: CanvasItem, c: Vector2, r: float, col: Color, a: float = 1.0, from_angle: float = 0.0, sweep: float = TAU, sc: float = 1.0) -> void:
	if from_angle == 0.0 and sweep >= TAU - 0.001:
		var qa: float = q_alpha(a * col.a)
		if qa <= 0.0:
			return
		var r2: int = int(roundf(maxf(r, 0.0) * 2.0))
		var half_n: float = float(int(ceilf(float(r2) * 0.5))) + 0.5
		var side: float = half_n * 2.0 * TEXEL * sc
		var o: Vector2 = snap(c) if sc == 1.0 else c
		ci.draw_texture_rect(_ring_mask(r2), Rect2(o - Vector2(side, side) * 0.5, Vector2(side, side)), false, Color(col, qa))
		return
	var n: int = maxi(16, int(sweep * maxf(r, 1.0) * 1.5))
	for i in range(n + 1):
		var ang: float = from_angle + sweep * float(i) / float(n)
		px(ci, c + Vector2(cos(ang), sin(ang)) * r * TEXEL, col, a)


## Artı işareti: ortası core, kolları arm (arm_len sanat pikseli; 2. halka daha soluk).
static func plus(ci: CanvasItem, c: Vector2, core: Color, arm: Color, a: float = 1.0, arm_len: int = 1) -> void:
	for k in range(1, arm_len + 1):
		var ka: float = a * (1.0 if k == 1 else 0.55)
		for d in [Vector2(k, 0), Vector2(-k, 0), Vector2(0, k), Vector2(0, -k)]:
			px(ci, c + d * TEXEL, arm, ka)
	px(ci, c, core, a)


static func ramp(cols: Array, t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	var n: int = cols.size() - 1
	var i: int = mini(n - 1, int(t * n))
	return (cols[i] as Color).lerp(cols[i + 1] as Color, t * n - i)


static func bez2(p0: Vector2, p1: Vector2, p2: Vector2, u: float) -> Vector2:
	var v: float = 1.0 - u
	return p0 * v * v + p1 * 2.0 * v * u + p2 * u * u


static func bez3(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, u: float) -> Vector2:
	var v: float = 1.0 - u
	return p0 * v * v * v + p1 * 3.0 * v * v * u + p2 * 3.0 * v * u * u + p3 * u * u * u
