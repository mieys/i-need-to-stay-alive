shader_type canvas_item;
render_mode unshaded;

// GÜN IŞIĞI D - "ALTIN PUS" (madde 282 prototipi): şekil yok, ışık HAVANIN kendisinde. Sağ üstten gelen çok hafif altın
// pus (paralaks 0,6, yavaş dalgalanan geniş kütleler, 3 düz kademe) + parlak yüzeylerde (su pırıltısı, açık patika, parlak
// çiçek, karakter ışıkları) sıcak piksel parlaması + gölgelerde çok hafif sıcak dolgu. Göz yormayan "güneşli gün" havası.
// Ekranı okur.
#include "res://tools/proto_20261019/gunes_sis/gs_ortak.gdshaderinc"

uniform sampler2D ekran : hint_screen_texture, filter_nearest;
uniform float pus_guc = 0.11;
uniform vec3 pus_renk : source_color = vec3(1.0, 0.84, 0.55);
uniform float paralaks = 0.6;
uniform float parlama_esigi = 0.58;
uniform float parlama_guc = 0.55;
uniform vec3 parlama_renk : source_color = vec3(1.0, 0.82, 0.52);

void fragment() {
	vec2 px = gs_texel(SCREEN_UV);
	vec2 uv = gs_uv(px);
	vec3 base = texture(ekran, SCREEN_UV).rgb;
	// Parlama: çevredeki 12 texel'in eşik üstü parlaklığı (2 ve 4 texel halkası), 2 düz kademe.
	float p = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7854;
		vec2 o = vec2(cos(a), sin(a));
		p += max(gs_lum(texture(ekran, gs_uv(px + o * 2.0)).rgb) - parlama_esigi, 0.0) * 1.0;
		if (i % 2 == 0) {
			p += max(gs_lum(texture(ekran, gs_uv(px + o * 4.0)).rgb) - parlama_esigi, 0.0) * 0.5;
		}
	}
	p = p / 6.0;
	float pk = gs_kademe(p * 2.6, 3.0);
	// Pus: sağ üste doğru yoğunlaşan, geniş ve yavaş kütleler.
	vec2 sp = gs_paralaks(px, paralaks);
	float h = fbm(sp * 0.0032 + vec2(zaman * 0.012, -zaman * 0.006));
	float egim = clamp(uv.x * 0.75 + (1.0 - uv.y) * 0.6 - 0.15, 0.0, 1.0);
	float pus = gs_kademe(smoothstep(0.3, 0.75, h) * (0.35 + 0.65 * egim), 3.0);
	// Altın ton: gölgelere çok hafif sıcak dolgu, parlaklara hafif sıcaklık.
	float l = gs_lum(base);
	vec3 col = base + vec3(0.03, 0.018, 0.0) * (1.0 - l) + base * vec3(0.03, 0.01, -0.04) * l;
	col += pus_renk * pus * pus_guc;
	col += parlama_renk * pk * parlama_guc * 0.2;
	COLOR = vec4(col, 1.0);
}
