// KARA BATAKLIK ZEMİN PROTOTİPLERİ 2. tur - YOL (çamur) + ÇİMEN (2026-11-11, kullanıcı: "bataklık biyomundaki zeminlerin shaderleri için
// yeni prototipler hazırla (hem yollar için hem zemin çimleri için)"; oyuna bağlı DEĞİL). Her prototip `vec3 cimen(vec3 tex, vec2 px)` ve
// `vec3 yol(vec3 tex, vec2 px)` yazar; ikisi bağımsız (A'nın çimeni B'nin yoluyla da birleşebilir).
// Kural: dither yok, her ton geçişi tek adımda düz piksel, desen dünya pikselinde (1 texel = 1 dünya px), yalnız DÜZ çimen / DÜZ çamur pikselleri
// (taban renge yakın) değişir - karoların saçak/kenar çizimleri aynen kalır. Renkler setin kendi karolarından ölçüldü.
//
// ÇAMUR maskesi bugünkü oyundan FARKLI: oyunda toprak_maske (r - 0,55g eşiği, ana haritanın kahve toprağına göre) bataklık çamurunda
// (#7c7538) yalnız ~0,18 veriyor -> bugünkü çamur deseni neredeyse görünmüyor. Burada çimendeki gibi taban renge uzaklık.

// ---- Çimen paleti (çimen karolarının saçakları): kontur #2c3821, koyu #4d6836, koyu orta #5b7338, orta #788e45, TABAN #90a347, açık #aeb750, parlak #d1d258
const vec3 G_KONTUR = vec3(0.173, 0.220, 0.129);
const vec3 G_KOYU = vec3(0.302, 0.408, 0.212);
const vec3 G_KOYU_ORTA = vec3(0.357, 0.451, 0.220);
const vec3 G_ORTA = vec3(0.471, 0.557, 0.271);
const vec3 G_TABAN = vec3(0.565, 0.639, 0.278);
const vec3 G_ACIK = vec3(0.682, 0.718, 0.314);
const vec3 G_PARLAK = vec3(0.820, 0.824, 0.345);

// ---- Çamur paleti (kıyı karolarının çamur kıyısı + zemin karoları): #342815 / #42361d / #524625 / #64582d / #69612e / TABAN #7c7538 / #8b8a3b / #9ea047
const vec3 M_KONTUR = vec3(0.204, 0.157, 0.082);
const vec3 M_EN_KOYU = vec3(0.259, 0.212, 0.114);
const vec3 M_KOYU = vec3(0.322, 0.275, 0.145);
const vec3 M_KOYU_ORTA = vec3(0.392, 0.345, 0.176);
const vec3 M_ORTA = vec3(0.412, 0.380, 0.180);
const vec3 M_TABAN = vec3(0.486, 0.459, 0.220);
const vec3 M_ACIK = vec3(0.545, 0.541, 0.231);
const vec3 M_PARLAK = vec3(0.620, 0.627, 0.278);

// ---- Taş paleti (setin kayaları, b_nesne): parlak #dbd8c6, açık #b9b29f, orta #978a7c, koyu #726a65, en koyu #4c4746
const vec3 T_PARLAK = vec3(0.859, 0.847, 0.776);
const vec3 T_ACIK = vec3(0.725, 0.698, 0.624);
const vec3 T_ORTA = vec3(0.592, 0.541, 0.486);
const vec3 T_KOYU = vec3(0.447, 0.416, 0.396);
const vec3 T_EN_KOYU = vec3(0.298, 0.278, 0.275);

uniform vec4 cim_taban : source_color = vec4(0.565, 0.639, 0.278, 1.0);   // #90a347
uniform float cim_tolerans = 0.045;
uniform vec4 camur_taban : source_color = vec4(0.486, 0.459, 0.220, 1.0); // #7c7538
uniform float camur_tolerans = 0.045;

// su birikintisi / su rengi (bataklık suyu, oyundaki birikinti renkleri)
uniform vec4 birikinti_rengi : source_color = vec4(0.153, 0.400, 0.306, 1.0);
uniform vec4 birikinti_kenar : source_color = vec4(0.290, 0.290, 0.161, 1.0);
uniform vec4 birikinti_isik : source_color = vec4(0.420, 0.600, 0.480, 1.0);

// Suya yakınlık alanı: yakalayıcı assets/map/bataklik_su_derinlik.png'den kurar (su hücresi = 1, kıyıdan uzaklaştıkça doğrusal azalır,
// 160 dünya px'te 0; chamfer uzaklığı). 8 dünya px / teksel, dünya (0,0)'dan, doğrusal süzme. (Mipmap kutu ortalaması denendi: köşeli
// "kamuflaj" lekeleri veriyordu.) Oyuna alınırsa üreteç (gen_bataklik.py) bu dokuyu yazar.
uniform sampler2D su_maske : filter_linear, repeat_disable;
uniform vec2 su_maske_boyut = vec2(556.0, 508.0);
uniform float su_maske_teksel = 8.0;

float pz_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float pz_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(pz_hash(i), pz_hash(i + vec2(1.0, 0.0)), f.x), mix(pz_hash(i + vec2(0.0, 1.0)), pz_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float pz_fbm(vec2 p) {
	return pz_vnoise(p) * 0.55 + pz_vnoise(p * 2.03) * 0.30 + pz_vnoise(p * 4.01) * 0.15;
}

// kıvrımlı leke alanı 0..1 (ölçek: küçük = büyük leke)
float pz_leke(vec2 px, float olcek, float kivrim) {
	vec2 w = vec2(pz_fbm(px * 0.011), pz_fbm(px * 0.011 + vec2(31.7, 7.3))) - 0.5;
	return pz_fbm((px + w * kivrim) * olcek);
}

// Karonun kendi rengine ORANLA (taban karoda paletin birebir aynısı).
vec3 pz_ton_c(vec3 tex, vec3 hedef) {
	return tex * (hedef / max(cim_taban.rgb, vec3(0.001)));
}

vec3 pz_ton_m(vec3 tex, vec3 hedef) {
	return tex * (hedef / max(camur_taban.rgb, vec3(0.001)));
}

float pz_cim_maske(vec3 rgb) {
	return 1.0 - smoothstep(cim_tolerans * 0.55, cim_tolerans * 1.55, distance(rgb, cim_taban.rgb));
}

float pz_camur_maske(vec3 rgb) {
	return 1.0 - smoothstep(camur_tolerans * 0.55, camur_tolerans * 1.55, distance(rgb, camur_taban.rgb));
}

// Suya yakınlık 0..1: suda 1, kıyıdan 160 px uzakta 0.
float pz_islaklik(vec2 px) {
	return texture(su_maske, (px + 0.5) / (su_maske_boyut * su_maske_teksel)).r;
}

// 4 bitlik palet dizinli küçük çizim: satır = onaltılık sayı, soldan sağa 1 hane = 1 px (0 = boş).
int pz_satir(int satir, int x, int w) {
	return (satir >> ((w - 1 - x) * 4)) & 0xF;
}

// Hücre içinde rastgele konumlu küçük çizimin yerel koordinatı (hücre H, çizim w x h). Kapsam dışı -> (-1, -1).
ivec2 pz_hucre_yerel(vec2 px, float H, vec2 tohum, int w, int h) {
	vec2 ci = floor(px / H);
	vec2 o = ci * H + floor(vec2(pz_hash(ci + tohum), pz_hash(ci + tohum.yx + 3.7)) * (H - vec2(float(w), float(h))));
	vec2 l = px - o;
	if (l.x < 0.0 || l.y < 0.0 || l.x >= float(w) || l.y >= float(h)) { return ivec2(-1); }
	return ivec2(l);
}

// Su birikintisi: H x H hücrede en çok bir yassı elips (yarıçap x rx_min..rx_max, y ~0,45 x). Döner: 0 yok, 1 su, 2 kuzey iç duvarı (koyu),
// 3 ışık (sol üst kısa parıltı), 4 güney dudağı (açık). Üst-güney bakışta çukurun kuzey duvarı görünür (gölge), güney dudağı ışık alır.
int pz_birikinti(vec2 px, float H, float yog, float rx_min, float rx_max, vec2 tohum) {
	vec2 hc = floor(px / H);
	if (pz_hash(hc + tohum) >= yog) { return 0; }
	float rx = rx_min + floor(pz_hash(hc + tohum + vec2(9.9, 0.7)) * (rx_max - rx_min + 1.0));
	float ry = max(1.0, floor(rx * 0.45 + 0.5));
	vec2 bos = max(vec2(1.0), vec2(H) - vec2(2.0 * rx + 4.0, 2.0 * ry + 4.0));
	vec2 merkez = hc * H + vec2(rx, ry) + 2.0 + floor(vec2(pz_hash(hc + tohum + vec2(1.1, 3.3)), pz_hash(hc + tohum + vec2(6.6, 2.2))) * bos);
	vec2 d = (px + 0.5 - merkez) / vec2(rx, ry);
	float r = dot(d, d);
	if (r < 1.0) {
		if (d.y < -0.15 && d.x > -0.75 && d.x < -0.15) { return 3; }
		return 1;
	}
	vec2 d2 = (px + 0.5 - merkez) / vec2(rx + 1.0, ry + 1.0);
	float r2 = dot(d2, d2);
	if (r2 < 1.0) {
		return d.y < 0.0 ? 2 : 4;
	}
	return 0;
}

// Kesikli eş yükselti çizgisi: alan K basamağa bölünür; pikselin değeri (n) ile ALTINDAKİ pikselin değeri (n_alt) farklı basamaktaysa
// piksel sınırın üstündedir (1 px kalın, düz kenarlı - yumuşatma yok). Çağıran altındaki pikseli de aynı alanla hesaplar.
bool pz_sinir(float n, float n_alt, float K) {
	return floor(n * K) != floor(n_alt * K);
}
