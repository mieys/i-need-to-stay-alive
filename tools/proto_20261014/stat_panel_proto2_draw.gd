extends Control

## PROTOTİP 2 (2026-10-14, oyuna bağlı DEĞİL): mini stat paneli, 32x32 yeni simgelerle (gen_stat_icons32.py -> out/stat_ikon32/).
## Kullanıcı: "2 güzel ama ikonlar daha anlaşılır, iyi piksel sanatı olsun" + "16x16 değil 32x32, çok ruhsuz".
## Simge 1:1 (32 px) çizilir; panel 4 satır x 36 px -> efsanevi panelden uzun, ALTI efsanevi panelle hizalı, yukarı uzar.
## Yazı PixeloidSans-Bold tam katında: font_px 9 (küçük) ya da 18 (can/kalkan çubuğundaki sayılarla aynı).
## Sayılar ASLA taşmaz: sütun genişliği WORST'teki en geniş olası yazıdan hesaplanır.

const PixelIcons := preload("res://scripts/hud_pixel_icons.gd")
const FONT: Font = preload("res://assets/fonts/PixeloidSans-Bold.ttf")
const OUTLINE := Color("#1e120a")
const PLATE := Color(0.13, 0.08, 0.05)
const STRIPE := Color(0.18, 0.12, 0.075)
const VALUE := Color(0.97, 0.93, 0.84)
const INSET := 3.0 ## levha içi pay
const EDGE := 7.0 ## ahşap kenar -> levha
const OVERLAP := 12.0 ## sağ kenar ana panelin altına girer
const TAB_SIZE := Vector2(20, 16)
const TAB_BITE := 4.0 ## sekme panelin üst kenarına bu kadar biner
const WORST: Array[String] = ["%600", "%250", "9999", "999.9", "x9.99"]

## En önemliden en önemsize; 8'li iki sayfa. [id, değer]
const STATS: Array = [
	["damage", "86"], ["fire_rate", "%45"], ["crit_chance", "%25"], ["crit_damage", "%175"],
	["cooldown_reduction", "%20"], ["lifesteal", "%6"], ["dodge", "%12"], ["speed", "96"],
	["shield_pen_percent", "%15"], ["range", "%20"], ["shield_protection", "%60"], ["shield_amount", "%30"],
	["shield_regen", "3.5"], ["health_regen", "4.5"], ["heal_power", "%25"], ["luck", "12"],
]

var mode: String = "panel" ## "panel" | "button"
var icon_dir: String = "res://tools/proto_20261014/out/stat_ikon32/" ## add_child'ten ÖNCE ayarlanır
var font_px: int = 9
var icon_px: float = 32.0 ## simge 1:1 (32 / 24 / 20 ayrı ayrı ÇİZİLMİŞ sayfalar)
var page: int = 0
var open: bool = true
var stress: bool = false
var _panel_box: StyleBox = null
var _tex: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel_box = UIKit.panel_style("status_badge")
	for s in STATS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(icon_dir + str(s[0]) + ".png"))
		_tex[s[0]] = ImageTexture.create_from_image(img)


func row_h() -> float:
	return icon_px + 4.0


func pad() -> float:
	return 2.0 if icon_px <= 24.0 else 3.0


func gap() -> float:
	return 3.0 if icon_px <= 24.0 else 4.0


func value_w() -> float:
	var w: float = 0.0
	for t in WORST:
		w = maxf(w, FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x)
	return ceilf(w)


func col_w() -> float:
	return pad() + icon_px + gap() + value_w() + pad()


func plate_size() -> Vector2:
	return Vector2(2.0 * col_w() + 2.0 * INSET, 4.0 * row_h() + 2.0 * INSET)


## Ahşap panelin boyutu (sekmeler HARİÇ).
func panel_size() -> Vector2:
	var ps: Vector2 = plate_size()
	return Vector2(EDGE + ps.x + 4.0 + OVERLAP, EDGE + ps.y + EDGE)


func _text(pos: Vector2, s: String, col: Color) -> void:
	var o: int = 2 if font_px <= 9 else 6
	draw_string_outline(FONT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, o, OUTLINE)
	draw_string(FONT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, col)


func _draw() -> void:
	if mode == "button":
		_draw_button()
	elif open:
		_draw_panel()


func _draw_tab(r: Rect2, label: String, active: bool) -> void:
	var fill: Color = Color(0.78, 0.6, 0.38) if active else Color(0.42, 0.29, 0.17)
	draw_rect(Rect2(r.position + Vector2(2, 0), Vector2(r.size.x - 4, r.size.y)), OUTLINE)
	draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, r.size.y - 2)), OUTLINE)
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 2 if active else 4)), fill)
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 2)), fill.lightened(0.25))
	var tw: float = FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string_outline(FONT, r.position + Vector2(roundf((r.size.x - tw) * 0.5), 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 2, OUTLINE)
	draw_string(FONT, r.position + Vector2(roundf((r.size.x - tw) * 0.5), 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			VALUE if active else Color(0.75, 0.66, 0.55))


func _draw_panel() -> void:
	var p := Vector2(0, TAB_SIZE.y - TAB_BITE)
	for i in 2:
		if i != page:
			_draw_tab(Rect2(Vector2(10 + i * (TAB_SIZE.x + 2), 0), TAB_SIZE), str(i + 1), false)
	draw_style_box(_panel_box, Rect2(p, panel_size()))
	_draw_tab(Rect2(Vector2(10 + page * (TAB_SIZE.x + 2), 0), TAB_SIZE + Vector2(0, TAB_BITE)), str(page + 1), true)
	var plate := Rect2(p + Vector2(EDGE, EDGE), plate_size())
	PixelIcons.draw_plate(self, plate, PLATE)
	var inner: Rect2 = plate.grow(-INSET)
	var cw: float = col_w()
	draw_rect(Rect2(inner.position + Vector2(cw - 1, 3), Vector2(2, inner.size.y - 6)), STRIPE)
	var rh: float = row_h()
	for r in range(1, 4):
		draw_rect(Rect2(inner.position + Vector2(3, r * rh), Vector2(inner.size.x - 6, 1)), STRIPE)
	var asc: float = FONT.get_ascent(font_px)
	for k in 8:
		var s: Array = STATS[page * 8 + k]
		var cell := Vector2(inner.position.x + (k % 2) * cw, inner.position.y + (k / 2) * rh)
		draw_texture(_tex[s[0]], cell + Vector2(pad(), roundf((rh - icon_px) * 0.5)))
		## Rakam yüksekliği ~ ascent x 0,78 (PixeloidSans) - satırın ortasına otursun.
		var base_y: float = cell.y + roundf(rh * 0.5 + asc * 0.39)
		_text(Vector2(cell.x + pad() + icon_px + gap(), base_y), WORST[k % WORST.size()] if stress else str(s[1]), VALUE)


func _draw_button() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var d := Vector2(0, 1) if open else Vector2.ZERO
	PixelIcons.draw_plate(self, r, Color(0.2, 0.13, 0.08) if open else PLATE)
	draw_rect(Rect2(Vector2(2, 2), Vector2(r.size.x - 4, 1)), Color(0.98, 0.82, 0.3, 0.55) if open else Color(0.36, 0.25, 0.15))
	var arrow: Array[String] = ["..X", ".XX", "XXX", ".XX", "..X"]
	if open:
		arrow = ["X..", "XX.", "XXX", "XX.", "X.."]
	var gold := Color(0.98, 0.82, 0.30)
	var bars: Array = [4, 8, 6, 11]
	for i in bars.size():
		var h: int = bars[i]
		draw_rect(Rect2(Vector2(25 + i * 5, 15 - h) + d, Vector2(4, h)), OUTLINE)
		draw_rect(Rect2(Vector2(26 + i * 5, 16 - h) + d, Vector2(2, h - 2)), gold if open else VALUE)
	PixelIcons.draw_flat(self, arrow, Vector2(9, 5) + d, 2.0, gold)
