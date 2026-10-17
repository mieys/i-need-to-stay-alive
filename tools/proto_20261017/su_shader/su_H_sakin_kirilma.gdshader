shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261017/su_shader/su_ortak.gdshaderinc"

// PROTOTİP H - SAKİN KIRILMA (2. set, 2026-10-17, oyuna bağlı DEĞİL).
// En sade: berrak suyun altındaki dip (çatlak toprak, kayalık kıyı) çok yavaş dalgalanır (satır başına en çok 1 tam piksel yatay
// kayma, uzun dalga boyu, ~14 sn döngü, kıyıda 0) + 3 temiz derinlik tonu + 1 px açık kıyı çizgisi ve koyu temas. Başka öğe yok.
// Ekran dokusu Su katmanından ÖNCE BackBufferCopy ister (bkz. D, su_capture.gd).

uniform sampler2D ekran : hint_screen_texture, filter_nearest;
uniform vec4 sig_renk : source_color = vec4(0.29, 0.54, 0.65, 1.0);
uniform vec4 orta_renk : source_color = vec4(0.247, 0.451, 0.62, 1.0);
uniform vec4 derin_renk : source_color = vec4(0.18, 0.34, 0.53, 1.0);
uniform vec4 cizgi_renk : source_color = vec4(0.70, 0.86, 0.90, 1.0);
uniform float sig_alfa = 0.55;
uniform float orta_alfa = 0.7;
uniform float derin_alfa = 0.82;
uniform float kirilma_hiz = 0.45;

varying vec2 world_pos;
varying float ekran_olcek;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	ekran_olcek = length((CANVAS_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xy);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (!su_mavi_mi(tex.rgb)) {
		COLOR = su_disi(tex);
		COLOR.rgb = harita_renk(COLOR.rgb);
	} else {
		vec2 px = floor(world_pos);
		float t = TIME * kirilma_hiz;
		float d = su_kiyi(px);

		float amp = smoothstep(4.0, 12.0, d);
		float wob = sin(px.y * 0.12 + t) * 0.7 + sin(px.y * 0.045 - t * 0.6) * 0.3;
		vec2 off = vec2(floor(wob * amp + 0.5), 0.0);
		vec3 dip = textureLod(ekran, SCREEN_UV + off * ekran_olcek * SCREEN_PIXEL_SIZE, 0.0).rgb;

		vec3 col = derin_renk.rgb;
		float a = derin_alfa;
		if (d < 6.0) {
			col = sig_renk.rgb;
			a = sig_alfa;
		} else if (d < 16.0) {
			col = orta_renk.rgb;
			a = orta_alfa;
		}
		if (d < 1.0) {
			col = mix(col, cizgi_renk.rgb, 0.55);
			a = 0.8;
		} else if (d < 2.5) {
			col *= 0.85;
			a = max(a, 0.72);
		}
		COLOR = vec4(mix(dip, harita_renk(col), a), tex.a);
	}
}
