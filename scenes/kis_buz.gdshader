shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"

// AYAZ DAĞI DONMUŞ GÖLLERİ (2026-11-12): "Yer/Buz" katmanı (setin buz dolgusu + çatlaklı buz karoları; YÜRÜNÜR, collision su saymaz).
// Setin buz karoları YARI SAYDAM (paneller alfa 186, beyaz damarlar 255): örnek haritada altlarında düz su karosu var. Burada altı shader'da:
//  - BUZUN ALTINDAKİ SU: setin su rengi (#436dae) çok büyük, çok yavaş kayan iki tonlu lekelerle (derin koyu / sığ açık) -> buzun altında derinlik;
//  - BALIK GÖLGELERİ: seyrek, buzun altında yavaşça yüzen 7x3 px koyu balıklar (yalnız saydam panellerden görünür, damarların altında kalır);
//  - buzun kendisi setin çizimi; çok az sakinleştirilir (damar kontrastı düşük - göl ekranın büyük kısmını kaplayınca göz yormasın);
//  - IŞILTI: dünyada yavaşça kayan çapraz, iki basamaklı parlak bant (buzda güneş yansıması) + seyrek tek piksel yanıp sönme.
// Desen dünya pikselinde, dither yok. Kalın ışıltı bandı ve balıklar geceleyin de var (gece renk ayarı her şeyi karartır).

uniform vec4 su_rengi : source_color = vec4(0.263, 0.427, 0.682, 1.0);      // #436dae - setin su karosu
uniform vec4 su_derin : source_color = vec4(0.231, 0.380, 0.635, 1.0);      // derin leke
uniform vec4 su_sig : source_color = vec4(0.302, 0.478, 0.722, 1.0);        // sığ leke
uniform vec4 balik_rengi : source_color = vec4(0.157, 0.271, 0.494, 1.0);
uniform vec4 isilti_rengi : source_color = vec4(0.902, 0.976, 1.0, 1.0);
uniform float sakinlik : hint_range(0.0, 0.5) = 0.14;                       // damar / panel kontrastını ortalamaya çeker
uniform float leke_olcegi : hint_range(0.002, 0.04) = 0.009;
uniform float akis_hizi : hint_range(0.0, 6.0) = 1.2;
uniform float bant_araligi : hint_range(120.0, 1200.0) = 520.0;             // ışıltı bantları arası (dünya px, çapraz)
uniform float bant_hizi : hint_range(0.0, 0.2) = 0.03;
uniform float balik_yogunlugu : hint_range(0.0, 1.0) = 0.3;                 // 112 px hücre başına
uniform float parilti_yogunlugu : hint_range(0.0, 0.2) = 0.03;              // 8 px hücre başına

varying vec2 world_pos;

float kb_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float kb_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(kb_hash(i), kb_hash(i + vec2(1.0, 0.0)), f.x), mix(kb_hash(i + vec2(0.0, 1.0)), kb_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float kb_fbm(vec2 p) {
	return kb_vnoise(p) * 0.55 + kb_vnoise(p * 2.03) * 0.30 + kb_vnoise(p * 4.01) * 0.15;
}

// 7x3 balık silueti (kuyruk solda), yön = +x ise olduğu gibi
bool kb_balik(vec2 l) {
	int x = int(l.x);
	int y = int(l.y);
	if (x < 0 || y < 0 || x > 6 || y > 2) {
		return false;
	}
	int r[3] = int[3](0x46, 0x7F, 0x46); // 1000110 / 1111111 / 1000110 (bit 6 = x0)
	return ((r[y] >> (6 - x)) & 1) == 1;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = floor(world_pos);
	float t = TIME;
	// buzun altındaki su (derinlik)
	vec2 akis = vec2(t * akis_hizi, t * akis_hizi * 0.43);
	vec2 w = vec2(kb_fbm((px + akis * 0.4) * 0.011), kb_fbm((px - akis * 0.3) * 0.011 + vec2(13.1, 4.7))) - 0.5;
	float z = kb_fbm((px + akis + w * 30.0) * leke_olcegi);
	vec3 su = su_rengi.rgb;
	if (z > 0.6) { su = su_derin.rgb; }
	else if (z < 0.38) { su = su_sig.rgb; }
	// balıklar: 112 px hücrede en çok bir tane, hücre içinde yatay yüzer (yön hücreye göre), dikeyde hafif salınır
	const float BC = 112.0;
	vec2 bc = floor(px / BC);
	float bh = kb_hash(bc + vec2(3.3, 8.1));
	if (bh < balik_yogunlugu) {
		float yon = kb_hash(bc + vec2(9.2, 1.4)) < 0.5 ? 1.0 : -1.0;
		float hiz = 5.0 + kb_hash(bc + vec2(6.6, 2.2)) * 6.0;
		float gx = mod(t * hiz * yon + bh * 997.0, BC + 14.0) - 7.0;
		float gy = 20.0 + kb_hash(bc + vec2(1.7, 5.9)) * (BC - 40.0) + floor(sin(t * 0.7 + bh * 40.0) * 1.5);
		vec2 l = px - bc * BC - floor(vec2(gx, gy));
		if (yon < 0.0) { l.x = 6.0 - l.x; }
		if (kb_balik(l)) { su = balik_rengi.rgb; }
	}
	vec3 c = mix(su, tex.rgb, tex.a);
	// sakinleştirme: damarlar ile paneller arasındaki farkı biraz kıs
	c = mix(c, vec3(0.43, 0.66, 0.84), sakinlik);
	// ışıltı bandı: çapraz, iki basamak (dış geniş + iç ince), dünyada kayar
	float s = fract((px.x * 0.55 + px.y) / bant_araligi - t * bant_hizi);
	if (s < 0.045) {
		c = mix(c, isilti_rengi.rgb, (s > 0.012 && s < 0.03) ? 0.26 : 0.13);
	}
	// tek piksel yanıp sönme
	const float HC = 8.0;
	vec2 hc = floor(px / HC);
	float h = kb_hash(hc + vec2(5.5, 2.5));
	if (h < parilti_yogunlugu) {
		vec2 o = floor(vec2(kb_hash(hc + vec2(1.3, 7.1)), kb_hash(hc + vec2(8.8, 4.4))) * (HC - 2.0)) + 1.0;
		float ph = fract(t * 0.3 + h * 41.0);
		if (ph < 0.06 && px - hc * HC == o) { c = mix(c, isilti_rengi.rgb, 0.85); }
	}
	COLOR = vec4(c, 1.0);
	if (tex.a <= 0.0) { COLOR.a = 0.0; }
	if (COLOR.a > 0.0) { COLOR.rgb = harita_renk(COLOR.rgb); }
}
