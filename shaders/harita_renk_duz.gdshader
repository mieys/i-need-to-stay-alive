shader_type canvas_item;

// Kendi shader'ı olmayan harita katmanları (orman, ev, köprü, maden, dış orman...) için SADECE harita renk ayarı
// (bkz. harita_renk.gdshaderinc, scripts/map_color_grade.gd). Zemin ayrıntısı kapalıyken zemin katmanları da bunu alır. Derin orman bölge
// zemini artık Harita.tmx'te GERÇEK KAROLAR ("Yer/Derin orman zemini", madde 363) - burada hesaplanmaz.

#include "res://shaders/harita_renk.gdshaderinc"

varying vec2 hr_dunya; // derin orman bölge renk ayarı için dünya konumu (madde 359)
// Dış çerçeve ormanı (Dış orman 1-4): yapraklar bölgenin ağaç paletine - Batı'da kızıl (madde 362), madde 365'ten beri kuzey/doğu/güney de
// (map_color_grade.gd outer_forest_material); 0 = yok.
uniform float do_dis_orman = 0.0;

void vertex() {
	hr_dunya = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (do_dis_orman > 0.5) {
		if (COLOR.a > 0.0) { COLOR.rgb = do_agac_guc(COLOR.rgb, hr_dunya, DOB_AGAC_GUC); }
	}
	if (COLOR.a > 0.0) { COLOR.rgb = harita_renk_d(COLOR.rgb, hr_dunya); }
}
