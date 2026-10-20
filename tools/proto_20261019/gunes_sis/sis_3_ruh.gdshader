shader_type canvas_item;
render_mode unshaded;

// SİSLİ HAVA 3 - "SİS PERDESİ + RUH IŞIKLARI" (madde 282 prototipi): 1'in yer sisi (daha hafif) + 2'nin uzaklık pusu
// (daha hafif) BİRLİKTE, üstüne ürkütücü ayrıntı: sisin derin (uzak) yerlerinde arada bir beliren, havada salınan soluk
// yeşil RUH IŞIKLARI (bataklık ışığı). Sadece oyuncudan uzakta görünür ve yaklaşınca söner -> yaratık / XP ile karışmaz.
#include "res://tools/proto_20261019/gunes_sis/gs_ortak.gdshaderinc"
#include "res://tools/proto_20261019/gunes_sis/sis_ortak.gdshaderinc"

uniform vec3 sis_gunduz : source_color = vec3(0.6, 0.67, 0.66);
uniform vec3 isik_renk : source_color = vec3(0.62, 1.0, 0.78);
uniform vec2 net_yaricap = vec2(190.0, 105.0);

// Ruh ışığı: 150 px hücrelerin ~%42'sinde, 5-8 sn'lik döngüde belirip söner, yavaşça salınır. Çekirdek 2x2 texel + 2 kademe hale.
float ruh(vec2 px, out float hale) {
	hale = 0.0;
	vec2 cell = floor(px / 150.0);
	float best = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = cell + vec2(float(x), float(y));
			float h = hash12(c + 3.3);
			if (h > 0.42) {
				continue;
			}
			float periyot = 5.0 + 3.0 * hash12(c + 8.1);
			float faz = fract(zaman / periyot + hash12(c + 1.9));
			float gorun = smoothstep(0.0, 0.25, faz) * (1.0 - smoothstep(0.6, 0.9, faz));
			vec2 m = (c + 0.2 + 0.6 * hash22(c)) * 150.0;
			m += vec2(sin(zaman * 0.45 + h * 30.0) * 9.0, sin(zaman * 0.9 + h * 17.0) * 4.0 - faz * 10.0);
			vec2 d = abs(px - floor(m) - 0.5);
			float dd = max(d.x, d.y * 1.2);
			if (dd < 1.1) {
				best = max(best, gorun);
			} else if (dd < 4.2) {
				hale = max(hale, gorun * (dd < 2.4 ? 0.6 : 0.28));
			}
		}
	}
	return best;
}

void fragment() {
	vec2 px = gs_texel(SCREEN_UV);
	vec2 uv = gs_uv(px);
	vec3 base = texture(ekran, SCREEN_UV).rgb;
	vec3 col = sis_renk_ayari(base, 0.38, vec3(0.9, 0.97, 0.95), 0.86);
	vec3 sr = sis_rengi(sis_gunduz);
	// uzaklık pusu (hafif)
	float d = length((px - oyuncu) / net_yaricap);
	// büyük, sürüklenen kümelerle bozulur (halka / hedef tahtası gibi okunmasın); oyuncunun dibi açık kalır
	float bozul = (yer_sisi(px, 0.0055) - 0.5) * 1.5 * smoothstep(0.3, 1.0, d);
	float uz = gs_kademe(smoothstep(0.8, 2.2, d + bozul), 4.0);
	col = mix(col, sr, uz * 0.42 * sis_k);
	// yer sisi (hafif)
	float m = gs_kademe(smoothstep(0.4, 0.76, yer_sisi(px, 0.0062)), 4.0);
	col = mix(col, sr * 1.05, m * 0.25 * mix(0.45, 1.0, aralik(px, 18.0, 70.0)) * sis_k);
	col *= mix(1.0, vinyet(uv, 0.24), sis_k);
	// ruh ışıkları: sadece uzakta (yakında söner)
	float hale;
	float r = ruh(px, hale);
	float uzakta = smoothstep(0.95, 1.3, d);
	col += isik_renk * (r * 0.75 + hale * 0.24) * uzakta * sis_k;
	COLOR = vec4(col, 1.0);
}
