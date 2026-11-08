extends RefCounted

## YUMUŞAK KART prototipi (2026-11-07) çizim yardımcıları. OYUNA BAĞLI DEĞİL.
## Her şey 3 px sanat pikseli ızgarasında (stil rehberi bölüm 3): köşe = piksel daire basamağı, çizgi 1 sanat px, elips sanat px satırları.
## Koordinatlar ekran px (3'ün katı), yarıçaplar sanat px (r) ya da ekran px (elips).

const PX := 3.0


## r sanat px yarıçaplı köşede, dış kenardan i. satırın içeri girişi (sanat px).
static func inset(r: int, i: int) -> int:
	if r <= 0 or i >= r:
		return 0
	var dy: float = float(r) - float(i) - 0.5
	return int(roundf(float(r) - sqrt(maxf(0.0, float(r * r) - dy * dy))))


## Piksel basamaklı köşeli dolu dikdörtgen.
static func rrect(ci: CanvasItem, rect: Rect2, r: int, col: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or col.a <= 0.0:
		return
	var rows: int = int(roundf(rect.size.y / PX))
	var rr: int = clampi(r, 0, rows / 2)
	var mid_h: float = rect.size.y - 2.0 * rr * PX
	if mid_h > 0.0:
		ci.draw_rect(Rect2(rect.position.x, rect.position.y + rr * PX, rect.size.x, mid_h), col)
	for i in rr:
		var k: float = inset(rr, i) * PX
		var w: float = rect.size.x - 2.0 * k
		if w <= 0.0:
			continue
		ci.draw_rect(Rect2(rect.position.x + k, rect.position.y + i * PX, w, PX), col)
		ci.draw_rect(Rect2(rect.position.x + k, rect.end.y - (i + 1) * PX, w, PX), col)


## Dikiş: rect'in kenarı boyunca 1 sanat px kalın kesik çizgi (on/off sanat px, kenarda ortalı);
## köşede yay yerine tek çapraz dikiş (r-2 piksel).
static func stitches(ci: CanvasItem, rect: Rect2, r: int, col: Color, on: int = 2, off: int = 2) -> void:
	if col.a <= 0.0:
		return
	var period: int = on + off
	var n: int = int(roundf(rect.size.x / PX)) - 2 * r
	if n > 0:
		var cnt: int = (n + off) / period
		var used: int = cnt * period - off
		var x0: float = rect.position.x + float(r + (n - used) / 2) * PX
		for d in cnt:
			var x: float = x0 + d * period * PX
			ci.draw_rect(Rect2(x, rect.position.y, on * PX, PX), col)
			ci.draw_rect(Rect2(x, rect.end.y - PX, on * PX, PX), col)
	var m: int = int(roundf(rect.size.y / PX)) - 2 * r
	if m > 0:
		var cnt2: int = (m + off) / period
		var used2: int = cnt2 * period - off
		var y0: float = rect.position.y + float(r + (m - used2) / 2) * PX
		for d in cnt2:
			var y: float = y0 + d * period * PX
			ci.draw_rect(Rect2(rect.position.x, y, PX, on * PX), col)
			ci.draw_rect(Rect2(rect.end.x - PX, y, PX, on * PX), col)
	if r >= 3:
		var corners: Array = [
			[rect.position.x, rect.position.y, 1.0, 1.0], [rect.end.x - PX, rect.position.y, -1.0, 1.0],
			[rect.position.x, rect.end.y - PX, 1.0, -1.0], [rect.end.x - PX, rect.end.y - PX, -1.0, -1.0]]
		for c: Array in corners:
			for i in range(1, r - 1):
				ci.draw_rect(Rect2(float(c[0]) + float(c[2]) * i * PX, float(c[1]) + float(c[3]) * (r - 1 - i) * PX, PX, PX), col)


## Elipsin sanat px satırlarındaki yarı genişlikleri (ekran px) + üst kenar.
static func _ellipse_rows(c: Vector2, rx: float, ry: float) -> Array:
	var rows: int = int(roundf(2.0 * ry / PX))
	var top: float = roundf((c.y - rows * PX * 0.5) / PX) * PX
	var hws: Array = []
	for i in rows:
		var yc: float = (i + 0.5) * PX - rows * PX * 0.5
		var t: float = 1.0 - (yc * yc) / (ry * ry)
		hws.append(roundf(rx * sqrt(t) / PX) * PX if t > 0.0 else 0.0)
	return [top, hws]


## Dolu elips (c.x 3'ün katı olmalı).
static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx <= 0.0 or ry <= 0.0 or col.a <= 0.0:
		return
	var er: Array = _ellipse_rows(c, rx, ry)
	var hws: Array = er[1]
	for i in hws.size():
		var hw: float = hws[i]
		if hw > 0.0:
			ci.draw_rect(Rect2(c.x - hw, float(er[0]) + i * PX, 2.0 * hw, PX), col)


## 1 sanat px elips çizgisi (komşu satırlara bağlanır, yassı elipste boşluk kalmaz).
static func ellipse_ring(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx <= 0.0 or ry <= 0.0 or col.a <= 0.0:
		return
	var er: Array = _ellipse_rows(c, rx, ry)
	var hws: Array = er[1]
	var n: int = hws.size()
	for i in n:
		var hw: float = hws[i]
		if hw <= 0.0:
			continue
		var y: float = float(er[0]) + i * PX
		if i == 0 or i == n - 1:
			ci.draw_rect(Rect2(c.x - hw, y, 2.0 * hw, PX), col)
			continue
		var inner: float = minf(minf(float(hws[i - 1]), float(hws[i + 1])), hw - PX)
		if inner <= 0.0:
			ci.draw_rect(Rect2(c.x - hw, y, 2.0 * hw, PX), col)
			continue
		ci.draw_rect(Rect2(c.x - hw, y, hw - inner, PX), col)
		ci.draw_rect(Rect2(c.x + inner, y, hw - inner, PX), col)


## Karakter deseni ("#" = dolu) sanat pikseliyle.
static func pattern(ci: CanvasItem, pos: Vector2, rows: Array, col: Color) -> void:
	for y in rows.size():
		var s: String = rows[y]
		for x in s.length():
			if s[x] == "#":
				ci.draw_rect(Rect2(pos.x + x * PX, pos.y + y * PX, PX, PX), col)
