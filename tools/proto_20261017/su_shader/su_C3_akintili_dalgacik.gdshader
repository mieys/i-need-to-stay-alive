shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261017/su_shader/su_ortak.gdshaderinc"

// PROTOTİP C3 - AKINTILI DALGACIK (2026-10-17, oyuna bağlı DEĞİL).
// Kullanıcı: "ilk halinin C'sini istiyorum (dalgacık) FAKAT nehir akıntılı olmalı, dalgacıklar akıntının yönüne doğru olmalı".
// C v1'in görünüşü AYNEN (7-11 px "︵" sırt, 2 px yüksek yuvarlak tepe, uçlar kıvrık, altında 1 px gölge; belirip uzar, kısalıp
// söner; geniş kabarmalar; kıyı yalama çizgisi). Fark: her dalgacık DOĞDUĞU noktadaki akış vektörüyle (su_akis.png, F ile aynı:
// kıyıya paralel, batı -> kuzeydoğu, kanal ortasında hızlı / kıyıda durgun) ömrü boyunca sürüklenir.
// - Merkez ileri hesaplanır (doğum + akış x yaş), piksel geriye kaydırılmaz: kıvrımlarda yer yer farklı kayma şekli yırtardı.
//   Bu yüzden bir piksel çevresindeki 3x5 hücrenin dalgacığını dener (yol <= akis_hiz x ömür ~15 px).
// - Her döngüde doğum yeri yeniden rastgele (aynı yerde tekrar doğmaz); doğum yeri kıyıya 5 px'ten yakınsa dalgacık yok.
// - `yonlu` (C4): sırtın tepe tarafı akıntıya döner (baskın eksene göre 4 yön: akıntı sağa -> ")", aşağı -> "︶"); kapalıyken
//   (C3) şekil hep v1 gibi "︵".

uniform sampler2D su_akis : filter_linear, repeat_disable;
uniform vec4 su_renk : source_color = vec4(0.235, 0.43, 0.6, 1.0);
uniform vec4 derin_renk : source_color = vec4(0.19, 0.35, 0.53, 1.0);
uniform float su_alfa = 0.76;
uniform float derin_alfa = 0.84;
uniform vec4 sirt_renk : source_color = vec4(0.6, 0.79, 0.9, 1.0);
uniform vec2 hucre = vec2(26.0, 14.0);
uniform float yogunluk = 0.55;
uniform float omur_hiz = 0.2; // döngü/sn; döngünün %55'i görünür (~2,75 sn)
uniform float akis_hiz = 6.0; // kanal ortasında px/sn
uniform bool yonlu = false;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec2 akis_at(vec2 p) {
	return texture(su_akis, (p + 0.5 - mesafe_origin) / mesafe_size).rg * 2.0 - 1.0;
}

// v1 şekli: dx = sırt boyunca uzaklık (mutlak), dy = -1 tepe tarafı, +1 arka (gölge) tarafı. 1 = sırt, -1 = gölge, 0 = yok
float sekil(float dx, float dy, float hw) {
	if (dy == -1.0 && dx <= hw - 3.0) {
		return 1.0; // yuvarlak tepe
	}
	if (dy == 0.0 && dx <= hw - 1.0) {
		return 1.0;
	}
	if (dy == 1.0 && dx == hw) {
		return 1.0; // uçlar bir piksel geri kıvrılır
	}
	if (dy == 1.0 && dx <= hw - 2.0) {
		return -1.0;
	}
	return 0.0;
}

float dalgacik(vec2 px, float t) {
	vec2 base = floor(px / hucre);
	float sonuc = 0.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			float r = su_hash(cell);
			if (r >= yogunluk) {
				continue;
			}
			float dongu = t * omur_hiz + r * 7.0;
			float phase = fract(dongu);
			if (phase >= 0.55) {
				continue;
			}
			float k = floor(dongu);
			vec2 h = su_hash2(cell + vec2(k * 3.17, k * 1.93));
			float r2 = su_hash(cell + vec2(5.7 + k * 0.731, 13.1));
			float w = 3.0 + floor(r2 * 3.0); // yarı genişlik 3-5 (7-11 px)
			vec2 dogum = cell * hucre + floor(h * hucre);
			if (su_kiyi(dogum) < 5.0) {
				continue;
			}
			vec2 f = akis_at(dogum);
			float yas = phase / omur_hiz;
			vec2 c = floor(dogum + f * akis_hiz * yas + 0.5);
			float hw = floor(w * sin(phase / 0.55 * 3.14159) + 0.5);
			if (hw < 1.0) {
				continue;
			}
			vec2 dp = px - c;
			float dx = abs(dp.x);
			float dy = dp.y;
			if (yonlu && dot(f, f) > 0.01) {
				vec2 ax = abs(f.x) >= abs(f.y) ? vec2(sign(f.x), 0.0) : vec2(0.0, sign(f.y));
				dy = -dot(dp, ax);
				dx = abs(dot(dp, vec2(-ax.y, ax.x)));
			}
			float s = sekil(dx, dy, hw);
			if (s > 0.5) {
				return 1.0;
			}
			if (s < -0.5) {
				sonuc = -1.0;
			}
		}
	}
	return sonuc;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (!su_mavi_mi(tex.rgb)) {
		COLOR = su_disi(tex);
		COLOR.rgb = harita_renk(COLOR.rgb);
	} else {
		vec2 px = floor(world_pos);
		float t = TIME;
		float d = su_kiyi(px);
		float th = su_bayer(px);

		float lv = su_kademe(clamp(d / 30.0, 0.0, 1.0), 1.0, th, 0.35);
		vec3 col = mix(su_renk.rgb, derin_renk.rgb, lv);
		float a = mix(su_alfa, derin_alfa, lv);

		// geniş kabarmalar (v1 ile aynı)
		vec2 wp = px * vec2(0.022, 0.045) + vec2(t * 0.07, t * 0.03);
		float sw = su_fbm(wp);
		col *= 1.0 + (su_kademe(sw, 2.0, th, 0.5) - 0.5) * 0.14;

		if (d > 3.5) {
			float dg = dalgacik(px, t);
			if (dg > 0.5) {
				col = mix(col, sirt_renk.rgb, 0.85);
				a = max(a, 0.92);
			} else if (dg < -0.5) {
				col *= 0.84;
			}
		}

		// kıyı: yalama çizgisi kıyıya 1,5..4,5 px arasında gelip gider (v1 ile aynı)
		float lap = 2.0 + 1.6 * sin(t * 1.5 + su_noise(px * 0.04) * 9.0);
		if (d < 1.2) {
			col = mix(col, sirt_renk.rgb, 0.55);
			a = 0.82;
		} else if (d < lap) {
			col *= 0.86;
			a = max(a, 0.8);
		} else if (d < lap + 1.0) {
			col = mix(col, sirt_renk.rgb, 0.6);
			a = max(a, 0.88);
		}
		COLOR = vec4(harita_renk(col), tex.a * a);
	}
}
