// GÜN IŞIĞI + SİS prototipleri ortak parçalar (madde 282, oyuna bağlı DEĞİL). gunes_sis_capture.gd her karede yazar.
// Her şey dünya texel ızgarasına oturur (piksel oyun). Geçişler DÜZ kademe (dither YOK - kullanıcı noktalı geçişleri
// "parazitli" buluyor, bkz. madde 209 2. set).

uniform vec2 dunya_sol_ust = vec2(0.0);
uniform vec2 dunya_boyut = vec2(640.0, 360.0);
uniform vec2 kamera = vec2(0.0);
uniform vec2 oyuncu = vec2(0.0);       // yerel oyuncunun ayak noktası (dünya px)
uniform float zaman = 0.0;
uniform vec2 ruzgar_ofset = vec2(0.0); // rüzgarla birikmiş sürüklenme (dünya px)
uniform float karanlik = 0.0;           // AtmosphereMath.darkness: 0 gündüz, 1 gece

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	return vec2(hash12(p), hash12(p + vec2(19.19, 7.13)));
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
	return vnoise(p) * 0.55 + vnoise(p * 2.03 + 17.1) * 0.30 + vnoise(p * 4.01 + 5.3) * 0.15;
}

// Ekran UV -> dünya texel merkezi.
vec2 gs_texel(vec2 screen_uv) {
	return floor(dunya_sol_ust + screen_uv * dunya_boyut) + 0.5;
}

// Dünya noktası -> ekran UV.
vec2 gs_uv(vec2 px) {
	return (px - dunya_sol_ust) / dunya_boyut;
}

// Paralaks uzayı: 0 = zemine yapışık, 1 = ekrana yapışık, < 0 = zeminden HIZLI kayar (kameraya yakın, havada).
vec2 gs_paralaks(vec2 px, float p) {
	return px - (px - kamera) * p;
}

// Düz kademe: 0..1 değeri n eşit basamağa böler (kenar = tek texel'lik temiz çizgi, dither yok).
float gs_kademe(float x, float n) {
	return floor(clamp(x, 0.0, 0.9999) * n + 0.0001) / max(n - 1.0, 1.0);
}

float gs_lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}
