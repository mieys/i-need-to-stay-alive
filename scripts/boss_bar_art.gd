extends RefCounted

## BOSS ÇUBUĞU çizim parçaları (kullanıcı isteği 2026-10-05): üst ortadaki "Ahşap Plaket" (T1) boss barı ve boss'un üstündeki
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

## Ana plaket (T1) ölçüsü (sanat pikseli).
const TOP_W := 224
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


# ---------------------------------------------------------------- T1: ana ahşap plaket
## origin = plaketin sol-üst köşesi (ekran px). name = boss adı (parşömen tabelada), hp/sh = 0..1.
@warning_ignore("integer_division")
static func top_plaque(ci: CanvasItem, o: Vector2, s: float, name_: String, hp: float, sh: float, w: int = TOP_W) -> void:
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
	var fh: int = 27
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
	rrect(ci, o, s, 5, fy + 4, 19, 19, OUT)
	r(ci, o, s, 6, fy + 5, 17, 17, RED_D)
	r(ci, o, s, 6, fy + 5, 17, 1, RED_M)
	skull(ci, o, s, 10, fy + 9)
	# çubuklar: üstte ince kalkan, altta can
	var x0: int = 30
	var bw: int = w - 30 - 6
	var sy: int = fy + 4
	var hy: int = fy + 13
	r(ci, o, s, x0 - 1, sy - 1, bw + 2, 8, OUT)
	fill_bar(ci, o, s, x0, sy, bw, 6, sh, SH_BANDS, EMPTY_BLUE)
	r(ci, o, s, x0 - 1, hy - 1, bw + 2, 12, OUT)
	fill_bar(ci, o, s, x0, hy, bw, 10, hp, HP_BANDS, TRACK)
	ticks(ci, o, s, x0, hy, bw, 10, 10)


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
	"slime": "SLIME", "vampire": "VAMPİR", "zombie": "ZOMBİ",
}


static func display_name(creature_id: String) -> String:
	var family: String = creature_id.rstrip("0123456789")
	return str(NAMES.get(family, family.to_upper()))
