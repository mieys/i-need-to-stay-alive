shader_type canvas_item;

// KALKAN DARBE PROTOTİPİ (oyuna bağlı DEĞİL, tools/proto_20261111/kalkan_darbe/): darbe baloncuğa DIŞARIDAN vurur.
// Her şey baloncuğun KENDİ 24x24 karesinden ve kendi texel ızgarasında (1 texel = baloncuk pikseli): tuval 48x48 texel,
// merkez = baloncuk merkezi. Düz 2D çember: basık/izometrik disk YOK, kuzey darbesi de önde (üst kenarda) çizilir.
//   1 A Işıyan Yüzey   : darbe noktasının çevresinde baloncuğun kendi sanatı belirir (açısal maske, 3 basamak), kenar parlar
//   2 B Esneyen Zar    : baloncuk görünür, darbe yanı İÇERİ çöker ve yaylanarak geri döner (yanlar hafif şişer)
//   3 C Dalga Halkası  : darbe noktasından baloncuk yüzeyine yayılan 2 halka (su zarına damla gibi)
//   4 D Seken Darbe    : (kıvılcım ve iz GDScript'te) kenar yayı parlar, tüm kenar bir an görünür, dış kenar bir texel titrer
//   5 E = A + D        : darbe başına tür (hit_kind): yakın dövüş 1 = A yaması, menzilli 4 = D sekmesi (iz/gecikme yok,
//                        mermi zaten kendisi gelir) - kullanıcı 2026-11-11: "A'yı seçiyorum, menzilli hasarda D'nin seken darbesi"

uniform sampler2D sheet : filter_nearest;
uniform vec4 frame_rect = vec4(0.0, 0.0, 24.0, 24.0);
uniform vec2 sheet_size = vec2(240.0, 240.0);
uniform int variant = 1;
uniform float hit_angle[4];
uniform float hit_age[4];
uniform float hit_kind[4]; // 1 = A katmanı, 4 = D katmanı (variant 1/4'te hepsi aynı)
uniform vec3 light_col = vec3(0.8, 1.0, 0.7);
uniform float canvas_px = 48.0;
uniform float contact_delay = 0.06;

const float R = 11.0;
const float DENT = 4.6; // B: en derin çöküş (texel); hit_variant.gd DENT ile aynı
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

float step3(float m) {
	return floor(clamp(m, 0.0, 1.0) * 3.0 + 0.5) / 3.0;
}

vec4 layer_a(vec2 p, float rho, float th) {
	vec4 outc = vec4(0.0);
	vec4 b = bub(p);
	float m = 0.0;
	float rim = 0.0;
	for (int i = 0; i < 4; i++) {
		float t = hit_age[i];
		if (t < 0.0 || hit_kind[i] != 1.0) {
			continue;
		}
		float d = adist(th, hit_angle[i]);
		// darbe noktasının çevresinde yuvarlak yama (pasta dilimi değil): yarıçap 4 -> 13 texel büyür
		vec2 P = (R - 0.5) * vec2(cos(hit_angle[i]), sin(hit_angle[i]));
		float r0 = mix(4.0, 13.0, smoothstep(0.0, 0.2, t));
		float fade = 1.0 - smoothstep(0.12, 0.5, t);
		m = max(m, (1.0 - smoothstep(r0 * 0.4, r0, length(p - P))) * fade);
		float rimw = mix(0.3, 0.75, smoothstep(0.0, 0.12, t));
		if (rho > R - 1.6 && d < rimw) {
			rim = max(rim, (1.0 - smoothstep(0.04, 0.3, t)) * (1.0 - 0.5 * d / rimw));
		}
	}
	float mq = step3(m);
	outc = vec4(mix(b.rgb, vec3(1.0), 0.2 * mq), min(1.0, b.a * 1.25) * mq);
	if (rim > 0.0 && b.a > 0.0) {
		float rq = step3(rim);
		outc = vec4(mix(b.rgb, HOT, 0.75 * rq), max(outc.a, 0.9 * rq));
	}
	return outc;
}

vec4 layer_d(vec2 p, float rho, float th) {
	vec4 outc = vec4(0.0);
	vec4 b = bub(p);
	float rimall = 0.0;
	float arc = 0.0;
	float pulse = 0.0;
	for (int i = 0; i < 4; i++) {
		float t = hit_age[i] - contact_delay;
		if (t < 0.0 || hit_kind[i] != 4.0) {
			continue;
		}
		float d = adist(th, hit_angle[i]);
		rimall = max(rimall, 0.8 * (1.0 - smoothstep(0.05, 0.34, t)));
		if (d < 0.7) {
			arc = max(arc, (1.0 - smoothstep(0.03, 0.28, t)) * (1.0 - smoothstep(0.25, 0.7, d)));
		}
		if (t > 0.02 && t < 0.15 && rho > R + 0.4 && rho < R + 1.4) {
			pulse = max(pulse, (1.0 - (t - 0.02) / 0.13) * (1.0 - smoothstep(0.5, 1.5, d)));
		}
	}
	bool onrim = rho > R - 1.6 && b.a > 0.0;
	if (onrim) {
		outc = vec4(b.rgb, min(1.0, b.a * 1.4) * rimall);
		if (arc > 0.0) {
			float aq = step3(arc);
			outc = vec4(mix(b.rgb, HOT, 0.4 + 0.5 * aq), max(outc.a, 0.5 + 0.45 * aq));
		}
	}
	if (pulse > 0.0) {
		outc = vec4(light_col, 0.75 * step3(pulse));
	}
	return outc;
}

void fragment() {
	vec2 p = floor(UV * canvas_px) + 0.5 - canvas_px * 0.5;
	float rho = length(p);
	float th = atan(p.y, p.x);
	vec4 outc = vec4(0.0);

	if (variant == 1) {
		outc = layer_a(p, rho, th);
	} else if (variant == 2) {
		float dent = 0.0;
		float vis = 0.0;
		float flash = 0.0;
		for (int i = 0; i < 4; i++) {
			float t = hit_age[i];
			if (t < 0.0) {
				continue;
			}
			float s = t < 0.05 ? t / 0.05 : exp(-(t - 0.05) * 7.0) * cos((t - 0.05) * 24.0);
			float d = adist(th, hit_angle[i]);
			dent += DENT * s * (exp(-pow(d / 0.42, 2.0)) - 0.3 * exp(-pow((d - 1.6) / 0.5, 2.0)));
			vis = max(vis, 0.85 * (1.0 - smoothstep(0.28, 0.65, t)));
			if (d < 0.6 && t < 0.2) {
				flash = max(flash, (1.0 - t / 0.2) * (1.0 - d / 0.6));
			}
		}
		float k = max((R - dent) / R, 0.3);
		vec2 src = p / k;
		vec4 b = bub(src);
		outc = vec4(b.rgb, min(1.0, b.a * 1.2) * vis);
		if (flash > 0.0 && length(src) > R - 1.6 && b.a > 0.0) {
			float fq = step3(flash);
			outc = vec4(mix(b.rgb, HOT, 0.7 * fq), max(outc.a, 0.9 * fq));
		}
	} else if (variant == 3) {
		vec4 b = bub(p);
		float vis = 0.0;
		float ring = 0.0;
		for (int i = 0; i < 4; i++) {
			float t = hit_age[i];
			if (t < 0.0) {
				continue;
			}
			vis = max(vis, 0.6 * (1.0 - smoothstep(0.3, 0.7, t)));
			vec2 P = (R - 0.5) * vec2(cos(hit_angle[i]), sin(hit_angle[i]));
			float dp = length(p - P);
			for (int j = 0; j < 2; j++) {
				float tj = t - float(j) * 0.13;
				if (tj < 0.0) {
					continue;
				}
				float u = clamp(tj / 0.5, 0.0, 1.0);
				float r = 23.0 * (1.0 - (1.0 - u) * (1.0 - u));
				if (abs(dp - r) < 0.6 && u < 1.0) {
					ring = max(ring, (1.0 - u) * (j == 0 ? 1.0 : 0.7));
				}
			}
		}
		outc = vec4(b.rgb, b.a * vis);
		if (ring > 0.0 && b.a > 0.0) {
			float rq = step3(ring);
			outc = vec4(mix(b.rgb, HOT, 0.3 + 0.55 * rq), max(outc.a, 0.3 + 0.6 * rq));
		}
	} else if (variant == 4) {
		outc = layer_d(p, rho, th);
	} else if (variant == 5) {
		vec4 la = layer_a(p, rho, th);
		vec4 ld = layer_d(p, rho, th);
		outc = ld.a > la.a ? ld : la;
	}
	COLOR = outc;
}
