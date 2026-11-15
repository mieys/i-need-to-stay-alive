shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://shaders/kis_desen.gdshaderinc"

// AYAZ DAĞI (kış) ZEMİNİ (2026-11-12; desen madde 630 "B - Rüzgâr Sırtları"): "Yer/Zemin Toprak" (kar dolgu) + "Yer/Zemin Çimen" (göl kıyısının
// kar kenarı) + "Yer/Patika" (toprak yol / eriyen kar) + sıcak kaynak kıyısı ("Su/Su ayrıntılar 2") + "Yer/Leke" + "Yer/Kar süsleri" AYNI malzeme
// (tools/kis/bake_kis.gd). Desen + tasarım notu: shaders/kis_desen.gdshaderinc. Kar ailesi rampayla koyulaşır (karonun çizimi korunur), düz kar
// tabanında rüzgâr sırtları; toprak ailesi ıslak toprak tonuna iner. Başka renkler (buz, kaya koyuları) aynen kalır.

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = floor(world_pos);
	vec3 rgb = tex.rgb;
	if (kd_kar_aile(rgb)) {
		rgb = kd_kar(rgb, px);
	} else if (kd_toprak_aile(rgb)) {
		rgb = kd_toprak(rgb, px);
	}
	COLOR = vec4(rgb, tex.a);
	if (COLOR.a > 0.0) { COLOR.rgb = harita_renk(COLOR.rgb); } // harita renk ayarı (madde 181) - fragment()'in EN SONUNDA
}
