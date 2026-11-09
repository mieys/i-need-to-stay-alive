extends RefCounted

## PİKSEL YOL TABELASI (madde 532, 2026-11-09; kullanıcı seçimi: pazar düğmeleri prototipi "B - Ok Tabela", madde 530). Sağı sivri ahşap
## tabela biçiminde düğme zemini - level pazarının DEVAM ET'i (SATIN AL ile aynı altın düğmeydi, karıştırılıyordu).
## Sanat pikselinde boyanır (1 sanat px = 3 ekran px, stil rehberi), x3 en yakın komşu büyütülür ve düğmenin TAM boyunda çizilir (9 dilim yok:
## uç tüm yüksekliği kaplar -> düğme boyu w_art*3 x h_art*3 olmalı). Sol köşeler 1 px yuvarlak, 1 px kenar (4 komşu), üst/sol iç ışık, alt iç
## gölge, kısa tahta damarları + solda iki çivi başı. edge_only: yalnız kenar (odak çerçevesi; normal kutunun üstüne çizilir).
## Renkler hud_theme rolleri. İçerik payı: sağda uç kadar (yazı gövdede ortalanır).

const HT := preload("res://scripts/hud_theme.gd")
const PX := 3
## Damarlar 100 sanat px genişliğe göre [x0, satır, x1); başka genişlikte orantılanır, satır yüksekliğe göre kırpılır.
const GRAIN := [[7, 4, 22], [30, 15, 52], [60, 4, 78], [12, 14, 20]]

static var _cache: Dictionary = {}


## Ucun genişliği (ekran px).
static func tip_px(h_art: int) -> int:
	return (h_art - 1) / 2 * PX


static func box(w_art: int, h_art: int, fill: Color, edge: Color, edge_only: bool = false) -> StyleBoxTexture:
	var key: String = "%d_%d_%s_%s_%s" % [w_art, h_art, fill.to_html(), edge.to_html(), edge_only]
	if not _cache.has(key):
		var img: Image = paint(w_art, h_art, fill, edge, edge_only)
		img.resize(w_art * PX, h_art * PX, Image.INTERPOLATE_NEAREST)
		_cache[key] = ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = _cache[key]
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = float(tip_px(h_art))
	sb.content_margin_bottom = float(PX) ## alt iç gölge bandı: yazı yüzün ortasına
	return sb


## Sanat pikselinde tabela. Tek sayı yükseklikte uç tek pikselde ortalanır.
static func paint(w: int, h: int, fill: Color, edge: Color, edge_only: bool = false) -> Image:
	var tip: int = (h - 1) / 2
	var body_end: int = w - 1 - tip
	var inside := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= w or y >= h:
			return false
		if x <= body_end:
			return not (x == 0 and (y == 0 or y == h - 1))
		return absi(y - tip) <= tip - (x - body_end)
	var hi: Color = fill.lerp(HT.ACCENT_SOFT, 0.28)
	var lo: Color = fill.lerp(HT.OUTLINE, 0.45)
	var grain: Color = fill.lerp(HT.OUTLINE, 0.22)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			if not inside.call(x, y):
				continue
			var is_edge: bool = not (inside.call(x - 1, y) and inside.call(x + 1, y) and inside.call(x, y - 1) and inside.call(x, y + 1))
			if edge_only:
				if is_edge:
					img.set_pixel(x, y, edge)
				continue
			var col: Color = fill
			if is_edge:
				col = edge
			elif not inside.call(x, y - 2) or not inside.call(x - 2, y):
				col = hi
			elif not inside.call(x, y + 2):
				col = lo
			else:
				for s: Array in GRAIN:
					var x0: int = int(s[0]) * w / 100
					var x1: int = mini(int(s[2]) * w / 100, body_end - 2)
					if y == int(s[1]) and x >= x0 and x < x1:
						col = grain
			img.set_pixel(x, y, col)
	if not edge_only and h >= 10:
		for ny: int in [4, h - 5]:
			img.set_pixel(3, ny, edge)
			img.set_pixel(3, ny - 1, hi)
	return img
