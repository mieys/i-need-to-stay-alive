shader_type canvas_item;

// KAR YAĞIŞI (Ayaz Dağı, 2026-11-12; scripts/weather_snow.gd görünüm alanını kaplayan TEK dikdörtgen çizer). Taneler DÜNYA pikselinde (kamera
// yürüyünce kar dünyada kalır, ekrana yapışmaz), dither yok, her tane tam piksel:
//  - 3 derinlik katmanı: uzak (1 px, yavaş, soluk mavi-beyaz), orta (1 px, beyaz), yakın (artı biçimli 5 px ya da 2x2, hızlı);
//  - her tane kendi evresinde yana salınır, alan rüzgâr yönünde hafif kayar;
//  - sayı yogunluk ile ölçeklenir (0 = hiç; açık havada weather_snow.gd çok seyrek bir "serpinti" verir).
// Alan dünyada kayarak düşer: örnekleme noktası zamanla yukarı kayar -> hücredeki tane aşağı iner (durum tutulmaz, CPU işi yok).

uniform float yogunluk : hint_range(0.0, 1.6) = 0.0;
uniform float ruzgar : hint_range(-1.0, 1.0) = 0.25;      // yatay kayma / düşüş oranı (işaret = rüzgâr yönü)
// Zemin de kar (#c5dadd): taneler saf beyaza yakın ve opak olmalı, yoksa karın üstünde kaybolur (ilk deneme 0.55-0.92 soluktu).
uniform vec4 yakin_renk : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 orta_renk : source_color = vec4(1.0, 1.0, 1.0, 0.92);
uniform vec4 uzak_renk : source_color = vec4(0.94, 0.97, 1.0, 0.78);

varying vec2 world_pos;

float ws_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// S hücre boyu, v düşüş hızı (px/sn), d taban yoğunluk, boy 0 = 1 px, 1 = artı (merkez + 4 kol yarı), 2 = 2x2
float ws_katman(vec2 px, float S, float v, float d, int boy, float t, float tohum) {
	vec2 q = px - floor(vec2(ruzgar * v * t, v * t));
	vec2 c = floor(q / S);
	float h = ws_hash(c + vec2(tohum, tohum * 1.7));
	if (h >= d * yogunluk) {
		return 0.0;
	}
	vec2 o = vec2(ws_hash(c + vec2(3.1, tohum)), ws_hash(c + vec2(tohum, 7.7))) * (S - 6.0) + 3.0;
	o.x += sin(t * (0.7 + h * 1.6) + h * 40.0) * 2.0;
	vec2 l = q - c * S - floor(o);
	if (boy == 0) {
		return l == vec2(0.0) ? 1.0 : 0.0;
	}
	if (boy == 1) {
		if (l == vec2(0.0)) { return 1.0; }
		return abs(l.x) + abs(l.y) == 1.0 ? 0.45 : 0.0;
	}
	return (l.x >= 0.0 && l.y >= 0.0 && l.x < 2.0 && l.y < 2.0) ? 1.0 : 0.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 px = floor(world_pos);
	float t = TIME;
	vec4 c = vec4(0.0);
	float a = ws_katman(px, 11.0, 13.0, 0.30, 0, t, 1.3);
	if (a > 0.0) { c = vec4(uzak_renk.rgb, uzak_renk.a * a); }
	a = ws_katman(px, 17.0, 21.0, 0.30, 0, t, 5.9);
	if (a > 0.0) { c = vec4(orta_renk.rgb, orta_renk.a * a); }
	a = ws_katman(px, 31.0, 33.0, 0.22, 1, t, 9.4);
	if (a > 0.0) { c = vec4(yakin_renk.rgb, yakin_renk.a * a); }
	a = ws_katman(px, 43.0, 41.0, 0.12, 2, t, 13.1);
	if (a > 0.0) { c = vec4(yakin_renk.rgb, yakin_renk.a * a); }
	COLOR = c;
}
