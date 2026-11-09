extends RefCounted

## GÖMME TEPSİ HUD KİTİ (madde 483, 2026-11-08; kullanıcı madde 480 prototiplerinden "B yi beğendim fakat bildirimlerin eskisine benzemesini
## istiyorum iç tasarım olarak dış tasarımı B iyi"): oyuncu panelinin (madde 454) malzemesinden StyleBox'lar - sol üst konsol, grup paneli,
## görev satırı ve bildirim levhaları aynı dili konuşsun.
##   tray  = paneldeki yan kutunun kendisi (hud_dock_tray_side.png, 9 dilim 18; çerçeve TRAY_EDGE = dış hat + ahşap + koyu iç çizgi)
##   well  = koyu gömme kuyu (hud_console_well.png, alt satırı ahşap dudağı)
##   plate = kabarık ahşap düğme (hud_console_plate{,_hover,_pressed}.png)
## Dokular tek üretici tools/gen_dock_tray_parts.py (renkler hud_theme.gd ile aynı). Kullanım: const HudTrayKit := preload("res://scripts/hud_tray_kit.gd")
## (class_name YOK, hud_theme.gd ile aynı sebep).

const HudTheme := preload("res://scripts/hud_theme.gd")
const TRAY_TEX: Texture2D = preload("res://assets/ui/kit/hud_dock_tray_side.png")
const WELL_TEX: Texture2D = preload("res://assets/ui/kit/hud_console_well.png")
const PLATE_TEX: Texture2D = preload("res://assets/ui/kit/hud_console_plate.png")
const PLATE_HOVER_TEX: Texture2D = preload("res://assets/ui/kit/hud_console_plate_hover.png")
const PLATE_PRESSED_TEX: Texture2D = preload("res://assets/ui/kit/hud_console_plate_pressed.png")
const BAG_ICON: Texture2D = preload("res://assets/ui/kit/hud_icon_bag.png")
const TRAY_EDGE := 12.0
const P := 3.0


static func _tex_sb(tex: Texture2D, margins: Array, pads: Array) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margins[0]
	sb.texture_margin_top = margins[1]
	sb.texture_margin_right = margins[2]
	sb.texture_margin_bottom = margins[3]
	sb.content_margin_left = pads[0]
	sb.content_margin_top = pads[1]
	sb.content_margin_right = pads[2]
	sb.content_margin_bottom = pads[3]
	return sb


## Yan kutu tepsisi; pad = içeriğin kutu kenarından uzaklığı (çerçeve TRAY_EDGE'i örtmesin diye en az TRAY_EDGE + 3 önerilir).
static func tray(pad_x: float, pad_y: float) -> StyleBoxTexture:
	return _tex_sb(TRAY_TEX, [18, 18, 18, 18], [pad_x, pad_y, pad_x, pad_y])


static func well(pad_x: float = 0.0, pad_y: float = 0.0) -> StyleBoxTexture:
	return _tex_sb(WELL_TEX, [9, 9, 9, 12], [pad_x, pad_y, pad_x, pad_y])


## state: "normal" / "hover" / "pressed"
static func plate(state: String, pad_x: float = 9.0, pad_y: float = 0.0) -> StyleBoxTexture:
	var t: Texture2D = PLATE_TEX
	match state:
		"hover":
			t = PLATE_HOVER_TEX
		"pressed":
			t = PLATE_PRESSED_TEX
	return _tex_sb(t, [9, 9, 9, 9], [pad_x, pad_y, pad_x, pad_y])


## Düğmeye kabarık ahşap levha görünüşü (normal/üstünde/basılı; odak çerçevesi yok).
static func style_plate_button(b: Button, pad_x: float = 9.0) -> void:
	b.add_theme_stylebox_override("normal", plate("normal", pad_x))
	b.add_theme_stylebox_override("hover", plate("hover", pad_x))
	b.add_theme_stylebox_override("pressed", plate("pressed", pad_x))
	b.add_theme_stylebox_override("hover_pressed", plate("pressed", pad_x))
	b.add_theme_stylebox_override("disabled", plate("normal", pad_x))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c: String in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, HudTheme.TEXT)
	for c2: String in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c2, HudTheme.DIM)


## Düğmeye küçük Gömme Tepsi görünüşü (grup panelinin Hasar düğmesi): üstündeyken bir ton açık, basılıyken koyu (StyleBoxTexture
## modulate_color), yazı krem. pad_x/pad_y içerik payı (çerçeve 12 px).
static func style_tray_button(b: Button, pad_x: float = 18.0, pad_y: float = 6.0) -> void:
	var states: Array = [["normal", Color.WHITE], ["hover", Color(1.18, 1.14, 1.1)], ["pressed", Color(0.8, 0.78, 0.76)],
		["hover_pressed", Color(0.8, 0.78, 0.76)], ["disabled", Color(0.85, 0.85, 0.85)]]
	for st: Array in states:
		var sb: StyleBoxTexture = tray(pad_x, pad_y)
		sb.modulate_color = st[1]
		b.add_theme_stylebox_override(st[0], sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c: String in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, HudTheme.TEXT)
	for c2: String in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c2, HudTheme.DIM)


## Paneldeki Q-E-R ayracının yatay hâli: koyu çizgi + ahşap ışığı (2 x P).
static func draw_divider(ci: CanvasItem, x0: float, x1: float, y: float) -> void:
	ci.draw_rect(Rect2(x0, y, x1 - x0, P), HudTheme.OUTLINE)
	ci.draw_rect(Rect2(x0, y + P, x1 - x0, P), Color(HudTheme.RIM_HI, 0.6))
