extends RefCounted

## KOYU MENÜ KİTİ (2026-10-16): kullanıcının seçtiği "SEÇİM D" prototipinin (tools/proto_20261016/menu_proto.gd) görünümü oyunda.
## Gece ormanı paleti (koyu yeşil-camgöbeği paneller, nane vurgu), m5x7 yazı, 45° pahlı piksel köşe (corner_detail = 1), metin gölgesi.
## Bej MenuKit'in (menu_kit.gd) yerine geçmez; çok oyunculu karakter seçimi (lobby_select_desktop.gd) ve ana menü (main_menu.gd, kehribar paletiyle) kullanır.
## Hepsi statik: const DarkKit := preload("res://scripts/menu_dark_kit.gd").

## Dış paneller hafif saydam (2026-10-16): arkadaki ana menü sahnesi ("Ocak Başı", menu_hearth_bg.gd) seçilsin. İç kutular/karolar opak.
const C_PANEL := Color("#362317e6")
const C_PANEL2 := Color("#432c1d")
const C_PANEL3 := Color("#573924")
const C_INSET := Color("#20140c")
const C_LINE := Color("#684528")
const C_LINE_HI := Color("#9a6b44")
const C_TEXT := Color("#f6e7cf")
const C_DIM := Color("#c4a283")
const C_ACCENT := Color("#f29c4c")
const C_ACCENT_DK := Color("#7a3814")
const C_ACCENT_TEXT := Color("#2b1004")
const C_GOOD := Color("#c2d27a")
const C_BAD := Color("#e2705a")
const C_PRICE := Color("#f6d58a")
const C_SPOT := Color("#d27a36")
## Oyuncu renkleri (kart şeridi, karakter kartı köşe işareti, sohbet adı); sıra = peer kimliği sırası.
const PLAYER_COLORS := [Color("#e8c26a"), Color("#7fd0d8"), Color("#e58f9e"), Color("#a99be6"),
		Color("#9fd38a"), Color("#f0a46a"), Color("#d9a0e0"), Color("#8fb4f0")]

const FS_SMALL := 16
const FS_LABEL := 24
const FS_BODY := 32
const FS_TITLE := 48

const G_CHECK := ["......#", ".....##", "#...##.", "##.##..", ".###...", "..#...."]
const G_LOCK := ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]
const G_LEFT := ["..#", ".##", "###", ".##", "..#"]
const G_DOWN := ["#####", ".###.", "..#.."]
const G_PERSON := ["..###..", "..###..", "..###..", ".......", ".#####.", "#######", "#######"]
const G_GLOBE := [".#####.", "#..#..#", "#######", "#..#..#", "#######", "#..#..#", ".#####."]
const G_CROWN := ["#..#..#", "##.#.##", "#######", "#######", ".#####."]
const G_DOTS := ["##..##..##", "##..##..##"]
const G_X := ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"]
const G_QMARK := [".####.", "##..##", "....##", "...##.", "..##..", "......", "..##.."]
const G_OPEN := ["..###..", ".#...#.", ".#.....", "#######", "###.###", "###.###", "#######"]


## Piksel desenli küçük simge ("#" = dolu).
class Glyph extends Control:
	var rows: Array = []
	var col: Color = Color.WHITE
	var px: int = 3

	func _init(pattern: Array, c: Color, pixel: int = 3) -> void:
		rows = pattern
		col = c
		px = pixel
		custom_minimum_size = Vector2(str(rows[0]).length() * px, rows.size() * px)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var off := ((size - custom_minimum_size) * 0.5).floor()
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				if row[x] == "#":
					draw_rect(Rect2(off + Vector2(x * px, y * px), Vector2(px, px)), col)


## Vitrin ışık havuzu (basamaklı daireler + zemin elipsi).
class Spot extends Control:
	var col: Color = Color.WHITE
	var floor_y: float = 0.84

	func _init(c: Color, fy: float = 0.84) -> void:
		col = c
		floor_y = fy
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := (size * 0.5).floor()
		var r: float = minf(size.x, size.y) * 0.48
		for i in 4:
			draw_circle(c, floorf(r * (1.0 - i * 0.2)), Color(col, 0.06 + i * 0.03))
		var fc := Vector2(c.x, floorf(size.y * floor_y))
		draw_set_transform(fc, 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, floorf(r * 0.62), Color(col, 0.2))
		draw_circle(Vector2.ZERO, floorf(r * 0.42), Color(col, 0.16))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Ruh Kıymığı kristali (fiyat yanında; Ruh Mağazası'ndakiyle aynı çizim).
class ShardIcon extends Control:
	var dim: bool = false

	func _init(px: float = 24.0, dimmed: bool = false) -> void:
		custom_minimum_size = Vector2(px, px)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim = dimmed

	func _draw() -> void:
		var s: float = size.x
		var c: float = s * 0.5
		var top := Vector2(c, s * 0.04)
		var mid_y: float = s * 0.38
		var l := Vector2(s * 0.12, mid_y)
		var r := Vector2(s * 0.88, mid_y)
		var bot := Vector2(c, s * 0.96)
		var m := Vector2(c, mid_y)
		var k: float = 0.5 if dim else 1.0
		var t := Color(k, k, k, 1)
		draw_colored_polygon(PackedVector2Array([top, m, l]), Color("#b4f1f5") * t)
		draw_colored_polygon(PackedVector2Array([top, r, m]), Color("#73d2dc") * t)
		draw_colored_polygon(PackedVector2Array([l, m, bot]), Color("#3f9fb0") * t)
		draw_colored_polygon(PackedVector2Array([m, r, bot]), Color("#27707f") * t)
		draw_polyline(PackedVector2Array([top, r, bot, l, top]), Color("#0b1418"), maxf(2.0, roundf(s / 12.0)))


## İnce ilerleme / bekleme çizgisi.
class Bar extends Control:
	var frac: float = 0.0
	var fill: Color = Color.WHITE
	var back: Color = Color.BLACK

	func _init(f: float, fc: Color, bc: Color, h: float = 6.0) -> void:
		frac = f
		fill = fc
		back = bc
		custom_minimum_size = Vector2(0, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), back)
		draw_rect(Rect2(0, 0, floorf(size.x * clampf(frac, 0.0, 1.0)), size.y), fill)


static func font() -> Font:
	return MenuKit.font()


static func sb(fill: Color, border: Color = Color(0, 0, 0, 0), bw: int = 3, r: int = 6, pad: float = -1.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	if border.a > 0.0 and bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.set_corner_radius_all(r)
	s.corner_detail = 1 ## 45 derece pah: pikselli köşe
	s.anti_aliasing = false
	if pad >= 0.0:
		s.set_content_margin_all(pad)
	return s


## Ekranın kök teması: Label rengi/gölgesi, LineEdit, kaydırma çubuğu, ipucu kutusu.
static func theme() -> Theme:
	var th := Theme.new()
	th.default_font = font()
	th.default_font_size = FS_BODY
	th.set_color("font_color", "Label", C_TEXT)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	th.set_constant("shadow_offset_x", "Label", 0)
	th.set_constant("shadow_offset_y", "Label", 3)
	var le := sb(C_INSET, C_LINE_HI, 2, 4, 10.0)
	th.set_stylebox("normal", "LineEdit", le)
	th.set_stylebox("focus", "LineEdit", sb(C_INSET, C_ACCENT, 2, 4, 10.0))
	th.set_color("font_color", "LineEdit", C_TEXT)
	th.set_color("font_placeholder_color", "LineEdit", C_DIM)
	th.set_color("caret_color", "LineEdit", C_ACCENT)
	th.set_font_size("font_size", "LineEdit", FS_LABEL)
	var track := sb(C_INSET, Color(0, 0, 0, 0), 0, 3)
	track.content_margin_left = 4
	track.content_margin_right = 4
	th.set_stylebox("scroll", "VScrollBar", track)
	for st: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		th.set_stylebox(st, "VScrollBar", sb(C_LINE_HI if st == "grabber" else C_ACCENT_DK, Color(0, 0, 0, 0), 0, 3))
	th.set_stylebox("panel", "TooltipPanel", sb(C_INSET, C_LINE_HI, 2, 4, 10.0))
	th.set_color("font_color", "TooltipLabel", C_TEXT)
	th.set_font_size("font_size", "TooltipLabel", FS_LABEL)
	th.set_font("font", "TooltipLabel", font())
	return th


static func lbl(t: String, fs: int = FS_BODY, c: Color = C_TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap(t: String, fs: int, c: Color, w: float, lines: int = 0) -> Label:
	var l := lbl(t, fs, c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if lines > 0:
		l.max_lines_visible = lines
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


static func box(fill: Color, border: Color = Color(0, 0, 0, 0), pad: float = 16.0, bw: int = 3, r: int = 6) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(fill, border, bw, r, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func h(sep: int = 12) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func v(sep: int = 12) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func sp(w: float = 0.0, hh: float = 0.0, ex: bool = false, ey: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, hh)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ex:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ey:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func hline(hh: float = 3.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = C_LINE
	r.custom_minimum_size = Vector2(0, hh)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func glyph(pat: Array, c: Color, px: int = 3) -> Glyph:
	return Glyph.new(pat, c, px)


## Tam katlı büyütme (piksel bozulmasın); kutudan büyükse küçültür.
static func icon(tex: Texture2D, bw: float, dim: bool = false, bh: float = -1.0) -> CenterContainer:
	var hh: float = bw if bh < 0.0 else bh
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(bw, hh)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex == null:
		return cc
	var ts: Vector2 = tex.get_size()
	var k: float = floorf(minf(bw / ts.x, hh / ts.y))
	if k < 1.0:
		k = minf(bw / ts.x, hh / ts.y)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.custom_minimum_size = (ts * k).floor()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		tr.modulate = Color(0.45, 0.45, 0.5, 1.0)
	cc.add_child(tr)
	return cc


## Çerçeveli ikon kutusu.
static func slot(tex: Texture2D, px: float, tip: String = "") -> PanelContainer:
	var p := box(C_INSET, C_LINE, 2, 2, 3)
	p.add_child(icon(tex, px))
	if tip != "":
		p.tooltip_text = tip
		p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


## Düğme stilleri: primary (vurgu dolgu), ghost (koyu), off (kapalı görünüm), danger (kırmızı kenar), tile / tile_on (seçim karosu).
static func style_button(b: BaseButton, kind: String, r: int = 6, pad: float = 10.0) -> void:
	var fill: Color = C_ACCENT
	var bd: Color = C_ACCENT_DK
	var tc: Color = C_ACCENT_TEXT
	match kind:
		"ghost":
			fill = C_PANEL2
			bd = C_LINE_HI
			tc = C_TEXT
		"off":
			fill = C_INSET
			bd = C_LINE
			tc = C_DIM
		"danger":
			fill = C_PANEL2
			bd = C_BAD.darkened(0.35)
			tc = C_BAD
		"tile":
			fill = C_PANEL2
			bd = C_LINE
			tc = C_TEXT
		"tile_on":
			fill = C_PANEL3
			bd = C_ACCENT
			tc = C_ACCENT
		"tile_locked":
			fill = C_INSET
			bd = C_LINE
			tc = C_DIM
	var bw: int = 3 if kind in ["tile_on", "primary", "ghost", "off", "danger"] else 2
	style_button_colors(b, fill, bd, tc, C_ACCENT, bw, r, pad)


## Renkleri verilen düğme stili (başka paletler, ör. ana menünün kehribar tonu, bunu kullanır).
static func style_button_colors(b: BaseButton, fill: Color, bd: Color, tc: Color, focus: Color, bw: int = 3, r: int = 6, pad: float = 10.0) -> void:
	b.add_theme_stylebox_override("normal", sb(fill, bd, bw, r, pad))
	b.add_theme_stylebox_override("hover", sb(fill.lightened(0.08), bd.lightened(0.15), bw, r, pad))
	b.add_theme_stylebox_override("pressed", sb(fill.darkened(0.12), bd, bw, r, pad))
	b.add_theme_stylebox_override("disabled", sb(fill, bd, bw, r, pad))
	## Odak (klavye/kumanda) halkası: dolgusuz vurgu kenarı (MenuKit dersi: odak stili normalin ÜSTÜNE çizilir).
	b.add_theme_stylebox_override("focus", sb(Color(0, 0, 0, 0), focus, 3, r))
	if b is Button:
		for fc: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			(b as Button).add_theme_color_override(fc, tc)


static func btn(t: String, kind: String = "primary", fs: int = FS_BODY, hh: float = 56.0, w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(w, hh)
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_font_override("font", font())
	style_button(b, kind)
	return b


## Düğmenin içine ortalı satır (ikon + yazı). Button'a çocuk eklenen kutu düğmenin asgari genişliğini büyütmez -> w verilmeli.
static func btn_row(b: Button, row: HBoxContainer, center: bool = true) -> Button:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER if center else BoxContainer.ALIGNMENT_BEGIN
	m.add_child(row)
	b.add_child(m)
	return b


static func chip(pat: Array, t: String, col: Color, fs: int = FS_LABEL) -> PanelContainer:
	var p := box(C_INSET, C_LINE, 6, 2, 4)
	var st: StyleBoxFlat = p.get_theme_stylebox("panel")
	st.content_margin_left = 12
	st.content_margin_right = 14
	var hb := h(10)
	if not pat.is_empty():
		hb.add_child(glyph(pat, col, 3))
	hb.add_child(lbl(t, fs, col))
	p.add_child(hb)
	return p


static func title_bar(text: String, right: Control = null, fs: int = FS_LABEL) -> HBoxContainer:
	var hb := h(10)
	hb.add_child(lbl(text, fs, C_ACCENT))
	hb.add_child(sp(0, 0, true))
	if right != null:
		hb.add_child(right)
	return hb


static func player_color(index: int) -> Color:
	return PLAYER_COLORS[posmod(index, PLAYER_COLORS.size())]
