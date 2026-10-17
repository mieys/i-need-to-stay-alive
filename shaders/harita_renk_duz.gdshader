shader_type canvas_item;

// Kendi shader'ı olmayan harita katmanları (orman, ev, köprü, maden, dış orman...) için SADECE harita renk ayarı
// (bkz. harita_renk.gdshaderinc, scripts/map_color_grade.gd). Zemin ayrıntısı kapalıyken zemin katmanları da bunu alır.

#include "res://shaders/harita_renk.gdshaderinc"

void fragment() {
	COLOR.rgb = harita_renk(COLOR.rgb);
}
