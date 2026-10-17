extends Control

## PROTOTİP (2026-10-14, oyuna bağlı DEĞİL): ana panelin SOLUNA yapışık LoL tarzı mini stat paneli + portre altı aç/kapa
## düğmesi + üstte 1-2 sayfa sekmeleri. Çizen: stat_panel_proto.gd (gerçek hud.tscn'in üstüne yerleştirir).
## mode = "panel" (stat paneli + sekmeler) | "button" (portre altı düğme).

const PixelIcons := preload("res://scripts/hud_pixel_icons.gd")
const FONT: Font = preload("res://assets/fonts/PixeloidSans-Bold.ttf")
const FONT_PX := 9
const OUTLINE := Color("#1e120a")
const PLATE := Color(0.13, 0.08, 0.05)
const STRIPE := Color(0.17, 0.11, 0.07)
const VALUE := Color(0.97, 0.93, 0.84)

## En önemliden en önemsize; 8'li iki sayfa. [id, ad, değer, renk]
const STATS: Array = [
	["damage", "Saldırı Gücü", "86", Color(0.93, 0.45, 0.30)],
	["fire_rate", "Saldırı Hızı", "%45", Color(0.98, 0.82, 0.30)],
	["crit_chance", "Kritik Şansı", "%25", Color(0.95, 0.33, 0.30)],
	["crit_damage", "Kritik Hasarı", "%175", Color(1.0, 0.60, 0.20)],
	["cooldown_reduction", "Bekleme Azaltma", "%20", Color(0.55, 0.75, 1.0)],
	["lifesteal", "Can Çalma", "%6", Color(0.86, 0.16, 0.26)],
	["dodge", "Sıvışma", "%12", Color(0.75, 0.92, 0.95)],
	["speed", "Hareket Hızı", "96", Color(0.55, 0.85, 0.45)],
	["shield_pen_percent", "Kalkan Delme", "%15", Color(0.74, 0.70, 0.88)],
	["range", "Menzil", "%20", Color(0.86, 0.74, 0.52)],
	["shield_protection", "Mana Kalkanı Soğurma", "%60", Color(0.24, 0.59, 0.91)],
	["shield_amount", "Mana Kalkanı Miktarı", "%30", Color(0.24, 0.59, 0.91)],
	["shield_regen", "Mana Kalkanı Yenilenmesi", "3.5", Color(0.42, 0.82, 0.96)],
	["health_regen", "Can Yenilenmesi", "4.5", Color(0.90, 0.20, 0.28)],
	["heal_power", "İyileştirme Gücü", "%25", Color(0.35, 0.85, 0.45)],
	["luck", "Şans", "12", Color(0.30, 0.74, 0.32)],
]

## B: yeni 7x7 piksel simgeler (dış kontur kod ekler -> 9x9, 2x = 18 px).
const GLYPHS: Dictionary = {
	"damage": [".....XX", "....XXX", "X..XXX.", ".XXXX..", "..XX...", ".XX.X..", "XX....."],
	"fire_rate": ["X..X...", "XX.XX..", ".XX.XX.", "..XX.XX", ".XX.XX.", "XX.XX..", "X..X..."],
	"crit_chance": ["..XXX..", ".X...X.", "X..X..X", "X.XXX.X", "X..X..X", ".X...X.", "..XXX.."],
	"crit_damage": ["X..X..X", ".XXXXX.", ".XXXXX.", "XXXXXXX", ".XXXXX.", ".XXXXX.", "X..X..X"],
	"cooldown_reduction": ["XXXXXXX", ".XXXXX.", "..XXX..", "...X...", "..X.X..", ".XXXXX.", "XXXXXXX"],
	"lifesteal": ["...X...", "..XXX..", "..XXX..", ".XXXXX.", "XXXXXXX", "XXXXXXX", ".XXXXX."],
	"dodge": [".....XX", "...XXXX", ".XXXXX.", "XXXX...", "XXXXX..", ".XX....", "X......"],
	"speed": [".XXX...", ".XXX...", ".XXX...", ".XXXX..", ".XXXXXX", "XXXXXXX", "XXXXXXX"],
	"shield_pen_percent": ["XXXX.XX", "XXX.XXX", "XX.XXXX", "X.XXXXX", ".XXXXX.", "..XXX..", "...X..."],
	"range": ["...XXXX", "....XXX", "...XX.X", "..XX...", ".XX....", "XX.....", "X......"],
	"shield_protection": ["XXXXXXX", "XXXXXXX", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."],
	"shield_amount": ["XXXXXXX", "XXX.XXX", "X.....X", "XXX.XXX", ".XX.XX.", "..XXX..", "...X..."],
	"shield_regen": ["XXXXXXX", "XXX.XXX", "XX...XX", "XXX.XXX", ".XX.XX.", "..XXX..", "...X..."],
	"health_regen": [".XX.XX.", "XXXXXXX", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."],
	"heal_power": ["..XXX..", "..XXX..", "XXXXXXX", "XXXXXXX", "XXXXXXX", "..XXX..", "..XXX.."],
	"luck": [".XX.XX.", "XXXXXXX", ".XXXXX.", "XXXXXXX", ".XX.XX.", "....X..", ".....X."],
}
## A: aynı simgeyi paylaşan statlara sağ alt köşe işareti (3x3, 2x).
const MARKS: Dictionary = {
	"shield_amount": [".X.", "XXX", ".X."],
	"shield_regen": [".X.", "XXX", "X.X"],
	"heal_power": [".X.", "XXX", ".X."],
	"cooldown_reduction": ["XXX", ".X.", "XXX"],
}
const LEVEL_ICON := {
	"damage": "stat_damage", "fire_rate": "stat_fire_rate", "crit_chance": "stat_crit_chance", "crit_damage": "stat_crit_damage",
	"cooldown_reduction": "stat_speed", "lifesteal": "stat_lifesteal", "dodge": "stat_dodge", "speed": "stat_speed",
	"shield_pen_percent": "stat_armor_pen_percent", "range": "stat_range", "shield_protection": "stat_shield",
	"shield_amount": "stat_shield", "shield_regen": "stat_shield", "health_regen": "stat_max_health",
	"heal_power": "stat_max_health", "luck": "stat_luck",
}

const ICON := 18
## Sayılar ASLA panelden taşmaz (kullanıcı): sütun genişliği en geniş OLASI değere göre hesaplanır, panel ona göre genişler.
## Gerçek oyunda bu sınırı aşan değer kısaltılır (10000 -> "10k").
const WORST: Array[String] = ["%600", "%250", "9999", "999.9", "x9.99"]
const CELL_PAD := 2.0 ## hücre sol boşluğu, ikon-yazı arası ve sağ pay
const PLATE_INSET := 3.0
const PANEL_H := 140.0
const OVERLAP := 12.0 ## sağ kenar ana panelin altına girer (efsanevi panelin aynası)
const TAB_SIZE := Vector2(22, 18)

var mode: String = "panel"
var variant: String = "B"
var page: int = 0
var open: bool = true
var stress: bool = false ## değerler yerine WORST yazıları (taşma denetimi)
var _panel_box: StyleBox = null
var _icon_cache: Dictionary = {}


## Değer sütununun en geniş olası yazısı (piksel).
static func value_w() -> float:
	var w: float = 0.0
	for t in WORST:
		w = maxf(w, FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x)
	return ceilf(w)


static func col_w() -> float:
	return CELL_PAD + ICON + CELL_PAD + value_w() + CELL_PAD


## Panel: sol kenar 7 + levha (2 sütun + 2x içe pay) + 4 + ana panelin altına giren OVERLAP.
static func panel_size() -> Vector2:
	return Vector2(7.0 + 2.0 * col_w() + 2.0 * PLATE_INSET + 4.0 + OVERLAP, PANEL_H)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel_box = UIKit.panel_style("status_badge")


func _icon(id: String) -> Texture2D:
	if _icon_cache.has(id):
		return _icon_cache[id]
	var img: Image = (load("res://assets/ui/level_up_icons/%s.png" % LEVEL_ICON[id]) as Texture2D).get_image()
	img.convert(Image.FORMAT_RGBA8)
	var r: Rect2i = img.get_used_rect()
	var side: int = maxi(r.size.x, r.size.y)
	var sq := Image.create(side, side, false, Image.FORMAT_RGBA8)
	sq.blit_rect(img, r, Vector2i((side - r.size.x) / 2, (side - r.size.y) / 2))
	sq.resize(ICON, ICON, Image.INTERPOLATE_LANCZOS)
	var t := ImageTexture.create_from_image(sq)
	_icon_cache[id] = t
	return t


## Dış konturlu, üç tonlu 2x piksel simge (kontur şeklin DIŞINA eklenir; içteki boşluklar da koyu kalır).
func _glyph(rows: Array, pos: Vector2, px: float, base: Color) -> void:
	var h: int = rows.size()
	var w: int = (rows[0] as String).length()
	var filled := func(x: int, y: int) -> bool:
		return y >= 0 and y < h and x >= 0 and x < w and (rows[y] as String)[x] == "X"
	for y in range(-1, h + 1):
		for x in range(-1, w + 1):
			var r := Rect2(pos + Vector2(x + 1, y + 1) * px, Vector2(px, px))
			if filled.call(x, y):
				var c: Color = base
				if not filled.call(x - 1, y) or not filled.call(x, y - 1):
					c = base.lightened(0.35)
				elif not filled.call(x + 1, y) or not filled.call(x, y + 1):
					c = base.darkened(0.3)
				draw_rect(r, c)
			elif filled.call(x - 1, y) or filled.call(x + 1, y) or filled.call(x, y - 1) or filled.call(x, y + 1):
				draw_rect(r, OUTLINE)


func _text(pos: Vector2, s: String, col: Color) -> void:
	draw_string_outline(FONT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, 2, OUTLINE)
	draw_string(FONT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, col)


func _draw() -> void:
	if mode == "button":
		_draw_button()
	elif open:
		_draw_panel()


func _draw_tab(r: Rect2, label: String, active: bool) -> void:
	## Sekme: üst köşeleri kesik ahşap dil; etkin olan panelle birleşir (alt çizgisi yok), etkin olmayan koyu.
	var fill: Color = Color(0.78, 0.6, 0.38) if active else Color(0.42, 0.29, 0.17)
	draw_rect(Rect2(r.position + Vector2(2, 0), Vector2(r.size.x - 4, r.size.y)), OUTLINE)
	draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, r.size.y - 2)), OUTLINE)
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 2 if active else 4)), fill)
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 2)), fill.lightened(0.25))
	var tw: float = FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x
	_text(r.position + Vector2(roundf((r.size.x - tw) * 0.5), 13), label, VALUE if active else Color(0.75, 0.66, 0.55))


func _draw_panel() -> void:
	var p := Vector2(0, TAB_SIZE.y - 4) ## panelin sol üstü (sekmeler üstünde, 4 px panele biner)
	## Sekmeler önce: etkin sekme panelin üst kenarına biner.
	for i in 2:
		if i != page:
			_draw_tab(Rect2(Vector2(10 + i * (TAB_SIZE.x + 2), 0), TAB_SIZE), str(i + 1), false)
	draw_style_box(_panel_box, Rect2(p, panel_size()))
	_draw_tab(Rect2(Vector2(10 + page * (TAB_SIZE.x + 2), 0), TAB_SIZE + Vector2(0, 4)), str(page + 1), true)
	var ps: Vector2 = panel_size()
	var plate := Rect2(p + Vector2(7, 7), Vector2(ps.x - OVERLAP - 11, ps.y - 14))
	PixelIcons.draw_plate(self, plate, PLATE)
	var inner: Rect2 = plate.grow(-PLATE_INSET)
	var cw: float = col_w()
	var row_h: float = floorf(inner.size.y / 4.0)
	if variant == "A":
		for r in 4:
			if r % 2 == 1:
				draw_rect(Rect2(inner.position + Vector2(0, r * row_h), Vector2(inner.size.x, row_h)), STRIPE)
	else:
		draw_rect(Rect2(inner.position + Vector2(cw - 1, 2), Vector2(2, inner.size.y - 4)), STRIPE)
	for k in 8:
		var s: Array = STATS[page * 8 + k]
		var cell := Vector2(inner.position.x + (k % 2) * cw, inner.position.y + (k / 2) * row_h)
		var icon_pos := cell + Vector2(CELL_PAD, roundf((row_h - ICON) * 0.5))
		if variant == "A":
			draw_texture(_icon(s[0]), icon_pos)
			if MARKS.has(s[0]):
				_glyph(MARKS[s[0]], icon_pos + Vector2(ICON - 8, ICON - 8), 2.0, s[3])
		else:
			_glyph(GLYPHS[s[0]], icon_pos, 2.0, s[3])
		_text(cell + Vector2(CELL_PAD + ICON + CELL_PAD, roundf(row_h * 0.5) + 4), WORST[k % WORST.size()] if stress else str(s[2]), VALUE)


func _draw_button() -> void:
	## Portre altı düğme: 64x20 koyu levha. A = "STAT" yazısı + ok; B = küçük çubuk grafik simgesi + ok. Açıkken basılı (1 px aşağı, parlak).
	var r := Rect2(Vector2.ZERO, size)
	var d := Vector2(0, 1) if open else Vector2.ZERO
	PixelIcons.draw_plate(self, r, Color(0.2, 0.13, 0.08) if open else PLATE)
	draw_rect(Rect2(Vector2(2, 2), Vector2(r.size.x - 4, 1)), Color(0.36, 0.25, 0.15) if not open else Color(0.98, 0.82, 0.3, 0.55))
	var arrow: Array[String] = ["..X", ".XX", "XXX", ".XX", "..X"]
	if open:
		arrow = ["X..", "XX.", "XXX", "XX.", "X.."]
	var gold := Color(0.98, 0.82, 0.30)
	if variant == "A":
		_text(Vector2(17, 14) + d, "STAT", gold if open else VALUE)
		PixelIcons.draw_flat(self, arrow, Vector2(7, 5) + d, 2.0, gold)
	else:
		var bars: Array = [4, 8, 6, 11]
		for i in bars.size():
			var h: int = bars[i]
			draw_rect(Rect2(Vector2(25 + i * 5, 15 - h) + d, Vector2(4, h)), OUTLINE)
			draw_rect(Rect2(Vector2(26 + i * 5, 16 - h) + d, Vector2(2, h - 2)), gold if open else VALUE)
		PixelIcons.draw_flat(self, arrow, Vector2(9, 5) + d, 2.0, gold)
