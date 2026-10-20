shader_type canvas_item;
render_mode unshaded;

// GÜN IŞIĞI C - "BULUT ARASI GÜNEŞ" (madde 282 prototipi): huzme YOK. Güneş ve bulut tek bir sistem: rüzgarla sürüklenen
// büyük bulut gölgelerinin arasında kalan yerler güneş alır (sıcak, hafif aydınlık), gölgeler SERİN (mavimsi, biraz koyu) -
// sadece karartma değil renk de değişir. 3 düz kademe (güneş / yarı / gölge), kenarlar temiz. Zemine bağlı (paralaks 0).
// Mevcut bulut gölgesi + huzmenin YERİNE geçer. Ekranı okur (renk çarpımı için).
#include "res://tools/proto_20261019/gunes_sis/gs_ortak.gdshaderinc"

uniform sampler2D ekran : hint_screen_texture, filter_nearest;
uniform float kaplama = 0.46;
uniform float olcek = 0.0017;
uniform vec3 golge_carpan : source_color = vec3(0.8, 0.85, 0.97);
uniform vec3 gunes_carpan : source_color = vec3(1.06, 1.03, 0.96);
uniform vec3 gunes_ekle : source_color = vec3(0.045, 0.032, 0.008);
uniform float kenar_isik = 0.03;   // gölge kenarının güneş tarafında 1-2 texel'lik ılık şerit

float bulut(vec2 px) {
	vec2 cp = (px + ruzgar_ofset) * olcek;
	vec2 warp = vec2(fbm(cp * 0.7 + zaman * 0.004), fbm(cp * 0.7 + vec2(9.2, 3.7) - zaman * 0.003)) - 0.5;
	float c = fbm(cp + warp * 0.9);
	float esik = 1.0 - kaplama;
	return smoothstep(esik - 0.06, esik + 0.1, c);
}

void fragment() {
	vec2 px = gs_texel(SCREEN_UV);
	vec3 base = texture(ekran, SCREEN_UV).rgb;
	float b = bulut(px);
	float k = gs_kademe(b, 3.0);      // 0 güneş, 0,5 yarı, 1 gölge
	vec3 g = base * gunes_carpan + gunes_ekle;
	vec3 s = base * golge_carpan;
	vec3 col = mix(g, s, k);
	// güneş tarafındaki kenar şeridi: gölgeye çok yakın ama hâlâ güneşte
	if (k == 0.0 && b > 0.12) {
		col += vec3(1.0, 0.9, 0.6) * kenar_isik;
	}
	COLOR = vec4(col, 1.0);
}
