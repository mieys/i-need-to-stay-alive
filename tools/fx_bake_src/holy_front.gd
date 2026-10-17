extends "res://tools/fx_bake_src/fx_melek_holy.gd"

## Pişirme: sadece ÖN katman, şok halkası HARİÇ (halka shader ile çiziliyor): ilk parlama + halo + yükselen "+" parıltılar.


func _draw() -> void:
	pass


func _draw_front() -> void:
	var env: float = _envelope()
	var texel: float = PixelDraw.TEXEL
	if _t < 0.12:
		PixelDraw.disc_dither(_front, BODY_CENTER, 54.0, Color(1.0, 0.98, 0.8, 0.9), int(_t * 60.0), 2)
	if env > 0.0:
		var hp: Vector2 = BODY_CENTER + Vector2(0, -36.0)
		for i in range(28):
			var ha: float = float(i) * TAU / 28.0
			var col: Color = WHITE_GOLD if (i + int(_t * 14.0)) % 5 == 0 else GOLD
			PixelDraw.px(_front, hp + Vector2(cos(ha) * 15.0, sin(ha) * 5.0), 1, col)
	for s in _sparkles:
		var k: float = float(s[1]) / float(s[2])
		var p: Vector2 = s[0]
		var col2: Color = WHITE_GOLD if k < 0.5 else GOLD
		PixelDraw.px(_front, p, 1, col2)
		if k > 0.15 and k < 0.8:
			for o in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
				PixelDraw.px(_front, p + o * texel, 1, col2)
