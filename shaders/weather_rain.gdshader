shader_type canvas_item;
render_mode world_vertex_coords;

// Yağmur (scripts/weather_rain.gd) - GPU'da animasyon: damla yüksekliği, sıçrama ve halka konumları kareden kareye CPU'da değil burada `clock` ile hesaplanır.
// Üç MultiMesh bu shader'ı `kind` ile paylaşır (0 damla çizgisi + baş noktası, 1 iki sıçrama noktası, 2 sekiz halka noktası).
// Örnek (instance) dönüşümünün ORİJİNİ = damlanın düşeceği yer noktası (dünya, MODEL_MATRIX[3]); `INSTANCE_CUSTOM` = kind'a göre parametreler.
// Mesh köşe UV.x = ilkel etiketi (köşe rengi sRGB<->doğrusal dönüşümüne girebilir, UV girmez). Çizim eski _draw ile aynı: çizgi 1 birim kalınlığında dörtgen, noktalar 1x1 birim, dünya pikseline (floor) oturur.
// world_vertex_coords: VERTEX dünya uzayında gelir ve dünya uzayında çıkar (bkz. particle_trail.gdshader).

uniform int kind = 0;
uniform float clock = 0.0;
uniform float slant = 0.2; // eğim x rüzgar yönü (yatay bileşen; yön = normalize(slant, 1))
uniform vec4 drop_color = vec4(0.74, 0.84, 1.0, 0.5);
uniform vec4 head_color = vec4(0.86, 0.93, 1.0, 0.7);
uniform vec4 splash_color = vec4(0.82, 0.9, 1.0, 0.75);
uniform vec4 ripple_color = vec4(0.8, 0.9, 1.0, 0.4);

const float SPLASH_LIFE = 0.22;
const float SPLASH_GRAVITY = 260.0;
const float RIPPLE_LIFE = 0.38;
const float RIPPLE_MAX_RADIUS = 4.5;
const float TAU_ = 6.28318530718;

float hash11(float n) {
	return fract(sin(n * 12.9898 + 78.233) * 43758.5453);
}

void vertex() {
	vec2 at = MODEL_MATRIX[3].xy; // örnek orijini = yer noktası (dünya)
	vec2 local = VERTEX - at; // mesh köşesi (birim dörtgen)
	vec2 world = at;
	vec4 col = vec4(0.0);
	if (kind == 0) {
		// custom: x = hız, y = çizgi boyu, z = t0'daki yükseklik, w = t0
		float h = max(INSTANCE_CUSTOM.z - INSTANCE_CUSTOM.x * (clock - INSTANCE_CUSTOM.w), 0.0);
		vec2 tip = floor(at + vec2(-slant * h, -h));
		if (UV.x < 0.5) {
			// çizgi dörtgeni: local.x 0 = kuyruk, 1 = uç; local.y -1/+1 = kalınlık yönü
			vec2 dir = normalize(vec2(slant, 1.0));
			vec2 tipc = tip + vec2(0.5);
			vec2 p = mix(tipc - dir * INSTANCE_CUSTOM.y, tipc, local.x);
			world = p + vec2(-dir.y, dir.x) * 0.5 * local.y;
			col = drop_color;
		} else {
			world = tip + local; // baş noktası 1x1
			col = head_color;
		}
	} else if (kind == 1) {
		// custom: x = doğuş zamanı, y = tohum
		float age = clock - INSTANCE_CUSTOM.x;
		if (age >= 0.0 && age < SPLASH_LIFE) {
			float side = UV.x < 0.5 ? -1.0 : 1.0;
			float vx = side * mix(18.0, 38.0, hash11(INSTANCE_CUSTOM.y + side * 7.0));
			float vy = -mix(32.0, 52.0, hash11(INSTANCE_CUSTOM.y * 1.7 + 3.0 + side));
			vec2 pos = at + vec2(side * 0.5, -0.5) + vec2(vx, vy) * age + vec2(0.0, 0.5 * SPLASH_GRAVITY * age * age);
			world = floor(pos) + local;
			col = vec4(splash_color.rgb, splash_color.a * (1.0 - age / SPLASH_LIFE));
		}
	} else {
		// custom: x = doğuş zamanı
		float age = clock - INSTANCE_CUSTOM.x;
		if (age >= 0.0 && age < RIPPLE_LIFE) {
			float k = age / RIPPLE_LIFE;
			float r = mix(1.0, RIPPLE_MAX_RADIUS, k);
			float ang = floor(UV.x * 8.0 + 0.5) * TAU_ / 8.0;
			world = floor(at + vec2(cos(ang) * r, sin(ang) * r * 0.45)) + local;
			col = vec4(ripple_color.rgb, ripple_color.a * (1.0 - k));
		}
	}
	VERTEX = world;
	COLOR = col;
}
