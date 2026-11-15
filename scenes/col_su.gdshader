shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"

// ALTIN KUMLAR VAHA SUYU (madde 631, 2026-11-12): ana haritanın su shader'ının (scenes/su.gdshader, madde 214/424) AYNISI - sade, tek saydamlık,
// seyrek akıntılı dalgacık sırtları, kıyıya hiçbir şey çizmez. Tek fark RENK: çöl "Su/Su" karosu düz mavi collision karosu (görünüşü shader'a bırakılmış),
// ana haritada ise karo kendi rengini taşır (kullanıcı derinliği Tiled'da boyar) -> burada `su_rengi` (setin su rengi #3e8e96: kıyı karolarının sığ su
// gölgesi + köpüğü bu renge göre çizilmiş) kullanılır, sırt rengi de buna göre teal tonlu.
// Kıyıya uzaklık + akış dokuları çöl haritasından pişirilir (assets/map/col_su_mesafe.png + col_su_akis.png: `Godot --headless --path . -s tools/gen_su_dokusu.gd -- col`,
// alan + yollar scripts/map_profiles.gd "col" -> "su_doku"), scripts/water_fx.gd bunları verir; dokusuz çalışırsa düz su.
// Dünya koordinatında, harita karolarının piksel ızgarasında çalışır; harita renk ayarı en sonda.

uniform sampler2D su_mesafe : hint_default_white, filter_linear, repeat_disable; // R = kıyıya uzaklık / 64 dünya px (2 px/teksel)
uniform sampler2D su_akis : hint_default_black, filter_linear, repeat_disable; // RG = 0,5 + 0,5 akış, B = dalgacık doğabilir (4 px/teksel)
uniform vec2 doku_origin = vec2(-576.0, -384.0);
uniform vec2 doku_size = vec2(5248.0, 4864.0);
uniform bool dalgacik_acik = true;

uniform vec4 su_rengi : source_color = vec4(0.243, 0.557, 0.588, 1.0); // #3e8e96 - setin su karosu
uniform float su_alfa = 0.8; // tek saydamlık (karonun kendi alfasıyla çarpılır)
uniform vec4 sirt_renk : source_color = vec4(0.62, 0.86, 0.87, 1.0);
uniform float sirt_guc = 0.6;
uniform vec2 hucre = vec2(26.0, 14.0);
uniform float yogunluk = 0.22;
uniform float omur_hiz = 0.2; // döngü/sn; döngünün %55'i görünür (~2,75 sn)
uniform float akis_hiz = 6.0; // kanal ortasında px/sn (piksel arama alanı 3x5 hücre: akis_hiz x ömür <= ~16 px)

varying vec2 world_pos;

void vertex() {
	// TileMapLayer karolarını yerel koordinatta çizer; MODEL_MATRIX dünyaya çevirir - desen haritaya yapışık.
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec2 doku_uv(vec2 px) {
	return (px + 0.5 - doku_origin) / doku_size;
}

// Dünya pikselinin kıyıya uzaklığı (dünya px); kıyı çizgisi ~0, kıyı sanatının altı < 0.
float kiyi(vec2 px) {
	return texture(su_mesafe, doku_uv(px)).r * 64.0 - 1.0;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + vec2(19.19, 7.73)));
}

// dx = sırt boyunca uzaklık (mutlak), dy = -1 tepe, 0 gövde, +1 kıvrık uç; gölge satırı yok.
bool sekil(float dx, float dy, float hw) {
	return (dy == -1.0 && dx <= hw - 3.0) || (dy == 0.0 && dx <= hw - 1.0) || (dy == 1.0 && dx == hw);
}

bool dalgacik(vec2 px, float t) {
	vec2 base = floor(px / hucre);
	for (int j = -2; j <= 2; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			float r = hash21(cell);
			if (r >= yogunluk) {
				continue;
			}
			float dongu = t * omur_hiz + r / yogunluk * 7.0;
			float phase = fract(dongu);
			if (phase >= 0.55) {
				continue;
			}
			float k = floor(dongu);
			vec2 h = hash22(cell + vec2(k * 3.17, k * 1.93));
			float r2 = hash21(cell + vec2(5.7 + k * 0.731, 13.1));
			float w = 3.0 + floor(r2 * 3.0); // yarı genişlik 3-5 (7-11 px)
			vec2 dogum = cell * hucre + floor(h * hucre);
			vec3 ak = texture(su_akis, doku_uv(dogum)).rgb;
			if (ak.b < 0.5) {
				continue; // kıyıya çok yakın / su dışı
			}
			vec2 f = ak.rg * 2.0 - 1.0;
			vec2 c = floor(dogum + f * akis_hiz * (phase / omur_hiz) + 0.5);
			float hw = floor(w * sin(phase / 0.55 * 3.14159) + 0.5);
			if (hw < 1.0) {
				continue;
			}
			vec2 dp = px - c;
			if (sekil(abs(dp.x), dp.y, hw)) {
				return true;
			}
		}
	}
	return false;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = floor(world_pos);
	float d = kiyi(px);
	vec3 col = su_rengi.rgb;
	float a = su_alfa;
	if (dalgacik_acik && d > 3.5 && dalgacik(px, TIME)) {
		col = mix(col, sirt_renk.rgb, sirt_guc);
		a = max(a, 0.88);
	}
	COLOR = vec4(col, tex.a * a);
	if (COLOR.a > 0.0) { COLOR.rgb = harita_renk(COLOR.rgb); } // çöl renk ayarı (eski col_su ile aynı çağrı) - fragment()'in EN SONUNDA kalmalı
}
