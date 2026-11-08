shader_type canvas_item;
// C "AKINTI ÇİZGİLERİ" (sade su prototipi, 2026-11-06, oyuna bağlı DEĞİL): suyun kendi rengi + 1 px kıyı çizgisi + seyrek, 1 px
// kalınlığında DÜZ kısa yatay çizgiler (5-9 px): ortadan uzar, kısalıp söner, ömrü boyunca doğduğu yerin akıntısıyla sürüklenir.
// Kıvrım / gölge / tepe yok - en düz "su parıltısı" çizgisi.
#include "res://tools/proto_20261106/su_sade/su_sade_ortak.gdshaderinc"

uniform vec2 hucre = vec2(30.0, 12.0);
uniform float yogunluk = 0.3;
uniform float omur_hiz = 0.18; // döngü/sn; döngünün %50'si görünür (~2,8 sn)
uniform float akis_hiz = 5.0;
uniform float cizgi_guc = 0.62;

bool cizgi(vec2 px, float t) {
	vec2 base = floor(px / hucre);
	for (int j = -2; j <= 2; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			float r = hash21(cell);
			if (r >= yogunluk) {
				continue;
			}
			float dongu = t * omur_hiz + r / yogunluk * 3.7;
			float phase = fract(dongu);
			if (phase >= 0.5) {
				continue;
			}
			float k = floor(dongu);
			vec2 h = hash22(cell + vec2(k * 2.71, k * 1.37));
			float w = 2.0 + floor(hash21(cell + vec2(4.3 + k * 0.613, 9.7)) * 3.0); // yarı uzunluk 2-4
			vec2 dogum = cell * hucre + floor(h * hucre);
			vec3 ak = texture(su_akis, doku_uv(dogum)).rgb;
			if (ak.b < 0.5) {
				continue;
			}
			vec2 f = ak.rg * 2.0 - 1.0;
			vec2 c = floor(dogum + f * akis_hiz * (phase / omur_hiz) + 0.5);
			float hw = floor(w * sin(phase / 0.5 * 3.14159) + 0.5);
			if (hw < 1.0) {
				continue;
			}
			vec2 dp = px - c;
			if (dp.y == 0.0 && abs(dp.x) <= hw) {
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
		if (d > 3.5 && cizgi(px, TIME)) {
			col = mix(col, sirt_renk.rgb, cizgi_guc);
			a = max(a, 0.86);
		}
		kiyi_cizgisi(d, col, a);
		COLOR = bitir(tex, col, a);
	}
}
