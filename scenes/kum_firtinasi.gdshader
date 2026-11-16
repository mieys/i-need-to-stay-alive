shader_type canvas_item;
render_mode unshaded;

// ALTIN KUMLAR KUM FIRTINASI (madde 718, kullanıcı onayı "Yeni 2 - kum yılanları", prototip tools/proto_20261115/kum_firtinasi/).
// Tam ekran, DÜNYAYA YAPIŞIK (cam_origin / world_per_px her karede weather_sandstorm.gd'den): ekran rengi kuma çekilir + düz toz örtüsü
// + rüzgar yönünde hızlı kum çizgileri + yere yakın kıvrılarak akan kum yılanları. Dither / benek YOK: düz alfa bantları (3 kademe).
// amount (0..1) = fırtına şiddeti (atmosphere.gd sand_intensity) - her öğe onunla ölçeklenir. Katman gün-gece geçişinden ÖNCE çizilir
// (main.gd): gece karartması kumu da karartır.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 cam_origin = vec2(0.0);
uniform float world_per_px = 0.5;
uniform float t = 0.0;
uniform float amount = 0.0;
uniform float slope = 0.16;          // rüzgar eğimi (y / x)
uniform float wind_sign = 1.0;       // +1 sağa, -1 sola

uniform float grade_amt = 0.85;
uniform vec3 sand_mul = vec3(1.0, 0.82, 0.6);
uniform vec3 sand_lift = vec3(0.07, 0.045, 0.0);
uniform float desat = 0.3;
uniform float veil_amt = 0.14;
uniform vec3 veil_col = vec3(0.87, 0.71, 0.48);

uniform float streak_amt = 0.6;
uniform float streak_density = 0.26;
uniform vec3 streak_col = vec3(0.99, 0.90, 0.70);

uniform float snake_amt = 0.8;
uniform float snake_spacing = 13.0;
uniform float snake_amp = 5.0;
uniform float snake_speed = 150.0;
uniform vec3 snake_col = vec3(0.95, 0.83, 0.60);

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
	// sanat pikseli ızgarası: 1 dünya birimi
	vec2 w = floor(cam_origin + FRAGCOORD.xy * world_per_px);
	float u = w.x * wind_sign;
	float v = w.y - floor(w.x * slope);

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(col, vec3(lum), desat) * sand_mul + sand_lift;
	col = mix(col, g, grade_amt * amount);
	col = mix(col, veil_col, veil_amt * amount);

	// kum yılanları: her şerit kendi dalga boyu / fazıyla kıvrılır, şerit boyunca parçalı (3 düz bant)
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
			col = mix(col, snake_col, a * snake_amt * amount);
			break;
		}
	}

	// kum çizgileri: 1 birim kalın, 3 birimlik şeritler, baş parlak kuyruk soluk
	if (mod(v, 3.0) < 1.0) {
		int lane = int(floor(v / 3.0));
		float hl = h2(ivec2(lane, 7));
		float period = mix(130.0, 340.0, h2(ivec2(lane, 19)));
		float speed = mix(200.0, 330.0, hl);
		float len = mix(7.0, 22.0, h2(ivec2(lane, 31)));
		float x = u - t * speed + hl * 997.0;
		float seg = floor(x / period);
		float f = x - seg * period;
		if (h2(ivec2(lane, int(seg) + 4096)) < streak_density && f < len) {
			float k = f / len;
			float a = k > 0.62 ? 1.0 : (k > 0.28 ? 0.6 : 0.3);
			col = mix(col, streak_col, a * streak_amt * amount);
		}
	}
	COLOR = vec4(col, 1.0);
}
