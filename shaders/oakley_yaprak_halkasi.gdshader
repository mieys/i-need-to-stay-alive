shader_type canvas_item;

// OAKLEY ÇİÇEĞİ "YAPRAK HALKASI" ÇİZİCİSİ (madde 285/316; FPS 2026-10-19): eski sürüm her karede GDScript _draw'da ~150 piksel dikdörtgeni +
// Bresenham iz üretiyordu - açmış çiçek başına kare başı ~0,54 ms CPU (12 çiçekte kare 5,3 -> 12,3 ms). Artık yaprak KONUMLARI GDScript'te
// (scripts/oakley_flower_fx.gd leaf_pos - tek kaynak, testli), bu shader yalnız dünya pikseli ızgarasında boyar. Çiçek başına TEK materyal, üç dörtgen
// (zemin / arka / ön) aynı materyali paylaşır; hangi katman olduğu dörtgenin 1x1 dokusunun kırmızısında (0 zemin, 0,5 arka, 1 ön).
// Koordinatlar çiçeğin yereli (kök = çiçek merkezi), piksel (x, y) = [x, x+1) - eski draw_rect ile aynı ızgara.

uniform sampler2D leaf_tex : filter_nearest; // 7x7 yaprak (oakley_flower_fx.gd LEAF_ROWS)
uniform vec4 leaf_a[6];   // yaprak: x, havadaki y, açı, alfa
uniform vec4 leaf_b[6];   // yerdeki y (gölge), iz elipsinin merkez y, -, -
uniform vec4 p0;          // yörünge yarıçapı, havuz yarıçapı (0,5 adımlı), doğuş alfası, -
uniform vec4 p1;          // yaprak sayısı, yeni yaprakların ilk sırası, parıltı alfası, -
uniform vec2 origin;      // dörtgenin sol-üstü (çiçek yereli)
uniform vec2 size;        // dörtgen boyu (dünya px)

const float FOOT_Y = 20.0;
const vec3 TRAIL = vec3(226.0, 250.0, 170.0) / 255.0;
const vec3 POOL_C = vec3(236.0, 246.0, 170.0) / 255.0;
const vec3 POOL_IN = vec3(252.0, 252.0, 214.0) / 255.0;
const vec3 SHADOW = vec3(28.0, 48.0, 22.0) / 255.0;
const vec3 SPARK_CORE = vec3(255.0, 255.0, 236.0) / 255.0;
const vec3 SPARK_ARM = vec3(228.0, 186.0, 76.0) / 255.0;

float band(float a) {
	return clamp(floor(a * 5.0 + 0.5) / 5.0, 0.0, 1.0);
}

vec4 over(vec4 dst, vec3 c, float a) {
	float oa = a + dst.a * (1.0 - a);
	if (oa <= 0.0) {
		return dst;
	}
	return vec4((c * a + dst.rgb * dst.a * (1.0 - a)) / oa, oa);
}

// piksel merkezi (q + 0,5) elipsin içinde mi (merkez piksel sınırında - eski havuz dokusuyla aynı simetri)
bool in_ell(vec2 q, float rx, float ry) {
	vec2 d = (q + 0.5) / vec2(max(rx, 0.6), max(ry, 0.6));
	return dot(d, d) <= 1.0;
}

vec4 ground(vec2 px) {
	vec4 col = vec4(0.0);
	float rr = p0.y;
	vec2 q = px - vec2(0.0, FOOT_Y - 1.0);
	if (in_ell(q, rr, rr * 0.5)) {
		col = over(col, POOL_C, 0.2);
		if (in_ell(q, rr * 0.5, rr * 0.25)) {
			col = over(col, POOL_IN, 0.2);
		}
		// kesintisiz 1 px kenar: dolu elips - 4-komşu aşındırma (2:1'de üst/alt kopmaz)
		bool edge = !in_ell(q + vec2(1.0, 0.0), rr, rr * 0.5) || !in_ell(q - vec2(1.0, 0.0), rr, rr * 0.5)
				|| !in_ell(q + vec2(0.0, 1.0), rr, rr * 0.5) || !in_ell(q - vec2(0.0, 1.0), rr, rr * 0.5);
		if (edge) {
			col = over(col, POOL_C, 0.6);
		}
		col.a *= p0.z;
	}
	int n = int(p1.x + 0.5);
	for (int i = 0; i < 6; i++) {
		if (i >= n) {
			break;
		}
		vec4 a = leaf_a[i];
		float sa = band(0.4 * a.w);
		vec2 tl = vec2(floor(a.x + 0.5) - 2.0, floor(leaf_b[i].x + 0.5));
		if (sa > 0.0 && px.y == tl.y && px.x >= tl.x && px.x < tl.x + 4.0) {
			col = over(col, SHADOW, sa);
		}
	}
	return col;
}

vec4 orbit(vec2 px, bool want_front) {
	vec4 col = vec4(0.0);
	int n = int(p1.x + 0.5);
	int first_new = int(p1.y + 0.5);
	float r = max(p0.x, 0.6);
	for (int i = 0; i < 6; i++) {
		if (i >= n) {
			break;
		}
		vec4 a = leaf_a[i];
		bool fr = sin(a.z) >= 0.0;
		if (fr != want_front || a.w <= 0.0) {
			continue;
		}
		// iz: yörünge elipsinin yaprağın ARKASINDA kalan 0,9 rad'lık parçası, 1 px (örtük eğriye uzaklık <= 0,5), ilk 0,36 rad güçlü
		vec2 rel = px + 0.5 - vec2(0.0, leaf_b[i].y);
		vec2 e = vec2(rel.x / r, rel.y / (0.45 * r));
		float f = dot(e, e) - 1.0;
		vec2 g = vec2(2.0 * rel.x / (r * r), 2.0 * rel.y / (0.2025 * r * r));
		float dist = abs(f) / max(length(g), 1e-4);
		if (dist <= 0.5) {
			float rel_ang = mod(a.z - atan(e.y, e.x), TAU);
			if (rel_ang <= 0.9) {
				col = over(col, TRAIL, rel_ang <= 0.36 ? band(0.8 * a.w) : band(0.45 * a.w));
			}
		}
		// yaprak: 7x7, gidiş yönüne sivri uç (arkadaki yarıda yatay ayna, yan çeyreklerde dikey ayna)
		vec2 tl = floor(vec2(a.x - 3.5, a.y - 3.5) + 0.5);
		vec2 lp = px - tl;
		if (lp.x >= 0.0 && lp.y >= 0.0 && lp.x < 7.0 && lp.y < 7.0) {
			int qd = int(mod(a.z + PI * 0.25, TAU) / (PI * 0.5)) % 4;
			vec2 sp = vec2(fr ? lp.x : 6.0 - lp.x, (qd == 1 || qd == 3) ? 6.0 - lp.y : lp.y);
			vec4 t = texelFetch(leaf_tex, ivec2(sp), 0);
			if (t.a > 0.0) {
				col = over(col, t.rgb, band(a.w));
			}
		}
		// yeni yaprağın üstünde 4 uçlu parıltı (5x5)
		if (i >= first_new && p1.z > 0.0) {
			vec2 d = px - (floor(a.xy + 0.5) + vec2(0.0, -6.0));
			float m = max(abs(d.x), abs(d.y));
			if ((d.x == 0.0 || d.y == 0.0) && m <= 2.0) {
				col = over(col, m <= 1.0 ? SPARK_CORE : SPARK_ARM, p1.z);
			}
		}
	}
	return col;
}

void fragment() {
	float layer = texture(TEXTURE, vec2(0.5)).r;
	vec2 px = floor(UV * size) + origin;
	if (layer < 0.25) {
		COLOR = ground(px);
	} else {
		COLOR = orbit(px, layer > 0.75);
	}
}
