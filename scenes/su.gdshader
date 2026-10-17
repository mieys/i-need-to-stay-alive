shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"

// "Su" katmanının suyu (harita_baked.tscn -> Su/Su, ayrıca Su/Su collisionsuz aynı materyali paylaşır; dokular + ayar scripts/water_fx.gd).
//
// 2026-10-17 (madde 214): prototip C3 "AKINTILI DALGACIK" (madde 209, tools/proto_20261017/su_shader/su_C3_akintili_dalgacik.gdshader)
// oyunda. Kullanıcı: "suların shader'ı neredeyse yok gibi" (eski sürüm: +/-%4,5 ışık bandı + seyrek 2-4 px pırıltı, karede piksellerin
// ~%0,7'si değişiyordu) -> 4+4 prototip; seçilen: ilk C ("dalgacık") + "nehir akıntılı olmalı, dalgacıklar akıntının yönüne doğru".
//   - Derinlik: kıyıya uzaklık dokusu (su_mesafe, haritadan pişirilir: görünen su = Su karosunun mavi pikselleri - kıyı ayrıntı
//     katmanlarının mavi olmayan opak pikselleri; köprü altı su sayılır) ile 2 ton, sınırı noktalı.
//   - Geniş ışık kabarmaları (yavaş kayan gradyan gürültü, 3 kademe, +/-%7).
//   - Dalgacıklar: 7-11 px "︵" sırt (2 px yüksek yuvarlak tepe, uçlar kıvrık, altında 1 px gölge), belirip uzar, kısalıp söner;
//     her biri DOĞDUĞU noktadaki akış vektörüyle (su_akis: kıyıya paralel, batı -> kuzeydoğu, kanal ortasında hızlı / kıyıda
//     durgun) ömrü boyunca sürüklenir. Merkez ileri hesaplanır (piksel geri kaydırılsa kıvrımlarda akış farkı şekli yırtardı), bu
//     yüzden piksel çevresindeki 3x5 hücre denenir. Her döngüde doğum yeri yeniden rastgele; kıyıya < 5 px'te doğmaz.
//     `dalgacik_acik` = "Zemin ayrıntısı" grafik ayarı (telefonda pahalı döngü).
//   - Kıyı: 1 px açık çizgi + ıslak koyu bant + kıyıya 1,5..4,5 px arasında gelip giden 1 px "yalama" çizgisi.
// Dünya koordinatında, harita karolarının piksel ızgarasında (1 dünya birimi = 1 karo pikseli) çalışır; harita renk ayarı en sonda.

uniform sampler2D su_mesafe : hint_default_white, filter_linear, repeat_disable; // R = kıyıya uzaklık / 64 dünya px (2 px/teksel)
uniform sampler2D su_akis : hint_default_black, filter_linear, repeat_disable; // RG = 0,5 + 0,5 akış, B = dalgacık doğabilir (4 px/teksel)
uniform vec2 doku_origin = vec2(-576.0, -384.0);
uniform vec2 doku_size = vec2(5248.0, 4864.0);
uniform bool dalgacik_acik = true;

uniform vec4 su_renk : source_color = vec4(0.235, 0.43, 0.6, 1.0);
uniform vec4 derin_renk : source_color = vec4(0.19, 0.35, 0.53, 1.0);
uniform float su_alfa = 0.76;
uniform float derin_alfa = 0.84;
uniform vec4 sirt_renk : source_color = vec4(0.6, 0.79, 0.9, 1.0);
uniform vec2 hucre = vec2(26.0, 14.0);
uniform float yogunluk = 0.55;
uniform float omur_hiz = 0.2; // döngü/sn; döngünün %55'i görünür (~2,75 sn)
uniform float akis_hiz = 6.0; // kanal ortasında px/sn (piksel arama alanı 3x5 hücre: akis_hiz x ömür <= ~16 px)

varying vec2 world_pos;

void vertex() {
	// TileMapLayer karolarını yerel koordinatta çizer; MODEL_MATRIX dünyaya çevirir - desen haritaya yapışık.
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec2 doku_uv(vec2 px) {
	return (px + 0.5 - doku_origin) / doku_size;
}

// Dünya pikselinin kıyıya uzaklığı (dünya px); kıyı çizgisi ~0, kıyı sanatının altı < 0.
float kiyi(vec2 px) {
	return texture(su_mesafe, doku_uv(px)).r * 64.0 - 1.0;
}

// Su karosunun pikseli mi (terrain_collision.gd _class_mask ile aynı kural)? Su katmanına boyanmış çimen karoları değil.
bool mavi_mi(vec3 c) {
	return c.b > c.g + 0.03 && c.b > c.r + 0.1;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + vec2(19.19, 7.73)));
}

// Gradyan gürültü 0..1 (değer gürültüsü sert kademeyle ızgaraya hizalı dikdörtgen lekeler veriyordu).
vec2 grad2(vec2 p) {
	float a = hash21(p) * 6.2831853;
	return vec2(cos(a), sin(a));
}

float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(grad2(i), f);
	float b = dot(grad2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(grad2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(grad2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return clamp(0.5 + mix(mix(a, b, u.x), mix(c, d, u.x), u.y), 0.0, 1.0);
}

float fbm2(vec2 p) {
	vec2 q = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.1 + vec2(3.1, 1.7);
	return gnoise(p) * 0.62 + gnoise(q) * 0.38;
}

// 4x4 Bayer eşiği (0..1)
float bayer4(vec2 px) {
	vec2 p = mod(px, 4.0);
	vec2 a = mod(p, 2.0);
	vec2 b = floor(p / 2.0);
	float v = 4.0 * mod(2.0 * a.x + 3.0 * a.y, 4.0) + mod(2.0 * b.x + 3.0 * b.y, 4.0);
	return (v + 0.5) / 16.0;
}

// 0..1 -> n kademe; kademe sınırında `genislik` kadar noktalı geçiş.
float kademe(float v, float n, float esik, float genislik) {
	return clamp(floor(v * n + 0.5 + (esik - 0.5) * genislik), 0.0, n) / n;
}

// dx = sırt boyunca uzaklık (mutlak), dy = -1 tepe, +1 arka (gölge). 1 = sırt, -1 = gölge, 0 = yok
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
			float r = hash21(cell);
			if (r >= yogunluk) {
				continue;
			}
			float dongu = t * omur_hiz + r * 7.0;
			float phase = fract(dongu);
			if (phase >= 0.55) {
				continue;
			}
			float k = floor(dongu);
			vec2 h = hash22(cell + vec2(k * 3.17, k * 1.93));
			float r2 = hash21(cell + vec2(5.7 + k * 0.731, 13.1));
			float w = 3.0 + floor(r2 * 3.0); // yarı genişlik 3-5 (7-11 px)
			vec2 dogum = cell * hucre + floor(h * hucre);
			vec3 ak = texture(su_akis, doku_uv(dogum)).rgb;
			if (ak.b < 0.5) {
				continue; // kıyıya çok yakın / su dışı
			}
			vec2 f = ak.rg * 2.0 - 1.0;
			vec2 c = floor(dogum + f * akis_hiz * (phase / omur_hiz) + 0.5);
			float hw = floor(w * sin(phase / 0.55 * 3.14159) + 0.5);
			if (hw < 1.0) {
				continue;
			}
			vec2 dp = px - c;
			float s = sekil(abs(dp.x), dp.y, hw);
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
	if (!mavi_mi(tex.rgb)) {
		// Su katmanına boyanmış çimen karosu (madde 85): eski shader'daki gibi hafif renk + saydamlık.
		COLOR = vec4(mix(tex.rgb, vec3(0.18, 0.48, 0.68), 0.12), tex.a * 0.73);
		COLOR.rgb = harita_renk(COLOR.rgb);
	} else {
		vec2 px = floor(world_pos);
		float t = TIME;
		float d = kiyi(px);
		float th = bayer4(px);

		float lv = kademe(clamp(d / 30.0, 0.0, 1.0), 1.0, th, 0.35);
		vec3 col = mix(su_renk.rgb, derin_renk.rgb, lv);
		float a = mix(su_alfa, derin_alfa, lv);

		// geniş kabarmalar
		vec2 wp = px * vec2(0.022, 0.045) + vec2(t * 0.07, t * 0.03);
		col *= 1.0 + (kademe(fbm2(wp), 2.0, th, 0.5) - 0.5) * 0.14;

		if (dalgacik_acik && d > 3.5) {
			float dg = dalgacik(px, t);
			if (dg > 0.5) {
				col = mix(col, sirt_renk.rgb, 0.85);
				a = max(a, 0.92);
			} else if (dg < -0.5) {
				col *= 0.84;
			}
		}

		// kıyı: yalama çizgisi kıyıya 1,5..4,5 px arasında gelip gider (kıyı boyunca farklı fazda)
		float lap = 2.0 + 1.6 * sin(t * 1.5 + gnoise(px * 0.04) * 9.0);
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
		COLOR = vec4(col, tex.a * a);
		COLOR.rgb = harita_renk(COLOR.rgb); // harita renk ayarı (madde 181) - fragment()'in EN SONUNDA kalmalı
	}
}
