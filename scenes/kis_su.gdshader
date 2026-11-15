shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"

// AYAZ DAĞI SICAK KAYNAĞI (2026-11-12). "Su/Su" katmanı DÜZ MAVİ karo (collision mavi pikseli su sayar - kaynak yürünmez); görünüş burada:
//  - sıcak kaynağın ılık turkuaz rengi; çok yavaş kayan, KISIK açık / koyu lekeler (kontrast düşük),
//  - KABARCIKLAR: seyrek noktalarda 1 px'ten 3 px'e büyüyüp sönen halkalar (kaynayan su; yüzeyden buhar kis_fx.gd'de),
//  - seyrek tek piksel ışıltı.
// Desen dünya pikselinde, dither yok (madde 424 "sade su"). Dalga izleri ayrı katmanda ("Su süsleri", setin animasyonlu izleri).

uniform vec4 su_rengi : source_color = vec4(0.243, 0.596, 0.627, 1.0);    // #3e98a0
uniform vec4 su_koyu : source_color = vec4(0.212, 0.533, 0.584, 1.0);
uniform vec4 su_acik : source_color = vec4(0.302, 0.663, 0.675, 1.0);
uniform vec4 kabarcik_rengi : source_color = vec4(0.659, 0.890, 0.863, 1.0);
uniform float leke_olcegi : hint_range(0.002, 0.06) = 0.02;
uniform float akis_hizi : hint_range(0.0, 10.0) = 3.0;
uniform float kabarcik_yogunlugu : hint_range(0.0, 0.5) = 0.1;            // 10 px hücre başına
uniform float kabarcik_hizi : hint_range(0.05, 2.0) = 0.6;

varying vec2 world_pos;

float ks_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ks_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(ks_hash12(i), ks_hash12(i + vec2(1.0, 0.0)), f.x), mix(ks_hash12(i + vec2(0.0, 1.0)), ks_hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float ks_fbm(vec2 p) {
	return ks_vnoise(p) * 0.55 + ks_vnoise(p * 2.03) * 0.30 + ks_vnoise(p * 4.01) * 0.15;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = floor(world_pos);
	float t = TIME;
	vec2 akis = vec2(t * akis_hizi, -t * akis_hizi * 0.6);
	vec2 w = vec2(ks_fbm((px + akis * 0.5) * 0.02), ks_fbm((px - akis * 0.3) * 0.02 + vec2(17.3, 5.1))) - 0.5;
	float z = ks_fbm((px + akis + w * 18.0) * leke_olcegi);
	vec3 c = su_rengi.rgb;
	if (z > 0.62) { c = su_koyu.rgb; }
	if (z < 0.36) { c = su_acik.rgb; }
	// kabarcık halkaları
	const float HC = 10.0;
	vec2 hc = floor(px / HC);
	float h = ks_hash12(hc + vec2(7.7, 1.9));
	if (h < kabarcik_yogunlugu) {
		vec2 o = floor(vec2(ks_hash12(hc + vec2(2.3, 9.1)), ks_hash12(hc + vec2(5.6, 3.3))) * (HC - 6.0)) + 3.0;
		vec2 l = px - hc * HC - o;
		float ph = fract(t * kabarcik_hizi + h * 31.0);
		if (ph < 0.5) {
			float r = floor(ph * 6.0); // 0..2
			float d = max(abs(l.x), abs(l.y));
			bool halka = r == 0.0 ? (l == vec2(0.0)) : (d == r && abs(l.x) + abs(l.y) <= r + 1.0);
			if (halka) {
				c = mix(c, kabarcik_rengi.rgb, r == 0.0 ? 0.7 : (r == 1.0 ? 0.5 : 0.3));
			}
		}
	}
	COLOR = vec4(c, tex.a);
	if (COLOR.a > 0.0) { COLOR.rgb = harita_renk(COLOR.rgb); }
}
