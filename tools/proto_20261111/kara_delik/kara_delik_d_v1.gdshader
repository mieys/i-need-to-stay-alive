// ESKI MERKEZ (v1, 2026-11-11 ilk tur: duz kara elips + 1 px foton halkasi) - karsilastirma icin saklandi, kod "D1".
// cevresinde bukulup ice kayar. Ekran dokusu (onunde BackBufferCopy), ornekleme konumu sanat pikseline (0,903 dunya)
// oturtulur -> bukulen zemin de pikselli kalir. Zaman 16 fps'e basamaklanir (sayfa efektleriyle ayni ritim).
// Dugum deligin cocugu (yerel = dunya, olcek 1): lp = delik merkezine gore dunya ofseti.
// Zaman cizelgesi digerleriyle ayni: giris 0,4 sn, cikis 6,0 sn'de baslar, CARPMA 6,25 sn (sesin cokus vurusu), bitis 6,5 sn.
shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float t = 0.0;
uniform float radius = 110.0;
uniform float sq = 0.5;
uniform float px = 0.903;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

float ease_out(float x) {
	x = clamp(x, 0.0, 1.0);
	return 1.0 - (1.0 - x) * (1.0 - x);
}

void fragment() {
	// ekran uv'si / yerel birim (eksen hizali olcek) - turevler dallanmadan ONCE
	vec2 jac = vec2(dFdx(SCREEN_UV.x) / dFdx(lp.x), dFdy(SCREEN_UV.y) / dFdy(lp.y));
	float tq = floor(t * 16.0) / 16.0;
	vec2 ps = (floor(lp / px) + 0.5) * px;
	vec2 q = vec2(ps.x, ps.y / sq);
	float r = length(q);
	float ang = atan(q.y, q.x);

	float size = ease_out(tq / 0.4);
	float extra_spin = 0.0;
	float shock = -1.0;
	if (tq >= 6.0) {
		float u = (tq - 6.0) / 0.5;
		if (u < 0.5) {
			float v = u / 0.5;
			size = 1.0 - 0.8 * v * v;
			extra_spin = 5.0 * v;
		} else {
			size = 0.0;
			shock = (u - 0.5) / 0.5;
		}
	}
	float R = radius * size;
	vec4 outc = vec4(0.0);
	// 1 sanat pikseli kalinliginda elips halka: yatayda 1 px, ust/altta duzlemde 2 px (= ekranda 1 px)
	float ring_w = px * (1.0 + abs(sin(ang)) / sq * 0.5);

	if (size > 0.0 && r < R) {
		float e = r / R;
		float inner = 1.0 - e;
		// bukulme: sabit burulma + zamanla birikip merkezde hizlanan donus + ice kayma (disaridan ornekle)
		float twist = 1.5 * inner * inner + (0.6 * tq + extra_spin) * inner * inner * inner;
		float ang_s = ang + twist;
		float rho_s = r + (R - r) * 0.42 * inner;
		vec2 qs = rho_s * vec2(cos(ang_s), sin(ang_s));
		vec2 p_s = vec2(qs.x, qs.y * sq);
		vec3 col = texture(screen_tex, SCREEN_UV + (p_s - lp) * jac).rgb;
		// karartma bantlari (dither yok), mor-lacivert kayma; dis bant zemini oldugu gibi birakir
		float b = 1.0;
		if (e < 0.78) b = 0.86;
		if (e < 0.52) b = 0.68;
		if (e < 0.32) b = 0.46;
		col = col * b + vec3(0.09, 0.02, 0.17) * (1.0 - b);
		float eh = 0.13 * radius * max(size, 0.35);
		if (r < eh) {
			col = vec3(0.025, 0.01, 0.045);
		} else if (r < eh + ring_w) {
			col = vec3(1.0, 0.95, 0.99);
		} else if (r < eh + ring_w * 2.0 && q.y < 0.0) {
			col = mix(col, vec3(0.72, 0.53, 1.0), 0.66);
		} else if (abs(r - 0.24 * radius * size) < ring_w * 0.5 && q.y < 0.0) {
			col = mix(col, vec3(0.72, 0.53, 1.0), 0.33);
		}
		// alan siniri: 1 px soluk mor
		if (r > R - ring_w) {
			col = mix(col, vec3(0.6, 0.4, 0.95), 0.33);
		}
		outc = vec4(col, 1.0);
	}
	if (shock >= 0.0) {
		// sok dalgasi: halkanin icinde zemin disa kirilir + onde ince krem kenar; merkezde 1 kare parlama
		float rs = mix(0.1, 1.0, ease_out(shock)) * radius;
		float band_w = 9.0;
		float d = r - rs;
		if (abs(d) < band_w) {
			float k = 1.0 - abs(d) / band_w;
			float push = 6.0 * k * (1.0 - shock);
			vec2 qs = (r + push) * vec2(cos(ang), sin(ang));
			vec2 p_s = vec2(qs.x, qs.y * sq);
			vec3 col = texture(screen_tex, SCREEN_UV + (p_s - lp) * jac).rgb;
			col = col * (0.85 + 0.15 * shock);
			if (d > band_w - ring_w * 2.0 && shock < 0.85) {
				col = mix(col, vec3(1.0, 0.95, 0.99), shock < 0.5 ? 1.0 : 0.66);
			}
			outc = vec4(col, 1.0);
		}
		if (shock < 0.34 && r < 12.0 * (1.0 - shock * 2.0)) {
			outc = vec4(1.0, 0.96, 1.0, 1.0);
		}
	}
	COLOR = outc;
}
