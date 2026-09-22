extends Node2D

## Büyücü Kız pasifi KADİM PATLAMA'nın görseli - PIXEL tarzı, SIFIRDAN (kullanıcı isteği, 2026-09-22: "pasif skill efektini sıfırdan, daha iyi,
## pixel tarzda tasarla"). Eskiden 56x56'lık raster sprite sheet'ti. Öldürülen yaratığın bulunduğu yerde "kadim bir mühür patlıyor":
##   1. YERDE KADİM MÜHÜR: içi dolu 8 köşeli yıldız + 2 halka (biri kesikli, ters yönde dönen) + halka üstünde 8 altın rün işareti - merkezden
##      patlama alanına doğru genişler (alan hasarının gerçekten vurduğu bölgeyi gösterir) ve solar
##   2. MERKEZ PATLAMASI: beyaz-pembe parlama + yukarı fışkıran 5 ışık sütunu (kısa pixel çizgiler)
##   3. dışa savrulan elmas kristal kırıkları + genişleyen koyu mor dither diski
## Gerçek oyuncuda (player.gd _spawn_world_explosion_fx) da, uzak oyuncuda ("melee_hit" broadcast'i, scene_path ile bu sahne) da AYNI script.
## Arcane Lanet patlamasından (fx_arcane_impact.gd, kafatası + yıldız ışını) bilerek FARKLI: burada yerde dönen bir MÜHÜR + altın rünler var.

const PixelDraw := preload("res://scripts/pixel_draw.gd")

const LIFE := 0.6
const MAX_R := 96.0 ## mühür halkasının en dış yarıçapı (px) - oyun alanını boğmasın diye hasar yarıçapından (160) küçük tutuldu

var _t: float = 0.0
var _shards: Array = [] ## [dir, speed, kind]


func _ready() -> void:
	z_index = 40
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in range(10):
		_shards.append([Vector2.from_angle(TAU * float(i) / 10.0 + randf_range(-0.25, 0.25)), randf_range(0.7, 1.15), i % 3])


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


## Kenarları pixel ızgarasına oturan iç içe geçmiş 2 kare = 8 köşeli yıldızın çizgileri (rot kadar döner).
func _star8(radius: float, rot: float, col: Color) -> void:
	for sq in range(2):
		var pts: Array[Vector2] = []
		for i in range(4):
			var a: float = rot + float(sq) * PI / 4.0 + float(i) * PI / 2.0
			pts.append(Vector2(cos(a), sin(a) * 0.62) * radius)
		for i in range(4):
			PixelDraw.line(self, pts[i], pts[(i + 1) % 4], col, 1)


func _draw() -> void:
	var t: float = PixelDraw.TEXEL
	var k: float = clampf(_t / LIFE, 0.0, 1.0)
	var ease_out: float = 1.0 - pow(1.0 - k, 2.2)
	var fade: float = 1.0 - pow(k, 1.7) ## uzun süre okunaklı kalıp sonda hızla solsun
	var R: float = 16.0 + (MAX_R - 16.0) * ease_out
	var gold := Color(1.0, 0.86, 0.42)
	var violet := Color(0.72, 0.38, 1.0)
	var pink := Color(1.0, 0.7, 0.95)
	## --- koyu mor dither zemin ---
	PixelDraw.disc_dither(self, Vector2.ZERO, R * 0.62, Color(0.3, 0.06, 0.48, 0.45 * fade), int(_t * 24.0), 2)
	## --- mühür: perspektifli (yassı) elips halkalar + 8 köşeli yıldız ---
	var ry: float = 0.62
	var n_outer: int = maxi(24, int(TAU * R / t))
	for i in range(n_outer):
		var a: float = TAU * float(i) / float(n_outer)
		PixelDraw.px(self, Vector2(cos(a) * R, sin(a) * R * ry), 1, Color(violet, fade * 0.95))
	var R2: float = R * 0.7
	var n_in: int = maxi(20, int(TAU * R2 / t))
	for i in range(n_in):
		if (i + int(_t * 30.0)) % 4 >= 2:
			continue
		var a2: float = -TAU * float(i) / float(n_in)
		PixelDraw.px(self, Vector2(cos(a2) * R2, sin(a2) * R2 * ry), 1, Color(pink, fade * 0.85))
	_star8(R * 0.55, _t * 1.6, Color(gold, fade))
	_star8(R * 0.55 - 1.5, _t * 1.6, Color(1.0, 0.95, 0.7, fade * 0.7))
	## --- 8 altın rün işareti (halka üstünde, küçük artı) ---
	for i in range(8):
		var ar: float = TAU * float(i) / 8.0 + _t * 0.9
		var rp: Vector2 = Vector2(cos(ar) * R, sin(ar) * R * ry)
		PixelDraw.px(self, rp, 1, Color(gold, fade))
		PixelDraw.px(self, rp + Vector2(t, 0), 1, Color(gold, fade * 0.7))
		PixelDraw.px(self, rp + Vector2(-t, 0), 1, Color(gold, fade * 0.7))
		PixelDraw.px(self, rp + Vector2(0, -t), 1, Color(gold, fade * 0.7))
	## --- merkez patlaması: parlama + yukarı fışkıran ışık sütunları ---
	if k < 0.22:
		var fk: float = k / 0.22
		PixelDraw.disc(self, Vector2(0, -4.0), (1.0 - fk * 0.5) * 11.0 * t, Color(1.0, 0.86, 0.98, 1.0 - fk))
		PixelDraw.disc(self, Vector2(0, -4.0), (1.0 - fk) * 6.0 * t, Color(1, 1, 1, 1))
	for i in range(5):
		var cx: float = (float(i) - 2.0) * 4.0
		var col_h: float = (16.0 + 22.0 * (1.0 - absf(float(i) - 2.0) / 3.0)) * sin(minf(1.0, k * 1.5) * PI)
		var steps: int = maxi(0, int(col_h / t))
		for s in range(steps):
			var f: float = float(s) / float(maxi(steps, 1))
			PixelDraw.px(self, Vector2(cx, -3.0 - float(s) * t), 2, Color(pink, fade * (1.0 - f * 0.8)))
	## --- elmas kristal kırıkları ---
	for sh in _shards:
		var dir: Vector2 = sh[0]
		var pos: Vector2 = Vector2(dir.x, dir.y * 0.7) * (10.0 + 62.0 * ease_out * float(sh[1])) + Vector2(0, -8.0 * ease_out)
		var col: Color = [Color(1, 0.92, 1), violet, gold][int(sh[2])]
		PixelDraw.px(self, pos, 1, Color(col, fade))
		PixelDraw.px(self, pos + Vector2(t, 0), 1, Color(col, fade * 0.6))
		PixelDraw.px(self, pos + Vector2(0, t), 1, Color(col, fade * 0.6))
