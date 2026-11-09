shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://shaders/toprak_desen.gdshaderinc"
#include "res://tools/proto_20261109/bataklik_cimen/ortak.gdshaderinc"

// D - SADE: neredeyse düz - yalnız çok büyük, keskin kenarlı iki ton (taban / bir ton koyu) ve 6 px hücrede seyrek tek piksel benek (koyu ya da
// açık). Setin düz çizim diline en sadık, en sakin yön; doku saçaklardan ve süs nesnelerinden gelir.

vec3 cimen(vec3 tex, vec2 px) {
	float z = pc_leke(px, 0.0042, 40.0);
	vec3 c = pc_ton(tex, z > 0.56 ? mix(P_TABAN, P_ORTA, 0.30) : P_TABAN);
	vec2 ci = floor(px / 6.0);
	vec2 o = ci * 6.0 + floor(vec2(pc_hash(ci + vec2(2.0, 0.5)), pc_hash(ci + vec2(7.0, 3.5))) * 5.0);
	if (px == o) {
		float r = pc_hash(ci + vec2(3.3, 1.1));
		if (r < 0.05) { c = pc_ton(tex, P_ORTA); }
		else if (r < 0.085) { c = pc_ton(tex, mix(P_TABAN, P_ACIK, 0.6)); }
	}
	return c;
}

#include "res://tools/proto_20261109/bataklik_cimen/son.gdshaderinc"
