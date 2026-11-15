shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261111/bataklik_zemin/ortak.gdshaderinc"

// C - SAKİN DOKU: öbek / süs YOK - zeminin her yerine yayılmış, DÜŞÜK KONTRASTLI ince doku (çiftlik oyunlarının çimen/toprak dokusu gibi).
// Tonlar taban ile komşu tonun ARASINDA (yarım ton), göz yormaz; uzaktan neredeyse düz, yakından dokulu.
//  ÇİMEN: 4 px hücrede yarısında rüzgâra yatık 2 px koyu yaprak izi, bir kısmında 1 px açık uç; arada seyrek tam ton küçük tutam.
//  YOL:   3 px hücrede seyrek koyu / açık tek piksel benek, 11 px hücrede çakıl (2x1 + gölge), çok büyük yumuşak iki ton.

const vec3 G_YARI_KOYU = vec3(0.518, 0.598, 0.2745);   // TABAN ile ORTA arası
const vec3 G_YARI_ACIK = vec3(0.6235, 0.6785, 0.296);  // TABAN ile AÇIK arası
const vec3 M_YARI_KOYU = vec3(0.439, 0.402, 0.198);    // TABAN ile KOYU ORTA arası
const vec3 M_YARI_ACIK = vec3(0.5155, 0.50, 0.2255);   // TABAN ile AÇIK arası

vec3 cimen(vec3 tex, vec2 px) {
	float z = pz_leke(px, 0.005, 40.0);
	vec3 c = pz_ton_c(tex, z > 0.6 ? mix(G_TABAN, G_YARI_KOYU, 0.5) : G_TABAN);
	// seyrek tam ton tutam (17 px hücre %18, 3x3)
	ivec2 t = pz_hucre_yerel(px, 17.0, vec2(4.1, 2.6), 3, 3);
	if (t.x >= 0 && pz_hash(floor(px / 17.0) + vec2(0.9, 7.7)) < 0.18) {
		int r[3] = int[3](0x030, 0x323, 0x121);
		int v = pz_satir(r[t.y], t.x, 3);
		if (v == 3) { return pz_ton_c(tex, G_ACIK); }
		if (v == 2) { return pz_ton_c(tex, G_ORTA); }
		if (v == 1) { return pz_ton_c(tex, G_KOYU_ORTA); }
	}
	// yaprak izi: 4 px hücrede %50 "/" (üst sağ + alt sol), %22'sinde üstte açık uç
	vec2 ci = floor(px / 4.0);
	if (pz_hash(ci + vec2(3.7, 1.9)) < 0.5) {
		vec2 o = ci * 4.0 + floor(vec2(pz_hash(ci + vec2(1.2, 8.5)), pz_hash(ci + vec2(6.4, 2.3))) * vec2(3.0, 2.0));
		vec2 l = px - o;
		bool ac = pz_hash(ci + vec2(9.5, 5.5)) < 0.22;
		if (l == vec2(1.0, 0.0)) { c = pz_ton_c(tex, ac ? G_YARI_ACIK : G_YARI_KOYU); }
		else if (l == vec2(0.0, 1.0)) { c = pz_ton_c(tex, G_YARI_KOYU); }
	}
	return c;
}

vec3 yol(vec3 tex, vec2 px) {
	float z = pz_leke(px, 0.006, 36.0);
	vec3 c = pz_ton_m(tex, z > 0.6 ? M_YARI_KOYU : M_TABAN);
	// çakıl (11 px hücre %13): 2x1 taş + altında gölge
	ivec2 g = pz_hucre_yerel(px, 11.0, vec2(5.9, 3.4), 2, 2);
	if (g.x >= 0 && pz_hash(floor(px / 11.0) + vec2(8.1, 0.6)) < 0.13) {
		if (g.y == 0) { return g.x == 0 ? pz_ton_m(tex, M_PARLAK) : pz_ton_m(tex, M_ACIK); }
		return pz_ton_m(tex, M_KOYU_ORTA);
	}
	// benek: 3 px hücrede %30 koyu, %12 açık tek piksel
	vec2 ci = floor(px / 3.0);
	vec2 o = ci * 3.0 + floor(vec2(pz_hash(ci + vec2(2.0, 0.5)), pz_hash(ci + vec2(7.0, 3.5))) * 3.0);
	if (px == o) {
		float r = pz_hash(ci + vec2(4.4, 9.1));
		if (r < 0.30) { c = pz_ton_m(tex, M_YARI_KOYU); }
		else if (r < 0.42) { c = pz_ton_m(tex, M_YARI_ACIK); }
	}
	return c;
}

#include "res://tools/proto_20261111/bataklik_zemin/son.gdshaderinc"
