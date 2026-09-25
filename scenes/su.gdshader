shader_type canvas_item;

// "Su" katmanının suyu (harita_baked.tscn -> Su/Su TileMapLayer).
//
// YENİDEN YAZIM (kullanıcı isteği 2026-09-25: "su tilelayerına eklediğim shaderı oyunla daha uyumlu olacak şekilde
// güncelle, sudaki efekt pek hoş durmuyor"). Eski sürümün iki kök sorunu vardı:
//   1) Deseni karonun ATLAS UV'sinden hesaplıyordu - her su karosu aynı dalga desenini tekrar ediyor, desen dünyaya
//      değil doku atlasına bağlı olduğu için karo sınırlarında kesiliyor/kayıyordu.
//   2) Dalgalar smoothstep'li yumuşak kenarlı (anti-aliased) kıvrık çizgilerdi - piksel sanat haritada "bulanık" ve
//      yabancı duruyordu.
// Yeni sürüm dünya koordinatında, harita karolarının piksel ızgarasında (1 dünya birimi = 1 karo pikseli) çalışır:
//   - Işık bantları: yatayda uzamış, çok yavaş kayan gürültü 4 kademeye nicemlenip (yumuşak geçiş yok, piksel dili)
//     suyun parlaklığını çok hafifçe (+/- wave_strength) değiştirir - su "kıpırdıyor" hissi.
//   - Pırıltılar: seyrek, 2-4 piksellik kısa YATAY çizgiler (üstten bakışta suyun güneşi yansıtması) - uzayıp kısalarak
//     belirip kaybolur, akıntıyla yavaşça sürüklenir. Uçları biraz sönük, ortası parlak.
// water_tint / water_alpha adları ve anlamı eskisiyle AYNI (sahnedeki ayarlı değerler aynen geçerli).

uniform vec4 water_tint : source_color = vec4(0.18, 0.45, 0.63, 1.0);
uniform float water_alpha : hint_range(0.5, 1.0) = 0.94;
uniform float tint_amount : hint_range(0.0, 0.5) = 0.12;

// Işık bantları
uniform float wave_strength : hint_range(0.0, 0.2) = 0.045;
uniform float wave_scale : hint_range(0.005, 0.2) = 0.03;

// Pırıltılar (ripple_color adı eskisinden - sahnedeki ayarlı renk pırıltı rengi olarak kullanılır)
uniform vec4 ripple_color : source_color = vec4(0.64, 0.82, 0.95, 0.8);
uniform float sparkle_strength : hint_range(0.0, 1.0) = 0.6;
uniform float sparkle_density : hint_range(0.0, 1.0) = 0.16;
uniform vec2 sparkle_cell = vec2(14.0, 9.0);

// Genel animasyon hızı ve akıntı (piksel/sn)
uniform float anim_speed : hint_range(0.0, 3.0) = 1.0;
uniform vec2 current = vec2(2.0, 0.4);

// Efekt pikselinin dünya birimi (harita karoları 1:1 -> 1).
uniform float pixel_size = 1.0;

varying vec2 world_pos;

void vertex() {
	// TileMapLayer karolarını yerel koordinatta çizer; MODEL_MATRIX dünyaya çevirir - desen haritaya yapışık.
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 col = mix(tex.rgb, water_tint.rgb, tint_amount);

	vec2 px = floor(world_pos / pixel_size);
	float t = TIME * anim_speed;

	// --- Işık bantları: yatayda uzun (x ölçeği y'nin yarısı), iki oktav, 4 kademe ---
	vec2 wp = px * vec2(wave_scale, wave_scale * 2.0) + vec2(t * 0.06, t * 0.025);
	float n = value_noise(wp) * 0.65 + value_noise(wp * 2.3 + vec2(7.1, 3.7) - vec2(t * 0.04, 0.0)) * 0.35;
	float band = floor(clamp(n, 0.0, 0.999) * 4.0) / 3.0 - 0.5;
	col *= 1.0 + band * 2.0 * wave_strength;

	// --- Pırıltılar ---
	vec2 q = px - floor(current * t);
	vec2 cell = floor(q / sparkle_cell);
	vec2 in_cell = q - cell * sparkle_cell;
	float r = hash21(cell);
	if (r < sparkle_density) {
		float r2 = hash21(cell + vec2(17.3, 4.1));
		float r3 = hash21(cell + vec2(3.1, 29.7));
		float max_len = 2.0 + floor(r2 * 3.0); // 2-4 piksel
		vec2 origin = floor(vec2(r3 * (sparkle_cell.x - max_len), r2 * (sparkle_cell.y - 1.0)));
		// Her hücre kendi fazında: döngünün %40'ında görünür, ortasında en uzun.
		float phase = fract(t * 0.32 + r * 11.0 + r3 * 3.0);
		if (phase < 0.4) {
			float grow = 1.0 - abs(phase / 0.4 * 2.0 - 1.0);
			float len = max(1.0, floor(max_len * grow + 0.5));
			float dx = in_cell.x - origin.x - floor((max_len - len) * 0.5);
			if (in_cell.y == origin.y && dx >= 0.0 && dx < len) {
				float edge = (len > 2.0 && (dx < 0.5 || dx > len - 1.5)) ? 0.55 : 1.0;
				col = mix(col, ripple_color.rgb, clamp(sparkle_strength * edge * ripple_color.a * 1.25, 0.0, 1.0));
			}
		}
	}

	COLOR = vec4(col, tex.a * water_alpha);
}
