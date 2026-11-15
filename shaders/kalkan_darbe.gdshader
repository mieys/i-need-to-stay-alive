shader_type canvas_item;

// MANA KALKANI HASAR ALMA EFEKTİ "A - Işıyan Yüzey" (madde 566/572; scripts/mana_shield_fx.gd yüzey katmanı).
// Darbe baloncuğa DIŞARIDAN vurur: darbe noktasının çevresinde baloncuğun KENDİ "loop" karesi yuvarlak bir yama hâlinde
// belirip büyür ve söner, vurulan kenar krem parlar. Düz 2B çember (basık / izometrik disk yok, kuzey darbesi de önde).
// Her şey baloncuğun kendi texel ızgarasında: tuval 48x48 texel, merkez = baloncuk merkezi, düğüm ölçeği = BubbleSprite
// ölçeği. Tür rengi kendiliğinden gelir (baloncuğun kendi karesi). Menzilli darbenin seken kıvılcımları GDScript'te.

uniform sampler2D sheet : filter_nearest;
uniform vec4 frame_rect = vec4(0.0, 0.0, 24.0, 24.0);
uniform vec2 sheet_size = vec2(240.0, 240.0);
uniform float hit_angle[4];
uniform float hit_age[4]; // < 0: boş yuva
uniform float canvas_px = 48.0;

const float R = 11.0; // baloncuğun görünen yarıçapı (texel) - mana_shield_fx.gd BUBBLE_R
const vec3 HOT = vec3(1.0, 1.0, 0.94);

vec4 bub(vec2 p) {
	vec2 src = floor(p + 12.0);
	if (src.x < 0.0 || src.y < 0.0 || src.x > 23.0 || src.y > 23.0) {
		return vec4(0.0);
	}
	return texture(sheet, (frame_rect.xy + src + 0.5) / sheet_size);
}

float adist(float a, float b) {
	return abs(mod(a - b + PI, TAU) - PI);
}

// 3 basamaklı maske: dither yok, piksel sanatı gibi basamaklı solma
float step3(float m) {
	return floor(clamp(m, 0.0, 1.0) * 3.0 + 0.5) / 3.0;
}

void fragment() {
	vec2 p = floor(UV * canvas_px) + 0.5 - canvas_px * 0.5;
	float rho = length(p);
	float th = atan(p.y, p.x);
	vec4 b = bub(p);
	float m = 0.0;
	float rim = 0.0;
	for (int i = 0; i < 4; i++) {
		float t = hit_age[i];
		if (t < 0.0) {
			continue;
		}
		float d = adist(th, hit_angle[i]);
		// darbe noktası çevresinde yuvarlak yama: yarıçap 4 -> 13 texel büyür, 0,12-0,5 sn söner
		vec2 P = (R - 0.5) * vec2(cos(hit_angle[i]), sin(hit_angle[i]));
		float r0 = mix(4.0, 13.0, smoothstep(0.0, 0.2, t));
		float fade = 1.0 - smoothstep(0.12, 0.5, t);
		m = max(m, (1.0 - smoothstep(r0 * 0.4, r0, length(p - P))) * fade);
		// vurulan kenar yayı
		float rimw = mix(0.3, 0.75, smoothstep(0.0, 0.12, t));
		if (rho > R - 1.6 && d < rimw) {
			rim = max(rim, (1.0 - smoothstep(0.04, 0.3, t)) * (1.0 - 0.5 * d / rimw));
		}
	}
	float mq = step3(m);
	vec4 outc = vec4(mix(b.rgb, vec3(1.0), 0.2 * mq), min(1.0, b.a * 1.25) * mq);
	if (rim > 0.0 && b.a > 0.0) {
		float rq = step3(rim);
		outc = vec4(mix(b.rgb, HOT, 0.75 * rq), max(outc.a, 0.9 * rq));
	}
	COLOR = outc;
}
