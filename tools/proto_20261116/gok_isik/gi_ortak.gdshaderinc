// GÖK IŞIĞI + YANSIMA prototipleri ortak kodu (2026-11-16, oyuna bağlı DEĞİL; yakalama gok_isik_capture.gd).
// Hepsi renk geçişinden (gece) SONRA tam ekran ColorRect olarak çizilir, sahneyi okur (ekran). Her şey DÜNYA texel ızgarasında
// (floor(dünya px)) hesaplanır - kamera kayınca desen zemine yapışık kalır, piksel ızgarası haritanınkiyle aynı.
// Kurallar: dither / benek YOK (düz alfa kademeleri), en parlak renk krem #f3e6cc, yanıp sönme <= 1 Hz, genlik küçük.

uniform sampler2D ekran : hint_screen_texture, filter_nearest;
uniform vec2 dunya_sol_ust = vec2(0.0);
uniform vec2 dunya_boyut = vec2(960.0, 540.0);
uniform vec2 kamera = vec2(0.0);
uniform vec2 kamera0 = vec2(0.0);      // gök katmanının çapası (güneş/ay yansıması kamerayla birlikte yavaşça kayar)
uniform float zaman = 0.0;
uniform float karanlik = 0.0;          // 0 gündüz .. 1 gece (AtmosphereMath.darkness)
uniform vec2 ruzgar_ofset = vec2(0.0); // bulutların rüzgarla sürüklenmesi (dünya px)

// Su geometrisi: oyundaki scripts/water_fx.gd dokuları (R = kıyıya uzaklık / 64 px, RG = akış).
uniform sampler2D su_mesafe : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D su_akis : hint_default_black, filter_linear, repeat_disable;
uniform vec2 doku_origin = vec2(-576.0, -384.0);
uniform vec2 doku_size = vec2(5248.0, 4864.0);

// DİK DURAN nesneler (ağaç / çalı / ev / karakter): aynı dünyanın yalnız bunları çizen ikinci görünümü (SubViewport, görünürlük katmanı 2),
// 1 texel = 1 dünya px. Su pikselinin üstünde dik nesne varsa (sudaki karakter, suya taşan taç) efekt çizilmez; B aynası bunları yansıtır.
uniform sampler2D dik_doku : hint_default_transparent, filter_nearest, repeat_disable;
uniform vec2 dik_koken = vec2(0.0);
uniform vec2 dik_boyut = vec2(1024.0, 640.0);

const vec3 KREM = vec3(0.953, 0.902, 0.8);

vec2 gi_doku_uv(vec2 px) {
	return (px + 0.5 - doku_origin) / doku_size;
}

// Dünya pikselinin kıyıya uzaklığı (dünya px): suyun içinde > 0, kıyı sanatının altı / kara < 0.
float gi_kiyi(vec2 px) {
	return texture(su_mesafe, gi_doku_uv(px)).r * 64.0 - 1.0;
}

vec2 gi_akis(vec2 px) {
	return texture(su_akis, gi_doku_uv(px)).rg * 2.0 - 1.0;
}

vec2 gi_ekran_uv(vec2 px) {
	return (px + 0.5 - dunya_sol_ust) / dunya_boyut;
}

bool gi_ekranda(vec2 px) {
	vec2 uv = gi_ekran_uv(px);
	return uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0;
}

vec3 gi_ekran(vec2 px) {
	return texture(ekran, gi_ekran_uv(px)).rgb;
}

float gi_dik(vec2 px) {
	vec2 uv = (px + 0.5 - dik_koken) / dik_boyut;
	if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
		return 0.0;
	}
	return texture(dik_doku, uv).a;
}

// Ekrandaki renk SU mu (scenes/su.gdshader mavi_mi kuralı; gece renk geçişi maviyi en az kararttığı için eşik biraz yüksek).
bool gi_mavi(vec3 c) {
	float gt = mix(0.03, 0.05, karanlik);
	float rt = mix(0.1, 0.12, karanlik);
	return c.b > c.g + gt && c.b > c.r + rt;
}

// Görünen su yüzeyi: geometri (kıyıdan içeride) + renk (köprü / taç / karakter değil) + üstünde dik nesne yok.
bool gi_su(vec2 px, vec3 c) {
	return gi_kiyi(px) > 0.5 && gi_mavi(c) && gi_dik(px) < 0.5;
}

float gi_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 gi_hash2(vec2 p) {
	return vec2(gi_hash(p), gi_hash(p + vec2(17.3, 5.9)));
}

float gi_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = gi_hash(i);
	float b = gi_hash(i + vec2(1.0, 0.0));
	float c = gi_hash(i + vec2(0.0, 1.0));
	float d = gi_hash(i + vec2(1.0, 1.0));
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float gi_fbm(vec2 p) {
	return gi_vnoise(p) * 0.55 + gi_vnoise(p * 2.03 + 17.1) * 0.30 + gi_vnoise(p * 4.01 + 5.3) * 0.15;
}

// Sıcak/soğuk ışık ekle: koyu yüzey daha çok açılır, parlak olan az; sonuç krem tavanını geçmez (zaten parlaksa dokunulmaz).
vec3 gi_isik(vec3 c, vec3 renk, float a) {
	vec3 r = c + renk * a * (1.0 - c * 0.55);
	return min(r, max(c, KREM));
}

// 0..1 değeri 3 düz kademeye böler (eşikler e.x < e.y < e.z) -> 0, 1, 2, 3.
float gi_kademe3(float v, vec3 e) {
	return v > e.z ? 3.0 : (v > e.y ? 2.0 : (v > e.x ? 1.0 : 0.0));
}

// Zamanla açılıp sönen şeylerin gücü de basamaklı (4 adım): sönüş yumuşak alfa geçişi değil, düz bantlar.
float gi_basamak(float v, float n) {
	return floor(clamp(v, 0.0, 1.0) * n + 0.5) / n;
}
