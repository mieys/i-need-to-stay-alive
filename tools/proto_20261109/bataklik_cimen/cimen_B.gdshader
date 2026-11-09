shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://shaders/toprak_desen.gdshaderinc"
#include "res://tools/proto_20261109/bataklik_cimen/ortak.gdshaderinc"

// B - OT TUTAMLARI: setin kendi ot çizim dili - çimen karolarının saçağındaki V biçimli sapların küçük hâlleri (3 çeşit: 3x3, 5x4, 7x5), TAM
// setin paletiyle (dip koyu orta, gövde orta, açık, parlak uç). Tutamlar kümeler hâlinde (kümede sık, arası açık), zemin neredeyse düz
// (yalnız çok hafif tek koyu leke). Örnek haritanın "her yerde ot" görünüşüne en yakın yön.

vec3 cimen(vec3 tex, vec2 px) {
	float z = pc_leke(px, 0.006, 28.0);
	vec3 c = pc_ton(tex, z > 0.63 ? mix(P_TABAN, P_ORTA, 0.28) : P_TABAN);
	const float H = 10.0;
	vec2 ci = floor(px / H);
	float yog = mix(0.06, 0.62, smoothstep(0.42, 0.70, pc_leke(ci * H + 5.0, 0.02, 10.0)));
	if (pc_hash(ci + vec2(1.9, 7.3)) >= yog) {
		return c;
	}
	float tur = pc_hash(ci + vec2(4.6, 2.8));
	vec2 o = ci * H + floor(vec2(pc_hash(ci + vec2(3.1, 0.4)), pc_hash(ci + vec2(6.2, 1.9))) * (H - 8.0));
	vec2 l = px - o;
	int x = int(l.x);
	int y = int(l.y);
	int v = 0;
	if (tur < 0.4) {
		if (x >= 0 && y >= 0 && x < 5 && y < 4) {
			int r[4] = int[4](0x00400, 0x04340, 0x33233, 0x12121);
			v = pc_satir(r[y], x, 5);
		}
	} else if (tur < 0.75) {
		if (x >= 0 && y >= 0 && x < 7 && y < 5) {
			int r[5] = int[5](0x0004000, 0x0403040, 0x0303030, 0x3232323, 0x1121211);
			v = pc_satir(r[y], x, 7);
		}
	} else {
		if (x >= 0 && y >= 0 && x < 3 && y < 3) {
			int r[3] = int[3](0x040, 0x343, 0x121);
			v = pc_satir(r[y], x, 3);
		}
	}
	if (v == 1) { c = pc_ton(tex, P_KOYU_ORTA); }
	else if (v == 2) { c = pc_ton(tex, P_ORTA); }
	else if (v == 3) { c = pc_ton(tex, P_ACIK); }
	else if (v == 4) { c = P_PARLAK; }
	return c;
}

#include "res://tools/proto_20261109/bataklik_cimen/son.gdshaderinc"
