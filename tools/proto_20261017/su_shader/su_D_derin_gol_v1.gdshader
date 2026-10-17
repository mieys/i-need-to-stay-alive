shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://tools/proto_20261017/su_shader/su_ortak.gdshaderinc"

// PROTOTİP D v1 - DERİN GÖL (2026-10-17, oyuna bağlı DEĞİL). SADECE karşılaştırma için saklandı: kullanıcı "daha az göz yorsun"
// dedi -> güncel sürüm su_D_derin_gol.gdshader (v2).
// Suyun altındaki dip (toprak çatlakları, çakıllar) ekran dokusundan okunup satır satır TAM piksel kaydırılır -> dip dalgalanır
// (keskin kalır, bulanıklık yok); kıyıda kaydırma 0 (kenar oynamaz). Üstte yavaş kayan bulut yansıması (gök rengi, 3 kademe,
// noktalı), derinlikte koyulaşma, güneş pırıltıları (sıcak beyaz, mevcuttan yoğun). Kıyı: koyu temas + 1 px açık çizgi.
// NOT: ekran dokusu Su katmanından ÖNCE bir BackBufferCopy (tam görüş) düğümü ister (otomatik kopya dipte sadece temizleme
// rengini okuyordu, bkz. su_capture.gd); kare başı bir ekran kopyası = telefonda maliyeti ölçülmeli.

uniform sampler2D ekran : hint_screen_texture, filter_nearest;
uniform vec4 su_renk : source_color = vec4(0.247, 0.451, 0.62, 1.0);
uniform vec4 derin_renk : source_color = vec4(0.16, 0.30, 0.49, 1.0);
uniform vec4 gok_renk : source_color = vec4(0.62, 0.76, 0.86, 1.0);
uniform float sig_alfa = 0.6;
uniform float derin_alfa = 0.85;
uniform float derinlik_px = 26.0;
uniform float kirilma_px = 1.6;
uniform float yansima_guc = 0.2;
uniform vec4 pirilti_renk : source_color = vec4(1.0, 0.97, 0.86, 1.0);
uniform int hata_ayikla = 0; // 1 = sadece dip, 2 = sadece yansima katsayisi

varying vec2 world_pos;
varying float ekran_olcek; // ekran pikseli / dünya birimi

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	ekran_olcek = length((CANVAS_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xy);
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

		// kırılma: satır başına yatay (+ az dikey) tam piksel kaydırma
		float amp = kirilma_px * smoothstep(1.5, 9.0, d);
		vec2 off = vec2(sin(px.y * 0.42 + t * 1.9) * 0.7 + sin(px.y * 0.13 - t * 1.1) * 0.3,
				sin(px.x * 0.27 + t * 1.4) * 0.45) * amp;
		off = floor(off + 0.5);
		vec2 dip_uv = SCREEN_UV + off * ekran_olcek * SCREEN_PIXEL_SIZE;
		vec3 dip = textureLod(ekran, dip_uv, 0.0).rgb;

		float lv = su_kademe(clamp(d / derinlik_px, 0.0, 1.0), 2.0, th, 0.45);
		vec3 wcol = mix(su_renk.rgb, derin_renk.rgb, lv);
		float a = mix(sig_alfa, derin_alfa, lv);

		// bulut yansıması: büyük, yavaş, 3 kademe
		vec2 cp = px * 0.0065 + vec2(t * 0.012, t * 0.005);
		float cl = su_fbm(cp);
		float refl = su_kademe(clamp((cl - 0.4) * 3.0, 0.0, 1.0), 2.0, th, 0.25);
		wcol = mix(wcol, gok_renk.rgb, refl * yansima_guc * smoothstep(2.0, 8.0, d));

		// güneş pırıltısı
		float sp = d > 5.0 ? su_pirilti(px, t, vec2(12.0, 8.0), 0.3, 4.0, vec2(1.0, 0.2), 0.45) : 0.0;
		wcol = mix(wcol, pirilti_renk.rgb, sp * 0.9);
		a = max(a, sp);

		// kıyı
		if (d < 1.2) {
			wcol = mix(wcol, gok_renk.rgb, 0.5);
			a = max(a, 0.8);
		} else if (d < 3.0) {
			wcol *= 0.8;
			a = max(a, 0.75);
		}
		COLOR = vec4(mix(dip, harita_renk(wcol), a), tex.a);
		if (hata_ayikla == 1) { COLOR = vec4(dip, 1.0); }
		if (hata_ayikla == 2) { COLOR = vec4(vec3(refl), 1.0); }
	}
}
