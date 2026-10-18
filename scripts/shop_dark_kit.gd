extends RefCounted

## DÜKKANLARIN KOYU KİTİ (2026-10-16, madde 197). Kullanıcı prototiplerden seyyar satıcıda "A - Klasik Pazar" (LoL düzeni),
## demircide "A - Örs Vitrini" seçti (tools/proto_20261016/dukkan_proto.gd, madde 195). Bu dosya o prototipin çizim yardımcılarının
## oyun sürümü: merchant_shop_screen.gd + weapon_shop_screen.gd paylaşır. Palet örnek başına (satıcı kayrak+altın, demirci koyu ahşap).
## Kurallar/fiyatlar BURADA DEĞİL (items.gd, weapon_shop_logic.gd); bu kit sadece görünüş.
## Yazı m5x7 (MenuKit.font), 24/32/40/48 boyutları; panel köşeleri 45° pah (corner_detail 1) = pikselli köşe.

const PAL_SLATE := {
	"panel": Color("#1b212e"), "panel2": Color("#242c3b"), "panel3": Color("#2f3a4f"), "inset": Color("#121722"),
	"line": Color("#353f55"), "line_hi": Color("#56657f"), "text": Color("#ece6d7"), "dim": Color("#96a0b2"),
	"accent": Color("#d9b46a"), "accent_dk": Color("#6e5426"), "accent_text": Color("#21180a"),
	"good": Color("#94c97e"), "bad": Color("#dc8676"), "price": Color("#eccb7e"), "spot": Color("#6f8fc0"),
}
const PAL_WOOD := {
	"panel": Color("#241c16"), "panel2": Color("#2e251d"), "panel3": Color("#3b2f24"), "inset": Color("#1a140f"),
	"line": Color("#45372a"), "line_hi": Color("#6a5440"), "text": Color("#efe2c6"), "dim": Color("#ad9b80"),
	"accent": Color("#e2a64e"), "accent_dk": Color("#6a4416"), "accent_text": Color("#24160a"),
	"good": Color("#a9c96e"), "bad": Color("#dc7f60"), "price": Color("#f2c674"), "spot": Color("#c0803a"),
}

## Telefon (madde 276; kullanıcı onayı 2026-10-18, madde 253 "B - Gece Sıvası"): mavi-mor sıva paneller + altın/krem yazı
## (prototip tools/proto_20261018/mobil_proto.gd SKINS["B"] ile aynı; menu_dark_kit.gd ailesi). Seyyar satıcı / demirci / envanter.
const PAL_NIGHT := {
	"panel": Color("#1a1a2c"), "panel2": Color("#23233a"), "panel3": Color("#302f4c"), "inset": Color("#12121f"),
	"line": Color("#3b3a5a"), "line_hi": Color("#5f5c86"), "text": Color("#efe6d6"), "dim": Color("#a7a2c0"),
	"accent": Color("#f4c56e"), "accent_dk": Color("#6a5226"), "accent_text": Color("#231a0a"),
	"good": Color("#a8d69a"), "bad": Color("#e38c7c"), "price": Color("#f0da94"), "spot": Color("#7c78c8"),
}

## Eşya kademesi çerçeve renkleri (oyundaki kahve / mavi / mor) - koyu zeminde okunsun diye açılmış tonlar.
const TIER_COL := [Color("#c39a64"), Color("#6f9df2"), Color("#b98af2")]
const TIER_NAME := ["PARÇA", "EPİK", "EFSANEVİ"]
## Efsun kontür renkleri (enchant_weapon_glow.gd TIER_COLORS ile aynı), dizin = kademe (1 kontürsüz).
const ENCH_COL := [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.47, 0.91, 0.35), Color(0.31, 0.63, 1.0), Color(0.73, 0.49, 1.0), Color(1.0, 0.33, 0.28)]
const ROMAN := ["I", "II", "III", "IV", "V"]
const SHARD_TEXT := Color("#a8d8f0")

const COIN_PATH := "res://assets/ui/newui/icon_gold_coin.png"
const SHARD_PATH := "res://assets/pickups/weapon_shard/shard_icon.png"

const G_CHECK := ["......#", ".....##", "#...##.", "##.##..", ".###...", "..#...."]
const G_LOCK := ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]
const G_REROLL := ["..####.#", ".#....##", "#....###", "#.......", ".......#", "###....#", "##....#.", "#.####.."]
const G_ARROW := ["...#...", "....#..", "#######", "....#..", "...#..."]
const G_DIAMOND := ["..#..", ".###.", "#####", ".###.", "..#.."]
const G_HAMMER := ["#######", "#######", "#######", "..###..", "...#...", "...#...", "...#...", "...#..."]
const G_CROWN := ["#..#..#", "##.#.##", "#######", "#######", ".#####."]
const G_X := ["##...##", ".##.##.", "..###..", ".##.##.", "##...##"]

const SIL_SHADER := """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(tint.rgb, step(0.35, a) * tint.a);
}
"""

static var _tex_cache: Dictionary = {}
static var _sil_shader: Shader = null
static var _sil_mats: Dictionary = {}

var P: Dictionary = {}


func _init(pal: Dictionary) -> void:
	P = pal


## ---------------------------------------------------------------- çizim sınıfları
## Piksel desenli küçük simge ("#" = dolu piksel).
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

	func set_color(c: Color) -> void:
		col = c
		queue_redraw()

	func _draw() -> void:
		var off := ((size - custom_minimum_size) * 0.5).floor()
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				if row[x] == "#":
					draw_rect(Rect2(off + Vector2(x * px, y * px), Vector2(px, px)), col)


class Bar extends Control:
	var frac: float = 0.0
	var fill: Color = Color.WHITE
	var back: Color = Color.BLACK

	func _init(f: float, fc: Color, bc: Color, h: float = 10.0, w: float = 0.0) -> void:
		frac = clampf(f, 0.0, 1.0)
		fill = fc
		back = bc
		custom_minimum_size = Vector2(w, h)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_frac(f: float) -> void:
		var nf: float = clampf(f, 0.0, 1.0)
		if not is_equal_approx(nf, frac):
			frac = nf
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), back)
		var fw: float = floorf((size.x - 6.0) * frac)
		if fw > 0.0:
			draw_rect(Rect2(3, 3, fw, size.y - 6), fill)
			draw_rect(Rect2(3, 3, fw, 2), fill.lightened(0.3))


## Renkli ustalık çubuğu: her bölüm kendi renginde (4 geliştirme + final).
class TierPips extends Control:
	var cols: Array = []
	var on: int = 0
	var back: Color = Color.BLACK

	func _init(colors: Array, filled: int, bc: Color, w: float, h: float) -> void:
		cols = colors
		on = filled
		back = bc
		custom_minimum_size = Vector2(w, h)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n: int = cols.size()
		var gap: float = 4.0
		var seg: float = floorf((size.x - gap * (n - 1)) / n)
		for i in n:
			var x: float = i * (seg + gap)
			var c: Color = cols[i] if i < on else back
			draw_rect(Rect2(x, 0, seg, size.y), c)
			if i < on:
				draw_rect(Rect2(x, 0, seg, 2), c.lightened(0.35))


## Basamaklı ışık havuzu + zemin elipsi (vitrin).
class Spot extends Control:
	var col: Color = Color.WHITE
	var floor_y: float = 0.78

	func _init(c: Color, fy: float = 0.78) -> void:
		col = c
		floor_y = fy
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := (size * Vector2(0.5, 0.48)).floor()
		var r: float = minf(size.x, size.y) * 0.46
		for i in 4:
			draw_circle(c, floorf(r * (1.0 - i * 0.2)), Color(col, 0.06 + i * 0.03))
		var fc := Vector2(c.x, floorf(size.y * floor_y))
		draw_set_transform(fc, 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, floorf(r * 0.62), Color(col, 0.20))
		draw_circle(Vector2.ZERO, floorf(r * 0.44), Color(col, 0.16))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Bağlantı çizgileri (tarif ağacı): [PackedVector2Array, Color, kalınlık].
class Lines extends Control:
	var segs: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for s: Array in segs:
			draw_polyline(s[0] as PackedVector2Array, s[1] as Color, float(s[2]))


## Üstü çizili eski fiyat.
class StrikeLabel extends Label:
	var strike: Color = Color.WHITE

	func _draw() -> void:
		draw_rect(Rect2(0, floorf(size.y * 0.5), size.x, 2), strike)


## ---------------------------------------------------------------- temel yardımcılar
func c(k: String) -> Color:
	return P[k]


func sb(fill: Color, border: Color = Color(0, 0, 0, 0), bw: int = 3, r: int = 6, pad: float = -1.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	if border.a > 0.0 and bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.set_corner_radius_all(r)
	s.corner_detail = 1
	s.anti_aliasing = false
	if pad >= 0.0:
		s.set_content_margin_all(pad)
	return s


func theme() -> Theme:
	var th := Theme.new()
	th.default_font = MenuKit.font()
	th.default_font_size = 32
	th.set_color("font_color", "Label", c("text"))
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	th.set_constant("shadow_offset_x", "Label", 0)
	th.set_constant("shadow_offset_y", "Label", 3)
	var track := sb(c("inset"), Color(0, 0, 0, 0), 0, 3)
	track.content_margin_left = 5
	track.content_margin_right = 5
	th.set_stylebox("scroll", "VScrollBar", track)
	for st: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		th.set_stylebox(st, "VScrollBar", sb(c("line_hi"), Color(0, 0, 0, 0), 0, 3))
	## İpucu kutusu (kumanda/fare üstü açıklamaları) koyu kitte okunsun.
	th.set_stylebox("panel", "TooltipPanel", sb(c("panel2"), c("line_hi"), 2, 4, 8.0))
	th.set_color("font_color", "TooltipLabel", c("text"))
	th.set_font_size("font_size", "TooltipLabel", 24)
	return th


func tw(t: String, fs: int) -> float:
	return MenuKit.font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func lbl(t: String, fs: int = 32, col: Color = Color(0, 0, 0, 0), align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col if col.a > 0.0 else c("text"))
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func wrap(t: String, fs: int, col: Color, w: float, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := lbl(t, fs, col, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	return l


func clip(t: String, fs: int, col: Color, w: float, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := lbl(t, fs, col, align)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = w
	return l


func strike_lbl(t: String, fs: int, col: Color) -> StrikeLabel:
	var l := StrikeLabel.new()
	l.text = t
	l.strike = col
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func box(fill: Color, border: Color = Color(0, 0, 0, 0), pad: float = 16.0, bw: int = 3, r: int = 6) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(fill, border, bw, r, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func h(sep: int = 12) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func v(sep: int = 12) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func sp(w: float = 0.0, ht: float = 0.0, ex: bool = false, ey: bool = false) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(w, ht)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ex:
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ey:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


func hline(col: Color = Color(0, 0, 0, 0), ht: float = 3.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = col if col.a > 0.0 else c("line")
	r.custom_minimum_size = Vector2(0, ht)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func expand(n: Control, x: bool = true, y: bool = false) -> Control:
	if x:
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if y:
		n.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return n


func center(n: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(n)
	return cc


func glyph(pat: Array, col: Color, px: int = 3) -> Glyph:
	return Glyph.new(pat, col, px)


## ---------------------------------------------------------------- ikonlar
static func tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	return _tex_cache[path]


## Kutuya sığan en büyük TAM katlı büyütme (piksel bozulmasın); kutudan büyük doku (silah ikonları 250 px) yumuşak küçültülür.
func icon_tr(t: Texture2D, bx: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if t == null:
		tr.custom_minimum_size = Vector2(bx, bx)
		tr.size = tr.custom_minimum_size
		return tr
	var ts: Vector2 = t.get_size()
	var big: float = maxf(ts.x, ts.y)
	var k: float = floorf(bx / big)
	if k >= 1.0:
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.custom_minimum_size = (ts * k).floor()
	else:
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.custom_minimum_size = (ts * bx / big).floor()
	tr.size = tr.custom_minimum_size
	return tr


func icon(t: Texture2D, bx: float, dim: bool = false) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(bx, bx)
	cc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if t == null:
		return cc
	var tr := icon_tr(t, bx)
	if dim:
		tr.modulate = Color(0.5, 0.5, 0.56, 1.0)
	cc.add_child(tr)
	return cc


func coin(bx: float = 24.0) -> CenterContainer:
	return icon(tex(COIN_PATH), bx)


func shard(bx: float = 24.0, dim: bool = false) -> CenterContainer:
	return icon(tex(SHARD_PATH), bx, dim)


## [ikon] sayı - kind "gold" | "shard". Sayı etiketi meta "label"de (sonradan güncellenir).
func amt(n: int, fs: int, col: Color, kind: String = "gold") -> HBoxContainer:
	var row := h(6)
	var bx: float = 32.0 if fs >= 32 else 24.0
	row.add_child(coin(bx) if kind == "gold" else shard(bx))
	var l := lbl(str(n), fs, col)
	row.add_child(l)
	row.set_meta("label", l)
	return row


func amt_w(n: int, fs: int) -> float:
	return (32.0 if fs >= 32 else 24.0) + 6.0 + tw(str(n), fs)


func sil_mat(col: Color) -> ShaderMaterial:
	if _sil_shader == null:
		_sil_shader = Shader.new()
		_sil_shader.code = SIL_SHADER
	var k: String = col.to_html()
	if not _sil_mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = _sil_shader
		m.set_shader_parameter("tint", col)
		_sil_mats[k] = m
	return _sil_mats[k]


## Silah ikonu + efsun kademesi kontürü (oyundaki gibi; kademe 1 kontürsüz).
func wicon(t: Texture2D, bx: float, tier: int, dim: bool = false) -> Control:
	var host := Control.new()
	host.custom_minimum_size = Vector2(bx, bx)
	host.size = host.custom_minimum_size
	host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = ENCH_COL[clampi(tier, 0, 5)]
	var px: float = clampf(roundf(bx / 56.0), 2.0, 4.0)
	var inner: float = bx - px * 4.0
	if col.a > 0.0 and not dim:
		for off: Vector2 in [Vector2(-px, 0), Vector2(px, 0), Vector2(0, -px), Vector2(0, px), Vector2(-px, -px), Vector2(px, -px), Vector2(-px, px), Vector2(px, px)]:
			var s := icon_tr(t, inner)
			s.material = sil_mat(col)
			s.position = ((host.size - s.size) * 0.5).floor() + off
			host.add_child(s)
	var ic := icon_tr(t, inner)
	ic.position = ((host.size - ic.size) * 0.5).floor()
	if dim:
		ic.modulate = Color(0.45, 0.45, 0.5, 1.0)
	host.add_child(ic)
	return host


## Eşya yuvası: koyu iç + kenar rengi + tam katlı ikon. o: sel / dim / sold / owned / stock / fill
func tile(t: Texture2D, s: float, border: Color, o: Dictionary = {}) -> Control:
	var host := Control.new()
	host.custom_minimum_size = Vector2(s, s)
	host.size = host.custom_minimum_size
	host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim: bool = bool(o.get("dim", false))
	var bw: int = 3 if s >= 48.0 else 2
	var ring := Panel.new()
	ring.name = "SelRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override("panel", sb(Color(0, 0, 0, 0), c("accent"), 3, 8))
	ring.position = Vector2(-6, -6)
	ring.size = Vector2(s + 12, s + 12)
	ring.visible = bool(o.get("sel", false))
	host.add_child(ring)
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: Color = o.get("fill", c("inset"))
	bg.add_theme_stylebox_override("panel", sb(fill, border.darkened(0.55) if dim else border, bw, 4))
	bg.size = host.size
	host.add_child(bg)
	if not dim:
		var glow := ColorRect.new()
		glow.color = Color(border, 0.10)
		glow.position = Vector2(bw, bw)
		glow.size = Vector2(s - bw * 2, floorf((s - bw * 2) * 0.5))
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(glow)
	if t != null:
		var ic := icon_tr(t, s - bw * 2 - 2)
		ic.position = ((host.size - ic.size) * 0.5).floor()
		if dim or bool(o.get("sold", false)):
			ic.modulate = Color(0.42, 0.42, 0.48, 1.0)
		host.add_child(ic)
	if bool(o.get("sold", false)):
		var sh := ColorRect.new()
		sh.color = Color(0, 0, 0, 0.45)
		sh.position = Vector2(bw, bw)
		sh.size = host.size - Vector2(bw * 2, bw * 2)
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(sh)
	if bool(o.get("owned", false)):
		var bs: float = 22.0 if s >= 64.0 else 18.0
		var badge := Panel.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("panel", sb(c("good"), c("good").darkened(0.6), 2, 3))
		badge.position = Vector2(s - bs + 4, s - bs + 4)
		badge.size = Vector2(bs, bs)
		host.add_child(badge)
		var g := glyph(G_CHECK, Color("#10200c"), 2)
		g.position = badge.position + ((Vector2(bs, bs) - g.custom_minimum_size) * 0.5).floor()
		host.add_child(g)
	if bool(o.get("stock", false)):
		var g2 := glyph(G_DIAMOND, c("price"), 2)
		g2.position = Vector2(bw + 3, bw + 3)
		host.add_child(g2)
	return host


func empty_slot(s: float) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", sb(Color(0, 0, 0, 0.25), c("line"), 2, 4))
	p.custom_minimum_size = Vector2(s, s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## ---------------------------------------------------------------- düğmeler
func btn_style(b: Button, kind: String, r: int = 6) -> void:
	var fill: Color = c("accent")
	var bd: Color = c("accent_dk")
	match kind:
		"ghost":
			fill = c("panel2")
			bd = c("line_hi")
		"off":
			fill = c("inset")
			bd = c("line")
		"tab":
			fill = Color(0, 0, 0, 0)
			bd = Color(0, 0, 0, 0)
		"tab_on":
			fill = c("panel3")
			bd = c("accent")
	var tc: Color = btn_tc(kind)
	b.add_theme_stylebox_override("normal", sb(fill, bd, 3, r, 10.0))
	b.add_theme_stylebox_override("hover", sb(fill.lightened(0.08) if kind != "tab" else Color(c("panel2"), 0.7), bd, 3, r, 10.0))
	b.add_theme_stylebox_override("pressed", sb(fill.darkened(0.12) if kind != "tab" else c("panel2"), bd, 3, r, 10.0))
	b.add_theme_stylebox_override("disabled", sb(c("inset"), c("line"), 3, r, 10.0))
	b.add_theme_stylebox_override("focus", sb(Color(0, 0, 0, 0), c("accent").lightened(0.3), 3, r, 10.0))
	for fc: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(fc, tc)
	b.add_theme_color_override("font_disabled_color", c("dim"))


func btn_tc(kind: String) -> Color:
	match kind:
		"ghost":
			return c("text")
		"off", "tab":
			return c("dim")
		"tab_on":
			return c("accent")
	return c("accent_text")


func btn(t: String, kind: String = "primary", fs: int = 32, ht: float = 60.0, w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(w, ht)
	b.add_theme_font_size_override("font_size", fs)
	btn_style(b, kind)
	return b


## İçine ortalanmış satır koyulan düğme (simge + yazı + fiyat). Satır meta "row"da.
func row_btn(row: HBoxContainer, kind: String = "primary", ht: float = 64.0, w: float = 0.0) -> Button:
	var b := btn("", kind, 32, ht, w)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(row)
	b.add_child(cc)
	b.set_meta("row", row)
	if w <= 0.0:
		b.custom_minimum_size.x = est_w(row) + 48.0
	return b


## Ağaca eklenmeden önce genişlik tahmini (Label'ın en küçük boyutu ağaç dışında yedek fontla ölçülür - yanlış çıkar).
func est_w(n: Node) -> float:
	if n is Label:
		return tw((n as Label).text, (n as Label).get_theme_font_size("font_size"))
	if n is HBoxContainer:
		var w: float = 0.0
		var k: int = 0
		for ch in n.get_children():
			if ch is Control and not (ch as Control).visible:
				continue
			w += est_w(ch)
			k += 1
		return w + maxi(0, k - 1) * (n as HBoxContainer).get_theme_constant("separation")
	if n is Control:
		return (n as Control).custom_minimum_size.x
	return 0.0


## Bakiye çipi: [ikon] başlık / değer. Değer etiketi meta "label"de.
func chip(kind: String, caption: String) -> PanelContainer:
	var p := box(c("inset"), c("line_hi"), 8.0)
	var row := h(10)
	row.add_child(sp(2))
	row.add_child(coin(32) if kind == "gold" else shard(32))
	var col := v(-8)
	col.add_child(lbl(caption, 24, c("dim")))
	var val := lbl("0", 32, c("price") if kind == "gold" else SHARD_TEXT)
	val.custom_minimum_size.x = 72
	col.add_child(val)
	row.add_child(col)
	row.add_child(sp(4))
	p.add_child(row)
	p.set_meta("label", val)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## ---------------------------------------------------------------- telefon "yan ray" (madde 276; prototip B "Yan Ray + Detay")
## Solda dar dikey şerit: üstte geri (kapat) düğmesi, altında simgeli sekmeler (seçili = koyu levha + altın kenar, altın simge/yazı;
## diğerleri çerçevesiz, soluk). Seyyar satıcı / demirci / envanter aynı parçaları kullanır.
const G_BACK := ["...#...", "..#....", ".#.....", "#######", ".#.....", "..#....", "...#..."]
const G_BAG := ["..####..", ".#....#.", "########", "########", "###..###", "########", ".######."]
const G_STAR := ["...#...", "...#...", "#######", ".#####.", "..###..", ".##.##.", "##...##"]
const G_PLUS := ["..###..", "..###..", "#######", "#######", "#######", "..###..", "..###.."]
const G_SHIELD := ["#######", "#######", "#######", ".#####.", ".#####.", "..###..", "...#..."]
const G_SWORD := ["......#", ".....#.", "....#..", "#..#...", ".##....", ".##....", "#..#..."]


func rail_back(w: float = 92.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 72)
	btn_style(b, "ghost", 8)
	var g := center(glyph(G_BACK, c("text"), 4))
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(g)
	return b


func rail_tab(caption: String, pat: Array, on: bool, w: float = 92.0, ht: float = 100.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, ht)
	var box := v(6)
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not pat.is_empty():
		var gc := center(glyph(pat, c("dim"), 4))
		gc.name = "Glyph"
		gc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(gc)
	var l := lbl(caption, 24, c("dim"), HORIZONTAL_ALIGNMENT_CENTER)
	l.name = "Caption"
	box.add_child(l)
	b.add_child(box)
	set_rail_tab(b, on)
	return b


func set_rail_tab(b: Button, on: bool) -> void:
	btn_style(b, "tab_on" if on else "tab", 8)
	var col: Color = c("accent") if on else c("dim")
	var gc: Node = b.get_node_or_null("Box/Glyph")
	if gc and gc.get_child_count() > 0 and gc.get_child(0) is Glyph:
		(gc.get_child(0) as Glyph).col = col
		(gc.get_child(0) as Glyph).queue_redraw()
	var l: Label = b.get_node_or_null("Box/Caption") as Label
	if l:
		l.add_theme_color_override("font_color", col)

