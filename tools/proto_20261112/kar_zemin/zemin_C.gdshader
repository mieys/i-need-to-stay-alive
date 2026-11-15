shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261112/kar_zemin/ortak.gdshaderinc"

// C - İNCE KAR: kar ince, yer yer altındaki DONMUŞ FUNDA görünür (gri-zeytin, kuru ot sapı + kırağı). Beyazı renkle kırar: kar alanın
// ~%92'i. Açıklıklar orta boy ve seyrek (ilk hâli büyük ve sık = kamuflaj), kar kalınlığı okunur: açıklığın üst kenarında karın yüzü (1 px mavi) + açıklığa
// düşen gölge, alt kenarında ışık yakalayan kar dudağı. Kar tonu ~0,73. Funda, patikanın tenine (kahve) karışmasın diye zeytin.

const vec3 R1 = vec3(0.435, 0.490, 0.537);  // #6f7d89
const vec3 R2 = vec3(0.506, 0.576, 0.627);  // #8193a0
const vec3 R3 = vec3(0.584, 0.651, 0.690);  // #95a6b0
const vec3 R4 = vec3(0.678, 0.745, 0.776);  // #adbec6 TABAN
const vec3 R5 = vec3(0.737, 0.796, 0.820);  // #bccbd1
const vec3 R6 = vec3(0.808, 0.851, 0.867);  // #ced9dd
const vec3 C_YUZ = vec3(0.596, 0.663, 0.702);    // #98a9b3 kar yüzü (açıklığın üst kenarı)
const vec3 C_DUDAK = vec3(0.761, 0.812, 0.831);  // #c2cfd4 kar dudağı (açıklığın alt kenarı)
const vec3 C_Z = vec3(0.478, 0.490, 0.400);      // #7a7d66 funda
const vec3 C_ZK = vec3(0.420, 0.431, 0.349);     // #6b6e59 koyu funda
const vec3 C_ZA = vec3(0.529, 0.541, 0.443);     // #878a71 açık funda
const vec3 C_ZG = vec3(0.365, 0.376, 0.306);     // #5d604e karın düşürdüğü gölge
const vec3 C_SAP = vec3(0.612, 0.588, 0.451);    // #9c9673 kuru ot sapı
const vec3 C_KIRAGI = vec3(0.667, 0.714, 0.722); // #aab6b8
const vec3 C_PARILTI = vec3(0.92, 0.95, 0.96);

const float ESIK = 0.665;

vec3 rampa(vec3 tex) {
	return kz_rampa(tex, R1, R2, R3, R4, R5, R6);
}

float acik(vec2 px) {
	return kz_leke(px + vec2(57.0, 203.0), 0.015, 34.0);
}

vec3 kar_desen(vec3 taban, vec2 px, float t) {
	bool burada = acik(px) > ESIK;
	bool ust = acik(px + vec2(0.0, -1.0)) > ESIK;
	if (!burada) {
		if (ust) { return C_DUDAK; }
		if (acik(px + vec2(0.0, 1.0)) > ESIK) { return C_YUZ; }
		float p = kz_parilti(px, t, 0.035, 0.22, 8.0);
		return p > 0.0 ? mix(taban, C_PARILTI, p) : taban;
	}
	if (!ust) { return C_ZG; }
	float z = kz_leke(px + vec2(19.0, 71.0), 0.022, 12.0);
	vec3 c = z > 0.6 ? C_ZK : (z < 0.4 ? C_ZA : C_Z);
	vec2 h5 = floor(px / 5.0);
	if (kz_hash(h5 + vec2(3.7, 1.3)) < 0.24) {
		vec2 o = h5 * 5.0 + vec2(floor(kz_hash(h5 + vec2(8.1, 2.6)) * 4.0), 1.0 + floor(kz_hash(h5 + vec2(0.4, 6.6)) * 3.0));
		if (px == o || px == o + vec2(0.0, -1.0)) { c = C_SAP; }
	}
	vec2 h7 = floor(px / 7.0);
	if (kz_hash(h7 + vec2(5.5, 9.2)) < 0.14) {
		vec2 o = h7 * 7.0 + floor(vec2(kz_hash(h7 + vec2(1.9, 4.4)), kz_hash(h7 + vec2(7.3, 0.8))) * 6.0);
		if (px == o) { c = C_KIRAGI; }
	}
	return c;
}

vec3 toprak(vec3 tex, vec2 px) {
	return kz_toprak(tex, px, vec3(0.86, 0.85, 0.86), R5);
}

#include "res://tools/proto_20261112/kar_zemin/son.gdshaderinc"
