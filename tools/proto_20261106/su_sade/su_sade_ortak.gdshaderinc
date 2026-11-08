// SADE SU prototipleri ortak parçası (2026-11-06, oyuna bağlı DEĞİL). Kullanıcı: "sudaki shaderlar için daha sade 4 prototip".
// Oyundaki `scenes/su.gdshader` (C3 Akıntılı Dalgacık, madde 214) ile AYNI dokular / renkler / uniform adları: WaterFx.attach'ın
// verdiği su_mesafe + su_akis + doku_origin/doku_size burada da çalışır. Fark yalnız süslerde: hepsi noktasız (dither yok),
// her prototip TEK bir hareket fikri. DERİNLİK TONU YOK (kullanıcı: "derinlik renk değişimini istemiyorum, onları kendim yapıyorum"):
// suyun rengi = karonun KENDİ rengi (kullanıcının boyadığı), shader yalnız tek saydamlık + süs ekler. (Oyundaki C3 karo rengini
// su_renk/derin_renk ile EZİYOR - boyanan derinlik oyunda görünmez.)
#include "res://shaders/harita_renk.gdshaderinc"

uniform sampler2D su_mesafe : hint_default_white, filter_linear, repeat_disable; // R = kıyıya uzaklık / 64 dünya px
uniform sampler2D su_akis : hint_default_black, filter_linear, repeat_disable; // RG = 0,5 + 0,5 akış, B = dalgacık doğabilir
uniform vec2 doku_origin = vec2(-576.0, -384.0);
uniform vec2 doku_size = vec2(5248.0, 4864.0);

uniform float su_alfa = 0.8; // tek saydamlık her yerde (karonun kendi alfasıyla çarpılır)
uniform vec4 sirt_renk : source_color = vec4(0.6, 0.79, 0.9, 1.0);
uniform float kiyi_guc = 0.5; // 1 px kıyı çizgisi

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec2 doku_uv(vec2 px) {
	return (px + 0.5 - doku_origin) / doku_size;
}

float kiyi(vec2 px) {
	return texture(su_mesafe, doku_uv(px)).r * 64.0 - 1.0;
}

vec2 akis(vec2 px) {
	return texture(su_akis, doku_uv(px)).rg * 2.0 - 1.0;
}

bool mavi_mi(vec3 c) {
	return c.b > c.g + 0.03 && c.b > c.r + 0.1;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + vec2(19.19, 7.73)));
}

vec2 grad2(vec2 p) {
	float a = hash21(p) * 6.2831853;
	return vec2(cos(a), sin(a));
}

float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(grad2(i), f);
	float b = dot(grad2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(grad2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(grad2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return clamp(0.5 + mix(mix(a, b, u.x), mix(c, d, u.x), u.y), 0.0, 1.0);
}

float fbm2(vec2 p) {
	vec2 q = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.1 + vec2(3.1, 1.7);
	return gnoise(p) * 0.62 + gnoise(q) * 0.38;
}

// Su katmanına boyanmış çimen karosu (madde 85): oyundaki gibi.
vec4 cimen_karosu(vec4 tex) {
	vec4 c = vec4(mix(tex.rgb, vec3(0.18, 0.48, 0.68), 0.12), tex.a * 0.73);
	if (c.a > 0.0) { c.rgb = harita_renk_d(c.rgb, world_pos); }
	return c;
}

// Taban: karonun kendi rengi, tek saydamlık - kıyıya uzaklığa göre ton değişimi YOK.
void taban(vec4 tex, out vec3 col, out float a) {
	col = tex.rgb;
	a = su_alfa;
}

// 1 px açık kıyı çizgisi (hareketsiz).
void kiyi_cizgisi(float d, inout vec3 col, inout float a) {
	if (d < 1.2) {
		col = mix(col, sirt_renk.rgb, kiyi_guc);
		a = 0.82;
	}
}

vec4 bitir(vec4 tex, vec3 col, float a) {
	vec4 c = vec4(col, tex.a * a);
	if (c.a > 0.0) { c.rgb = harita_renk_d(c.rgb, world_pos); } // harita renk ayarı EN SONDA (oyundaki gibi)
	return c;
}
