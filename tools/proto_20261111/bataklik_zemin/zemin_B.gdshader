shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261111/bataklik_zemin/ortak.gdshaderinc"

// B - TAŞ VE KÖK: yol üstünde seyrek BASAMAK TAŞLARI (setin kaya paleti, üstünde yosun pikseli, altında çamura düşen gölge) ve çamurdan
// yer yer çıkan KÖKLER (1 px koyu gövde + üstünde bir ton açık sırt = yuvarlak kök); çamur keskin iki ton (ıslak koyu / taban).
//  ÇİMEN: çok büyük iki ton + öbek öbek YONCA (üç yapraklı küçük leke: açık üst, orta, koyu gölge) + seyrek çakıl, ağaç diplerini andıran
//         kök bölgelerinde çimene de kök uzanır.

float kok_alan(vec2 p) {
	vec2 w = vec2(pz_vnoise(p * 0.02), pz_vnoise(p * 0.02 + vec2(17.0, 5.0))) - 0.5;
	return pz_fbm((p + w * 40.0) * vec2(0.022, 0.034));
}

// px kök pikseli mi (sağ ya da alt komşu farklı basamakta -> 4-bağlı 1 px çizgi), yalnız kök bölgesinde ve kesik kesik
bool kok(vec2 p, float esik) {
	if (pz_leke(p, 0.016, 10.0) < esik) { return false; }
	float a = kok_alan(p);
	const float K = 5.0;
	if (!(pz_sinir(a, kok_alan(p + vec2(1.0, 0.0)), K) || pz_sinir(a, kok_alan(p + vec2(0.0, 1.0)), K))) { return false; }
	// kesik: basamağa ve x'e göre parçalar
	return pz_vnoise(vec2(p.x * 0.09, floor(a * K) * 3.1)) > 0.36;
}

vec3 tas(vec3 tex, vec2 px, out bool var_mi) {
	var_mi = false;
	vec2 ci = floor(px / 21.0);
	if (pz_hash(ci + vec2(2.6, 9.3)) >= 0.24) { return tex; }
	bool buyuk = pz_hash(ci + vec2(5.1, 4.4)) < 0.55;
	int v = 0;
	if (buyuk) {
		ivec2 l = pz_hucre_yerel(px, 21.0, vec2(3.3, 1.2), 6, 5);
		if (l.x < 0) { return tex; }
		// 1 en koyu, 2 koyu, 3 orta, 4 açık, 5 parlak, 6 yosun, 7 gölge
		int r[5] = int[5](0x045460, 0x444336, 0x233322, 0x122221, 0x077770);
		v = pz_satir(r[l.y], l.x, 6);
	} else {
		ivec2 l = pz_hucre_yerel(px, 21.0, vec2(3.3, 1.2), 4, 4);
		if (l.x < 0) { return tex; }
		int r[4] = int[4](0x0540, 0x4433, 0x0220, 0x0770);
		v = pz_satir(r[l.y], l.x, 4);
	}
	if (v == 0) { return tex; }
	var_mi = true;
	if (v == 1) { return T_EN_KOYU; }
	if (v == 2) { return T_KOYU; }
	if (v == 3) { return T_ORTA; }
	if (v == 4) { return T_ACIK; }
	if (v == 5) { return T_PARLAK; }
	if (v == 6) { return G_ORTA; }
	return pz_ton_m(tex, M_KOYU);
}

vec3 cimen(vec3 tex, vec2 px) {
	float z = pz_leke(px, 0.0045, 40.0);
	vec3 c = pz_ton_c(tex, z > 0.58 ? mix(G_TABAN, G_ORTA, 0.35) : G_TABAN);
	// kök (yalnız kök bölgesinin en yoğun yerinde)
	if (kok(px, 0.70)) { return pz_ton_c(tex, mix(G_KOYU_ORTA, M_KOYU_ORTA, 0.6)); }
	if (kok(px + vec2(0.0, 1.0), 0.70)) { return pz_ton_c(tex, G_ORTA); }
	// yonca öbekleri: öbek alanında 6 px hücrede %55 (4x3)
	vec2 ci = floor(px / 6.0);
	float obek = pz_leke(ci * 6.0 + 3.0, 0.03, 10.0);
	if (obek > 0.6 && pz_hash(ci + vec2(1.4, 6.6)) < 0.55) {
		ivec2 l = pz_hucre_yerel(px, 6.0, vec2(6.2, 2.9), 4, 3);
		if (l.x >= 0) {
			int r[3] = int[3](0x0330, 0x3223, 0x0110);
			int v = pz_satir(r[l.y], l.x, 4);
			if (v == 3) { return pz_ton_c(tex, G_ACIK); }
			if (v == 2) { return pz_ton_c(tex, G_ORTA); }
			if (v == 1) { return pz_ton_c(tex, G_KOYU_ORTA); }
		}
	}
	// seyrek çakıl (23 px hücre %8, 2x1 + gölge; gri tonu çimende pembe okunuyordu -> koyu gri)
	ivec2 g = pz_hucre_yerel(px, 23.0, vec2(8.8, 0.3), 2, 2);
	if (g.x >= 0 && pz_hash(floor(px / 23.0) + vec2(4.0, 4.0)) < 0.08) {
		if (g.y == 0) { return g.x == 0 ? T_ORTA : T_KOYU; }
		return pz_ton_c(tex, G_ORTA);
	}
	return c;
}

vec3 yol(vec3 tex, vec2 px) {
	float z = pz_leke(px, 0.010, 30.0);
	vec3 c = pz_ton_m(tex, z > 0.60 ? M_ORTA : M_TABAN);
	bool var_mi;
	vec3 t = tas(tex, px, var_mi);
	if (var_mi) { return t; }
	if (kok(px, 0.58)) { return pz_ton_m(tex, M_EN_KOYU); }
	if (kok(px + vec2(0.0, 1.0), 0.58)) { return pz_ton_m(tex, M_KOYU_ORTA); }
	// ince çakıl: 7 px hücrede %12 tek piksel
	vec2 ci = floor(px / 7.0);
	vec2 o = ci * 7.0 + floor(vec2(pz_hash(ci + vec2(2.0, 0.5)), pz_hash(ci + vec2(7.0, 3.5))) * 6.0);
	if (px == o && pz_hash(ci + vec2(3.3, 1.1)) < 0.12) { c = pz_ton_m(tex, M_ACIK); }
	return c;
}

#include "res://tools/proto_20261111/bataklik_zemin/son.gdshaderinc"
