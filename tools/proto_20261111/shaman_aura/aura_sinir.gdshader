shader_type canvas_item;

// PROTOTİP (oyuna bağlı DEĞİL): Shaman E (Kalkan Totemi) AURA SINIRI - 4 görünüş, tek shader (variant 0-3).
// Sınır = totem_shield.gd totem_radius (220; "Geniş Alan" x1,3) - kalkan/şerit verilen alanın kenarı (mesafe = DAİRE).
// PARAZİTSİZ (madde 562 ek 4 / totem_shield_link.gdshader ile aynı kural): her parça kendi DÜNYA ızgara hücresinin
// (cell = karakter pikseli 0,903) MERKEZİNE göre karar verir -> hücre ya tam dolu ya boş, dither yok, düz tonlar.
// Düğüm top_level (0,0)'da: yerel köşe = dünya.
//   0 A İnce Halka      : 1 hücre açık mavi çizgi + 1 hücre koyu dış dudak + soluk iç dudak; çizgide yavaşça dolaşan parlak kuyruklu yay.
//   1 B Işıyan Kenar    : çizgi yok; kenardan içe 4 düz bant (parlak -> soluk), bant sınırları sırayla 1 hücre nefes alır.
//   2 C Işık Perdesi    : yerde ince çizgi + üstünden yükselen alçak ışık duvarı (silindir: arka yay arkada, ön yay önde), sütun boyları
//                         yavaşça dalgalanır, seyrek ışık zerreleri yukarı süzülür.
//   3 D Köşebentler     : sürekli çizgi yok; 8 kalın yay işareti, iki ucunda içe dönen kanca (seçim köşebenti dili), parlaklık
//                         işaretten işarete sırayla dolaşır (dönme YOK).

uniform int variant = 0;
uniform float cell = 0.903;
uniform vec2 center;
uniform float radius = 220.0;    // dünya
uniform float time_s = 0.0;
uniform float alpha_mult = 1.0;  // belirme / sönme
uniform float grow = 1.0;        // 0..1 açılış (perde boyu)
uniform vec4 c_dark : source_color = vec4(0.078, 0.204, 0.420, 1.0);
uniform vec4 c_base : source_color = vec4(0.290, 0.659, 1.0, 1.0);   // E mavisi (kalkan şeridiyle aynı)
uniform vec4 c_light : source_color = vec4(0.651, 0.847, 1.0, 1.0);
uniform vec4 c_hot : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

// a'dan b'ye saat yönünde (ekran y aşağı) açı farkı [0, TAU)
float ang_diff(float a, float b) {
	return mod(a - b + 4.0 * TAU, TAU);
}

vec4 variant_a(float e, float ang, float r) {
	vec4 col = vec4(0.0);
	float breath = 0.80 + 0.12 * sin(time_s * TAU / 4.0);
	if (e > 0.5 && e <= 1.5) {
		col = vec4(c_dark.rgb, 0.58);
	} else if (e >= -1.5 && e < -0.5) {
		col = vec4(c_base.rgb, 0.24);
	} else if (abs(e) <= 0.5) {
		col = vec4(c_light.rgb, breath);
		// dolaşan kuyruklu yay: 9 sn'de bir tur, baş önde, kuyruk 3 düz basamakta söner
		float head = time_s * TAU / 9.0;
		float behind = ang_diff(head, ang) * r; // hücre cinsinden yay boyu
		if (behind < 5.0) {
			col = vec4(c_hot.rgb, 1.0);
		} else if (behind < 16.0) {
			col = vec4(mix(c_light.rgb, c_hot.rgb, 0.55), 0.95);
		} else if (behind < 34.0) {
			col = vec4(c_light.rgb, min(1.0, breath + 0.12));
		}
	}
	return col;
}

vec4 variant_b(float e) {
	float s = 0.5 + 0.5 * sin(time_s * TAU / 3.6);
	float b2 = 3.0 + floor(s * 2.0 + 0.5);
	float b3 = 6.0 + floor(s * 3.0 + 0.5);
	float b4 = 11.0 + floor(s * 5.0 + 0.5);
	vec4 col = vec4(0.0);
	if (e <= 0.5 && e >= -1.0) {
		col = vec4(c_light.rgb, 0.78);
	} else if (e < -1.0 && e >= -b2) {
		col = vec4(c_base.rgb, 0.40);
	} else if (e < -b2 && e >= -b3) {
		col = vec4(c_base.rgb, 0.21);
	} else if (e < -b3 && e >= -b4) {
		col = vec4(c_base.rgb, 0.10);
	}
	return col;
}

vec4 variant_c(vec2 rel, float e, float r) {
	vec4 col = vec4(0.0);
	if (abs(e) <= 0.5) {
		col = vec4(c_light.rgb, 0.72);
	}
	float X = rel.x;
	if (abs(X) >= r) {
		return col;
	}
	float s = sqrt(r * r - X * X);
	// perde boyu sütundan sütuna YUMUŞAK dalga (rastgele değil -> tepe çizgisi parazitsiz piksel dalgası), dalga çevre boyunca akar;
	// ön ve arka yay ters yönde akar (silindir dönüyor gibi). Boy 7..13 hücre, tam hücre adımlarıyla.
	float hb = s - rel.y;   // ön yay (alt) üstündeki yükseklik
	float ht = -s - rel.y;  // arka yay (üst) üstündeki yükseklik
	float Hf = floor(10.0 + 3.0 * sin(X * 0.075 + time_s * 1.2) + 0.5) * grow;
	float Hb = floor(10.0 + 3.0 * sin(X * 0.075 - time_s * 1.2 + 2.1) + 0.5) * grow;
	float best = -1.0;
	float H = 1.0;
	float wall_a = 1.0;
	if (hb > 0.5 && hb <= Hf) {
		best = hb;
		H = Hf;
		wall_a = 0.80; // ön perde iç zemini örtmesin: biraz daha soluk
	} else if (ht > 0.5 && ht <= Hb) {
		best = ht;
		H = Hb;
	}
	if (best > 0.0) {
		float f = best / max(H, 1.0);
		float a = f < 0.25 ? 0.52 : (f < 0.6 ? 0.32 : 0.17);
		col = vec4(c_base.rgb, a * wall_a);
		if (best > H - 1.0) {
			col = vec4(c_light.rgb, 0.62 * wall_a); // perdenin tepe çizgisi
		}
		// seyrek yükselen zerre (1 hücre), tepeyi geçip söner
		if (hash11(X * 1.37 + 11.0) > 0.82) {
			float hm = fract(time_s * 0.4 + hash11(X + 5.0)) * (H + 4.0);
			if (abs(best - hm) <= 0.5) {
				col = vec4(c_hot.rgb, 0.95 * wall_a);
			}
		}
	} else if (hash11(X * 1.37 + 11.0) > 0.82) {
		// tepenin üstüne çıkan zerre (perde dışında, son 4 hücre)
		float h2 = hb > 0.5 && hb <= Hf + 4.0 ? hb : (ht > 0.5 && ht <= Hb + 4.0 ? ht : -1.0);
		float H2 = hb > 0.5 && hb <= Hf + 4.0 ? Hf : Hb;
		if (h2 > 0.0) {
			float hm = fract(time_s * 0.4 + hash11(X + 5.0)) * (H2 + 4.0);
			if (abs(h2 - hm) <= 0.5) {
				col = vec4(c_light.rgb, 0.7 * (1.0 - (hm - H2) / 4.0));
			}
		}
	}
	return col;
}

vec4 variant_d(float e, float ang, float r) {
	const float N = 8.0;
	float seg = TAU / N;
	float a0 = ang + seg * 0.5; // işaretler ana yönlerde ortalı
	float idx = floor(mod(a0, TAU) / seg);
	float u = fract(mod(a0, TAU) / seg); // işaret içinde 0..1
	float half_span = 0.2;                // işaret yarı açısı (dilim payı) -> 18 derece yay
	float du = (u - 0.5) * seg * r;       // işaret ortasından yay boyu (hücre)
	float half_len = half_span * seg * r;
	float from_end = half_len - abs(du);  // uca uzaklık (hücre)
	vec4 col = vec4(0.0);
	if (from_end < -0.5) {
		return col;
	}
	// parlaklık işaretten işarete dolaşır (4 sn'de tur)
	float w = fract(time_s / 4.0 - idx / N);
	vec3 body = c_base.rgb;
	vec3 line = w < 0.14 ? c_hot.rgb : c_light.rgb;
	float bright = w < 0.14 ? 1.0 : 0.88;
	// gövde: 3 hücre kalın (dış koyu dudak + açık çizgi + iç mavi)
	if (from_end >= -0.5) {
		if (e > 0.5 && e <= 1.5) {
			col = vec4(c_dark.rgb, 0.55);
		} else if (abs(e) <= 0.5) {
			col = vec4(line, bright);
		} else if (e < -0.5 && e >= -1.5) {
			col = vec4(body, 0.70);
		}
	}
	// uçta içe dönen kanca: son 2 hücre kalın, kenardan 8 hücre içeri (dış koyu dudak kancanın dış yüzünde de)
	if (e < -1.5 && e >= -8.5) {
		if (from_end >= -0.5 && from_end < 1.5) {
			col = vec4(e >= -6.5 ? body : c_light.rgb, e >= -6.5 ? 0.72 : bright * 0.9);
		} else if (from_end >= 1.5 && from_end < 2.5) {
			col = vec4(c_dark.rgb, 0.45);
		}
	}
	return col;
}

void fragment() {
	vec2 cc = (floor(world_pos / cell) + 0.5) * cell;
	vec2 c0 = (floor(center / cell) + 0.5) * cell;
	vec2 rel = (cc - c0) / cell;          // hücre
	float d = length(rel);
	float r = radius / cell;
	float e = d - r;                       // + dışarı, - içeri (hücre)
	float ang = atan(rel.y, rel.x);
	vec4 col = vec4(0.0);
	if (variant == 0) {
		col = variant_a(e, ang, r);
	} else if (variant == 1) {
		col = variant_b(e);
	} else if (variant == 2) {
		col = variant_c(rel, e, r);
	} else {
		col = variant_d(e, ang, r);
	}
	col.a *= alpha_mult;
	COLOR = col;
}
