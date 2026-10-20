extends Node2D

## Dışarıdaki BABAANNE'nin can çubuğu (madde 313): 22x4 dünya pikseli, koyu kenar + kırmızı dolgu + üst açık şerit.
## Babaanne kökü 0,5 ölçekli -> 1 dünya pikseli = 2 yerel birim. Can meta "hp" (babaanne_npc.gd on_hp_changed yazar), sadece değişince çizilir.

const W := 22.0
const H := 4.0
const MAX_HP := 100.0
const FRAME := Color(0.11, 0.07, 0.08)
const BACK := Color(0.28, 0.16, 0.15)
const FILL := Color(0.84, 0.27, 0.22)
const FILL_HI := Color(0.97, 0.52, 0.42)


func _draw() -> void:
	var k: float = 2.0 ## yerel birim / dünya pikseli
	var hp: float = clampf(float(get_meta("hp", MAX_HP)), 0.0, MAX_HP)
	var x0: float = -W * 0.5 * k
	draw_rect(Rect2(x0 - k, -k, (W + 2.0) * k, (H + 2.0) * k), FRAME)
	draw_rect(Rect2(x0, 0.0, W * k, H * k), BACK)
	var fw: float = round(W * hp / MAX_HP)
	if fw > 0.0:
		draw_rect(Rect2(x0, 0.0, fw * k, H * k), FILL)
		draw_rect(Rect2(x0, 0.0, fw * k, k), FILL_HI)
