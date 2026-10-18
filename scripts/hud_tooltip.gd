extends RefCounted

## HUD İPUCU kiti (2026-10-18, kullanıcı: "mouseu skillerin üstüne gelince açıklamalarını şuanki arayüze uygun olacak şekilde
## tasarla yeniden"): yetenek panelinin "Kısık Ahşap" levhası (madde 207) + hedef yuvaya inen basamaklı uç + açık yazı.
## Eski ipucu bej pencereydi (window_tight) - koyu panelin üstünde ayrı bir ekran gibi duruyordu.
## Kullanım: const HudTooltip := preload("res://scripts/hud_tooltip.gd") ; class_name YOK (hud_theme.gd ile aynı sebep).
## Ölçüler 3 ekran px = 1 sanat pikseli ızgarasında (MenuKit.T) - levha, kuyu ve uç aynı piksel boyunda.

const HudTheme := preload("res://scripts/hud_theme.gd")

const PX := 3.0 ## 1 sanat pikseli
const NOTCH_ROWS := 4 ## uç: 4 sanat pikseli boy, 7 genişlik (basamaklı)
const GAP := 16.0 ## levha alt kenarı ile hedefin üstü arası (ucun ucu ~4 px yukarıda biter)
const SCREEN_PAD := 8.0
const META_NOTCH := &"hud_tip_notch_x"


## Koyu levha (yetenek paneli/grup satırlarıyla aynı doku), fareyi yutmaz.
static func make_panel(min_width: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(min_width, 0)
	var sb := MenuKit._tex_style("hud_plaque_clean.png", [6, 5, 6, 5], [21, 15, 21, 15], false, MenuKit.GAME_DIR)
	p.add_theme_stylebox_override("panel", sb)
	p.draw.connect(_draw_notch.bind(p))
	return p


## Koyu kuyu (evrimler / bu oyunda bölümü, ikon yuvası).
static func well_style(pad_x: float = 12.0, pad_y: float = 9.0) -> StyleBox:
	return MenuKit._tex_style("hud_inset.png", [4, 4, 4, 4], [pad_x, pad_y, pad_x, pad_y], true, MenuKit.GAME_DIR)


static func make_well(pad_x: float = 12.0, pad_y: float = 9.0) -> PanelContainer:
	var w := PanelContainer.new()
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.add_theme_stylebox_override("panel", well_style(pad_x, pad_y))
	return w


## Tüm biçim boyutları aynı (kalın metin aksi hâlde tema varsayılanına - 88 px - düşer, bkz. skill_icon.gd eski notu).
static func make_rich(font_size: int, color: Color, wrap: bool = true) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		r.add_theme_font_size_override(key, font_size)
	r.add_theme_color_override("default_color", color)
	r.add_theme_constant_override("outline_size", 0)
	return r


static func make_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_label(l, font_size, color, 0)
	return l


## Oyulmuş ayraç: koyu çizgi + altında ışık çizgisi (levhanın üst kenar parlaklığıyla aynı dil).
static func make_divider() -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	var dark := ColorRect.new()
	dark.color = Color(HudTheme.OUTLINE, 0.55)
	dark.custom_minimum_size = Vector2(0, PX)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(dark)
	var lit := ColorRect.new()
	lit.color = Color(HudTheme.RIM_HI, 0.30)
	lit.custom_minimum_size = Vector2(0, PX)
	lit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lit)
	return box


## Tuş kapağı: HUD mini düğme levhası + tuş harfi.
static func make_keycap(text: String) -> PanelContainer:
	var k := PanelContainer.new()
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	k.add_theme_stylebox_override("panel", UIKit.button_style("hud", "normal", true))
	k.custom_minimum_size = Vector2(39, 39)
	var l := make_label(text, UIKit.FS_BODY, HudTheme.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	k.add_child(l)
	return k


## Tür etiketi (ULTİ / TEMEL / PASİF): menü kitinin renkli etiket dokuları (karakter seçimindeki yetenek satırlarıyla aynı).
static func make_tag(kind: String) -> PanelContainer:
	var k: String = kind.to_upper()
	var style: String = "tag_ulti" if k.begins_with("ULT") else ("tag_pasif" if k.begins_with("PAS") or k.begins_with("RUH") else "tag_temel")
	var t := PanelContainer.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_stylebox_override("panel", MenuKit.style(style, MenuKit.GAME_DIR))
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := make_label(kind, MenuKit.FS_SMALL, MenuKit.C_CREAM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_child(l)
	return t


## İpucunu hedefin üstüne ortalar, ekrana sığdırır (piksel yazı bulanmasın diye tam piksele yuvarlı) ve ucu hedefin ortasına çevirir.
static func place_above(tip: Control, target: Control) -> void:
	if not (is_instance_valid(tip) and is_instance_valid(target)):
		return
	tip.reset_size()
	var tgt: Rect2 = target.get_global_rect()
	var vp: Vector2 = tip.get_viewport_rect().size
	var cx: float = tgt.position.x + tgt.size.x * 0.5
	var x: float = clampf(cx - tip.size.x * 0.5, SCREEN_PAD, maxf(SCREEN_PAD, vp.x - tip.size.x - SCREEN_PAD))
	var y: float = maxf(SCREEN_PAD, tgt.position.y - tip.size.y - GAP)
	tip.global_position = Vector2(roundf(x), roundf(y))
	var nx: float = clampf(roundf(cx - tip.global_position.x), PX * 8.0, tip.size.x - PX * 8.0)
	if not tip.has_meta(META_NOTCH) or float(tip.get_meta(META_NOTCH)) != nx:
		tip.set_meta(META_NOTCH, nx)
		tip.queue_redraw()


## Basamaklı uç: levhanın alt konturunu açıp aşağı iner (koyu kenar dolgusu RIM_LO + dış hat OUTLINE, 3 px piksel).
static func _draw_notch(tip: Control) -> void:
	if not tip.has_meta(META_NOTCH):
		return
	var cx: float = float(tip.get_meta(META_NOTCH))
	var y0: float = tip.size.y - PX ## levhanın en alt (kontur) satırı
	var x0: float = roundf(cx - PX * 0.5)
	## Satır 0 = levhanın kontur satırı (ağız açılır); satır r'de dolgu yarı genişliği NOTCH_ROWS-1-r, kontur ±(NOTCH_ROWS-r)
	## -> 1:1 basamaklı köşegen, en altta tek kontur pikseli.
	for r in NOTCH_ROWS:
		var half: int = NOTCH_ROWS - 1 - r
		tip.draw_rect(Rect2(x0 - half * PX, y0 + r * PX, (2 * half + 1) * PX, PX), HudTheme.RIM_LO)
	for r in range(1, NOTCH_ROWS + 1):
		var o: int = NOTCH_ROWS - r
		tip.draw_rect(Rect2(x0 - o * PX, y0 + r * PX, PX, PX), HudTheme.OUTLINE)
		tip.draw_rect(Rect2(x0 + o * PX, y0 + r * PX, PX, PX), HudTheme.OUTLINE)
