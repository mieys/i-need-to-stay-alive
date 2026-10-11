extends RefCounted

## BOSS ÇUBUĞU çizim parçaları (kullanıcı isteği 2026-10-05): üst ortadaki boss barı (2026-10-10'dan beri R2 "Kafatası Madalyonu";
## eskisi T1 "Ahşap Plaket" top_plaque_wood olarak duruyor) ve boss'un üstündeki
## kafatası plakası (O1'in kafatası parçası) AYNI piksel çizim fonksiyonlarını kullanır. Prototipler tools/boss_bar_proto/'da
## (Python, art.py) - buradaki koordinatlar onların BİREBİR portu; paleti oyun kitinden (assets/ui/game, assets/ui/kit) örneklendi.
## Hepsi kodla çizilir (doku yok): CanvasItem._draw içinden çağrılır; `s` = bir sanat pikselinin ekran/yerel birim karşılığı
## (üst bar: 3, boss üstü kafatası: 1 yerel birim = 2 ekran px).
##
## Yazı: m5x7, 16 boyutunda 1x (büyük harf 7 px) - s ile çarpılır (s=3 -> 48, oyundaki FS_TITLE ile aynı).

const OUT := Color("#382011")
const OUT2 := Color("#1e120a")
const W_HI := Color("#ae956d")
const W_FACE := Color("#a4875c")
const W_MD := Color("#94764c")
const W_DK := Color("#683e20")
const W_SH := Color("#725531")
const GOLD_L := Color("#c2aa6c")
const GOLD := Color("#b78b2a")
const GOLD_D := Color("#956313")
const PARCH := Color("#c8a878")
const PARCH_HI := Color("#d9bd8f")
const PARCH_SH := Color("#ae8e60")
const INK := Color("#3a2212")
const CREAM := Color("#fff0d6")
const BONE := Color("#e9ddc2")
const BONE_D := Color("#b9a98a")
const IRON_D := Color("#24202b")
const TRACK := Color("#1d0f0b")
const RED_HI := Color("#f07a62")
const RED_L := Color("#d2413a")
const RED := Color("#ae2730")
const RED_M := Color("#831824")
const RED_D := Color("#570c11")
const BLUE_HI := Color("#bfe0ff")
const BLUE_L := Color("#6fa8e6")
const BLUE := Color("#3065ac")
const BLUE_D := Color("#13284d")
const EMPTY_BLUE := Color("#0f1c33")

const HP_BANDS: Array[Color] = [RED_HI, RED_L, RED, RED, RED_M, RED_D]
const SH_BANDS: Array[Color] = [BLUE_HI, BLUE_L, BLUE, BLUE, BLUE_D]

const FONT_PATH := "res://assets/fonts/m5x7.ttf"
const FONT_UNIT := 16 ## m5x7'in 1x boyutu (büyük harf 7 px)
const CAP_H := 7

## Üst bar (R2 Kafatası Madalyonu, 2026-10-10) ölçüsü (sanat pikseli). Eski T1 ahşap plaket 224 x 44 idi (top_plaque_wood).
const TOP_W := 226
const TOP_H := 38
## Kafatası plakası (boss üstü) ölçüsü ve kafanın üstünde bırakılan boşluk (yerel birim = 2 ekran px -> 12 px).
const PLATE_SIZE := 15
const PLATE_GAP := 6.0

const SKULL_ROWS: Array[String] = [
	"..XXXXX..",
	".XWWWWWX.",
	"XWWWWWWWX",
	"XWKKWKKWX",
	"XWKKWKKWX",
	".XWWXWWX.",
	"..XWWWX..",
	"..XWXWX..",
	"...XXX...",
]

static var _font: Font = null
## doku -> en üstteki opak satır (hücre içinde, texel); aynı sayfa için bir kez ölçülür.
static var _empty_top_cache: Dictionary = {}


static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) as Font
	return _font


# ---------------------------------------------------------------- ilkel çizimler
static func r(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(w, h) * s), c)


## Köşeleri 1 piksel kesik dolu dikdörtgen.
static func rrect(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, w: float, h: float, c: Color) -> void:
	r(ci, o, s, x + 1, y, w - 2, h, c)
	r(ci, o, s, x, y + 1, 1, h - 2, c)
	r(ci, o, s, x + w - 1, y + 1, 1, h - 2, c)


static func box(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, w: float, h: float, c: Color) -> void:
	r(ci, o, s, x, y, w, 1, c)
	r(ci, o, s, x, y + h - 1, w, 1, c)
	r(ci, o, s, x, y, 1, h, c)
	r(ci, o, s, x + w - 1, y, 1, h, c)


## Satır satır renk bantları (bantlar yüksekliğe eşit bölünür).
@warning_ignore("integer_division")
static func vgrad(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, w: float, h: float, bands: Array[Color]) -> void:
	var n: int = bands.size()
	for yy in range(int(h)):
		r(ci, o, s, x, y + yy, w, 1, bands[mini(n - 1, yy * n / int(h))])


## İz + soldan `ratio` kadar bantlı dolgu (dolgunun sağ ucunda 1 px parlak kenar).
@warning_ignore("integer_division")
static func fill_bar(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, w: float, h: float, ratio: float,
		bands: Array[Color], track: Color) -> void:
	r(ci, o, s, x, y, w, h, track)
	var fw: int = int(roundf(w * clampf(ratio, 0.0, 1.0)))
	if ratio > 0.0 and fw < 1:
		fw = 1
	if fw > 0:
		vgrad(ci, o, s, x, y, fw, h, bands)
		if fw < int(w):
			r(ci, o, s, x + fw - 1, y, 1, h, bands[bands.size() / 2])


## %10 gibi eşit aralıklı ince koyu çizgiler (can çubuğunun dilimleri).
static func ticks(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, w: float, h: float, n: int,
		color: Color = OUT, alpha: float = 0.45) -> void:
	var c := Color(color.r, color.g, color.b, alpha)
	for i in range(1, n):
		r(ci, o, s, x + roundf(w * float(i) / float(n)), y, 1, h, c)


## ASCII sanat: '.' saydam; aynı renkli yatay parçalar tek dikdörtgen olarak çizilir.
static func blit(ci: CanvasItem, o: Vector2, s: float, rows: Array[String], pal: Dictionary, x: float, y: float) -> void:
	for yy in range(rows.size()):
		var row: String = rows[yy]
		var xx: int = 0
		while xx < row.length():
			var ch: String = row[xx]
			if ch == "." or not pal.has(ch):
				xx += 1
				continue
			var run: int = 1
			while xx + run < row.length() and row[xx + run] == ch:
				run += 1
			r(ci, o, s, x + xx, y + yy, run, 1, pal[ch])
			xx += run


static func skull(ci: CanvasItem, o: Vector2, s: float, x: float, y: float) -> void:
	blit(ci, o, s, SKULL_ROWS, {"X": OUT, "W": BONE, "K": OUT2}, x, y)
	r(ci, o, s, x + 1, y + 5, 1, 1, BONE_D)
	r(ci, o, s, x + 7, y + 5, 1, 1, BONE_D)
	r(ci, o, s, x + 6, y + 6, 1, 1, BONE_D)


static func nail(ci: CanvasItem, o: Vector2, s: float, x: float, y: float) -> void:
	r(ci, o, s, x, y, 1, 1, GOLD_L)
	r(ci, o, s, x + 1, y, 1, 1, GOLD)
	r(ci, o, s, x, y + 1, 1, 1, GOLD)
	r(ci, o, s, x + 1, y + 1, 1, 1, GOLD_D)


# ---------------------------------------------------------------- yazı
## Yazının sanat pikseli cinsinden genişliği (s ölçeğinde çizilecekse).
static func text_width(text: String, s: float) -> float:
	return ceilf(font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(FONT_UNIT * s)).x / s)


## Büyük harf üstü sanat-y = cap_y olacak şekilde yazar (taban çizgisi = cap_y + 7). outline verilirse 1 px (s) anahatlı.
static func text(ci: CanvasItem, o: Vector2, s: float, x: float, cap_y: float, str_: String, color: Color,
		outline: Color = Color(0, 0, 0, 0)) -> void:
	var pos: Vector2 = o + Vector2(x, cap_y + CAP_H) * s
	var size: int = int(FONT_UNIT * s)
	if outline.a > 0.0:
		ci.draw_string_outline(font(), pos, str_, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(s), outline)
	ci.draw_string(font(), pos, str_, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Büyük sayıyı binlik noktalı yazar (Türkçe): 164549 -> "164.549". Negatif/NaN 0'a kırpılır.
static func fmt_int(v: float) -> String:
	var n: int = int(roundf(maxf(v, 0.0)))
	var digits: String = str(n)
	var out: String = ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += "."
		out += digits[i]
	return out


## "şimdiki / en çok" çubuk yazısı (boss barı); en çok <= 0 ise (ör. kalkansız boss) boş.
static func bar_text(current: float, maximum: float) -> String:
	if maximum <= 0.0:
		return ""
	return "%s / %s" % [fmt_int(current), fmt_int(maximum)]


## Çubuğun içine ortalanmış sayı (krem yazı, koyu anahatlı - hem kırmızı hem mavi bantta okunur). bar_h = çubuğun sanat piksel yüksekliği.
static func bar_label(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, bar_w: float, bar_h: float, str_: String) -> void:
	if str_.is_empty():
		return
	var tw: float = text_width(str_, s)
	text(ci, o, s, x + roundf((bar_w - tw) * 0.5), y + floorf((bar_h - float(CAP_H)) * 0.5), str_, CREAM, OUT2)


# ---------------------------------------------------------------- R2: Kafatası Madalyonu (2026-10-10, şu anki üst bar)
## Kullanıcı 3. tur prototiplerden R2'yi seçti (tools/boss_bar_proto/protos_top3.py top_r2 - buradaki koordinatlar onun BİREBİR portu):
## solda büyük yuvarlak kafatası madalyonu, iki çubuk sağa doğru bıçak ucu gibi sivrilir, isim çubuğun üstünde sola yaslı.
## Kırmızının arkasında açık renkli "son hasar izi" (trail = izin ulaştığı can oranı, >= hp; boss_bar_top.gd geriden getirir).
## Değere bağlı olmayan parçalar (gövde/uç/anahat ve madalyon) bir kez piksel koşularına çevrilip önbelleğe alınır.
const MEDAL_SKULL_ROWS: Array[String] = [
	"...XXXXXXX...",
	"..XWWWWWWWX..",
	".XWWWWWWWWWX.",
	"XWWWWWWWWWWWX",
	"XWKKKWWWKKKWX",
	"XWKKKWWWKKKWX",
	"XWKKWWWWWKKWX",
	".XWWWWKWWWWX.",
	"..XWWKKKWWX..",
	"..XWWWWWWWX..",
	"..XWXWXWXWX..",
	"...XXXXXXX...",
]
const IRON := Color("#3b3640")
const IRON_L := Color("#5b5563")
const TRACK_RED := Color("#2a0f10")
const TRAIL := Color("#d98670")
const MEDAL_R := 15
const MEDAL_C := Vector2i(16, 21)
const BAR_X0 := 26 ## çubukların sol kenarı
const BODY_Y := 12 ## çubuk gövdesinin üstü
const BODY_H := 22
const TIP := 8 ## sivri ucun sütun sayısı

static var _medal_cache: Dictionary = {} ## w -> {"base": runs, "front": runs}; run = [x, y, uzunluk, renk]


## Medalyon barının çubuk genişliği (sanat pikseli).
static func medal_bar_w(w: int) -> int:
	return w - 2 - BAR_X0 - TIP


## Can çubuğu: koyu iz + son hasar izi + bantlı dolgu (ucunda parlak çizgi) + sadece dolu kısımda %10 dilimleri.
static func hp_bar_trail(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, w: float, h: float, hp: float, trail: float) -> void:
	r(ci, o, s, x, y, w, h, TRACK_RED)
	var tw: int = int(roundf(w * clampf(trail, 0.0, 1.0)))
	if trail > hp and tw > 0:
		r(ci, o, s, x, y, tw, h, TRAIL)
	var fw: int = _fill(ci, o, s, x, y, w, h, hp, HP_BANDS)
	var c := Color(OUT2.r, OUT2.g, OUT2.b, 0.35)
	for i in range(1, 10):
		var tx: float = x + roundf(w * float(i) / 10.0)
		if tx >= x + fw - 1:
			break
		r(ci, o, s, tx, y, 1, h, c)


## Bantlı dolgu, ucunda en açık bant rengi; dolu genişliği döner.
static func _fill(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, w: float, h: float, ratio: float, bands: Array[Color]) -> int:
	var fw: int = int(roundf(w * clampf(ratio, 0.0, 1.0)))
	if ratio > 0.0 and fw < 1:
		fw = 1
	if fw > 0:
		vgrad(ci, o, s, x, y, fw, h, bands)
		if fw < int(w):
			r(ci, o, s, x + fw - 1, y, 1, h, bands[0])
	return fw


## origin = barın sol-üst köşesi (ekran px). name = boss adı, hp/sh = 0..1, trail = son hasar izinin ulaştığı can oranı (<= hp ise iz yok).
## hp_text / sh_text: çubukların içindeki sayılar ("164.549 / 165.000"); boşsa yazı yok.
@warning_ignore("integer_division")
static func top_plaque(ci: CanvasItem, o: Vector2, s: float, name_: String, hp: float, sh: float, w: int = TOP_W, hp_text: String = "",
		sh_text: String = "", trail: float = -1.0) -> void:
	var parts: Dictionary = _medal_parts(w)
	_draw_runs(ci, o, s, parts["base"])
	var bw: int = medal_bar_w(w)
	r(ci, o, s, BAR_X0, BODY_Y + 1, bw, 9, EMPTY_BLUE)
	_fill(ci, o, s, BAR_X0, BODY_Y + 1, bw, 9, sh, SH_BANDS)
	hp_bar_trail(ci, o, s, BAR_X0, BODY_Y + 11, bw, 10, hp, trail)
	bar_label(ci, o, s, BAR_X0, BODY_Y + 1, bw, 9, sh_text)
	bar_label(ci, o, s, BAR_X0, BODY_Y + 11, bw, 10, hp_text)
	text(ci, o, s, BAR_X0 + 6, 2, name_, CREAM, OUT2)
	_draw_runs(ci, o, s, parts["front"])


static func _draw_runs(ci: CanvasItem, o: Vector2, s: float, runs: Array) -> void:
	for run: Array in runs:
		r(ci, o, s, run[0], run[1], run[2], 1, run[3])


## Piksel haritası (Vector2i -> Color) -> satır satır aynı renkli yatay koşular.
static func _to_runs(pm: Dictionary) -> Array:
	var keys: Array = pm.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var runs: Array = []
	for k: Vector2i in keys:
		var c: Color = pm[k]
		if not runs.is_empty():
			var last: Array = runs[runs.size() - 1]
			if last[1] == k.y and last[0] + last[2] == k.x and last[3] == c:
				last[2] += 1
				continue
		runs.append([k.x, k.y, 1, c])
	return runs


## Değere bağlı olmayan parçalar: "base" = çubuk gövdesi + sivri uç + anahat (çubukların ARKASI), "front" = madalyon + kafatası (en önde).
@warning_ignore("integer_division")
static func _medal_parts(w: int) -> Dictionary:
	if _medal_cache.has(w):
		return _medal_cache[w]
	var end: int = w - 2
	var bw: int = medal_bar_w(w)
	var pm: Dictionary = {}
	for y in range(BODY_Y, BODY_Y + BODY_H):
		for x in range(BAR_X0 - 6, end):
			pm[Vector2i(x, y)] = IRON_D
	for x in range(BAR_X0, BAR_X0 + bw):
		pm[Vector2i(x, BODY_Y + 10)] = OUT2
	var mid: float = float(BODY_Y) + float(BODY_H) * 0.5
	for i in range(TIP): # sivri uç: son TIP sütunda dikeyde daralır
		var x: int = end - TIP + i
		var half: float = float(BODY_H) * 0.5 * (1.0 - float(i + 1) / float(TIP + 1))
		for yy in range(BODY_Y, BODY_Y + BODY_H):
			if absf(float(yy) + 0.5 - mid) > half:
				pm.erase(Vector2i(x, yy))
			else:
				pm[Vector2i(x, yy)] = IRON if float(yy) < mid else IRON_D
	for x in range(end - TIP - 1, end):
		pm[Vector2i(x, BODY_Y + BODY_H / 2 - 1)] = IRON_L
	var outline: Dictionary = {} # 4-komşu dış anahat
	for y in range(BODY_Y - 1, BODY_Y + BODY_H + 1):
		for x in range(BAR_X0 - 7, end + 1):
			var p := Vector2i(x, y)
			if pm.has(p):
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if pm.has(p + d):
					outline[p] = OUT2
					break
	pm.merge(outline)
	for x in range(BAR_X0, BAR_X0 + bw):
		pm[Vector2i(x, BODY_Y)] = IRON_L
	var front: Dictionary = {}
	var mcx: float = float(MEDAL_C.x)
	var mcy: float = float(MEDAL_C.y)
	var rr: float = float(MEDAL_R)
	for y in range(MEDAL_C.y - MEDAL_R - 1, MEDAL_C.y + MEDAL_R + 2):
		for x in range(MEDAL_C.x - MEDAL_R - 1, MEDAL_C.x + MEDAL_R + 2):
			var d: float = Vector2(float(x) + 0.5 - mcx, float(y) + 0.5 - mcy).length()
			if d > rr:
				continue
			var c: Color
			if d > rr - 1.2:
				c = OUT2
			elif d > rr - 3.2:
				var ang: float = atan2(float(y) + 0.5 - mcy, float(x) + 0.5 - mcx)
				c = GOLD_L if (ang > -2.6 and ang < -0.6) else (GOLD_D if (ang > 0.6 and ang < 2.6) else GOLD)
			elif d > rr - 4.2:
				c = OUT2
			else:
				c = RED_M if y < MEDAL_C.y - 3 else RED_D
			front[Vector2i(x, y)] = c
	var pal: Dictionary = {"X": OUT2, "W": BONE, "K": OUT2}
	for yy in range(MEDAL_SKULL_ROWS.size()):
		var row: String = MEDAL_SKULL_ROWS[yy]
		for xx in range(row.length()):
			if pal.has(row[xx]):
				front[Vector2i(MEDAL_C.x - 6 + xx, MEDAL_C.y - 6 + yy)] = pal[row[xx]]
	front[Vector2i(MEDAL_C.x - 4, MEDAL_C.y + 1)] = BONE_D
	front[Vector2i(MEDAL_C.x + 4, MEDAL_C.y + 1)] = BONE_D
	var parts := {"base": _to_runs(pm), "front": _to_runs(front)}
	_medal_cache[w] = parts
	return parts


# ---------------------------------------------------------------- T1: eski ahşap plaket (2026-10-05..10-10 kullanıldı; geri dönmek için
## boss_bar_top.gd _draw'da top_plaque yerine bunu çağır ve TOP_W/TOP_H'yi 224/44 yap)
## origin = plaketin sol-üst köşesi (ekran px). name = boss adı (parşömen tabelada), hp/sh = 0..1.
## hp_text / sh_text (2026-10-09, "bossların can ve kalkan sayısı görünmüyor"): çubukların içine yazılan sayılar ("164.549 / 165.000"); boşsa yazı yok.
@warning_ignore("integer_division")
static func top_plaque_wood(ci: CanvasItem, o: Vector2, s: float, name_: String, hp: float, sh: float, w: int = 224, hp_text: String = "", sh_text: String = "") -> void:
	var tw: float = text_width(name_, s)
	var sw: int = int(tw) + 22
	var sx: int = (w - sw) / 2
	# isim tabelası
	rrect(ci, o, s, sx, 0, sw, 13, OUT)
	r(ci, o, s, sx + 1, 1, sw - 2, 11, PARCH)
	r(ci, o, s, sx + 1, 1, sw - 2, 1, PARCH_HI)
	r(ci, o, s, sx + 1, 11, sw - 2, 1, PARCH_SH)
	for nx in [sx + 4, sx + sw - 5]:
		r(ci, o, s, nx, 5, 1, 1, GOLD_L)
		r(ci, o, s, nx, 6, 1, 1, GOLD)
		r(ci, o, s, nx, 7, 1, 1, GOLD_D)
	text(ci, o, s, sx + 11, 3, name_, INK)
	# ana plaket
	var fy: int = 11
	var fh: int = 33
	rrect(ci, o, s, 0, fy, w, fh, OUT)
	r(ci, o, s, 1, fy + 1, w - 2, fh - 2, W_FACE)
	r(ci, o, s, 1, fy + 1, w - 2, 1, W_HI)
	r(ci, o, s, 1, fy + 1, 1, fh - 2, W_HI)
	r(ci, o, s, 1, fy + fh - 2, w - 2, 1, W_DK)
	r(ci, o, s, w - 2, fy + 1, 1, fh - 2, W_MD)
	var gx: int = 6
	while gx < w - 6: # ahşap damarı
		r(ci, o, s, gx, fy + 6, 1, 1, W_MD)
		r(ci, o, s, gx + 4, fy + 19, 1, 1, W_MD)
		r(ci, o, s, gx + 7, fy + 12, 1, 1, W_SH)
		gx += 11
	for p: Vector2 in [Vector2(3, fy + 3), Vector2(w - 5, fy + 3), Vector2(3, fy + fh - 5), Vector2(w - 5, fy + fh - 5)]:
		nail(ci, o, s, p.x, p.y)
	# kafatası yuvası (HUD'daki kalp yuvasının karşılığı)
	rrect(ci, o, s, 5, fy + 7, 19, 19, OUT)
	r(ci, o, s, 6, fy + 8, 17, 17, RED_D)
	r(ci, o, s, 6, fy + 8, 17, 1, RED_M)
	skull(ci, o, s, 10, fy + 12)
	# çubuklar: üstte kalkan (9), altta can (11) - ikisinin de içinde sayı
	var x0: int = 30
	var bw: int = w - 30 - 6
	var sy: int = fy + 4
	var sh_h: int = 9
	var hy: int = fy + 16
	var hp_h: int = 11
	r(ci, o, s, x0 - 1, sy - 1, bw + 2, sh_h + 2, OUT)
	fill_bar(ci, o, s, x0, sy, bw, sh_h, sh, SH_BANDS, EMPTY_BLUE)
	r(ci, o, s, x0 - 1, hy - 1, bw + 2, hp_h + 2, OUT)
	fill_bar(ci, o, s, x0, hy, bw, hp_h, hp, HP_BANDS, TRACK)
	ticks(ci, o, s, x0, hy, bw, hp_h, 10)
	bar_label(ci, o, s, x0, sy, bw, sh_h, sh_text)
	bar_label(ci, o, s, x0, hy, bw, hp_h, hp_text)


# ---------------------------------------------------------------- boss üstü kafatası plakası (O1'in kafatası parçası)
## origin = plakanın sol-üst köşesi; PLATE_SIZE x PLATE_SIZE sanat pikseli.
static func skull_plate(ci: CanvasItem, o: Vector2, s: float) -> void:
	rrect(ci, o, s, 0, 0, PLATE_SIZE, PLATE_SIZE, OUT2)
	r(ci, o, s, 1, 1, 13, 13, IRON_D)
	box(ci, o, s, 1, 1, 13, 13, GOLD_D)
	r(ci, o, s, 1, 1, 1, 1, GOLD_L)
	r(ci, o, s, 13, 1, 1, 1, GOLD_L)
	r(ci, o, s, 2, 2, 11, 11, RED_D)
	skull(ci, o, s, 3, 3)


# ---------------------------------------------------------------- kafa konumu (kafatası plakasının yerleşimi)
## Boss sprite'ının O ANKİ karesindeki en üstteki opak pikselin, boss kökünün YEREL koordinatındaki y'si (negatif = yukarı).
## Sprite sayfası (hframes x vframes: sütunlar kareler, satırlar yönler) her hücre için bir kez ölçülür ve saklanır; işaret her
## kare bu karenin değerini okuyup kafayla birlikte hafifçe süzülür (boss_skull_marker.gd). Sabit "tüm karelerin en yükseği"
## kullanılırsa golemde işaret kafadan ~60 px yukarıda havada kalıyordu (kareler arasında 11 texel fark var).
## Ölçülemezse (doku okunamıyor) null döner, çağıran eski formüle düşer.
@warning_ignore("integer_division")
static func head_top_local(sprite: Sprite2D) -> Variant:
	if sprite == null or sprite.texture == null or sprite.hframes < 1 or sprite.vframes < 1:
		return null
	var tex: Texture2D = sprite.texture
	var cell_h: int = tex.get_height() / sprite.vframes
	var key: String = "%s|%d|%d" % [tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id()), sprite.hframes, sprite.vframes]
	if not _empty_top_cache.has(key):
		_empty_top_cache[key] = _measure_cell_tops(tex, sprite.hframes, sprite.vframes)
	var tops: PackedInt32Array = _empty_top_cache[key]
	if tops.is_empty():
		return null
	var empty_top: int = tops[sprite.frame] if sprite.frame >= 0 and sprite.frame < tops.size() else -1
	if empty_top < 0: ## bu hücre boş: sayfanın tipik (ortanca) değeri
		var valid: Array = []
		for v in tops:
			if v >= 0:
				valid.append(v)
		if valid.is_empty():
			return null
		valid.sort()
		empty_top = int(valid[valid.size() / 2])
	return sprite.position.y + sprite.scale.y * (sprite.offset.y - float(cell_h) * 0.5 + float(empty_top))


## Her hücrenin "üstteki boş satır sayısı" (hücre içinde, texel); boş hücre -1. Doku okunamazsa boş dizi.
@warning_ignore("integer_division")
static func _measure_cell_tops(tex: Texture2D, hframes: int, vframes: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return out
	if img.is_compressed() and img.decompress() != OK:
		return out
	var cell_w: int = tex.get_width() / hframes
	var cell_h: int = tex.get_height() / vframes
	for row in range(vframes):
		for col in range(hframes):
			var used: Rect2i = img.get_region(Rect2i(col * cell_w, row * cell_h, cell_w, cell_h)).get_used_rect()
			out.append(used.position.y if used.size.x > 0 else -1)
	return out


## Boss adı (üst barda ve küçük plaketlerde): creature_id'nin rakamsız kısmı -> görünen ad. Tablodaki değer büyük harfli.
const NAMES := {
	"agac": "AĞAÇ", "bitki": "BİTKİ", "demon": "DEMON", "golem": "GOLEM", "hayalet": "HAYALET", "iblis": "İBLİS",
	"iskelet": "İSKELET", "lich": "LICH", "mantar": "MANTAR", "ork": "ORK", "rat": "FARE", "rontgen": "RÖNTGEN",
	"slime": "SLIME", "vampire": "VAMPİR", "zombie": "ZOMBİ", "minotaur": "MİNOTAUR", "underground": "YERALTI CANAVARI", "sandworm": "SOLUCAN", "balkabagi": "BALKABAĞI KAFA", "wendigo": "WENDİGO", "banshee": "BANSHEE", "ucansetan": "UÇAN ŞEYTAN",
}


static func display_name(creature_id: String) -> String:
	var family: String = creature_id.rstrip("0123456789")
	return str(NAMES.get(family, family.to_upper()))
