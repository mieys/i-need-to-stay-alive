// AYAZ DAĞI KAR ZEMİNİ PROTOTİPLERİ - ORTAK (2026-11-12, oyuna bağlı DEĞİL). Kullanıcı: "harita çok beyaz göz yoruyor".
// Teşhis: oyundaki kar dolgusu #c5dadd (ışıkla ekranda ~#c1d2d9, parlaklık ~0,83) görüş alanının ~%70'ini tek düz renkle kaplıyor.
// Her prototip üç şey yapar:
//  1) KAR RAMPASI: setin kar tonlarının TAMAMI (dolgu + karoların kenar topakları + gölgeleri; mavimsi düşük doygun pikseller) parlaklık
//     sırasına göre prototipin kendi 6 tonuna eşlenir (palet değişimi - girdi tonları ayrık olduğu için çıktı da ayrık, dither yok).
//     0,38 altı (koyu kaya/uçurum) aynen kalır, 0,38-0,53 arası orana yumuşar -> karonun çizimi bozulmaz, yalnız değer düşer.
//  2) Düz taban pikselinde prototipin DESENİ (her biri ayrı şekil dili).
//  3) TOPRAK (patika / eriyen kar) kar koyulaştığı için de koyulaşır ("ıslak toprak") - yoksa yol kara karışır.
// Kurallar: dünya pikseli, dither yok, ton geçişi tek adım düz piksel (madde 529 dersi).

uniform vec4 kar_taban : source_color = vec4(0.773, 0.855, 0.867, 1.0);     // #c5dadd düz kar karosu
uniform vec4 toprak_taban : source_color = vec4(0.729, 0.620, 0.427, 1.0);  // #ba9e6d düz toprak karosu
uniform float taban_tolerans : hint_range(0.0, 0.2) = 0.03;

// Setin kar rampasının parlaklıkları (k_zemin.png'den ölçüldü): #7a8b97 0,53 / #8ba1ab 0,61 / #a7bdc4 0,72 / #c5dadd 0,832 (TABAN) /
// #d7ebed 0,90 / #edfefe 0,976.
const float KZ_S0 = 0.38;
const float KZ_S1 = 0.53;
const float KZ_S2 = 0.61;
const float KZ_S3 = 0.72;
const float KZ_S4 = 0.832;
const float KZ_S5 = 0.90;
const float KZ_S6 = 0.976;

float kz_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float kz_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(kz_hash(i), kz_hash(i + vec2(1.0, 0.0)), f.x), mix(kz_hash(i + vec2(0.0, 1.0)), kz_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float kz_fbm(vec2 p) {
	return kz_vnoise(p) * 0.55 + kz_vnoise(p * 2.03) * 0.30 + kz_vnoise(p * 4.01) * 0.15;
}

// Kıvrımlı büyük leke alanı (0..1).
float kz_leke(vec2 px, float olcek, float kivrim) {
	vec2 w = vec2(kz_fbm(px * 0.009), kz_fbm(px * 0.009 + vec2(31.7, 7.3))) - 0.5;
	return kz_fbm((px + w * kivrim) * olcek);
}

float kz_luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Kar ailesi: mavi >= kırmızı, düşük doygunluk. Buzun doygun camgöbeği ve toprak/kum girmez.
bool kz_kar_aile(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	return c.b >= c.r - 0.01 && (mx - mn) / max(mx, 0.001) < 0.26;
}

// Toprak ailesi: kırmızı baskın sıcak tonlar (patika, toprak adası, toprak lekesi).
bool kz_toprak_aile(vec3 c) {
	return c.r > c.b + 0.08 && c.r >= c.g - 0.02;
}

float kz_kar_maske(vec3 rgb) {
	return 1.0 - smoothstep(taban_tolerans * 0.55, taban_tolerans * 1.55, distance(rgb, kar_taban.rgb));
}

float kz_toprak_maske(vec3 rgb) {
	return 1.0 - smoothstep(taban_tolerans * 0.55, taban_tolerans * 1.55, distance(rgb, toprak_taban.rgb));
}

// Kar rampası: r1..r6 = KZ_S1..KZ_S6 parlaklıklarındaki girdinin yeni rengi (r4 = taban).
vec3 kz_rampa(vec3 tex, vec3 r1, vec3 r2, vec3 r3, vec3 r4, vec3 r5, vec3 r6) {
	float l = kz_luma(tex);
	if (l <= KZ_S0) { return tex; }
	if (l < KZ_S1) { return tex * mix(1.0, kz_luma(r1) / KZ_S1, (l - KZ_S0) / (KZ_S1 - KZ_S0)); }
	if (l < KZ_S2) { return mix(r1, r2, (l - KZ_S1) / (KZ_S2 - KZ_S1)); }
	if (l < KZ_S3) { return mix(r2, r3, (l - KZ_S2) / (KZ_S3 - KZ_S2)); }
	if (l < KZ_S4) { return mix(r3, r4, (l - KZ_S3) / (KZ_S4 - KZ_S3)); }
	if (l < KZ_S5) { return mix(r4, r5, (l - KZ_S4) / (KZ_S5 - KZ_S4)); }
	return mix(r5, r6, clamp((l - KZ_S5) / (KZ_S6 - KZ_S5), 0.0, 1.0));
}

// Kar parıltısı (bugünkü oyunun parıltısı): hc px hücrede en çok bir piksel kısa yanıp söner. Döner: karışım (0 yok).
float kz_parilti(vec2 px, float t, float yogunluk, float hiz, float hc) {
	vec2 h2 = floor(px / hc);
	float h = kz_hash(h2 + vec2(7.7, 1.9));
	if (h >= yogunluk) { return 0.0; }
	vec2 o = floor(vec2(kz_hash(h2 + vec2(2.3, 9.1)), kz_hash(h2 + vec2(5.6, 3.3))) * (hc - 2.0)) + 1.0;
	vec2 l = px - h2 * hc - o;
	float ph = fract(t * hiz + h * 37.0);
	if (ph < 0.07) {
		if (l == vec2(0.0)) { return 0.85; }
		if (ph > 0.02 && ph < 0.05 && abs(l.x) + abs(l.y) == 1.0) { return 0.45; }
	}
	return 0.0;
}

// Donmuş toprak (oyundaki kd_toprak ile aynı desen) x carpan; kırağı beneği kirağı rengiyle (kar rampasından gelir).
vec3 kz_toprak(vec3 tex, vec2 px, vec3 carpan, vec3 kiragi) {
	bool taban = kz_toprak_maske(tex) > 0.5;
	vec3 c = tex;
	if (taban) {
		vec3 b = toprak_taban.rgb;
		float z = kz_leke(px, 0.006, 30.0);
		if (z > 0.64) { c = tex * (vec3(0.706, 0.596, 0.408) / b); }
		else if (z < 0.36) { c = tex * (vec3(0.753, 0.643, 0.451) / b); }
		vec2 hk = floor(px / 6.0);
		if (kz_hash(hk + vec2(4.4, 8.8)) < 0.12) {
			vec2 o = hk * 6.0 + floor(vec2(kz_hash(hk + vec2(1.1, 3.3)), kz_hash(hk + vec2(9.9, 2.2))) * 5.0);
			if (px == o) { return kiragi; }
		}
		vec2 hc = floor(px / 11.0);
		if (kz_hash(hc + vec2(2.2, 7.7)) < 0.04) {
			vec2 o = hc * 11.0 + 1.0 + floor(vec2(kz_hash(hc + vec2(4.1, 0.6)), kz_hash(hc + vec2(8.3, 5.2))) * 8.0);
			if (px == o) { c = tex * (vec3(0.561, 0.463, 0.314) / b); }
		}
	}
	return c * carpan;
}
