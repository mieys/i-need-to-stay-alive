shader_type canvas_item;
render_mode world_vertex_coords;

// Saldırı Totemi ateş topunun UÇUŞU (scripts/fx_totem_fire_bolt.gd, madde 215). Eskiden her karede ~150 draw_rect + GDScript;
// şimdi tek MultiMesh çizimi: 29 örnek (14 kuyruk topağı, 4 baş katmanı, 3 alev dili, 3 yörünge kor, 5 kıvılcım), konumların
// hepsi uçuş ilerlemesi `u` ve `el` (geçen süre) uniform'larından burada hesaplanır. Çizim PixelDraw.disc/px ile AYNI ızgarada:
// merkez sanat pikseline oturur, daire satır satır (yarı genişlik sqrt(rt^2 - iy^2)), tek piksel = 1 texel'lik kare.
// INSTANCE_CUSTOM = (tür, k, 0, 0): 0 kuyruk k=1..14, 1 baş katmanı k=0..3, 2 dil k=0..2, 3 yörünge kor k=0..2, 4 kıvılcım k=0..4.

uniform vec2 start_pos = vec2(0.0);
uniform vec2 end_pos = vec2(100.0, 0.0);
uniform float u = 0.0;
uniform float el = 0.0;
uniform int seed = 0;
uniform int flick = 0;
uniform float texel = 1.212;

varying flat vec2 v_c;
varying flat float v_rt;
varying flat vec4 v_col;
varying vec2 v_pos;

vec3 fire(float t) {
	const vec3 S0 = vec3(1.0, 0.96, 0.7);
	const vec3 S1 = vec3(1.0, 0.78, 0.22);
	const vec3 S2 = vec3(1.0, 0.5, 0.1);
	const vec3 S3 = vec3(0.9, 0.2, 0.06);
	const vec3 S4 = vec3(0.45, 0.08, 0.06);
	float f = clamp(t, 0.0, 1.0) * 4.0;
	if (f < 1.0) return mix(S0, S1, f);
	if (f < 2.0) return mix(S1, S2, f - 1.0);
	if (f < 3.0) return mix(S2, S3, f - 2.0);
	return mix(S3, S4, f - 3.0);
}

float hash01(int n) {
	uint x = uint(n) * 374761393u + 668265263u;
	x = (x ^ (x >> 13u)) * 1274126177u;
	x = x ^ (x >> 16u);
	return float(x & 65535u) / 65535.0;
}

vec2 path(float q) {
	float c = clamp(q, 0.0, 1.0);
	float s = c * c * (3.0 - 2.0 * c);
	return mix(start_pos, end_pos, s);
}

void vertex() {
	int kind = int(INSTANCE_CUSTOM.x + 0.5);
	int k = int(INSTANCE_CUSTOM.y + 0.5);
	float T = texel;
	vec2 dir = end_pos - start_pos;
	dir = (length(dir) < 0.001) ? vec2(1.0, 0.0) : normalize(dir);
	vec2 side = vec2(-dir.y, dir.x);
	vec2 head = path(u);
	vec2 center = head;
	float rt = 0.0;
	vec4 col = vec4(1.0);
	if (kind == 0) {
		float f = float(k) / 14.0;
		vec2 jit = vec2(hash01(seed + k * 31 + flick) - 0.5, hash01(seed + k * 57 + flick * 3) - 0.5) * T * (2.0 + 5.0 * f);
		center = path(u - float(k) * 0.028) + jit;
		col = vec4(fire(0.28 + 0.62 * f), 1.0 - f * 0.75);
		float r = max(T * 1.2, (1.0 - f) * 4.6 * T);
		rt = float(int(r / T));
	} else if (kind == 1) {
		float pulse = 0.5 + 0.5 * sin(el * 40.0);
		float r = (k == 0) ? 5.4 * T + pulse * T : ((k == 1) ? 4.3 * T : ((k == 2) ? 3.0 * T : 1.6 * T));
		float ft = (k == 0) ? 0.66 : ((k == 1) ? 0.44 : ((k == 2) ? 0.24 : 0.02));
		col = vec4(fire(ft), 1.0);
		rt = float(int(r / T));
	} else if (kind == 2) {
		if (k == 2) {
			center = head + dir * T * 6.5;
			col = vec4(fire(0.1), 1.0);
		} else {
			float s2 = (k == 0) ? -1.0 : 1.0;
			center = head + dir * T * 5.0 + side * s2 * T * 2.0;
			col = vec4(fire(0.3), 1.0);
		}
		rt = -1.0;
	} else if (kind == 3) {
		float a = el * 22.0 + float(k) * 6.28318530718 / 3.0;
		center = head + vec2(cos(a), sin(a)) * 7.0 * T;
		col = vec4(fire(0.05 + 0.2 * float(k)), 1.0);
		rt = -1.0;
	} else {
		int sj = seed + k * 101 + flick / 2;
		vec2 back = path(u - (0.03 + 0.12 * hash01(sj)));
		vec2 off = vec2(hash01(sj + 7) - 0.5, hash01(sj + 13) - 0.5) * 11.0 * T;
		center = back + off;
		col = vec4(fire(0.15 + 0.55 * hash01(sj + 19)), 1.0);
		rt = -1.0;
	}
	center = floor(center / T + 0.5) * T;
	VERTEX = center + VERTEX;
	v_c = center;
	v_rt = rt;
	v_col = col;
	v_pos = VERTEX;
}

void fragment() {
	float T = texel;
	vec2 d = v_pos - v_c;
	if (v_rt < 0.0) {
		if (abs(d.x) > T * 0.5 || abs(d.y) > T * 0.5) discard;
	} else {
		float iy = floor(d.y / T + 0.5);
		float hw = sqrt(max(0.0, v_rt * v_rt - iy * iy));
		if (hw < 0.5 || abs(iy) > v_rt || abs(d.x) > hw * T) discard;
	}
	COLOR = v_col;
}
