shader_type canvas_item;
render_mode unshaded;
#include "res://tools/proto_20261116/gok_isik/gi_ortak.gdshaderinc"

// C - IŞIK KUYUSU: bulut aralığından düşen tek tek ışık SÜTUNLARI ve yere vurduğu yerde ışık HAVUZU; havuz suya denk gelirse su
// YILDIZ PIRILTILARIYLA kaynar. "Keskin" el: sert kenarlı 2 düz ton (cel), sütunun içinde 2 ince parlak şerit, tepede kademeyle söner.
// Bir kuyu 16-32 sn'lik döngünün %62'sinde açık; 4 basamakta belirip söner (bulut açılıp kapanıyor). Ekranda aynı anda 1-3 tane.
// Gündüz sol üstten altın, gece sağ üstten soluk gümüş (daha seyrek, daha uzun). Havuz zemine yapışık; sütun ondan güneşe doğru uzanır.
// Pırıltı: + biçimli yıldız (1 px -> 3x3 -> 5x5 -> geri), 1,1-2 sn döngü; havuz dışında suda çok seyrek tek nokta.

uniform vec2 hucre = vec2(220.0, 170.0);
uniform float tohum_gun = 3.0; // prototip kadrajında havuzu nehre denk getiren tohumlar (oyunda rastgele)
uniform float tohum_gece = 60.0;

const vec3 ALTIN = vec3(1.0, 0.83, 0.5);
const vec3 GUMUS = vec3(0.62, 0.74, 1.0);
const vec3 Y_GUN_KOL = vec3(1.0, 0.86, 0.52);
const vec3 Y_GUN_UC = vec3(0.98, 0.74, 0.42);
const vec3 Y_GECE_OZ = vec3(0.88, 0.9, 0.92);
const vec3 Y_GECE_KOL = vec3(0.66, 0.76, 0.98);
const vec3 Y_GECE_UC = vec3(0.46, 0.56, 0.86);

// x = sütun alfası, y = havuz alfası, z = havuzun içindeyse kuyunun gücü (pırıltı yoğunluğu için)
vec3 kuyular(vec2 px, vec2 yon, float yog, vec2 periyot, float H, vec4 alfa, float tohum, float t) {
	vec2 dik = vec2(yon.y, -yon.x);
	vec2 base = floor(px / hucre);
	vec3 r = vec3(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			if (gi_hash(cell + vec2(tohum, 0.5)) > yog) {
				continue;
			}
			float T = mix(periyot.x, periyot.y, gi_hash(cell + vec2(tohum, 1.5)));
			float faz = fract(t / T + gi_hash(cell + vec2(tohum, 2.5)));
			float on = 0.62;
			if (faz >= on) {
				continue;
			}
			float e = gi_basamak(smoothstep(0.0, 0.14, faz) * (1.0 - smoothstep(on - 0.14, on, faz)), 4.0);
			if (e <= 0.0) {
				continue;
			}
			vec2 P = floor(cell * hucre + (0.2 + 0.6 * gi_hash2(cell + vec2(tohum, 3.5))) * hucre);
			float rx = 30.0 + 18.0 * gi_hash(cell + vec2(tohum, 4.5));
			float ry = rx * 0.5;
			vec2 d = px - P;
			// havuz: kenarı yavaş gürültüyle bozulmuş elips (disk / hedef tahtası gibi durmasın), parlak çekirdek ışığın geldiği yana kayık
			float n1 = gi_vnoise(d * 0.07 + cell * 3.7 + tohum);
			float he = length(vec2(d.x / rx, d.y / ry)) * (0.86 + 0.28 * n1);
			if (he < 1.0) {
				vec2 di = d + yon * rx * 0.22;
				float hi = length(vec2(di.x / rx, di.y / ry)) * (0.86 + 0.28 * gi_vnoise(d * 0.09 + cell * 5.1 + tohum));
				r.y = max(r.y, (hi < 0.55 ? alfa.w : alfa.z) * e);
				r.z = max(r.z, e);
			}
			float tt = dot(d, -yon);
			if (tt > 0.0 && tt < H) {
				float ss = dot(d, dik);
				float w = rx * 0.78 * (1.0 - 0.22 * tt / H);
				if (abs(ss) < w) {
					// tek GENİŞ parlak şerit (5-9 px): ince çizgiler yağmur gibi okunuyor (madde 282 tuzağı)
					float sl = 1.0;
					float s1 = (gi_hash(cell + vec2(tohum, 5.5)) - 0.5) * w * 0.8;
					float g1 = 2.5 + 2.0 * gi_hash(cell + vec2(tohum, 7.5));
					if (abs(ss - s1) < g1) {
						sl = 2.0;
					}
					if (tt > H * 0.65) {
						sl = 1.0;
					}
					if (tt < H * 0.88) {
						r.x = max(r.x, (sl > 1.5 ? alfa.y : alfa.x) * e);
					}
				}
			}
		}
	}
	return r;
}

// + yıldız pırıltısı: 0 yok, 1 kol ucu, 2 kol, 3 öz.
float yildiz_piril(vec2 px, float yog, float t, float tohum) {
	vec2 hc = vec2(12.0, 9.0);
	vec2 base = floor(px / hc);
	float s = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			if (gi_hash(cell + vec2(tohum, 9.1)) >= yog) {
				continue;
			}
			float per = 1.1 + 0.9 * gi_hash(cell + vec2(tohum, 9.7));
			float dongu = t / per + gi_hash(cell + vec2(tohum, 8.3)) * 5.0;
			float faz = fract(dongu);
			if (faz >= 0.6) {
				continue;
			}
			float k = floor(dongu);
			vec2 c = floor(cell * hc + (0.15 + 0.7 * gi_hash2(cell + vec2(k * 1.9, tohum + k * 0.7))) * hc);
			float st = floor(sin(faz / 0.6 * 3.14159) * 3.0 + 0.5);
			if (st < 1.0) {
				continue;
			}
			vec2 d = abs(px - c);
			float v = 0.0;
			if (d.x == 0.0 && d.y == 0.0) {
				v = 3.0;
			} else if (st >= 2.0 && d.x + d.y == 1.0) {
				v = 2.0;
			} else if (st >= 3.0 && ((d.x == 0.0 && d.y == 2.0) || (d.y == 0.0 && d.x == 2.0))) {
				v = 1.0;
			}
			s = max(s, v);
		}
	}
	return s;
}

void fragment() {
	vec2 px = floor(dunya_sol_ust + SCREEN_UV * dunya_boyut);
	vec3 c = texture(ekran, SCREEN_UV).rgb;
	float gun = 1.0 - karanlik;
	vec3 col = c;
	vec3 kg = vec3(0.0);
	vec3 kn = vec3(0.0);
	if (gun > 0.0) {
		kg = kuyular(px, normalize(vec2(0.55, 1.0)), 0.7, vec2(16.0, 24.0), 190.0, vec4(0.1, 0.16, 0.13, 0.21), tohum_gun, zaman);
		col = gi_isik(col, ALTIN, max(kg.x, kg.y) * gun);
	}
	if (karanlik > 0.0) {
		kn = kuyular(px, normalize(vec2(-0.35, 1.0)), 0.6, vec2(22.0, 32.0), 230.0, vec4(0.065, 0.105, 0.09, 0.14), tohum_gece, zaman);
		col = gi_isik(col, GUMUS, max(kn.x, kn.y) * karanlik);
	}
	if (gi_su(px, c)) {
		if (gun > 0.0) {
			float p = yildiz_piril(px, kg.z > 0.0 ? 0.5 * kg.z : 0.03, zaman, 0.0);
			if (p > 2.5) {
				col = mix(col, KREM, 0.95 * gun);
			} else if (p > 1.5) {
				col = mix(col, Y_GUN_KOL, 0.8 * gun);
			} else if (p > 0.5) {
				col = mix(col, Y_GUN_UC, 0.5 * gun);
			}
		}
		if (karanlik > 0.0) {
			float p = yildiz_piril(px, kn.z > 0.0 ? 0.45 * kn.z : 0.025, zaman * 0.85, 3.0);
			if (p > 2.5) {
				col = mix(col, Y_GECE_OZ, 0.9 * karanlik);
			} else if (p > 1.5) {
				col = mix(col, Y_GECE_KOL, 0.72 * karanlik);
			} else if (p > 0.5) {
				col = mix(col, Y_GECE_UC, 0.45 * karanlik);
			}
		}
	}
	COLOR = vec4(col, 1.0);
}
