extends SceneTree

## ESC (duraklatma) + AYARLAR ekranı PROTOTİPLERİ (2026-10-17). Kullanıcı: "esc ekranı ve ayarlar için yeni arayüz prototipi hazırla 4 adet".
## Şu anki: scenes/pause_menu.tscn (bej UIKit penceresi DURAKLATILDI + 4 düğme; Ayarlar = ayrı bej pencere: ses, tam ekran,
## çözünürlük, FPS, arayüz saydamlığı, kamera sarsıntısı + "Grafik" / "Tuş Atamaları" düğmeleri ayrı pencere açar).
## Oyuna BAĞLI DEĞİL: gerçek SP main.tscn açılır, her prototip ayrı CanvasLayer'da (90+) üstüne kurulur. Hepsi gerçek Control'ler
## (ShopDarkKit / UIKit / m5x7), kaydırıcı-anahtar-açılır liste piksel çizim. Ayar içeriği BUGÜNKÜ ayarların aynısı, tek pencerede:
## GENEL (Ses + Ekran + Arayüz) / GRAFİK (graphics_settings_menu.gd) / TUŞLAR (keybind_menu.gd). Her yön mevcut bir ekranın dili:
##  A Kayrak Pencere  = Seyyar Satıcı + Oyun Bitti (PAL_SLATE), küçük orta pencere; ayarlar üst sekmeli büyük pencere.
##  B Ateş Işığı      = ana menü D (panelsiz, sol karartma, ikon + alt yazı, mum); ayarlar: sol sütun kategoriye döner, sağda satırlar.
##  C Kamp Panosu     = HUD "Kısık Ahşap" (hud_plaque), tam ekran: KOŞU sekmesi (karakter/donanım/takım) + iki sütunlu ayar + açıklama.
##  D Örs Kartları    = Demirci (PAL_WOOD): 2x2 büyük kart + ESC'de hızlı ayarlar; ayarlar tek kaydırmalı liste + içindekiler.
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261017/esc_ayar_proto.gd
##   ESC_AYAR_ONLY = "A_esc,A_ayar" gibi seçili çekimler (boşsa hepsi + ozet_esc.png / ozet_ayar.png / simdi.png).
##   OYUNDA (madde 234, B seçildi): "oyunda_esc,oyunda_genel,oyunda_grafik,oyunda_tuslar,anamenu_ayar" = gerçek pause_menu.tscn /
##   main_menu.tscn + settings_screen.gd. ("simdi_*" çekimleri artık YENİ menüyü verir - eski ekranın görüntüsü out/esc_ayar/simdi.png.)

const OUT := "res://tools/proto_20261017/out/esc_ayar/"
const HT := preload("res://scripts/hud_theme.gd")
const CHAR_ID := 2 ## Oakley
const RUN_TIER := "IV"
const RUN_TIME := "12:34"
const RUN_LEVEL := 18

const CAPTIONS := {
	"simdi_esc": "ŞU AN - duraklatma", "simdi_ayar": "ŞU AN - ayarlar",
	"A_esc": "A - Kayrak Pencere", "A_ayar": "A - Kayrak Pencere: ayarlar",
	"B_esc": "B - Ateş Işığı", "B_ayar": "B - Ateş Işığı: ayarlar",
	"C_esc": "C - Kamp Panosu", "C_ayar": "C - Kamp Panosu: ayarlar",
	"D_esc": "D - Örs Kartları", "D_ayar": "D - Örs Kartları: ayarlar",
}

## Ayarların bugünkü içeriği (değerler örnek). t: slider / toggle / option / seg.
const GENEL := [
	{"id": "ses", "title": "SES", "rows": [
		{"t": "slider", "label": "Oyun Sesi", "v": 0.8, "val": "%80"}]},
	{"id": "ekran", "title": "EKRAN", "rows": [
		{"t": "toggle", "label": "Tam Ekran", "v": true},
		{"t": "option", "label": "Çözünürlük", "val": "1920 x 1080", "disabled": true, "hint": "tam ekranda kilitli"},
		{"t": "toggle", "label": "FPS Göstergesi", "v": false}]},
	{"id": "arayuz", "title": "ARAYÜZ", "rows": [
		{"t": "slider", "label": "Arayüz Saydamlığı", "v": 1.0, "val": "%100"},
		{"t": "slider", "label": "Kamera Sarsıntısı", "v": 0.6, "val": "%60"},
		{"t": "toggle", "label": "Arayüz Animasyonları", "v": true}]},
]
const GRAFIK := {"id": "grafik", "title": "GRAFİK", "rows": [
	{"t": "seg", "label": "Kalite", "opts": ["Düşük", "Orta", "Yüksek"], "sel": 2},
	{"t": "toggle", "label": "Güneş Işığı / Bulut Gölgesi", "v": true},
	{"t": "toggle", "label": "Zemin Ayrıntısı", "v": true},
	{"t": "seg", "label": "Dünya Çözünürlüğü", "opts": ["%100", "%75", "%50"], "sel": 0},
	{"t": "seg", "label": "FPS Sınırı", "opts": ["30", "60", "120", "Sınırsız"], "sel": 1}]}
const TUSLAR := {"id": "tuslar", "title": "TUŞLAR", "rows": [
	{"t": "key", "label": "Yukarı Hareket", "val": "W"}, {"t": "key", "label": "Aşağı Hareket", "val": "S"},
	{"t": "key", "label": "Sola Hareket", "val": "A"}, {"t": "key", "label": "Sağa Hareket", "val": "D"},
	{"t": "key", "label": "Q Yeteneği", "val": "Q"}]}
const SHAKE_DESC := "Vuruş, patlama ve boss saldırılarında ekranın titreme gücü. %0 = tamamen kapalı; düşük değer göz yorgunluğunu azaltır."

## Piksel simgeler ("#" = dolu)
const G_GEAR := ["..#.#..", ".#####.", "###.###", "##...##", "###.###", ".#####.", "..#.#.."]
const G_GEM := ["..#..", ".###.", "#####", ".###.", "..#.."]
const G_KEY := [".#######.", "#.......#", "#.#.#.#.#", "#.......#", "#.#####.#", "#.......#", ".#######."]
const G_SPEAKER := ["...#....", "..##..#.", "####...#", "####.#.#", "####...#", "..##..#.", "...#...."]
const G_MONITOR := ["#########", "#.......#", "#.......#", "#.......#", "#########", "...###...", "..#####.."]
const G_EYE := ["..#####..", ".#.....#.", "#..###..#", ".#.....#.", "..#####.."]
const G_BACK := ["...#...", "..#....", "#######", "..#....", "...#..."]
const G_DIAMOND := ["..#..", ".###.", "#####", ".###.", "..#.."]
const G_DOT := ["##", "##"]
const HOURGLASS := [
	"OOOOOOOOOOOOO",
	"OWWWWWWWWWWWO",
	"OOOOOOOOOOOOO",
	" OHgggggggGO ",
	" OHgSSSSSgGO ",
	"  OHSSSSSGO  ",
	"   OHSSSGO   ",
	"    OHSGO    ",
	"     OSO     ",
	"    OgSgO    ",
	"   OggSggO   ",
	"  OHggSggGO  ",
	" OHgggSgggGO ",
	" OHggSSSggGO ",
	" OHSSSSSSSGO ",
	"OOOOOOOOOOOOO",
	"OWWWWWWWWWWWO",
	"OOOOOOOOOOOOO",
]
const ARROW_L := ["...##", "..###", ".####", "#####", ".####", "..###", "...##"]
const ARROW_R := ["##...", "###..", "####.", "#####", "####.", "###..", "##..."]
const ARROW_D := ["#######", ".#####.", "..###..", "...#..."]
const LOCK := ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]

## Ana menü D renkleri (main_menu.gd ile aynı)
const C_GOLD := Color("#f4c56e")
const C_GOLD_DIM := Color("#e2c08a")
const C_CREAM := Color("#efe2c6")
const C_SUB := Color("#b09878")
const C_TAG := Color("#c8b28e")
const C_RED := Color("#dc7f60")


## ------------------------------------------------------------------ piksel çizim parçaları
class Px extends Control:
	var P: Dictionary = {}
	var font: Font = null

	func setup(pal: Dictionary, w: float, h: float) -> void:
		P = pal
		font = pal.get("font") as Font
		custom_minimum_size = Vector2(w, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func r(x: float, y: float, w: float, h: float, c: Color) -> void:
		if w <= 0.0 or h <= 0.0:
			return
		draw_rect(Rect2(roundf(x), roundf(y), roundf(w), roundf(h)), c)

	## Köşeleri bir birim kesik çerçeve (piksel yuvarlak köşe).
	func frame(rc: Rect2, fill: Color, border: Color, bw: float = 3.0) -> void:
		var x := rc.position.x
		var y := rc.position.y
		var w := rc.size.x
		var h := rc.size.y
		if fill.a > 0.0:
			r(x + bw, y + bw, w - 2.0 * bw, h - 2.0 * bw, fill)
		r(x + bw, y, w - 2.0 * bw, bw, border)
		r(x + bw, y + h - bw, w - 2.0 * bw, bw, border)
		r(x, y + bw, bw, h - 2.0 * bw, border)
		r(x + w - bw, y + bw, bw, h - 2.0 * bw, border)

	func txt(s: String, x: float, w: float, fs: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
		if font == null:
			return
		var asc: float = font.get_ascent(fs)
		var dsc: float = font.get_descent(fs)
		var by: float = roundf((size.y - (asc + dsc)) * 0.5 + asc)
		draw_string(font, Vector2(roundf(x), by), s, align, w, fs, col)

	func pat(rows_: Array, pos: Vector2, s: float, cols: Dictionary) -> void:
		for j in rows_.size():
			var row: String = rows_[j]
			for i in row.length():
				var ch: String = row[i]
				if cols.has(ch):
					r(pos.x + i * s, pos.y + j * s, s, s, cols[ch])


class PxSlider extends Px:
	var v: float = 0.5
	var focused: bool = false

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var ty: float = roundf(h * 0.5 - 7.0)
		var fill: Color = P["s_fill"]
		r(0, ty, w, 14, P["s_border"])
		r(3, ty + 3, w - 6, 8, P["s_track"])
		var fx: float = roundf(3.0 + (w - 6.0) * v)
		r(3, ty + 3, fx - 3.0, 8, fill)
		r(3, ty + 3, fx - 3.0, 3, fill.lightened(0.3))
		for i in range(1, 4):
			var tx: float = roundf(3.0 + (w - 6.0) * float(i) / 4.0)
			if tx > fx + 12.0:
				r(tx - 1.0, ty + 3.0, 3, 8, P["s_border"])
		var kw := 18.0
		var kx: float = clampf(fx - kw * 0.5, 0.0, w - kw)
		if focused:
			frame(Rect2(kx - 5, -3, kw + 10, h + 6), Color(0, 0, 0, 0), P["focus"], 3.0)
		r(kx, 2, kw, h - 4, P["s_knob_dk"])
		r(kx + 3, 5, kw - 6, h - 10, P["s_knob"])
		r(kx + 3, 5, kw - 6, 3, (P["s_knob"] as Color).lightened(0.35))


class PxToggle extends Px:
	var on: bool = true

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var fill: Color = P["t_on"] if on else P["s_track"]
		frame(Rect2(0, 0, w, h), fill, P["t_on_bd"] if on else P["s_border"], 3.0)
		if on:
			r(3, 3, w - 6, 3, fill.lightened(0.22))
		var k: float = h - 14.0
		var kx: float = (w - 7.0 - k) if on else 7.0
		r(kx - 2, 5, k + 4, k + 4, P["s_knob_dk"])
		r(kx, 7, k, k, P["s_knob"] if on else P["dim"])
		r(kx, 7, k, 3, ((P["s_knob"] if on else P["dim"]) as Color).lightened(0.3))
		if on:
			txt("AÇIK", 8, kx - 14, 24, P["t_on_text"])
		else:
			txt("KAPALI", kx + k + 6, w - (kx + k + 6) - 8, 24, P["dim"])


## Açılır liste (çerçeveli) ya da B'nin konsol tarzı "< değer >" döngüsü.
class PxOption extends Px:
	var text: String = ""
	var disabled: bool = false
	var carousel: bool = false
	var focused: bool = false

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var tc: Color = P["dim"] if disabled else P["text"]
		var ac: Color = P["dim"] if disabled else P["accent"]
		if carousel:
			if disabled:
				pat(LOCK, Vector2(4, roundf(h * 0.5 - 7)), 2, {"#": ac})
			else:
				pat(ARROW_L, Vector2(4, roundf(h * 0.5 - 7)), 2, {"#": ac})
				pat(ARROW_R, Vector2(w - 14, roundf(h * 0.5 - 7)), 2, {"#": ac})
			txt(text, 22, w - 44, 32, (P["accent"] if focused else tc) if not disabled else tc)
			return
		frame(Rect2(0, 0, w, h), P["s_track"] if disabled else P["o_fill"], P["s_border"] if disabled else P["o_border"], 3.0)
		txt(text, 16, w - 60, 32, tc, HORIZONTAL_ALIGNMENT_LEFT)
		if disabled:
			pat(LOCK, Vector2(w - 30, roundf(h * 0.5 - 7)), 2, {"#": ac})
		else:
			pat(ARROW_D, Vector2(w - 32, roundf(h * 0.5 - 4)), 2, {"#": ac})


## A'nın kum saati madalyonu (bekleme/oyun bitti kum saati deseni)
class PxMedal extends Px:
	func _draw() -> void:
		var w: float = size.x
		frame(Rect2(0, 0, w, w), P["m_fill"], P["m_border"], 4.0)
		frame(Rect2(8, 8, w - 16, w - 16), Color(0, 0, 0, 0), P["m_ring"], 3.0)
		var s := 4.0
		pat(HOURGLASS, Vector2(roundf((w - 13.0 * s) * 0.5), roundf((w - 18.0 * s) * 0.5)), s, {
			"O": Color("#0b0e15"), "W": P["text"], "H": P["line_hi"], "g": P["panel3"], "G": P["line"], "S": P["accent"]})


## Kademeli (basamaklı) karartma bandı: x0'a kadar tam, sonra adım adım söner.
class PxShade extends Control:
	var col: Color = Color(0, 0, 0, 0.8)
	var x0: float = 1400.0
	var step_w: float = 56.0
	var steps: int = 6

	func _draw() -> void:
		draw_rect(Rect2(0, 0, x0, size.y), col)
		for i in steps:
			var a: float = col.a * (1.0 - float(i + 1) / float(steps + 1))
			draw_rect(Rect2(x0 + i * step_w, 0, step_w, size.y), Color(col, a))


## Dikey kaydırma çubuğu (D listesi)
class PxScroll extends Px:
	var top: float = 0.0
	var frac: float = 0.6

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		r(0, 0, w, h, P["s_track"])
		var gh: float = roundf(h * frac)
		var gy: float = roundf((h - gh) * top)
		r(0, gy, w, gh, P["line_hi"])
		r(0, gy, w, 3, (P["line_hi"] as Color).lightened(0.2))


## Liste sonunda panel rengine basamaklı solma (kesildiği belli olsun)
class PxFade extends Control:
	var col: Color = Color.BLACK
	var steps: int = 6

	func _draw() -> void:
		var sh: float = size.y / float(steps)
		for i in steps:
			draw_rect(Rect2(0, roundf(i * sh), size.x, ceilf(sh)), Color(col, float(i + 1) / float(steps + 1)))


## Takım satırı can + kalkan çubuğu (HUD grup paneli dili)
class PxBar extends Px:
	var hp: float = 1.0
	var sh: float = 0.0
	var down: bool = false

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		r(0, 0, w, h, HT.OUTLINE)
		r(3, 3, w - 6, h - 6, HT.INSET)
		var c: Color = HT.BAD if down else Color("#d9584a")
		r(3, 3, (w - 6) * hp, h - 6, c)
		r(3, 3, (w - 6) * hp, 3, c.lightened(0.3))
		if sh > 0.0:
			r(3 + (w - 6) * maxf(hp - sh, 0.0), 3, (w - 6) * minf(sh, hp), 3, Color("#8cc0e6"))


var _keep: Array = []
var font: Font = null
var SDK: GDScript = null
var UK: GDScript = null
var chars: GDScript = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("SHOT %s %dx%d" % [name, img.get_width(), img.get_height()])
	return img


func _hide_hud(hud: Node, on: bool) -> void:
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = not on
	for n in hud.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = not on


## ------------------------------------------------------------------ ortak yardımcılar
func _pal_px(kind: String, kit: RefCounted) -> Dictionary:
	var p: Dictionary = {"font": font}
	match kind:
		"A", "D":
			p.merge({"text": kit.c("text"), "dim": kit.c("dim"), "accent": kit.c("accent"), "line": kit.c("line"),
					"line_hi": kit.c("line_hi"), "panel3": kit.c("panel3"),
					"s_border": kit.c("line"), "s_track": kit.c("inset"), "s_fill": kit.c("accent"),
					"s_knob": kit.c("text"), "s_knob_dk": Color("#0b0e15") if kind == "A" else Color("#120d09"),
					"t_on": kit.c("accent"), "t_on_bd": kit.c("accent_dk"), "t_on_text": kit.c("accent_text"),
					"o_fill": kit.c("panel3"), "o_border": kit.c("line_hi"), "focus": kit.c("accent").lightened(0.35),
					"m_fill": kit.c("panel2"), "m_border": kit.c("accent_dk"), "m_ring": kit.c("accent")})
		"B":
			p.merge({"text": C_CREAM, "dim": C_SUB, "accent": C_GOLD, "line": Color("#3b2a1a"), "line_hi": Color("#6a5440"),
					"panel3": Color("#3b2f24"), "s_border": Color("#3b2a1a"), "s_track": Color("#140e09"), "s_fill": C_GOLD,
					"s_knob": C_CREAM, "s_knob_dk": Color("#1a110a"), "t_on": C_GOLD, "t_on_bd": Color("#6a4416"),
					"t_on_text": Color("#24160a"), "o_fill": Color("#2e251d"), "o_border": Color("#6a5440"),
					"focus": C_GOLD})
		"C":
			p.merge({"text": HT.TEXT, "dim": HT.DIM, "accent": HT.ACCENT, "line": HT.RIM_LO, "line_hi": HT.RIM_HI,
					"panel3": HT.PLATE_ON, "s_border": HT.OUTLINE, "s_track": HT.INSET, "s_fill": HT.ACCENT,
					"s_knob": HT.TEXT, "s_knob_dk": HT.OUTLINE, "t_on": HT.GOOD, "t_on_bd": Color("#4f6b2c"),
					"t_on_text": Color("#1c2410"), "o_fill": HT.PLATE_ON, "o_border": HT.RIM, "focus": HT.ACCENT})
	return p


func _style(kind: String) -> Dictionary:
	var pal: Dictionary = SDK.PAL_WOOD
	if kind == "A":
		pal = SDK.PAL_SLATE
	var kit: RefCounted = SDK.new(pal)
	return {"kind": kind, "kit": kit, "P": _pal_px(kind, kit)}


func _full(parent: Node) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _dim(parent: Control, col: Color) -> void:
	var d := ColorRect.new()
	d.color = col
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)


func _vignette(parent: Control, col: Color, amount: float) -> void:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 col : source_color;
uniform float amount;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 0.75);
	float v = smoothstep(0.18, 0.62, length(d));
	COLOR = vec4(col.rgb, clamp(col.a + v * amount, 0.0, 1.0));
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("amount", amount)
	var cr := ColorRect.new()
	cr.material = m
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cr)


func _center(parent: Control, n: Control) -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cc)
	cc.add_child(n)


func _tr(tex: Texture2D, s: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(s, s)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


func _outl(l: Label, col: Color, sz: int) -> Label:
	l.add_theme_color_override("font_outline_color", col)
	l.add_theme_constant_override("outline_size", sz)
	return l


func _lbl(S: Dictionary, t: String, fs: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return S["kit"].lbl(t, fs, col, align)


func _sb(fill: Color, border: Color = Color(0, 0, 0, 0), bw: int = 3, rad: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	if border.a > 0.0 and bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.set_corner_radius_all(rad)
	s.corner_detail = 1
	s.anti_aliasing = false
	return s


func _pc(sbx: StyleBox, l: float = 0.0, t: float = 0.0, rr: float = -1.0, b: float = -1.0) -> PanelContainer:
	var pc := PanelContainer.new()
	var s: StyleBox = sbx.duplicate()
	s.content_margin_left = l
	s.content_margin_right = l if rr < 0.0 else rr
	s.content_margin_top = t
	s.content_margin_bottom = t if b < 0.0 else b
	pc.add_theme_stylebox_override("panel", s)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc


func _shadowed(s: StyleBoxFlat) -> StyleBoxFlat:
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 10)
	return s


## Tuş kutucuğu ("ESC")
func _key(S: Dictionary, t: String, fill: Color, border: Color, col: Color) -> PanelContainer:
	var p := _pc(_sb(fill, border, 2, 4), 10, 2)
	p.add_child(_lbl(S, t, 24, col, HORIZONTAL_ALIGNMENT_CENTER))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _hint(S: Dictionary, pairs: Array, fill: Color, border: Color, kc: Color, tc: Color) -> HBoxContainer:
	var h: HBoxContainer = S["kit"].h(10)
	for i in pairs.size():
		var pr: Array = pairs[i]
		if i > 0:
			h.add_child(S["kit"].sp(18))
		h.add_child(_key(S, pr[0], fill, border, kc))
		h.add_child(_lbl(S, pr[1], 24, tc))
	return h


## "KADEME IV  ◆  12:34  ◆  SEVİYE 18"
func _run_line(S: Dictionary, fs: int, col: Color, dcol: Color) -> HBoxContainer:
	var kit: RefCounted = S["kit"]
	var h: HBoxContainer = kit.h(14)
	var parts := ["KADEME " + RUN_TIER, RUN_TIME, "SEVİYE %d" % RUN_LEVEL]
	for i in parts.size():
		if i > 0:
			h.add_child(kit.glyph(G_DIAMOND, dcol, 2))
		h.add_child(_lbl(S, parts[i], fs, col))
	return h


func _ctrl(S: Dictionary, row: Dictionary, focused: bool) -> Control:
	var P: Dictionary = S["P"]
	var kind: String = S["kind"]
	var kit: RefCounted = S["kit"]
	var t: String = row["t"]
	var hb: HBoxContainer = kit.h(14)
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sw: float = float(S.get("slider_w", 300.0))
	match t:
		"slider":
			var s := PxSlider.new()
			s.setup(P, sw, 32)
			s.v = row["v"]
			s.focused = focused
			hb.add_child(s)
			var vl := _lbl(S, str(row["val"]), 32, P["accent"] if focused else P["text"], HORIZONTAL_ALIGNMENT_RIGHT)
			vl.custom_minimum_size.x = 76
			hb.add_child(vl)
		"toggle":
			if kind == "B":
				var o := PxOption.new()
				o.setup(P, sw + 90.0, 44)
				o.carousel = true
				o.text = "Açık" if bool(row["v"]) else "Kapalı"
				o.focused = focused
				hb.add_child(o)
			else:
				var tg := PxToggle.new()
				tg.setup(P, 124, 40)
				tg.on = row["v"]
				hb.add_child(tg)
		"option":
			if row.has("hint"):
				hb.add_child(_lbl(S, row["hint"], 24, P["dim"]))
			var o := PxOption.new()
			o.setup(P, (sw + 90.0) if kind == "B" else 300.0, 48)
			o.carousel = kind == "B"
			o.text = row["val"]
			o.disabled = row.get("disabled", false)
			hb.add_child(o)
		"seg":
			if kind == "B":
				var o := PxOption.new()
				o.setup(P, sw + 90.0, 44)
				o.carousel = true
				o.text = (row["opts"] as Array)[int(row["sel"])]
				o.focused = focused
				hb.add_child(o)
			else:
				var sg: HBoxContainer = kit.h(6)
				var opts: Array = row["opts"]
				for i in opts.size():
					var on: bool = i == int(row["sel"])
					var b: Button
					if kind == "C":
						b = Button.new()
						b.text = opts[i]
						b.theme = UK.theme()
						UK.style_button(b, "green" if on else "hud", false, 24)
						b.custom_minimum_size = Vector2(0, 44)
					else:
						b = kit.btn(opts[i], "tab_on" if on else "ghost", 24, 44)
						b.custom_minimum_size.x = maxf(72.0, kit.tw(opts[i], 24) + 28.0)
					b.focus_mode = Control.FOCUS_NONE
					sg.add_child(b)
				hb.add_child(sg)
		"key":
			var kp := _key(S, row["val"], P["o_fill"], P["o_border"], P["text"])
			kp.custom_minimum_size = Vector2(96, 44)
			hb.add_child(kp)
			var kp2 := _key(S, "Sol Çubuk" if str(row["val"]) in ["W", "A", "S", "D"] else "LB", P["s_track"], P["s_border"], P["dim"])
			kp2.custom_minimum_size = Vector2(150, 44)
			hb.add_child(kp2)
	return hb


## Bir ayar satırı: yazı solda, denetim sağda. Kutu biçimi yöne göre.
func _row(S: Dictionary, row: Dictionary, focused: bool, idx: int) -> Control:
	var P: Dictionary = S["P"]
	var kind: String = S["kind"]
	var kit: RefCounted = S["kit"]
	var lab := _lbl(S, row["label"], 32, P["accent"] if focused and kind != "A" else P["text"])
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hb: HBoxContainer = kit.h(16)
	hb.add_child(lab)
	hb.add_child(_ctrl(S, row, focused))
	var rh: float = float(S.get("row_h", 60.0))
	match kind:
		"A":
			var pc := _pc(_sb(kit.c("panel2"), kit.c("accent") if focused else kit.c("line"), 3 if focused else 2, 6), 20, 4)
			pc.custom_minimum_size.y = rh
			pc.add_child(hb)
			return pc
		"B":
			var vb: VBoxContainer = kit.v(0)
			var s := StyleBoxFlat.new()
			s.bg_color = Color(C_GOLD, 0.09) if focused else Color(0, 0, 0, 0)
			if focused:
				s.border_width_left = 6
				s.border_color = C_GOLD
			var pc := _pc(s, 18, 4)
			pc.custom_minimum_size.y = rh
			pc.add_child(hb)
			vb.add_child(pc)
			vb.add_child(kit.hline(Color(C_GOLD_DIM, 0.16), 2))
			return vb
		"C":
			var pc := _pc(_sb(HT.INSET, HT.ACCENT if focused else HT.RIM_LO, 3, 4), 18, 4)
			pc.custom_minimum_size.y = rh
			pc.add_child(hb)
			return pc
		_: ## D: çizgili tablo satırı
			var fill: Color = kit.c("panel2") if idx % 2 == 0 else kit.c("panel")
			var pc := _pc(_sb(fill, kit.c("accent") if focused else Color(0, 0, 0, 0), 3, 4), 20, 4)
			pc.custom_minimum_size.y = rh
			pc.add_child(hb)
			return pc


func _sec_header(S: Dictionary, title: String, g: Array) -> Control:
	var kit: RefCounted = S["kit"]
	var P: Dictionary = S["P"]
	var h: HBoxContainer = kit.h(10)
	match S["kind"]:
		"B":
			h.add_child(kit.glyph(G_DIAMOND, C_GOLD, 3))
			h.add_child(_outl(_lbl(S, title, 32, C_GOLD), Color(0.2, 0.1, 0.03, 1), 6))
			var ln: ColorRect = kit.hline(Color(C_GOLD_DIM, 0.28), 2)
			ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ln.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(ln)
		"C":
			h.add_child(kit.glyph(g, HT.ACCENT, 3))
			h.add_child(_lbl(S, title, 24, HT.ACCENT))
		_:
			h.add_child(kit.glyph(g, P["accent"], 3))
			h.add_child(_lbl(S, title, 24, P["accent"]))
			var ln: ColorRect = kit.hline(kit.c("line"), 2)
			ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ln.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(ln)
	return h


func _glyph_for(id: String) -> Array:
	match id:
		"ses":
			return G_SPEAKER
		"ekran":
			return G_MONITOR
		"arayuz":
			return G_EYE
		"grafik":
			return G_GEM
		"tuslar":
			return G_KEY
	return G_GEAR


func _sections(S: Dictionary, secs: Array, focus_label: String, sep: int = 8, sec_gap: float = 10.0) -> VBoxContainer:
	var kit: RefCounted = S["kit"]
	var vb: VBoxContainer = kit.v(sep)
	var idx := 0
	for si in secs.size():
		var sec: Dictionary = secs[si]
		if si > 0:
			vb.add_child(kit.sp(0, sec_gap))
		vb.add_child(_sec_header(S, sec["title"], _glyph_for(sec["id"])))
		for row: Dictionary in sec["rows"]:
			vb.add_child(_row(S, row, row["label"] == focus_label, idx))
			idx += 1
	return vb


func _caption(parent: Node, k: String) -> void:
	var l := CanvasLayer.new()
	l.layer = 120
	parent.add_child(l)
	var kit: RefCounted = SDK.new(SDK.PAL_SLATE)
	var p := _pc(_sb(Color(0, 0, 0, 0.72), Color(1, 1, 1, 0.25), 2, 4), 12, 2)
	p.position = Vector2(12, 12)
	var lb: Label = kit.lbl(CAPTIONS.get(k, k), 24, Color.WHITE)
	p.add_child(lb)
	var holder := _full(l)
	holder.theme = kit.theme()
	holder.add_child(p)


## ================================================================== A - Kayrak Pencere
func _A_window(S: Dictionary, pad: float, w: float) -> Array:
	var kit: RefCounted = S["kit"]
	var pc := _pc(_shadowed(_sb(kit.c("panel"), kit.c("line_hi"), 3, 8)), pad, pad)
	pc.custom_minimum_size.x = w
	var vb: VBoxContainer = kit.v(14)
	pc.add_child(vb)
	return [pc, vb]


func _A_esc(root: Control) -> void:
	var S := _style("A")
	var kit: RefCounted = S["kit"]
	root.theme = kit.theme()
	_dim(root, Color(0.03, 0.04, 0.07, 0.6))
	var wv := _A_window(S, 32.0, 600.0)
	var vb: VBoxContainer = wv[1]
	var med := PxMedal.new()
	med.setup(S["P"], 96, 96)
	vb.add_child(kit.center(med))
	vb.add_child(_lbl(S, "DURAKLATILDI", 48, kit.c("accent"), HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(kit.center(_run_line(S, 24, kit.c("dim"), kit.c("line_hi"))))
	vb.add_child(kit.sp(0, 4))
	vb.add_child(kit.hline(kit.c("line"), 3))
	vb.add_child(kit.sp(0, 4))
	for spec: Array in [["Devam Et", "primary"], ["Ayarlar", "ghost"], ["Yeniden Başla", "ghost"], ["Ana Menüye Dön", "ghost"]]:
		var b: Button = kit.btn(spec[0], spec[1], 32, 64)
		b.focus_mode = Control.FOCUS_NONE
		if spec[0] == "Ana Menüye Dön":
			for fc: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(fc, kit.c("bad"))
		vb.add_child(b)
	vb.add_child(kit.sp(0, 6))
	vb.add_child(kit.center(_hint(S, [["ESC", "devam et"]], kit.c("inset"), kit.c("line_hi"), kit.c("text"), kit.c("dim"))))
	_center(root, wv[0])


func _A_ayar(root: Control) -> void:
	var S := _style("A")
	var kit: RefCounted = S["kit"]
	root.theme = kit.theme()
	_dim(root, Color(0.03, 0.04, 0.07, 0.7))
	var wv := _A_window(S, 28.0, 1180.0)
	var vb: VBoxContainer = wv[1]
	var head: HBoxContainer = kit.h(14)
	head.add_child(kit.glyph(G_GEAR, kit.c("accent"), 5))
	head.add_child(_lbl(S, "AYARLAR", 48, kit.c("accent")))
	head.add_child(kit.sp(0, 0, true))
	head.add_child(_hint(S, [["ESC", "geri"]], kit.c("inset"), kit.c("line_hi"), kit.c("text"), kit.c("dim")))
	vb.add_child(head)
	var tabs: HBoxContainer = kit.h(8)
	for tspec: Array in [[G_GEAR, "GENEL", true], [G_GEM, "GRAFİK", false], [G_KEY, "TUŞLAR", false]]:
		var on: bool = tspec[2]
		var rw: HBoxContainer = kit.h(12)
		rw.add_child(kit.glyph(tspec[0], kit.c("accent") if on else kit.c("dim"), 3))
		rw.add_child(_lbl(S, tspec[1], 32, kit.c("accent") if on else kit.c("dim")))
		var b: Button = kit.row_btn(rw, "tab_on" if on else "tab", 56, 230)
		b.focus_mode = Control.FOCUS_NONE
		tabs.add_child(b)
	vb.add_child(tabs)
	vb.add_child(kit.hline(kit.c("line"), 3))
	vb.add_child(_sections(S, GENEL, "Oyun Sesi", 8, 8))
	vb.add_child(kit.hline(kit.c("line"), 3))
	var foot: HBoxContainer = kit.h(14)
	var rst: Button = kit.btn("Varsayılana Dön", "ghost", 32, 60)
	rst.custom_minimum_size.x = 300
	foot.add_child(rst)
	foot.add_child(kit.sp(0, 0, true))
	var close: Button = kit.btn("Kapat", "primary", 32, 60, 240)
	foot.add_child(close)
	for b: Button in [rst, close]:
		b.focus_mode = Control.FOCUS_NONE
	vb.add_child(foot)
	_center(root, wv[0])


## ================================================================== B - Ateş Işığı
func _B_base(root: Control, wide: bool) -> Dictionary:
	var S := _style("B")
	root.theme = S["kit"].theme()
	_dim(root, Color(0.1, 0.06, 0.03, 0.32))
	if wide:
		var band := PxShade.new()
		band.col = Color(0.05, 0.035, 0.025, 0.8)
		band.x0 = 1520.0
		band.step_w = 48.0
		band.steps = 6
		band.set_anchors_preset(Control.PRESET_FULL_RECT)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(band)
	var shade := TextureRect.new()
	shade.texture = load("res://assets/ui/ana_menu/sol_golge.png")
	shade.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	return S


func _B_title(S: Dictionary, root: Control, title: String, sub: Control) -> void:
	var kit: RefCounted = S["kit"]
	var logo: VBoxContainer = kit.v(4)
	var t := _lbl(S, title, 72, C_GOLD)
	_outl(t, Color(0.06, 0.04, 0.03, 1), 12)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	t.add_theme_constant_override("shadow_offset_y", 6)
	logo.add_child(t)
	logo.add_child(sub)
	logo.add_child(kit.sp(0, 10))
	var trim := TextureRect.new()
	trim.texture = load("res://assets/ui/ana_menu/kiris_suslu.png")
	trim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	trim.stretch_mode = TextureRect.STRETCH_TILE
	trim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trim.custom_minimum_size = Vector2(480, 48)
	trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.add_child(trim)
	root.add_child(logo)
	logo.position = Vector2(48, 72)


func _B_item(S: Dictionary, title: String, sub: String, icon: Control, focused: bool, danger: bool = false) -> Control:
	var kit: RefCounted = S["kit"]
	var row: HBoxContainer = kit.h(12)
	row.custom_minimum_size = Vector2(560, 92)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(64, 64)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if focused:
		var at := AtlasTexture.new()
		at.atlas = load("res://harita/Ev içi/Candles.png")
		at.region = Rect2(96, 0, 32, 32)
		var c := _tr(at, 64)
		slot.add_child(c)
	row.add_child(slot)
	var ib := CenterContainer.new()
	ib.custom_minimum_size = Vector2(77, 48)
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ib.add_child(icon)
	row.add_child(ib)
	var col: VBoxContainer = kit.v(-6)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tl := _lbl(S, title, 48, C_GOLD if focused else (C_RED if danger else C_CREAM))
	if focused:
		_outl(tl, Color(0.35, 0.16, 0.04, 1), 8)
	tl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	tl.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(tl)
	if sub != "":
		col.add_child(_lbl(S, sub, 24, C_GOLD_DIM if focused else C_SUB))
	row.add_child(col)
	return row


func _B_hint(S: Dictionary, pairs: Array) -> HBoxContainer:
	return _hint(S, pairs, Color(0.08, 0.05, 0.03, 0.85), Color("#6a5440"), C_CREAM, C_TAG)


func _B_esc(root: Control, portrait: Texture2D) -> void:
	var S := _B_base(root, false)
	var kit: RefCounted = S["kit"]
	_B_title(S, root, "DURAKLATILDI", _run_line(S, 32, C_TAG, C_GOLD_DIM))
	var v: VBoxContainer = kit.v(0)
	v.add_child(_B_item(S, "DEVAM ET", "Kaldığın yerden sürdür", _tr(portrait, 48), true))
	v.add_child(_B_item(S, "AYARLAR", "Ses, ekran, grafik, tuşlar", _tr(load("res://assets/items/tornavida.png"), 48), false))
	v.add_child(_B_item(S, "YENİDEN BAŞLA", "Aynı karakterle baştan", _tr(load("res://assets/items/zaman_kiran.png"), 48), false))
	v.add_child(_B_item(S, "ANA MENÜ", "Koşu burada biter", _tr(load("res://assets/items/ruzgar_yuruyen_cizmeleri.png"), 48), false, true))
	root.add_child(v)
	v.position = Vector2(40, 330)
	var h := _B_hint(S, [["ESC", "devam et"], ["W/S", "seç"]])
	root.add_child(h)
	h.position = Vector2(64, 1000)


func _B_ayar(root: Control) -> void:
	var S := _B_base(root, true)
	S["slider_w"] = 300.0
	S["row_h"] = 64.0
	var kit: RefCounted = S["kit"]
	_B_title(S, root, "AYARLAR", _lbl(S, "Değişiklikler anında uygulanır", 32, C_TAG))
	var v: VBoxContainer = kit.v(0)
	v.add_child(_B_item(S, "GENEL", "Ses, ekran, arayüz", _tr(load("res://assets/items/tornavida.png"), 48), true))
	v.add_child(_B_item(S, "GRAFİK", "Kalite, gölge, zemin, FPS", _tr(load("res://assets/ui/newui/icon_gem_big.png"), 48), false))
	v.add_child(_B_item(S, "TUŞLAR", "Klavye ve kumanda", kit.glyph(G_KEY, C_CREAM, 5), false))
	v.add_child(kit.sp(0, 24))
	v.add_child(_B_item(S, "GERİ", "Duraklatma menüsüne dön", kit.glyph(G_BACK, C_SUB, 5), false))
	root.add_child(v)
	v.position = Vector2(40, 330)
	var col := _sections(S, GENEL, "Oyun Sesi", 0, 22)
	col.custom_minimum_size.x = 840
	root.add_child(col)
	col.position = Vector2(660, 150)
	var h := _B_hint(S, [["A/D", "değiştir"], ["W/S", "seç"], ["ESC", "geri"]])
	root.add_child(h)
	h.position = Vector2(680, 1000)


## ================================================================== C - Kamp Panosu
func _C_plaque(S: Dictionary, title: String, w: float, h: float) -> Array:
	var kit: RefCounted = S["kit"]
	var pc := _pc(UK.panel_style("hud_plaque"), 24, 20)
	pc.custom_minimum_size = Vector2(w, h)
	var vb: VBoxContainer = kit.v(12)
	pc.add_child(vb)
	if title != "":
		vb.add_child(_lbl(S, title, 32, HT.ACCENT))
	return [pc, vb]


func _C_well(child: Control, s: float) -> PanelContainer:
	var w := _pc(UK.panel_style("hud_inset_tight"), 0, 0)
	w.custom_minimum_size = Vector2(s, s)
	if child:
		var cc := CenterContainer.new()
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(child)
		w.add_child(cc)
	return w


func _C_frame(root: Control, sel: int) -> Dictionary:
	var S := _style("C")
	S["slider_w"] = 260.0
	S["row_h"] = 64.0
	var kit: RefCounted = S["kit"]
	root.theme = kit.theme()
	_vignette(root, Color(0.06, 0.035, 0.02, 0.62), 0.32)
	var top: VBoxContainer = kit.v(2)
	top.add_child(_lbl(S, "DURAKLATILDI", 48, HT.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	top.add_child(kit.center(_run_line(S, 24, HT.DIM, HT.RIM_HI)))
	top.custom_minimum_size.x = 1920
	root.add_child(top)
	top.position = Vector2(0, 36)
	var tabs: HBoxContainer = kit.h(10)
	var names := ["KOŞU", "AYARLAR", "GRAFİK", "TUŞLAR"]
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.theme = UK.theme()
		UK.style_button(b, "green" if i == sel else "hud", false, 32)
		b.custom_minimum_size = Vector2(240, 60)
		b.focus_mode = Control.FOCUS_NONE
		tabs.add_child(b)
	var tw := _full(root)
	var tc := CenterContainer.new()
	tc.custom_minimum_size = Vector2(1920, 60)
	tc.add_child(tabs)
	tw.add_child(tc)
	tc.position = Vector2(0, 150)
	var hint := _hint(S, [["Q/E", "sekme"], ["ESC", "devam et"]], HT.INSET, HT.RIM, HT.TEXT, HT.DIM)
	root.add_child(hint)
	hint.position = Vector2(1500, 1012)
	return S


func _C_bottom(S: Dictionary, root: Control, labels: Array, y: float) -> void:
	var kit: RefCounted = S["kit"]
	var h: HBoxContainer = kit.h(18)
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.theme = UK.theme()
		UK.style_button(b, "green" if i == 0 else "hud", false, 32)
		b.custom_minimum_size = Vector2(320, 64)
		b.focus_mode = Control.FOCUS_NONE
		h.add_child(b)
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(1920, 64)
	cc.add_child(h)
	root.add_child(cc)
	cc.position = Vector2(0, y)


func _C_esc(root: Control, team: Array) -> void:
	var S := _C_frame(root, 0)
	var kit: RefCounted = S["kit"]
	var row: HBoxContainer = kit.h(24)
	## KARAKTER
	var k := _C_plaque(S, "KARAKTER", 520, 500)
	var kv: VBoxContainer = k[1]
	var me: Dictionary = team[0]
	var top: HBoxContainer = kit.h(18)
	top.add_child(_C_well(_tr(me["tex"], 96), 112))
	var nv: VBoxContainer = kit.v(0)
	nv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nv.add_child(_lbl(S, me["cname"], 48, HT.TEXT))
	nv.add_child(_lbl(S, "Seviye %d - Evcil: Peri" % RUN_LEVEL, 24, HT.DIM))
	top.add_child(nv)
	kv.add_child(top)
	kv.add_child(kit.hline(Color(HT.OUTLINE, 0.6), 3))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 14)
	for st: Array in [["damage", "Saldırı Gücü", "64"], ["fire_rate", "Saldırı Hızı", "%138"], ["crit_chance", "Kritik Şansı", "%18"],
			["crit_damage", "Kritik Hasarı", "%175"], ["speed", "Hareket Hızı", "%112"], ["shield_amount", "Kalkan", "120"],
			["lifesteal", "Can Çalma", "2"], ["luck", "Şans", "14"]]:
		var cell: HBoxContainer = kit.h(8)
		cell.custom_minimum_size.x = 224
		cell.add_child(_tr(load("res://assets/ui/stat_mini/%s.png" % st[0]), 24))
		var nl := _lbl(S, st[1], 24, HT.DIM)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(nl)
		cell.add_child(_lbl(S, st[2], 24, HT.TEXT))
		grid.add_child(cell)
	kv.add_child(grid)
	row.add_child(k[0])
	## DONANIM
	var d := _C_plaque(S, "SİLAHLAR", 560, 500)
	var dv: VBoxContainer = d[1]
	var wts: GDScript = load("res://scripts/weapon_tier_art.gd")
	var wc: GDScript = load("res://scripts/weapon_catalog.gd")
	var wrow: HBoxContainer = kit.h(18)
	for ws: Array in [["yay", 3, "Yay"], ["boomerang", 2, "Bumerang"], ["tabanca", 1, "Tabanca"]]:
		var tex: Texture2D = wts.texture(ws[0], ws[1]) if wts.has_art(ws[0]) else wc.icon(ws[0])
		var col: VBoxContainer = kit.v(4)
		col.add_child(_C_well(_tr(tex, 96), 144))
		col.add_child(_lbl(S, ws[2], 24, HT.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		col.add_child(_lbl(S, "Kademe " + ["I", "II", "III", "IV", "V"][int(ws[1]) - 1], 24, HT.DIM, HORIZONTAL_ALIGNMENT_CENTER))
		wrow.add_child(col)
	dv.add_child(wrow)
	dv.add_child(kit.sp(0, 6))
	dv.add_child(_lbl(S, "EŞYALAR", 32, HT.ACCENT))
	var irow: HBoxContainer = kit.h(12)
	for ip: String in ["anka_muhru", "sifa_feneri", "zaman_kiran", "", "", ""]:
		irow.add_child(_C_well(_tr(load("res://assets/items/%s.png" % ip), 64) if ip != "" else null, 76))
	dv.add_child(irow)
	row.add_child(d[0])
	## TAKIM
	var t := _C_plaque(S, "TAKIM  4/4", 520, 500)
	var tv: VBoxContainer = t[1]
	for m: Dictionary in team:
		var tr: HBoxContainer = kit.h(14)
		tr.add_child(_C_well(_tr(m["tex"], 48), 64))
		var nc: VBoxContainer = kit.v(-4)
		nc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nc.add_child(_lbl(S, m["name"], 32, HT.ACCENT if m.get("me", false) else HT.TEXT))
		nc.add_child(_lbl(S, ("YERDE" if m.get("down", false) else m["cname"]), 24, HT.BAD if m.get("down", false) else HT.DIM))
		tr.add_child(nc)
		var bar := PxBar.new()
		bar.setup(S["P"], 150, 20)
		bar.hp = m["hp"]
		bar.sh = m.get("sh", 0.0)
		bar.down = m.get("down", false)
		tr.add_child(bar)
		tv.add_child(tr)
	tv.add_child(kit.sp(0, 8, false, true))
	var note := _lbl(S, "Çok oyunculuda oyun durmaz: karakterin bekler, takım savaşmaya devam eder.", 24, HT.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 470
	tv.add_child(note)
	row.add_child(t[0])
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(1920, 500)
	cc.add_child(row)
	root.add_child(cc)
	cc.position = Vector2(0, 262)
	_C_bottom(S, root, ["Devam Et", "Yeniden Başla", "Ana Menüye Dön"], 806)


func _C_ayar(root: Control) -> void:
	var S := _C_frame(root, 1)
	var kit: RefCounted = S["kit"]
	var row: HBoxContainer = kit.h(24)
	var l := _C_plaque(S, "", 790, 420)
	(l[1] as VBoxContainer).add_child(_sections(S, [GENEL[0], GENEL[1]], "", 10, 12))
	row.add_child(l[0])
	var r := _C_plaque(S, "", 790, 420)
	(r[1] as VBoxContainer).add_child(_sections(S, [GENEL[2]], "Kamera Sarsıntısı", 10, 12))
	row.add_child(r[0])
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(1920, 420)
	cc.add_child(row)
	root.add_child(cc)
	cc.position = Vector2(0, 262)
	## Seçili ayarın açıklaması
	var dp := _C_plaque(S, "", 1604, 120)
	var dh: HBoxContainer = kit.h(20)
	var dvb: VBoxContainer = kit.v(0)
	dvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dvb.add_child(_lbl(S, "Kamera Sarsıntısı", 32, HT.ACCENT))
	var dl := _lbl(S, SHAKE_DESC, 24, HT.DIM)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size.x = 1440
	dvb.add_child(dl)
	dh.add_child(dvb)
	(dp[1] as VBoxContainer).add_child(dh)
	var dc := CenterContainer.new()
	dc.custom_minimum_size = Vector2(1920, 120)
	dc.add_child(dp[0])
	root.add_child(dc)
	dc.position = Vector2(0, 706)
	_C_bottom(S, root, ["Devam Et", "Varsayılana Dön"], 862)


## ================================================================== D - Örs Kartları
func _D_window(S: Dictionary, pad: float, w: float) -> Array:
	var kit: RefCounted = S["kit"]
	var pc := _pc(_shadowed(_sb(kit.c("panel"), kit.c("line_hi"), 3, 8)), pad, pad)
	pc.custom_minimum_size.x = w
	var vb: VBoxContainer = kit.v(14)
	pc.add_child(vb)
	return [pc, vb]


func _D_tile(S: Dictionary, icon: Control, title: String, sub: String, focused: bool, danger: bool = false) -> Button:
	var kit: RefCounted = S["kit"]
	var b: Button = kit.btn("", "tab_on" if focused else "ghost", 32, 150, 384)
	b.focus_mode = Control.FOCUS_NONE
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb: VBoxContainer = kit.v(2)
	vb.add_child(kit.center(icon))
	vb.add_child(_lbl(S, title, 32, kit.c("accent") if focused else (kit.c("bad") if danger else kit.c("text")), HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(_lbl(S, sub, 24, kit.c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
	cc.add_child(vb)
	b.add_child(cc)
	return b


func _D_chip(S: Dictionary, t: String) -> PanelContainer:
	var kit: RefCounted = S["kit"]
	var p := _pc(_sb(kit.c("inset"), kit.c("line"), 2, 6), 14, 4)
	p.add_child(_lbl(S, t, 24, kit.c("price")))
	return p


func _D_esc(root: Control, portrait: Texture2D) -> void:
	var S := _style("D")
	S["slider_w"] = 300.0
	S["row_h"] = 56.0
	var kit: RefCounted = S["kit"]
	root.theme = kit.theme()
	_dim(root, Color(0.07, 0.045, 0.025, 0.58))
	var wv := _D_window(S, 28.0, 840.0)
	var vb: VBoxContainer = wv[1]
	vb.add_child(_lbl(S, "DURAKLATILDI", 48, kit.c("accent"), HORIZONTAL_ALIGNMENT_CENTER))
	var chips: HBoxContainer = kit.h(10)
	for t: String in ["KADEME " + RUN_TIER, RUN_TIME, "SEVİYE %d" % RUN_LEVEL]:
		chips.add_child(_D_chip(S, t))
	vb.add_child(kit.center(chips))
	vb.add_child(kit.sp(0, 2))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.add_child(_D_tile(S, _tr(portrait, 48), "Devam Et", "Kaldığın yerden sürdür", true))
	grid.add_child(_D_tile(S, _tr(load("res://assets/items/tornavida.png"), 64), "Ayarlar", "Tüm ayarlar", false))
	grid.add_child(_D_tile(S, _tr(load("res://assets/items/zaman_kiran.png"), 64), "Yeniden Başla", "Aynı karakterle baştan", false))
	grid.add_child(_D_tile(S, _tr(load("res://assets/items/ruzgar_yuruyen_cizmeleri.png"), 64), "Ana Menü", "Koşu burada biter", false, true))
	vb.add_child(kit.center(grid))
	vb.add_child(kit.sp(0, 4))
	vb.add_child(_sec_header(S, "HIZLI AYARLAR", G_GEAR))
	var q: VBoxContainer = kit.v(0)
	var qrows := [GENEL[0]["rows"][0], GENEL[2]["rows"][1], GENEL[1]["rows"][2]]
	for i in qrows.size():
		q.add_child(_row(S, qrows[i], false, i))
	vb.add_child(q)
	vb.add_child(kit.sp(0, 2))
	vb.add_child(kit.center(_hint(S, [["ESC", "devam et"]], kit.c("inset"), kit.c("line_hi"), kit.c("text"), kit.c("dim"))))
	_center(root, wv[0])


func _D_ayar(root: Control) -> void:
	var S := _style("D")
	S["slider_w"] = 300.0
	S["row_h"] = 58.0
	var kit: RefCounted = S["kit"]
	root.theme = kit.theme()
	_dim(root, Color(0.07, 0.045, 0.025, 0.66))
	var wv := _D_window(S, 28.0, 1260.0)
	var vb: VBoxContainer = wv[1]
	var head: HBoxContainer = kit.h(14)
	head.add_child(kit.glyph(G_GEAR, kit.c("accent"), 5))
	head.add_child(_lbl(S, "AYARLAR", 48, kit.c("accent")))
	head.add_child(kit.sp(0, 0, true))
	head.add_child(_hint(S, [["ESC", "kapat"]], kit.c("inset"), kit.c("line_hi"), kit.c("text"), kit.c("dim")))
	vb.add_child(head)
	vb.add_child(kit.hline(kit.c("line"), 3))
	var body: HBoxContainer = kit.h(20)
	## içindekiler: tıklayınca listede o bölüme kayar
	var rail: VBoxContainer = kit.v(6)
	rail.custom_minimum_size.x = 230
	var secs: Array = GENEL.duplicate() + [GRAFIK, TUSLAR]
	for i in secs.size():
		var sec: Dictionary = secs[i]
		var on: bool = i == 0
		var rw: HBoxContainer = kit.h(12)
		rw.add_child(kit.glyph(_glyph_for(sec["id"]), kit.c("accent") if on else kit.c("dim"), 3))
		rw.add_child(_lbl(S, sec["title"], 32, kit.c("accent") if on else kit.c("dim")))
		var b: Button = kit.row_btn(rw, "tab_on" if on else "tab", 56, 230)
		b.focus_mode = Control.FOCUS_NONE
		rail.add_child(b)
	body.add_child(rail)
	var vline: ColorRect = kit.hline(kit.c("line"), 0)
	vline.custom_minimum_size = Vector2(3, 0)
	vline.size_flags_vertical = Control.SIZE_FILL
	body.add_child(vline)
	var clip := Control.new()
	clip.clip_contents = true
	clip.custom_minimum_size = Vector2(910, 700)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var list := _sections(S, secs, "Oyun Sesi", 4, 14)
	list.custom_minimum_size.x = 910
	clip.add_child(list)
	var fade := PxFade.new()
	fade.col = kit.c("panel")
	fade.position = Vector2(0, 700 - 60)
	fade.size = Vector2(910, 60)
	clip.add_child(fade)
	body.add_child(clip)
	var sc := PxScroll.new()
	sc.setup(S["P"], 12, 700)
	sc.top = 0.0
	sc.frac = 0.48
	body.add_child(sc)
	vb.add_child(body)
	vb.add_child(kit.hline(kit.c("line"), 3))
	var foot: HBoxContainer = kit.h(14)
	var rst: Button = kit.btn("Varsayılana Dön", "ghost", 32, 60)
	rst.custom_minimum_size.x = 300
	foot.add_child(rst)
	foot.add_child(kit.sp(0, 0, true))
	var close: Button = kit.btn("Kapat", "primary", 32, 60, 240)
	foot.add_child(close)
	for b: Button in [rst, close]:
		b.focus_mode = Control.FOCUS_NONE
	vb.add_child(foot)
	_center(root, wv[0])


## ================================================================== çalıştırma
func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var only: String = OS.get_environment("ESC_AYAR_ONLY")
	var kinds: Array = ["simdi_esc", "simdi_ayar", "A_esc", "A_ayar", "B_esc", "B_ayar", "C_esc", "C_ayar", "D_esc", "D_ayar"]
	if only != "":
		kinds = Array(only.split(","))
	SDK = load("res://scripts/shop_dark_kit.gd")
	UK = load("res://scripts/ui_kit.gd")
	chars = load("res://scripts/characters.gd")
	font = load("res://assets/fonts/m5x7.ttf")
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", CHAR_ID)
	gm.set("selected_character", chars.get_def(CHAR_ID).get("skill", 1))
	gm.set("selected_pet", "peri")
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	current_scene.set("_run_end_recorded", true)
	gm.set("run_record_suppressed", true)
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
		hud.call("update_level", RUN_LEVEL)
	Input.warp_mouse(Vector2(1700, 560))
	await _wait(1.5)

	var my_def: Dictionary = chars.get_def(CHAR_ID)
	var portrait: Texture2D = load(str(my_def.get("portrait", "")))
	var team: Array = []
	for m: Array in [["Sen", CHAR_ID, 1.0, 0.3, false], ["Mira", 10, 0.62, 0.0, false], ["Kerem", 5, 0.0, 0.0, true], ["Deniz", 15, 0.88, 0.5, false]]:
		var d: Dictionary = chars.get_def(int(m[1]))
		team.append({"name": m[0], "cname": d.get("name", "?"), "tex": load(str(d.get("portrait", ""))), "hp": m[2], "sh": m[3],
				"down": m[4], "me": m[0] == "Sen"})

	var shots: Dictionary = {}
	for k: String in kinds:
		var layers: Array = []
		var pm: Node = null
		if k == "anamenu_ayar":
			continue
		if k.begins_with("simdi") or k.begins_with("oyunda"):
			pm = (load("res://scenes/pause_menu.tscn") as PackedScene).instantiate()
			current_scene.add_child(pm)
			await _wait(0.2)
			if k == "simdi_ayar" or (k.begins_with("oyunda") and k != "oyunda_esc"):
				pm.call("_on_settings_pressed")
				await _wait(0.1)
				var ss: Node = pm.call("get_settings_screen") if pm.has_method("get_settings_screen") else null
				if ss and k == "oyunda_grafik":
					ss.call("_set_category", 1, false)
				elif ss and k == "oyunda_tuslar":
					ss.call("_set_category", 2, false)
		else:
			if k.begins_with("C") and hud:
				_hide_hud(hud, true)
			var l := CanvasLayer.new()
			l.layer = 96
			root.add_child(l)
			layers.append(l)
			var rc := _full(l)
			match k:
				"A_esc":
					_A_esc(rc)
				"A_ayar":
					_A_ayar(rc)
				"B_esc":
					_B_esc(rc, portrait)
				"B_ayar":
					_B_ayar(rc)
				"C_esc":
					_C_esc(rc, team)
				"C_ayar":
					_C_ayar(rc)
				"D_esc":
					_D_esc(rc, portrait)
				"D_ayar":
					_D_ayar(rc)
		var cl := CanvasLayer.new()
		layers.append(cl)
		_caption(cl, k)
		root.add_child(cl)
		await _wait(0.9)
		shots[k] = await _shot(k)
		if pm:
			pm.queue_free()
		for l: Node in layers:
			l.queue_free()
		if hud:
			_hide_hud(hud, false)
		await _wait(0.3)

	for grp: Array in [["ozet_esc", ["A_esc", "B_esc", "C_esc", "D_esc"]], ["ozet_ayar", ["A_ayar", "B_ayar", "C_ayar", "D_ayar"]]]:
		var names: Array = grp[1]
		var ok := true
		for n: String in names:
			ok = ok and shots.has(n)
		if not ok:
			continue
		var sheet := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
		for i in 4:
			var im: Image = (shots[names[i]] as Image).duplicate()
			im.convert(Image.FORMAT_RGBA8)
			im.resize(960, 540, Image.INTERPOLATE_LANCZOS)
			@warning_ignore("integer_division")
			sheet.blit_rect(im, Rect2i(0, 0, 960, 540), Vector2i((i % 2) * 960, (i / 2) * 540))
		sheet.save_png(ProjectSettings.globalize_path(OUT + grp[0] + ".png"))
		print("SHOT %s" % grp[0])
	if kinds.has("anamenu_ayar"):
		change_scene_to_file("res://scenes/main_menu.tscn")
		await _wait(2.0)
		current_scene.call("_on_settings_pressed")
		await _wait(1.0)
		await _shot("anamenu_ayar")
	if shots.has("simdi_esc") and shots.has("simdi_ayar"):
		var sheet := Image.create(1920, 540, false, Image.FORMAT_RGBA8)
		for i in 2:
			var im: Image = (shots[["simdi_esc", "simdi_ayar"][i]] as Image).duplicate()
			im.convert(Image.FORMAT_RGBA8)
			im.resize(960, 540, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(im, Rect2i(0, 0, 960, 540), Vector2i(i * 960, 0))
		sheet.save_png(ProjectSettings.globalize_path(OUT + "simdi.png"))
		print("SHOT simdi")
	quit()
