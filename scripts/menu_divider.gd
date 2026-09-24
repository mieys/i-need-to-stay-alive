extends Control

## Menü bölüm başlığının iki yanındaki süs çizgisi (bkz. MenuKit.make_section_header): 1 texel (3 px) kalınlığında
## yatay çizgi, başlığa bakan ucunda küçük bir elmas. flip=false: sol taraf (elmas sağ uçta), true: sağ taraf.

var flip: bool = false
## Renkler MenuKit.C_LINE / C_ACCENT ile aynı (MenuKit bu scripti preload ettiği için buradan geri referans verilmiyor).
var line_color: Color = Color("#b3804b")
var diamond_color: Color = Color("#9c4f27")


func _init() -> void:
	custom_minimum_size = Vector2(30, 21)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	const T := 3.0
	var cy: float = floorf(size.y / (2.0 * T)) * T
	var line_col: Color = line_color
	var dia_col: Color = diamond_color
	## çizgi (elmasa kadar)
	if flip:
		draw_rect(Rect2(4 * T, cy, size.x - 4 * T, T), line_col)
	else:
		draw_rect(Rect2(0, cy, size.x - 4 * T, T), line_col)
	## elmas: 3 sütun (1-3-1)
	var ex: float = 0.0 if flip else size.x - 3 * T
	draw_rect(Rect2(ex, cy, T, T), dia_col)
	draw_rect(Rect2(ex + T, cy - T, T, 3 * T), dia_col)
	draw_rect(Rect2(ex + 2 * T, cy, T, T), dia_col)
