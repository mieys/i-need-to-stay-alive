shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://shaders/su_bulanik.gdshaderinc"

// KARA BATAKLIK SU SÜSLERİ ("Su/Su süsleri": dalga izleri, nilüfer, su mercimeği; 2026-11-16). Eskiden kendi shader'ı yoktu, harita renk
// ayarının düz materyalini alıyordu (map_color_grade.gd plain_material). Bulanık su (shaders/su_bulanik.gdshaderinc) açıkken karolardaki
// setin eski su paleti (nilüfer gölgesi, mercimek parıltısı, dalga izi) yeni suya boyanır - yoksa suyun üstünde eski camgöbeği lekeler kalır.
// Materyali scripts/water_fx.gd attach kurar (profil "su_doku" -> "su_karolari"); sonra yalnız renk ayarı (harita_renk_duz ile aynı).

uniform vec4 su_rengi : source_color = vec4(0.169, 0.337, 0.255, 1.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (COLOR.a > 0.0) {
		if (bulanik) {
			COLOR.rgb = su_bulanik_karo(COLOR.rgb, su_rengi.rgb, floor(world_pos), TIME);
		}
		COLOR.rgb = harita_renk_d(COLOR.rgb, world_pos);
	}
}
