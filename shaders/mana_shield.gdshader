shader_type canvas_item;

// MANA KALKANI "B - Mühür" (scripts/mana_shield_fx.gd): sayfalar renk değil TON NUMARASI taşır (R = ton * 36;
// 0 kontur, 1 koyu, 2 orta, 3 açık, 4 parlak, 5 krem, 6 beyaz - bkz. tools/gen_mana_shield_fx.py). Renk kalkan
// türünün paletinden gelir (c0..c6), böylece 4 tür tek sayfayı paylaşır.
// use_progress: yer mührü - merkezden ölçülen açı (önden başlayıp saat yönünde) progress'i aşan pikseller soluk çizilir.

uniform vec4 c0 : source_color = vec4(0.05, 0.09, 0.27, 1.0);
uniform vec4 c1 : source_color = vec4(0.14, 0.27, 0.64, 1.0);
uniform vec4 c2 : source_color = vec4(0.29, 0.53, 0.91, 1.0);
uniform vec4 c3 : source_color = vec4(0.59, 0.8, 1.0, 1.0);
uniform vec4 c4 : source_color = vec4(0.89, 0.96, 1.0, 1.0);
uniform vec4 c5 : source_color = vec4(1.0, 0.98, 0.89, 1.0);
uniform vec4 c6 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool use_progress = false;
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec2 ell_center = vec2(23.0, 11.0);
uniform vec2 ell_radii = vec2(17.0, 6.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

// Canvas fragment()'te COLOR zaten doku x köşe rengi; modulate'i ayrıca uygulamak için köşe rengi taşınır.
varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

vec3 tone_color(int t) {
	if (t <= 0) { return c0.rgb; }
	if (t == 1) { return c1.rgb; }
	if (t == 2) { return c2.rgb; }
	if (t == 3) { return c3.rgb; }
	if (t == 4) { return c4.rgb; }
	if (t == 5) { return c5.rgb; }
	return c6.rgb;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	int t = int(round(tex.r * 255.0 / 36.0));
	vec3 col = tone_color(t);
	float a = tex.a;
	if (use_progress) {
		vec2 px = floor(UV / TEXTURE_PIXEL_SIZE) + 0.5; // doku pikselinin merkezi: kesik kenar piksel ızgarasında kalır
		vec2 d = (px - ell_center) / ell_radii;
		float rel = mod(atan(d.y, d.x) - 1.5707963, 6.2831853);
		if (rel > progress * 6.2831853) {
			col = (t == 0) ? c1.rgb : c3.rgb;
			a = (a < 0.4) ? 0.0 : min(a, 0.32);
		}
	}
	col = mix(col, c5.rgb, flash);
	COLOR = vec4(col, a) * vcol;
}
