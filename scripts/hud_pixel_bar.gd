extends Control

## Oyuncu panelindeki (hud.gd "oyuncu dock'u") can/kalkan çubuğu - kullanıcının seçtiği yetenek paneli prototipi B'deki
## (2026-09-27) piksel çubuk: 2 px koyu kontur, köşeleri 2 px kesik, üstte açık / altta koyu şerit, ortada değer yazısı.
## hud.gd update_health / _on_item_shield_changed besler (set_values).

var ratio: float = 1.0
var fill: Color = Color(0.36, 0.78, 0.29)
var under: Color = Color(0.13, 0.08, 0.05)
var text: String = ""
var font_size: int = 24

const OUTLINE := Color("#1e120a")
const TEXT_COLOR := Color("#fff0d6")


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
	if text != "":
		var f: Font = get_theme_default_font()
		var ts: Vector2 = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var p := Vector2(round((size.x - ts.x) * 0.5), round((size.y + ts.y * 0.62) * 0.5))
		draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, OUTLINE)
		draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_COLOR)
