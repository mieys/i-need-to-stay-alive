// Hadime kara delik prototipi D2 - ON KATMAN (2026-11-11, kullanici: yaratiklar merkezi ortmesin, merkez onlari "yutsun").
// Yaratiklarin USTUNDE (z 20) yalniz merkez: kara kure + yatik disk + bukulen yaylar + foton halkasi, bir de carpma parlamasi.
// Ekran okumaz (BackBufferCopy gerekmez). Bukulen zemin / karartma / sinir / sok dalgasi zeminde kalir
// (kara_delik_d.gdshader center_mode 1). Kucuk dortgen (merkez +-34 x, -30..+16 dunya).
shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "res://tools/proto_20261111/kara_delik/kara_delik_d_merkez.gdshaderinc"

uniform float t = 0.0;
uniform float sq = 0.5;
uniform float px = 0.903;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float tq;
	float size;
	float extra_spin;
	float shock;
	kd_timeline(t, tq, size, extra_spin, shock);
	vec2 ps = (floor(lp / px) + 0.5) * px;
	vec4 c = kd_center(ps, size, extra_spin, tq, px, false);
	if (shock >= 0.0 && shock < 0.34) {
		vec2 q = vec2(ps.x, ps.y / sq);
		if (length(q) < 12.0 * (1.0 - shock * 2.0)) {
			c = vec4(1.0, 0.96, 1.0, 1.0);
		}
	}
	COLOR = c;
}
