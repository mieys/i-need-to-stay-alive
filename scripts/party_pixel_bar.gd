extends Control

## Grup panelindeki müttefik can/kalkan çubuğu (2026-10-10, kullanıcı: "grup penceresindeki can kalkan sayıları berbat görünüyor, çok tuhaf ve kalitesiz;
## tıpkı karakterlerin üstündeki can ve kalkan barları gibi olsun fakat daha geniş, içine yazı sığabilecek şekilde"). Çizim karakter üstü çubukla AYNI
## fonksiyon (overhead_bar.gd draw_pixel_bar: kalın siyah çerçeve, hafif yuvarlak köşe, sert gölge, üstte parlama şeridi) - iki görünüm ayrışmasın.
## Eski TextureProgressBar (görev çubuğu dokusu) arayüzüyle uyumlu: `value` (0..1) + `tint_progress`. Sayı çocuk bar_value_label.gd'dir.

const OverheadBarScript := preload("res://scripts/overhead_bar.gd")
const INSET := 3.0 ## çerçeve (2) + gölge (1) çubuğun kutusunun içinde kalsın

var bg_color := Color(0.12, 0.04, 0.04, 1.0)
var max_value: float = 1.0
var value: float = 1.0:
	set(v):
		if not is_equal_approx(v, value):
			value = v
			queue_redraw()
var tint_progress := Color(0.30, 0.82, 0.24, 1.0):
	set(v):
		if not v.is_equal_approx(tint_progress):
			tint_progress = v
			queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func _draw() -> void:
	var r := Rect2(Vector2(INSET - 1.0, INSET - 1.0), size - Vector2(INSET * 2.0, INSET * 2.0))
	OverheadBarScript.draw_pixel_bar(self, r, clampf(value / maxf(max_value, 0.001), 0.0, 1.0), tint_progress, bg_color)
