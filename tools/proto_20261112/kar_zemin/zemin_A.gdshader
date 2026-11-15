shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261112/kar_zemin/ortak.gdshaderinc"

// A - BULUTLU GÜN (en sakin): kar kapalı havadaki gibi gri-mavi, değer belirgin düşük (taban ~0,83 -> ~0,66). Desen yalnız ÇOK BÜYÜK
// kar yığıntıları: üç düz ton (gölge / taban / açık) + yığıntının rüzgâra bakan sırtında 1 px açık çizgi. Rüzgâr izi yok, parıltı seyrek.

const vec3 R1 = vec3(0.400, 0.451, 0.498);  // #667380
const vec3 R2 = vec3(0.459, 0.514, 0.561);  // #75838f
const vec3 R3 = vec3(0.533, 0.592, 0.639);  // #8897a3
const vec3 R4 = vec3(0.624, 0.686, 0.729);  // #9fafba TABAN
const vec3 R5 = vec3(0.678, 0.737, 0.773);  // #adbcc5
const vec3 R6 = vec3(0.757, 0.808, 0.831);  // #c1ced4
const vec3 A_GOLGE = vec3(0.588, 0.647, 0.690); // #96a5b0 yığıntı gölgesi
const vec3 A_ACIK = vec3(0.655, 0.718, 0.757);  // #a7b7c1 yığıntı üstü
const vec3 A_SIRT = vec3(0.722, 0.776, 0.808);  // #b8c6ce sırt çizgisi
const vec3 A_PARILTI = vec3(0.86, 0.90, 0.92);

vec3 rampa(vec3 tex) {
	return kz_rampa(tex, R1, R2, R3, R4, R5, R6);
}

vec3 kar_desen(vec3 taban, vec2 px, float t) {
	float z = kz_leke(px, 0.0036, 52.0);
	vec3 c = taban;
	if (z > 0.62) { c = A_GOLGE; }
	else if (z < 0.38) {
		c = A_ACIK;
		// sırt: açık yığıntının KUZEY kenarı (bir üst piksel artık açık değil) - tepeden vuran ışığın yakaladığı kenar
		if (kz_leke(px + vec2(0.0, -1.0), 0.0036, 52.0) >= 0.38) { c = A_SIRT; }
	}
	float p = kz_parilti(px, t, 0.03, 0.2, 9.0);
	if (p > 0.0) { c = mix(c, A_PARILTI, p); }
	return c;
}

vec3 toprak(vec3 tex, vec2 px) {
	return kz_toprak(tex, px, vec3(0.80, 0.79, 0.80), R5);
}

#include "res://tools/proto_20261112/kar_zemin/son.gdshaderinc"
