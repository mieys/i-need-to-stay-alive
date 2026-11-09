extends Control

## SEÇİM KÖŞEBENTLERİ (madde 538, 2026-11-09; kullanıcı seçim ekranında altın dış kart çerçevesini sevmedi, 4 prototipten "C - Köşebentler"i
## seçti; prototip tools/proto_20261109/secim_vurgu/). Kartın dört köşesinde piksel L köşebent: kol 5, kalınlık 1 sanat pikseli (t ekran px),
## 1 px koyu dış hat (HudTheme.OUTLINE); kart kenarının 2 sanat px içinde. Kartın çocuğu, tam boy (anchor), fare olaylarını geçirir;
## YEREL koordinatta çizilir -> düğmenin nefes / basma ölçeği ile birlikte hareket eder. Renk yoksa (a = 0) çizilmez.
## Kullanım: const CornerBrackets := preload("res://scripts/corner_brackets.gd"); var br := CornerBrackets.new(); kart.add_child(br); br.set_color(c)

const HudTheme := preload("res://scripts/hud_theme.gd")

var t: float = 3.0
var arm_px: int = 5
var _col: Color = Color(0, 0, 0, 0)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_color(c: Color) -> void:
	if c != _col:
		_col = c
		queue_redraw()


func _draw() -> void:
	if _col.a <= 0.0:
		return
	var o: Color = HudTheme.OUTLINE
	var arm: float = arm_px * t
	var ins: float = 2.0 * t
	for cx in 2:
		for cy in 2:
			var x0: float = ins if cx == 0 else size.x - ins - arm
			var y0: float = ins if cy == 0 else size.y - ins - arm
			var hy: float = y0 if cy == 0 else y0 + arm - t ## yatay kol
			var vx: float = x0 if cx == 0 else x0 + arm - t ## dikey kol
			draw_rect(Rect2(x0 - 1.0, hy - 1.0, arm + 2.0, t + 2.0), o)
			draw_rect(Rect2(vx - 1.0, y0 - 1.0, t + 2.0, arm + 2.0), o)
			draw_rect(Rect2(x0, hy, arm, t), _col)
			draw_rect(Rect2(vx, y0, t, arm), _col)
