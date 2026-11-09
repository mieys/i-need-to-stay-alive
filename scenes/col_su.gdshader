shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"

// ALTIN KUMLAR VAHA SUYU (2026-11-09). "Su/Su" katmanı DÜZ MAVİ karo (collision mavi pikseli su sayar - vaha suyu yürünmez); görünüş burada:
//  - çöl setinin kendi su rengi (#3e8e96: kıyı karolarının sığ su gölgesi + köpüğü bu renge göre çizilmiş -> dikişsiz),
//  - çok yavaş kayan, kıvrımlı ve KISIK koyu (derin) / açık (güneşli sığ) lekeler - berrak vaha suyu, kontrast düşük,
//  - seyrek, kısa yanıp sönen 1-3 px güneş pırıltısı.
// Desen dünya pikselinde, dither yok (oyunun "sade su" kararı, madde 424). Dalga izleri ayrı katmanda ("Su süsleri", setin animasyonlu izleri).
// Kara Bataklık suyunun (shaders/bataklik_su_desen.gdshaderinc) aynısı, renkler vahanın.

uniform vec4 su_rengi : source_color = vec4(0.243, 0.557, 0.588, 1.0);    // #3e8e96 - setin su karosu
uniform vec4 su_koyu : source_color = vec4(0.231, 0.533, 0.565, 1.0);
uniform vec4 su_daha_koyu : source_color = vec4(0.216, 0.506, 0.541, 1.0);
uniform vec4 su_acik : source_color = vec4(0.263, 0.584, 0.612, 1.0);
uniform vec4 parilti_rengi : source_color = vec4(0.651, 0.871, 0.851, 1.0);
uniform float leke_olcegi : hint_range(0.002, 0.04) = 0.012;
uniform float kivrim : hint_range(0.0, 60.0) = 24.0;
uniform float akis_hizi : hint_range(0.0, 10.0) = 2.0;
uniform float koyu_esik : hint_range(0.3, 0.9) = 0.60;
uniform float daha_koyu_esik : hint_range(0.3, 0.95) = 0.73;
uniform float acik_esik : hint_range(0.05, 0.6) = 0.36;
uniform float parilti_yogunlugu : hint_range(0.0, 0.2) = 0.03;            // 9 px hücre başına
uniform float parilti_hizi : hint_range(0.05, 2.0) = 0.38;

varying vec2 world_pos;

float cs_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float cs_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(cs_hash12(i), cs_hash12(i + vec2(1.0, 0.0)), f.x), mix(cs_hash12(i + vec2(0.0, 1.0)), cs_hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float cs_fbm(vec2 p) {
	return cs_vnoise(p) * 0.55 + cs_vnoise(p * 2.03) * 0.30 + cs_vnoise(p * 4.01) * 0.15;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = floor(world_pos);
	float t = TIME;
	vec2 akis = vec2(t * akis_hizi, t * akis_hizi * 0.37);
	vec2 w = vec2(cs_fbm((px + akis * 0.5) * 0.013), cs_fbm((px - akis * 0.3) * 0.013 + vec2(17.3, 5.1))) - 0.5;
	float z = cs_fbm((px + akis + w * kivrim) * leke_olcegi);
	vec3 c = su_rengi.rgb;
	if (z > koyu_esik) { c = su_koyu.rgb; }
	if (z > daha_koyu_esik) { c = su_daha_koyu.rgb; }
	if (z < acik_esik) { c = su_acik.rgb; }
	const float HC = 9.0;
	vec2 hc = floor(px / HC);
	float h = cs_hash12(hc + vec2(7.7, 1.9));
	if (h < parilti_yogunlugu) {
		vec2 o = floor(vec2(cs_hash12(hc + vec2(2.3, 9.1)), cs_hash12(hc + vec2(5.6, 3.3))) * (HC - 2.0)) + 1.0;
		vec2 l = px - hc * HC - o;
		float ph = fract(t * parilti_hizi + h * 31.0);
		if (ph < 0.10) {
			bool merkez = l == vec2(0.0);
			bool kol = ph > 0.03 && ph < 0.07 && (abs(l.x) + abs(l.y) == 1.0);
			if (merkez || kol) {
				c = mix(c, parilti_rengi.rgb, merkez ? 0.85 : 0.5);
			}
		}
	}
	COLOR = vec4(c, tex.a);
	if (COLOR.a > 0.0) { COLOR.rgb = harita_renk(COLOR.rgb); }
}
