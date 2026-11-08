shader_type canvas_item;
// B "SEYREK DALGACIK" (sade su prototipi, 2026-11-06, oyuna bağlı DEĞİL): oyundaki C3'ün "︵" dalgacık ŞEKLİ ve akıntıyla
// sürüklenmesi AYNI; sadeleşen: yarısından az dalgacık (0,55 -> 0,22), altındaki koyu gölge yok, sırt daha sönük, kabarma yok,
// kıyıda yalama/ıslak bant yok (sadece 1 px çizgi).
#include "res://tools/proto_20261106/su_sade/su_sade_ortak.gdshaderinc"

uniform vec2 hucre = vec2(26.0, 14.0);
uniform float yogunluk = 0.22;
uniform float omur_hiz = 0.2; // döngü/sn; döngünün %55'i görünür
uniform float akis_hiz = 6.0;
uniform float sirt_guc = 0.6;

// dx = sırt boyunca uzaklık, dy = -1 tepe, 0 gövde; gölge satırı yok.
bool sekil(float dx, float dy, float hw) {
	return (dy == -1.0 && dx <= hw - 3.0) || (dy == 0.0 && dx <= hw - 1.0) || (dy == 1.0 && dx == hw);
}

bool dalgacik(vec2 px, float t) {
	vec2 base = floor(px / hucre);
	for (int j = -2; j <= 2; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			float r = hash21(cell);
			if (r >= yogunluk) {
				continue;
			}
			float dongu = t * omur_hiz + r / yogunluk * 7.0;
			float phase = fract(dongu);
			if (phase >= 0.55) {
				continue;
			}
			float k = floor(dongu);
			vec2 h = hash22(cell + vec2(k * 3.17, k * 1.93));
			float r2 = hash21(cell + vec2(5.7 + k * 0.731, 13.1));
			float w = 3.0 + floor(r2 * 3.0);
			vec2 dogum = cell * hucre + floor(h * hucre);
			vec3 ak = texture(su_akis, doku_uv(dogum)).rgb;
			if (ak.b < 0.5) {
				continue;
			}
			vec2 f = ak.rg * 2.0 - 1.0;
			vec2 c = floor(dogum + f * akis_hiz * (phase / omur_hiz) + 0.5);
			float hw = floor(w * sin(phase / 0.55 * 3.14159) + 0.5);
			if (hw < 1.0) {
				continue;
			}
			vec2 dp = px - c;
			if (sekil(abs(dp.x), dp.y, hw)) {
				return true;
			}
		}
	}
	return false;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (!mavi_mi(tex.rgb)) {
		COLOR = cimen_karosu(tex);
	} else {
		vec2 px = floor(world_pos);
		float d = kiyi(px);
		vec3 col;
		float a;
		taban(tex, col, a);
		if (d > 3.5 && dalgacik(px, TIME)) {
			col = mix(col, sirt_renk.rgb, sirt_guc);
			a = max(a, 0.88);
		}
		kiyi_cizgisi(d, col, a);
		COLOR = bitir(tex, col, a);
	}
}
