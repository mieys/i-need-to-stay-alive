shader_type canvas_item;
render_mode unshaded;
#include "res://tools/proto_20261116/gok_isik/gi_ortak.gdshaderinc"

// B - GÖKYÜZÜ AYNASI: su gökyüzünü ve kıyıdaki dik nesneleri yansıtır (karada değişiklik yok, bulut gölgeleri oyundaki gibi).
// "Yansıma" eli: üstten bakılan oyunda görünmeyen gökyüzü suyun içinde görünür.
//   Gündüz: açık mavi gök (güneşe yakın daha açık, düz kademeler) + rüzgarla kayan krem bulut yansımaları (3 düz ton, dither yok) +
//           GÜNEŞ yansıması (krem öz, altın gövde, kenarı dalgacıklarla yatay şeritlere bölünür) + altına doğru söner PIRILTI YOLU
//           (her iki satırda bir kırık yatay çizgi) + ağaç / çalı / karakter AYNASI (kuzey kıyı çizgisine göre baş aşağı, satır satır
//           1 px dalgalanır, serin tonlu; ara ara bir satır kırılır).
//   Gece:   lacivert gök (aya yakın açık) + yavaş göz kırpan yıldızlar (%22 genlik, 3-6 sn) + ince koyu bulutlar + AY yansıması
//           (soluk krem öz, gümüş şeritler) + gümüş ay yolu + koyu siluet aynası.
// Gök katmanı uzakta: yürürken yansıma suya göre neredeyse sabit kalır (gok_gecikme) - gerçek sudaki gibi güneş/ay yansıması
// izleyenle birlikte gelir; ağaç/karakter yansıması zemine yapışık.

uniform vec2 isik_ekran = vec2(150.0, 70.0); // kamera0'dayken güneş/ay yansımasının kamera merkezine göre yeri (dünya px)
uniform float gok_gecikme = 0.15;           // yürürken gök yansıması ekranda bu oranda geri kayar (0 = ekrana yapışık)

const vec3 GOK_YAKIN = vec3(0.68, 0.85, 0.93);
const vec3 GOK_UZAK = vec3(0.52, 0.74, 0.89);
const vec3 BULUT_ALT = vec3(0.78, 0.84, 0.9);
const vec3 BULUT = vec3(0.9, 0.9, 0.88);
const vec3 BULUT_OZ = vec3(0.95, 0.92, 0.85);
const vec3 GUNES_OZ = vec3(0.953, 0.902, 0.8);
const vec3 GUNES_GOVDE = vec3(1.0, 0.86, 0.56);
const vec3 GUNES_KENAR = vec3(0.98, 0.76, 0.5);
const vec3 GECE_YAKIN = vec3(0.26, 0.35, 0.58);
const vec3 GECE_UZAK = vec3(0.13, 0.18, 0.32);
const vec3 GECE_BULUT = vec3(0.1, 0.12, 0.21);
const vec3 AY_KENAR = vec3(0.36, 0.44, 0.66);
const vec3 AY_OZ = vec3(0.9, 0.9, 0.86);
const vec3 AY_GOVDE = vec3(0.72, 0.8, 0.95);
const vec3 AY_HALE = vec3(0.47, 0.56, 0.82);
const vec3 YILDIZ = vec3(0.9, 0.9, 0.84);

float bulut_alan(vec2 s) {
	vec2 cp = s * 0.006;
	vec2 w = vec2(gi_fbm(cp * 0.8 + vec2(3.1, 7.4)), gi_fbm(cp * 0.8 + vec2(7.7, 1.3))) - 0.5;
	return gi_fbm(cp + w * 0.9);
}

// Yıldız parlaklığı (0 = yok). Hücre başına en çok bir yıldız; parlakların bir kısmı + kollu.
float yildiz(vec2 s, float t) {
	vec2 hc = vec2(11.0, 9.0);
	vec2 cell = floor(s / hc);
	float r = gi_hash(cell + vec2(4.4, 9.1));
	if (r > 0.3) {
		return 0.0;
	}
	vec2 c = floor(cell * hc + gi_hash2(cell + 2.2) * (hc - 2.0)) + 1.0;
	vec2 d = s - c;
	float b = 0.6 + 0.4 * gi_hash(cell + 6.6);
	float tw = 0.78 + 0.22 * sin(t * 6.2832 / (3.0 + 3.0 * gi_hash(cell + 8.8)) + 6.2832 * gi_hash(cell + 1.1));
	if (d.x == 0.0 && d.y == 0.0) {
		return b * tw;
	}
	if (r < 0.06 && abs(d.x) + abs(d.y) == 1.0) {
		return b * tw * 0.5;
	}
	return 0.0;
}

void fragment() {
	vec2 px = floor(dunya_sol_ust + SCREEN_UV * dunya_boyut);
	vec3 c = texture(ekran, SCREEN_UV).rgb;
	vec3 col = c;
	float gece = karanlik;
	if (gi_su(px, c)) {
		// ---- kuzey kıyı çizgisi (yukarı doğru küre izleme: kıyıya uzaklık kadar adım kıyıyı asla geçmez)
		float y = px.y;
		for (int i = 0; i < 24; i++) {
			float k = gi_kiyi(vec2(px.x, y));
			if (k < 0.5) {
				break;
			}
			y -= max(k, 1.0);
		}
		float kara_y = floor(y);
		float dd = px.y - kara_y;
		float wob = floor(sin(px.y * 0.85 + zaman * 1.5) * 1.15 * min(1.0, dd / 5.0) + 0.5);
		vec2 m = vec2(px.x + wob, kara_y - dd + 1.0);

		// ---- gökyüzü (yansıma): uzak katman, yürürken suya göre neredeyse sabit
		vec2 s = px - floor(kamera * (1.0 - gok_gecikme)) + floor(ruzgar_ofset * 1.5);
		vec2 isikW = floor(kamera + isik_ekran - (kamera - kamera0) * gok_gecikme);
		vec2 iyar = mix(vec2(22.0, 13.0), vec2(14.0, 9.0), gece);
		float di = length((px - isikW) * vec2(1.0, 1.35));
		float bv = bulut_alan(s);
		float bl = gi_kademe3(bv, vec3(0.55, 0.6, 0.66));
		vec3 gok;
		float a_gok;
		if (gece < 0.5) {
			float gl = gi_kademe3(1.0 - smoothstep(0.0, 300.0, di), vec3(0.3, 0.6, 0.85));
			gok = mix(GOK_UZAK, GOK_YAKIN, gl / 3.0);
			vec3 bc = bl > 2.5 ? BULUT_OZ : (bl > 1.5 ? BULUT : BULUT_ALT);
			gok = mix(gok, bc, bl > 0.5 ? 0.85 : 0.0);
			a_gok = bl > 0.5 ? 0.36 : 0.2;
		} else {
			float gl = gi_kademe3(1.0 - smoothstep(0.0, 170.0, di), vec3(0.35, 0.65, 0.9));
			gok = mix(GECE_UZAK, GECE_YAKIN, gl / 3.0);
			if (bl > 0.5) {
				vec3 bc = (bl < 1.5 && di < 220.0) ? AY_KENAR : GECE_BULUT;
				gok = mix(gok, bc, bl > 1.5 ? 0.55 : 0.4);
			} else if (di > iyar.x * 2.0) {
				float yb = yildiz(s, zaman);
				gok = mix(gok, YILDIZ, yb * 0.9);
			}
			a_gok = 0.6;
		}
		col = mix(col, gok, a_gok);
		bool yildiz_px = gece > 0.5 && bl < 0.5 && di > iyar.x * 2.0 && yildiz(s, zaman) > 0.0;

		// ---- dik nesne aynası (ağaç / çalı / ev / karakter) + kıyı dudağı (kıyının hemen altında kara kenarının ince yansıması)
		bool nesne = gi_ekranda(m) && gi_dik(m) > 0.5;
		bool kirik = sin(px.y * 0.55 + px.x * 0.035 + zaman * 0.8) > 0.93; // dalgacık satırı: yansıma o satırda kırılır
		vec3 ton = mix(vec3(0.70, 0.80, 0.92), vec3(0.80, 0.86, 1.0), gece);
		if (nesne && !kirik) {
			float a_n = mix(0.55, 0.62, gece) * (1.0 - 0.45 * smoothstep(14.0, 44.0, dd));
			col = mix(col, gi_ekran(m) * ton, a_n);
		} else if (dd <= 4.0 && gi_ekranda(m)) {
			col = mix(col, gi_ekran(m) * ton, 0.3);
		}

		// ---- güneş / ay yansıması: krem öz, gövde ve kenar dalgacıklarla yatay şeritlere bölünür; altında sönen pırıltı yolu
		if (!nesne && !yildiz_px) {
			vec2 dv = (px - isikW) / iyar;
			float e = length(dv);
			float kay = floor(sin(px.y * 1.3 + zaman * 1.1) * 3.0);
			float bulut_k = bl > 1.5 ? 0.5 : 1.0;
			vec3 oz = mix(GUNES_OZ, AY_OZ, gece);
			vec3 govde = mix(GUNES_GOVDE, AY_GOVDE, gece);
			vec3 kenar = mix(GUNES_KENAR, AY_HALE, gece);
			if (e < 1.0) {
				bool dolu = fract((px.x + kay + px.y * 3.7) / 8.0) < 1.0 - e * 0.7;
				if (e < 0.4) {
					col = mix(col, oz, 0.9 * bulut_k);
				} else if (e < 0.72 && dolu) {
					col = mix(col, govde, 0.72 * bulut_k);
				} else if (dolu) {
					col = mix(col, kenar, 0.45 * bulut_k);
				}
			} else {
				// pırıltı yolu: diskin altında (ekranda aşağı = izleyene doğru) her iki satırda bir kırık çizgi, aşağı indikçe kısalır
				float yol = mix(46.0, 40.0, gece);
				float dy = px.y - isikW.y;
				if (dy > iyar.y * 0.5 && dy < yol && mod(dy, 2.0) < 1.0) {
					float yk = 1.0 - dy / yol;
					float yari = iyar.x * (0.35 + 0.65 * yk);
					float dx = abs(px.x - isikW.x + kay);
					bool dolu = fract((px.x + kay * 2.0 + dy * 5.3) / 7.0) < 0.35 + 0.45 * yk;
					if (dx < yari && dolu) {
						col = mix(col, dx < yari * 0.4 ? govde : kenar, (0.35 + 0.4 * yk) * bulut_k);
					}
				}
			}
		}
	}
	COLOR = vec4(col, 1.0);
}
