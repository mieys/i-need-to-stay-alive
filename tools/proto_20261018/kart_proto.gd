extends SceneTree

## LEVEL ATLAMA + SANDIK kartları (seçme + karıştırma) PROTOTİPLERİ (2026-10-18). Kullanıcı: "level atlama sandık açma seçme
## rerolleme kartları için 4 yeni prototip hazırla". Oyuna BAĞLI DEĞİL: gerçek SP main.tscn açılır, önce ŞU ANKİ level ekranı ve
## sandık ekranı çekilir (simdi_*), sonra her yön kendi CanvasLayer'ında AYNI gerçek veriyle çizilir (stat ikonları, kart
## değerleri level_up_screen._scaled_desc_value'dan, eşya Items'tan, gerçek sandık + ışık sütunu sayfaları, gerçek zar/altın/imleç):
##  A Asılı Levha (Kısık Ahşap HUD: kirişten iple sarkan tahta levhalar; karıştırma = levha kendi ekseninde döner, seçim = seçilen
##    yukarı çekilir, iplerin kesildiği diğerleri düşer)
##  B Parşömen Kart (Ateş Işığı: kemerli pencereli parşömen + kurdele; karıştırma = kartlar kapanır, deste olur, karılır, dağıtılır,
##    açılır; seçim = tier renginde mühür basılır)
##  C Rün Taşı (Gece Sıvası: oyma halkalı kayrak taşı, tier = yanan taş sayısı; karıştırma = slot makarası soldan sağa durur;
##    seçim = rün halkası tutuşur, taş ışık küresine dönüşür)
##  D Işıklı Kapsül (bugünkü satır düzeni + sandığın ışık sütunu dili: madalyon + soldan ışık şeridi; karıştırma = satırlar
##    kayarak çıkar/girer; seçim = madalyondan ışık sütunu yükselir)
## Kareler zaman çizelgesinden DETERMİNİSTİK çizilir (gerçek zamandan bağımsız): level = bekle -> karıştır -> bekle -> seç;
## sandık = sallanma -> patlama -> kart çıkışı -> AL. Çıktı OUT: X_level.png, X_sandik.png, X_anlar.png (4 an), ozet_level.png,
## ozet_sandik.png; KART_FRAMES klasörüne X_level/NNN.png + X_sandik/NNN.png (GIF'e kart_gif.py çevirir).
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261018/kart_proto.gd
##   KART_ONLY="simdi,A" seçili yönler; KART_NOGIF=1 kare dökmeden sadece durağan resimler; KART_FRAMES = kare klasörü (mutlak).

const OUT := "res://tools/proto_20261018/out/kart/"
const GIF_FPS := 15.0
const GIF_CROP := Rect2i(300, 20, 1320, 960)
const GIF_SIZE := Vector2i(660, 480)
const CAPTIONS := {
	"A": "A - Asılı Levha",
	"B": "B - Parşömen Kart",
	"C": "C - Rün Taşı",
	"D": "D - Işıklı Kapsül",
}
## [stat id, tier, kaç kez alındı] - karıştırmadan önce / sonra (ortadaki seçilir)
const LEVEL_OLD := [["max_health", 1, 0], ["fire_rate", 3, 2], ["speed", 2, 1]]
const LEVEL_NEW := [["damage", 2, 3], ["crit_chance", 4, 0], ["dodge", 1, 1]]
const ITEM_KEY := "kan_disi"
const ITEM_TIER := 2
const CHEST_GOLD := 24
const REEL_ITEMS := ["bile_tasi", "yasam_kristali", "ceviklik_yuzugu", "tecrube_kitabi", "kutsal_tilsim", "isik_parcacigi"]

## Palet: HUD "Kısık Ahşap" (hud_theme.gd), Gece Sıvası (menu_dark_kit.gd), parşömen mürekkebi (tier_system.gd COLORS).
const OUTLINE := Color("#20150d")
const RIM := Color("#6a4a30")
const RIM_HI := Color("#86623f")
const RIM_LO := Color("#4b3320")
const PANEL := Color("#5a4734")
const INSET := Color("#271a11")
const STRIPE := Color("#342316")
const H_TEXT := Color("#f3e6cc")
const H_DIM := Color("#c4b090")
const H_PRICE := Color("#f6d27e")
const INK := Color("#3a2212")
const INK_DIM := Color("#5e3f24")
const INK_GOLD := Color("#8a5608")
const PARCH := Color("#efe0bf")
const CREAM := Color("#fff0d6")
const S_OUT := Color("#0c0c16")
const S_TEXT := Color("#efe6d6")
const S_DIM := Color("#a7a2c0")
const S_ACCENT := Color("#f4c56e")
const S_PRICE := Color("#f0da94")
## tier: [açık, orta, koyu] (level satırı ROW_GLOW_COLORS ailesi)
const TP := [
	[Color("#eef1f4"), Color("#a9b1ba"), Color("#5f6873")],
	[Color("#a8ccff"), Color("#4f86d8"), Color("#2c56b0")],
	[Color("#e2bbff"), Color("#9c5ad8"), Color("#5e2a92")],
	[Color("#ffd27a"), Color("#f08a3a"), Color("#b0281e")],
]
const TIER_TEXT := [Color("#cdd1d6"), Color("#a6c6f4"), Color("#d8aef4"), Color("#f8a890")]
const TIER_INK := [Color("#5a3a20"), Color("#2c56b0"), Color("#7430ac"), Color("#b0281e")]
const TIER_NAMES := ["Sıradan", "Nadir", "Epik", "Efsanevi"]
const TIER_UPPER := ["SIRADAN", "NADİR", "EPİK", "EFSANEVİ"]
const CAT_LIGHT := {"Saldırı": Color("#f09a80"), "Savunma": Color("#b5d98a"), "Yardımcı": Color("#9cc4ff")}
const CAT_INK := {"Saldırı": Color("#9a2e22"), "Savunma": Color("#3d6616"), "Yardımcı": Color("#2c5c9a")}
const RUNES := [
	["..#..", ".###.", "..#..", "..#..", ".#.#."],
	["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
	["###..", "#..#.", "###..", "#..#.", "#...#"],
	[".##..", "#..#.", "..#..", ".#...", "####."],
]


## Piksel dokular (1 sanat pikseli = 3 ekran pikseli; oyunun 48'lik ızgarası).
class Paint:
	static func hsh(x: int, y: int, s: int) -> float:
		var n: int = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
		n = (n * 1103515245 + 12345) & 0x7fffffff
		n = n ^ (n >> 15)
		return float(n & 0xffff) / 65535.0

	static func img(w: int, h: int) -> Image:
		return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)

	static func rect(im: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
		var r := Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, im.get_size()))
		if r.size.x > 0 and r.size.y > 0:
			im.fill_rect(r, c)

	static func px(im: Image, x: int, y: int, c: Color) -> void:
		if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
			im.set_pixel(x, y, c)

	static func frame(im: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
		rect(im, x, y, w, 1, c)
		rect(im, x, y + h - 1, w, 1, c)
		rect(im, x, y, 1, h, c)
		rect(im, x + w - 1, y, 1, h, c)

	static func diamond(im: Image, cx: int, cy: int, r: int, c: Color) -> void:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) + absi(dy) <= r:
					px(im, cx + dx, cy + dy, c)

	static func prof(r: int) -> Array:
		var out: Array = []
		for i in r:
			var yy: float = r - i - 0.5
			out.append(int(round(r - sqrt(r * r - yy * yy))))
		return out

	## 0 = şeklin dışı, 1 = kenar pikseli, 2 = bir içeri ... (köşeler pr satır kesikleriyle yuvarlanır)
	static func dmap(w: int, h: int, pr: Array) -> PackedInt32Array:
		var dm := PackedInt32Array()
		dm.resize(w * h)
		for y in h:
			var k: int = 0
			if y < pr.size():
				k = int(pr[y])
			elif h - 1 - y < pr.size():
				k = int(pr[h - 1 - y])
			for x in w:
				dm[y * w + x] = 9999 if (x >= k and x < w - k) else 0
		for y in h:
			for x in w:
				var i: int = y * w + x
				if dm[i] == 0:
					continue
				var up: int = dm[i - w] if y > 0 else 0
				var lf: int = dm[i - 1] if x > 0 else 0
				dm[i] = mini(dm[i], mini(up, lf) + 1)
		for y in range(h - 1, -1, -1):
			for x in range(w - 1, -1, -1):
				var i: int = y * w + x
				if dm[i] == 0:
					continue
				var dn: int = dm[i + w] if y < h - 1 else 0
				var rt: int = dm[i + 1] if x < w - 1 else 0
				dm[i] = mini(dm[i], mini(dn, rt) + 1)
		return dm

	static func line(im: Image, x0: int, y0: int, x1: int, y1: int, c: Color, hi: Color) -> void:
		var n: int = maxi(absi(x1 - x0), absi(y1 - y0))
		for k in n + 1:
			var f: float = float(k) / maxf(1.0, n)
			var x: int = int(round(lerpf(x0, x1, f)))
			var y: int = int(round(lerpf(y0, y1, f)))
			px(im, x + 1, y + 1, hi)
			px(im, x, y, c)

	static func rivet(im: Image, cx: int, cy: int) -> void:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				px(im, cx + dx, cy + dy, Color("#8a7350"))
		px(im, cx, cy, Color("#e0cfa0"))
		px(im, cx + 1, cy + 1, Color("#4b3a22"))

	# ---------------------------------------------------------------- A: ahşap
	static func wood(w: int, h: int, pr: Array, sd: int, plank: int) -> Image:
		var im := img(w, h)
		var dm := dmap(w, h, pr)
		for y in h:
			for x in w:
				var d: int = dm[y * w + x]
				if d == 0:
					continue
				var c: Color
				var bot: bool = y >= h - 3 or x >= w - 3
				if d == 1:
					c = OUTLINE
				elif d == 2:
					c = RIM_LO if bot else (RIM_HI if y <= 2 or x <= 2 else RIM)
				elif d == 3:
					c = RIM_LO if bot else RIM
				elif d == 4:
					c = RIM_LO
				else:
					c = PANEL
					var py: int = (y - 4) % plank
					if py == plank - 1:
						c = RIM_LO
					elif py == 0 and y > 4:
						c = Color("#66513c")
					elif hsh(x / 6, y, sd) < 0.14:
						c = Color("#523f2d")
					elif hsh(x, y, sd + 1) < 0.015:
						c = Color("#45341f")
				im.set_pixel(x, y, c)
		return im

	static func a_front(tier: int) -> Image:
		var w: int = 100
		var h: int = 140
		var im := wood(w, h, [2, 1], 3, 34)
		var pal: Array = TP[tier - 1]
		rect(im, 8, 6, w - 16, 14, OUTLINE)
		rect(im, 9, 7, w - 18, 12, pal[1])
		rect(im, 9, 7, w - 18, 1, pal[0])
		rect(im, 9, 18, w - 18, 1, pal[2])
		for p: Vector2i in [Vector2i(8, 6), Vector2i(w - 9, 6), Vector2i(8, 19), Vector2i(w - 9, 19)]:
			px(im, p.x, p.y, PANEL)
		rivet(im, 14, 2)
		rivet(im, w - 15, 2)
		for y in range(24, 80):
			for x in range(22, 80):
				var dd: float = Vector2(x + 0.5 - 50.0, y + 0.5 - 51.0).length()
				if dd <= 24.0:
					px(im, x, y, Color("#1e140d") if y < 32 else INSET)
				elif dd <= 25.2:
					px(im, x, y, RIM_LO if y < 51 else RIM_HI)
		rect(im, 7, 82, w - 14, h - 90, STRIPE)
		rect(im, 7, 82, w - 14, 1, OUTLINE)
		rect(im, 7, h - 9, w - 14, 1, RIM_HI)
		return im

	static func a_back() -> Image:
		var im := wood(100, 140, [2, 1], 9, 34)
		rivet(im, 14, 2)
		rivet(im, 85, 2)
		for y in range(54, 86):
			for x in range(34, 66):
				var cx: bool = x <= 35 or x >= 64
				var cy: bool = y <= 55 or y >= 84
				if cx and cy and not ((x == 35 or x == 64) and (y == 55 or y == 84)):
					continue
				var c: Color = RIM
				if x == 34 or y == 54 or x == 65 or y == 85 or (x == 35 or x == 64) and (y == 55 or y == 84):
					c = OUTLINE
				elif x >= 63 or y >= 83:
					c = RIM_LO
				elif x <= 36 or y <= 56:
					c = RIM_HI
				px(im, x, y, c)
		for p: Vector2i in [Vector2i(41, 61), Vector2i(55, 61), Vector2i(48, 68), Vector2i(41, 75), Vector2i(55, 75)]:
			rect(im, p.x, p.y, 4, 4, OUTLINE)
			px(im, p.x + 1, p.y + 1, RIM_LO)
		return im

	# ---------------------------------------------------------------- B: parşömen
	static func in_arch(x: int, y: int, ax0: int, ax1: int, ay0: int, ay1: int) -> bool:
		if x < ax0 or x > ax1 or y < ay0 or y > ay1:
			return false
		var acx: float = (ax0 + ax1 + 1) * 0.5
		var ar: float = (ax1 - ax0 + 1) * 0.5
		var acy: float = ay0 + ar
		if y + 0.5 >= acy:
			return true
		return Vector2(x + 0.5 - acx, y + 0.5 - acy).length() <= ar

	static func parchment(w: int, h: int, sd: int) -> Image:
		var im := img(w, h)
		var dm := dmap(w, h, [2, 1])
		for y in h:
			for x in w:
				var d: int = dm[y * w + x]
				if d == 0:
					continue
				var c: Color
				if d == 1:
					if hsh(x, y, sd) < 0.22:
						continue
					c = Color("#7a5a36")
				elif d == 2:
					c = Color("#dcc79e")
				else:
					c = PARCH
					if hsh(x, y, sd + 1) < 0.035:
						c = Color("#e2cfa6")
					elif hsh(x, y, sd + 2) < 0.008:
						c = Color("#cdb68a")
					if y > h - 26:
						c = c.lerp(Color("#e3cfa5"), 0.5)
				im.set_pixel(x, y, c)
		return im

	static func b_front(tier: int) -> Image:
		var w: int = 96
		var h: int = 148
		var im := parchment(w, h, 11)
		var ink: Color = TIER_INK[tier - 1]
		var pal: Array = TP[tier - 1]
		frame(im, 4, 4, w - 8, h - 8, ink)
		frame(im, 6, 6, w - 12, h - 12, ink.lerp(PARCH, 0.55))
		for p: Vector2i in [Vector2i(4, 4), Vector2i(w - 5, 4), Vector2i(4, h - 5), Vector2i(w - 5, h - 5)]:
			diamond(im, p.x, p.y, 2, ink)
			px(im, p.x, p.y, pal[0])
		var ax0: int = 13
		var ax1: int = w - 14
		var ay0: int = 12
		var ay1: int = 64
		for y in range(ay0, ay1 + 1):
			for x in range(ax0, ax1 + 1):
				if not in_arch(x, y, ax0, ax1, ay0, ay1):
					continue
				var e1: bool = not (in_arch(x - 1, y, ax0, ax1, ay0, ay1) and in_arch(x + 1, y, ax0, ax1, ay0, ay1)
						and in_arch(x, y - 1, ax0, ax1, ay0, ay1) and in_arch(x, y + 1, ax0, ax1, ay0, ay1))
				var e2: bool = not (in_arch(x - 2, y, ax0, ax1, ay0, ay1) and in_arch(x + 2, y, ax0, ax1, ay0, ay1)
						and in_arch(x, y - 2, ax0, ax1, ay0, ay1))
				var f: float = float(y - ay0) / float(ay1 - ay0)
				var c: Color
				if e1:
					c = INK
				elif e2:
					c = pal[0]
				elif f < 0.3:
					c = pal[2]
				elif f < 0.55:
					c = (pal[2] as Color).lerp(pal[1], 0.5)
				elif f < 0.8:
					c = pal[1]
				else:
					c = (pal[1] as Color).lerp(pal[0], 0.45)
				im.set_pixel(x, y, c)
		for k in 7:
			var sx: int = ax0 + 6 + int(hsh(k, 3, 41) * (ax1 - ax0 - 12))
			var sy: int = ay0 + 8 + int(hsh(k, 4, 41) * 12)
			if in_arch(sx, sy, ax0 + 2, ax1 - 2, ay0 + 2, ay1):
				px(im, sx, sy, pal[0])
		for p: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			px(im, 26 + p.x, 26 + p.y, pal[0])
		var ry0: int = 60
		var ry1: int = 71
		for y in range(ry0, ry1 + 1):
			var depth: int = maxi(0, int(4.0 - absf(y - 65.5) * 0.7))
			for x in range(2, w - 2):
				if x - 2 < depth or (w - 3 - x) < depth:
					continue
				var c: Color = ink
				if y == ry0 or y == ry1 or x - 2 == depth or w - 3 - x == depth:
					c = INK
				elif y == ry0 + 1:
					c = ink.lerp(pal[1], 0.5)
				elif y == ry1 - 1:
					c = ink.lerp(INK, 0.4)
				im.set_pixel(x, y, c)
		return im

	static func b_back() -> Image:
		var w: int = 96
		var h: int = 148
		var im := img(w, h)
		var dm := dmap(w, h, [2, 1])
		for y in h:
			for x in w:
				var d: int = dm[y * w + x]
				if d == 0:
					continue
				var c: Color
				if d == 1:
					c = Color("#2a120e")
				elif d == 2:
					c = Color("#c8964a")
				elif d == 3:
					c = Color("#8a5a2a")
				elif d == 4:
					c = Color("#3e1814")
				else:
					c = Color("#5a2420")
					if (x + y) % 12 == 0 or (x - y + 1200) % 12 == 0:
						c = Color("#6c2e28")
				im.set_pixel(x, y, c)
		var cx: float = 48.0
		var cy: float = 74.0
		for y in range(48, 101):
			for x in range(22, 75):
				var v := Vector2(x + 0.5 - cx, y + 0.5 - cy)
				var dd: float = v.length()
				if dd <= 4.0:
					px(im, x, y, Color("#c8964a"))
				elif dd <= 9.0:
					px(im, x, y, Color("#f4d890"))
				elif dd <= 15.0:
					px(im, x, y, Color("#e0b060"))
				elif dd <= 17.0:
					px(im, x, y, Color("#8a5a2a"))
				elif dd >= 19.0 and dd <= 25.0:
					var a: float = fposmod(v.angle(), TAU / 8.0)
					if a < 0.12 or a > TAU / 8.0 - 0.12:
						px(im, x, y, Color("#c8964a"))
		for p: Vector2i in [Vector2i(10, 10), Vector2i(w - 11, 10), Vector2i(10, h - 11), Vector2i(w - 11, h - 11)]:
			diamond(im, p.x, p.y, 2, Color("#c8964a"))
		return im

	static func b_seal(tier: int) -> Image:
		var im := img(32, 32)
		var pal: Array = TP[tier - 1]
		for y in 32:
			for x in 32:
				var v := Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0)
				var dd: float = v.length()
				var edge: float = 12.5 + 1.6 * hsh(int((v.angle() + PI) * 4.0), 1, 31)
				if dd > edge + 1.0:
					continue
				var c: Color = pal[1]
				if dd > edge:
					c = INK
				elif dd > edge - 1.2:
					c = pal[2]
				elif dd <= 9.5 and dd > 8.3:
					c = pal[2]
				elif x + y < 24 and dd > 6.0:
					c = (pal[1] as Color).lerp(pal[0], 0.3)
				im.set_pixel(x, y, c)
		for p: Vector2i in [Vector2i(10, 16), Vector2i(11, 17), Vector2i(12, 18), Vector2i(13, 19), Vector2i(14, 18), Vector2i(15, 17),
				Vector2i(16, 16), Vector2i(17, 15), Vector2i(18, 14), Vector2i(19, 13), Vector2i(20, 12)]:
			rect(im, p.x, p.y - 1, 2, 2, pal[0])
		return im

	static func b_scroll(w: int, h: int) -> Image:
		var im := img(w, h)
		var dm := dmap(w, h, [2, 1])
		for y in h:
			for x in w:
				var d: int = dm[y * w + x]
				if d == 0:
					continue
				var c: Color
				if d == 1:
					c = Color("#7a5a36")
				elif x < 7 or x >= w - 7:
					c = Color("#7a5a36") if (x == 6 or x == w - 7) else (Color("#d2bb8e") if x % 3 == 0 else Color("#e6d4ad"))
				elif y == 2:
					c = Color("#fff6e0")
				elif y >= h - 3:
					c = Color("#dcc79e")
				else:
					c = PARCH
					if hsh(x, y, 61) < 0.03:
						c = Color("#e2cfa6")
				im.set_pixel(x, y, c)
		return im

	static func b_ribbon(w: int, h: int, tier: int) -> Image:
		var im := img(w, h)
		var ink: Color = TIER_INK[tier - 1]
		var pal: Array = TP[tier - 1]
		var mid: float = (h - 1) * 0.5
		for y in h:
			var depth: int = maxi(0, int(5.0 - absf(y - mid) * 0.5))
			for x in w:
				if x < depth or w - 1 - x < depth:
					continue
				var c: Color = ink
				if y == 0 or y == h - 1 or x == depth or w - 1 - x == depth:
					c = INK
				elif y == 1 or y == 2:
					c = ink.lerp(pal[1], 0.5)
				elif y >= h - 3:
					c = ink.lerp(INK, 0.4)
				im.set_pixel(x, y, c)
		return im

	# ---------------------------------------------------------------- C: kayrak
	static func slate(w: int, h: int, pr: Array, sd: int) -> Image:
		var im := img(w, h)
		var dm := dmap(w, h, pr)
		for y in h:
			for x in w:
				var d: int = dm[y * w + x]
				if d == 0:
					continue
				var c: Color
				if d == 1:
					c = S_OUT
				elif d <= 3:
					var tl: bool = y < 4 or x < 4
					var br: bool = y > h - 5 or x > w - 5
					c = Color("#17172a") if br else (Color("#56557a") if tl else Color("#3b3a5a"))
				else:
					var by: int = y / 4
					var bx: int = (x + (by % 2) * 2) / 4
					var hv: float = hsh(bx, by, sd)
					c = Color("#2b2c42") if hv < 0.4 else (Color("#2f3048") if hv < 0.75 else Color("#27283c"))
					if hsh(x, y, sd + 7) < 0.02:
						c = Color("#35365a")
				im.set_pixel(x, y, c)
		return im

	static func c_front() -> Image:
		var w: int = 104
		var h: int = 140
		var im := slate(w, h, [3, 1, 1], 21)
		var crack := Color("#16162a")
		var chi := Color("#3b3a5a")
		line(im, 8, 104, 14, 112, crack, chi)
		line(im, 14, 112, 13, 120, crack, chi)
		line(im, 13, 120, 19, 131, crack, chi)
		line(im, 92, 22, 97, 30, crack, chi)
		line(im, 97, 30, 95, 38, crack, chi)
		for k in 4:
			var sx: int = 34 + k * 12
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var m: int = absi(dx) + absi(dy)
					if m == 3:
						px(im, sx + dx, 9 + dy, S_OUT)
					elif m < 3:
						px(im, sx + dx, 9 + dy, Color("#12121f"))
		var cx: float = 52.0
		var cy: float = 50.0
		for y in range(16, 86):
			for x in range(18, 88):
				var dd: float = Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
				if dd <= 26.5:
					px(im, x, y, Color("#16162a") if y < cy - 21 else Color("#1d1d30"))
				elif dd <= 28.8:
					px(im, x, y, Color("#121222"))
				elif dd <= 30.0:
					px(im, x, y, Color("#45446a") if y > cy else Color("#17172a"))
		rect(im, 8, 92, w - 16, h - 100, Color("#232338"))
		rect(im, 8, 92, w - 16, 1, Color("#17172a"))
		rect(im, 8, h - 9, w - 16, 1, Color("#3b3a5a"))
		return im

	static func c_gem(tier: int) -> Image:
		var im := img(7, 7)
		var pal: Array = TP[tier - 1]
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var m: int = absi(dx) + absi(dy)
				if m > 3:
					continue
				var c: Color = pal[1]
				if m == 3:
					c = S_OUT
				elif dy < 0 and m <= 1:
					c = pal[0]
				elif dy > 0:
					c = pal[2]
				im.set_pixel(3 + dx, 3 + dy, c)
		return im

	# ---------------------------------------------------------------- D: kapsül
	static func d_row(tier: int, w: int, h: int) -> Image:
		var pal: Array = TP[tier - 1]
		var im := img(w, h)
		var dm := dmap(w, h, prof(8))
		for y in h:
			for x in w:
				var d: int = dm[y * w + x]
				if d == 0:
					continue
				var c: Color
				if d == 1:
					c = OUTLINE
				elif d == 2:
					c = (pal[1] as Color).lerp(INSET, 0.1)
				else:
					c = INSET
					var band: int = (x - 2) / 14
					if band < 10:
						c = c.lerp(pal[1], 0.5 * pow(1.0 - band / 10.0, 1.6))
					if y == 3 and x > 10 and x < int(w * 0.55):
						c = c.lerp(pal[0], 0.3)
					c.a = 0.94
				im.set_pixel(x, y, c)
		return im

	static func d_btn(w: int, h: int) -> Image:
		var im := img(w, h)
		var dm := dmap(w, h, prof(6))
		for y in h:
			for x in w:
				var d: int = dm[y * w + x]
				if d == 0:
					continue
				var c: Color = Color(INSET, 0.94)
				if d == 1:
					c = OUTLINE
				elif d == 2:
					c = RIM
				elif y == 3 and x > 8 and x < w - 8:
					c = Color(RIM_HI, 0.94)
				im.set_pixel(x, y, c)
		return im

	static func d_med(tier: int) -> Image:
		var pal: Array = TP[tier - 1]
		var im := img(44, 44)
		for y in 44:
			for x in 44:
				var v := Vector2(x + 0.5 - 22.0, y + 0.5 - 22.0)
				var dd: float = v.length()
				if dd > 21.5:
					continue
				var c: Color
				if dd > 20.5:
					c = OUTLINE
				elif dd > 18.0:
					c = pal[0] if (x < 22 and y < 22 and dd > 19.0 and v.angle() < -1.9) else pal[1]
				elif dd > 17.0:
					c = pal[2]
				elif dd < 14.0:
					c = Color("#21170f")
				else:
					c = Color("#1b120c")
				im.set_pixel(x, y, c)
		return im


## Basit başlık çipi ("simdi" çekimleri için).
class Cap extends Control:
	var text := ""
	var font: Font

	func _draw() -> void:
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x + 28.0
		draw_rect(Rect2(14, 12, w, 46), Color(0, 0, 0, 0.62))
		draw_string(font, Vector2(28, 18 + font.get_ascent(32)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, CREAM)


class Proto extends Control:
	const C_REVEAL := 1.0
	const MOUTH := Vector2(960, 590)
	const CHEST_C := Vector2(960, 620)
	const INV := Vector2(1560, 1010)

	var kind := "A"
	var mode := "level"
	var t := 0.0
	var caption := ""
	var font: Font
	var old_cards: Array = []
	var new_cards: Array = []
	var item: Dictionary = {}
	var reel_stat: Array = []
	var reel_item: Array = []
	var die: Texture2D
	var coin: Texture2D
	var curs: Array = []
	var chest_sheet: Texture2D
	var beam_sheet: Texture2D
	var title_glow: Texture2D
	var bg_tex: Texture2D ## dünya bir kez yakalanır: her karede aynı arka plan (GIF küçük kalsın)
	var _tx: Dictionary = {}
	var _a := 1.0
	var _m := Color.WHITE

	func build() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		position = Vector2.ZERO
		size = Vector2(1920, 1080)
		var cf: Image = Paint.c_front()
		for tier in range(1, 5):
			_tx["A_front_%d" % tier] = _it(Paint.a_front(tier))
			_tx["B_front_%d" % tier] = _it(Paint.b_front(tier))
			_tx["C_front_%d" % tier] = _it(cf)
			_tx["C_gem_%d" % tier] = _it(Paint.c_gem(tier))
			_tx["B_seal_%d" % tier] = _it(Paint.b_seal(tier))
			_tx["D_row_%d" % tier] = _it(Paint.d_row(tier, 280, 50))
			_tx["D_med_%d" % tier] = _it(Paint.d_med(tier))
		_tx["A_back"] = _it(Paint.a_back())
		_tx["B_back"] = _it(Paint.b_back())
		_tx["C_back"] = _it(cf)
		_tx["A_beam"] = _it(Paint.wood(380, 12, [1], 5, 999))
		_tx["A_btn"] = _it(Paint.wood(140, 24, [2, 1], 7, 999))
		_tx["A_btn_s"] = _it(Paint.wood(64, 22, [2, 1], 8, 999))
		_tx["A_btn_m"] = _it(Paint.wood(92, 22, [2, 1], 9, 999))
		_tx["B_btn"] = _it(Paint.b_scroll(140, 24))
		_tx["B_btn_s"] = _it(Paint.b_ribbon(64, 22, ITEM_TIER))
		_tx["B_btn_m"] = _it(Paint.b_scroll(92, 22))
		_tx["C_btn"] = _it(Paint.slate(140, 24, [2, 1], 31))
		_tx["C_btn_s"] = _it(Paint.slate(64, 22, [2, 1], 32))
		_tx["C_btn_m"] = _it(Paint.slate(92, 22, [2, 1], 33))
		_tx["D_btn"] = _it(Paint.d_btn(140, 22))
		_tx["D_btn_s"] = _it(Paint.d_btn(64, 22))
		_tx["D_btn_m"] = _it(Paint.d_btn(92, 22))

	func _it(im: Image) -> ImageTexture:
		return ImageTexture.create_from_image(im)

	# ------------------------------------------------------------ zaman
	static func cl(x: float) -> float:
		return clampf(x, 0.0, 1.0)

	static func ss(x: float) -> float:
		var y: float = cl(x)
		return y * y * (3.0 - 2.0 * y)

	static func eo(x: float) -> float:
		var y: float = cl(x)
		return 1.0 - pow(1.0 - y, 3.0)

	static func ei(x: float) -> float:
		var y: float = cl(x)
		return y * y * y

	static func eob(x: float) -> float:
		var y: float = cl(x)
		var c: float = 1.70158
		return 1.0 + (c + 1.0) * pow(y - 1.0, 3.0) + c * pow(y - 1.0, 2.0)

	static func ca(c: Color, a: float) -> Color:
		return Color(c.r, c.g, c.b, a)

	func rlen() -> float:
		match kind:
			"B":
				return 1.4
			"C":
				return 1.35
			"D":
				return 1.0
		return 1.05

	func t_reroll() -> float:
		return 0.75

	func t_sel() -> float:
		return t_reroll() + rlen() + 0.8

	func level_end() -> float:
		return t_sel() + 1.5

	func clen() -> float:
		match kind:
			"B":
				return 0.95
			"C":
				return 1.3
		return 0.85

	func t_hover_al() -> float:
		return C_REVEAL + clen() + 0.35

	func t_press() -> float:
		return t_hover_al() + 0.55

	func chest_end() -> float:
		return t_press() + 1.0

	func end_time() -> float:
		return level_end() if mode == "level" else chest_end()

	func hover_level(i: int) -> float:
		if i != 1:
			return 0.0
		var tr: float = t_reroll()
		var h: float = ss((t - 0.15) / 0.15) * (1.0 - ss((t - (tr - 0.28)) / 0.12))
		return maxf(h, ss((t - (tr + rlen() + 0.3)) / 0.15))

	# ------------------------------------------------------------ yerleşim
	func card_size() -> Vector2:
		match kind:
			"B":
				return Vector2(288, 444)
			"C":
				return Vector2(312, 420)
		return Vector2(300, 420)

	func level_anchor(i: int) -> Vector2:
		match kind:
			"A":
				return Vector2(960 + (i - 1) * 370, 270) ## levhanın üst ortası (asılma noktası)
			"B":
				return Vector2(960 + (i - 1) * 360, 512)
			"C":
				return Vector2(960 + (i - 1) * 372, 510)
		return Vector2(960, 372 + i * 180)

	func reroll_pos() -> Vector2:
		match kind:
			"B":
				return Vector2(960, 812)
			"D":
				return Vector2(960, 884)
		return Vector2(960, 790)

	func chest_btn_y() -> float:
		match kind:
			"B":
				return 676.0
			"D":
				return 552.0
		return 662.0

	# ------------------------------------------------------------ çizim yardımcıları
	func _col(c: Color) -> Color:
		return Color(c.r * _m.r, c.g * _m.g, c.b * _m.b, c.a * _a)

	func _img_rect(tex: Texture2D, r: Rect2) -> void:
		draw_texture_rect(tex, r, false, _col(Color.WHITE))

	func _img_reg(tex: Texture2D, r: Rect2, src: Rect2) -> void:
		draw_texture_rect_region(tex, r, src, _col(Color.WHITE))

	func _tw(s: String, sz: int) -> float:
		return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x

	func _text_b(s: String, x: float, base: float, sz: int, c: Color, oc: Color, osz: int) -> void:
		var p := Vector2(round(x), round(base))
		if osz > 0 and oc.a > 0.0:
			draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, osz, Color(oc.r, oc.g, oc.b, oc.a * _a))
		draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(c.r, c.g, c.b, c.a * _a))

	## align: 0 orta, -1 sol (x = sol kenar), 1 sağ (x = sağ kenar); y = yazının üstü
	func _text(s: String, x: float, y: float, sz: int, c: Color, align: int = 0, oc: Color = Color(0, 0, 0, 0), osz: int = 0) -> void:
		var w: float = _tw(s, sz)
		var x0: float = x - w * 0.5 if align == 0 else (x if align < 0 else x - w)
		_text_b(s, x0, y + font.get_ascent(sz), sz, c, oc, osz)

	func _parts(parts: Array, cx: float, y: float, sz: int, oc: Color, osz: int) -> void:
		var tw: float = 0.0
		for p: Array in parts:
			tw += _tw(str(p[0]), sz)
		var x: float = cx - tw * 0.5
		for p: Array in parts:
			_text(str(p[0]), x, y, sz, p[1], -1, oc, osz)
			x += _tw(str(p[0]), sz)

	func _value_line(d: Dictionary, cx: float, y: float, vc: Color, bc: Color, oc: Color, osz: int) -> void:
		var v: String = str(d["value"])
		var b: String = str(d["verb"])
		var vw: float = _tw(v, 64)
		var bw: float = _tw(b, 32)
		var x0: float = cx - (vw + 12.0 + bw) * 0.5
		var base: float = y + font.get_ascent(64)
		_text_b(v, x0, base, 64, vc, oc, osz)
		_text_b(b, x0 + vw + 12.0, base, 32, bc, oc, osz)

	func _xf(pos: Vector2, rot: float = 0.0, sc: Vector2 = Vector2.ONE) -> void:
		draw_set_transform(pos, rot, sc)

	func _xr() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _glow(r: Rect2, c: Color, amt: float, steps: int = 4, step: float = 6.0, radius: int = 10) -> void:
		if amt <= 0.01:
			return
		for k in range(steps, 0, -1):
			var sb := StyleBoxFlat.new()
			sb.bg_color = ca(c, minf(1.0, 0.12 * amt) * _a)
			sb.set_corner_radius_all(radius + int(k * step))
			sb.corner_detail = 4
			sb.anti_aliasing = false
			draw_style_box(sb, r.grow(k * step))

	func _glow_circle(c: Vector2, r: float, col: Color, amt: float) -> void:
		if amt <= 0.01:
			return
		for k in range(4, 0, -1):
			draw_circle(c, r + 7.0 * k, ca(col, minf(1.0, 0.12 * amt) * _a))

	func _shadow(r: Rect2, off: Vector2, radius: int, a: float) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, a * _a)
		sb.set_corner_radius_all(radius)
		sb.anti_aliasing = false
		draw_style_box(sb, Rect2(r.position + off, r.size))

	func _sparks(center: Vector2, q: float, col: Color, n: int, r0: float, r1: float, sd: int) -> void:
		if q <= 0.0 or q >= 1.0:
			return
		for k in n:
			var ang: float = TAU * k / n + Paint.hsh(k, 0, sd) * 0.6
			var sp: float = lerpf(0.55, 1.0, Paint.hsh(k, 1, sd))
			var p: Vector2 = center + Vector2(cos(ang), sin(ang)) * lerpf(r0, r1, eo(q) * sp)
			var sz: float = 6.0 if Paint.hsh(k, 2, sd) < 0.5 else 3.0
			draw_rect(Rect2(round(p.x / 3.0) * 3.0, round(p.y / 3.0) * 3.0, sz, sz), ca(col, (1.0 - q) * _a))

	func _column(x: float, y_bot: float, y_top: float, w: float, col: Color, a: float) -> void:
		var hg: float = y_bot - y_top
		if hg <= 1.0 or a <= 0.01:
			return
		var widths := [1.0, 0.62, 0.3]
		var alphas := [0.10, 0.16, 0.32]
		for sgi in 8:
			var y0: float = y_top + hg * sgi / 8.0
			var y1: float = y_top + hg * (sgi + 1) / 8.0
			var fa: float = float(sgi + 1) / 8.0
			for k in 3:
				var ww: float = round(w * float(widths[k]) / 6.0) * 6.0
				draw_rect(Rect2(round(x - ww * 0.5), round(y0), ww, round(y1) - round(y0)), ca(col, float(alphas[k]) * fa * a))

	func _coin(r: Rect2) -> void:
		_img_reg(coin, r, Rect2(0, 0, 16, 16))

	func _die(c: Vector2, rot: float) -> void:
		_xf(c, rot)
		draw_texture_rect(die, Rect2(-16.5, -16.5, 33, 33), false, _col(Color.WHITE))
		_xr()

	## parts: ["die"] / ["coin"] / ["t", yazı, renk, kontur]
	func _button(key: String, center: Vector2, hover: float, press: float, parts: Array, die_r: float = 0.0) -> void:
		var tex: Texture2D = _tx[key]
		var sz := Vector2(tex.get_width(), tex.get_height()) * 3.0
		var off := Vector2(0, -3.0 * hover + 4.0 * press)
		var r := Rect2(center - sz * 0.5 + off, sz)
		if press < 0.5:
			_shadow(Rect2(r.position, r.size), Vector2(0, 6), 8, 0.3)
		var k: float = 1.0 + 0.14 * hover - 0.12 * press
		_m = Color(k, k, k)
		_img_rect(tex, r)
		_m = Color.WHITE
		var tw: float = 0.0
		for p: Array in parts:
			match str(p[0]):
				"die":
					tw += 33.0 + 12.0
				"coin":
					tw += 32.0 + 6.0
				_:
					tw += _tw(str(p[1]), 32) + 10.0
		tw -= 10.0
		var x: float = r.get_center().x - tw * 0.5
		var cy: float = r.get_center().y
		for p: Array in parts:
			match str(p[0]):
				"die":
					_die(Vector2(x + 16.5, cy), die_r)
					x += 45.0
				"coin":
					_coin(Rect2(round(x), round(cy - 16.0), 32, 32))
					x += 38.0
				_:
					var s: String = str(p[1])
					_text(s, x, cy - 19.0, 32, p[2], -1, p[3], 4)
					x += _tw(s, 32) + 10.0

	# ------------------------------------------------------------ ana çizim
	func _draw() -> void:
		_a = 1.0
		_m = Color.WHITE
		if bg_tex:
			draw_texture_rect(bg_tex, Rect2(0, 0, 1920, 1080), false)
		_bg()
		if mode == "level":
			_draw_level()
		else:
			_draw_chest()
		_xr()
		_a = 1.0
		_m = Color.WHITE
		var cs: Array = _cursor_level() if mode == "level" else _cursor_chest()
		var ct: Texture2D = curs[int(cs[1])]
		var cp: Vector2 = cs[0]
		draw_texture_rect(ct, Rect2(round(cp.x) - 2.0, round(cp.y) - 2.0, 38, 50), false)
		if caption != "":
			var w: float = _tw(caption, 32) + 28.0
			draw_rect(Rect2(14, 12, w, 46), Color(0, 0, 0, 0.62))
			_text(caption, 28, 18, 32, CREAM, -1)

	func _bg() -> void:
		var base := Color(0.08, 0.05, 0.03, 0.5)
		var edge := Color(0.05, 0.03, 0.02, 0.07)
		match kind:
			"B":
				base = Color(0.10, 0.05, 0.03, 0.52)
				edge = Color(0.06, 0.025, 0.015, 0.08)
			"C":
				base = Color(0.05, 0.05, 0.10, 0.62)
				edge = Color(0.03, 0.03, 0.07, 0.07)
			"D":
				base = Color(0.06, 0.04, 0.02, 0.5)
		draw_rect(Rect2(0, 0, 1920, 1080), base)
		for k in 6:
			var th: float = 60.0 * (k + 1)
			draw_rect(Rect2(0, 0, 1920, th * 0.6), edge)
			draw_rect(Rect2(0, 1080 - th * 0.6, 1920, th * 0.6), edge)
			draw_rect(Rect2(0, 0, th, 1080), edge)
			draw_rect(Rect2(1920 - th, 0, th, 1080), edge)
		if kind == "B":
			for k in 5:
				draw_circle(Vector2(960, 520), 560.0 - k * 90.0, Color(1.0, 0.62, 0.3, 0.025))
		elif kind == "C":
			for k in 5:
				draw_circle(Vector2(960, 520), 560.0 - k * 90.0, Color(0.55, 0.5, 1.0, 0.02))

	func _title(main: String, sub: String, sub_a: float, coin_sub: bool) -> void:
		_a = 1.0
		_m = Color.WHITE
		var y: float = 52.0
		var col: Color = H_TEXT
		var oc: Color = OUTLINE
		var sc: Color = H_DIM
		match kind:
			"B":
				y = 66.0
				col = CREAM
				oc = INK
				sc = Color("#e8c890")
			"C":
				y = 80.0
				col = S_ACCENT
				oc = S_OUT
				sc = S_DIM
			"D":
				y = 56.0
				col = CREAM
				oc = INK
				sc = Color("#e6d2b0")
		if kind == "D" and title_glow:
			_img_rect(title_glow, Rect2(960 - 336, y - 16, 672, 96))
		_text(main, 960, y, 64, col, 0, oc, 6)
		_a = sub_a
		if sub_a > 0.01:
			if coin_sub:
				var pc: Color = INK_GOLD.lerp(H_PRICE, 0.6) if kind == "B" else (S_PRICE if kind == "C" else H_PRICE)
				var sw: float = _tw(sub, 32)
				var pop: float = 1.0 + 0.25 * sin(cl((sub_a - 0.0) * 1.0) * PI) * (1.0 - sub_a)
				var x0: float = 960.0 - (32.0 + 8.0 + sw) * 0.5
				_coin(Rect2(round(x0), round(y + 74 - 4 * pop), 32 * pop, 32 * pop))
				_text(sub, x0 + 40.0, y + 72, 32, pc, -1, oc, 4)
			else:
				_text(sub, 960, y + 72, 32, sc, 0, oc, 4)
		_a = 1.0
		if kind == "B":
			for k in range(-6, 7):
				if k == 0:
					continue
				var cxp: float = 960.0 + k * 27.0
				var r: float = 5.0 if absi(k) % 2 == 1 else 3.0
				draw_colored_polygon(PackedVector2Array([Vector2(cxp, y + 116 - r), Vector2(cxp + r, y + 116), Vector2(cxp, y + 116 + r),
						Vector2(cxp - r, y + 116)]), Color("#c8964a"))

	# ------------------------------------------------------------ LEVEL
	func _blank(i: int) -> Dictionary:
		return {"i": i, "c": Vector2.ZERO, "rot": 0.0, "sx": 1.0, "sy": 1.0, "sc": 1.0, "a": 1.0, "face": "front",
			"data": {}, "hover": 0.0, "glow": 0.0, "flash": 0.0, "z": 5.0 if i == 1 else float(i), "ropes": 1.0, "lift": 0.0}

	func _draw_level() -> void:
		_title("SEVİYE ATLADIN!", "Seviye 12  ·  17 sn", 1.0, false)
		var sts: Array = []
		for i in 3:
			match kind:
				"A":
					sts.append(_st_A(i))
				"B":
					sts.append(_st_B(i))
				"C":
					sts.append(_st_C(i))
				_:
					sts.append(_st_D(i))
		if kind == "A":
			_img_rect(_tx["A_beam"], Rect2(960 - 570, 196, 1140, 36))
			for st: Dictionary in sts:
				_ropes(st)
		var order: Array = sts.duplicate()
		order.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["z"]) < float(q["z"]))
		for st: Dictionary in order:
			if kind == "D":
				_row(st)
			else:
				_card(st)
		_reroll_button()
		_fx_level(sts[1])

	func _st_A(i: int) -> Dictionary:
		var st := _blank(i)
		var top: Vector2 = level_anchor(i)
		var h: float = hover_level(i)
		var rot: float = 0.012 * sin(t * 1.7 + i * 1.3)
		var lift: float = 10.0 * h
		st["hover"] = h
		st["glow"] = h
		st["sc"] = 1.0 + 0.03 * h
		st["data"] = old_cards[i]
		var rt: float = t - t_reroll() - i * 0.12
		if rt >= 0.0:
			var p: float = ss(rt / 0.75)
			var ang: float = p * TAU
			st["sx"] = cos(ang)
			if ang >= PI * 1.5:
				st["data"] = new_cards[i]
			elif ang >= PI * 0.5:
				st["face"] = "back"
			lift += 26.0 * sin(p * PI)
			if rt > 0.75:
				rot += 0.07 * exp(-5.0 * (rt - 0.75)) * sin(13.0 * (rt - 0.75))
		var s: float = t - t_sel()
		if s >= 0.0:
			if i == 1:
				st["sy"] = 1.0 - 0.05 * sin(cl(s / 0.15) * PI)
				st["glow"] = 1.0 + 0.8 * sin(cl(s / 0.5) * PI)
				st["flash"] = sin(cl((s - 0.05) / 0.3) * PI)
				lift += 600.0 * ei((s - 0.4) / 0.6)
				st["a"] = 1.0 - cl((s - 0.75) / 0.3)
			else:
				var f: float = s - 0.12
				if f > 0.0:
					top.y += 1300.0 * f * f
					rot += (i - 1) * 1.2 * f
					st["a"] = 1.0 - cl(f / 0.55)
					st["ropes"] = 0.0
		top.y -= lift
		st["c"] = top
		st["rot"] = rot
		st["lift"] = lift
		return st

	func _ropes(st: Dictionary) -> void:
		var ra: float = float(st["ropes"]) * float(st["a"])
		if ra <= 0.01:
			return
		var top: Vector2 = st["c"]
		var rest_x: float = level_anchor(int(st["i"])).x
		var sxv: float = float(st["sx"]) * float(st["sc"])
		for side: float in [-1.0, 1.0]:
			var anchor := Vector2(rest_x + side * 108.0, 228.0)
			var att: Vector2 = top + Vector2(side * 108.0 * sxv, 6.0).rotated(float(st["rot"]))
			if att.y <= anchor.y + 3.0:
				continue
			var n: int = int(anchor.distance_to(att) / 3.0)
			for k in n + 1:
				var p: Vector2 = anchor.lerp(att, float(k) / maxf(1.0, n))
				var c: Color = Color("#c9a46a") if (k / 2) % 2 == 0 else Color("#8a6a3a")
				draw_rect(Rect2(round(p.x) - 1.5, round(p.y) - 1.5, 3, 3), ca(c, ra))

	func _st_B(i: int) -> Dictionary:
		var st := _blank(i)
		var base: Vector2 = level_anchor(i)
		var fan_rot: float = (i - 1) * 0.05
		var rest: Vector2 = base + Vector2(0, absf(i - 1) * 16.0)
		var h: float = hover_level(i)
		var c: Vector2 = rest + Vector2(0, -26.0 * h)
		var rot: float = fan_rot * (1.0 - h)
		st["hover"] = h
		st["glow"] = h
		st["sc"] = 1.0 + 0.05 * h
		st["lift"] = 26.0 * h
		st["data"] = old_cards[i]
		var rt: float = t - t_reroll()
		var stack := Vector2(960 + (i - 1) * 5, 500 - (i - 1) * 5)
		if rt >= 0.0:
			if rt < 0.3:
				var p: float = cl((rt - i * 0.06) / 0.22)
				st["sx"] = cos(p * PI)
				if p >= 0.5:
					st["face"] = "back"
			elif rt < 0.9:
				st["face"] = "back"
				var g: float = ss((rt - 0.3) / 0.25)
				c = rest.lerp(stack, g)
				rot = lerpf(fan_rot, 0.0, g)
				var q: float = cl((rt - 0.55) / 0.35)
				if q > 0.0 and q < 1.0:
					var dirs := [-1.0, 1.0, 0.0]
					var dv: float = float(dirs[i])
					c.x += dv * 130.0 * sin(q * TAU)
					c.y -= absf(sin(q * TAU)) * 14.0 * absf(dv)
					st["z"] = float(i) + 3.0 * sin(q * TAU) * dv
			else:
				st["face"] = "back"
				var dl: float = eo((rt - 0.9 - i * 0.05) / 0.22)
				c = stack.lerp(rest, dl)
				rot = lerpf(0.0, fan_rot, dl)
				var p2: float = cl((rt - 1.12 - i * 0.06) / 0.22)
				if p2 > 0.0:
					st["sx"] = cos(p2 * PI)
					if p2 >= 0.5:
						st["face"] = "front"
						st["data"] = new_cards[i]
		var s: float = t - t_sel()
		if s >= 0.0:
			if i == 1:
				var l2: float = 40.0 * ss(s / 0.2)
				c.y -= l2
				st["lift"] = float(st["lift"]) + l2
				st["sc"] = float(st["sc"]) + 0.04 * ss(s / 0.2)
				st["seal"] = cl((s - 0.15) / 0.18)
				st["glow"] = 1.0 + 0.6 * sin(cl((s - 0.15) / 0.5) * PI)
				st["flash"] = 0.7 * sin(cl((s - 0.15) / 0.25) * PI)
				var f: float = ei((s - 0.65) / 0.45)
				c = c.lerp(Vector2(960, 1040), f)
				st["sc"] = float(st["sc"]) * (1.0 - 0.75 * f)
				st["a"] = 1.0 - cl((s - 0.85) / 0.25)
			else:
				var p: float = cl((s - 0.1) / 0.2)
				st["sx"] = cos(p * PI)
				if p >= 0.5:
					st["face"] = "back"
				var f: float = ei((s - 0.35) / 0.5)
				c.y += 520.0 * f
				st["a"] = 1.0 - f
		st["c"] = c
		st["rot"] = rot
		return st

	func _st_C(i: int) -> Dictionary:
		var st := _blank(i)
		var c: Vector2 = level_anchor(i)
		var h: float = hover_level(i)
		st["hover"] = h
		st["glow"] = h
		c.y -= 8.0 * h
		st["data"] = old_cards[i]
		var rt: float = t - t_reroll()
		if rt >= 0.0:
			var stop: float = 0.55 + i * 0.28
			if rt < stop:
				st["spin"] = rt
				st["spin_icons"] = reel_stat
				st["gem_cycle"] = (int(rt * 14.0) + i) % 4
				c.y -= 2.0 * sin(rt * 40.0)
			else:
				st["data"] = new_cards[i]
				var since: float = rt - stop
				c.y += 8.0 * sin(cl(since / 0.14) * PI)
				st["gems"] = mini(int((new_cards[i] as Dictionary)["tier"]), 1 + int(since / 0.06))
				st["dust"] = since
		var s: float = t - t_sel()
		if s >= 0.0:
			if i == 1:
				st["ignite"] = s
				c.y -= 6.0 * ss(s / 0.2)
				st["glow"] = 1.0 + 0.6 * sin(cl(s / 0.5) * PI)
				st["flash"] = 0.6 * sin(cl((s - 0.1) / 0.35) * PI)
				st["a"] = 1.0 - cl((s - 0.55) / 0.3)
			else:
				st["dark"] = 0.6 * ss(s / 0.3)
				c.y += 30.0 * ss((s - 0.1) / 0.4)
				st["a"] = 1.0 - cl((s - 0.5) / 0.4)
		st["c"] = c
		return st

	func _st_D(i: int) -> Dictionary:
		var st := _blank(i)
		var c0: Vector2 = level_anchor(i)
		var c: Vector2 = c0
		var h: float = hover_level(i)
		st["hover"] = h
		st["glow"] = h
		st["data"] = old_cards[i]
		var rt: float = t - t_reroll()
		if rt >= 0.0:
			var tin: float = 0.42 + i * 0.09
			if rt < tin:
				var po: float = ei((rt - i * 0.07) / 0.28)
				c.x -= 1100.0 * po
				st["a"] = 1.0 - po
			else:
				st["data"] = new_cards[i]
				c.x += 1100.0 * (1.0 - eob((rt - tin) / 0.38))
				st["a"] = cl((rt - tin) / 0.2)
		var s: float = t - t_sel()
		if s >= 0.0:
			if i == 1:
				st["column"] = cl((s - 0.12) / 0.35)
				st["column_a"] = 1.0 - cl((s - 0.85) / 0.3)
				st["sy"] = 1.0 + 0.08 * ss(s / 0.2) - 0.06 * sin(cl(s / 0.12) * PI)
				st["glow"] = 1.0 + 0.5 * sin(cl(s / 0.6) * PI)
				st["flash"] = sin(cl((s - 0.05) / 0.3) * PI)
				var q: float = ei((s - 0.6) / 0.35)
				st["sx"] = 1.0 - 0.97 * q
				c.x = c0.x - 340.0 + 340.0 * float(st["sx"])
				st["text_a"] = 1.0 - cl((s - 0.55) / 0.15)
				st["med_fly"] = ei((s - 0.85) / 0.4)
				st["med_to"] = Vector2(c0.x - 340.0, -60.0)
				st["a"] = 1.0 - cl((s - 1.05) / 0.2)
			else:
				var dirx: float = -1.0 if i == 0 else 1.0
				c.x += dirx * 1000.0 * ei((s - 0.08) / 0.4)
				st["a"] = float(st["a"]) * (1.0 - cl((s - 0.08) / 0.35))
		st["c"] = c
		return st

	func _reroll_button() -> void:
		var a: float = 1.0 - cl((t - t_sel()) / 0.3)
		if a <= 0.01:
			return
		_a = a
		var tc: Color = H_TEXT
		var oc: Color = OUTLINE
		var pc: Color = H_PRICE
		match kind:
			"B":
				tc = INK
				oc = Color(0, 0, 0, 0)
				pc = INK_GOLD
			"C":
				tc = S_TEXT
				oc = S_OUT
				pc = S_PRICE
		var tr: float = t_reroll()
		var hov: float = ss((t - (tr - 0.1)) / 0.08) * (1.0 - ss((t - (tr + rlen() + 0.15)) / 0.1))
		var prs: float = 1.0 if t >= tr and t < tr + 0.12 else 0.0
		var q: float = t - tr
		var dr: float = 0.0 if q < 0.0 else eo(q / 0.6) * TAU * 2.0
		_button("%s_btn" % kind, reroll_pos(), hov, prs, [["die"], ["t", "Karıştır", tc, oc], ["coin"], ["t", "6", pc, oc]], dr)
		_a = 1.0

	func _cursor_level() -> Array:
		var card_p: Vector2 = level_anchor(1) + (Vector2(0, 210) if kind == "A" else Vector2.ZERO) + Vector2(46, 70)
		var btn_p: Vector2 = reroll_pos() + Vector2(168, 20)
		var start := Vector2(1320, 940)
		var tr: float = t_reroll()
		var te: float = tr + rlen()
		var p: Vector2
		if t < tr - 0.3:
			p = start.lerp(card_p, ss(t / 0.2))
		elif t < te + 0.15:
			p = card_p.lerp(btn_p, ss((t - (tr - 0.3)) / 0.2))
		else:
			p = btn_p.lerp(card_p, ss((t - (te + 0.15)) / 0.2))
		var stt: int = 0
		if (t >= 0.2 and t < tr - 0.3) or (t >= tr - 0.12 and t < te + 0.15) or t >= te + 0.33:
			stt = 1
		var ts: float = t_sel()
		if (t >= tr and t < tr + 0.12) or (t >= ts and t < ts + 0.12):
			stt = 2
		return [p, stt]

	func _fx_level(ch: Dictionary) -> void:
		var s: float = t - t_sel()
		if s < 0.0:
			return
		var d: Dictionary = ch["data"]
		var col: Color = TP[int(d.get("tier", 1)) - 1][0]
		var c: Vector2 = ch["c"]
		_a = 1.0
		match kind:
			"A":
				_sparks(c + Vector2(0, 210), cl((s - 0.05) / 0.6), col, 22, 120, 380, 13)
			"B":
				_sparks(c + Vector2(0, 170), cl((s - 0.3) / 0.45), col, 14, 40, 170, 17)
			"C":
				_c_ignite(c + Vector2(0, -60), s, col)

	func _c_ignite(center: Vector2, s: float, col: Color) -> void:
		for k in 3:
			var q: float = cl((s - k * 0.12) / 0.55)
			if q > 0.0 and q < 1.0:
				draw_arc(center, 85.0 + 230.0 * eo(q), 0.0, TAU, 48, ca(col, (1.0 - q) * 0.9), 6.0, false)
		var cq: float = cl((s - 0.18) / 0.3)
		var cf: float = 1.0 - cl((s - 0.55) / 0.2)
		if cq > 0.0 and cf > 0.0:
			for k in 6:
				var ang: float = k * TAU / 6.0 + 0.3
				var dv := Vector2(cos(ang), sin(ang))
				draw_line(center + dv * 40.0, center + dv * (40.0 + 160.0 * eo(cq)), ca(col, 0.85 * cf), 6.0)
		var oq: float = cl((s - 0.5) / 0.55)
		if oq > 0.0 and oq < 1.0:
			var p: Vector2 = center.lerp(Vector2(960, 150), ei(oq))
			var r: float = lerpf(26.0, 8.0, cl((oq - 0.5) / 0.5))
			for g in 3:
				draw_circle(p, r + 10.0 * (3 - g), ca(col, 0.15))
			draw_circle(p, r, col)
			draw_circle(p, r * 0.5, Color(1, 1, 1, 0.9))

	# ------------------------------------------------------------ kart (A/B/C)
	func _card(st: Dictionary) -> void:
		var a: float = st["a"]
		if a <= 0.01:
			return
		var sz: Vector2 = card_size()
		var d: Dictionary = st["data"]
		var tier: int = int(d.get("tier", 1))
		var r := Rect2(-sz.x * 0.5, 0.0 if kind == "A" else -sz.y * 0.5, sz.x, sz.y)
		var sxa: float = maxf(absf(float(st["sx"])), 0.002)
		var sc: float = st["sc"]
		_a = a
		_m = Color.WHITE
		_xf(st["c"], float(st["rot"]), Vector2(sxa * sc, float(st["sy"]) * sc))
		_shadow(r, Vector2(8, 10 + float(st["lift"]) * 0.35), 10, 0.32)
		var front: bool = st["face"] == "front"
		if front:
			_glow(r, TP[tier - 1][0], float(st["glow"]))
		var k: float = 1.0 + 0.1 * float(st["hover"])
		_m = Color(k, k, k)
		_img_rect(_tx["%s_front_%d" % [kind, tier]] if front else _tx["%s_back" % kind], r)
		_m = Color.WHITE
		if front:
			match kind:
				"A":
					_face_A(r, d)
				"B":
					_face_B(r, d, st)
				"C":
					_face_C(r, d, st)
		var fl: float = st.get("flash", 0.0)
		if fl > 0.01:
			draw_rect(r.grow(-6.0), Color(1, 1, 1, 0.32 * fl * a))
		var dk: float = st.get("dark", 0.0)
		if dk > 0.01:
			draw_rect(r, Color(0.02, 0.02, 0.05, dk * a))
		_xr()

	func _face_A(r: Rect2, d: Dictionary) -> void:
		var cx: float = r.get_center().x
		var y0: float = r.position.y
		var tier: int = int(d["tier"])
		_text(str(TIER_UPPER[tier - 1]), cx, y0 + 21, 32, CREAM, 0, OUTLINE, 4)
		var item_mode: bool = d.has("lines")
		var isz: float = 128.0 if item_mode else 144.0
		_img_rect(d["icon"], Rect2(cx - isz * 0.5, y0 + 153 - isz * 0.5, isz, isz))
		_text(str(d["title"]), cx, y0 + 254, 48, H_TEXT, 0, OUTLINE, 4)
		if item_mode:
			var lines: Array = d["lines"]
			for k in lines.size():
				_text(str(lines[k]), cx, y0 + 304 + 32 * k, 32, H_PRICE, 0, OUTLINE, 4)
			_text(str(d["kademe"]), cx, y0 + 368, 32, H_DIM, 0, OUTLINE, 4)
		else:
			_value_line(d, cx, y0 + 294, H_PRICE, H_DIM, OUTLINE, 4)
			_parts(_cat_parts(d, CAT_LIGHT, H_DIM), cx, y0 + 362, 32, OUTLINE, 4)

	func _cat_parts(d: Dictionary, cats: Dictionary, dim: Color) -> Array:
		var parts: Array = [[str(d["cat"]), cats.get(str(d["cat"]), dim)]]
		if int(d.get("count", 0)) > 0:
			parts.append(["  ·  %dx alındı" % int(d["count"]), dim])
		return parts

	func _face_B(r: Rect2, d: Dictionary, st: Dictionary) -> void:
		var cx: float = r.get_center().x
		var y0: float = r.position.y
		var tier: int = int(d["tier"])
		_text(str(TIER_UPPER[tier - 1]), cx, y0 + 182, 32, CREAM, 0, INK, 4)
		var item_mode: bool = d.has("lines")
		var isz: float = 128.0 if item_mode else 144.0
		_img_rect(d["icon"], Rect2(cx - isz * 0.5, y0 + 112 - isz * 0.5, isz, isz))
		_text(str(d["title"]), cx, y0 + 228, 48, INK)
		if item_mode:
			var lines: Array = d["lines"]
			for k in lines.size():
				_text(str(lines[k]), cx, y0 + 284 + 34 * k, 32, INK_GOLD)
			_text(str(d["kademe"]), cx, y0 + 384, 32, INK_DIM)
		else:
			_value_line(d, cx, y0 + 274, INK_GOLD, INK_DIM, Color(0, 0, 0, 0), 0)
			_parts(_cat_parts(d, CAT_INK, INK_DIM), cx, y0 + 356, 32, Color(0, 0, 0, 0), 0)
		var seal: float = st.get("seal", 0.0)
		if seal > 0.0:
			var ss_: float = lerpf(2.2, 1.0, eo(seal))
			var sp := Vector2(cx, y0 + r.size.y - 60.0)
			var a0: float = _a
			_a = a0 * seal
			_img_rect(_tx["B_seal_%d" % tier], Rect2(sp - Vector2(48, 48) * ss_, Vector2(96, 96) * ss_))
			_a = a0

	func _face_C(r: Rect2, d: Dictionary, st: Dictionary) -> void:
		var cx: float = r.get_center().x
		var y0: float = r.position.y
		var tier: int = int(d.get("tier", 1))
		var spin: bool = st.has("spin")
		var cyc: int = int(st.get("gem_cycle", -1))
		var lit: int = int(st.get("gems", tier))
		for k in 4:
			var gp := Vector2(cx - 54.0 + 36.0 * k, y0 + 28.0)
			var on: bool = (k == cyc) if cyc >= 0 else (k < lit)
			if on:
				var gt: int = 4 if cyc >= 0 else tier
				_glow_circle(gp, 6.0, TP[gt - 1][0], 1.2)
				_img_rect(_tx["C_gem_%d" % gt], Rect2(gp - Vector2(10.5, 10.5), Vector2(21, 21)))
		var ic := Vector2(cx, y0 + 150.0)
		var hv: float = st["hover"]
		var inten: float = 0.42 + 0.08 * sin(t * 2.0 + float(st["i"])) + 0.58 * hv
		if spin:
			inten = 0.6 + 0.3 * sin(t * 30.0)
		if st.has("ignite"):
			inten = 1.0
		var rune_col: Color = TP[3][0] if spin else TP[tier - 1][0]
		_glow_circle(ic, 60.0, rune_col, 0.35 + 0.65 * hv)
		_runes(ic, 87.0, rune_col, inten, t * (0.35 + 0.5 * hv) + float(st["i"]))
		if spin:
			_reel(ic, float(st["spin"]) + float(st["i"]) * 0.37, st["spin_icons"])
			_text("· · ·", cx, y0 + 296, 48, S_DIM, 0, S_OUT, 4)
		else:
			var item_mode: bool = d.has("lines")
			var isz: float = 128.0 if item_mode else 144.0
			_img_rect(d["icon"], Rect2(ic.x - isz * 0.5, ic.y - isz * 0.5, isz, isz))
			if item_mode:
				_text(str(d["kademe"]).to_upper(), cx, y0 + 243, 32, S_DIM, 0, S_OUT, 4)
				_text(str(d["title"]), cx, y0 + 280, 48, S_TEXT, 0, S_OUT, 4)
				var lines: Array = d["lines"]
				for k in lines.size():
					_text(str(lines[k]), cx, y0 + 326 + 30 * k, 32, S_PRICE, 0, S_OUT, 4)
			else:
				var parts: Array = [[str(d["cat"]).to_upper(), CAT_LIGHT.get(str(d["cat"]), S_DIM)]]
				if int(d.get("count", 0)) > 0:
					parts.append(["  ·  %dx" % int(d["count"]), S_DIM])
				_parts(parts, cx, y0 + 243, 32, S_OUT, 4)
				_text(str(d["title"]), cx, y0 + 280, 48, S_TEXT, 0, S_OUT, 4)
				_value_line(d, cx, y0 + 318, S_PRICE, S_DIM, S_OUT, 4)
		var dust: float = st.get("dust", -1.0)
		if dust >= 0.0 and dust < 0.4:
			var q: float = dust / 0.4
			for k in 10:
				var side: float = -1.0 if k % 2 == 0 else 1.0
				var px_: float = cx + side * (110.0 + 70.0 * q * Paint.hsh(k, 5, 3))
				var py_: float = r.end.y - 6.0 - 30.0 * q * Paint.hsh(k, 6, 3) + 30.0 * q * q
				draw_rect(Rect2(round(px_ / 3.0) * 3.0, round(py_ / 3.0) * 3.0, 6, 6), Color(0.42, 0.42, 0.55, (1.0 - q) * _a))

	func _runes(center: Vector2, rad: float, col: Color, inten: float, ang0: float) -> void:
		for k in 10:
			var ang: float = ang0 + k * TAU / 10.0
			var p: Vector2 = center + Vector2(cos(ang), sin(ang)) * rad
			var pat: Array = RUNES[k % 4]
			for yy in 5:
				var row: String = pat[yy]
				for xx in 5:
					if row[xx] == "#":
						draw_rect(Rect2(round(p.x) - 7.5 + xx * 3, round(p.y) - 7.5 + yy * 3, 3, 3), ca(col, clampf(inten, 0.0, 1.0) * _a))

	func _reel(center: Vector2, rt: float, icons: Array) -> void:
		var spd: float = 13.0
		var gap: float = 0.95
		var a0: float = fmod(rt * spd, gap)
		var base: int = int(rt * spd / gap)
		for k in range(-2, 3):
			var ang: float = a0 + k * gap
			if absf(ang) >= PI * 0.5:
				continue
			var yy: float = 64.0 * sin(ang)
			var hs: float = cos(ang)
			var tex: Texture2D = icons[posmod(base - k, icons.size())]
			var isz: float = 128.0
			draw_texture_rect(tex, Rect2(center.x - isz * 0.5, center.y + yy - isz * hs * 0.5, isz, isz * hs), false,
					Color(1, 1, 1, pow(hs, 1.5) * _a))

	# ------------------------------------------------------------ satır (D)
	func _row(st: Dictionary) -> void:
		var a: float = st["a"]
		if a <= 0.01:
			return
		var d: Dictionary = st["data"]
		var tier: int = int(d.get("tier", 1))
		var pal: Array = TP[tier - 1]
		var hv: float = st["hover"]
		var c: Vector2 = st["c"] + Vector2(14.0 * hv, 0)
		var w: float = 840.0
		var h: float = 150.0
		var sxs: float = maxf(float(st["sx"]) * float(st["sc"]), 0.002)
		var sys: float = float(st["sy"]) * float(st["sc"])
		var med: Vector2 = c + Vector2((-w * 0.5 + 80.0) * sxs, 0)
		var col: float = st.get("column", 0.0)
		_a = a
		if col > 0.0:
			_column(med.x, med.y, lerpf(med.y, -40.0, eo(col)), 132.0, pal[0], float(st.get("column_a", 1.0)) * a)
		_xf(c, 0.0, Vector2(sxs, sys))
		var r := Rect2(-w * 0.5, -h * 0.5, w, h)
		_shadow(r, Vector2(0, 9), 26, 0.3)
		_glow(r, pal[0], float(st["glow"]), 4, 6.0, 26)
		var k: float = 1.0 + 0.1 * hv
		_m = Color(k, k, k)
		_img_rect(_tx["D_row_%d" % tier], r)
		_m = Color.WHITE
		var shm: float = fmod(t * 0.45 + float(st["i"]) * 0.37, 1.0)
		if shm < 0.5:
			draw_rect(Rect2(r.position.x + 6.0 + shm * 2.0 * 400.0, r.position.y + 6.0, 18, h - 12.0), ca(pal[0], 0.1 * a * (1.0 - shm * 2.0)))
		var ta: float = st.get("text_a", 1.0)
		_a = a * ta
		var item_mode: bool = d.has("lines")
		var tx: float = r.position.x + 172.0
		_text(str(d["title"]), tx, -58, 48, H_TEXT, -1, OUTLINE, 4)
		if item_mode:
			_parts([[str(TIER_NAMES[tier - 1]), TIER_TEXT[tier - 1]], ["  ·  " + str(d["kademe"]), H_DIM]],
					tx + (_tw(str(TIER_NAMES[tier - 1]) + "  ·  " + str(d["kademe"]), 32)) * 0.5, 4, 32, OUTLINE, 4)
			var lines: Array = d["lines"]
			for kk in lines.size():
				_text(str(lines[kk]), r.end.x - 36.0, -46.0 + 38.0 * kk, 32, H_PRICE, 1, OUTLINE, 4)
		else:
			var parts: Array = [[str(TIER_NAMES[tier - 1]), TIER_TEXT[tier - 1]], ["  ·  ", H_DIM], [str(d["cat"]), CAT_LIGHT.get(str(d["cat"]), H_DIM)]]
			if int(d.get("count", 0)) > 0:
				parts.append(["  ·  %dx alındı" % int(d["count"]), H_DIM])
			var pw: float = 0.0
			for p: Array in parts:
				pw += _tw(str(p[0]), 32)
			_parts(parts, tx + pw * 0.5, 4, 32, OUTLINE, 4)
			_text(str(d["value"]), r.end.x - 36.0, -56, 64, H_PRICE, 1, OUTLINE, 4)
			_text(str(d["verb"]), r.end.x - 36.0, 18, 32, H_DIM, 1, OUTLINE, 4)
		_a = a
		var fl: float = st.get("flash", 0.0)
		if fl > 0.01:
			draw_rect(r.grow(-6.0), Color(1, 1, 1, 0.25 * fl * a))
		_xr()
		var ms: float = st.get("med", 1.0)
		var mf: float = st.get("med_fly", 0.0)
		if ms > 0.01:
			var mp: Vector2 = med.lerp(st.get("med_to", INV), mf)
			var msz: float = 132.0 * ms * float(st["sc"]) * (1.0 - 0.8 * mf)
			_a = a
			_glow_circle(mp, msz * 0.5, pal[0], float(st["glow"]))
			_img_rect(_tx["D_med_%d" % tier], Rect2(mp - Vector2(msz, msz) * 0.5, Vector2(msz, msz)))
			var isz: float = 96.0 * ms * float(st["sc"]) * (1.0 - 0.8 * mf)
			_img_rect(d["icon"], Rect2(mp - Vector2(isz, isz) * 0.5, Vector2(isz, isz)))
		_a = 1.0

	# ------------------------------------------------------------ SANDIK
	func _draw_chest() -> void:
		var ga: float = cl((t - 0.85) / 0.15)
		_title("EŞYA SANDIĞI", "+%d Altın" % CHEST_GOLD, ga, true)
		_chest_sprite()
		var st: Dictionary = _chest_state()
		var rs: float = t - C_REVEAL
		var s: float = t - t_press()
		if kind == "D" and rs > 0.0:
			var pa: float = (1.0 - 0.55 * cl((rs - clen()) / 0.4)) * (1.0 - cl(s / 0.3))
			_column(960, MOUTH.y, lerpf(MOUTH.y, -40.0, eo(rs / 0.25)), 168.0, TP[ITEM_TIER - 1][0], pa)
		if kind == "D":
			_row(st)
		else:
			_card(st)
		_chest_buttons()
		_a = 1.0
		var col: Color = TP[ITEM_TIER - 1][0]
		match kind:
			"A":
				_sparks(Vector2(960, 400), cl((rs - 0.5) / 0.45), col, 14, 100, 300, 3)
			"B":
				_sparks(Vector2(960, 400), cl((rs - 0.62) / 0.45), col, 16, 80, 280, 9)
			"C":
				var q: float = cl((rs - 0.95) / 0.5)
				if q > 0.0 and q < 1.0:
					draw_arc(Vector2(960, 340), 85.0 + 220.0 * eo(q), 0.0, TAU, 48, ca(col, (1.0 - q) * 0.9), 6.0, false)

	func _chest_sprite() -> void:
		var f: int = 0
		var bf: int = 0
		if t < 0.4:
			f = int(t * 10.0) % 4
			bf = int(t * 10.0) % 24
		elif t < 0.8:
			f = 4 + mini(3, int((t - 0.4) * 10.0))
			bf = 24 + f - 4
		elif t < 1.5:
			f = mini(15, 8 + int((t - 0.8) / 0.1))
			var j: int = int((t - 0.8) / 0.05)
			bf = 28 + j if j < 9 else -1
		else:
			f = 16 + int((t - 1.5) * 8.0) % 4
			bf = -1
		## oyundaki gibi: kart çıkınca sandık söner (chest_menu._hide_chest)
		var after: float = cl((t - C_REVEAL - 0.05) / 0.35)
		_a = 1.0 - after
		if _a <= 0.01:
			_a = 1.0
			return
		var cp: Vector2 = CHEST_C + Vector2(0, 24.0 * after)
		if bf >= 0:
			_img_reg(beam_sheet, Rect2(cp + Vector2(0, -176) - Vector2(256, 384), Vector2(512, 768)), Rect2(bf * 128, 0, 128, 192))
		_img_reg(chest_sheet, Rect2(cp - Vector2(192, 192), Vector2(384, 384)), Rect2(f * 96, 0, 96, 96))
		_a = 1.0
		_sparks(CHEST_C + Vector2(0, -40), cl((t - 0.8) / 0.5), TP[ITEM_TIER - 1][0], 22, 30, 260, 77)

	func _chest_state() -> Dictionary:
		var st := _blank(1)
		st["data"] = item
		var rs: float = t - C_REVEAL
		if rs < 0.0:
			st["a"] = 0.0
			return st
		var target := Vector2(960, 400)
		var c: Vector2 = target
		match kind:
			"A":
				var p: float = eo(rs / 0.7)
				c = (MOUTH + Vector2(0, -60)).lerp(Vector2(960, 190), p)
				st["sc"] = lerpf(0.25, 1.0, p)
				var ang: float = lerpf(PI * 0.5, TAU, ss(rs / 0.7))
				st["sx"] = cos(ang)
				st["face"] = "back" if ang < PI * 1.5 else "front"
				var e: float = rs - 0.7
				if e > 0.0:
					st["rot"] = 0.07 * exp(-5.0 * e) * sin(12.0 * e)
			"B":
				var p: float = eo(rs / 0.45)
				c = MOUTH.lerp(target, p)
				st["sc"] = lerpf(0.3, 1.0, p)
				st["rot"] = 0.12 * (1.0 - p) * sin(rs * 20.0)
				var f: float = cl((rs - 0.55) / 0.3)
				st["face"] = "back"
				if f > 0.0:
					st["sx"] = cos(f * PI)
					if f >= 0.5:
						st["face"] = "front"
			"C":
				var p: float = eo(rs / 0.3)
				c = MOUTH.lerp(target, p)
				st["sc"] = lerpf(0.3, 1.0, p)
				if rs < 0.95:
					st["spin"] = rs
					st["spin_icons"] = reel_item
					st["gem_cycle"] = int(rs * 14.0) % 4
				else:
					var since: float = rs - 0.95
					st["gems"] = mini(ITEM_TIER, 1 + int(since / 0.08))
					st["dust"] = since
					c.y += 8.0 * sin(cl(since / 0.14) * PI)
			"D":
				c = Vector2(960, 420)
				var e: float = cl((rs - 0.2) / 0.4)
				st["sx"] = maxf(eob(e), 0.002)
				st["sy"] = lerpf(0.35, 1.0, eo(e))
				st["a"] = 1.0 if e > 0.0 else 0.0
				st["med"] = eob((rs - 0.45) / 0.25) if rs > 0.45 else 0.0
				st["text_a"] = cl((rs - 0.5) / 0.25)
		st["glow"] = 0.55 * cl((rs - clen()) / 0.2)
		var s: float = t - t_press()
		if s >= 0.0:
			if kind == "B":
				st["seal"] = cl(s / 0.15)
			var f: float = ei((s - 0.25) / 0.55)
			if kind == "D":
				var q: float = ei(s / 0.25)
				st["sx"] = 1.0 - 0.97 * q
				c.x = 960.0 - 340.0 + 340.0 * float(st["sx"])
				st["text_a"] = 1.0 - cl(s / 0.12)
				st["med_fly"] = ei((s - 0.25) / 0.5)
				st["med_to"] = INV
			else:
				c = c.lerp(INV, f)
				st["sc"] = float(st["sc"]) * lerpf(1.0, 0.12, f)
			st["a"] = float(st["a"]) * (1.0 - cl((s - 0.6) / 0.2))
		st["c"] = c
		return st

	func _chest_buttons() -> void:
		var a: float = cl((t - (C_REVEAL + clen())) / 0.2) * (1.0 - cl((t - t_press() - 0.1) / 0.3))
		if a <= 0.01:
			return
		var y: float = chest_btn_y()
		var hov: float = ss((t - t_hover_al()) / 0.08)
		var prs: float = 1.0 if t >= t_press() and t < t_press() + 0.12 else 0.0
		var tc: Color = H_TEXT
		var oc: Color = OUTLINE
		var pc: Color = H_PRICE
		var al_tc: Color = H_TEXT
		var al_oc: Color = OUTLINE
		match kind:
			"B":
				tc = INK
				oc = Color(0, 0, 0, 0)
				pc = INK_GOLD
				al_tc = CREAM
				al_oc = INK
			"C":
				tc = S_TEXT
				oc = S_OUT
				pc = S_PRICE
				al_tc = S_ACCENT
				al_oc = S_OUT
			"A", "D":
				al_tc = H_PRICE
		_a = a
		_button("%s_btn_s" % kind, Vector2(810, y), hov, prs, [["t", "AL", al_tc, al_oc]])
		_button("%s_btn_m" % kind, Vector2(1068, y), 0.0, 0.0, [["t", "SAT", tc, oc], ["coin"], ["t", "+%d" % int(item["sell"]), pc, oc]])
		_a = 1.0

	func _cursor_chest() -> Array:
		var start := Vector2(1320, 940)
		var al := Vector2(840, chest_btn_y() + 14.0)
		var th: float = t_hover_al()
		var p: Vector2 = start.lerp(al, ss((t - (th - 0.3)) / 0.28))
		var stt: int = 1 if t >= th - 0.02 else 0
		if t >= t_press() and t < t_press() + 0.12:
			stt = 2
		return [p, stt]


# ==================================================================== çalıştırıcı
func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _grab() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.get_size() != Vector2i(1920, 1080):
		img.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	img.convert(Image.FORMAT_RGBA8)
	return img


func _save(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT + name))
	print("SHOT ", name)


func _caption_layer(text: String, font: Font) -> CanvasLayer:
	var l := CanvasLayer.new()
	l.layer = 120
	var c := Cap.new()
	c.text = text
	c.font = font
	c.size = Vector2(1920, 1080)
	l.add_child(c)
	root.add_child(l)
	return l


func _grid(imgs: Array) -> Image:
	var out := Image.create_empty(1920, 1080, false, Image.FORMAT_RGBA8)
	for k in mini(4, imgs.size()):
		var h: Image = (imgs[k] as Image).duplicate() as Image
		h.convert(Image.FORMAT_RGBA8)
		h.resize(960, 540, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(h, Rect2i(0, 0, 960, 540), Vector2i((k % 2) * 960, (k / 2) * 540))
	return out


func _stat_card(lscr: Object, ups: Array, icon_dir: String, icon_paths: Dictionary, spec: Array) -> Dictionary:
	var id: String = spec[0]
	var tier: int = spec[1]
	var up: Dictionary = {}
	for u: Dictionary in ups:
		if str(u["id"]) == id:
			up = u
	var val: String = str(lscr.call("_scaled_desc_value", str(up["desc"]), tier, id))
	var cdr: bool = id == "cooldown_reduction"
	return {"title": str(up["title"]), "cat": str(up["cat"]), "tier": tier, "count": int(spec[2]),
		"value": ("-" if cdr else "+") + val.replace("+", "").replace("-", ""), "verb": "azalır" if cdr else "artar",
		"icon": load(icon_dir + str(icon_paths.get(id, "stat_damage.png")))}


func _draw_grab(pr: Control) -> Image:
	pr.queue_redraw()
	return await _grab()


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var only: String = OS.get_environment("KART_ONLY")
	var kinds: Array = ["simdi", "A", "B", "C", "D"]
	if only != "":
		kinds = Array(only.split(","))
	var nogif: bool = OS.get_environment("KART_NOGIF") == "1"
	var frames_dir: String = OS.get_environment("KART_FRAMES")
	if frames_dir == "":
		frames_dir = ProjectSettings.globalize_path(OUT + "kareler")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var font: Font = load("res://assets/fonts/m5x7.ttf")

	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", 2)
	var chars: GDScript = load("res://scripts/characters.gd")
	gm.set("selected_character", chars.get_def(2).get("skill", 1))
	gm.set("selected_pet", "peri")
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(2.5)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player:
		player.global_position += Vector2(40, 170)
	var hud: Node = current_scene.get_node_or_null("HUD")
	if hud:
		hud.call("update_level", 12)
	await _wait(1.0)

	## veri: gerçek kart değerleri (level_up_screen._scaled_desc_value) + gerçek ikonlar
	var lus: GDScript = load("res://scripts/level_up_screen.gd")
	var lscr: Object = lus.new()
	var ups: Array = lus.get_script_constant_map()["UPGRADES"]
	var sim: Dictionary = (load("res://scripts/stat_icon.gd") as GDScript).get_script_constant_map()
	var icon_dir: String = sim["ICON_DIR"]
	var icon_paths: Dictionary = sim["ICON_PATHS"]
	var old_cards: Array = []
	var new_cards: Array = []
	for spec: Array in LEVEL_OLD:
		old_cards.append(_stat_card(lscr, ups, icon_dir, icon_paths, spec))
	for spec: Array in LEVEL_NEW:
		new_cards.append(_stat_card(lscr, ups, icon_dir, icon_paths, spec))
	(lscr as Node).free()
	var reel_stat: Array = []
	var seen: Dictionary = {}
	for f: String in icon_paths.values():
		if not seen.has(f) and f != "stat_damage_old.png":
			seen[f] = true
			reel_stat.append(load(icon_dir + f))
	var items: GDScript = load("res://scripts/items.gd")
	var lines: Array = []
	for ln: String in str(items.call("describe", ITEM_KEY)).split("\n"):
		if ln.strip_edges() != "" and lines.size() < 2:
			lines.append(ln.strip_edges())
	var kad: Array = items.get_script_constant_map()["KADEME_NAMES"]
	var item := {"title": str(items.call("item_name", ITEM_KEY)), "tier": ITEM_TIER, "lines": lines,
		"kademe": str(kad[int(items.call("kademe", ITEM_KEY)) - 1]), "sell": int(int(items.call("cost", ITEM_KEY)) * 0.5),
		"icon": load(str(items.call("icon_path", ITEM_KEY)))}
	var reel_item: Array = []
	for k: String in REEL_ITEMS:
		reel_item.append(load(str(items.call("icon_path", k))))
	print("VERI eski=", old_cards.map(func(c: Dictionary) -> String: return "%s %s" % [c["title"], c["value"]]),
		" yeni=", new_cards.map(func(c: Dictionary) -> String: return "%s %s" % [c["title"], c["value"]]), " esya=", item["title"], " ", lines)

	## ŞU AN: gerçek level ekranı + gerçek sandık ekranı
	if kinds.has("simdi"):
		current_scene.call("_show_level_up_screen", 12)
		await _wait(1.6)
		var cap := _caption_layer("ŞU AN - level atlama", font)
		var shot: Image = await _grab()
		_save(shot, "simdi_level.png")
		cap.queue_free()
		var scr: Node = current_scene.get_node_or_null("LevelUpScreen")
		if scr:
			scr.queue_free()
		current_scene.set("_active_level_up_screen", null)
		paused = false
		await _wait(0.5)
		var cm: Node = (load("res://scenes/chest_menu.tscn") as PackedScene).instantiate()
		current_scene.add_child(cm)
		cm.call("setup", player, 4)
		await _wait(3.4)
		cap = _caption_layer("ŞU AN - sandık", font)
		shot = await _grab()
		_save(shot, "simdi_sandik.png")
		cap.queue_free()
		cm.queue_free()
		paused = false
		await _wait(0.4)

	var bg_shot: Image = await _grab()
	var bg_tex := ImageTexture.create_from_image(bg_shot)
	var chest_script: GDScript = load("res://scripts/chest_art.gd")
	var cmap: Dictionary = chest_script.get_script_constant_map()
	var curs: Array = [load("res://assets/ui/cursor/imlec_normal.png"), load("res://assets/ui/cursor/imlec_el.png"),
		load("res://assets/ui/cursor/imlec_basili.png")]
	var lvl_imgs: Array = []
	var chest_imgs: Array = []
	for k: String in kinds:
		if k == "simdi":
			continue
		var layer := CanvasLayer.new()
		layer.layer = 110
		root.add_child(layer)
		var pr := Proto.new()
		pr.kind = k
		pr.font = font
		pr.old_cards = old_cards
		pr.new_cards = new_cards
		pr.item = item
		pr.reel_stat = reel_stat
		pr.reel_item = reel_item
		pr.die = load("res://assets/ui/game/levelup_die.png")
		pr.coin = load("res://assets/pickups/gold/gold_coin.png")
		pr.curs = curs
		pr.chest_sheet = (cmap["NORMAL_TIER_SHEETS"] as Array)[ITEM_TIER - 1]
		pr.beam_sheet = (cmap["BEAM_TIER_SHEETS"] as Array)[ITEM_TIER - 1]
		pr.title_glow = load("res://assets/ui/game/levelup_title_glow.png")
		pr.bg_tex = bg_tex
		pr.build()
		layer.add_child(pr)
		await process_frame
		var moments: Array = []
		pr.mode = "level"
		pr.caption = CAPTIONS[k]
		pr.t = 0.4
		var img: Image = await _draw_grab(pr)
		_save(img, k + "_level.png")
		lvl_imgs.append(img)
		pr.caption = CAPTIONS[k] + " · seçim üstünde"
		moments.append(await _draw_grab(pr))
		pr.caption = CAPTIONS[k] + " · karıştırma"
		pr.t = pr.t_reroll() + pr.rlen() * 0.5
		moments.append(await _draw_grab(pr))
		pr.caption = CAPTIONS[k] + " · seçildi"
		pr.t = pr.t_sel() + 0.32
		moments.append(await _draw_grab(pr))
		pr.mode = "chest"
		pr.caption = CAPTIONS[k] + " · sandık açılıyor"
		pr.t = Proto.C_REVEAL + pr.clen() * 0.55
		moments.append(await _draw_grab(pr))
		pr.caption = CAPTIONS[k]
		pr.t = pr.t_hover_al() + 0.3
		img = await _draw_grab(pr)
		_save(img, k + "_sandik.png")
		chest_imgs.append(img)
		_save(_grid(moments), k + "_anlar.png")
		if not nogif:
			pr.caption = ""
			for md: String in ["level", "chest"]:
				pr.mode = md
				var sub: String = frames_dir.path_join("%s_%s" % [k, "level" if md == "level" else "sandik"])
				DirAccess.make_dir_recursive_absolute(sub)
				var n: int = int(ceil(pr.end_time() * GIF_FPS))
				for fi in n:
					pr.t = fi / GIF_FPS
					var fr: Image = await _draw_grab(pr)
					var g: Image = fr.get_region(GIF_CROP)
					g.resize(GIF_SIZE.x, GIF_SIZE.y, Image.INTERPOLATE_BILINEAR)
					g.save_png(sub.path_join("%03d.png" % fi))
				print("KARE ", k, " ", md, " ", n)
		layer.queue_free()
		await process_frame
	if lvl_imgs.size() == 4:
		_save(_grid(lvl_imgs), "ozet_level.png")
		_save(_grid(chest_imgs), "ozet_sandik.png")
	print("BITTI")
	quit()
