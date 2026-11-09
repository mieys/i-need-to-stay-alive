shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://shaders/col_desen.gdshaderinc"

// ALTIN KUMLAR (çöl) ZEMİNİ (2026-11-09): "Yer/Zemin Toprak" (kum dolgu) + "Yer/Zemin Çimen" (saçaklı çimen) + kıyı karoları
// ("Su/Su ayrıntılar 2": kum ve çimen kıyısı - kıyının kumu / çimeni de iç zeminle aynı desende) AYNI malzeme (tools/col/bake_col.gd).
// Desen + tasarım notu: shaders/col_desen.gdshaderinc. Yalnız taban rengine yakın pikseller değişir: saçak, kenar, kıyı köpüğü aynen kalır.

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = floor(world_pos);
	vec3 rgb = tex.rgb;
	float mk = cd_kum_maske(rgb);
	if (mk > 0.0) {
		rgb = mix(rgb, cd_kum(tex.rgb, px), mk);
	}
	float mc = cd_cim_maske(tex.rgb);
	if (mc > 0.0) {
		rgb = mix(rgb, cd_cimen(tex.rgb, px), mc);
	}
	COLOR = vec4(rgb, tex.a);
	if (COLOR.a > 0.0) { COLOR.rgb = harita_renk(COLOR.rgb); } // harita renk ayarı (madde 181) - fragment()'in EN SONUNDA
}
