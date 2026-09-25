extends Control

## Arayüzdeki küçük can/kalkan/oran çubuğu - karakterin üstündeki çubukla BİREBİR aynı çizim (overhead_bar.gd
## draw_pixel_bar: kalın siyah çerçeve, hafif oval köşe, sert gölge, üstte parlama şeridi). Kullanıcı isteği (2026-09-25):
## "grup paneli ... can kalkan barları tıpkı karakterin üstündeki can kalkan barına benzer olmalı gereksiz yer kaplamaması
## gereksiz ayrıntılı olmaması için" - party_panel.gd satırları ve hasar sıralaması bunu kullanır.

const OverheadBarScript := preload("res://scripts/overhead_bar.gd")

var ratio: float = 1.0
var fill_color: Color = Color(0.30, 0.82, 0.24, 1.0)
var bg_color: Color = Color(0.12, 0.04, 0.04, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_values(new_ratio: float, new_fill: Color) -> void:
	new_ratio = clampf(new_ratio, 0.0, 1.0)
	if is_equal_approx(new_ratio, ratio) and new_fill.is_equal_approx(fill_color):
		return
	ratio = new_ratio
	fill_color = new_fill
	queue_redraw()


func _draw() -> void:
	## Çerçeve (OUTLINE) ve gölge (SHADOW_OFFSET) kontrolün İÇİNDE kalsın diye dolgu dikdörtgeni içeri alınır.
	var o: float = OverheadBarScript.OUTLINE
	var inner := Rect2(Vector2(o, o), size - Vector2(o * 2.0 + 1.0, o * 2.0 + 1.0))
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	OverheadBarScript.draw_pixel_bar(self, inner, ratio, fill_color, bg_color)
