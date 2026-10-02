shader_type canvas_item;

// ==================================================
// ZEMİN ÇİMEN - "Canlı çayır" (Harita > Yer > "Zemin Çimen", "Su ayrıntılar 2" de aynı materyali paylaşır)
// ==================================================
// Kullanıcı isteği (2026-10-02): "çimen ve toprak için ayarladığımız shaderların daha iyi olmasını istiyorum" - 4 prototipten
// "C - Canlı çayır" seçildi, düzeltmeyle: "C çok iyi ama parlaklar aşırı parlak ve göz alıyor" -> güneşli/açık lekeler,
// yaprak ışığı ve çiçekler yumuşatıldı, güneşli alan küçültüldü.
// Önceki "Yaprak Kümesi" tasarımı git'te (d65010a). Onun asıl kusuru leke kenarlarındaki 4x4 Bayer dither'dı: yakından
// dağınık piksel kırıntısı gibi görünüyordu (kullanıcı gölgelerde de aynısını istemedi) - burada HİÇ dither yok, her ton
// geçişi tek adımda düz piksel.
//
// Tasarım:
//  - Desen DÜNYA koordinatından (1 dünya pikseli = 1 texel; karolar arası kesintisiz, kamera 2x'te her texel 2x2 ekran pikseli).
//  - Kıvrımlı (domain warp) lekeler: derin yeşil / daha derin yeşil / açık / güneşli (sıcak sarımsı) - keskin kenar.
//  - Karo setindeki çalı yaprağının minik hali (yaprak kümesi), koyu lekelerde sık ve gruplu.
//  - Açık lekelerde seyrek minik çiçekler (3x3 artı: beyaz/sarı/pembe), koyu lekelerde üç yapraklı yonca.
//  - Sadece DÜZ çimen piksellerine uygulanır (cim_taban'a yakın): patika/çalı kenarı karolarındaki çizimler aynen kalır.
//  - Tonlar karonun kendi rengine GÖRE uygulanır (çarpan): düz karoda paletin birebir aynısı.
// Parametre adları eski shader'ınkilerle BİLEREK çakışmıyor (cim_ / kume_ önekleri): harita_baked.tscn'deki materyalde eski
// adlarla kayıtlı değerler (renk_koyu, koyu_esik ...) yeni varsayılanları ezmesin - o eski kayıtlar artık kullanılmıyor, zararsız.

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
uniform float kume_seyrek : hint_range(0.0, 1.0) = 0.10;            // yaprak kümesi: açık lekelerde (13 px hücre)
uniform float kume_sik : hint_range(0.0, 1.0) = 0.45;               // yaprak kümesi: koyu lekelerde
uniform float cicek_yogunlugu : hint_range(0.0, 0.6) = 0.16;        // 19 px hücre başına (açık lekelerde)
uniform float yonca_yogunlugu : hint_range(0.0, 0.6) = 0.20;        // 19 px hücre başına (koyu lekelerde)

// ---------------- GENEL
uniform float cim_tolerans : hint_range(0.0, 0.2) = 0.045;          // cim_taban'a bu kadar yakın pikseller "düz çimen"
uniform float cim_efekt : hint_range(0.0, 1.0) = 1.0;               // 0 = karonun düz rengi, 1 = tam efekt

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

// Kıvrımlı büyük lekeler (0..1).
float lekeler(vec2 px) {
	vec2 w = vec2(fbm(px * 0.011), fbm(px * 0.011 + vec2(31.7, 7.3))) - 0.5;
	return fbm((px + w * cim_kivrim) * cim_leke_olcegi);
}

// Hedef tonu karonun kendi rengine oranla uygula (düz karoda paletin birebir aynısı).
vec3 ton(vec3 tex, vec3 hedef) {
	return tex * (hedef / max(cim_taban.rgb, vec3(0.001)));
}

// Yaprak kümesi (karo setindeki çalı yaprağının minik hali). Döner: 0 yok, 1 gövde, 2 ışık (sol-üst), 3 kenar gölgesi,
// 4 zemin gölgesi. Her satır 6 haneli onaltılık sayı (soldan sağa 1 hane = 1 px).
int yaprak(vec2 l, float tur) {
	int x = int(l.x);
	int y = int(l.y);
	if (x < 0 || y < 0 || x > 5 || y > 4) { return 0; }
	int ra[5] = int[5](0x022000, 0x211300, 0x011130, 0x003300, 0x004400);
	int rb[5] = int[5](0x002000, 0x021130, 0x211130, 0x033300, 0x044000);
	int satir = tur < 0.5 ? ra[y] : rb[y];
	return (satir >> ((5 - x) * 4)) & 0xF;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Sadece düz çimen pikselleri (karo kenarlarındaki yaprak/kontur çizimleri olduğu gibi kalır).
	float maske = 1.0 - smoothstep(cim_tolerans * 0.55, cim_tolerans * 1.55, distance(tex.rgb, cim_taban.rgb));
	vec2 px = floor(world_pos);

	// LEKELER (keskin kenar)
	float z = lekeler(px);
	vec3 hedef = cim_taban.rgb;
	bool koyu = false;
	if (z > cim_koyu_esik) { hedef = cim_koyu.rgb; koyu = true; }
	if (z > cim_daha_koyu_esik) { hedef = cim_daha_koyu.rgb; }
	if (z < cim_acik_esik) { hedef = cim_acik.rgb; }
	if (z < cim_gunes_esik) { hedef = cim_gunes.rgb; }
	vec3 c = ton(tex.rgb, hedef);

	// YAPRAK KÜMELERİ: 13x13 hücrede en fazla 1; koyu lekede sık (gruplanırlar).
	const float HUCRE = 13.0;
	vec2 ci = floor(px / HUCRE);
	vec2 o = floor(vec2(hash12(ci + vec2(3.1, 6.2)), hash12(ci + vec2(6.2, 3.1) + 3.7)) * (vec2(HUCRE) - vec2(6.0, 5.0) - 1.0));
	vec2 l = px - ci * HUCRE - o;
	float zc = lekeler(ci * HUCRE + 6.0);
	float olasilik = mix(kume_seyrek, kume_sik, smoothstep(0.42, 0.68, zc));
	if (hash12(ci + vec2(1.9, 7.3)) < olasilik) {
		int t = yaprak(l, hash12(ci + vec2(4.6, 2.8)));
		if (t == 1) { c = ton(tex.rgb, koyu ? cim_acik.rgb : yaprak_govde.rgb); }
		else if (t == 2) { c = ton(tex.rgb, koyu ? yaprak_govde.rgb : yaprak_isik.rgb); }
		else if (t == 3 || t == 4) { c = ton(tex.rgb, koyu ? yaprak_golge.rgb : cim_daha_koyu.rgb); }
	}

	// ÇİÇEK / YONCA: 19x19 hücrede en fazla 1 - açık lekelerde çiçek, koyu lekelerde yonca.
	const float H2 = 19.0;
	vec2 cj = floor(px / H2);
	vec2 o2 = floor(vec2(hash12(cj + vec2(8.1, 2.6)), hash12(cj + vec2(2.6, 8.1))) * (H2 - 4.0));
	vec2 m = px - cj * H2 - o2;
	float zj = lekeler(cj * H2 + 9.0);
	float r = hash12(cj + vec2(5.5, 5.5));
	if (zj < 0.55 && r < cicek_yogunlugu) {
		float tur = hash12(cj + vec2(1.3, 9.7));
		vec3 yaprakcik = tur < 0.45 ? cicek_beyaz.rgb : (tur < 0.8 ? cicek_sari.rgb : cicek_pembe.rgb);
		vec3 orta = tur < 0.45 ? cicek_sari.rgb : cicek_beyaz.rgb;
		if (m == vec2(1.0, 1.0)) { c = orta; }
		else if (m == vec2(1.0, 0.0) || m == vec2(0.0, 1.0) || m == vec2(2.0, 1.0) || m == vec2(1.0, 2.0)) { c = yaprakcik; }
		else if (m == vec2(1.0, 3.0) || m == vec2(2.0, 2.0)) { c = ton(tex.rgb, cim_daha_koyu.rgb); }
	} else if (zj > 0.58 && r < yonca_yogunlugu) {
		// yonca: üç yaprak (2x2 bloklar) + ortada koyu, altında gölge
		bool y1 = (m.x >= 0.0 && m.x <= 1.0 && m.y >= 1.0 && m.y <= 2.0);
		bool y2 = (m.x >= 2.0 && m.x <= 3.0 && m.y >= 1.0 && m.y <= 2.0);
		bool y3 = (m.x >= 1.0 && m.x <= 2.0 && m.y == 0.0);
		if (m == vec2(1.0, 1.0) || m == vec2(2.0, 1.0)) { c = ton(tex.rgb, yaprak_golge.rgb); }
		else if (y1 || y2 || y3) { c = ton(tex.rgb, (m.y == 0.0 || m.x == 0.0) ? yaprak_govde.rgb : cim_acik.rgb); }
		else if (m.y == 3.0 && m.x >= 1.0 && m.x <= 2.0) { c = ton(tex.rgb, yaprak_golge.rgb); }
	}

	COLOR = vec4(mix(tex.rgb, c, maske * cim_efekt), tex.a);
}
