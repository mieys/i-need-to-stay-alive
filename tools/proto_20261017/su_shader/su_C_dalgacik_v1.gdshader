shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261017/su_shader/su_ortak.gdshaderinc"

// PROTOTİP C v1 - DALGACIK (2026-10-17, oyuna bağlı DEĞİL). SADECE karşılaştırma için saklandı: kullanıcı "baloncuk çıkıyormuş
// gibi duruyor" dedi -> güncel sürüm su_C_dalgacik.gdshader (v2).
// El çizimi piksel su dili: suyun üstünde açık renk küçük dalga sırtları ("︵", 7-11 px, 2 px yüksek, altında 1 px koyu gölge) belirip uzar,
// kısalıp kaybolur, akıntıyla sürüklenir (tuğla dizilimli hücreler, her biri kendi fazında). Geniş ışık kabarmaları (3 kademe,
// mevcuttan güçlü). Kıyı: ıslak koyu bant + kıyıya gelip giden 1 px açık "yalama" çizgisi.

uniform vec4 su_renk : source_color = vec4(0.235, 0.43, 0.6, 1.0);
uniform vec4 derin_renk : source_color = vec4(0.19, 0.35, 0.53, 1.0);
uniform float su_alfa = 0.76;
uniform float derin_alfa = 0.84;
uniform vec4 sirt_renk : source_color = vec4(0.6, 0.79, 0.9, 1.0);
uniform vec2 hucre = vec2(26.0, 14.0);
uniform float yogunluk = 0.55;
uniform float omur_hiz = 0.2;
uniform vec2 akinti = vec2(1.6, 0.35);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// 1 = sırt, -1 = sırtın gölgesi, 0 = yok
float dalgacik(vec2 px, float t) {
	vec2 q = px - floor(akinti * t);
	float row = floor(q.y / hucre.y);
	q.x += mod(row, 2.0) * hucre.x * 0.5;
	vec2 cell = vec2(floor(q.x / hucre.x), row);
	vec2 ic = q - cell * hucre;
	float r = su_hash(cell);
	if (r >= yogunluk) {
		return 0.0;
	}
	float r2 = su_hash(cell + vec2(5.7, 13.1));
	float r3 = su_hash(cell + vec2(21.3, 2.9));
	float w = 3.0 + floor(r2 * 3.0); // yarı genişlik 3-5 (7-11 px)
	vec2 c = vec2(w + 1.0 + floor(r3 * (hucre.x - 2.0 * w - 2.0)), 2.0 + floor(r2 * (hucre.y - 4.0)));
	float phase = fract(t * omur_hiz + r * 7.0);
	if (phase >= 0.55) {
		return 0.0;
	}
	float s = sin(phase / 0.55 * 3.14159);
	float hw = floor(w * s + 0.5);
	if (hw < 1.0) {
		return 0.0;
	}
	float dx = abs(ic.x - c.x);
	float dy = ic.y - c.y;
	if (dy == -1.0 && dx <= hw - 3.0) {
		return 1.0; // yuvarlak tepe
	}
	if (dy == 0.0 && dx <= hw - 1.0) {
		return 1.0;
	}
	if (dy == 1.0 && dx == hw) {
		return 1.0; // uçlar bir piksel aşağı kıvrılır
	}
	if (dy == 1.0 && dx <= hw - 2.0) {
		return -1.0;
	}
	return 0.0;
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

		// geniş kabarmalar
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

		// kıyı: yalama çizgisi kıyıya 1,5..4,5 px arasında gelip gider (kıyı boyunca farklı fazda)
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
