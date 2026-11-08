shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"

// "Su" katmanının suyu (harita_baked.tscn -> Su/Su, ayrıca Su/Su collisionsuz aynı materyali paylaşır; dokular + ayar scripts/water_fx.gd).
//
// 2026-11-06 (madde 424): sade su prototipi B "SEYREK DALGACIK" (madde 423, tools/proto_20261106/su_sade/su_B_seyrek_dalgacik.gdshader)
// oyunda. Kullanıcı: "sudaki shaderlar için daha sade 4 prototip" -> "derinlik renk değişimini istemiyorum, onları kendim yapıyorum" -> B.
//   - Renk = karonun KENDİ rengi (kullanıcı derinliği Tiled'da karolarla boyuyor), her yerde tek saydamlık `su_alfa`. Kıyıya uzaklığa göre
//     ton değişimi, noktalı (Bayer) geçiş, ışık kabarması YOK. (Önceki C3 mavi pikselleri su_renk/derin_renk ile eziyordu.)
//   - Dalgacıklar: C3'ün (madde 214) 7-11 px "︵" sırtı aynı şekil (2 px yuvarlak tepe, uçlar kıvrık), GÖLGE SATIRI YOK, sönük (sirt_guc),
//     seyrek (yogunluk 0,22; C3 0,55); belirip uzar, kısalıp söner, her biri DOĞDUĞU noktadaki akış vektörüyle (su_akis: kıyıya paralel,
//     batı -> kuzeydoğu, kanal ortasında hızlı / kıyıda durgun) ömrü boyunca sürüklenir. Merkez ileri hesaplanır (piksel geri kaydırılsa
//     kıvrımlarda akış farkı şekli yırtardı), bu yüzden piksel çevresindeki 3x5 hücre denenir. Her döngüde doğum yeri yeniden rastgele;
//     kıyıya < 5 px'te doğmaz. `dalgacik_acik` = "Zemin ayrıntısı" grafik ayarı (telefonda pahalı döngü; kapalıyken düz su).
//   - Kıyı: shader kıyıya HİÇBİR ŞEY çizmez (kullanıcı: "su kenarlarındaki izleri kaldır"; 1 px açık çizgi madde 424'te vardı,
//     kaldırıldı). Kıyıyı yalnız kullanıcının kıyı sanatı karoları çizer. `kiyi()` sadece dalgacığın kıyıya yakın doğmaması için.
// Dünya koordinatında, harita karolarının piksel ızgarasında (1 dünya birimi = 1 karo pikseli) çalışır; harita renk ayarı en sonda.

uniform sampler2D su_mesafe : hint_default_white, filter_linear, repeat_disable; // R = kıyıya uzaklık / 64 dünya px (2 px/teksel)
uniform sampler2D su_akis : hint_default_black, filter_linear, repeat_disable; // RG = 0,5 + 0,5 akış, B = dalgacık doğabilir (4 px/teksel)
uniform vec2 doku_origin = vec2(-576.0, -384.0);
uniform vec2 doku_size = vec2(5248.0, 4864.0);
uniform bool dalgacik_acik = true;

uniform float su_alfa = 0.8; // tek saydamlık (karonun kendi alfasıyla çarpılır)
uniform vec4 sirt_renk : source_color = vec4(0.6, 0.79, 0.9, 1.0);
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

// Su karosunun pikseli mi (terrain_collision.gd _class_mask ile aynı kural)? Su katmanına boyanmış çimen karoları değil.
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
	if (!mavi_mi(tex.rgb)) {
		// Su katmanına boyanmış çimen karosu (madde 85): eski shader'daki gibi hafif renk + saydamlık.
		COLOR = vec4(mix(tex.rgb, vec3(0.18, 0.48, 0.68), 0.12), tex.a * 0.73);
		if (COLOR.a > 0.0) { COLOR.rgb = harita_renk_d(COLOR.rgb, world_pos); }
	} else {
		vec2 px = floor(world_pos);
		float d = kiyi(px);
		vec3 col = tex.rgb;
		float a = su_alfa;
		if (dalgacik_acik && d > 3.5 && dalgacik(px, TIME)) {
			col = mix(col, sirt_renk.rgb, sirt_guc);
			a = max(a, 0.88);
		}
		COLOR = vec4(col, tex.a * a);
		if (COLOR.a > 0.0) { COLOR.rgb = harita_renk_d(COLOR.rgb, world_pos); } // harita + derin orman bölge renk ayarı (madde 181/359) - fragment()'in EN SONUNDA kalmalı
	}
}
