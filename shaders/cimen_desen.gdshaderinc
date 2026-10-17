// ZEMİN ÇİMEN DESENİ - "Canlı çayır" (tasarım notu: scenes/çimen yaprak.gdshader başı). 2026-10-16 (madde 186) buraya taşındı ki AYNI
// desen hem zemine ("Zemin Çimen", "Su ayrıntılar 2") hem plato tepelerine ("Orman parçaları 2", scenes/orman_parcalari_doku.gdshader)
// uygulansın: desen DÜNYA koordinatından, iki katman yan yana dikişsiz. Fonksiyonlar "cd_" önekli (orman shader'ında aynı adlı fbm/hash var).
// Kullanım: maske = cimen_maske(tex.rgb); c = cimen_desen(tex.rgb, floor(world_pos)); renk = mix(..., c, maske * cim_efekt).
// Değerler: sahnedeki materyal = buradaki varsayılanlar; bir kısmını OYUNDA scripts/map_color_grade.gd CALM_PARAMS ezer.

// ---------------- RENKLER (cim_taban = düz çimen karosunun rengi; diğerleri ona oranla uygulanır)
uniform vec4 cim_taban : source_color = vec4(0.478, 0.678, 0.333, 1.0);       // #7aad55
uniform vec4 cim_koyu : source_color = vec4(0.420, 0.627, 0.318, 1.0);        // derin yeşil leke
uniform vec4 cim_daha_koyu : source_color = vec4(0.373, 0.580, 0.306, 1.0);   // derin lekenin içi
uniform vec4 cim_acik : source_color = vec4(0.510, 0.702, 0.341, 1.0);        // açık leke (yumuşatıldı)
uniform vec4 cim_gunes : source_color = vec4(0.541, 0.718, 0.345, 1.0);       // güneşli sıcak leke (yumuşatıldı)
uniform vec4 yaprak_govde : source_color = vec4(0.561, 0.741, 0.353, 1.0);
uniform vec4 yaprak_isik : source_color = vec4(0.612, 0.765, 0.365, 1.0);
uniform vec4 yaprak_golge : source_color = vec4(0.361, 0.553, 0.294, 1.0);
uniform vec4 cicek_beyaz : source_color = vec4(0.851, 0.847, 0.773, 1.0);
uniform vec4 cicek_sari : source_color = vec4(0.875, 0.776, 0.431, 1.0);
uniform vec4 cicek_pembe : source_color = vec4(0.824, 0.624, 0.698, 1.0);

// ---------------- LEKELER
uniform float cim_leke_olcegi : hint_range(0.003, 0.03) = 0.0080;   // küçük = daha büyük lekeler
uniform float cim_kivrim : hint_range(0.0, 80.0) = 38.0;            // lekelerin kıvrımlılığı
uniform float cim_koyu_esik : hint_range(0.3, 0.9) = 0.60;          // büyük = daha az derin leke
uniform float cim_daha_koyu_esik : hint_range(0.3, 0.95) = 0.71;
uniform float cim_acik_esik : hint_range(0.1, 0.7) = 0.42;          // küçük = daha az açık leke
uniform float cim_gunes_esik : hint_range(0.0, 0.6) = 0.31;         // küçük = daha az güneşli leke

// ---------------- AYRINTILAR
// OYUNDA kume_/cicek_/yonca_ değerlerini scripts/map_color_grade.gd CALM_PARAMS ezer (madde 184, sahnedeki değer değil).
uniform float kume_seyrek : hint_range(0.0, 1.0) = 0.10;            // yaprak kümesi: açık lekelerde (13 px hücre)
uniform float kume_sik : hint_range(0.0, 1.0) = 0.45;               // yaprak kümesi: koyu lekelerde
uniform float cicek_yogunlugu : hint_range(0.0, 0.6) = 0.16;        // 19 px hücre başına (açık lekelerde)
uniform float yonca_yogunlugu : hint_range(0.0, 0.6) = 0.20;        // 19 px hücre başına (koyu lekelerde)

// ---------------- GENEL
uniform float cim_tolerans : hint_range(0.0, 0.2) = 0.045;          // cim_taban'a bu kadar yakın pikseller "düz çimen"
uniform float cim_efekt : hint_range(0.0, 1.0) = 1.0;               // 0 = karonun düz rengi, 1 = tam efekt

// Dave Hoskins hash12 - tam sayı girdilerde periyot/desen üretmez.
float cd_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float cd_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = cd_hash12(i);
	float b = cd_hash12(i + vec2(1.0, 0.0));
	float c = cd_hash12(i + vec2(0.0, 1.0));
	float d = cd_hash12(i + vec2(1.0, 1.0));
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float cd_fbm(vec2 p) {
	return cd_vnoise(p) * 0.55 + cd_vnoise(p * 2.03) * 0.30 + cd_vnoise(p * 4.01) * 0.15;
}

// Kıvrımlı büyük lekeler (0..1).
float cd_lekeler(vec2 px) {
	vec2 w = vec2(cd_fbm(px * 0.011), cd_fbm(px * 0.011 + vec2(31.7, 7.3))) - 0.5;
	return cd_fbm((px + w * cim_kivrim) * cim_leke_olcegi);
}

// Hedef tonu karonun kendi rengine oranla uygula (düz karoda paletin birebir aynısı).
vec3 cd_ton(vec3 tex, vec3 hedef) {
	return tex * (hedef / max(cim_taban.rgb, vec3(0.001)));
}

// Yaprak kümesi (karo setindeki çalı yaprağının minik hali). Döner: 0 yok, 1 gövde, 2 ışık (sol-üst), 3 kenar gölgesi,
// 4 zemin gölgesi. Her satır 6 haneli onaltılık sayı (soldan sağa 1 hane = 1 px).
int cd_yaprak(vec2 l, float tur) {
	int x = int(l.x);
	int y = int(l.y);
	if (x < 0 || y < 0 || x > 5 || y > 4) { return 0; }
	int ra[5] = int[5](0x022000, 0x211300, 0x011130, 0x003300, 0x004400);
	int rb[5] = int[5](0x002000, 0x021130, 0x211130, 0x033300, 0x044000);
	int satir = tur < 0.5 ? ra[y] : rb[y];
	return (satir >> ((5 - x) * 4)) & 0xF;
}

// Sadece düz çimen pikselleri (karo kenarlarındaki yaprak/kontur çizimleri olduğu gibi kalır): 1 = tam cim_taban.
float cimen_maske(vec3 rgb) {
	return 1.0 - smoothstep(cim_tolerans * 0.55, cim_tolerans * 1.55, distance(rgb, cim_taban.rgb));
}

// px = floor(dünya konumu). Döner: desenli çimen rengi (maske uygulanmamış).
vec3 cimen_desen(vec3 tex_rgb, vec2 px) {
	vec4 tex = vec4(tex_rgb, 1.0);
	// LEKELER (keskin kenar)
	float z = cd_lekeler(px);
	vec3 hedef = cim_taban.rgb;
	bool koyu = false;
	if (z > cim_koyu_esik) { hedef = cim_koyu.rgb; koyu = true; }
	if (z > cim_daha_koyu_esik) { hedef = cim_daha_koyu.rgb; }
	if (z < cim_acik_esik) { hedef = cim_acik.rgb; }
	if (z < cim_gunes_esik) { hedef = cim_gunes.rgb; }
	vec3 c = cd_ton(tex.rgb, hedef);

	// YAPRAK KÜMELERİ: 13x13 hücrede en fazla 1; koyu lekede sık (gruplanırlar).
	const float HUCRE = 13.0;
	vec2 ci = floor(px / HUCRE);
	vec2 o = floor(vec2(cd_hash12(ci + vec2(3.1, 6.2)), cd_hash12(ci + vec2(6.2, 3.1) + 3.7)) * (vec2(HUCRE) - vec2(6.0, 5.0) - 1.0));
	vec2 l = px - ci * HUCRE - o;
	float zc = cd_lekeler(ci * HUCRE + 6.0);
	float olasilik = mix(kume_seyrek, kume_sik, smoothstep(0.42, 0.68, zc));
	if (cd_hash12(ci + vec2(1.9, 7.3)) < olasilik) {
		int t = cd_yaprak(l, cd_hash12(ci + vec2(4.6, 2.8)));
		if (t == 1) { c = cd_ton(tex.rgb, koyu ? cim_acik.rgb : yaprak_govde.rgb); }
		else if (t == 2) { c = cd_ton(tex.rgb, koyu ? yaprak_govde.rgb : yaprak_isik.rgb); }
		else if (t == 3 || t == 4) { c = cd_ton(tex.rgb, koyu ? yaprak_golge.rgb : cim_daha_koyu.rgb); }
	}

	// ÇİÇEK / YONCA: 19x19 hücrede en fazla 1 - açık lekelerde çiçek, koyu lekelerde yonca.
	const float H2 = 19.0;
	vec2 cj = floor(px / H2);
	vec2 o2 = floor(vec2(cd_hash12(cj + vec2(8.1, 2.6)), cd_hash12(cj + vec2(2.6, 8.1))) * (H2 - 4.0));
	vec2 m = px - cj * H2 - o2;
	float zj = cd_lekeler(cj * H2 + 9.0);
	float r = cd_hash12(cj + vec2(5.5, 5.5));
	if (zj < 0.55 && r < cicek_yogunlugu) {
		float tur = cd_hash12(cj + vec2(1.3, 9.7));
		vec3 yaprakcik = tur < 0.45 ? cicek_beyaz.rgb : (tur < 0.8 ? cicek_sari.rgb : cicek_pembe.rgb);
		vec3 orta = tur < 0.45 ? cicek_sari.rgb : cicek_beyaz.rgb;
		if (m == vec2(1.0, 1.0)) { c = orta; }
		else if (m == vec2(1.0, 0.0) || m == vec2(0.0, 1.0) || m == vec2(2.0, 1.0) || m == vec2(1.0, 2.0)) { c = yaprakcik; }
		else if (m == vec2(1.0, 3.0) || m == vec2(2.0, 2.0)) { c = cd_ton(tex.rgb, cim_daha_koyu.rgb); }
	} else if (zj > 0.58 && r < yonca_yogunlugu) {
		// yonca: üç yaprak (2x2 bloklar) + ortada koyu, altında gölge
		bool y1 = (m.x >= 0.0 && m.x <= 1.0 && m.y >= 1.0 && m.y <= 2.0);
		bool y2 = (m.x >= 2.0 && m.x <= 3.0 && m.y >= 1.0 && m.y <= 2.0);
		bool y3 = (m.x >= 1.0 && m.x <= 2.0 && m.y == 0.0);
		if (m == vec2(1.0, 1.0) || m == vec2(2.0, 1.0)) { c = cd_ton(tex.rgb, yaprak_golge.rgb); }
		else if (y1 || y2 || y3) { c = cd_ton(tex.rgb, (m.y == 0.0 || m.x == 0.0) ? yaprak_govde.rgb : cim_acik.rgb); }
		else if (m.y == 3.0 && m.x >= 1.0 && m.x <= 2.0) { c = cd_ton(tex.rgb, yaprak_golge.rgb); }
	}
	return c;
}
