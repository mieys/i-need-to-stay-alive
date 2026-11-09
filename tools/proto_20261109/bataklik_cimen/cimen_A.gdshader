shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://shaders/toprak_desen.gdshaderinc"
#include "res://tools/proto_20261109/bataklik_cimen/ortak.gdshaderinc"

// A - ISLAK ÇAYIR: büyük, yumuşak kıvrımlı nemli (koyu) / kuru (açık) lekeler, nemli lekelerde küçük sızıntı gölcükleri (bataklık suyu rengi,
// üstte ıslak koyu kenar, bir parlak piksel), seyrek dik ot sapları (kuruda açık + parlak uç, nemlide koyu). Az şey, büyük şekiller.

vec3 cimen(vec3 tex, vec2 px) {
	float z = pc_leke(px, 0.0065, 34.0);
	vec3 h = P_TABAN;
	bool nem = false;
	if (z > 0.60) { h = mix(P_TABAN, P_ORTA, 0.36); nem = true; }
	if (z > 0.71) { h = mix(P_TABAN, P_ORTA, 0.62); }
	if (z < 0.33) { h = mix(P_TABAN, P_ACIK, 0.28); }
	vec3 c = pc_ton(tex, h);
	// sızıntı gölcükleri (yalnız nemli lekenin içinde)
	const float H1 = 18.0;
	vec2 c1 = floor(px / H1);
	if (pc_leke(c1 * H1 + 9.0, 0.0065, 34.0) > 0.68 && pc_hash(c1 + vec2(2.2, 7.1)) < 0.16) {
		vec2 m = c1 * H1 + 5.0 + floor(vec2(pc_hash(c1 + vec2(1.7, 0.3)), pc_hash(c1 + vec2(5.3, 2.9))) * (H1 - 10.0));
		float rx = 2.5 + floor(pc_hash(c1 + vec2(9.1, 4.4)) * 2.0);
		vec2 d = (px + 0.5 - m) / vec2(rx, 1.45);
		float r = dot(d, d);
		if (r < 0.8) {
			c = (px == m + vec2(-1.0, -1.0)) ? vec3(0.42, 0.60, 0.48) : vec3(0.141, 0.404, 0.294);
		} else if (r < 1.5 && d.y < 0.1) {
			c = pc_ton(tex, P_ORTA);
		}
		return c;
	}
	// seyrek dik ot sapları
	const float H2 = 7.0;
	vec2 c2 = floor(px / H2);
	if (pc_hash(c2 + vec2(4.1, 1.3)) < 0.22) {
		vec2 o = c2 * H2 + floor(vec2(pc_hash(c2 + vec2(3.3, 0.7)), pc_hash(c2 + vec2(8.8, 2.1))) * (H2 - 1.0));
		float L = 2.0 + floor(pc_hash(c2 + vec2(6.6, 5.2)) * 2.0);
		if (px.x == o.x && px.y >= o.y && px.y < o.y + L) {
			if (nem) {
				c = pc_ton(tex, P_ORTA);
			} else {
				c = px.y == o.y ? P_PARLAK : pc_ton(tex, P_ACIK);
			}
		}
	}
	return c;
}

#include "res://tools/proto_20261109/bataklik_cimen/son.gdshaderinc"
