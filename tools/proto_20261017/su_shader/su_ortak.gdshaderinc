// SU SHADER PROTOTİPLERİ ortak parçaları (2026-10-17, oyuna bağlı DEĞİL; bkz. su_capture.gd).
// Hepsi dünya koordinatında, harita karolarının piksel ızgarasında (1 dünya birimi = 1 karo pikseli) çalışır.

// Kıyıya uzaklık dokusu (su_mesafe.py): R = uzaklık / 64 dünya px, 2 dünya px/teksel, doğrusal süzgeç.
uniform sampler2D su_mesafe : filter_linear, repeat_disable;
uniform vec2 mesafe_origin = vec2(-576.0, -384.0);
uniform vec2 mesafe_size = vec2(5248.0, 4864.0);

// Dünya pikselinin (px = floor(dünya)) kıyıya uzaklığı, dünya px. Kıyı çizgisi ~0; kıyı sanatının altı < 0.
float su_kiyi(vec2 px) {
	vec2 uv = (px + 0.5 - mesafe_origin) / mesafe_size;
	return texture(su_mesafe, uv).r * 64.0 - 1.0;
}

// Su karosunun pikseli mi (terrain_collision.gd _class_mask ile aynı kural)? Su katmanına boyanmış çimen karoları değil.
bool su_mavi_mi(vec3 c) {
	return c.b > c.g + 0.03 && c.b > c.r + 0.1;
}

float su_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 su_hash2(vec2 p) {
	return vec2(su_hash(p), su_hash(p + vec2(19.19, 7.73)));
}

// Gradyan (Perlin) gürültü, 0..1. Değer gürültüsü KULLANILMAZ: sert eşikle (kademe) ızgaraya hizalı dikdörtgen lekeler veriyordu.
vec2 su_grad(vec2 p) {
	float a = su_hash(p) * 6.2831853;
	return vec2(cos(a), sin(a));
}

float su_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(su_grad(i), f);
	float b = dot(su_grad(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(su_grad(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(su_grad(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return clamp(0.5 + mix(mix(a, b, u.x), mix(c, d, u.x), u.y), 0.0, 1.0);
}

// iki oktav, ikinci oktav döndürülmüş (eksen hizası kalmasın)
float su_fbm(vec2 p) {
	vec2 q = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.1 + vec2(3.1, 1.7);
	return su_noise(p) * 0.62 + su_noise(q) * 0.38;
}

// 4x4 Bayer eşiği (0..1): piksel dilinde kademe geçişlerini noktalı (dither) yapar.
float su_bayer(vec2 px) {
	vec2 p = mod(px, 4.0);
	vec2 a = mod(p, 2.0);
	vec2 b = floor(p / 2.0);
	float v = 4.0 * mod(2.0 * a.x + 3.0 * a.y, 4.0) + mod(2.0 * b.x + 3.0 * b.y, 4.0);
	return (v + 0.5) / 16.0;
}

// 0..1 değeri n kademeye nicemler; kademe sınırında `genislik` (kademenin oranı) kadar noktalı geçiş.
float su_kademe(float v, float n, float esik, float genislik) {
	return clamp(floor(v * n + 0.5 + (esik - 0.5) * genislik), 0.0, n) / n;
}

// Seyrek yatay pırıltılar (mevcut su.gdshader'ın pırıltısı, parametreli): hücre başına en fazla bir çizgi, büyüyüp küçülür.
// 0 = yok, 1 = parlak, 0.55 = sönük uç.
float su_pirilti(vec2 px, float t, vec2 hucre, float yogunluk, float uzun, vec2 akinti, float hiz) {
	vec2 q = px - floor(akinti * t);
	vec2 cell = floor(q / hucre);
	vec2 ic = q - cell * hucre;
	float r = su_hash(cell);
	if (r >= yogunluk) {
		return 0.0;
	}
	float r2 = su_hash(cell + vec2(17.3, 4.1));
	float r3 = su_hash(cell + vec2(3.1, 29.7));
	float max_len = 2.0 + floor(r2 * (uzun + 1.0));
	vec2 o = floor(vec2(r3 * (hucre.x - max_len), r2 * (hucre.y - 1.0)));
	float phase = fract(t * hiz + r * 11.0 + r3 * 3.0);
	if (phase >= 0.4) {
		return 0.0;
	}
	float grow = 1.0 - abs(phase / 0.4 * 2.0 - 1.0);
	float len = max(1.0, floor(max_len * grow + 0.5));
	float dx = ic.x - o.x - floor((max_len - len) * 0.5);
	if (abs(ic.y - o.y) > 0.5 || dx < 0.0 || dx >= len) {
		return 0.0;
	}
	return (len > 2.0 && (dx < 0.5 || dx > len - 1.5)) ? 0.55 : 1.0;
}

// Su olmayan piksel (Su katmanına boyanmış çimen karosu): mevcut shader'daki gibi hafif renk + saydamlık.
vec4 su_disi(vec4 tex) {
	return vec4(mix(tex.rgb, vec3(0.18, 0.48, 0.68), 0.12), tex.a * 0.73);
}
