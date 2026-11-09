shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://shaders/toprak_desen.gdshaderinc"
#include "res://tools/proto_20261109/bataklik_cimen/ortak.gdshaderinc"

// C - YOSUN VE YAPRAK: orman tabanı hissi - küçük (8-20 px) kıvrımlı yosun benekleri üç tonda (koyu yosun / orta / açık), benekler büyük
// ölçekte yer yer seyrelir (düz çimen açıklıkları); seyrek düşmüş yapraklar (hardal / pas, 2 px + altında gölge) ve çok seyrek minik ak
// mantarlar. Çiçek yok.

vec3 cimen(vec3 tex, vec2 px) {
	float big = pc_leke(px, 0.0045, 30.0);
	float z = pc_leke(px, 0.022, 14.0);
	vec3 h = P_TABAN;
	if (z > 0.62) { h = mix(P_TABAN, P_KOYU_ORTA, 0.30); }
	else if (z > 0.52) { h = mix(P_TABAN, P_ORTA, 0.34); }
	else if (z < 0.36) { h = mix(P_TABAN, P_ACIK, 0.24); }
	if (big < 0.40) { h = mix(h, P_TABAN, 0.75); } // açıklık: benek seyrek
	vec3 c = pc_ton(tex, h);
	// düşmüş yaprak
	const float H1 = 8.0;
	vec2 c1 = floor(px / H1);
	if (pc_hash(c1 + vec2(5.5, 1.7)) < 0.10) {
		vec2 o = c1 * H1 + 1.0 + floor(vec2(pc_hash(c1 + vec2(2.4, 6.6)), pc_hash(c1 + vec2(7.7, 3.1))) * (H1 - 3.0));
		float tur = pc_hash(c1 + vec2(0.9, 9.9));
		vec3 yr = tur < 0.55 ? vec3(0.62, 0.50, 0.25) : vec3(0.50, 0.35, 0.20);
		bool yatay = tur < 0.3 || tur > 0.8;
		vec2 b = yatay ? vec2(1.0, 0.0) : vec2(1.0, 1.0);
		if (px == o || px == o + b) { c = yr; }
		else if (px == o + vec2(0.0, 1.0) || (yatay && px == o + vec2(1.0, 1.0))) { c = pc_ton(tex, P_KOYU_ORTA); }
	}
	// minik ak mantar (koyu yosunda)
	const float H2 = 23.0;
	vec2 c2 = floor(px / H2);
	if (pc_hash(c2 + vec2(3.7, 8.2)) < 0.10 && pc_leke(c2 * H2 + 11.0, 0.022, 14.0) > 0.5) {
		vec2 o = c2 * H2 + 3.0 + floor(vec2(pc_hash(c2 + vec2(1.2, 4.5)), pc_hash(c2 + vec2(6.1, 0.8))) * (H2 - 7.0));
		if (px == o || px == o + vec2(1.0, 0.0)) { c = vec3(0.86, 0.82, 0.70); }
		else if (px == o + vec2(0.0, 1.0)) { c = vec3(0.74, 0.70, 0.60); }
		else if (px == o + vec2(1.0, 1.0) || px == o + vec2(0.0, 2.0)) { c = pc_ton(tex, P_KOYU_ORTA); }
	}
	return c;
}

#include "res://tools/proto_20261109/bataklik_cimen/son.gdshaderinc"
