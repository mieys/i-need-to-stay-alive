shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261112/kar_zemin/ortak.gdshaderinc"

// B - RÜZGÂR SIRTLARI: rüzgârın oyduğu kar dalgaları (Altın Kumlar'ın kum kıvrımlarının kış karşılığı). Taban orta değerde (~0,74), beyazı
// asıl kıran şey düzenli ama kesik MERCEK biçimli sırtlar: üstte 1 px açık sırt, altında rüzgâr altı gölgesi (ortası 3 px, uçlara incelir).
// Sırt sıklığı geniş bölgelerde değişir (sakin cepler + sık tarlalar). Parıltı yok.

const vec3 R1 = vec3(0.420, 0.478, 0.529);  // #6b7a87
const vec3 R2 = vec3(0.486, 0.549, 0.600);  // #7c8c99
const vec3 R3 = vec3(0.576, 0.643, 0.686);  // #93a4af
const vec3 R4 = vec3(0.667, 0.733, 0.769);  // #aabbc4 TABAN
const vec3 R5 = vec3(0.737, 0.796, 0.824);  // #bccbd2
const vec3 R6 = vec3(0.816, 0.863, 0.882);  // #d0dce1
const vec3 B_SIRT = vec3(0.769, 0.824, 0.847);  // #c4d2d8
const vec3 B_GOLGE = vec3(0.576, 0.651, 0.698); // #93a6b2
const vec3 B_DERIN = vec3(0.522, 0.592, 0.647); // #8597a5

const float P = 13.0; // sırt bantları arası (dünya px)

vec3 rampa(vec3 tex) {
	return kz_rampa(tex, R1, R2, R3, R4, R5, R6);
}

vec3 kar_desen(vec3 taban, vec2 px, float t) {
	float u = px.y + px.x * 0.12 + 3.0 * sin(px.x * 0.045 + kz_fbm(px * 0.01) * 4.0);
	float k = floor(u / P);
	float f = floor(u - k * P);
	float seg_l = 16.0 + floor(kz_hash(vec2(k, 2.9)) * 22.0);
	float sx = px.x + kz_hash(vec2(k, 6.1)) * 60.0;
	float seg = floor(sx / seg_l);
	float s = (sx - seg * seg_l) / seg_l;
	float bolge = kz_leke(px + vec2(311.0, 97.0), 0.006, 30.0);
	if (kz_hash(vec2(k, seg)) < mix(0.18, 0.88, bolge)) { return taban; }
	float w = floor(3.4 * (1.0 - (2.0 * s - 1.0) * (2.0 * s - 1.0)));
	if (w < 1.0) { return taban; }
	float off = floor(kz_hash(vec2(k, seg) + 4.4) * 5.0);
	if (f == off) { return B_SIRT; }
	if (f == off + 1.0) { return B_DERIN; }
	if (f > off + 1.0 && f <= off + w) { return B_GOLGE; }
	return taban;
}

vec3 toprak(vec3 tex, vec2 px) {
	return kz_toprak(tex, px, vec3(0.82, 0.81, 0.82), R5);
}

#include "res://tools/proto_20261112/kar_zemin/son.gdshaderinc"
