shader_type canvas_item;
render_mode unshaded;
#include "res://tools/proto_20261116/gok_isik/gi_ortak.gdshaderinc"

// A - ALTIN HUZME (gündüz) / GÜMÜŞ AY HUZMESİ (gece) + huzmenin suya düştüğü yerde PIRILTI.
// "Yumuşak" el: seyrek, geniş çapraz huzmeler; 3 düz kademe (hale / gövde / öz), iki ucu incelir, 9-22 sn'de bir nefes alır.
// Havada durdukları için zemine göre biraz kayar (paralaks 0,35-0,4). Gündüz sol üstten sıcak altın, gece sağ üstten ince gümüş.
// Su: huzmenin içinde krem / gümüş YATAY pırıltı çizgileri (1 -> 3 -> 5 -> 3 -> 1 px, 1,6-3 sn'lik döngü, her döngüde yeni yer);
// huzme dışında çok seyrek. Pırıltı gündüz krem öz + altın kol, gece gümüş.

const float A_GUN[4] = {0.0, 0.07, 0.13, 0.2};
const float A_GECE[4] = {0.0, 0.05, 0.09, 0.135};
const vec3 ALTIN = vec3(1.0, 0.8, 0.46);
const vec3 GUMUS = vec3(0.6, 0.72, 1.0);
const vec3 PIR_GUN_KOL = vec3(1.0, 0.8, 0.46);
const vec3 PIR_GECE_OZ = vec3(0.86, 0.88, 0.9);
const vec3 PIR_GECE_KOL = vec3(0.6, 0.7, 0.95);

// Huzme alanı 0..1. W = şerit hücresi (huzmeye dik), yog = hücrede huzme olasılığı, hw = yarı genişlik aralığı, P = huzme boyunca tekrar,
// L = yarı boy aralığı, nefes = nefes periyodu aralığı (sn).
float huzme(vec2 px, vec2 yon, float W, float yog, vec2 hw, float P, vec2 L, vec2 nefes, float paralaks, float tohum) {
	vec2 q = px - floor(kamera * paralaks);
	vec2 dik = vec2(yon.y, -yon.x);
	float u = dot(q, dik);
	float v = dot(q, yon);
	float ci = floor(u / W);
	float I = 0.0;
	for (int k = -1; k <= 1; k++) {
		float c = ci + float(k);
		if (gi_hash(vec2(c, tohum)) > yog) {
			continue;
		}
		float uc = (c + 0.15 + 0.7 * gi_hash(vec2(c, tohum + 1.0))) * W;
		float w = mix(hw.x, hw.y, gi_hash(vec2(c, tohum + 2.0)));
		float x = abs(u - uc) / w;
		if (x >= 1.0) {
			continue;
		}
		float kay = gi_hash(vec2(c, tohum + 3.0)) * P;
		float seg = floor((v + kay) / P);
		float vl = (v + kay) - (seg + 0.5) * P;
		float len = mix(L.x, L.y, gi_hash(vec2(c + seg * 7.0, tohum + 4.0)));
		float pv = 1.0 - smoothstep(len * 0.4, len, abs(vl));
		if (pv <= 0.0) {
			continue;
		}
		float per = mix(nefes.x, nefes.y, gi_hash(vec2(c, tohum + 5.0)));
		float b = 0.62 + 0.38 * sin(zaman * 6.2832 / per + 6.2832 * gi_hash(vec2(c + seg, tohum + 6.0)));
		float pu = 1.0 - x * x;
		I = max(I, pu * pv * b * mix(0.75, 1.0, gi_hash(vec2(c, tohum + 7.0))));
	}
	return I;
}

// Yatay pırıltı çizgisi: 0 yok, 1 kol, 2 öz. Hücre başına en çok bir çizgi; yoğunluk huzmenin içinde yog_ic, dışında yog_dis.
float piril(vec2 px, float yog, float t, float tohum) {
	vec2 hc = vec2(10.0, 5.0);
	vec2 base = floor(px / hc);
	float sonuc = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			if (gi_hash(cell + vec2(0.37 + tohum, 1.91)) >= yog) {
				continue;
			}
			float per = 1.6 + 1.4 * gi_hash(cell + vec2(3.1, 0.7 + tohum));
			float dongu = t / per + gi_hash(cell + vec2(5.3 + tohum, 2.2)) * 7.0;
			float faz = fract(dongu);
			if (faz >= 0.5) {
				continue;
			}
			float k = floor(dongu);
			vec2 h = gi_hash2(cell + vec2(k * 1.37 + tohum, k * 2.71));
			vec2 c = floor(cell * hc + h * hc);
			float hl = floor(4.0 * sin(faz * 2.0 * 3.14159) + 0.5);
			if (hl < 1.0) {
				continue;
			}
			vec2 d = px - c;
			if (d.y == 0.0 && abs(d.x) <= hl - 1.0) {
				sonuc = max(sonuc, (abs(d.x) < 0.5 && hl >= 2.0) ? 2.0 : 1.0);
			}
		}
	}
	return sonuc;
}

void fragment() {
	vec2 px = floor(dunya_sol_ust + SCREEN_UV * dunya_boyut);
	vec3 c = texture(ekran, SCREEN_UV).rgb;
	float gun = 1.0 - karanlik;
	vec3 col = c;
	float kg = 0.0;
	float kn = 0.0;
	if (gun > 0.0) {
		float I = huzme(px, normalize(vec2(0.45, 1.0)), 128.0, 0.55, vec2(16.0, 34.0), 760.0, vec2(200.0, 320.0), vec2(9.0, 15.0), 0.35, 11.0);
		kg = gi_kademe3(I, vec3(0.14, 0.42, 0.72));
		col = gi_isik(col, ALTIN, A_GUN[int(kg)] * gun);
	}
	if (karanlik > 0.0) {
		float I = huzme(px, normalize(vec2(-0.25, 1.0)), 140.0, 0.55, vec2(8.0, 16.0), 820.0, vec2(220.0, 340.0), vec2(14.0, 22.0), 0.4, 23.0);
		kn = gi_kademe3(I, vec3(0.14, 0.42, 0.72));
		col = gi_isik(col, GUMUS, A_GECE[int(kn)] * karanlik);
	}
	if (gi_su(px, c)) {
		if (gun > 0.0) {
			float p = piril(px, kg >= 1.0 ? 0.42 : 0.03, zaman, 0.0);
			if (p > 1.5) {
				col = mix(col, KREM, 0.92 * gun);
			} else if (p > 0.5) {
				col = mix(col, PIR_GUN_KOL, 0.66 * gun);
			}
		}
		if (karanlik > 0.0) {
			float p = piril(px, kn >= 1.0 ? 0.4 : 0.025, zaman * 0.8, 4.0);
			if (p > 1.5) {
				col = mix(col, PIR_GECE_OZ, 0.85 * karanlik);
			} else if (p > 0.5) {
				col = mix(col, PIR_GECE_KOL, 0.6 * karanlik);
			}
		}
	}
	COLOR = vec4(col, 1.0);
}
