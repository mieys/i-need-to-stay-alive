extends Node2D

## Melek pasifi iyileştirme işareti (2026-10-10, kullanıcı prototip "A · Artı Işıltısı"nı seçti; tools/proto_20261010/gen_protos.py eff_plus):
## karakterin başının üstünde iki küçük yeşil-beyaz artı (5x5 piksel, ortası beyaz) yükselip söner. Minimalist, kozmetik, ~1 sn.
## Melek'in kendi istemcisinde player.gd _melek_heal_sparkles kurar; diğer istemcilere NetworkManager "melek_sparkle" ile gider (hedef peer'lerin
## düğümüne eklenir). Ebeveynin (karakter kökü) üstünde yerel konumla durur, karakterle birlikte hareket eder.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const LIFE := 1.0
const RISE := 16.0 ## texel
const HEAD_Y := -44.0 ## karakter kökünden başın üstü (dünya px; karakterler %15 küçüldükten sonra)
const C_ARM := Color(0.47, 0.92, 0.55)
const C_CORE := Color(0.94, 1.0, 0.94)
const PLUSES := [[-7.0, 0.0], [6.0, 0.35]] ## [x texel, gecikme sn]

var _t: float = 0.0


func _ready() -> void:
	z_index = 60
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2(0.0, HEAD_Y)


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE + 0.35:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var tx: float = PixelDraw.TEXEL
	for p: Array in PLUSES:
		var tt: float = (_t - float(p[1])) / LIFE
		if tt <= 0.0 or tt >= 1.0:
			continue
		var a: float = sin(tt * PI)
		var c := Vector2(float(p[0]) * tx, (6.0 - tt * RISE) * tx).round()
		var arm := Color(C_ARM.r, C_ARM.g, C_ARM.b, a)
		for off: Vector2 in [Vector2(0, -2), Vector2(0, -1), Vector2(-2, 0), Vector2(-1, 0), Vector2(1, 0), Vector2(2, 0), Vector2(0, 1), Vector2(0, 2)]:
			draw_rect(Rect2(c + off * tx, Vector2(tx, tx)), arm)
		draw_rect(Rect2(c, Vector2(tx, tx)), Color(C_CORE.r, C_CORE.g, C_CORE.b, a))
