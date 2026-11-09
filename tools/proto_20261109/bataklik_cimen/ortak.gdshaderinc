// KARA BATAKLIK ÇİMEN PROTOTİPLERİ ortak parçası (2026-11-09, kullanıcı: "zemin shaderlarını beğenmedim yeni shader prototipi üretir misin
// çimenler için"; oyuna bağlı DEĞİL). Her prototip yalnız `vec3 cimen(vec3 tex, vec2 px)` yazar; çamur kısmı (toprak_desen + su birikintisi)
// bugünkü scenes/bataklik_zemin.gdshader ile AYNI (yakalayıcı çamur değerlerini oyundaki malzemeden kopyalar). Kural: dither yok, her ton
// geçişi tek adımda düz piksel, desen dünya pikselinde (1 texel = 1 dünya px), yalnız düz çimen pikselleri (taban renge yakın) değişir -
// karoların saçak/kenar çizimleri aynen kalır.
//
// Bataklık setinin çimen paleti (karoların saçaklarından ölçüldü): koyu kontur #2c3821, koyu #4d6836, koyu orta #5b7338, orta #788e45,
// TABAN #90a347, açık #aeb750, parlak #d1d258.

const vec3 P_KONTUR = vec3(0.173, 0.220, 0.129);
const vec3 P_KOYU = vec3(0.302, 0.408, 0.212);
const vec3 P_KOYU_ORTA = vec3(0.357, 0.451, 0.220);
const vec3 P_ORTA = vec3(0.471, 0.557, 0.271);
const vec3 P_TABAN = vec3(0.565, 0.639, 0.278);
const vec3 P_ACIK = vec3(0.682, 0.718, 0.314);
const vec3 P_PARLAK = vec3(0.820, 0.824, 0.345);

uniform vec4 cim_taban : source_color = vec4(0.565, 0.639, 0.278, 1.0);
uniform float cim_tolerans = 0.045;

uniform vec4 birikinti_rengi : source_color = vec4(0.153, 0.400, 0.306, 1.0);
uniform vec4 birikinti_kenar : source_color = vec4(0.290, 0.290, 0.161, 1.0);
uniform vec4 birikinti_isik : source_color = vec4(0.420, 0.600, 0.480, 1.0);
uniform float birikinti_yogunlugu : hint_range(0.0, 1.0) = 0.22;

float pc_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float pc_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(pc_hash(i), pc_hash(i + vec2(1.0, 0.0)), f.x), mix(pc_hash(i + vec2(0.0, 1.0)), pc_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float pc_fbm(vec2 p) {
	return pc_vnoise(p) * 0.55 + pc_vnoise(p * 2.03) * 0.30 + pc_vnoise(p * 4.01) * 0.15;
}

// kıvrımlı leke alanı 0..1 (ölçek: küçük = büyük leke)
float pc_leke(vec2 px, float olcek, float kivrim) {
	vec2 w = vec2(pc_fbm(px * 0.011), pc_fbm(px * 0.011 + vec2(31.7, 7.3))) - 0.5;
	return pc_fbm((px + w * kivrim) * olcek);
}

// Karonun kendi rengine ORANLA uygula (taban karoda paletin birebir aynısı, kenara yakın tonlarda kayma olmaz).
vec3 pc_ton(vec3 tex, vec3 hedef) {
	return tex * (hedef / max(cim_taban.rgb, vec3(0.001)));
}

float pc_cimen_maske(vec3 rgb) {
	return 1.0 - smoothstep(cim_tolerans * 0.55, cim_tolerans * 1.55, distance(rgb, cim_taban.rgb));
}

// Bugünkü çamur su birikintisi (scenes/bataklik_zemin.gdshader ile aynı).
int pc_birikinti(vec2 px) {
	const float HC = 15.0;
	vec2 hc = floor(px / HC);
	if (td_hash12(hc + vec2(4.4, 8.8)) >= birikinti_yogunlugu) { return 0; }
	if (td_lekeler(hc * HC + 7.0) < toprak_koyu_esik) { return 0; }
	vec2 merkez = hc * HC + 4.0 + floor(vec2(td_hash12(hc + vec2(1.1, 3.3)), td_hash12(hc + vec2(6.6, 2.2))) * (HC - 8.0));
	float rx = 1.5 + floor(td_hash12(hc + vec2(9.9, 0.7)) * 2.0);
	float ry = 1.0 + floor(td_hash12(hc + vec2(0.3, 5.5)) * 1.5);
	vec2 d = (px + 0.5 - merkez) / vec2(rx, ry);
	float r = dot(d, d);
	if (r < 0.75) {
		return (px.x == merkez.x - 1.0 && px.y == merkez.y - ry + 0.0) ? 3 : 1;
	}
	if (r < 1.25 && d.y > -0.2) { return 2; }
	return 0;
}

// 4 bitlik palet dizinli küçük çizim: satır = onaltılık sayı, soldan sağa 1 hane = 1 px (0 = boş).
int pc_satir(int satir, int x, int w) {
	return (satir >> ((w - 1 - x) * 4)) & 0xF;
}
