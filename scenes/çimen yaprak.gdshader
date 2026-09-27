shader_type canvas_item;

// ==================================================
// ZEMİN ÇİMEN - piksel yaprak kümeli çimen (Harita > Yer > "Zemin Çimen")
// ==================================================
// Kullanıcı isteği (2026-09-26): "Zemin Çimen tilelayerındaki shaderı pixel oyunumla daha uyumlu bir shaderla değiştir" -
// 6 prototipten "C - Yaprak Kümesi" seçildi. Eski shader (çimen kir.gdshader) geri dönülebilsin diye olduğu gibi duruyor.
//
// Eski shader'ın sorunları: blade_density = 1.0 ile her 8x8 px hücreye bir çimen çizgisi düşüyordu (düzenli ızgara hissi),
// karanlık öbek + gürültü katmanı çimeni kirli/koyu gösteriyordu, renkler karo setinin paletinden değildi.
//
// Tasarım:
//  - Desen DÜNYA koordinatından (1 dünya pikseli = 1 texel; karolar arası kesintisiz, kamera 2x'te her texel 2x2 ekran pikseli).
//  - Sadece çimen karo setinin (Ground_grass.png) kendi yeşil paleti.
//  - Kıvrımlı 3 tonlu yumuşak lekeler (domain warp), leke kenarında sadece ince 4x4 Bayer dither (bulanık geçiş yok).
//  - Karo setindeki çalı yaprağının minik hali (ışık sol-üst, gövde, sağ-alt kenar gölgesi, zemin gölgesi); koyu lekelerde
//    daha sık, gruplar halinde - rastgele ızgara hissi olmasın.
//  - Sadece DÜZ çimen piksellerine uygulanır (renk_taban'a yakın): patika/çalı kenarı karolarındaki çizimler aynen kalır.
//  - Tonlar karonun kendi rengine GÖRE uygulanır (çarpan): düz karoda paletin birebir aynısı.

// ---------------- RENKLER (karo setinin paleti; renk_taban = düz çimen karosunun rengi)
uniform vec4 renk_taban : source_color = vec4(0.478, 0.678, 0.333, 1.0);      // #7aad55
uniform vec4 renk_orta_koyu : source_color = vec4(0.443, 0.643, 0.325, 1.0);  // #71a453 - hafif koyu lekeler
uniform vec4 renk_koyu : source_color = vec4(0.392, 0.608, 0.318, 1.0);       // #649b51 - koyu lekelerin içi
uniform vec4 renk_daha_koyu : source_color = vec4(0.357, 0.573, 0.322, 1.0);  // #5b9252 - yaprak kenar gölgesi
uniform vec4 renk_golge : source_color = vec4(0.318, 0.506, 0.294, 1.0);      // #51814b - yaprağın zemin gölgesi
uniform vec4 renk_acik : source_color = vec4(0.522, 0.722, 0.349, 1.0);       // #85b859 - açık lekeler
uniform vec4 renk_daha_acik : source_color = vec4(0.588, 0.773, 0.373, 1.0);  // #96c55f - yaprak gövdesi
uniform vec4 renk_parlak : source_color = vec4(0.729, 0.827, 0.384, 1.0);     // #bad362 - yaprak ışığı

// ---------------- LEKELER
uniform float leke_olcegi : hint_range(0.003, 0.03) = 0.0085;      // küçük = daha büyük lekeler
uniform float kivrim : hint_range(0.0, 80.0) = 38.0;               // lekelerin kıvrımlılığı (domain warp)
uniform float orta_koyu_esik : hint_range(0.3, 0.9) = 0.60;        // büyük = daha az koyu leke
uniform float koyu_esik : hint_range(0.3, 0.95) = 0.69;
uniform float acik_esik : hint_range(0.1, 0.7) = 0.39;             // küçük = daha az açık leke
uniform float kenar_yumusakligi : hint_range(0.0, 0.08) = 0.012;   // leke kenarındaki dither bandı
uniform float benek_yogunlugu : hint_range(0.0, 0.05) = 0.0;       // tek tük 1 px koyu benek (seçilen "C"de yok; istenirse ~0.006)

// ---------------- YAPRAK KÜMELERİ (13x13 px hücre başına en fazla 1)
uniform float yaprak_seyrek : hint_range(0.0, 1.0) = 0.12;         // açık lekelerdeki olasılık
uniform float yaprak_sik : hint_range(0.0, 1.0) = 0.5;             // koyu lekelerdeki olasılık

// ---------------- GENEL
uniform float taban_toleransi : hint_range(0.0, 0.2) = 0.045;      // renk_taban'a bu kadar yakın pikseller "düz çimen" sayılır
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

// v > esik ? true : false - eşiğin +-kenar_yumusakligi bandında 4x4 Bayer dither (piksel-sanat geçişi).
bool dith(float v, float esik, vec2 px) {
	float t = clamp((v - esik) / max(2.0 * kenar_yumusakligi, 0.0001) + 0.5, 0.0, 1.0);
	return t > bayer4(px);
}

// Kıvrımlı büyük lekeler (0..1).
float lekeler(vec2 px) {
	vec2 w = vec2(fbm(px * 0.011), fbm(px * 0.011 + vec2(31.7, 7.3))) - 0.5;
	return fbm((px + w * kivrim) * leke_olcegi);
}

// Hedef tonu karonun kendi rengine oranla uygula (düz karoda paletin birebir aynısı).
vec3 ton(vec3 tex, vec3 hedef) {
	return tex * (hedef / max(renk_taban.rgb, vec3(0.001)));
}

// Yaprak kümesi (karo setindeki çalı yaprağının minik hali). Döner: 0 yok, 1 gövde, 2 ışık (sol-üst),
// 3 kenar gölgesi (sağ-alt), 4 zemin gölgesi (altta). Her satır 6 haneli onaltılık sayı (soldan sağa 1 hane = 1 px).
int yaprak(vec2 l, float tur) {
	int x = int(l.x);
	int y = int(l.y);
	if (x < 0 || y < 0 || x > 5 || y > 4) { return 0; }
	// tur < 0.5:         diğer:
	// .22...             ..2...
	// 2113..             .2113.
	// .1113.             21113.
	// ..33..             .333..
	// ..44..             .44...
	int ra[5] = int[5](0x022000, 0x211300, 0x011130, 0x003300, 0x004400);
	int rb[5] = int[5](0x002000, 0x021130, 0x211130, 0x033300, 0x044000);
	int satir = tur < 0.5 ? ra[y] : rb[y];
	return (satir >> ((5 - x) * 4)) & 0xF;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Sadece düz çimen pikselleri (karo kenarlarındaki yaprak/kontur çizimleri olduğu gibi kalır).
	float maske = 1.0 - smoothstep(taban_toleransi * 0.55, taban_toleransi * 1.55, distance(tex.rgb, renk_taban.rgb));
	vec2 px = floor(world_pos);

	// LEKELER
	float z = lekeler(px);
	vec3 hedef = renk_taban.rgb;
	int bolge = 0; // -1 açık, 0 taban, 1 orta koyu, 2 koyu
	if (dith(z, orta_koyu_esik, px)) { hedef = renk_orta_koyu.rgb; bolge = 1; }
	if (dith(z, koyu_esik, px)) { hedef = renk_koyu.rgb; bolge = 2; }
	if (!dith(z, acik_esik, px)) { hedef = renk_acik.rgb; bolge = -1; }
	bool koyu_bolge = bolge >= 1;
	vec3 c = ton(tex.rgb, hedef);

	// Tek tük 1 px koyu benek (düz renk "boş" durmasın).
	if (hash12(px + vec2(7.0, 13.0)) < benek_yogunlugu) { c = ton(tex.rgb, bolge == 2 ? renk_daha_koyu.rgb : renk_koyu.rgb); }

	// YAPRAK KÜMELERİ: 13x13 hücrede en fazla 1; olasılık hücrenin leke değerine göre (koyu lekede sık) - gruplanırlar.
	const float HUCRE = 13.0;
	vec2 ci = floor(px / HUCRE);
	vec2 o = floor(vec2(hash12(ci + vec2(3.1, 6.2)), hash12(ci + vec2(6.2, 3.1) + 3.7)) * (vec2(HUCRE) - vec2(6.0, 5.0) - 1.0));
	vec2 l = px - ci * HUCRE - o;
	float zc = lekeler(ci * HUCRE + 6.0);
	float olasilik = mix(yaprak_seyrek, yaprak_sik, smoothstep(0.42, 0.68, zc));
	if (hash12(ci + vec2(1.9, 7.3)) < olasilik) {
		int t = yaprak(l, hash12(ci + vec2(4.6, 2.8)));
		if (t == 1) { c = ton(tex.rgb, koyu_bolge ? renk_acik.rgb : renk_daha_acik.rgb); }
		else if (t == 2) { c = ton(tex.rgb, koyu_bolge ? renk_daha_acik.rgb : renk_parlak.rgb); }
		else if (t == 3) { c = ton(tex.rgb, koyu_bolge ? renk_daha_koyu.rgb : renk_koyu.rgb); }
		else if (t == 4) { c = ton(tex.rgb, koyu_bolge ? renk_golge.rgb : renk_daha_koyu.rgb); }
	}

	COLOR = vec4(mix(tex.rgb, c, maske * efekt_gucu), tex.a);
}
