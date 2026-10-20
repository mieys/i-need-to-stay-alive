extends RefCounted

## TELEFON MENÜ KİTİ (2026-10-19): telefon ekranlarının (duraklatma, ayarlar, oyun bitti, ana menü, oda, karakter seçimi, Ruh
## Mağazası, rekorlar) ortak parçaları. Kaynak: kullanıcının seçtiği prototip "S" seti (tools/proto_20261018/mobil_proto.gd,
## madde 253): B "Gece Sıvası" derisi = MenuDarkKit renkleri, 2400x1080 tuval (EXPAND: genişlik telefona göre değişir, boy 1080),
## kenar payı 96, üstte 120 px kare geri düğmesi + 64 px başlık, altta 136 px yüksek düğme sırası (alt kenardan 28 px yukarıda),
## gövde yazısı 48, küçük yazı 32 (m5x7 8'in katlarında keskin). Hepsi statik: const PK := preload("res://scripts/phone_menu_kit.gd").

const DK := preload("res://scripts/menu_dark_kit.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")

const SIDE := 96.0
const TOP := 28.0
const BACK := 120.0
const BTN_H := 136.0
const BOTTOM := 28.0
const RAD := 14
const BTN_RAD := 18
const FS_HERO := 96
const FS_TITLE := 64
const FS_BODY := 48
const FS_SMALL := 32
const DIMBG := Color(0.03, 0.03, 0.06)
## Panel dolgusu prototipteki "panel" (#1a1a2c) - DK.C_PANEL hafif saydam (ana menü sahnesi seçilsin diye) olduğundan ayrı.
const C_PANEL := Color("#1a1a2c")
const C_DANGER_FILL := Color("#4e2018")
const C_DANGER_TEXT := Color("#ffd8c8")
const C_SOUL := Color("#e6dcff") ## Ruh Kıymığı sayısı = mor kristalin açık tonu (madde 343)

## Tasarım genişliği (20:9 telefon). Tuval daha darsa kök orantılı küçülür (bkz. fit).
const DESIGN_W := 2400.0

## Piksel simgeler ("#" ana renk, "h" açık ton, "k" koyu ton) - prototipteki desenler.
const G_BACK := ["...#......", "..##......", ".#########", "##########", ".#########", "..##......", "...#......"]
const G_PLAY := ["##.......", "####.....", "######...", "########.", "#########", "########.", "######...", "####.....", "##......."]
const G_GEAR := ["...#.#...", ".#######.", ".##...##.", "##.....##", ".#.....#.", "##.....##", ".##...##.", ".#######.", "...#.#..."]
const G_HOME := ["....#....", "...###...", "..#####..", ".#######.", "#########", ".##...##.", ".##...##.", ".##...##."]
const G_REROLL := ["..####.#", ".#....##", "#....###", "#.......", ".......#", "###....#", "##....#.", "#.####.."]
const G_CLOCK := ["..#####..", ".#.....#.", "#...#...#", "#...#...#", "#...###.#", "#.......#", ".#.....#.", "..#####.."]
const G_SKULL := ["..#####..", ".#######.", "#########", "#kk###kk#", "#kk###kk#", ".###k###.", "..#####..", "..#k#k#.."]
const G_SWORD := [".......hh", "......h#h", ".....h#h.", "....h#h..", "k..h#h...", ".k##h....", "..kk.....", ".k..k....", "k........"]
const G_STAR := ["....#....", "...###...", "#########", ".#######.", "..#####..", ".###.###.", "##.....##"]
const G_GRID := ["###.###", "###.###", "###.###", ".......", "###.###", "###.###", "###.###"]
const G_TROPHY := ["#########", "#.#####.#", "#.#####.#", ".#######.", "..#####..", "...###...", "....#....", "..#####..", ".#######."]
const G_USER := ["...###...", "..#####..", "..#####..", "...###...", ".........", ".#######.", "#########", "#########"]
const G_USERS := [".##...##.", "####.####", "####.####", ".##...##.", ".........", "####.####", "####.####"]
const G_PLUS := ["..###..", "..###..", "#######", "#######", "#######", "..###..", "..###.."]
const G_LOCK := ["..###..", ".#...#.", ".#...#.", "#######", "###k###", "###k###", "#######"]
const G_CHECK := ["......#", ".....##", "#...##.", "##.##..", ".###...", "..#...."]
const G_KEY := [".###.....", "#...#####", "#...#.#.#", ".###....."]
const G_WIFI := [".#######.", "#.......#", "..#####..", ".#.....#.", "...###...", "....#...."]
const G_LAN := ["..###..", "..#.#..", "..###..", "...#...", "#######", "#..#..#", "##.#.##"]
const G_CROWN := ["#...#...#", "##.###.##", "#########", "#h##h##h#", "#########", ".#######."]
const G_DIAMOND := ["..#..", ".###.", "#####", ".###.", "..#.."]
const G_UP := ["...#...", "..###..", ".#####.", "#######", "..###..", "..###..", "..###.."]
const G_HEART := [".##.##.", "#######", "#######", "#######", ".#####.", "..###..", "...#..."]
const G_SHIELD := ["#########", "#########", "####h####", "#########", ".#######.", ".#######.", "..#####..", "...###...", "....#...."]
const G_X := ["##...##", "###.###", ".#####.", "..###..", ".#####.", "###.###", "##...##"]
const G_CHEV_L := ["....#", "...##", "..##.", ".##..", "##...", ".##..", "..##.", "...##", "....#"]
const G_CHEV_R := ["#....", "##...", ".##..", "..##.", "...##", "..##.", ".##..", "##...", "#...."]


## Çok tonlu piksel simge: "#" ana renk, "h" açık, "k" koyu ton.
class PGlyph extends Control:
	var rows: Array = []
	var col: Color = Color.WHITE
	var px: int = 6

	func _init(pattern: Array, c: Color, pixel: int = 6) -> void:
		rows = pattern
		col = c
		px = pixel
		custom_minimum_size = Vector2(str(rows[0]).length() * px, rows.size() * px)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_color(c: Color) -> void:
		col = c
		queue_redraw()

	func _draw() -> void:
		var off := ((size - custom_minimum_size) * 0.5).floor()
		var hi: Color = col.lightened(0.45)
		var lo: Color = col.darkened(0.6)
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				var ch: String = row[x]
				if ch == ".":
					continue
				draw_rect(Rect2(off + Vector2(x * px, y * px), Vector2(px, px)), col if ch == "#" else (hi if ch == "h" else lo))


## Ekran kökünü tuvale oturtur: tuval 2400'den darsa (16:9 telefon 1920, 4:3 tablet 1440) kök orantılı küçülür ve boyu tasarım
## alanında uzar (alta/üste çapalı parçalar yayılır, yan yana parçalar üst üste binmez); genişse (21:9) kök tuval kadar genişler.
## Görünür alan değişince yeniden uygulanır. Kökün kendi çapaları kullanılmaz (sol üst + boyut).
class Fitter extends Node:
	func _ready() -> void:
		get_viewport().size_changed.connect(apply)
		apply.call_deferred()

	func _exit_tree() -> void:
		if get_viewport() and get_viewport().size_changed.is_connected(apply):
			get_viewport().size_changed.disconnect(apply)

	func apply() -> void:
		var root := get_parent() as Control
		if root == null or not root.is_inside_tree():
			return
		var vp: Vector2 = root.get_viewport().get_visible_rect().size
		## Gerçek telefonda çentik / kamera deliği payı (masaüstü denemesinde sıfır): kök o kadar içeriden başlar.
		var safe: Rect2 = MobileUIScript.safe_margins(root.get_viewport())
		var avail: Vector2 = vp - safe.position - safe.size
		var sc: float = minf(1.0, avail.x / DESIGN_W)
		root.set_anchors_preset(Control.PRESET_TOP_LEFT)
		root.position = safe.position
		root.scale = Vector2(sc, sc)
		root.size = (avail / sc).floor()


static func fit(root: Control) -> void:
	if root.get_node_or_null("PhoneFit") != null:
		return
	var f := Fitter.new()
	f.name = "PhoneFit"
	root.add_child(f)
	if root.is_inside_tree():
		f.apply()


static func glyph(pat: Array, c: Color, px: int = 6) -> PGlyph:
	return PGlyph.new(pat, c, px)


static func lbl(t: String, fs: int = FS_BODY, c: Color = DK.C_TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := DK.lbl(t, fs, c, align)
	l.add_theme_font_override("font", DK.font())
	return l


## Görünür tuval boyutu (telefonda genişlik en-boy oranına göre değişir).
static func view(n: Node) -> Vector2:
	return n.get_viewport().get_visible_rect().size if n and n.is_inside_tree() else Vector2(2400, 1080)


static func sb(fill: Color, border: Color = Color(0, 0, 0, 0), bw: int = 3, r: int = RAD, pad: float = -1.0) -> StyleBoxFlat:
	return DK.sb(fill, border, bw, r, pad)


## Ekranı kaplayan lacivert karartma.
static func dim(alpha: float) -> ColorRect:
	var d := ColorRect.new()
	d.name = "PhoneDim"
	d.color = Color(DIMBG, alpha)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


## Kenardan içeri sönen karartma. edge: SIDE_TOP / SIDE_BOTTOM / SIDE_LEFT; extent: px (üst/alt için boy, sol için genişlik).
static func fade(edge: int, extent: float, alpha: float) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(DIMBG, alpha))
	g.set_color(1, Color(DIMBG, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64 if edge == SIDE_LEFT else 4
	gt.height = 4 if edge == SIDE_LEFT else 64
	match edge:
		SIDE_BOTTOM:
			gt.fill_from = Vector2(0, 1)
			gt.fill_to = Vector2(0, 0)
		SIDE_LEFT:
			gt.fill_from = Vector2(0, 0)
			gt.fill_to = Vector2(1, 0)
		_:
			gt.fill_from = Vector2(0, 0)
			gt.fill_to = Vector2(0, 1)
	var tr := TextureRect.new()
	tr.name = "PhoneFade%d" % edge
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match edge:
		SIDE_BOTTOM:
			tr.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			tr.offset_top = -extent
			tr.offset_bottom = 0.0
		SIDE_LEFT:
			tr.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			tr.offset_right = extent
		_:
			tr.set_anchors_preset(Control.PRESET_TOP_WIDE)
			tr.offset_bottom = extent
	return tr


## Prototipteki levha: panel dolgusu (alpha) + 3 px çizgi kenar + 14 px pahlı köşe.
static func panel(alpha: float = 0.92, pad: float = 24.0, border: Color = DK.C_LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(Color(C_PANEL, alpha), border, 3, RAD, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Koyu iç kuyu (stat karosu, liste satırı zemini).
static func inset(alpha: float = 0.92, pad: float = 16.0, border: Color = DK.C_LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(Color(DK.C_INSET, alpha), border, 3, RAD, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## ---------------------------------------------------------------- düğmeler
## kind: primary (altın dolgu), secondary (koyu levha), selected (seçili sekme: altın kenar + yazı), ghost (soluk), danger, disabled.
static func kind_colors(kind: String) -> Array:
	match kind:
		"primary":
			return [DK.C_ACCENT, DK.C_ACCENT_DK, DK.C_ACCENT_TEXT]
		"selected":
			return [DK.C_PANEL3, DK.C_ACCENT, DK.C_ACCENT]
		"ghost":
			return [Color(DK.C_INSET, 0.6), DK.C_LINE, DK.C_DIM]
		"danger":
			return [C_DANGER_FILL, DK.C_BAD, C_DANGER_TEXT]
		"disabled":
			return [Color(DK.C_INSET, 0.92), DK.C_LINE, Color(DK.C_DIM, 0.55)]
	return [DK.C_PANEL3, DK.C_LINE_HI, DK.C_TEXT]


## Düğme: ortada [simge] + yazı (fs). w = 0: yazıya göre. Yazı / simge meta "pk_label" / "pk_glyph"da, tür meta "pk_kind"de.
static func button(t: String, kind: String = "secondary", fs: int = FS_BODY, pat: Array = [], w: float = 0.0, h: float = BTN_H) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, h)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g: PGlyph = null
	if not pat.is_empty():
		g = glyph(pat, DK.C_TEXT, 6 if fs >= FS_BODY else 4)
		row.add_child(g)
	var l: Label = null
	if t != "":
		l = lbl(t, fs, DK.C_TEXT)
		l.name = "Text"
		row.add_child(l)
	b.add_child(row)
	if l: ## null set_meta anahtarı siler - yoksa hiç yazılmaz
		b.set_meta("pk_label", l)
	if g:
		b.set_meta("pk_glyph", g)
	if w <= 0.0:
		var tw: float = DK.font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if t != "" else 0.0
		b.custom_minimum_size.x = ceilf(tw + (g.custom_minimum_size.x + 20.0 if g else 0.0) + 96.0)
	set_kind(b, kind)
	return b


static func set_kind(b: Button, kind: String) -> void:
	b.set_meta("pk_kind", kind)
	var cs: Array = kind_colors(kind)
	var r: int = mini(int(b.custom_minimum_size.y * 0.5), BTN_RAD)
	var fill: Color = cs[0]
	var bd: Color = cs[1]
	b.add_theme_stylebox_override("normal", sb(fill, bd, 3, r))
	b.add_theme_stylebox_override("hover", sb(fill.lightened(0.06), bd.lightened(0.1), 3, r))
	b.add_theme_stylebox_override("pressed", sb(fill.darkened(0.15), bd, 3, r))
	b.add_theme_stylebox_override("disabled", sb(fill, bd, 3, r))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var l: Label = (b.get_meta("pk_label") if b.has_meta("pk_label") else null)
	if l:
		l.add_theme_color_override("font_color", cs[2])
	var g: PGlyph = (b.get_meta("pk_glyph") if b.has_meta("pk_glyph") else null)
	if g:
		g.set_color(cs[2])
	## Altın düğmenin üst parlaklığı + alt gölge şeridi (prototip _btn "primary").
	var hl: Node = b.get_node_or_null("PkShine")
	if kind == "primary" and hl == null:
		for i in 2:
			var s := ColorRect.new()
			s.name = "PkShine" if i == 0 else "PkShade"
			s.color = Color(1, 1, 1, 0.28) if i == 0 else Color(0, 0, 0, 0.18)
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s.set_anchors_preset(Control.PRESET_TOP_WIDE if i == 0 else Control.PRESET_BOTTOM_WIDE)
			s.offset_left = 8.0
			s.offset_right = -8.0
			if i == 0:
				s.offset_top = 4.0
				s.offset_bottom = 8.0
			else:
				s.offset_top = -10.0
				s.offset_bottom = -6.0
			b.add_child(s)
			b.move_child(s, 0)
	elif kind != "primary" and hl != null:
		for n: String in ["PkShine", "PkShade"]:
			var c: Node = b.get_node_or_null(n)
			if c:
				b.remove_child(c)
				c.queue_free()


static func set_text(b: Button, t: String) -> void:
	var l: Label = (b.get_meta("pk_label") if b.has_meta("pk_label") else null)
	if l:
		l.text = t


## Sol üstteki 120 px kare geri düğmesi (ya da başka simgeli kare düğme).
static func square(pat: Array = G_BACK, s: float = BACK, kind: String = "secondary") -> Button:
	var b := button("", kind, FS_BODY, pat, s, s)
	b.name = "PhoneBack"
	return b


## Üst satır: geri düğmesi + başlık (+ alt yazı). parent'a eklenir; başlık etiketini döndürür.
static func header(parent: Control, title: String, sub: String = "", back: Callable = Callable()) -> Label:
	var tx: float = SIDE
	if back.is_valid():
		var b := square()
		b.position = Vector2(SIDE, TOP)
		b.size = Vector2(BACK, BACK)
		b.pressed.connect(back)
		parent.add_child(b)
		tx = SIDE + BACK + 32.0
	var t := lbl(title, FS_TITLE, DK.C_ACCENT)
	t.name = "PhoneTitle"
	t.position = Vector2(tx, TOP - 4.0)
	t.size = Vector2(1200, 80)
	parent.add_child(t)
	if sub != "":
		var s := lbl(sub, FS_SMALL, DK.C_DIM)
		s.name = "PhoneSub"
		s.position = Vector2(tx, TOP + 70.0)
		s.size = Vector2(1200, 48)
		parent.add_child(s)
	return t


## Alt düğme sırası y'si (tuvalin alt kenarından BOTTOM + BTN_H yukarıda).
static func bottom_y(vp: Vector2) -> float:
	return vp.y - BOTTOM - BTN_H


## Prototipteki stat karosu: koyu kuyu, solda simge + büyük değer, altında küçük başlık.
static func stat_tile(value: String, caption: String, pat: Array, col: Color = DK.C_TEXT, icon_tex: Texture2D = null,
		value_fs: int = FS_TITLE, cap_fs: int = 24) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(Color(DK.C_PANEL2, 0.96), DK.C_LINE, 3, RAD, 24.0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := DK.v(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var row := DK.h(16)
	if icon_tex:
		row.add_child(DK.icon(icon_tex, 64))
	elif not pat.is_empty():
		row.add_child(glyph(pat, col, 7))
	var vl := lbl(value, value_fs, col)
	vl.name = "Value"
	row.add_child(vl)
	v.add_child(row)
	var cl := lbl(caption, cap_fs, DK.C_DIM)
	cl.name = "Caption"
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 4)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(cl)
	v.add_child(m)
	p.add_child(v)
	return p


## Karakter yüzü (lobi portresi) koyu kare kuyu içinde.
static func portrait(tex: Texture2D, s: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(DK.C_INSET, DK.C_LINE_HI, 3, 6, 3.0))
	p.custom_minimum_size = Vector2(s, s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(DK.icon(tex, s - 12.0))
	return p


## ---------------------------------------------------------------- B "Yan Ray + Detay" iskeleti (prototip _B_frame)
## Solda ekranın kenarına taşan koyu ray (üstte geri, altında simgeli sekmeler - sekmeler rayda ORTALI), ortada levha, sağda ekranın
## kenarına taşan ayrıntı sütunu (içerik iki yandan EDGE). Döner: {back, tabs: Array[Button], mid: Control (levhanın içerik kutusu),
## det: VBoxContainer (ayrıntı içeriği), mid_panel}. Sekme seçimi: set_rail(tabs, i). Kök fit(root) ile tasarım alanında olmalı.
const RAIL_W := 272.0
const RAIL_TAB := Vector2(176, 156)
const EDGE := 48.0


static func b_frame(root: Control, tabs: Array, back: Callable, det_w: float = 860.0, dim_a: float = 0.6) -> Dictionary:
	if dim_a > 0.0:
		root.add_child(dim(dim_a))
	var rail := Panel.new()
	rail.name = "Rail"
	rail.add_theme_stylebox_override("panel", sb(Color(C_PANEL, 0.97), DK.C_LINE, 3, 0))
	rail.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	rail.offset_left = -20.0
	rail.offset_right = RAIL_W
	rail.offset_top = -20.0
	rail.offset_bottom = 20.0
	rail.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(rail)
	var col := DK.v(12)
	col.name = "RailTabs"
	col.position = Vector2((RAIL_W - RAIL_TAB.x) * 0.5, TOP)
	var back_btn: Button = null
	if back.is_valid():
		back_btn = button("", "ghost", FS_BODY, G_BACK, RAIL_TAB.x, 112.0)
		back_btn.name = "PhoneBack"
		back_btn.pressed.connect(back)
		col.add_child(back_btn)
		col.add_child(DK.sp(0, 12))
	var out_tabs: Array[Button] = []
	for t: Array in tabs:
		var b := rail_tab(str(t[0]), t[1])
		col.add_child(b)
		out_tabs.append(b)
	root.add_child(col)
	var det_panel := Panel.new()
	det_panel.name = "DetailBack"
	det_panel.add_theme_stylebox_override("panel", sb(Color(DK.C_PANEL2, 0.98), DK.C_LINE_HI, 3, 0))
	det_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	det_panel.offset_left = -(det_w + 2.0 * EDGE)
	det_panel.offset_right = 40.0
	det_panel.offset_top = -20.0
	det_panel.offset_bottom = 20.0
	det_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(det_panel)
	var det := DK.v(0)
	det.name = "Detail"
	det.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	det.offset_left = -(det_w + EDGE)
	det.offset_right = -EDGE
	det.offset_top = TOP + 12.0
	det.offset_bottom = -(TOP + 12.0)
	root.add_child(det)
	var mid_panel := PanelContainer.new()
	mid_panel.name = "Mid"
	mid_panel.add_theme_stylebox_override("panel", sb(Color(C_PANEL, 0.9), DK.C_LINE, 3, 18, 32.0))
	mid_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	mid_panel.offset_left = RAIL_W + 24.0
	mid_panel.offset_top = TOP
	mid_panel.offset_bottom = -TOP
	mid_panel.offset_right = -(det_w + 2.0 * EDGE + 24.0)
	mid_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var mid := Control.new()
	mid.name = "Content"
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_panel.add_child(mid)
	root.add_child(mid_panel)
	return {"back": back_btn, "tabs": out_tabs, "mid": mid, "det": det, "mid_panel": mid_panel}


## Ray sekmesi 176x156: simge (desen dizisi ya da hazır Control) + küçük yazı; seçili = koyu levha + altın kenar + sol kenarda altın şerit.
static func rail_tab(caption: String, icon: Variant) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = RAIL_TAB
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var box := DK.v(10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ic: Control = glyph(icon, DK.C_TEXT, 7) if icon is Array else icon as Control
	ic.name = "Icon"
	var icw := CenterContainer.new()
	icw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icw.add_child(ic)
	box.add_child(icw)
	var l := lbl(caption, 24, DK.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	l.name = "Caption"
	box.add_child(l)
	b.add_child(box)
	var strip := ColorRect.new()
	strip.name = "Strip"
	strip.color = DK.C_ACCENT
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.position = Vector2(-(RAIL_W - RAIL_TAB.x) * 0.5, 12)
	strip.size = Vector2(10, RAIL_TAB.y - 24.0)
	b.add_child(strip)
	return b


static func set_rail(tabs: Array, sel: int) -> void:
	for i in tabs.size():
		var b: Button = tabs[i]
		var on: bool = i == sel
		var st: StyleBox = sb(DK.C_PANEL3, DK.C_ACCENT, 3, 16) if on else StyleBoxEmpty.new()
		for s: String in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(s, st)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		(b.get_node("Strip") as Control).visible = on
		var ic: Node = b.find_child("Icon", true, false)
		if ic is PGlyph:
			(ic as PGlyph).set_color(DK.C_ACCENT if on else DK.C_TEXT)
		(b.find_child("Caption", true, false) as Label).add_theme_color_override("font_color", DK.C_ACCENT if on else DK.C_DIM)


## Sayfa: levha içeriğini temizleyip yeni sayfayı tam boy yerleştirir.
static func set_page(mid: Control, page: Control) -> void:
	for c in mid.get_children():
		mid.remove_child(c)
		c.queue_free()
	mid.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


## Kaydırılabilir dikey liste (dokunarak kaydırılır; çubuk ince). Döner: [scroll, vbox].
static func scroll_list(sep: int = 12) -> Array:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := DK.v(sep)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return [sc, v]


## Yazı kutusu (B): koyu kuyu + çizgi kenar, odakta altın kenar; m5x7 yazı.
static func line_edit(placeholder: String = "", fs: int = FS_BODY, h: float = 96.0) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, h)
	e.add_theme_font_override("font", DK.font())
	e.add_theme_font_size_override("font_size", fs)
	e.add_theme_color_override("font_color", DK.C_TEXT)
	e.add_theme_color_override("font_placeholder_color", Color(DK.C_DIM, 0.7))
	e.add_theme_color_override("caret_color", DK.C_ACCENT)
	e.add_theme_color_override("selection_color", Color(DK.C_ACCENT, 0.35))
	var n := sb(DK.C_INSET, DK.C_LINE, 3, 12, 20.0)
	e.add_theme_stylebox_override("normal", n)
	e.add_theme_stylebox_override("read_only", n)
	e.add_theme_stylebox_override("focus", sb(Color(0, 0, 0, 0), DK.C_ACCENT, 3, 12))
	return e


## İki satırlı iri düğme: [simge] başlık + altında küçük açıklama (prototip _btn(..., sub)). Başlık meta "pk_label"de (set_kind boyar),
## açıklama meta "pk_sub"da.
static func big_button(t: String, sub: String, kind: String, pat: Array, w: float, h: float, fs: int = FS_TITLE) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, h)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := DK.v(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := DK.h(20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var g: PGlyph = null
	if not pat.is_empty():
		g = glyph(pat, DK.C_TEXT, 7)
		row.add_child(g)
	var l := lbl(t, fs, DK.C_TEXT)
	row.add_child(l)
	v.add_child(row)
	var s := lbl(sub, FS_SMALL, DK.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	s.visible = sub != ""
	v.add_child(s)
	b.add_child(v)
	b.set_meta("pk_label", l)
	if g:
		b.set_meta("pk_glyph", g)
	b.set_meta("pk_sub", s)
	set_kind(b, kind)
	var sc: Color = Color(DK.C_ACCENT_TEXT, 0.75) if kind == "primary" else DK.C_DIM
	s.add_theme_color_override("font_color", sc)
	return b
