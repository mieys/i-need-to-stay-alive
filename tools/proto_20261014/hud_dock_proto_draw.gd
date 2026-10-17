extends Control

## Oyuncu paneli (dock) yeniden tasarım PROTOTİPLERİ - sadece çizim, oyuna bağlı değil (2026-10-14).
## 4 seçenek x 2 durum (normal / can az + kalp yenileniyor + Q beklemede). Ölçüler 1920x1080 EKRAN pikseli, ölçeksiz:
## yazılar piksel yazı tipinin tam katında (m5x7 = 16 katları, PixeloidSans = 9 katları) - bulanıklığın sebebi kesirli ölçekti.

const HEART_ROWS: Array[String] = ["..XXX.XXX..", ".XXXXXXXXX.", "XXXXXXXXXXX", "XXXXXXXXXXX", "XXXXXXXXXXX", ".XXXXXXXXX.",
	"..XXXXXXX..", "...XXXXX...", "....XXX....", ".....X....."]
const SHIELD_ROWS: Array[String] = ["XXXXXXXXXXX", "XXXXXXXXXXX", "XXXXXXXXXXX", "XXXXXXXXXXX", "XXXXXXXXXXX", ".XXXXXXXXX.",
	".XXXXXXXXX.", "..XXXXXXX..", "...XXXXX...", "....XXX...."]
const INK := Color("#1e120a")
const CREAM := Color("#fff0d6")
const DIM := Color("#c9b592")
const PLATE := Color("#2b1b11")
const HP_OK := Color(0.36, 0.78, 0.29)
const HP_LOW := Color(0.86, 0.24, 0.22)
const SHIELD := Color(0.24, 0.59, 0.91)
const TIMER := Color(1.0, 0.78, 0.8)
const REGEN_TOTAL := 300.0

var f_m: Font = load("res://assets/fonts/m5x7.ttf")
var f_p: Font = load("res://assets/fonts/PixeloidSans-Bold.ttf")
var t_frame: Texture2D = load("res://assets/ui/kit/hud_skill_frame.png")
var t_small: Texture2D = load("res://assets/ui/kit/hud_skill_frame_small.png")
var t_avatar: Texture2D = load("res://assets/ui/kit/hud_avatar_frame.png")
var t_avatar_bg: Texture2D = load("res://assets/ui/kit/hud_avatar_bg.png")
var t_badge: Texture2D = load("res://assets/ui/kit/hud_level_badge.png")
var sb_panel: StyleBox
var sb_tab: StyleBox
var icons: Dictionary = {}
var t_portrait: Texture2D
var states: Array = [
	{"hp": 1284, "hpmax": 2150, "sh": 356, "shmax": 900, "hearts": 2, "regen": -1.0, "cd": ""},
	{"hp": 312, "hpmax": 2150, "sh": 0, "shmax": 900, "hearts": 0, "regen": 187.0, "cd": "8"},
]


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sb_panel = UIKit.panel_style("ability_bar")
	sb_tab = UIKit.panel_style("status_badge")
	var def: Dictionary = Characters.get_def(0)
	for k: String in ["skill_icon", "skill2_icon", "skill3_icon", "passive_icon"]:
		icons[k] = load(str(def[k]))
	t_portrait = load(str(def["portrait"]))
	queue_redraw()


func _cap(font: Font, size: int) -> float:
	return float(size) * (7.0 / 16.0 if font == f_m else 7.0 / 9.0)


func _w(font: Font, s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Yazı: (x, dikey orta) - rakamların görsel ortası cy'ye gelir.
func _txt(font: Font, x: float, cy: float, s: String, size: int, col: Color, outline: int = 4) -> float:
	var p := Vector2(roundf(x), roundf(cy + _cap(font, size) * 0.5))
	if outline > 0:
		draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline * 2, INK)
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	return _w(font, s, size)


func _txt_c(font: Font, r: Rect2, s: String, size: int, col: Color, outline: int = 4) -> void:
	_txt(font, r.position.x + (r.size.x - _w(font, s, size)) * 0.5, r.position.y + r.size.y * 0.5, s, size, col, outline)


func _in(rows: Array[String], x: int, y: int) -> bool:
	return y >= 0 and y < rows.size() and x >= 0 and x < rows[y].length() and rows[y][x] == "X"


func _pix(rows: Array[String], pos: Vector2, px: float, base: Color, light: Color, shade: Color, fill: float = 1.0, empty: bool = false) -> void:
	var h: int = rows.size()
	for y in h:
		for x in rows[y].length():
			if not _in(rows, x, y):
				continue
			var edge: bool = not (_in(rows, x - 1, y) and _in(rows, x + 1, y) and _in(rows, x, y - 1) and _in(rows, x, y + 1))
			var c: Color = base
			if edge:
				c = INK
			elif empty and float(h - y) > fill * float(h):
				c = Color(0.34, 0.31, 0.36) if x + y <= 5 else Color(0.2, 0.18, 0.22)
			elif not _in(rows, x + 2, y) or not _in(rows, x, y + 2):
				c = shade
			elif x + y <= 5:
				c = light
			draw_rect(Rect2(pos + Vector2(x, y) * px, Vector2(px, px)), c)


func _heart(pos: Vector2, px: float, active: bool, fill: float = 0.0) -> void:
	if active:
		_pix(HEART_ROWS, pos, px, Color(0.9, 0.2, 0.28), Color(1.0, 0.46, 0.5), Color(0.62, 0.09, 0.19))
	else:
		_pix(HEART_ROWS, pos, px, Color(0.78, 0.34, 0.42), Color(0.78, 0.34, 0.42), Color(0.78, 0.34, 0.42), fill, true)


func _shield_icon(pos: Vector2, px: float) -> void:
	_pix(SHIELD_ROWS, pos, px, SHIELD, SHIELD.lightened(0.4), SHIELD.darkened(0.35))


func _plate(r: Rect2, col: Color = PLATE) -> void:
	draw_rect(Rect2(r.position + Vector2(2, 0), r.size - Vector2(4, 0)), INK)
	draw_rect(Rect2(r.position + Vector2(0, 2), r.size - Vector2(0, 4)), INK)
	draw_rect(r.grow(-2), col)


func _bar(r: Rect2, ratio: float, fill: Color) -> void:
	_plate(r, Color(0.13, 0.08, 0.05))
	var inner := r.grow(-2)
	var w: float = roundf(inner.size.x * clampf(ratio, 0.0, 1.0) / 2.0) * 2.0
	if w > 0.0:
		draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), fill)
		draw_rect(Rect2(inner.position, Vector2(w, 2)), fill.lightened(0.35))
		draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 2), Vector2(w, 2)), fill.darkened(0.3))


func _slot(r: Rect2, key: String, label: String, cd: String = "") -> void:
	var small: bool = r.size.x < 48.0
	var b: float = r.size.x * (4.0 / 32.0 if small else 7.0 / 52.0)
	draw_texture_rect(icons[key], r.grow(-b + 1.0), false)
	if cd != "":
		draw_rect(r.grow(-b + 1.0), Color(0.05, 0.03, 0.02, 0.72))
	draw_texture_rect(t_small if small else t_frame, r, false)
	if cd != "":
		_txt_c(f_m, r, cd, 48, CREAM, 4)
	if label != "":
		_txt(f_m, r.end.x - 15.0, r.end.y - 11.0, label, 32, Color("#ffe9a8"), 3)


func _portrait(r: Rect2) -> void:
	var k: float = r.size.x / 96.0
	var clip := Rect2(r.position + Vector2(12, 12) * k, Vector2(72, 72) * k)
	draw_texture_rect(t_avatar_bg, clip, false)
	var ts: Vector2 = t_portrait.get_size()
	var s: float = minf(clip.size.x / ts.x, clip.size.y / ts.y)
	draw_texture_rect(t_portrait, Rect2(roundf(clip.position.x + (clip.size.x - ts.x * s) * 0.5), roundf(clip.end.y - ts.y * s), ts.x * s, ts.y * s), false)
	draw_texture_rect(t_avatar, r, false)


func _badge(r: Rect2, lvl: String, size: int = 32) -> void:
	draw_texture_rect(t_badge, r, false)
	_txt_c(f_m, r, lvl, size, Color("#3a2212"), 0)


func _hp_col(st: Dictionary) -> Color:
	return HP_LOW if float(st["hp"]) / float(st["hpmax"]) < 0.3 else HP_OK


func _clock(sec: float) -> String:
	var s: int = int(ceil(sec))
	return "%d:%02d" % [s / 60, s % 60]


func _regen_fill(i: int, regen: float) -> float:
	return (1.0 - regen / REGEN_TOTAL) if (i == 0 and regen >= 0.0) else 0.0


func _skills(o: Vector2, x0: float, pitch: float, y: float, st: Dictionary) -> void:
	var keys: Array = [["skill_icon", "Q"], ["skill2_icon", "E"], ["skill3_icon", "R"]]
	for i in 3:
		_slot(Rect2(o + Vector2(x0 + float(i) * pitch, y), Vector2(56, 56)), keys[i][0], keys[i][1], str(st["cd"]) if i == 0 else "")


func _divider(o: Vector2, x: float, y: float, h: float) -> void:
	draw_rect(Rect2(o + Vector2(x, y), Vector2(2, h)), Color(0.23, 0.13, 0.07, 0.55))


func _draw() -> void:
	var names: Array = ["A", "B", "C", "D"]
	for v in 4:
		var y: float = 110.0 + float(v) * 245.0
		_txt(f_m, 150.0, y + 70.0, names[v], 96, CREAM, 4)
		for s in 2:
			var o := Vector2(250.0 + float(s) * 760.0, y)
			call("_draw_" + ["a", "b", "c", "d"][v], o, states[s])


## A: bugünkü yerleşim; sayılar keskin + büyük, pasif küçük, kalp sekmesinde dev sayaç.
func _draw_a(o: Vector2, st: Dictionary) -> void:
	var regen: float = float(st["regen"])
	var tab_w: float = 100.0 + (96.0 if regen >= 0.0 else 0.0)
	draw_style_box(sb_tab, Rect2(o + Vector2(10, -38), Vector2(tab_w, 46)))
	draw_style_box(sb_panel, Rect2(o, Vector2(404, 152)))
	for i in 3:
		_heart(o + Vector2(22 + i * 26, -28), 2.0, i < int(st["hearts"]), _regen_fill(i, regen))
	if regen >= 0.0:
		_txt(f_m, o.x + 108.0, o.y - 18.0, _clock(regen), 48, TIMER, 4)
	_portrait(Rect2(o + Vector2(14, 12), Vector2(84, 84)))
	_badge(Rect2(o + Vector2(34, 74), Vector2(44, 44)), "12")
	_slot(Rect2(o + Vector2(126, 24), Vector2(36, 36)), "passive_icon", "")
	_divider(o, 177, 20, 44)
	_skills(o, 196, 68, 14, st)
	var hp := Rect2(o + Vector2(112, 78), Vector2(276, 30))
	_bar(hp, float(st["hp"]) / float(st["hpmax"]), _hp_col(st))
	_txt_c(f_m, hp, "%d/%d" % [st["hp"], st["hpmax"]], 32, CREAM, 4)
	var sh := Rect2(o + Vector2(112, 111), Vector2(276, 26))
	_bar(sh, float(st["sh"]) / float(st["shmax"]), SHIELD)
	_txt_c(f_m, sh, "%d/%d" % [st["sh"], st["shmax"]], 32, CREAM, 4)


## B: sayılar barın yanında koyu levhada (dolgu rengi yazıyı hiç bozmaz), kalpler + sayaç panelin içinde.
func _draw_b(o: Vector2, st: Dictionary) -> void:
	var regen: float = float(st["regen"])
	draw_style_box(sb_panel, Rect2(o, Vector2(472, 152)))
	_portrait(Rect2(o + Vector2(14, 12), Vector2(84, 84)))
	_badge(Rect2(o + Vector2(34, 74), Vector2(44, 44)), "12")
	_skills(o, 112, 68, 14, st)
	_divider(o, 314, 20, 44)
	_slot(Rect2(o + Vector2(326, 24), Vector2(36, 36)), "passive_icon", "")
	for i in 3:
		_heart(o + Vector2(378 + i * 26, 16), 2.0, i < int(st["hearts"]), _regen_fill(i, regen))
	if regen >= 0.0:
		var tp := Rect2(o + Vector2(376, 42), Vector2(80, 28))
		_plate(tp)
		_txt_c(f_p, tp, _clock(regen), 18, TIMER, 0)
	var rows: Array = [[78.0, 30.0, "hp", "hpmax"], [112.0, 26.0, "sh", "shmax"]]
	for row: Array in rows:
		var is_hp: bool = row[2] == "hp"
		var cy: float = o.y + float(row[0]) + float(row[1]) * 0.5
		if is_hp:
			_heart(Vector2(o.x + 112, cy - 10), 2.0, true)
		else:
			_shield_icon(Vector2(o.x + 112, cy - 10), 2.0)
		_bar(Rect2(o + Vector2(140, row[0]), Vector2(166, row[1])), float(st[row[2]]) / float(st[row[3]]), _hp_col(st) if is_hp else SHIELD)
		var pl := Rect2(o + Vector2(312, row[0]), Vector2(144, row[1]))
		_plate(pl)
		var cur: String = str(st[row[2]])
		var mx: String = "/" + str(st[row[3]])
		var x: float = pl.end.x - 8.0 - _w(f_p, cur + mx, 18)
		x += _txt(f_p, x, cy, cur, 18, CREAM if is_hp else Color("#bfe0ff"), 0)
		_txt(f_p, x, cy, mx, 18, DIM, 0)


## C: barlar üstte panel boyunca; mevcut can DEV rakamla, azami küçük.
func _draw_c(o: Vector2, st: Dictionary) -> void:
	var regen: float = float(st["regen"])
	draw_style_box(sb_panel, Rect2(o, Vector2(440, 170)))
	var hp := Rect2(o + Vector2(16, 14), Vector2(408, 36))
	_bar(hp, float(st["hp"]) / float(st["hpmax"]), _hp_col(st))
	_heart(hp.position + Vector2(8, 8), 2.0, true)
	var x: float = hp.position.x + 38.0
	x += _txt(f_m, x, hp.get_center().y, str(st["hp"]), 48, CREAM, 4)
	_txt(f_m, x + 2.0, hp.get_center().y + 3.0, "/" + str(st["hpmax"]), 32, DIM, 4)
	var sh := Rect2(o + Vector2(16, 53), Vector2(408, 24))
	_bar(sh, float(st["sh"]) / float(st["shmax"]), SHIELD)
	_shield_icon(sh.position + Vector2(8, 2), 2.0)
	_txt(f_m, sh.position.x + 38.0, sh.get_center().y, "%d/%d" % [st["sh"], st["shmax"]], 32, CREAM, 4)
	_portrait(Rect2(o + Vector2(16, 84), Vector2(72, 72)))
	_badge(Rect2(o + Vector2(60, 122), Vector2(40, 40)), "12")
	_slot(Rect2(o + Vector2(108, 102), Vector2(36, 36)), "passive_icon", "")
	_divider(o, 153, 98, 44)
	_skills(o, 164, 64, 92, st)
	for i in 3:
		_heart(o + Vector2(354 + i * 24, 92), 2.0, i < int(st["hearts"]), _regen_fill(i, regen))
	if regen >= 0.0:
		_txt_c(f_m, Rect2(o + Vector2(352, 118), Vector2(72, 34)), _clock(regen), 48, TIMER, 4)


## D: tek bar (can + üstünde mavi kalkan şeridi), sayılar altta ayrı levhalarda; pasif portrenin altında, kalpler sağ sütunda.
func _draw_d(o: Vector2, st: Dictionary) -> void:
	var regen: float = float(st["regen"])
	draw_style_box(sb_panel, Rect2(o, Vector2(470, 152)))
	_portrait(Rect2(o + Vector2(14, 10), Vector2(84, 84)))
	_badge(Rect2(o + Vector2(10, 98), Vector2(44, 44)), "12")
	_slot(Rect2(o + Vector2(60, 102), Vector2(36, 36)), "passive_icon", "")
	_skills(o, 144, 76, 12, st)
	var bar := Rect2(o + Vector2(116, 74), Vector2(266, 24))
	_bar(bar, float(st["hp"]) / float(st["hpmax"]), _hp_col(st))
	var shw: float = roundf((bar.size.x - 4.0) * float(st["sh"]) / float(st["shmax"]) / 2.0) * 2.0
	if shw > 0.0:
		draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2(shw, 8)), SHIELD)
		draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2(shw, 2)), SHIELD.lightened(0.4))
		draw_rect(Rect2(bar.position + Vector2(2, 10), Vector2(shw, 2)), INK)
	var p1 := Rect2(o + Vector2(116, 102), Vector2(148, 36))
	var p2 := Rect2(o + Vector2(268, 102), Vector2(114, 36))
	_plate(p1)
	_plate(p2)
	_heart(p1.position + Vector2(8, 8), 2.0, true)
	var x: float = p1.position.x + 36.0
	x += _txt(f_m, x, p1.get_center().y, str(st["hp"]), 32, CREAM, 0)
	_txt(f_m, x, p1.get_center().y, "/" + str(st["hpmax"]), 32, DIM, 0)
	_shield_icon(p2.position + Vector2(6, 8), 2.0)
	x = p2.position.x + 32.0
	x += _txt(f_m, x, p2.get_center().y, str(st["sh"]), 32, Color("#bfe0ff"), 0)
	_txt(f_m, x, p2.get_center().y, "/" + str(st["shmax"]), 32, DIM, 0)
	_divider(o, 392, 16, 120)
	for i in 3:
		_heart(o + Vector2(416, 12 + i * 24), 2.0, i < int(st["hearts"]), _regen_fill(i, regen))
	if regen >= 0.0:
		var tp := Rect2(o + Vector2(400, 102), Vector2(56, 36))
		_plate(tp)
		_txt_c(f_m, tp, _clock(regen), 32, TIMER, 0)
