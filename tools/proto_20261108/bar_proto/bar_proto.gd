extends "res://scripts/hud_pixel_bar.gd"

## CAN / KALKAN ÇUBUĞU görünüş prototipleri (2026-11-08, oyuna bağlı DEĞİL). Kullanıcı: "can ve kalkan barının en boylarını ve konumunu
## değiştirmeden görünüşleri için 4 yeni prototip üretir misin pixel art".
## hud_capture.gd BAR_PROTO=<A..D> ile dock çubuklarına bu betiği takar (değerler korunur). Çubuk dikdörtgeni, simge ve değer yazısı AYNI
## (taban betik); yalnız _draw_round_bar ezilir. Hepsi EKRAN PİKSELİNDE (taban gibi: global dönüşüm geri alınır, tam piksel).
##   A Ahşap Oluk     - yuva çerçeveleriyle aynı ahşap çerçeve (HudTrayFrame, 1 px katlar) + dolguda %10 çentikleri
##   B Cam Tüp        - iksir tüpü: üstte cam yansıması, dolgu ucunda açık sıvı yüzeyi, birkaç kabarcık, altta koyu tortu
##   C Bölmeli        - 10 kabartmalı blok, boşlar koyu yuva, kısmi blok kesik
##   D Pirinç Kapaklı - iki uçta perçinli pirinç kapak, arada kanal, 3 bantlı dolgu + kısa parlama çizgisi

const HudTrayFrame := preload("res://scripts/hud_tray_frame.gd")
const P_BRASS_DK := Color("#6a4416")
const P_BRASS := Color("#c0803a")
const P_BRASS_HI := Color("#f0c070")
const P_BRASS_SH := Color("#8a5a24")
const SOCKET := Color("#2c1e12")

var proto_style: String = "A"


func _draw_round_bar(r: Rect2) -> bool:
	var xf: Transform2D = get_global_transform()
	var a: Vector2 = (xf * r.position).round()
	var b: Vector2 = (xf * r.end).round()
	var g := Rect2(a, b - a)
	if g.size.x < 40.0 or g.size.y < 12.0:
		return false
	_bar_px = _snap(g, BAR_PX) ## yazı tabanla aynı yerde
	match proto_style:
		"A": _style_wood(xf, g)
		"B": _style_glass(xf, g)
		"C": _style_segments(xf, g)
		"D":
			_style_brass(xf, g)
			_bar_px = Rect2(g.position, Vector2(g.size.x - 6.0, g.size.y)) ## değer yazısı sağ kapağa binmesin
	return true


## Satır başına köşe girintili dolu yuvarlak dikdörtgen (sanat pikseli p, köşe kalıbı prof) - ekran pikseli koordinatı.
func _round_rows(g: Rect2, p: float, prof: Array, col: Color) -> void:
	var rows: int = int(g.size.y / p)
	for y in rows:
		var k: int = 0
		if y < prof.size():
			k = prof[y]
		elif rows - 1 - y < prof.size():
			k = prof[rows - 1 - y]
		draw_rect(Rect2(g.position.x + k * p, g.position.y + y * p, g.size.x - 2 * k * p, p), col)


func _snap(g: Rect2, p: float) -> Rect2:
	var w: float = floorf(g.size.x / p) * p
	var h: float = floorf(g.size.y / p) * p
	return Rect2(g.position + ((g.size - Vector2(w, h)) * 0.5).floor(), Vector2(w, h))


# ---------------------------------------------------------------------------------------------------------------- A Ahşap Oluk
func _style_wood(xf: Transform2D, g: Rect2) -> void:
	## çerçeve HudTrayFrame kendi dönüşümünü kurar: yerel dikdörtgen ver
	var inv: Transform2D = xf.affine_inverse()
	var local := Rect2(inv * g.position, inv * g.end - inv * g.position)
	var t: float = 1.0
	draw_set_transform_matrix(inv)
	var inner := g.grow(-4.0 * t)
	draw_rect(inner, under)
	var fw: float = floorf(inner.size.x * clampf(ratio, 0.0, 1.0))
	if fw > 0.0:
		var f := Rect2(inner.position, Vector2(fw, inner.size.y))
		draw_rect(f, fill)
		draw_rect(Rect2(f.position, Vector2(fw, 2)), fill.lightened(0.3))
		draw_rect(Rect2(f.position.x, f.end.y - 2, fw, 2), fill.darkened(0.3))
		for i in range(1, 10):
			var x: float = inner.position.x + floorf(inner.size.x * i / 10.0)
			if x < f.end.x - 1.0:
				draw_rect(Rect2(x, f.position.y + 2, 1, f.size.y - 4), fill.darkened(0.22))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	HudTrayFrame.draw(self, local, t)


# ---------------------------------------------------------------------------------------------------------------- B Cam Tüp
func _style_glass(xf: Transform2D, g0: Rect2) -> void:
	var p: float = 2.0
	var g: Rect2 = _snap(g0, p)
	draw_set_transform_matrix(xf.affine_inverse())
	var prof: Array = [3, 1, 1]
	_round_rows(g, p, prof, OUTLINE)
	var inner := Rect2(g.position + Vector2(p, p), g.size - Vector2(2 * p, 2 * p))
	var iprof: Array = [2, 1]
	_round_rows(inner, p, iprof, Color("#1d1611"))
	var rows: int = int(inner.size.y / p)
	var fw: float = floorf(inner.size.x * clampf(ratio, 0.0, 1.0) / p) * p
	if fw > 0.0:
		for y in rows:
			var k: int = 0
			if y < iprof.size():
				k = iprof[y]
			elif rows - 1 - y < iprof.size():
				k = iprof[rows - 1 - y]
			var x0: float = inner.position.x + k * p
			var x1: float = minf(inner.position.x + fw, inner.end.x - k * p)
			if x1 <= x0:
				continue
			var c: Color = fill
			if y >= rows - 2:
				c = fill.darkened(0.28) ## dipte tortu
			elif y == 1:
				c = fill.lightened(0.18)
			draw_rect(Rect2(x0, inner.position.y + y * p, x1 - x0, p), c)
		## sıvı yüzeyi: dolgu ucunda 1 sanat px açık sütun
		var sx: float = inner.position.x + fw - p
		if fw < inner.size.x - p:
			draw_rect(Rect2(sx, inner.position.y + 2 * p, p, inner.size.y - 4 * p), fill.lightened(0.45))
		## kabarcıklar (sabit konum, dolgu içindeyse)
		for bx in [0.18, 0.43, 0.71]:
			var x: float = inner.position.x + floorf(inner.size.x * bx / p) * p
			if x < inner.position.x + fw - 3 * p:
				draw_rect(Rect2(x, inner.position.y + floorf(rows * 0.55) * p, p, p), fill.lightened(0.55))
	## cam yansıması: üst iç satırda uzun çizgi + kısa kesik (yarı saydam krem), her şeyin üstünde
	var ry: float = inner.position.y + p
	var lx: float = inner.position.x + 3 * p
	var long_w: float = floorf(inner.size.x * 0.55 / p) * p
	draw_rect(Rect2(lx, ry, long_w, p * 0.5), Color(1.0, 0.96, 0.85, 0.42))
	draw_rect(Rect2(lx + long_w + 3 * p, ry, 4 * p, p * 0.5), Color(1.0, 0.96, 0.85, 0.32))
	draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------------------------------------------------------- C Bölmeli
func _style_segments(xf: Transform2D, g0: Rect2) -> void:
	var p: float = 2.0
	var g: Rect2 = _snap(g0, p)
	draw_set_transform_matrix(xf.affine_inverse())
	_round_rows(g, p, [2, 1], OUTLINE)
	var inner := Rect2(g.position + Vector2(p, p), g.size - Vector2(2 * p, 2 * p))
	var n: int = 10
	var gap: float = p
	var seg_w: float = floorf((inner.size.x - gap * (n - 1)) / n)
	var extra: float = inner.size.x - (seg_w * n + gap * (n - 1))
	var filled: float = clampf(ratio, 0.0, 1.0) * n
	var x: float = inner.position.x
	for i in n:
		var w: float = seg_w + (1.0 if float(i) < extra else 0.0)
		var cell := Rect2(x, inner.position.y, w, inner.size.y)
		## köşe blokları içe yuvarlak (ilk/son blok)
		draw_rect(cell, SOCKET)
		draw_rect(Rect2(cell.position, Vector2(w, p)), Color(0, 0, 0, 0.25))
		var part: float = clampf(filled - i, 0.0, 1.0)
		if part > 0.0:
			var fw: float = maxf(p, floorf(w * part / p) * p) if part < 1.0 else w
			var f := Rect2(cell.position, Vector2(fw, cell.size.y))
			draw_rect(f, fill)
			draw_rect(Rect2(f.position, Vector2(fw, p)), fill.lightened(0.32))
			draw_rect(Rect2(f.position, Vector2(p, f.size.y)), fill.lightened(0.18))
			draw_rect(Rect2(f.position.x, f.end.y - p, fw, p), fill.darkened(0.32))
			if part >= 1.0:
				draw_rect(Rect2(f.end.x - p, f.position.y + p, p, f.size.y - p), fill.darkened(0.18))
		x += w + gap
	## ilk ve son blokta dış köşe pikselleri dış hatla kapanır (yuvarlak görünüm)
	draw_rect(Rect2(inner.position, Vector2(p, p)), OUTLINE)
	draw_rect(Rect2(inner.position.x, inner.end.y - p, p, p), OUTLINE)
	draw_rect(Rect2(inner.end.x - p, inner.position.y, p, p), OUTLINE)
	draw_rect(Rect2(inner.end.x - p, inner.end.y - p, p, p), OUTLINE)
	draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------------------------------------------------------- D Pirinç Kapaklı
func _style_brass(xf: Transform2D, g0: Rect2) -> void:
	var p: float = 2.0
	var g: Rect2 = _snap(g0, p)
	draw_set_transform_matrix(xf.affine_inverse())
	var cap_w: float = 4 * p
	## kanal (iki kapak arası): üst/alt koyu çizgi + kuyu
	var ch := Rect2(g.position.x + cap_w - p, g.position.y + p, g.size.x - 2 * cap_w + 2 * p, g.size.y - 2 * p)
	draw_rect(ch, OUTLINE)
	var inner := ch.grow(-p)
	draw_rect(inner, under)
	var fw: float = floorf(inner.size.x * clampf(ratio, 0.0, 1.0) / p) * p
	if fw > 0.0:
		var hgt: float = inner.size.y
		var b1: float = floorf(hgt / 3.0 / p) * p
		draw_rect(Rect2(inner.position, Vector2(fw, hgt)), fill)
		draw_rect(Rect2(inner.position, Vector2(fw, b1)), fill.lightened(0.22))
		draw_rect(Rect2(inner.position.x, inner.end.y - b1, fw, b1), fill.darkened(0.25))
		var sh_w: float = minf(fw - 2 * p, floorf(inner.size.x * 0.3 / p) * p)
		if sh_w > 0.0:
			draw_rect(Rect2(inner.position.x + 2 * p, inner.position.y + p * 0.5, sh_w, p * 0.5), Color(1, 1, 1, 0.45))
	## pirinç kapaklar
	for side in [0, 1]:
		var cx: float = g.position.x if side == 0 else g.end.x - cap_w
		var cap := Rect2(cx, g.position.y, cap_w, g.size.y)
		_round_rows(cap, p, [1], P_BRASS_DK)
		var ci := cap.grow(-p)
		draw_rect(ci, P_BRASS)
		draw_rect(Rect2(ci.position, Vector2(ci.size.x, p)), P_BRASS_HI)
		draw_rect(Rect2(ci.position.x, ci.end.y - p, ci.size.x, p), P_BRASS_SH)
		draw_rect(Rect2(ci.position.x + (p if side == 0 else 0.0), ci.position.y + p, p, ci.size.y - 2 * p), P_BRASS_HI if side == 0 else P_BRASS_SH)
		## perçin
		var rv := Vector2(ci.position.x + floorf((ci.size.x - p) * 0.5 / p) * p, ci.position.y + floorf((ci.size.y - p) * 0.5 / p) * p)
		draw_rect(Rect2(rv, Vector2(p, p)), P_BRASS_DK)
		draw_rect(Rect2(rv - Vector2(0, p * 0.5), Vector2(p * 0.5, p * 0.5)), P_BRASS_HI)
	draw_set_transform_matrix(Transform2D.IDENTITY)
