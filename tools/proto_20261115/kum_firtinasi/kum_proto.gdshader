shader_type canvas_item;
render_mode unshaded;

// KUM FIRTINASI prototipi (2026-11-15, oyuna bağlı DEĞİL). Tam ekran, dünyaya yapışık (cam_origin): ekran renginin kum
// tonuna çekilmesi + rüzgar yönünde uzanan toz kümeleri + hızlı kum çizgileri. Dither / gürültü beneği YOK: toz kümeleri
// 4 düz alfa bandı, çizgiler 1 dünya birimi kalınlıkta (2 ekran px) ve 3 düz alfa bandı.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 cam_origin = vec2(0.0);
uniform float world_per_px = 0.5;
uniform float t = 0.0;
uniform float slope = 0.16;          // rüzgar eğimi (y / x)
uniform float wind_sign = 1.0;       // +1 sağa, -1 sola

uniform float grade_amt = 0.0;
uniform vec3 sand_mul = vec3(1.0, 0.86, 0.66);
uniform vec3 sand_lift = vec3(0.07, 0.045, 0.0);
uniform float desat = 0.3;

uniform float veil_amt = 0.0;        // her yerde düz toz örtüsü
uniform float haze_amt = 0.0;        // toz kümeleri
uniform float haze_scale = 60.0;
uniform float haze_stretch = 4.0;
uniform float haze_speed = 150.0;
uniform float wall_amt = 0.0;         // B: büyük, yavaş toz duvarı
uniform float wall_scale = 220.0;
uniform float haze_lo = 0.45;
uniform float haze_hi = 0.8;
uniform vec3 haze_col = vec3(0.87, 0.71, 0.48);
uniform vec3 haze_core = vec3(0.93, 0.80, 0.58);
uniform float edge_amt = 0.0;        // ekran kenarına doğru küme yoğunluğu artar (görüş daralması hissi)

// YENİ toz (2026-11-15 tur 2, kullanıcı: eski kümeler "bulut gibi"): yuvarlak leke YOK.
// 1) lifli akıntı: rüzgar boyunca çok uzun, çok ince, dalgalı lifler; büyük bir rüzgar zarfı yoğunluğu taşır.
uniform float fiber_amt = 0.0;
uniform float fiber_len = 160.0;
uniform float fiber_thick = 7.0;
uniform float fiber_warp = 26.0;
uniform float fiber_speed = 170.0;
uniform float fiber_env_scale = 210.0;
uniform vec3 dust_col = vec3(0.92, 0.78, 0.55);
uniform vec3 dust_hi = vec3(0.98, 0.89, 0.70);
// 2) kum yılanları: yere yakın, kıvrılarak akan ince kum dereleri.
uniform float snake_amt = 0.0;
uniform float snake_spacing = 13.0;
uniform float snake_amp = 5.0;
uniform float snake_speed = 150.0;
uniform vec3 snake_col = vec3(0.95, 0.83, 0.60);

uniform float streak_amt = 0.0;
uniform float streak_density = 0.3;
uniform float streak_len_min = 7.0;
uniform float streak_len_max = 22.0;
uniform vec3 streak_col = vec3(0.99, 0.90, 0.70);

uint hu(uint x) {
	x ^= x >> 16u; x *= 0x7feb352du; x ^= x >> 15u; x *= 0x846ca68bu; x ^= x >> 16u;
	return x;
}
float h2(ivec2 p) {
	return float(hu(uint(p.x) * 0x9E3779B1u ^ hu(uint(p.y) + 0x632BE5ABu))) / 4294967295.0;
}
float vnoise(vec2 p) {
	ivec2 i = ivec2(floor(p));
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h2(i), b = h2(i + ivec2(1, 0)), c = h2(i + ivec2(0, 1)), d = h2(i + ivec2(1, 1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	// sanat pikseli ızgarası: 1 dünya birimi = 2 ekran px
	vec2 w = floor(cam_origin + FRAGCOORD.xy * world_per_px);
	float u = w.x * wind_sign;
	float sh = floor(w.x * slope);
	float v = w.y - sh;

	// 1) renk: kuma doğru
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(col, vec3(lum), desat) * sand_mul + sand_lift;
	col = mix(col, g, grade_amt);

	// 2) toz örtüsü + rüzgar yönünde uzayan, hızlı akan toz şeritleri (3 düz bant) + B için büyük yavaş toz duvarı
	vec2 c = SCREEN_UV - 0.5;
	float er = length(c * vec2(1.0, 0.75)) * 2.0;
	col = mix(col, haze_col, veil_amt);
	if (wall_amt > 0.0) {
		vec2 qw = vec2((u - t * haze_speed * 0.45) / (wall_scale * 2.6), v / wall_scale);
		float nw = vnoise(qw) + edge_amt * smoothstep(0.55, 1.3, er);
		float bw = floor(clamp((nw - 0.45) / 0.4, 0.0, 1.0) * 3.0) / 3.0;
		col = mix(col, haze_col, bw * wall_amt);
	}
	if (haze_amt > 0.0) {
		vec2 q = vec2((u - t * haze_speed) / (haze_scale * haze_stretch), v / haze_scale);
		float n = vnoise(q) * 0.65 + vnoise(q * 2.0 + vec2(13.7, 5.1)) * 0.35;
		float d = clamp((n - haze_lo) / (haze_hi - haze_lo), 0.0, 1.0);
		float band = floor(d * 3.0) / 3.0;
		vec3 hc = mix(haze_col, haze_core, step(0.99, band));
		col = mix(col, hc, band * haze_amt);
	}

	// 2b) lifli toz akıntısı
	if (fiber_amt > 0.0) {
		float uu = u - t * fiber_speed;
		float vw = v + fiber_warp * (vnoise(vec2(uu / 170.0, v / 95.0 + 3.1)) - 0.5);
		float f = vnoise(vec2(uu / fiber_len, vw / fiber_thick)) * 0.6
			+ vnoise(vec2(uu / (fiber_len * 0.55) + 7.3, vw / (fiber_thick * 0.65) + 1.7)) * 0.4;
		float env = vnoise(vec2((u - t * fiber_speed * 0.8) / (fiber_env_scale * 2.8), v / fiber_env_scale));
		env = smoothstep(0.3, 0.75, env + edge_amt * smoothstep(0.55, 1.3, er));
		float dd = clamp((f * (0.6 + 0.4 * env) - 0.38) / 0.28, 0.0, 1.0);
		float fb = floor(dd * 3.0) / 3.0;
		vec3 fc = mix(dust_col, dust_hi, step(0.99, fb));
		col = mix(col, fc, fb * fiber_amt);
	}
	// 2c) kum yılanları
	if (snake_amt > 0.0) {
		float uu = u - t * snake_speed;
		int l0 = int(floor(v / snake_spacing));
		for (int k = -1; k <= 1; k++) {
			int ln = l0 + k;
			float hl = h2(ivec2(ln, 53));
			float center = floor((float(ln) + 0.5) * snake_spacing + snake_amp * sin(uu / mix(38.0, 70.0, hl) + hl * 6.283));
			float dv = v - center;
			if (dv >= 0.0 && dv < 1.0 + step(0.6, hl)) {
				float seg = vnoise(vec2(uu / mix(70.0, 120.0, hl) + hl * 17.0, float(ln) * 0.37));
				float a = floor(clamp((seg - 0.42) / 0.33, 0.0, 1.0) * 3.0) / 3.0;
				col = mix(col, snake_col, a * snake_amt);
				break;
			}
		}
	}

	// 3) kum çizgileri (1 birim kalın, kademeli eğim, baş parlak kuyruk soluk)
	if (streak_amt > 0.0 && mod(v, 3.0) < 1.0) {
		int lane = int(floor(v / 3.0));
		float hl = h2(ivec2(lane, 7));
		float hl2 = h2(ivec2(lane, 19));
		float hl3 = h2(ivec2(lane, 31));
		float period = mix(130.0, 340.0, hl2);
		float speed = mix(200.0, 330.0, hl);
		float len = mix(streak_len_min, streak_len_max, hl3);
		float x = u - t * speed + hl * 997.0;
		float seg = floor(x / period);
		float hs = h2(ivec2(lane, int(seg) + 4096));
		float f = x - seg * period;
		if (hs < streak_density && f < len) {
			float k = f / len;
			float a = k > 0.62 ? 1.0 : (k > 0.28 ? 0.6 : 0.3);
			col = mix(col, streak_col, a * streak_amt);
		}
	}
	COLOR = vec4(col, 1.0);
}
