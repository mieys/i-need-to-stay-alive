// KARA BATAKLIK ÇİMENİ - "B - Ot Tutamları" (madde 526, kullanıcı 4 prototipten seçti; prototip tools/proto_20261109/bataklik_cimen/cimen_B).
// Setin kendi ot çizim dili: çimen karolarının saçağındaki V biçimli sapların küçük hâlleri (3 çeşit: 3x3, 5x4, 7x5), TAM setin paletiyle
// (dip koyu orta, gövde orta, açık, parlak uç), kümeler hâlinde (kümede sık, arası açık); zemin neredeyse düz (yalnız çok hafif tek koyu leke).
// Dither yok, desen dünya pikselinde, yalnız düz çimen pikseli (taban renge yakın) değişir - karoların saçak/kenar çizimleri aynen kalır.
// Kullanan: scenes/bataklik_zemin.gdshader ("Yer/Zemin Toprak", "Yer/Zemin Çimen", kıyı karoları "Su/Su ayrıntılar 2" aynı malzeme).
// Kullanım: float m = bc_maske(tex.rgb); rgb = mix(tex.rgb, bc_cimen(tex.rgb, floor(world_pos)), m);
//
// Palet (karoların saçaklarından ölçüldü): koyu orta #5b7338, orta #788e45, TABAN #90a347, açık #aeb750, parlak #d1d258.

const vec3 BC_KOYU_ORTA = vec3(0.357, 0.451, 0.220);
const vec3 BC_ORTA = vec3(0.471, 0.557, 0.271);
const vec3 BC_TABAN = vec3(0.565, 0.639, 0.278);
const vec3 BC_ACIK = vec3(0.682, 0.718, 0.314);
const vec3 BC_PARLAK = vec3(0.820, 0.824, 0.345);

uniform vec4 cim_taban : source_color = vec4(0.565, 0.639, 0.278, 1.0);   // #90a347: düz çimen karosunun rengi (maske + oran tabanı)
uniform float cim_tolerans : hint_range(0.0, 0.2) = 0.045;               // tabana bu kadar yakın pikseller "düz çimen"

float bc_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bc_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(bc_hash(i), bc_hash(i + vec2(1.0, 0.0)), f.x), mix(bc_hash(i + vec2(0.0, 1.0)), bc_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float bc_fbm(vec2 p) {
	return bc_vnoise(p) * 0.55 + bc_vnoise(p * 2.03) * 0.30 + bc_vnoise(p * 4.01) * 0.15;
}

// kıvrımlı leke alanı 0..1 (ölçek: küçük = büyük leke)
float bc_leke(vec2 px, float olcek, float kivrim) {
	vec2 w = vec2(bc_fbm(px * 0.011), bc_fbm(px * 0.011 + vec2(31.7, 7.3))) - 0.5;
	return bc_fbm((px + w * kivrim) * olcek);
}

// Karonun kendi rengine ORANLA (taban karoda paletin birebir aynısı).
vec3 bc_ton(vec3 tex, vec3 hedef) {
	return tex * (hedef / max(cim_taban.rgb, vec3(0.001)));
}

// 1 = tam düz çimen pikseli.
float bc_maske(vec3 rgb) {
	return 1.0 - smoothstep(cim_tolerans * 0.55, cim_tolerans * 1.55, distance(rgb, cim_taban.rgb));
}

// 4 bitlik palet dizinli küçük çizim: satır = onaltılık sayı, soldan sağa 1 hane = 1 px (0 = boş).
int bc_satir(int satir, int x, int w) {
	return (satir >> ((w - 1 - x) * 4)) & 0xF;
}

// px = floor(dünya konumu). Döner: desenli çimen rengi (maske uygulanmamış).
vec3 bc_cimen(vec3 tex, vec2 px) {
	float z = bc_leke(px, 0.006, 28.0);
	vec3 c = bc_ton(tex, z > 0.63 ? mix(BC_TABAN, BC_ORTA, 0.28) : BC_TABAN);
	// 10 px hücrede en çok bir tutam; yoğunluk küme alanına göre (kümede sık, arası seyrek)
	const float H = 10.0;
	vec2 ci = floor(px / H);
	float yog = mix(0.06, 0.62, smoothstep(0.42, 0.70, bc_leke(ci * H + 5.0, 0.02, 10.0)));
	if (bc_hash(ci + vec2(1.9, 7.3)) >= yog) {
		return c;
	}
	float tur = bc_hash(ci + vec2(4.6, 2.8));
	vec2 o = ci * H + floor(vec2(bc_hash(ci + vec2(3.1, 0.4)), bc_hash(ci + vec2(6.2, 1.9))) * (H - 8.0));
	vec2 l = px - o;
	int x = int(l.x);
	int y = int(l.y);
	int v = 0;
	if (tur < 0.4) {
		if (x >= 0 && y >= 0 && x < 5 && y < 4) {
			int r[4] = int[4](0x00400, 0x04340, 0x33233, 0x12121);
			v = bc_satir(r[y], x, 5);
		}
	} else if (tur < 0.75) {
		if (x >= 0 && y >= 0 && x < 7 && y < 5) {
			int r[5] = int[5](0x0004000, 0x0403040, 0x0303030, 0x3232323, 0x1121211);
			v = bc_satir(r[y], x, 7);
		}
	} else {
		if (x >= 0 && y >= 0 && x < 3 && y < 3) {
			int r[3] = int[3](0x040, 0x343, 0x121);
			v = bc_satir(r[y], x, 3);
		}
	}
	if (v == 1) { c = bc_ton(tex, BC_KOYU_ORTA); }
	else if (v == 2) { c = bc_ton(tex, BC_ORTA); }
	else if (v == 3) { c = bc_ton(tex, BC_ACIK); }
	else if (v == 4) { c = BC_PARLAK; }
	return c;
}
