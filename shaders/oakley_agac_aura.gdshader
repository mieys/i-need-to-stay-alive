shader_type canvas_item;

// OAKLEY R "HAYAT AĞACI" GÖLGE ALANI - YAPRAK HALKASI (madde 704; kullanıcı seçimi prototip B, madde 698).
// Eski alan 169 x 84,5'te çizili dokuların x2,07 büyütülmesiydi (düz sarı elips + kalın basamaklı kenar + kalın ışık çizgileri).
// Artık her şey 1 dünya pikseli ızgarasında BURADA çizilir, Kadim Gövde (x1,25) dahil her boyda keskin:
//   zemin katmanı : kenarda yumuşak düz alfa BANTLI halka (titreşim/parazit YOK - kullanıcı kuralı) + tüm yaprak gölgeleri + arka yarı yaprakları
//   ön katman     : ön yarı (güney) yaprakları - karakterlerin üstünde
//   halka         : açılış darbesi (eski halka.png ile aynı kural, iki elips çizgisi, 14 fps kare)
// Yaprak i: alanın kenarında yavaşça döner (OMEGA), havada salınır (yükseklik 4-10 px), 2 karede ters döner, ~3,2 sn'de bir 5x5 pırıltı.
// Hangi katman olduğu dörtgenin 1x1 dokusunun kırmızısında (0 zemin, 0,5 ön, 1 halka) - oakley_tree.gd _layer_texture.
// Koordinatlar ağacın (tam sayıya yuvarlanmış) merkezine göre, piksel (x, y) = [x, x+1).

uniform sampler2D leaf_tex : filter_nearest; // 8 x 18: 3 yaprak çeşidi, 8x6 hücre, alta hizalı (oakley_tree.gd LEAF_ROWS)
uniform vec2 origin;  // dörtgenin sol üstü (ağaç merkezine göre)
uniform vec2 size;    // dörtgen boyu (dünya px)
uniform float rx = 350.0; // alan yarıçapları (Kadim Gövde çarpanı dahil)
uniform float ry = 175.0;
uniform float t = 0.0;    // ağacın açılışından beri (sn)
uniform float za = 0.0;   // alan alfası (0..1, bantlı)
uniform float ring_f = -1.0; // açılış halkası karesi (0..5)

const float N = 60.0;
const float SLOT = 6.28318530718 / 60.0;
const float OMEGA = 0.1122; // rad/sn (prototipte 2,8 sn'de 3 yuva)
const float CYCLE = 2.8;    // salınım / dönme temposu (prototip döngüsü)
const vec3 BAND_C = vec3(226.0, 250.0, 170.0) / 255.0;
const vec3 SHADOW = vec3(28.0, 48.0, 22.0) / 255.0;
const vec3 RING_C = vec3(255.0, 248.0, 214.0) / 255.0;
const vec3 SPARK_CORE = vec3(255.0, 255.0, 236.0) / 255.0;
const vec3 SPARK_ARM = vec3(228.0, 186.0, 76.0) / 255.0;

vec4 over(vec4 dst, vec3 c, float a) {
	if (a <= 0.0) {
		return dst;
	}
	float oa = a + dst.a * (1.0 - a);
	return vec4((c * a + dst.rgb * dst.a * (1.0 - a)) / oa, oa);
}

float band(float a, float n) {
	return clamp(floor(a * n + 0.5) / n, 0.0, 1.0);
}

vec4 ground_band(vec2 px) {
	vec2 q = (px + 0.5) / vec2(rx, ry);
	float r = length(q);
	if (r > 1.0) {
		return vec4(0.0);
	}
	float e = (r - 0.955) / 0.05;
	float f = exp(-e * e) * 0.6 + pow(clamp(1.0 - r, 0.0, 1.0), 2.0) * 0.3;
	float lv = band(f, 4.0);
	return over(vec4(0.0), BAND_C, lv * 0.26 * za);
}

vec4 leaves(vec2 px, bool front, vec4 col) {
	// pikselin ~9 px altındaki nokta yaprağın yer noktasına yakın: oradan en yakın yuvayı bul, komşularıyla birlikte dene
	vec2 q = vec2((px.x + 0.5) / rx, (px.y + 9.5) / ry);
	float rq = length(q);
	if (rq < 0.86 || rq > 1.08) {
		return col;
	}
	float k = floor((atan(q.y, q.x) - OMEGA * t) / SLOT + 0.5);
	for (float d = -1.0; d <= 1.0; d += 1.0) {
		float fi = mod(k + d, N);
		int v = int(mod(fi, 3.0));
		float th = fi * SLOT + (v == 1 ? 0.031 : (v == 2 ? -0.027 : 0.0)) + OMEGA * t;
		float rr = v == 0 ? 0.985 : (v == 1 ? 0.955 : 1.0);
		vec2 g = floor(vec2(rx * rr * cos(th), ry * rr * sin(th)) + 0.5);
		bool is_front = sin(th) >= 0.0;
		// gölge: zemin katmanında, iki yarının yaprakları için de (yerdedir)
		if (!front && px.y == g.y) {
			float sw = v == 0 ? 6.0 : (v == 1 ? 7.0 : 4.0);
			float x0 = g.x - floor(sw * 0.5);
			if (px.x >= x0 && px.x < x0 + sw) {
				col = over(col, SHADOW, band(0.35 * za, 5.0));
			}
		}
		if (is_front != front) {
			continue;
		}
		float h = floor(7.0 + 3.0 * sin(th * 6.0 + 2.0 * TAU * t / CYCLE) + 0.5);
		vec2 lp = px - vec2(g.x - 4.0, g.y - h - 6.0);
		if (lp.x >= 0.0 && lp.y >= 0.0 && lp.x < 8.0 && lp.y < 6.0) {
			float fl = mod(floor(8.0 * t / CYCLE + 13.0 * th / TAU), 2.0);
			float sx = fl > 0.5 ? 7.0 - lp.x : lp.x;
			vec4 tx = texelFetch(leaf_tex, ivec2(int(sx), int(lp.y) + v * 6), 0);
			if (tx.a > 0.0) {
				col = over(col, tx.rgb, za);
			}
		}
		// pırıltı: her yaprak ~3,2 sn'de bir 0,24 sn; kol boyu 1 -> 2 -> 1 (tam yıldız, tek sönük piksel yok)
		float gp = fract(t / 3.2 + fi * 0.618);
		if (gp < 0.075) {
			vec2 dd = px - vec2(g.x, g.y - h - 9.0);
			float m = max(abs(dd.x), abs(dd.y));
			float arm = (gp < 0.025 || gp >= 0.05) ? 1.0 : 2.0;
			if ((dd.x == 0.0 || dd.y == 0.0) && m <= arm) {
				col = over(col, m < 0.5 ? SPARK_CORE : SPARK_ARM, za);
			}
		}
	}
	return col;
}

vec4 ring(vec2 px) {
	vec4 col = vec4(0.0);
	if (ring_f < 0.0) {
		return col;
	}
	float k = clamp(ring_f / 14.0 / 0.42, 0.0, 1.0);
	float q = 1.0 - pow(1.0 - k, 3.0);
	float r1 = 18.0 + (rx * 1.3 - 18.0) * q;
	for (int j = 0; j < 2; j++) {
		float r = j == 0 ? r1 : r1 * 0.82;
		float th = j == 0 ? 3.0 - 1.5 * q : 1.5;
		float al = band((j == 0 ? 0.9 : 0.4) * (1.0 - q), 5.0);
		vec2 e = (px + 0.5) / vec2(r, r * 0.5);
		float dd = dot(e, e);
		float inner = (r - th) / r;
		if (dd <= 1.0 && dd >= inner * inner) {
			col = over(col, RING_C, al);
		}
	}
	return col;
}

void fragment() {
	float layer = texture(TEXTURE, vec2(0.5)).r;
	vec2 px = floor(UV * size) + origin;
	if (layer > 0.75) {
		COLOR = ring(px);
	} else if (layer > 0.25) {
		COLOR = leaves(px, true, vec4(0.0));
	} else {
		COLOR = leaves(px, false, ground_band(px));
	}
}
