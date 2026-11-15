shader_type canvas_item;

// Shaman E (Kalkan Totemi) KALKAN ŞERİDİ - "Işık Tülü" (madde 567; prototip madde 562 D2 + ızgara G1, kullanıcı seçti).
// Taşın rün merkezinden (p0) hedefin KALKAN BALONCUĞUNUN taşa bakan yüzüne (p1) kavisli, dalgalanarak akan tül + parlak orta çizgi;
// son üçte birde hedefin kalkan rengine döner, değdiği yerde baloncuk yüzeyinde parlak yay.
// PARAZİTSİZ (madde 562 ek 4): her parça kendi DÜNYA ızgara hücresinin (cell = karakter pikseli 0,903) MERKEZİNE göre karar verir ->
// hücre ya tam dolu ya boş, kenarlar tırtıksız, dalga tam piksel adımlarla akar. Düğüm top_level (0,0)'da: yerel köşe = dünya.

uniform float cell = 0.903;
uniform vec2 p0;
uniform vec2 p1;
uniform float arc_h = 10.0;      // kavis yüksekliği (dünya)
uniform float wave_len = 34.0;   // dalga boyu (dünya)
uniform float wave_amp = 1.4;    // dalga genliği (dünya)
uniform float wave_speed = 1.0;  // saniyede dalga
uniform float time_s = 0.0;
uniform float half_outer = 2.5;  // hücre: dış tül
uniform float half_inner = 1.5;  // hücre: iç tül
uniform vec4 col_outer_a : source_color = vec4(0.290, 0.659, 1.0, 1.0);  // taş ucu (E mavisi)
uniform vec4 col_inner_a : source_color = vec4(0.651, 0.847, 1.0, 1.0);
uniform vec4 col_hot_a : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 col_outer_b : source_color = vec4(0.290, 0.659, 1.0, 1.0); // kalkan ucu (baloncuk rengi)
uniform vec4 col_inner_b : source_color = vec4(0.651, 0.847, 1.0, 1.0);
uniform vec4 col_hot_b : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 bub_c;
uniform float bub_r = 0.0;       // 0 = baloncuk yok (yay çizilmez)
uniform float th0 = 0.0;         // baloncuk merkezinden taşa açı
uniform float span = 0.733;      // yay yarı açısı (42 derece)
uniform float alpha_mult = 1.0;  // bağ belirme / sönme

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec2 center_at(float u, float len) {
	vec2 d = p1 - p0;
	vec2 p = p0 + d * u - vec2(0.0, arc_h * 4.0 * u * (1.0 - u));
	vec2 t = normalize(vec2(d.x, d.y - arc_h * (4.0 - 8.0 * u)) + vec2(1e-5, 0.0));
	vec2 n = vec2(-t.y, t.x);
	float ph = u * len / wave_len * TAU - time_s * TAU * wave_speed;
	return p + n * sin(ph) * wave_amp * sin(PI * u);
}

void fragment() {
	vec2 cc = (floor(world_pos / cell) + 0.5) * cell;
	float len = length(p1 - p0);
	const int N = 40;
	float best = 1e9;
	float bu = 0.0;
	vec2 a = center_at(0.0, len);
	for (int i = 1; i <= N; i++) {
		vec2 b = center_at(float(i) / float(N), len);
		vec2 ab = b - a;
		float tt = clamp(dot(cc - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
		float dd = length(cc - (a + ab * tt));
		if (dd < best) {
			best = dd;
			bu = (float(i - 1) + tt) / float(N);
		}
		a = b;
	}
	float d = best / cell;
	float taper = pow(max(sin(PI * bu), 0.0), 0.5);
	float fade = smoothstep(0.0, 0.08, bu);
	float k = smoothstep(0.6, 1.0, bu);
	vec4 col = vec4(0.0);
	if (d <= max(0.5, half_outer * taper)) {
		col = vec4(mix(col_outer_a.rgb, col_outer_b.rgb, k), 0.18 * fade);
	}
	if (d <= max(0.5, half_inner * taper)) {
		col = vec4(mix(col_inner_a.rgb, col_inner_b.rgb, k), 0.38 * fade);
	}
	if (d <= 0.5 && taper > 0.12) {
		float ph = bu * len / wave_len * TAU - time_s * TAU * wave_speed;
		float bright = 0.5 + 0.5 * cos(ph);
		vec3 c_line = bright > 0.8 ? mix(col_hot_a.rgb, col_hot_b.rgb, k) : mix(col_inner_a.rgb, col_inner_b.rgb, k);
		col = vec4(c_line, clamp((0.7 + 0.3 * bright) * fade, 0.0, 1.0));
	}
	if (bub_r > 0.0) {
		// baloncuk yüzeyinde yay: dalga tepesi vardıkça parlar
		float glow = 0.6 + 0.4 * (0.5 + 0.5 * cos(len / wave_len * TAU - time_s * TAU * wave_speed));
		vec2 rel = cc - bub_c;
		float rr = length(rel) / cell;
		float rg = bub_r / cell;
		float off = abs(mod(atan(rel.y, rel.x) - th0 + PI, TAU) - PI) / span;
		if (abs(rr - (rg - 1.0)) <= 0.5 && off < 0.6) {
			float a_in = 0.45 * glow * (1.0 - off / 0.6);
			if (a_in > col.a) {
				col = vec4(col_outer_b.rgb, a_in);
			}
		}
		if (abs(rr - rg) <= 0.5 && off <= 1.0) {
			float a_rim = clamp(1.2 * glow * pow(max(0.0, 1.0 - off), 1.3), 0.0, 1.0);
			if (a_rim > col.a) {
				col = vec4(off < 0.3 ? col_hot_b.rgb : col_inner_b.rgb, a_rim);
			}
		}
	}
	COLOR = vec4(col.rgb, col.a * alpha_mult);
}
