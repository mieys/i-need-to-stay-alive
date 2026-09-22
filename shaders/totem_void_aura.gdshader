shader_type canvas_item;

// Alan Totemi'nin (mor) yerdeki AURASI - piksel-art "büyü çemberi + boşluk girdabı".
// Kullanıcı geri bildirimi (2026-09-22): "mor totemin etrafında açtığı aura çok kötü, pixel tarzda yeniden tasarla" - eski aura seyrek
// noktalardan oluşan soluk bir halka + dağınık spiral noktalarıydı. Yeni aura tamamen bu shader'la ve TEXEL ızgarasına oturtularak çizilir
// (her "piksel" 1 oyun texel'i = 1.212 px; kenarlar basamaklı, bulanık/yumuşak çizgi YOK):
//   * dış çember: 2 texel kalınlığında, kesikli parlak dilimleri yavaşça dönen katı halka + koyu dış kontur
//   * rün kuşağı: halkanın hemen içinde 16 adet 5x5 pixel rün (6 farklı motif), yavaşça dönen, nabız atan
//   * iç çember: ters yönde dönen ince kesikli halka + totem tabanı etrafında küçük çember
//   * boşluk girdabı: Bayer (sıralı dither) ile kenara doğru koyulaşan, dönen 3 sarmal kollu zemin
//   * yükselen boşluk kıvılcımları (1 texel)
// Sunucu/istemci ayrımı yok: salt görsel, her istemcide aynı çizim (bkz. CLAUDE.md - görsel kopya aynı script/sahneyi kurar).

uniform float radius_px = 180.0;
uniform float texel = 1.212;
uniform vec2 quad_size = vec2(376.0, 376.0);
uniform vec4 col_dark : source_color = vec4(0.12, 0.04, 0.24, 1.0);
uniform vec4 col_mid : source_color = vec4(0.56, 0.28, 0.92, 1.0);
uniform vec4 col_light : source_color = vec4(0.86, 0.68, 1.0, 1.0);
uniform vec4 col_white : source_color = vec4(0.98, 0.94, 1.0, 1.0);
uniform float fill_alpha = 0.36;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
// 5x5 rün motifleri (satır satır 5 bit, en üst satır en yüksek bit): elmas / artı / üçgen / hilal / S kancası / göz
const int GLYPH[6] = int[6](
	(4 << 20) | (10 << 15) | (17 << 10) | (10 << 5) | 4,
	(4 << 20) | (4 << 15) | (31 << 10) | (4 << 5) | 4,
	(4 << 20) | (10 << 15) | (10 << 10) | (17 << 5) | 31,
	(14 << 20) | (16 << 15) | (16 << 10) | (16 << 5) | 14,
	(15 << 20) | (16 << 15) | (14 << 10) | (1 << 5) | 30,
	(14 << 20) | (17 << 15) | (21 << 10) | (17 << 5) | 14
);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float bayer(vec2 tc) {
	int x = int(mod(tc.x, 4.0));
	int y = int(mod(tc.y, 4.0));
	return (BAYER[x + y * 4] + 0.5) / 16.0;
}

void fragment() {
	vec2 p = (UV - 0.5) * quad_size;
	vec2 tc = floor(p / texel);
	vec2 q = (tc + 0.5) * texel;
	float len = length(q);
	float d = len / radius_px;
	float a = atan(q.y, q.x);
	float t = TIME;
	float pulse = 0.5 + 0.5 * sin(t * 2.0);
	vec4 col = vec4(0.0);

	// --- boşluk girdabı (zemin): kenardan içeri solan dither bandı + dönen 3 sarmal kol (2x2 texel'lik iri dama = temiz pixel-art dokusu) ---
	if (d <= 1.0) {
		vec2 tc2 = floor(tc / 2.0);
		float edge_grad = smoothstep(0.72, 1.0, d);
		float arms = fract(a / TAU * 3.0 + d * 1.6 - t * 0.10);
		float band = smoothstep(0.0, 0.08, arms) * (1.0 - smoothstep(0.20, 0.32, arms));
		float arm = band * smoothstep(0.10, 0.34, d) * (1.0 - smoothstep(0.78, 0.94, d));
		float density = max(edge_grad * 0.85, arm * 0.62);
		if (bayer(tc2) < density) {
			vec3 c = mix(col_dark.rgb, col_mid.rgb, arm * 0.75 + edge_grad * 0.12);
			col = vec4(c, fill_alpha + 0.22 * arm);
		}
	}

	// --- totem tabanı çevresinde küçük çember + 8 çentik ---
	float rc = radius_px * 0.115;
	if (abs(len - rc) < texel * 0.55) {
		col = vec4(mix(col_mid.rgb, col_light.rgb, pulse * 0.5), 0.9);
	}
	if (len < rc - texel && len > rc - texel * 3.0) {
		float ticks = floor(a / TAU * 8.0 + 0.5);
		float ang_to = abs(a - (ticks / 8.0) * TAU);
		if (ang_to < 0.09) {
			col = vec4(col_light.rgb, 0.85);
		}
	}

	// --- iç çember: ters yönde dönen ince kesikli halka ---
	float r2 = radius_px * 0.62;
	if (abs(len - r2) < texel * 0.55) {
		float seg = floor(a / TAU * 40.0 + t * 0.8);
		if (mod(seg, 3.0) < 2.0) {
			col = vec4(col_mid.rgb, 0.85);
		}
	}

	// --- rün kuşağı: 16 slot, yavaşça dönen, nabız atan 5x5 pixel rünler ---
	float rg = radius_px - texel * 10.0;
	float rot = t * 0.012;
	float ka = floor(fract(a / TAU - rot) * 16.0);
	float ac = (ka + 0.5) / 16.0 * TAU + rot * TAU;
	vec2 slot = rg * vec2(cos(ac), sin(ac));
	vec2 sc = (floor(slot / texel) + 0.5) * texel;
	vec2 loc = (q - sc) / texel;
	int gx = int(floor(loc.x + 2.5));
	int gy = int(floor(loc.y + 2.5));
	if (gx >= -1 && gx <= 5 && gy >= -1 && gy <= 5) {
		int gid = int(mod(floor(hash21(vec2(ka, 3.7)) * 6.0), 6.0));
		bool lit = false;
		if (gx >= 0 && gx <= 4 && gy >= 0 && gy <= 4) {
			lit = ((GLYPH[gid] >> (24 - (gy * 5 + gx))) & 1) == 1;
		}
		if (lit) {
			float glow = 0.5 + 0.5 * sin(t * 2.0 + ka * 0.9);
			col = vec4(mix(col_mid.rgb, col_light.rgb, glow), 0.96);
		} else if (col.a < 0.55) {
			col = vec4(col_dark.rgb * 0.5, 0.62); // rünün arkasında koyu zemin (okunaklılık)
		}
	}

	// --- dış çember: 2 texel katı halka, kesikli parlak dilimler, koyu dış kontur ---
	float rd = len - radius_px;
	if (rd < texel * 0.6 && rd > -texel * 1.6) {
		float seg2 = floor(a / TAU * 64.0 - t * 0.7);
		float bright = (mod(seg2, 6.0) < 2.0) ? 1.0 : 0.0;
		vec3 base = mix(col_mid.rgb, col_light.rgb, bright * (0.55 + 0.45 * pulse));
		if (rd > -texel * 0.5) {
			base = mix(base, col_dark.rgb, 0.6);
		}
		col = vec4(base, 0.97);
	}

	// --- yükselen boşluk kıvılcımları (12 texel'lik hücre başına en fazla 1) ---
	vec2 cell = floor(tc / 12.0);
	float h = hash21(cell);
	float h2 = hash21(cell + 17.3);
	if (h2 > 0.84 && d < 0.93) {
		vec2 inc = tc - cell * 12.0;
		float ph = fract(t * (0.10 + 0.10 * h) + h * 7.0);
		float mx = floor(fract(h * 9.7) * 12.0 + sin(ph * 6.2 + h * 20.0) * 1.4);
		float my = floor((1.0 - ph) * 12.0);
		if (floor(inc.x) == clamp(mx, 0.0, 11.0) && floor(inc.y) == my) {
			col = vec4(mix(col_light.rgb, col_white.rgb, 1.0 - ph), 0.95 * (1.0 - ph * 0.7));
		}
	}

	COLOR = col;
}
