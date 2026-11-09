shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://shaders/bataklik_su_desen.gdshaderinc"

// SUYA GİREN AYAK (madde 525, Kara Bataklık; kullanıcı: "geçerken karakterlerin (uçanlar hariç) ayakları suya girmiş gibi görünmeli, hafif
// derinlik hissi olmalı"). Karakterin sprite'ına DOKUNULMAZ: karakterin hemen üstünde (sprite'ın kardeşi, aynı z) çizilen tek dörtgen, ayağın
// çevresine SUYUN KENDİ RENGİNİ (shaders/bataklik_su_desen.gdshaderinc - çevredeki suyla piksel piksel aynı) yarı saydam boyar:
//  - ŞERİT: su çizgisinden (ayak - derinlik) ayağa kadar, gövde genişliğinde; örtü su çizgisinde %50'den ayakta %90'a koyulaşır -> bacak
//    aşağı indikçe suda kaybolur (derinlik hissi). Dışarıda kalan kısmı suyun üstüne su boyar = görünmez.
//  - SU ÇİZGİSİ: şeridin üstünde 1 px, gövdeden biraz geniş, kesik kesik kıpırdayan açık çizgi (yüzey bacağa değiyor).
//  - HALKALAR: su çizgisi yüksekliğinde merkezlenen, büyüyüp sönen 1 px elips halka (yürürken sık, dururken seyrek); arka yarısı bacakların
//    arkasında kalır (gövde genişliğinin içinde çizilmez).
// Her şey dünya pikselinde, dither yok. Kıyıda çimene taşmaz: `maske` (assets/map/bataklik_su_derinlik.png, 2 dünya px / teksel, 0 = kara,
// 1..255 = su + kıyıya uzaklık) kara olan pikselde hiçbir şey çizilmez. Derinlik ve halka zamanlaması scripts/wade_fx.gd'den (örtü başına uniform).

uniform sampler2D maske : filter_nearest, repeat_disable;
uniform vec2 maske_boyut = vec2(1.0, 1.0);   // teksel
uniform float maske_teksel = 2.0;             // dünya px / teksel
uniform vec2 ayak = vec2(0.0);                // ayak noktası (dünya px, tam sayı)
uniform float yari_genislik = 8.0;            // gövde yarı genişliği (px)
uniform float derinlik = 4.0;                 // su çizgisinin ayaktan yüksekliği (px, tam sayı)
uniform vec4 halkalar = vec4(1.0, 0.0, 1.0, 0.0); // (faz 0..1, güç) x 2
uniform float halka_maks = 9.0;               // halkanın gövde kenarından en çok büyüme payı (px)
uniform float ortu_ust : hint_range(0.0, 1.0) = 0.5;   // su çizgisinin hemen altında örtü (bacak belirgin)
uniform float ortu_alt : hint_range(0.0, 1.0) = 0.9;   // ayakta örtü (ayak neredeyse kaybolur): derinlikle kademeli = derinlik hissi
uniform float cizgi_alfa : hint_range(0.0, 1.0) = 0.85;
uniform float halka_alfa : hint_range(0.0, 1.0) = 0.8;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Elips halka (1 px): merkez = su çizgisi; rx = gövde kenarı + büyüme, ry = rx * 0.42 (oyunun 2:1'e yakın zemin elipsleri).
float halka(vec2 d, float faz, float guc) {
	if (guc <= 0.0 || faz >= 1.0) { return 0.0; }
	float rx = yari_genislik + 1.0 + faz * halka_maks;
	float ry = max(1.5, rx * 0.42);
	// arka yarı bacakların arkasında
	if (d.y < 0.0 && abs(d.x) < yari_genislik * 0.75) { return 0.0; }
	float e = length(vec2(d.x / rx, d.y / ry));
	float px_kalinlik = 0.75 / min(rx, ry * 1.6);
	if (abs(e - 1.0) > px_kalinlik) { return 0.0; }
	return guc * (1.0 - faz) * (1.0 - faz * 0.4);
}

void fragment() {
	vec4 modu = COLOR; // köşe rengi = sahibin modulate'i (görünmezlik / çalı saydamlığı / vuruş rengi örtüye de geçsin)
	vec2 px = floor(world_pos);
	float m = texture(maske, (px + 0.5) / (maske_teksel * maske_boyut)).r;
	if (m <= 0.0) {
		discard;
	}
	vec3 su = bs_su_rengi(px, TIME);
	float dx = px.x - ayak.x;
	float dy = px.y - ayak.y;
	float wy = dy + derinlik; // su çizgisine göre (0 = su çizgisi satırı)
	vec4 c = vec4(0.0);
	if (wy >= 0.0 && dy <= 1.0 && abs(dx) <= yari_genislik) {
		float k = clamp(wy / max(derinlik, 1.0), 0.0, 1.0);
		c = vec4(su, mix(ortu_ust, ortu_alt, k));
	}
	// su çizgisi: şeridin hemen üstü, kesik (kıpırdar)
	if (wy == -1.0 && abs(dx) <= yari_genislik + 1.0) {
		float k = bs_hash12(vec2(dx, floor(TIME * 5.0)));
		if (k > 0.3) {
			float uc = abs(dx) > yari_genislik - 1.0 ? 0.55 : 1.0;
			c = vec4(mix(su, parilti_rengi.rgb, 0.8), cizgi_alfa * uc);
		}
	}
	vec2 d = vec2(dx, wy);
	float h = max(halka(d, halkalar.x, halkalar.y), halka(d, halkalar.z, halkalar.w));
	if (h > 0.0) {
		vec4 hc = vec4(mix(su, parilti_rengi.rgb, 0.75), halka_alfa * h);
		c = c.a > 0.0 ? vec4(mix(c.rgb, hc.rgb, hc.a), max(c.a, hc.a)) : hc;
	}
	if (c.a <= 0.0) {
		discard;
	}
	c.rgb = harita_renk(c.rgb);
	COLOR = c * modu;
}
