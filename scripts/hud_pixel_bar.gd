extends Control

## Oyuncu panelindeki (hud.gd "oyuncu dock'u") can/kalkan çubuğu - kullanıcının seçtiği yetenek paneli prototipi B'deki
## (2026-09-27) piksel çubuk: 2 px koyu kontur, köşeleri 2 px kesik, üstte açık / altta koyu şerit, ortada değer yazısı.
## hud.gd update_health / _on_item_shield_changed besler (set_values).

var ratio: float = 1.0
var fill: Color = Color(0.36, 0.78, 0.29)
var under: Color = HudTheme.INSET
var text: String = ""
var font_size: int = 24

const HudTheme := preload("res://scripts/hud_theme.gd")
const OUTLINE := HudTheme.OUTLINE
const TEXT_COLOR := Color("#fff0d6")

## 2026-10-14 (oyuncu paneli yeniden tasarımı, kullanıcının seçtiği prototip 2): "birleşik" kip - solda piksel ikon
## (icon_kind: "heart" / "shield"), değer yazısı çubuğun SAĞ ucunda ve dolgu yazının altından geçer; mevcut değer açık,
## "/azami" soluk. Yazı kalın piksel yazı tipinin TAM katında (PixeloidSans 9 x 2) - eski bulanıklığın sebebi kesirli
## ölçekti (22 px x 0,85). Telefon HUD'u bu kipi açmaz (eski ortalanmış yazı).
const PixelIcons := preload("res://scripts/hud_pixel_icons.gd")
const VALUE_FONT: Font = preload("res://assets/fonts/PixeloidSans-Bold.ttf")
const VALUE_FONT_SIZE := 18
const VALUE_CAP := 14.0 ## rakam yüksekliği (7 sanat pikseli x 2)
const VALUE_DIM := HudTheme.DIM
const ICON_SPACE := 28.0 ## ikon (22 px) + boşluk; çubuk bundan sonra başlar
var merged: bool = false
var icon_kind: String = ""
var value_color: Color = TEXT_COLOR


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_values(new_ratio: float, new_fill: Color, new_text: String) -> void:
	new_ratio = clampf(new_ratio, 0.0, 1.0)
	if is_equal_approx(new_ratio, ratio) and new_fill.is_equal_approx(fill) and new_text == text:
		return
	ratio = new_ratio
	fill = new_fill
	text = new_text
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if merged and icon_kind != "":
		var ip := Vector2(0.0, roundf((size.y - 20.0) * 0.5))
		if icon_kind == "shield":
			PixelIcons.draw_shape(self, PixelIcons.SHIELD, ip, 2.0, PixelIcons.SHIELD_COLOR)
		else:
			PixelIcons.draw_shape(self, PixelIcons.HEART, ip, 2.0, PixelIcons.HEART_COLOR)
		r = Rect2(Vector2(ICON_SPACE, 0.0), size - Vector2(ICON_SPACE, 0.0))
	if r.size.x < 6.0 or r.size.y < 6.0:
		return
	draw_rect(Rect2(r.position + Vector2(2, 0), Vector2(r.size.x - 4, r.size.y)), OUTLINE)
	draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, r.size.y - 4)), OUTLINE)
	var inner := r.grow(-2)
	draw_rect(inner, under)
	var w: float = round(inner.size.x * ratio / 2.0) * 2.0
	if w > 0.0:
		draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), fill)
		draw_rect(Rect2(inner.position, Vector2(w, 2)), fill.lightened(0.35))
		draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 2), Vector2(w, 2)), fill.darkened(0.3))
	if merged:
		_draw_value_right(r)
	elif text != "":
		var f: Font = get_theme_default_font()
		var ts: Vector2 = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var p := Vector2(round((size.x - ts.x) * 0.5), round((size.y + ts.y * 0.62) * 0.5))
		draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(3, int(round(font_size * 0.2))), OUTLINE) ## kontur yazıyla orantılı (eskiden sabit 6: küçük yazıyı dolduruyordu)
		draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_COLOR)


## "1284/2150": sağa yaslı, mevcut değer value_color, "/azami" soluk; koyu kontur dolgunun üstünde de okutur.
func _draw_value_right(r: Rect2) -> void:
	if text == "":
		return
	var cut: int = text.find("/")
	var cur: String = text if cut < 0 else text.substr(0, cut)
	var rest: String = "" if cut < 0 else text.substr(cut)
	var w_cur: float = VALUE_FONT.get_string_size(cur, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FONT_SIZE).x
	var w_rest: float = VALUE_FONT.get_string_size(rest, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FONT_SIZE).x
	var p := Vector2(roundf(r.end.x - 10.0 - w_cur - w_rest), roundf(r.position.y + (r.size.y + VALUE_CAP) * 0.5))
	draw_string_outline(VALUE_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FONT_SIZE, 6, OUTLINE)
	draw_string(VALUE_FONT, p, cur, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FONT_SIZE, value_color)
	if rest != "":
		draw_string(VALUE_FONT, p + Vector2(w_cur, 0.0), rest, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FONT_SIZE, VALUE_DIM)
