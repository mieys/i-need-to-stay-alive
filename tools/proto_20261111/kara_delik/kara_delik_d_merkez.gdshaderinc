// Hadime kara delik prototipi D - ORTAK parca (2026-11-11): zaman cizelgesi + MERKEZ (kara kure, yatik birikim diski, bukulen
// isik yayi, foton halkasi). Zemin shader'i (kara_delik_d.gdshader, center_mode 0 = merkezi kendisi cizer) ve on katman
// (kara_delik_d_on.gdshader, yaratiklarin USTUNDE: merkeze varan "yutulur") ayni kodu kullanir.

float kd_ease_out(float x) {
	x = clamp(x, 0.0, 1.0);
	return 1.0 - (1.0 - x) * (1.0 - x);
}

// giris 0,4 sn, cikis 6,0 sn'de: 0,25 sn hizlanip buzulur, CARPMA 6,25 sn (sesin cokus vurusu), sok 6,25-6,5 sn.
void kd_timeline(float t, out float tq, out float size, out float extra_spin, out float shock) {
	tq = floor(t * 16.0) / 16.0;
	size = kd_ease_out(tq / 0.4);
	extra_spin = 0.0;
	shock = -1.0;
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
}

// duz alfali "ustune koy" (a = 0 dokunmaz)
vec4 kd_over(vec4 under, vec3 c, float a) {
	if (a <= 0.0) {
		return under;
	}
	float oa = a + under.a * (1.0 - a);
	vec3 rgb = (c * a + under.rgb * under.a * (1.0 - a)) / max(oa, 0.0001);
	return vec4(rgb, oa);
}

// ps: sanat pikseline oturmus yerel konum (delik merkezine gore dunya). glow_band: diskin disindaki soluk mor bant
// (yalniz zeminde - yaratiklarin ustunde onlari morartirdi). Donus (rgb, a): a = 0 bos.
vec4 kd_center(vec2 ps, float size, float extra_spin, float tq, float px, bool glow_band) {
	vec4 acc = vec4(0.0);
	float hr = 11.0 * size;
	if (hr <= 1.5) {
		return acc;
	}
	vec3 C_DEEP = vec3(0.26, 0.10, 0.45);
	vec3 C_VIO = vec3(0.49, 0.25, 0.80);
	vec3 C_LAV = vec3(0.72, 0.53, 1.0);
	vec3 C_CREAM = vec3(1.0, 0.86, 0.98);
	vec3 C_WHITE = vec3(1.0, 0.97, 1.0);
	vec2 d = ps - vec2(0.0, -6.0 * size);
	float rs = length(d);
	// disk neredeyse yandan gorunur (0,22): on bant kurenin ortasindan gecer, kurenin alt kismi bandin altinda kalir
	vec2 de = vec2(d.x, d.y / 0.22);
	float rd = length(de);
	float a = atan(de.y, de.x);
	float din = hr * 1.35;
	float dout = hr * 2.5;
	float spin_w = 1.8 + extra_spin * 2.0;
	bool in_disk = rd > din && rd < dout;
	vec3 dc = C_DEEP;
	float dk = 0.0;
	if (in_disk) {
		float x = (rd - din) / (dout - din);
		float dop = 0.5 - 0.5 * cos(a);
		float streak = fract(a * 3.0 / 6.28318 + 1.3 * log(rd / hr) - tq * spin_w * 0.5);
		float heat = (1.0 - x) * 0.62 + dop * 0.45 + (streak < 0.34 ? 0.12 : -0.06);
		if (heat > 0.98) dc = C_WHITE;
		else if (heat > 0.78) dc = C_CREAM;
		else if (heat > 0.55) dc = C_LAV;
		else if (heat > 0.32) dc = C_VIO;
		else dc = C_DEEP;
		dk = x > 0.8 ? 0.66 : 1.0;
	}
	if (glow_band && rd >= dout && rd < dout * 1.16) {
		acc = kd_over(acc, C_VIO, 0.33);
	}
	bool front = d.y > 0.0;
	if (in_disk && !front) {
		acc = kd_over(acc, dc, dk);
	}
	// bukulen yay: kurenin ust yarisi cevresinde, tepeye dogru kalinlasir
	float arc_in = hr + px;
	float up = clamp(-d.y / max(rs, 0.001), 0.0, 1.0);
	float arc_th = px * (1.0 + 1.4 * up * up);
	if (d.y < 0.0 && rs >= arc_in && rs < arc_in + arc_th) {
		float h2 = 0.55 + 0.35 * clamp(-d.x / max(rs, 0.001), -1.0, 1.0) + 0.25 * up;
		acc = kd_over(acc, h2 > 0.9 ? C_CREAM : (h2 > 0.62 ? C_LAV : C_VIO), 1.0);
	}
	// alttaki ikincil goruntu: kurenin altinda ince yay
	if (d.y > 0.0 && rs >= arc_in && rs < arc_in + px) {
		acc = kd_over(acc, C_LAV, 0.66);
	}
	if (rs < hr) {
		acc = kd_over(acc, vec3(0.02, 0.006, 0.035), 1.0);
	} else if (rs < hr + px) {
		acc = kd_over(acc, d.x < 0.0 ? C_WHITE : C_CREAM, 1.0);
	}
	if (in_disk && front) {
		acc = kd_over(acc, dc, dk);
	}
	return acc;
}
