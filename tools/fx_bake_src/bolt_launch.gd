extends "res://tools/fx_bake_src/fx_totem_fire_bolt.gd"

## Pişirme sahnesi: sadece ATIŞ ANI patlaması (halka + parlama), orijinde; ilk 0,12 sn.


func _init() -> void:
	travel_time = 1.0


func _draw_flight() -> void:
	var t: float = PixelDraw.TEXEL
	if _elapsed < 0.12:
		var m: float = _elapsed / 0.12
		PixelDraw.ring(self, start_pos, 3.0 * t + m * 12.0 * t, Color(PixelDraw.fire_color(0.1 + 0.6 * m), 1.0 - m), 1)
		PixelDraw.disc(self, start_pos, (1.0 - m) * 5.0 * t, Color(1.0, 0.85, 0.4, 1.0 - m))
