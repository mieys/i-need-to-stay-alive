// AYAZ DAĞI (kış) ZEMİN DESENİ - "B - RÜZGÂR SIRTLARI" (madde 630, 2026-11-12; ilk sürüm madde 629 "harita çok beyaz göz yoruyor" diye
// değişti). Kullanan: scenes/kis_zemin.gdshader ("Yer/Zemin Toprak" kar dolgu, "Yer/Zemin Çimen" göl kıyısı kar kenarı, "Yer/Patika" toprak
// yol + kenarındaki kar topakları, "Su/Su ayrıntılar 2" sıcak kaynak kıyısı, "Yer/Leke" + "Yer/Kar süsleri" kar/toprak lekeleri - hepsi aynı
// malzeme). Prototip: tools/proto_20261112/kar_zemin/zemin_B.gdshader (formül birebir aynı).
// Kural (oyunun piksel dili, madde 529 dersi): desen DÜNYA pikselinde, dither yok, her ton geçişi tek adım düz piksel.
//  1) KAR RAMPASI (palet değişimi): setin kar tonlarının TAMAMI (dolgu + karoların topak kenarı + gölgeleri; mavi >= kırmızı, doygunluk < 0,26)
//     parlaklık sırasına göre 6 yeni tona eşlenir (taban #c5dadd ~0,83 -> #aabbc4 ~0,74). 0,38 altı (koyu kaya) aynen, 0,38-0,53 orana yumuşar
//     -> karonun çizimi bozulmaz, girdi ayrık olduğu için çıktı da ayrık.
//  2) Düz taban pikselinde RÜZGÂR SIRTLARI: kesik MERCEK biçimli kar dalgaları (1 px açık sırt, altında rüzgâr altı gölgesi ortası 3 px, uçlara
//     incelir), 13 px bant, hafif eğik + menderes, bölge bölge sıklık (sakin cepler + sık tarlalar). Parıltı yok.
//  3) TOPRAK (patika / eriyen kar / toprak lekesi) x0,82 ("ıslak toprak": kar koyulaşınca yol kara karışmasın) + oyunun eski donmuş toprak deseni
//     (tek adım ton + kırağı beneği (rampanın açık tonu) + çakıl).
// Kullanım: if (kd_kar_aile(rgb)) { rgb = kd_kar(tex.rgb, px); } else if (kd_toprak_aile(rgb)) { rgb = kd_toprak(tex.rgb, px); }

// Yeni kar rampası (R4 = taban). Hadime çukurunun "kar" paleti (scripts/hadime_black_hole.gd) bu tonlara göre.
const vec3 KD_R1 = vec3(0.420, 0.478, 0.529);   // #6b7a87
const vec3 KD_R2 = vec3(0.486, 0.549, 0.600);   // #7c8c99
const vec3 KD_R3 = vec3(0.576, 0.643, 0.686);   // #93a4af
const vec3 KD_R4 = vec3(0.667, 0.733, 0.769);   // #aabbc4 TABAN
const vec3 KD_R5 = vec3(0.737, 0.796, 0.824);   // #bccbd2
const vec3 KD_R6 = vec3(0.816, 0.863, 0.882);   // #d0dce1
const vec3 KD_SIRT = vec3(0.769, 0.824, 0.847);  // #c4d2d8 sırt
const vec3 KD_GOLGE = vec3(0.576, 0.651, 0.698); // #93a6b2 rüzgâr altı gölgesi
const vec3 KD_DERIN = vec3(0.522, 0.592, 0.647); // #8597a5 sırtın hemen altı
const vec3 KD_TOPRAK_CARPAN = vec3(0.82, 0.81, 0.82);

// Setin kar rampasının parlaklıkları (k_zemin.png'den ölçüldü): #7a8b97 0,53 / #8ba1ab 0,61 / #a7bdc4 0,72 / #c5dadd 0,832 (TABAN) /
// #d7ebed 0,90 / #edfefe 0,976.
const float KD_S0 = 0.38;
const float KD_S1 = 0.53;
const float KD_S2 = 0.61;
const float KD_S3 = 0.72;
const float KD_S4 = 0.832;
const float KD_S5 = 0.90;
const float KD_S6 = 0.976;
const float KD_SIRT_ARALIGI = 13.0; // sırt bantları arası (dünya px)

uniform vec4 kar_taban : source_color = vec4(0.773, 0.855, 0.867, 1.0);     // #c5dadd: düz kar karosu (desen maskesi)
uniform vec4 toprak_taban : source_color = vec4(0.729, 0.620, 0.427, 1.0);  // #ba9e6d: düz toprak karosu
uniform float taban_tolerans : hint_range(0.0, 0.2) = 0.03;

float kd_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float kd_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(kd_hash(i), kd_hash(i + vec2(1.0, 0.0)), f.x), mix(kd_hash(i + vec2(0.0, 1.0)), kd_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float kd_fbm(vec2 p) {
	return kd_vnoise(p) * 0.55 + kd_vnoise(p * 2.03) * 0.30 + kd_vnoise(p * 4.01) * 0.15;
}

float kd_leke(vec2 px, float olcek, float kivrim) {
	vec2 w = vec2(kd_fbm(px * 0.009), kd_fbm(px * 0.009 + vec2(31.7, 7.3))) - 0.5;
	return kd_fbm((px + w * kivrim) * olcek);
}

float kd_luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Kar ailesi: mavi >= kırmızı, düşük doygunluk. Buzun doygun camgöbeği ve toprak girmez.
bool kd_kar_aile(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	return c.b >= c.r - 0.01 && (mx - mn) / max(mx, 0.001) < 0.26;
}

// Toprak ailesi: kırmızı baskın sıcak tonlar (patika, toprak adası, toprak lekesi).
bool kd_toprak_aile(vec3 c) {
	return c.r > c.b + 0.08 && c.r >= c.g - 0.02;
}

float kd_kar_maske(vec3 rgb) {
	return 1.0 - smoothstep(taban_tolerans * 0.55, taban_tolerans * 1.55, distance(rgb, kar_taban.rgb));
}

float kd_toprak_maske(vec3 rgb) {
	return 1.0 - smoothstep(taban_tolerans * 0.55, taban_tolerans * 1.55, distance(rgb, toprak_taban.rgb));
}

vec3 kd_rampa(vec3 tex) {
	float l = kd_luma(tex);
	if (l <= KD_S0) { return tex; }
	if (l < KD_S1) { return tex * mix(1.0, kd_luma(KD_R1) / KD_S1, (l - KD_S0) / (KD_S1 - KD_S0)); }
	if (l < KD_S2) { return mix(KD_R1, KD_R2, (l - KD_S1) / (KD_S2 - KD_S1)); }
	if (l < KD_S3) { return mix(KD_R2, KD_R3, (l - KD_S2) / (KD_S3 - KD_S2)); }
	if (l < KD_S4) { return mix(KD_R3, KD_R4, (l - KD_S3) / (KD_S4 - KD_S3)); }
	if (l < KD_S5) { return mix(KD_R4, KD_R5, (l - KD_S4) / (KD_S5 - KD_S4)); }
	return mix(KD_R5, KD_R6, clamp((l - KD_S5) / (KD_S6 - KD_S5), 0.0, 1.0));
}

// Düz taban pikselinin rengi: rüzgâr sırtları (yoksa taban).
vec3 kd_sirtlar(vec3 taban, vec2 px) {
	float u = px.y + px.x * 0.12 + 3.0 * sin(px.x * 0.045 + kd_fbm(px * 0.01) * 4.0);
	float k = floor(u / KD_SIRT_ARALIGI);
	float f = floor(u - k * KD_SIRT_ARALIGI);
	float seg_l = 16.0 + floor(kd_hash(vec2(k, 2.9)) * 22.0);
	float sx = px.x + kd_hash(vec2(k, 6.1)) * 60.0;
	float seg = floor(sx / seg_l);
	float s = (sx - seg * seg_l) / seg_l;
	float bolge = kd_leke(px + vec2(311.0, 97.0), 0.006, 30.0);
	if (kd_hash(vec2(k, seg)) < mix(0.18, 0.88, bolge)) { return taban; }
	float w = floor(3.4 * (1.0 - (2.0 * s - 1.0) * (2.0 * s - 1.0)));
	if (w < 1.0) { return taban; }
	float off = floor(kd_hash(vec2(k, seg) + 4.4) * 5.0);
	if (f == off) { return KD_SIRT; }
	if (f == off + 1.0) { return KD_DERIN; }
	if (f > off + 1.0 && f <= off + w) { return KD_GOLGE; }
	return taban;
}

// Kar ailesinden bir piksel -> rampa + (düz tabansa) sırtlar. px = floor(dünya konumu).
vec3 kd_kar(vec3 tex, vec2 px) {
	vec3 c = kd_rampa(tex);
	float mk = kd_kar_maske(tex);
	if (mk > 0.0) { c = mix(c, kd_sirtlar(KD_R4, px), mk); }
	return c;
}

// Toprak ailesinden bir piksel -> donmuş toprak deseni (yalnız düz taban) x ıslak toprak çarpanı; kırağı beneği rampanın açık tonu.
vec3 kd_toprak(vec3 tex, vec2 px) {
	vec3 c = tex;
	if (kd_toprak_maske(tex) > 0.5) {
		vec3 b = toprak_taban.rgb;
		float z = kd_leke(px, 0.006, 30.0);
		if (z > 0.64) { c = tex * (vec3(0.706, 0.596, 0.408) / b); }       // #b49868
		else if (z < 0.36) { c = tex * (vec3(0.753, 0.643, 0.451) / b); }  // #c0a473
		vec2 hk = floor(px / 6.0);
		if (kd_hash(hk + vec2(4.4, 8.8)) < 0.12) {
			vec2 o = hk * 6.0 + floor(vec2(kd_hash(hk + vec2(1.1, 3.3)), kd_hash(hk + vec2(9.9, 2.2))) * 5.0);
			if (px == o) { return KD_R5; }
		}
		vec2 hc = floor(px / 11.0);
		if (kd_hash(hc + vec2(2.2, 7.7)) < 0.04) {
			vec2 o = hc * 11.0 + 1.0 + floor(vec2(kd_hash(hc + vec2(4.1, 0.6)), kd_hash(hc + vec2(8.3, 5.2))) * 8.0);
			if (px == o) { c = tex * (vec3(0.561, 0.463, 0.314) / b); }      // #8f7650 çakıl
		}
	}
	return c * KD_TOPRAK_CARPAN;
}
