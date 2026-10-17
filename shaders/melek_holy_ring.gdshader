shader_type canvas_item;

// Melek R (Kutsal Korku) genişleyen kesikli şok halkaları (scripts/fx_melek_holy.gd, madde 215). Eskiden PixelDraw.ring ile
// her karede ~2000 draw_rect; şimdi tek dörtgen. Sanat pikseli ızgarasında (yerel birim, texel 1,212) iki halka: dıştaki 2 piksel
// kalın (açık altın değil GOLD), içteki 1 piksel (GOLD_LIGHT), ikisi de açı boyunca kesikli ve kayan (yürüyen karınca).

uniform vec2 center = vec2(0.0);
uniform float radius1 = 0.0;
uniform float radius2 = 0.0;
uniform float phase1 = 0.0;
uniform float phase2 = 0.0;
uniform int off1 = 3;
uniform int off2 = 6;
uniform float texel = 1.212;
uniform vec4 col1 : source_color = vec4(1.0, 0.82, 0.22, 1.0);
uniform vec4 col2 : source_color = vec4(1.0, 0.95, 0.6, 1.0);

varying vec2 v_local;

void vertex() {
	v_local = VERTEX;
}

bool on_ring(vec2 cell_pos, float radius, float n, int on_len, int off_len, float phase) {
	vec2 d = cell_pos - center;
	float dd = length(d);
	if (abs(dd - radius) > 0.5 * texel * n) {
		return false;
	}
	float a = atan(d.y, d.x);
	if (a < 0.0) {
		a += 6.28318530718;
	}
	float count = max(8.0, floor(6.28318530718 * radius / (texel * n)));
	float idx = floor(a / 6.28318530718 * count);
	float v = trunc(idx + phase);
	int period = on_len + off_len;
	float m = v - float(period) * trunc(v / float(period));
	return m < float(on_len);
}

void fragment() {
	vec2 cell = floor(v_local / texel + 0.5) * texel;
	vec4 c = vec4(0.0);
	if (radius1 > 0.0 && on_ring(cell, radius1, 2.0, 8, off1, phase1)) {
		c = col1;
	}
	if (radius2 > 0.0 && on_ring(cell, radius2, 1.0, 3, off2, phase2)) {
		c = col2;
	}
	if (c.a < 0.5) {
		discard;
	}
	COLOR = c;
}
