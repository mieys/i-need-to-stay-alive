shader_type canvas_item;

// ==================================================
// ZEMİN TOPRAK - kuru çatlak + çakıl (Harita > Yer > "Zemin Toprak")
// ==================================================
// Kullanıcı isteği (2026-10-02): "çimen ve toprak için ayarladığımız shaderların daha iyi olmasını istiyorum" - 4 prototipten
// "B - Kuru çatlak" ile "C - Çakıllı" karıştırıldı: "toprakta B yi ve C yi karıştırıp uyumlu hale getir ve çatlakları biraz
// azalt". Önceki "Canlı" tasarımı git'te (d65010a); onun kusuru 4x4 Bayer dither'lı leke kenarları + minik topak
// benekleriydi (yakından grenli/dağınık piksel) - burada HİÇ dither yok, her geçiş tek adımda düz piksel.
//
// Tasarım (iki desen birbirini tamamlar, üst üste binmez):
//  - Desen DÜNYA koordinatından (1 dünya pikseli = 1 texel, karolar arası kesintisiz).
//  - Kıvrımlı lekeler: sıkışık koyu / taban / açık / kuru (tozlu) - keskin kenar.
//  - ÇATLAKLAR sadece en kuru (açık) lekelerde, kesik kesik: 1 px koyu çizgi + altında 1 px kalkık açık kenar (Voronoi
//    hücre sınırları).
//  - ÇAKILLAR çoğunlukla koyu (sıkışık) lekelerde: ince çakıl (1-2 px, üç ton, altında 1 px gölge) + seyrek iri çakıl
//    (3x2, sol-üst ışık). Çatlak bölgesinde çakıl çok seyrek.
//  - Tonlar karonun kendi rengine GÖRE uygulanır (çarpan): düz karoda paletin aynısı, kenar karolarındaki ayrıntı korunur.
// Parametre adları eski shader'ınkilerle BİLEREK çakışmıyor (toprak_ / catlak_ / cakil_ önekleri, eski cakil_rengi/
// cakil_golge/cakil_yogunlugu yok): harita_baked.tscn'deki eski kayıtlı değerler yeni varsayılanları ezmesin.

// ---------------- RENKLER (toprak_taban = toprak karosunun rengi; diğerleri ona oranla uygulanır)
uniform vec4 toprak_taban : source_color = vec4(0.588, 0.494, 0.365, 1.0);    // #967e5d
uniform vec4 toprak_koyu : source_color = vec4(0.557, 0.463, 0.341, 1.0);     // sıkışık/koyu leke
uniform vec4 toprak_acik : source_color = vec4(0.616, 0.522, 0.388, 1.0);     // açık leke
uniform vec4 toprak_kuru : source_color = vec4(0.643, 0.553, 0.416, 1.0);     // kuru/tozlu leke (çatlaklar burada)
uniform vec4 catlak_rengi : source_color = vec4(0.522, 0.427, 0.310, 1.0);
uniform vec4 catlak_kenar : source_color = vec4(0.671, 0.584, 0.451, 1.0);    // çatlağın altındaki kalkık kenar
uniform vec4 cakil_acik : source_color = vec4(0.718, 0.647, 0.557, 1.0);
uniform vec4 cakil_orta : source_color = vec4(0.643, 0.573, 0.490, 1.0);
uniform vec4 cakil_koyu : source_color = vec4(0.553, 0.478, 0.400, 1.0);
uniform vec4 cakil_dip : source_color = vec4(0.478, 0.388, 0.294, 1.0);       // çakılın altındaki gölge
uniform vec4 iri_isik : source_color = vec4(0.776, 0.718, 0.643, 1.0);        // iri çakılın sol-üst ışığı

// ---------------- LEKELER
uniform float toprak_leke_olcegi : hint_range(0.003, 0.03) = 0.0080;  // küçük = daha büyük lekeler
uniform float toprak_kivrim : hint_range(0.0, 80.0) = 30.0;
uniform float toprak_koyu_esik : hint_range(0.3, 0.9) = 0.60;         // büyük = daha az koyu leke
uniform float toprak_acik_esik : hint_range(0.1, 0.7) = 0.44;         // küçük = daha az açık leke
uniform float toprak_kuru_esik : hint_range(0.0, 0.6) = 0.36;         // küçük = daha az kuru leke

// ---------------- ÇATLAKLAR
uniform float catlak_esik : hint_range(0.0, 0.7) = 0.42;              // bu lekeden daha kuru yerlerde çatlak olur
uniform float catlak_hucre : hint_range(6.0, 30.0) = 13.0;            // çatlak hücresi (texel) - büyük = seyrek ağ
uniform float catlak_kesik : hint_range(0.0, 1.0) = 0.30;             // büyük = daha kesik/az çatlak

// ---------------- ÇAKILLAR
uniform float ince_cakil_seyrek : hint_range(0.0, 1.0) = 0.05;        // 5 px hücre: açık/kuru lekelerde
uniform float ince_cakil_sik : hint_range(0.0, 1.0) = 0.32;           // 5 px hücre: koyu lekelerde
uniform float iri_cakil_yogunlugu : hint_range(0.0, 1.0) = 0.12;      // 17 px hücre

// ---------------- GENEL
uniform float toprak_efekt : hint_range(0.0, 1.0) = 1.0;              // 0 = karonun düz rengi, 1 = tam efekt

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Dave Hoskins hash12 / hash22 - tam sayı girdilerde periyot/desen üretmez.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
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

float lekeler(vec2 px) {
	vec2 warp = vec2(fbm(px * 0.012), fbm(px * 0.012 + vec2(31.7, 7.3))) - 0.5;
	return fbm((px + warp * toprak_kivrim) * toprak_leke_olcegi);
}

// Voronoi F2-F1 (texel cinsinden) - küçük değer = hücre sınırı (çatlak).
float catlak_mesafe(vec2 p) {
	vec2 g = floor(p / catlak_hucre);
	float f1 = 1e9;
	float f2 = 1e9;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cc = g + vec2(float(x), float(y));
			vec2 pt = (cc + 0.15 + hash22(cc) * 0.7) * catlak_hucre;
			float d = length(p - pt);
			if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
		}
	}
	return f2 - f1;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Sadece toprak renkli pikseller (karonun çimen/kontur pikselleri olduğu gibi kalır).
	float toprak_maske = smoothstep(0.18, 0.38, tex.r - tex.g * 0.55);
	vec2 px = floor(world_pos);

	// LEKELER (keskin kenar)
	float z = lekeler(px);
	vec3 hedef = toprak_taban.rgb;
	if (z > toprak_koyu_esik) { hedef = toprak_koyu.rgb; }
	if (z < toprak_acik_esik) { hedef = toprak_acik.rgb; }
	if (z < toprak_kuru_esik) { hedef = toprak_kuru.rgb; }
	vec3 c = tex.rgb * (hedef / max(toprak_taban.rgb, vec3(0.001)));

	// ÇATLAKLAR: sadece kuru lekelerde, 5x5 bloklar halinde kesik kesik.
	if (z < catlak_esik) {
		vec2 pc = px + 0.5;
		float kes = hash12(floor(px / 5.0) + vec2(3.0, 9.0));
		if (kes > catlak_kesik) {
			if (catlak_mesafe(pc) < 0.8) { c = catlak_rengi.rgb; }
			else if (catlak_mesafe(pc - vec2(0.0, 1.0)) < 0.8) { c = catlak_kenar.rgb; }
		}
	}

	// İNCE ÇAKIL: 5x5 hücrede en fazla 1 (1x1 ya da 2x1, üç ton), altında 1 px gölge - koyu lekelerde sık.
	const float H1 = 5.0;
	vec2 ci = floor(px / H1);
	float zc = lekeler(ci * H1 + 2.0);
	if (hash12(ci + vec2(5.3, 1.7)) < mix(ince_cakil_seyrek, ince_cakil_sik, smoothstep(0.46, 0.68, zc))) {
		vec2 o = floor(vec2(hash12(ci + vec2(2.1, 8.4)), hash12(ci + vec2(6.6, 3.2))) * vec2(H1 - 2.0, H1 - 2.0));
		vec2 l = px - ci * H1 - o;
		float g = hash12(ci + vec2(9.9, 4.4));
		float w = g > 0.55 ? 2.0 : 1.0;
		vec3 tas = g < 0.33 ? cakil_koyu.rgb : (g < 0.7 ? cakil_orta.rgb : cakil_acik.rgb);
		if (l.y == 0.0 && l.x >= 0.0 && l.x < w) { c = (w == 2.0 && l.x == 0.0) ? cakil_acik.rgb : tas; }
		else if (l.y == 1.0 && l.x >= 0.0 && l.x < w) { c = cakil_dip.rgb; }
	}

	// İRİ ÇAKIL: 17x17 hücrede en fazla 1 - 3x2 yuvarlatılmış, sol-üst ışık, altında gölge.
	const float H2 = 17.0;
	vec2 cj = floor(px / H2);
	if (hash12(cj + vec2(1.3, 6.1)) < iri_cakil_yogunlugu) {
		vec2 o2 = floor(vec2(hash12(cj + vec2(4.2, 7.9)), hash12(cj + vec2(8.8, 1.4))) * (H2 - 5.0));
		vec2 m = px - cj * H2 - o2;
		bool tas2 = m.x >= 0.0 && m.x < 3.0 && m.y >= 0.0 && m.y < 2.0 && !(m.y == 1.0 && m.x == 2.0 && hash12(cj) > 0.5);
		if (tas2) { c = (m.y == 0.0 && m.x == 0.0) ? iri_isik.rgb : (m.y == 1.0 ? cakil_orta.rgb : cakil_acik.rgb); }
		else if (m.y == 2.0 && m.x >= 0.0 && m.x < 3.0) { c = cakil_dip.rgb; }
	}

	COLOR = vec4(mix(tex.rgb, c, toprak_maske * toprak_efekt), tex.a);
}
