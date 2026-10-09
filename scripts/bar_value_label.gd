extends Control

## Çubuğun İÇİNE ortalanmış, piksel-net "şimdiki/en çok" sayısı (grup paneli can/kalkan çubukları, bkz. party_panel.gd _add_bar_label).
## NEDEN Label DEĞİL (kullanıcı 2026-10-09: "sayıların konumu biraz aşağıda kalmış, zor okunuyor, çubuklara sığmıyor"): Label satır yüksekliğine göre
## ortalanır, m5x7'nin boşluğu yüzünden yazı ~2-3 px aşağı oturuyordu ve 24 punto (1,5 kat) piksel yazıyı bulandırıyordu. Burada yazı kendi taban çizgisiyle
## (çubuk ortası + büyük harf yüksekliğinin yarısı), TAM sayı katında (32 = 2x) ve tam piksele yuvarlanarak çizilir; sığmazsa 24 -> 16'ya düşer.
## Anahat koyu kahve (HUD sayılarıyla aynı dil), yazı beyaz.

const FONT_PATH := "res://assets/fonts/m5x7.ttf"
const SIZES: Array[int] = [32, 24, 16] ## 2x, 1,5x, 1x - hep en büyük sığan seçilir
const CAP_RATIO := 7.0 / 16.0 ## m5x7: 16 punto = büyük harf/rakam 7 px
const PAD_X := 8.0 ## çubuğun iki yanında bırakılan boşluk (panelde çubuk 130 px: 9 karaktere kadar 2x, "9999/10000" 1,5x)
const PAD_Y := 4.0 ## yazının üstünde+altında (anahat dahil) bırakılan boşluk
const TEXT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const OUTLINE_COLOR := Color(0.12, 0.06, 0.03, 1.0)

static var _font: Font = null

var text: String = "":
	set(v):
		if v != text:
			text = v
			queue_redraw()


static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) as Font
	return _font


## Yazı için en büyük sığan punto: genişlik avail_w içinde, büyük harf yüksekliği + PAD_Y avail_h içinde. Hiçbiri sığmazsa en küçüğü.
static func pick_size(str_: String, avail_w: float, avail_h: float) -> int:
	for fs in SIZES:
		var w: float = font().get_string_size(str_, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if w <= avail_w and roundf(float(fs) * CAP_RATIO) + PAD_Y <= avail_h:
			return fs
	return SIZES[SIZES.size() - 1]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if text.is_empty():
		return
	var fs: int = pick_size(text, size.x - PAD_X * 2.0, size.y)
	var f: Font = font()
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var cap: float = roundf(float(fs) * CAP_RATIO)
	## Taban çizgisi: büyük harfin (rakamın) üstü çubuk ortasının cap/2 üstünde, altı cap/2 altında.
	var pos := Vector2(roundf((size.x - tw) * 0.5), roundf((size.y + cap) * 0.5))
	var outline: int = maxi(1, int(roundf(float(fs) / 16.0)))
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, OUTLINE_COLOR)
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT_COLOR)
