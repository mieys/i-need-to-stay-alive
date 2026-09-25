shader_type canvas_item;

// ==================================================
// ZEMİN TOPRAK - cozy piksel toprak (Harita > Yer > "Zemin Toprak")
// ==================================================
// Kullanıcı isteği (2026-09-25): "zemin toprak tilelayerında shader var ancak toprak pek güzel durmuyor pixel tarzında daha
// cozy ve göz yormayan bir toprak texture'ına sahip olacağı bir shadera ihtiyacı var" - prototiplerden "C - Canlı" seçildi
// (sade lekeler + seyrek çakıllar + çok seyrek filiz/çöp).
//
// Eski shader'ın asıl sorunu: deseni ATLAS UV'sinden (UV / TEXTURE_PIXEL_SIZE) hesaplıyordu. Harita tek bir düz toprak
// karosuyla (Ground_grass.png 1,4) döşeli olduğu için her 16x16 karo atlasın AYNI bölgesini örnekliyor -> aynı benek deseni
// her 16 px'te birebir tekrar ediyor, karo sınırlarında kopuyordu (göz yoran ızgara hissi). Ayrıca hash'i (x*127.1) tam sayı
// girdilerde 10'luk periyotla tekrar ediyordu.
//
// Yeni tasarım:
//  - Desen DÜNYA koordinatından (1 dünya pikseli = 1 texel, karolar arası kesintisiz; kamera 2x'te her texel 2x2 ekran pikseli).
//  - Birkaç tonlu sınırlı palet: yumuşak, düşük kontrastlı koyu/açık lekeler (domain-warp'lı gürültü), leke kenarlarında
//    yalnız 2-4 px'lik ince 4x4 Bayer dither (piksel-sanat geçişi, bulanık gradyan yok).
//  - Seyrek 3-4 px'lik minik topaklar + seyrek küçük çakıllar (1 px ışık sol-üst, 1 px gölge alt) + çok seyrek 3 px'lik
//    yeşil filizler ve 4 px'lik dal/çöp parçaları.
//  - Tonlar karonun kendi rengine GÖRE uygulanır (çarpan): düz karoda paletin aynısı, kenar karolarındaki ayrıntı korunur.
// Yeni parametre adları eski shader'ınkilerle BİLEREK çakışmıyor: sahnede (harita_baked.tscn) eski adlarla kayıtlı değerler
// (soil_opacity 0.606 vb.) yeni varsayılanları ezmesin. O eski kayıtlar artık kullanılmıyor, zararsız.

// ---------------- RENKLER (karonun kendi rengi = taban; diğerleri ona göre oran olarak uygulanır)
uniform vec4 zemin_taban : source_color = vec4(0.588, 0.494, 0.365, 1.0);      // #967e5d - toprak karosunun rengi
uniform vec4 zemin_koyu : source_color = vec4(0.549, 0.451, 0.333, 1.0);       // #8c7355 - nemli/koyu lekeler
uniform vec4 zemin_daha_koyu : source_color = vec4(0.514, 0.412, 0.298, 1.0);  // #83694c - koyu lekelerin iç kısmı
uniform vec4 zemin_acik : source_color = vec4(0.624, 0.525, 0.392, 1.0);       // #9f8664 - kuru/açık lekeler

// ---------------- LEKELER
uniform float leke_olcegi : hint_range(0.003, 0.03) = 0.0095;      // küçük = daha büyük lekeler
uniform float koyu_esik : hint_range(0.3, 0.9) = 0.58;             // büyük = daha az koyu leke
uniform float daha_koyu_esik : hint_range(0.3, 0.95) = 0.68;
uniform float acik_esik : hint_range(0.1, 0.7) = 0.40;             // küçük = daha az açık leke
uniform float kenar_yumusakligi : hint_range(0.0, 0.08) = 0.012;   // leke kenarındaki dither bandı
uniform float kivrim : hint_range(0.0, 80.0) = 36.0;               // lekelerin kıvrımlılığı (domain warp)

// ---------------- MİNİK TOPAKLAR + ÇAKILLAR
uniform float topak_miktari : hint_range(0.0, 1.0) = 1.0;
uniform float cakil_yogunlugu : hint_range(0.0, 0.6) = 0.12;       // 11x11 px hücre başına çakıl olasılığı
uniform vec4 cakil_rengi : source_color = vec4(0.663, 0.576, 0.478, 1.0);   // #a9937a
uniform vec4 cakil_isik : source_color = vec4(0.733, 0.651, 0.549, 1.0);    // #bba68c
uniform vec4 cakil_golge : source_color = vec4(0.463, 0.376, 0.290, 1.0);   // #76604a

// ---------------- FİLİZ + ÇÖP ("C - Canlı": toprak cansız durmasın diye çok seyrek)
uniform float filiz_yogunlugu : hint_range(0.0, 0.6) = 0.18;       // 29x29 px hücre başına küçük yeşil filiz olasılığı
uniform float cop_yogunlugu : hint_range(0.0, 0.6) = 0.10;         // 29x29 px hücre başına küçük dal/çöp parçası olasılığı
uniform vec4 filiz_acik : source_color = vec4(0.612, 0.773, 0.416, 1.0);    // #9cc56a - filizin ucu
uniform vec4 filiz_koyu : source_color = vec4(0.435, 0.604, 0.282, 1.0);    // #6f9a48
uniform vec4 cop_rengi : source_color = vec4(0.416, 0.322, 0.220, 1.0);     // #6a5238

// ---------------- GENEL
uniform float efekt_gucu : hint_range(0.0, 1.0) = 1.0;             // 0 = karonun düz rengi, 1 = tam efekt

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Dave Hoskins hash12 - tam sayı girdilerde periyot/desen üretmez.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03) * 0.30 + vnoise(p * 4.01) * 0.15;
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[y * 4 + x] / 16.0 + 1.0 / 32.0;
}

// v > esik ? 1 : 0 - eşiğin +-kenar_yumusakligi bandında Bayer dither.
bool dith(float v, float esik, vec2 px) {
	float t = clamp((v - esik) / max(2.0 * kenar_yumusakligi, 0.0001) + 0.5, 0.0, 1.0);
	return t > bayer4(px);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Sadece toprak renkli pikseller (karonun çimen/kontur pikselleri olduğu gibi kalır).
	float soil_mask = smoothstep(0.18, 0.38, tex.r - tex.g * 0.55);

	vec2 px = floor(world_pos);   // dünya pikseli (texel) - bütün desen bu ızgarada sabit

	// LEKELER: domain warp'lı gürültü, eşiklerle koyu / daha koyu / açık bölgeler.
	vec2 warp = vec2(fbm(px * 0.012), fbm(px * 0.012 + vec2(31.7, 7.3))) - 0.5;
	float z = fbm((px + warp * kivrim) * leke_olcegi);
	vec3 target = zemin_taban.rgb;
	if (dith(z, koyu_esik, px)) { target = zemin_koyu.rgb; }
	if (dith(z, daha_koyu_esik, px)) { target = zemin_daha_koyu.rgb; }
	if (!dith(z, acik_esik, px)) { target = zemin_acik.rgb; }
	// Karonun kendi rengine oranla uygula (düz toprak karosunda paletin birebir aynısı).
	vec3 c = tex.rgb * (target / max(zemin_taban.rgb, vec3(0.001)));

	// MİNİK TOPAKLAR: 3-4 px'lik seyrek koyu/açık kümeler (tek tek benek yerine).
	float cl = vnoise(px * 0.45);
	float h = hash12(px + vec2(11.0, 3.0));
	if (cl > 0.80 && h > 0.35) { c = mix(c, c * vec3(0.94, 0.935, 0.93), topak_miktari); }
	if (cl < 0.12 && h > 0.45) { c = mix(c, min(c * vec3(1.05, 1.05, 1.045), vec3(1.0)), topak_miktari); }

	// ÇAKILLAR: 11x11 hücrede en fazla 1 taş (2x1 / 2x2 / 3x2, köşesi yuvarlak), sol-üst 1 px ışık, altında 1 px gölge.
	const float CELL = 11.0;
	vec2 ci = floor(px / CELL);
	if (hash12(ci + vec2(5.3, 1.7)) < cakil_yogunlugu) {
		vec2 o = floor(vec2(hash12(ci + vec2(2.1, 8.4)), hash12(ci + vec2(6.6, 3.2))) * (CELL - 4.0));
		float kind = hash12(ci + vec2(9.9, 4.4));
		vec2 l = px - ci * CELL - o;
		float w = kind > 0.6 ? 3.0 : 2.0;
		float hh = kind > 0.3 ? 2.0 : 1.0;
		bool inside = l.x >= 0.0 && l.y >= 0.0 && l.x < w && l.y < hh && !(w == 3.0 && hh == 2.0 && l.x == 2.0 && l.y == 1.0);
		if (inside) {
			c = (l.x == 0.0 && l.y == 0.0) ? cakil_isik.rgb : cakil_rengi.rgb;
		} else if (l.y == hh && l.x >= 0.0 && l.x < w) {
			c = cakil_golge.rgb;
		}
	}

	// FİLİZ / ÇÖP: 29x29 hücrede en fazla 1 tane - filiz = 3 px gövde + 2 yaprak (ucu açık yeşil), çöp = 4 px çapraz dal.
	const float CELL2 = 29.0;
	vec2 cj = floor(px / CELL2);
	float k = hash12(cj + vec2(1.1, 9.1));
	vec2 o2 = floor(vec2(hash12(cj + vec2(4.4, 2.2)), hash12(cj + vec2(7.7, 5.5))) * (CELL2 - 5.0));
	vec2 m = px - cj * CELL2 - o2;
	if (k < filiz_yogunlugu) {
		bool sprout = (m.x == 1.0 && m.y >= 0.0 && m.y <= 2.0) || (m.x == 0.0 && m.y == 1.0) || (m.x == 2.0 && m.y == 0.0);
		if (sprout) { c = m.y == 0.0 ? filiz_acik.rgb : filiz_koyu.rgb; }
	} else if (k > 1.0 - cop_yogunlugu) {
		if (m.x >= 0.0 && m.x < 4.0 && m.y == floor(m.x / 2.0)) { c = cop_rengi.rgb; }
	}

	COLOR = vec4(mix(tex.rgb, c, soil_mask * efekt_gucu), tex.a);
}
