shader_type canvas_item;
render_mode unshaded;

// SİSLİ HAVA 1 - "YER SİSİ" (madde 282 prototipi): zeminde süzülen soluk gri-yeşil sis kümeleri (zemine bağlı, rüzgarla
// çok yavaş kayar, kendi içinde kıvrılır), 3 düz kademe, dither yok. Renkler biraz solgun ve serin; karakterin çevresinde
// sis hafifçe aralanır. En hafif sürüm - oyun alanı tamamen okunur.
#include "res://tools/proto_20261019/gunes_sis/gs_ortak.gdshaderinc"
#include "res://tools/proto_20261019/gunes_sis/sis_ortak.gdshaderinc"

uniform vec3 sis_gunduz : source_color = vec3(0.76, 0.81, 0.8);
uniform float yogunluk = 0.3;

void fragment() {
	vec2 px = gs_texel(SCREEN_UV);
	vec2 uv = gs_uv(px);
	vec3 base = texture(ekran, SCREEN_UV).rgb;
	vec3 col = sis_renk_ayari(base, 0.28, vec3(0.92, 0.97, 0.96), 0.93);
	float m = smoothstep(0.36, 0.74, yer_sisi(px, 0.0062));
	float k = gs_kademe(m, 4.0);
	float a = k * yogunluk * mix(0.45, 1.0, aralik(px, 18.0, 70.0)) * sis_k;
	col = mix(col, sis_rengi(sis_gunduz), a);
	col *= mix(1.0, vinyet(uv, 0.18), sis_k);
	COLOR = vec4(col, 1.0);
}
