shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261111/bataklik_zemin/ortak.gdshaderinc"

// D - AKIŞ KIVRIMLARI: yatayda uzamış kıvrımlı eş yükselti çizgileri, kesik kesik.
//  YOL:   ağır akan çamurun SIRTLARI - sınırın üst pikseli bir ton açık (ışık alan sırt), alt pikseli bir ton koyu (sırtın gölgesi); sırtlar
//         arasındaki çukurlarda yer yer ıslak koyu yama + tek piksel su parıltısı.
//  ÇİMEN: rüzgârla TARANMIŞ çayır - aynı yöntemle kısa çizgiler (üstü açık, altı orta), 3-7 px'lik kesikler hâlinde; zemin düz.

float camur_alan(vec2 p) {
	vec2 w = vec2(pz_vnoise(p * 0.015), pz_vnoise(p * 0.015 + vec2(11.0, 23.0))) - 0.5;
	return pz_fbm((p + w * 60.0) * vec2(0.012, 0.040));
}

float cim_alan(vec2 p) {
	vec2 w = vec2(pz_vnoise(p * 0.012), pz_vnoise(p * 0.012 + vec2(41.0, 3.0))) - 0.5;
	return pz_fbm((p + w * 70.0) * vec2(0.010, 0.036));
}

vec3 cimen(vec3 tex, vec2 px) {
	vec3 c = pz_ton_c(tex, G_TABAN);
	const float K = 7.0;
	float a = cim_alan(px);
	float alt = cim_alan(px + vec2(0.0, 1.0));
	float ust = cim_alan(px - vec2(0.0, 1.0));
	bool s_ust = pz_sinir(a, alt, K);   // px çizginin üst pikseli
	bool s_alt = pz_sinir(ust, a, K);   // px çizginin alt pikseli
	if (!s_ust && !s_alt) { return c; }
	float lv = floor((s_ust ? a : ust) * K);
	// kesik: basamağa göre kaydırılmış 3-7 px parçalar, yarısı boş
	float seg = floor((px.x + lv * 13.0) / (3.0 + floor(pz_hash(vec2(lv, 2.0)) * 5.0)));
	if (pz_hash(vec2(seg, lv + 0.5)) < 0.6) { return c; }
	return s_ust ? pz_ton_c(tex, G_ACIK) : pz_ton_c(tex, G_ORTA);
}

vec3 yol(vec3 tex, vec2 px) {
	const float K = 7.0;
	float a = camur_alan(px);
	float alt = camur_alan(px + vec2(0.0, 1.0));
	float ust = camur_alan(px - vec2(0.0, 1.0));
	float fr = fract(a * K);
	vec3 c = pz_ton_m(tex, M_TABAN);
	// çukur (basamağın alt dilimi) - büyük ıslak alanlarda koyu yama
	bool islak = pz_leke(px, 0.02, 12.0) > 0.55;
	if (islak && fr < 0.30) {
		c = pz_ton_m(tex, M_ORTA);
		vec2 ci = floor(px / 6.0);
		vec2 o = ci * 6.0 + floor(vec2(pz_hash(ci + vec2(2.0, 0.5)), pz_hash(ci + vec2(7.0, 3.5))) * 5.0);
		if (px == o && pz_hash(ci + vec2(5.3, 1.1)) < 0.12) { c = birikinti_isik.rgb; }
	}
	bool s_ust = pz_sinir(a, alt, K);
	bool s_alt = pz_sinir(ust, a, K);
	if (s_ust || s_alt) {
		float lv = floor((s_ust ? a : ust) * K);
		float seg = floor((px.x + lv * 17.0) / (5.0 + floor(pz_hash(vec2(lv, 7.0)) * 7.0)));
		if (pz_hash(vec2(seg, lv + 0.25)) < 0.7) {
			c = s_ust ? pz_ton_m(tex, M_ACIK) : pz_ton_m(tex, M_KOYU_ORTA);
		}
	}
	return c;
}

#include "res://tools/proto_20261111/bataklik_zemin/son.gdshaderinc"
