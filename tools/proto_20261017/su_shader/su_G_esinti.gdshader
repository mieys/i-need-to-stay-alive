shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261017/su_shader/su_ortak.gdshaderinc"

// PROTOTİP G - ESİNTİ (2. set, 2026-10-17, oyuna bağlı DEĞİL).
// Cam gibi durgun su (gökyüzünü biraz yansıtan açık ton) + üstünden yavaşça geçen rüzgâr lekeleri: rüzgârın sürttüğü yüzey mat
// ve koyu (2 temiz kademe), lekenin ÖN kenarında 1 px açık çizgi. Lekeler rüzgâr yönünde kayar ve yavaşça biçim değiştirir.
// Nokta yok, küçük parlak öğe yok; kıyıda 1 px açık çizgi.

uniform vec4 sig_renk : source_color = vec4(0.30, 0.55, 0.66, 1.0);
uniform vec4 derin_renk : source_color = vec4(0.22, 0.41, 0.59, 1.0);
uniform vec4 gok_renk : source_color = vec4(0.66, 0.80, 0.88, 1.0);
uniform float sig_alfa = 0.66;
uniform float derin_alfa = 0.82;
uniform vec2 ruzgar = vec2(7.0, 1.8); // px/sn
uniform float leke_olcek = 0.012;
uniform float leke_esik = 0.6;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float leke(vec2 px, float t) {
	return su_fbm((px - ruzgar * t) * leke_olcek + vec2(0.0, t * 0.012));
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

		vec3 col = d < 9.0 ? sig_renk.rgb : derin_renk.rgb;
		float a = d < 9.0 ? sig_alfa : derin_alfa;
		col = mix(col, gok_renk.rgb, 0.1); // durgun yüzey: hafif gök yansıması

		float g = leke(px, t);
		if (d > 2.0 && g > leke_esik) {
			float on = leke(px + normalize(ruzgar) * 2.0, t);
			if (on <= leke_esik) {
				col = mix(col, gok_renk.rgb, 0.45); // ön kenar
			} else {
				col *= g > leke_esik + 0.08 ? 0.84 : 0.9;
				a = max(a, 0.8);
			}
		}
		if (d < 1.0) {
			col = mix(col, gok_renk.rgb, 0.5);
			a = 0.8;
		}
		COLOR = vec4(harita_renk(col), tex.a * a);
	}
}
