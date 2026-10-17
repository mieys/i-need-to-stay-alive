shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261017/su_shader/su_ortak.gdshaderinc"

// PROTOTİP A - KIYI KÖPÜĞÜ (2026-10-17, oyuna bağlı DEĞİL).
// Derinlik: kıyıda açık turkuaz + saydam (dip görünür), ortada koyu + daha opak; 3 kademe, sınırlar noktalı.
// Kıyı: 1-3 px köpük şeridi (gürültüyle kalınlaşıp incelir) + açıktan kıyıya yürüyen kesik köpük dalgaları; dalga kıyıya
// vurunca şerit bir an kalınlaşır (her kıyı noktası kendi zamanında). Açıkta hafif ışık bantları + seyrek pırıltı.

uniform vec4 sig_renk : source_color = vec4(0.31, 0.58, 0.64, 1.0);
uniform vec4 orta_renk : source_color = vec4(0.247, 0.451, 0.62, 1.0);
uniform vec4 derin_renk : source_color = vec4(0.17, 0.32, 0.51, 1.0);
uniform float sig_alfa = 0.56;
uniform float orta_alfa = 0.74;
uniform float derin_alfa = 0.86;
uniform float derinlik_px = 28.0;
uniform vec4 kopuk_renk : source_color = vec4(0.87, 0.94, 0.95, 1.0);
uniform float dalga_aralik = 9.0;
uniform float dalga_hiz = 0.3;
uniform float dalga_menzil = 17.0;
uniform vec4 pirilti_renk : source_color = vec4(0.70, 0.86, 0.95, 1.0);

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
		float th = su_bayer(px);

		float lv = su_kademe(clamp(d / derinlik_px, 0.0, 1.0), 2.0, th, 0.45);
		vec3 col = lv < 0.75 ? mix(sig_renk.rgb, orta_renk.rgb, lv * 2.0) : mix(orta_renk.rgb, derin_renk.rgb, lv * 2.0 - 1.0);
		float a = lv < 0.75 ? mix(sig_alfa, orta_alfa, lv * 2.0) : mix(orta_alfa, derin_alfa, lv * 2.0 - 1.0);

		// açıkta hafif ışık bantları (yatay uzun, 3 kademe)
		vec2 wp = px * vec2(0.03, 0.06) + vec2(t * 0.06, t * 0.025);
		float sw = su_fbm(wp);
		col *= 1.0 + (su_kademe(sw, 2.0, th, 0.5) - 0.5) * 0.08 * smoothstep(6.0, 14.0, d);

		// kıyıya yürüyen dalgalar: faz = d / aralık + t * hız (+ kıyı boyunca kayma) -> çizgi kıyıya doğru ilerler
		float ofs = su_noise(px * 0.025) * 1.7;
		float ph = d / dalga_aralik + t * dalga_hiz + ofs;
		float k = floor(ph);
		float f = fract(ph) * dalga_aralik; // çizginin önünden piksel
		float kes = su_noise(px * vec2(0.11, 0.11) + vec2(k * 7.3, k * 3.1));
		float vur = pow(1.0 - fract(t * dalga_hiz + ofs), 5.0); // dalga kıyıya yeni vurdu -> 1

		float rim = 1.0 + su_noise(px * 0.2 + vec2(t * 0.5, -t * 0.35)) * 1.6 + vur * 1.8;
		if (d < rim) {
			col = kopuk_renk.rgb;
			a = 0.92;
		} else if (d < rim + 1.5 && th > 0.5) {
			col = mix(col, kopuk_renk.rgb, 0.7);
			a = max(a, 0.85);
		} else if (d < dalga_menzil * (0.55 + kes * 0.6) && kes > 0.4) {
			float son = 1.0 - smoothstep(dalga_menzil * 0.4, dalga_menzil, d);
			if (f < 1.0) {
				col = mix(col, kopuk_renk.rgb, 0.6 * son);
				a = mix(a, 0.9, son);
			} else if (f < 2.0) {
				col *= 1.0 - 0.07 * son;
			}
		}

		if (d > 9.0) {
			float sp = su_pirilti(px, t, vec2(15.0, 10.0), 0.22, 2.0, vec2(1.5, 0.3), 0.32);
			col = mix(col, pirilti_renk.rgb, sp * 0.85);
			a = max(a, sp * 0.95);
		}
		COLOR = vec4(harita_renk(col), tex.a * a);
	}
}
