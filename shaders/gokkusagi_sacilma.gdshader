shader_type canvas_item;

// GÖKKUŞAĞI ASASI IŞIK SAÇILMASI (madde 551; prototip tools/proto_20261110/gokkusagi_v2 "nefes" kipi Flow("C2") = "C + yıldız"):
// ışın düşmana değdiği sürece vurulandan RASTGELE yönlere yarı saydam tayf konileri - her koni kendi yönünde yumuşakça uzar ve geri kısalır
// (sin^0,85), boyu dipteyken yeni rastgele yöne geçer (görünmez), uç incelerek ve 8 adımda söner; gelen ışının üstüne düşen koni orada kısılır
// (back_ang). Ortada krem ışık lekesi + D'nin dönen 8 kollu yıldızı. Hasar alanı (60 px) koni boyuyla (48-64, son %70'i söner) okunur.
// Quad: fx_rainbow_beam.gd Scatter - merkez = vurulan düşman, 1 piksel = 1 dünya px, top_level dünya koordinatı. Hesap tamamen burada
// (yalnız t / back_ang / seed / alpha uniform), kaster ve uzak kuklada aynı kural - ağ verisi yok (rastgele görünüş eşitlenmez, gerek de yok).

uniform float size = 144.0;
uniform float t = 0.0;
uniform float back_ang = 3.14159;
uniform float seed = 0.0;
uniform float alpha = 1.0;

const int N = 5;
const float LOOP = 3.0; // PI Godot shader dilinde yerleşik (yeniden tanımlamak derlemeyi kırar)
const float BACK_SEP = 0.4887; // 28 derece
const vec3 CREAM = vec3(1.0, 0.980, 0.941);
const vec3 RB[6] = vec3[6](
	vec3(0.941, 0.416, 0.353), vec3(0.969, 0.635, 0.290), vec3(0.957, 0.847, 0.353),
	vec3(0.525, 0.824, 0.431), vec3(0.384, 0.698, 0.925), vec3(0.659, 0.478, 0.902));

float h01(float a, float b, float c) {
	return fract(sin(a * 12.9898 + b * 78.233 + c * 37.719 + seed * 4.581) * 43758.5453);
}

float q8(float a) {
	return floor(clamp(a, 0.0, 1.0) * 8.0 + 0.5) / 8.0;
}

float sm01(float x) {
	x = clamp(x, 0.0, 1.0);
	return x * x * (3.0 - 2.0 * x);
}

float angdiff(float a, float b) {
	return abs(mod(a - b + PI, 2.0 * PI) - PI);
}

vec4 over(vec4 dst, vec3 c, float a) {
	return vec4(c * a, a) + dst * (1.0 - a);
}

void fragment() {
	vec2 p = floor(UV * size) + 0.5 - size * 0.5;
	vec4 acc = vec4(0.0);
	float spacing = 2.0 * PI / float(N);
	// ---- ışık konileri
	for (int i = 0; i < N; i++) {
		float fi = float(i);
		float cyc = h01(fi, 1.0, 0.0) < 0.25 ? 2.0 : (h01(fi, 1.0, 0.0) < 0.75 ? 3.0 : 4.0); // döngüde kaç nefes
		float ph = fi / float(N) + (h01(fi, 2.0, 0.0) - 0.5) * 0.16;
		float x = cyc * t / LOOP + ph;
		float k = floor(x);
		float u = x - k;
		float ang = back_ang + (fi + 0.5) * spacing + (h01(fi, k, 3.0) - 0.5) * 0.9 * spacing + 0.06 * (u - 0.5);
		float lmax = 48.0 + 16.0 * h01(fi, k, 7.0);
		float grow = pow(sin(PI * u), 0.85);
		float L = 6.0 + (lmax - 6.0) * grow;
		float vis = sm01((angdiff(ang, back_ang) - BACK_SEP * 0.5) / BACK_SEP) * sm01(grow / 0.25);
		if (vis <= 0.0) {
			continue;
		}
		vec2 dir = vec2(cos(ang), sin(ang));
		float s = dot(p, dir) - 4.0; // koni vurulandan 4 px dışarıda başlar
		float d = floor(dir.x * p.y - dir.y * p.x + 0.5);
		float len = L - 4.0;
		if (s < 0.0 || s > len) {
			continue;
		}
		float f = clamp(s / max(1.0, len), 0.0, 1.0);
		float fade = pow(clamp((1.0 - f) / 0.7, 0.0, 1.0), 1.3);
		float hw = 1.0 + 5.0 * f;
		float ad = abs(d);
		if (ad > hw + 0.6) {
			continue;
		}
		float uu = clamp(d / max(hw, 0.6), -0.999, 0.999);
		int kk = int(clamp(floor((uu + 1.0) * 0.5 * 6.0), 0.0, 5.0));
		bool core = ad < 0.5;
		vec3 c = core ? CREAM : mix(RB[kk], CREAM, 0.4);
		float edge = clamp((hw + 0.6 - ad) / 1.2, 0.0, 1.0);
		float a = q8((core ? 0.75 : 0.5) * edge * fade * vis);
		acc = over(acc, c, a);
	}
	// ---- merkez ışık lekesi (5 x 4, radyal söner)
	float rr = length(p / vec2(5.0, 4.0));
	if (rr <= 1.0) {
		acc = over(acc, CREAM, q8(0.6 * (1.0 - rr * rr)));
	}
	// ---- D'nin dönen yıldızı: 8 kol (uzun/kısa), ilk pikseller krem, sönüş uca ertelenir
	for (int i = 0; i < 8; i++) {
		float fi = float(i);
		float an = radians(fi * 45.0) + t * 0.7;
		vec2 dir = vec2(cos(an), sin(an));
		float s = dot(p, dir) - 3.0;
		float dd = abs(dir.x * p.y - dir.y * p.x);
		bool long_arm = (i % 2) == 0;
		float ln = (long_arm ? 15.0 : 8.0) + 3.5 * sin(t * 6.0 + fi * 1.7);
		if (dd > 0.5 || s < -0.5 || s > ln) {
			continue;
		}
		float j = max(0.0, floor(s + 0.5));
		int ci = (i + int(floor(t * 3.0))) % 6;
		vec3 c = j < (long_arm ? 5.0 : 3.0) ? CREAM : (long_arm ? mix(RB[ci], CREAM, 0.5) : RB[ci]);
		acc = over(acc, c, q8((1.0 - pow(j / ln, 2.0)) * 0.9));
	}
	// ---- merkez artı
	if ((abs(p.x) < 2.5 && abs(p.y) < 0.5) || (abs(p.y) < 2.5 && abs(p.x) < 0.5)) {
		acc = over(acc, CREAM, 1.0);
	}
	acc *= alpha;
	COLOR = acc.a > 0.001 ? vec4(acc.rgb / acc.a, acc.a) : vec4(0.0);
}
