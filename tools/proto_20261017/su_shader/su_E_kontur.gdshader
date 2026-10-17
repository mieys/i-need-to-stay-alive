shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261017/su_shader/su_ortak.gdshaderinc"

// PROTOTİP E - KONTUR BANTLARI (2. set, 2026-10-17, oyuna bağlı DEĞİL).
// Kıyıya paralel 3 temiz renk bandı (sığ açık turkuaz / orta / derin), bant sınırlarında 1 px açık kontur çizgisi; çizgiler
// yavaşça "nefes alır" (kıyı boyunca farklı fazda +/-1 px gelip gider, ~9 sn). Başka hareket yok, nokta (dither) yok.

uniform vec4 sig_renk : source_color = vec4(0.33, 0.60, 0.66, 1.0);
uniform vec4 orta_renk : source_color = vec4(0.247, 0.451, 0.62, 1.0);
uniform vec4 derin_renk : source_color = vec4(0.19, 0.35, 0.55, 1.0);
uniform float sig_alfa = 0.6;
uniform float orta_alfa = 0.76;
uniform float derin_alfa = 0.86;
uniform vec4 cizgi_renk : source_color = vec4(0.72, 0.88, 0.92, 1.0);
uniform float bant1 = 4.5;
uniform float bant2 = 12.0;
uniform float nefes_px = 1.0;
uniform float nefes_hiz = 0.7;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (!su_mavi_mi(tex.rgb)) {
		COLOR = su_disi(tex);
		COLOR.rgb = harita_renk(COLOR.rgb);
	} else {
		vec2 px = floor(world_pos);
		float t = TIME;
		float d = su_kiyi(px);
		float faz = su_noise(px * 0.03) * 6.2831;
		float b1 = bant1 + nefes_px * sin(t * nefes_hiz + faz);
		float b2 = bant2 + nefes_px * 1.3 * sin(t * nefes_hiz * 0.8 + faz + 2.0);

		vec3 col = derin_renk.rgb;
		float a = derin_alfa;
		if (d < b1) {
			col = sig_renk.rgb;
			a = sig_alfa;
		} else if (d < b2) {
			col = orta_renk.rgb;
			a = orta_alfa;
		}
		if (d < 1.0) {
			col = mix(col, cizgi_renk.rgb, 0.6);
			a = 0.8;
		} else if (d >= b1 && d < b1 + 1.0) {
			col = mix(col, cizgi_renk.rgb, 0.7);
			a = 0.85;
		} else if (d >= b2 && d < b2 + 1.0) {
			col = mix(col, cizgi_renk.rgb, 0.4);
			a = max(a, 0.84);
		}
		COLOR = vec4(harita_renk(col), tex.a * a);
	}
}
