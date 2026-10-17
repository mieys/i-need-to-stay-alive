shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261017/su_shader/su_ortak.gdshaderinc"

// PROTOTİP F - AKAN NEHİR (2. set, 2026-10-17, oyuna bağlı DEĞİL).
// Su gerçekten akar: dere boyunca akış vektörü dokusu (su_mesafe.py su_akis.png: kıyıya paralel, kanal ortasında hızlı, kıyıda
// durgun) ile yatay uzun ton dokusu (açık / daha açık / koyu çizgiler) akıntı yönünde sürüklenir. Klasik akış haritası: iki fazlı
// kaydırma, faz başı görünmez (ağırlık 0), karışımın kontrastı korunur. 2 temiz derinlik tonu, 1 px açık kıyı çizgisi, nokta yok.
// İlk ayar (8 px/sn, 20x3,5 px doku, %32 açık) karede piksellerin %9'unu değiştiriyordu (D v1 %1,5 "göz yoruyor") -> yavaş + iri + sönük.

uniform sampler2D su_akis : filter_linear, repeat_disable;
uniform vec4 su_renk : source_color = vec4(0.25, 0.46, 0.62, 1.0);
uniform vec4 derin_renk : source_color = vec4(0.20, 0.37, 0.56, 1.0);
uniform vec4 acik_renk : source_color = vec4(0.62, 0.80, 0.88, 1.0);
uniform float su_alfa = 0.72;
uniform float derin_alfa = 0.84;
uniform float akis_hiz = 4.5; // tam hızda px/sn
uniform float donem = 7.0; // faz süresi (sn)
uniform vec2 doku_olcek = vec2(0.035, 0.2); // yatay uzun (~29 x 5 px)

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
		vec2 f = texture(su_akis, (px + 0.5 - mesafe_origin) / mesafe_size).rg * 2.0 - 1.0;

		vec3 col = d < 10.0 ? su_renk.rgb : derin_renk.rgb;
		float a = d < 10.0 ? su_alfa : derin_alfa;

		float p0 = fract(t / donem);
		float p1 = fract(t / donem + 0.5);
		float w0 = 1.0 - abs(2.0 * p0 - 1.0);
		float w1 = 1.0 - w0;
		vec2 q0 = px - f * akis_hiz * donem * p0;
		vec2 q1 = px - f * akis_hiz * donem * p1 + vec2(53.0, 17.0);
		float n = su_noise(q0 * doku_olcek) * w0 + su_noise(q1 * doku_olcek + vec2(9.1, 4.7)) * w1;
		n = 0.5 + (n - 0.5) / sqrt(w0 * w0 + w1 * w1); // iki faz karışınca kontrast düşmesin

		if (d > 2.0) {
			if (n > 0.8) {
				col = mix(col, acik_renk.rgb, 0.24);
			} else if (n > 0.7) {
				col = mix(col, acik_renk.rgb, 0.11);
			} else if (n < 0.24) {
				col *= 0.95;
			}
		}
		if (d < 1.0) {
			col = mix(col, acik_renk.rgb, 0.45);
			a = 0.8;
		} else if (d < 2.5) {
			col *= 0.88;
			a = max(a, 0.76);
		}
		COLOR = vec4(harita_renk(col), tex.a * a);
	}
}
