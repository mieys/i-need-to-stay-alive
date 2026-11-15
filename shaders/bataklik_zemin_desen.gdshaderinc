// KARA BATAKLIK ZEMİN DESENİ - "C - Sakin Doku" (madde 583, kullanıcı 4 prototipten seçti; prototip tools/proto_20261111/bataklik_zemin/zemin_C).
// Öbek / süs YOK: zeminin her yerine yayılmış, DÜŞÜK KONTRASTLI ince doku. Tonlar taban ile komşu tonun ARASINDA (yarım ton) - uzaktan neredeyse
// düz, yakından dokulu, göz yormaz. Dither yok, desen dünya pikselinde, yalnız DÜZ çimen / DÜZ çamur pikseli (taban renge yakın) değişir - karoların
// saçak / kenar çizimleri aynen kalır.
//  - ÇİMEN: çok büyük yumuşak iki ton, 4 px hücrede yarısında rüzgâra yatık 2 px yaprak izi (bir kısmının ucu açık), 17 px hücrede seyrek tutam.
//  - ÇAMUR (patikalar, açıklıklar, koru altı - hepsi aynı karo): çok büyük iki ton, 3 px hücrede tek piksel koyu / açık benek, 11 px hücrede çakıl.
// Önceki: çimen "B - Ot Tutamları" (madde 526), çamur ana haritanın toprak_desen'i - toprak_maske (ana haritanın kahve toprağına göre) bataklık
// çamurunda ~0,18 veriyordu, desen neredeyse görünmüyordu; burada iki maske de taban renge uzaklık.
// Kullanan: scenes/bataklik_zemin.gdshader ("Yer/Zemin Toprak", "Yer/Zemin Çimen", kıyı karoları "Su/Su ayrıntılar 2" aynı malzeme).
// Kullanım: rgb = mix(rgb, bz_cimen(tex.rgb, px), bz_cim_maske(tex.rgb)); rgb = mix(rgb, bz_camur(tex.rgb, px), bz_camur_maske(tex.rgb));
//
// Palet (setin karolarından ölçüldü): çimen koyu orta #5b7338, orta #788e45, TABAN #90a347, açık #aeb750; çamur koyu orta #64582d, TABAN #7c7538,
// açık #8b8a3b, parlak #9ea047 (kıyı karolarının çamur kıyısı).

const vec3 BZ_G_KOYU_ORTA = vec3(0.357, 0.451, 0.220);
const vec3 BZ_G_ORTA = vec3(0.471, 0.557, 0.271);
const vec3 BZ_G_TABAN = vec3(0.565, 0.639, 0.278);
const vec3 BZ_G_ACIK = vec3(0.682, 0.718, 0.314);
const vec3 BZ_G_YARI_KOYU = vec3(0.518, 0.598, 0.2745);   // TABAN ile ORTA arası
const vec3 BZ_G_YARI_ACIK = vec3(0.6235, 0.6785, 0.296);  // TABAN ile AÇIK arası

const vec3 BZ_M_KOYU_ORTA = vec3(0.392, 0.345, 0.176);
const vec3 BZ_M_TABAN = vec3(0.486, 0.459, 0.220);
const vec3 BZ_M_ACIK = vec3(0.545, 0.541, 0.231);
const vec3 BZ_M_PARLAK = vec3(0.620, 0.627, 0.278);
const vec3 BZ_M_YARI_KOYU = vec3(0.439, 0.402, 0.198);    // TABAN ile KOYU ORTA arası
const vec3 BZ_M_YARI_ACIK = vec3(0.5155, 0.50, 0.2255);   // TABAN ile AÇIK arası

uniform vec4 cim_taban : source_color = vec4(0.565, 0.639, 0.278, 1.0);    // #90a347: düz çimen karosunun rengi (maske + oran tabanı)
uniform float cim_tolerans : hint_range(0.0, 0.2) = 0.045;                // tabana bu kadar yakın pikseller "düz çimen"
uniform vec4 camur_taban : source_color = vec4(0.486, 0.459, 0.220, 1.0);  // #7c7538: düz çamur karosunun rengi
uniform float camur_tolerans : hint_range(0.0, 0.2) = 0.045;

float bz_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bz_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(bz_hash(i), bz_hash(i + vec2(1.0, 0.0)), f.x), mix(bz_hash(i + vec2(0.0, 1.0)), bz_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float bz_fbm(vec2 p) {
	return bz_vnoise(p) * 0.55 + bz_vnoise(p * 2.03) * 0.30 + bz_vnoise(p * 4.01) * 0.15;
}

// kıvrımlı leke alanı 0..1 (ölçek: küçük = büyük leke)
float bz_leke(vec2 px, float olcek, float kivrim) {
	vec2 w = vec2(bz_fbm(px * 0.011), bz_fbm(px * 0.011 + vec2(31.7, 7.3))) - 0.5;
	return bz_fbm((px + w * kivrim) * olcek);
}

// Karonun kendi rengine ORANLA (taban karoda paletin birebir aynısı).
vec3 bz_ton_c(vec3 tex, vec3 hedef) {
	return tex * (hedef / max(cim_taban.rgb, vec3(0.001)));
}

vec3 bz_ton_m(vec3 tex, vec3 hedef) {
	return tex * (hedef / max(camur_taban.rgb, vec3(0.001)));
}

// 1 = tam düz çimen / çamur pikseli.
float bz_cim_maske(vec3 rgb) {
	return 1.0 - smoothstep(cim_tolerans * 0.55, cim_tolerans * 1.55, distance(rgb, cim_taban.rgb));
}

float bz_camur_maske(vec3 rgb) {
	return 1.0 - smoothstep(camur_tolerans * 0.55, camur_tolerans * 1.55, distance(rgb, camur_taban.rgb));
}

// 4 bitlik palet dizinli küçük çizim: satır = onaltılık sayı, soldan sağa 1 hane = 1 px (0 = boş).
int bz_satir(int satir, int x, int w) {
	return (satir >> ((w - 1 - x) * 4)) & 0xF;
}

// H x H hücrede rastgele konumlu w x h çizimin yerel koordinatı; kapsam dışı -> (-1, -1).
ivec2 bz_hucre_yerel(vec2 px, float H, vec2 tohum, int w, int h) {
	vec2 ci = floor(px / H);
	vec2 o = ci * H + floor(vec2(bz_hash(ci + tohum), bz_hash(ci + tohum.yx + 3.7)) * (H - vec2(float(w), float(h))));
	vec2 l = px - o;
	if (l.x < 0.0 || l.y < 0.0 || l.x >= float(w) || l.y >= float(h)) { return ivec2(-1); }
	return ivec2(l);
}

// px = floor(dünya konumu). Döner: desenli çimen rengi (maske uygulanmamış).
vec3 bz_cimen(vec3 tex, vec2 px) {
	float z = bz_leke(px, 0.005, 40.0);
	vec3 c = bz_ton_c(tex, z > 0.6 ? mix(BZ_G_TABAN, BZ_G_YARI_KOYU, 0.5) : BZ_G_TABAN);
	// seyrek tam ton tutam (17 px hücre %18, 3x3)
	ivec2 t = bz_hucre_yerel(px, 17.0, vec2(4.1, 2.6), 3, 3);
	if (t.x >= 0 && bz_hash(floor(px / 17.0) + vec2(0.9, 7.7)) < 0.18) {
		int r[3] = int[3](0x030, 0x323, 0x121);
		int v = bz_satir(r[t.y], t.x, 3);
		if (v == 3) { return bz_ton_c(tex, BZ_G_ACIK); }
		if (v == 2) { return bz_ton_c(tex, BZ_G_ORTA); }
		if (v == 1) { return bz_ton_c(tex, BZ_G_KOYU_ORTA); }
	}
	// yaprak izi: 4 px hücrede %50 "/" (üst sağ + alt sol), %22'sinde üstte açık uç
	vec2 ci = floor(px / 4.0);
	if (bz_hash(ci + vec2(3.7, 1.9)) < 0.5) {
		vec2 o = ci * 4.0 + floor(vec2(bz_hash(ci + vec2(1.2, 8.5)), bz_hash(ci + vec2(6.4, 2.3))) * vec2(3.0, 2.0));
		vec2 l = px - o;
		bool ac = bz_hash(ci + vec2(9.5, 5.5)) < 0.22;
		if (l == vec2(1.0, 0.0)) { c = bz_ton_c(tex, ac ? BZ_G_YARI_ACIK : BZ_G_YARI_KOYU); }
		else if (l == vec2(0.0, 1.0)) { c = bz_ton_c(tex, BZ_G_YARI_KOYU); }
	}
	return c;
}

// px = floor(dünya konumu). Döner: desenli çamur rengi (maske uygulanmamış).
vec3 bz_camur(vec3 tex, vec2 px) {
	float z = bz_leke(px, 0.006, 36.0);
	vec3 c = bz_ton_m(tex, z > 0.6 ? BZ_M_YARI_KOYU : BZ_M_TABAN);
	// çakıl (11 px hücre %13): 2x1 taş + altında gölge
	ivec2 g = bz_hucre_yerel(px, 11.0, vec2(5.9, 3.4), 2, 2);
	if (g.x >= 0 && bz_hash(floor(px / 11.0) + vec2(8.1, 0.6)) < 0.13) {
		if (g.y == 0) { return g.x == 0 ? bz_ton_m(tex, BZ_M_PARLAK) : bz_ton_m(tex, BZ_M_ACIK); }
		return bz_ton_m(tex, BZ_M_KOYU_ORTA);
	}
	// benek: 3 px hücrede %30 koyu, %12 açık tek piksel
	vec2 ci = floor(px / 3.0);
	vec2 o = ci * 3.0 + floor(vec2(bz_hash(ci + vec2(2.0, 0.5)), bz_hash(ci + vec2(7.0, 3.5))) * 3.0);
	if (px == o) {
		float r = bz_hash(ci + vec2(4.4, 9.1));
		if (r < 0.30) { c = bz_ton_m(tex, BZ_M_YARI_KOYU); }
		else if (r < 0.42) { c = bz_ton_m(tex, BZ_M_YARI_ACIK); }
	}
	return c;
}
