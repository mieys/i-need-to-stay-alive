shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261017/su_shader/su_ortak.gdshaderinc"

// PROTOTİP C v2 - DALGA SIRTLARI (2026-10-17, oyuna bağlı DEĞİL).
// El çizimi piksel su dili: suyun üstünde ince (1 px), uzun, hafif kıvrık açık renk dalga sırtı çizgileri; sırtlar dalga boyu
// aralıkla sıralanıp akıntı yönünde YÜRÜR, her sırt kendi kesik desenine bölünür, kesikler uçlarından uzayıp kısalır (yerinde
// belirip sönmez). Geniş ışık kabarmaları (3 kademe). Kıyıya yaklaşırken sırtlar noktalı söner. Kıyı: ıslak koyu bant + kıyıya
// gelip giden 1 px açık "yalama" çizgisi.
// v2 (kullanıcı: "baloncuk çıkıyormuş gibi duruyor"; v1 = su_C_dalgacik_v1.gdshader): v1'in 2 px yüksek yuvarlak tepeli "︵"
// dalgacıkları + altlarındaki koyu gölge kubbe gibi okunuyordu, ortadan büyüyüp YERİNDE sönmeleri ve rastgele dağılmaları yüzeye
// çıkan kabarcık hissi veriyordu -> gölgesiz 1 px çizgi, sıra hâlinde, hareket eden sırtlar.

uniform vec4 su_renk : source_color = vec4(0.235, 0.43, 0.6, 1.0);
uniform vec4 derin_renk : source_color = vec4(0.19, 0.35, 0.53, 1.0);
uniform float su_alfa = 0.76;
uniform float derin_alfa = 0.84;
uniform vec4 sirt_renk : source_color = vec4(0.6, 0.79, 0.9, 1.0);
uniform float dalga_boyu = 13.0; // sırtlar arası (px)
uniform float dalga_hiz = 0.2; // sırt/sn -> ~2,6 px/sn
uniform vec2 dalga_yon = vec2(0.06, 1.0); // yürüme yönü; sırtlar buna dik (neredeyse yatay)
uniform float kesik_esik = 0.53; // yüksek = daha az / daha kısa kesik
uniform float sirt_guc = 0.7;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// 0 = yok, 1 = sırt, 0.5 = kesiğin noktalı ucu
float sirt(vec2 px, float t, float th) {
	vec2 dir = normalize(dalga_yon);
	vec2 perp = vec2(-dir.y, dir.x);
	// hafif kıvrım: sırtlar düz paralel çizgi olmasın (büyük kıvrım sırtları eğik "yağmur çizgisi" yapıyordu)
	float kivrim = su_noise(px * 0.015 + vec2(0.0, t * 0.02)) * 0.6;
	float ph = dot(px, dir) / dalga_boyu + kivrim - t * dalga_hiz;
	float k = floor(ph);
	if (fract(ph) * dalga_boyu >= 1.0) {
		return 0.0;
	}
	// sırt boyunca kesik deseni: her sırtın kendi deseni, zamanla yavaşça değişir (kesikler uçlarından uzar/kısalır)
	float s = dot(px, perp);
	float n = su_noise(vec2(s * 0.06 + k * 13.7, k * 3.1 + t * 0.15));
	if (n > kesik_esik + 0.07) {
		return 1.0;
	}
	if (n > kesik_esik && th > 0.5) {
		return 0.5;
	}
	return 0.0;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (!su_mavi_mi(tex.rgb)) {
		COLOR = su_disi(tex);
		COLOR.rgb = harita_renk(COLOR.rgb);
	} else {
		vec2 px = floor(world_pos);
		float t = TIME;
		float d = su_kiyi(px);
		float th = su_bayer(px);

		float lv = su_kademe(clamp(d / 30.0, 0.0, 1.0), 1.0, th, 0.35);
		vec3 col = mix(su_renk.rgb, derin_renk.rgb, lv);
		float a = mix(su_alfa, derin_alfa, lv);

		// geniş kabarmalar
		vec2 wp = px * vec2(0.022, 0.045) + vec2(t * 0.07, t * 0.03);
		float sw = su_fbm(wp);
		col *= 1.0 + (su_kademe(sw, 2.0, th, 0.5) - 0.5) * 0.12;

		// dalga sırtları: kıyıya 4-9 px kala noktalı söner
		if (d > 4.0 && th < smoothstep(4.0, 9.0, d)) {
			float sr = sirt(px, t, th);
			col = mix(col, sirt_renk.rgb, sr * sirt_guc);
			a = mix(a, 0.9, sr);
		}

		// kıyı: yalama çizgisi kıyıya 1,5..4,5 px arasında gelip gider (kıyı boyunca farklı fazda)
		float lap = 2.0 + 1.6 * sin(t * 1.5 + su_noise(px * 0.04) * 9.0);
		if (d < 1.2) {
			col = mix(col, sirt_renk.rgb, 0.55);
			a = 0.82;
		} else if (d < lap) {
			col *= 0.86;
			a = max(a, 0.8);
		} else if (d < lap + 1.0) {
			col = mix(col, sirt_renk.rgb, 0.6);
			a = max(a, 0.88);
		}
		COLOR = vec4(harita_renk(col), tex.a * a);
	}
}
