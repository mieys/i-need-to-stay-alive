shader_type canvas_item;

// Shaman E (Kalkan Totemi) AURA SINIRI - "C Işık Perdesi" (madde 586; prototip tools/proto_20261111/shaman_aura/, kullanıcı seçti).
// Sınır = totem_radius (kalkan + şerit alanı, mesafe = DAİRE). Yerde 1 hücre açık çizgi + üstünden yükselen alçak ışık duvarı (silindir:
// arka yay çizginin üstünde arkada, ön yay alanın içine doğru önde ve daha soluk). Duvar boyu 7..13 hücre, tepe çizgisi yumuşak dalga
// (sütundan sütuna rastgele DEĞİL -> parazitsiz), ön/arka ters yönde akar; seyrek beyaz zerreler yükselip tepeyi geçerek söner.
// PARAZİTSİZ (madde 562 ek 4, totem_shield_link.gdshader ile aynı kural): her parça kendi DÜNYA ızgara hücresinin (cell = karakter pikseli
// 0,903) MERKEZİNE göre karar verir -> hücre ya tam dolu ya boş, dither yok, düz tonlar. Düğüm dönüşümü dünya -> world_pos.

uniform float cell = 0.903;
uniform vec2 center;
uniform float radius = 220.0;    // dünya
uniform float time_s = 0.0;
uniform float alpha_mult = 1.0;  // belirme / sönme
uniform float grow = 1.0;        // 0..1 açılış (perde boyu)
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

void fragment() {
	vec2 cc = (floor(world_pos / cell) + 0.5) * cell;
	vec2 c0 = (floor(center / cell) + 0.5) * cell;
	vec2 rel = (cc - c0) / cell;          // hücre
	float r = radius / cell;
	float e = length(rel) - r;             // + dışarı, - içeri (hücre)
	vec4 col = vec4(0.0);
	if (abs(e) <= 0.5) {
		col = vec4(c_light.rgb, 0.72);
	}
	float X = rel.x;
	if (abs(X) < r) {
		float s = sqrt(r * r - X * X);
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
			wall_a = 0.80; // ön perde alanın içini örtmesin: biraz daha soluk
		} else if (ht > 0.5 && ht <= Hb) {
			best = ht;
			H = Hb;
		}
		bool mote_col = hash11(X * 1.37 + 11.0) > 0.82;
		if (best > 0.0) {
			float f = best / max(H, 1.0);
			float a = f < 0.25 ? 0.52 : (f < 0.6 ? 0.32 : 0.17);
			col = vec4(c_base.rgb, a * wall_a);
			if (best > H - 1.0) {
				col = vec4(c_light.rgb, 0.62 * wall_a); // perdenin tepe çizgisi
			}
			if (mote_col) {
				float hm = fract(time_s * 0.4 + hash11(X + 5.0)) * (H + 4.0);
				if (abs(best - hm) <= 0.5) {
					col = vec4(c_hot.rgb, 0.95 * wall_a);
				}
			}
		} else if (mote_col) {
			// tepenin üstüne çıkan zerre (perde dışında, son 4 hücre), yükseldikçe söner
			bool front = hb > 0.5 && hb <= Hf + 4.0;
			float h2 = front ? hb : (ht > 0.5 && ht <= Hb + 4.0 ? ht : -1.0);
			float H2 = front ? Hf : Hb;
			if (h2 > 0.0) {
				float hm = fract(time_s * 0.4 + hash11(X + 5.0)) * (H2 + 4.0);
				if (abs(h2 - hm) <= 0.5) {
					col = vec4(c_light.rgb, 0.7 * (1.0 - (hm - H2) / 4.0));
				}
			}
		}
	}
	col.a *= alpha_mult;
	COLOR = col;
}
