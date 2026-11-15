shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261111/bataklik_zemin/ortak.gdshaderinc"

// A - ISLAK KIYI: zemin SUYA YAKLAŞTIKÇA ıslanır (su maskesinden üç kuşak: kuru / nemli / ıslak, sınırları kıvrımlı ve keskin).
//  ÇİMEN: kuruda açık kısa saplar + seyrek saman ucu; nemlide bir yarım ton koyu + koyu saplar; ıslakta (kıyı) bir ton koyu, yastık yosun
//         (koyu orta, üst kenarı ışık alır), KAMIŞ öbekleri (ince dik saplar, bazılarında kahve kamış başı) ve küçük su sızıntıları.
//  YOL:   kuruda açık kabuk lekeleri + kısa çatlak parçaları; nemlide düz çamur + seyrek birikinti; ıslakta koyu ıslak çamur, sık ve büyük
//         birikintiler, 1 px ıslak parıltılar.

// 0 kuru, 1 nemli, 2 ıslak
// kıyıdan ~45 px ıslak, ~95 px'e kadar nemli (alan 160 px'te 0), sınır kıvrımlı
int bolge(vec2 px) {
	float w = pz_islaklik(px) + (pz_leke(px, 0.03, 14.0) - 0.5) * 0.30;
	return w > 0.70 ? 2 : (w > 0.40 ? 1 : 0);
}

vec3 cimen(vec3 tex, vec2 px) {
	int b = bolge(px);
	vec3 c = pz_ton_c(tex, b == 2 ? G_ORTA : (b == 1 ? mix(G_TABAN, G_ORTA, 0.35) : G_TABAN));
	if (b == 0) {
		// kuru: seyrek açık "v" ot (10 px hücre %16), bazısının ucu parlak
		ivec2 l = pz_hucre_yerel(px, 10.0, vec2(1.3, 8.1), 3, 2);
		vec2 ci = floor(px / 10.0);
		if (l.x >= 0 && pz_hash(ci + vec2(5.5, 2.2)) < 0.16) {
			int r[2] = int[2](0x304, 0x030);
			int v = pz_satir(r[l.y], l.x, 3);
			if (v == 3 || (v == 4 && pz_hash(ci + vec2(0.7, 0.7)) < 0.6)) { c = pz_ton_c(tex, G_ACIK); }
			else if (v == 4) { c = G_PARLAK; }
		}
		return c;
	}
	if (b == 1) {
		ivec2 l = pz_hucre_yerel(px, 6.0, vec2(2.7, 4.4), 1, 2);
		if (l.x >= 0 && pz_hash(floor(px / 6.0) + vec2(9.1, 0.6)) < 0.30) {
			c = pz_ton_c(tex, G_ORTA);
		}
		return c;
	}
	// ISLAK: küçük yastık yosun (ilk sürümde iri ve sıktı = kamuflaj lekesi)
	float y = pz_leke(px, 0.09, 6.0);
	if (y > 0.68) {
		c = pz_leke(px - vec2(0.0, 1.0), 0.09, 6.0) > 0.68 ? pz_ton_c(tex, G_KOYU_ORTA) : pz_ton_c(tex, G_TABAN);
	}
	// küçük su sızıntısı (13 px hücre)
	ivec2 s = pz_hucre_yerel(px, 13.0, vec2(4.2, 0.9), 5, 2);
	if (s.x >= 0 && pz_hash(floor(px / 13.0) + vec2(7.7, 3.1)) < 0.12) {
		int r0[2] = int[2](0x09770, 0x17771);
		int v = pz_satir(r0[s.y], s.x, 5);
		if (v == 9) { c = birikinti_isik.rgb; }
		else if (v == 7) { c = birikinti_rengi.rgb; }
		else if (v == 1) { c = pz_ton_c(tex, G_KOYU_ORTA); }
	}
	// kamış öbekleri (9 px hücre, 5x7)
	ivec2 k = pz_hucre_yerel(px, 9.0, vec2(3.9, 6.2), 5, 7);
	vec2 kc = floor(px / 9.0);
	if (k.x >= 0 && pz_hash(kc + vec2(0.4, 5.8)) < 0.34) {
		float tur = pz_hash(kc + vec2(8.3, 1.6));
		int v = 0;
		if (tur < 0.45) {
			int r[7] = int[7](0x00040, 0x04030, 0x03030, 0x03024, 0x02023, 0x02212, 0x12121);
			v = pz_satir(r[k.y], k.x, 5);
		} else if (tur < 0.7) {
			int r[7] = int[7](0x05000, 0x06040, 0x06030, 0x02030, 0x02020, 0x02020, 0x12121);
			v = pz_satir(r[k.y], k.x, 5);
		} else if (k.y >= 3) {
			int r[4] = int[4](0x00400, 0x00300, 0x02320, 0x01210);
			v = pz_satir(r[k.y - 3], k.x, 5);
		}
		if (v == 1) { c = pz_ton_c(tex, G_KOYU); }
		else if (v == 2) { c = pz_ton_c(tex, G_KOYU_ORTA); }
		else if (v == 3) { c = pz_ton_c(tex, G_TABAN); }
		else if (v == 4) { c = pz_ton_c(tex, G_ACIK); }
		else if (v == 5) { c = M_KOYU_ORTA; }
		else if (v == 6) { c = M_KOYU; }
	}
	return c;
}

vec3 yol(vec3 tex, vec2 px) {
	int b = bolge(px);
	float z = pz_leke(px, 0.012, 24.0);
	vec3 c;
	if (b == 0) {
		bool kabuk = z < 0.50;
		c = pz_ton_m(tex, kabuk ? M_ACIK : M_TABAN);
		// çakıl (12 px hücre %10, 2x1 + gölge)
		ivec2 g = pz_hucre_yerel(px, 12.0, vec2(6.3, 2.8), 2, 2);
		if (g.x >= 0 && pz_hash(floor(px / 12.0) + vec2(1.9, 9.2)) < 0.10) {
			return g.y == 0 ? pz_ton_m(tex, g.x == 0 ? M_PARLAK : M_ACIK) : pz_ton_m(tex, M_KOYU_ORTA);
		}
		if (kabuk) {
			// kısa çatlak parçası: 6 px hücrede %35, 3 px (yatay / çapraz / L)
			ivec2 l = pz_hucre_yerel(px, 6.0, vec2(2.2, 7.4), 3, 2);
			vec2 ci = floor(px / 6.0);
			if (l.x >= 0 && pz_hash(ci + vec2(6.1, 0.2)) < 0.35) {
				float t = pz_hash(ci + vec2(3.3, 9.4));
				bool on = t < 0.33 ? (l.y == 0) : (t < 0.66 ? (l.y == (l.x >= 2 ? 1 : 0) && l.x != 1) || (l.x == 1 && l.y == 0) : (l.y == 1 || l.x == 0));
				if (on) { c = pz_ton_m(tex, M_KOYU_ORTA); }
			}
		}
		return c;
	}
	if (b == 1) {
		c = pz_ton_m(tex, z > 0.6 ? M_ORTA : M_TABAN);
		int p = pz_birikinti(px, 17.0, 0.16, 2.0, 3.0, vec2(4.4, 8.8));
		if (p == 1) { c = birikinti_rengi.rgb; }
		else if (p == 3) { c = birikinti_isik.rgb; }
		else if (p == 2) { c = pz_ton_m(tex, M_KOYU); }
		else if (p == 4) { c = pz_ton_m(tex, M_ACIK); }
		return c;
	}
	c = pz_ton_m(tex, z > 0.45 ? M_KOYU_ORTA : M_ORTA);
	int p = pz_birikinti(px, 14.0, 0.42, 2.0, 5.0, vec2(1.7, 5.2));
	if (p == 1) { c = birikinti_rengi.rgb; }
	else if (p == 3) { c = birikinti_isik.rgb; }
	else if (p == 2) { c = pz_ton_m(tex, M_EN_KOYU); }
	else if (p == 4) { c = pz_ton_m(tex, M_TABAN); }
	else {
		// ıslak parıltı: 5 px hücrede %10 tek açık piksel
		vec2 ci = floor(px / 5.0);
		vec2 o = ci * 5.0 + floor(vec2(pz_hash(ci + vec2(2.0, 0.5)), pz_hash(ci + vec2(7.0, 3.5))) * 4.0);
		if (px == o && pz_hash(ci + vec2(5.3, 1.1)) < 0.10) { c = pz_ton_m(tex, M_ACIK); }
	}
	return c;
}

#include "res://tools/proto_20261111/bataklik_zemin/son.gdshaderinc"
