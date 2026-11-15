shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261112/kar_zemin/ortak.gdshaderinc"

// D - KAR YASTIKLARI (sıcak / lavanta): göz yoran şey hem değer hem soğuk camgöbeği-beyaz -> kar akşamüstü ışığındaki gibi LAVANTA gölgeli,
// ışık alan yerleri KREM. Taban ~0,66. Desen: seyrek yumuşak kar tümsekleri (yastık): sol üstte krem ışık hilali, altına düşen 1-2 px lavanta
// zemin gölgesi (dış hat yok) + iki tonlu çok büyük gölge / ışık bölgeleri + seyrek sıcak parıltı.

const vec3 R1 = vec3(0.408, 0.400, 0.506);  // #686681
const vec3 R2 = vec3(0.478, 0.471, 0.580);  // #7a7894
const vec3 R3 = vec3(0.561, 0.549, 0.651);  // #8f8ca6
const vec3 R4 = vec3(0.663, 0.651, 0.729);  // #a9a6ba TABAN
const vec3 R5 = vec3(0.741, 0.710, 0.749);  // #bdb5bf
const vec3 R6 = vec3(0.831, 0.792, 0.776);  // #d4cac6
const vec3 D_GOLGE = vec3(0.616, 0.604, 0.698); // #9d9ab2 büyük gölge bölgesi
const vec3 D_ACIK = vec3(0.698, 0.678, 0.741);  // #b2adbd büyük ışık bölgesi
const vec3 D_YAST = vec3(0.725, 0.702, 0.749);  // #b9b3bf yastık gövdesi
const vec3 D_ISIK = vec3(0.808, 0.765, 0.749);  // #cec3bf krem ışık kenarı
const vec3 D_DUSEN = vec3(0.612, 0.596, 0.698); // #9c98b2 zemine düşen gölge
const vec3 D_PARILTI = vec3(0.953, 0.902, 0.812);

const float HC = 30.0;

vec3 rampa(vec3 tex) {
	return kz_rampa(tex, R1, R2, R3, R4, R5, R6);
}

float elips(vec2 p, vec2 c, vec2 r) {
	vec2 d = (p - c) / r;
	return dot(d, d);
}

vec3 kar_desen(vec3 taban, vec2 px, float t) {
	float z = kz_leke(px, 0.004, 44.0);
	vec3 c = taban;
	if (z > 0.63) { c = D_GOLGE; }
	else if (z < 0.37) { c = D_ACIK; }
	vec2 h = floor(px / HC);
	// yastık sıklığı büyük bölgelerde değişir (hücre merkezinden okunur: yastık yarım kesilmez); merkez hücrede geniş oynar (ızgara okunmasın)
	float sik = kz_leke(h * HC + HC * 0.5 + vec2(211.0, 37.0), 0.006, 30.0);
	if (kz_hash(h + vec2(6.3, 2.1)) < mix(0.12, 0.62, sik)) {
		vec2 r = vec2(6.0 + floor(kz_hash(h + vec2(1.7, 8.8)) * 6.0), 3.0 + floor(kz_hash(h + vec2(9.4, 3.6)) * 4.0));
		vec2 bos = vec2(HC) - 2.0 * r - 5.0;
		vec2 m = h * HC + r + 1.0 + floor(vec2(kz_hash(h + vec2(2.2, 5.5)), kz_hash(h + vec2(7.1, 0.9))) * bos);
		vec2 p = px + 0.5;
		if (elips(p, m, r) < 1.0) {
			// gövde + sol üstte krem ışık hilali (dış hat yok: kontur taş/kaldırım gibi okunuyordu)
			if (elips(p, m + vec2(2.0, 2.0), r) >= 1.0) { return D_ISIK; }
			return D_YAST;
		}
		if (elips(p, m + vec2(0.5, 2.0), r) < 1.0) { return D_DUSEN; }
	}
	float sp = kz_parilti(px, t, 0.04, 0.2, 8.0);
	if (sp > 0.0) { c = mix(c, D_PARILTI, sp); }
	return c;
}

vec3 toprak(vec3 tex, vec2 px) {
	return kz_toprak(tex, px, vec3(0.82, 0.78, 0.78), R5);
}

#include "res://tools/proto_20261112/kar_zemin/son.gdshaderinc"
