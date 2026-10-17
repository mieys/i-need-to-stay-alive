shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261017/su_shader/su_ortak.gdshaderinc"

// PROTOTİP B - IŞIK AĞI / KOSTİK (2026-10-17, oyuna bağlı DEĞİL).
// Berrak sığ su: dibe vuran güneş ışığının oynayan kıvrık bantları (yinelemeli türbülans kostiği; Voronoi ağı denendi, dipteki
// toprak çatlaklarına benziyordu), 2 kademe; sığda güçlü derinde sönük. Su daha saydam (dip daha çok görünür), kıyıda 1 px ıslak parlak çizgi + içinde koyu temas çizgisi.

uniform vec4 sig_renk : source_color = vec4(0.27, 0.53, 0.64, 1.0);
uniform vec4 derin_renk : source_color = vec4(0.20, 0.38, 0.57, 1.0);
uniform float sig_alfa = 0.6;
uniform float derin_alfa = 0.8;
uniform float derinlik_px = 30.0;
uniform vec4 isik_renk : source_color = vec4(0.70, 0.88, 0.86, 1.0);
uniform float donem = 72.0;
uniform float esik_parlak = 0.45;
uniform float esik_sonuk = 0.22;
uniform float isik_guc = 0.6;
uniform float hiz = 0.7;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Kostik: yinelemeli türbülans (bilinen "water turbulence" deseni, joltz0r), `donem` dünya px'te döşenir. 0..1, parlak bantlar ~1.
float kostik(vec2 px, float t) {
	vec2 p = mod(px / donem * 6.2831853, 6.2831853) - 250.0;
	vec2 i = p;
	float c = 1.0;
	float inten = 0.005;
	for (int n = 0; n < 4; n++) {
		float tt = t * (1.0 - (3.5 / float(n + 1)));
		i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
	}
	c /= 4.0;
	c = 1.17 - pow(c, 1.4);
	return clamp(pow(abs(c), 8.0), 0.0, 1.0);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (!su_mavi_mi(tex.rgb)) {
		COLOR = su_disi(tex);
		COLOR.rgb = harita_renk(COLOR.rgb);
	} else {
		vec2 px = floor(world_pos);
		float t = TIME * hiz;
		float d = su_kiyi(px);
		float th = su_bayer(px);

		float lv = su_kademe(clamp(d / derinlik_px, 0.0, 1.0), 2.0, th, 0.45);
		vec3 col = mix(sig_renk.rgb, derin_renk.rgb, lv);
		float a = mix(sig_alfa, derin_alfa, lv);

		// kostik bantları: 2 kademe (parlak çekirdek + sönük kenar), kenar noktalı
		float k = kostik(px, t * 0.6);
		float guc = isik_guc * mix(1.0, 0.35, smoothstep(6.0, derinlik_px, d)) * smoothstep(0.5, 3.0, d);
		float isik = 0.0;
		if (k > esik_parlak) {
			isik = 1.0;
		} else if (k > esik_sonuk) {
			isik = th > 0.35 ? 0.45 : 0.0;
		}
		col = mix(col, isik_renk.rgb, isik * guc);
		a = mix(a, max(a, 0.8), isik * guc);

		// kıyı: 1 px ıslak parlak çizgi + içinde koyu temas
		if (d < 1.3) {
			col = mix(col, isik_renk.rgb, 0.65);
			a = 0.75;
		} else if (d < 2.6) {
			col *= 0.82;
			a = max(a, 0.7);
		}
		COLOR = vec4(harita_renk(col), tex.a * a);
	}
}
