shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://shaders/su_dalgacik.gdshaderinc" // dalgacık uniform'ları + kiyi() / dalgacik() (2026-11-16: ana menü nehri de kullanır)
#include "res://shaders/su_bulanik.gdshaderinc" // BULANIK SU (2026-11-16, Kara Bataklık): dip çamuru + yarı saydam pis su; `bulanik` kapalıyken etkisiz

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

// su_mesafe / su_akis / doku_origin / doku_size / dalgacik_acik / sirt_renk / sirt_guc / hucre / yogunluk / omur_hiz / akis_hiz:
// shaders/su_dalgacik.gdshaderinc (aynı adlar, scripts/water_fx.gd bunları yazar).

// SABİT RENK (madde 714, kullanıcı 2026-11-15: "tüm sular ana haritadaki su shaderını kullanmalı"): Kara Bataklık / Altın Kumlar / Ayaz Dağı
// sıcak kaynağı / Batık Nekropol de BU shader'ı kullanır. Onların "Su" karosu kendi rengini taşımaz (üreteçlerin düz mavi collision karosu, zindan
// setinin dalga karosu) -> sabit_renk açıkken renk su_rengi'nden gelir, karonun yalnız alfası kullanılır; saydamlık / dalgacık / akış / kıyı AYNI.
// Değerler harita profilinden (scripts/map_profiles.gd "su_doku" -> "renk" / "sirt"), materyali scripts/water_fx.gd make_material kurar.
uniform bool sabit_renk = false;
uniform vec4 su_rengi : source_color = vec4(0.243, 0.557, 0.588, 1.0);
uniform float su_alfa = 0.8; // tek saydamlık (karonun kendi alfasıyla çarpılır)

varying vec2 world_pos;

void vertex() {
	// TileMapLayer karolarını yerel koordinatta çizer; MODEL_MATRIX dünyaya çevirir - desen haritaya yapışık.
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// doku_uv / kiyi / hash21 / hash22 / sekil / dalgacik: shaders/su_dalgacik.gdshaderinc.

// Su karosunun pikseli mi (terrain_collision.gd _class_mask ile aynı kural)? Su katmanına boyanmış çimen karoları değil.
bool mavi_mi(vec3 c) {
	return c.b > c.g + 0.03 && c.b > c.r + 0.1;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (!sabit_renk && !mavi_mi(tex.rgb)) {
		// Su katmanına boyanmış çimen karosu (madde 85): eski shader'daki gibi hafif renk + saydamlık.
		COLOR = vec4(mix(tex.rgb, vec3(0.18, 0.48, 0.68), 0.12), tex.a * 0.73);
		if (COLOR.a > 0.0) { COLOR.rgb = harita_renk_d(COLOR.rgb, world_pos); }
	} else {
		vec2 px = floor(world_pos);
		float d = kiyi(px);
		vec3 col = sabit_renk ? su_rengi.rgb : tex.rgb;
		float a = su_alfa;
		if (bulanik) {
			// dibi kendisi çizer (bataklıkta su hücresinin altında karo yok) -> opak; örtü (bataklik_su_ayak) aynı su_bulanik()'i çizer
			col = su_bulanik(col, px, TIME);
			a = 1.0;
		}
		if (dalgacik_acik && d > 3.5 && dalgacik(px, TIME)) {
			col = mix(col, sirt_renk.rgb, sirt_guc);
			a = max(a, 0.88);
		}
		COLOR = vec4(col, tex.a * a);
		if (COLOR.a > 0.0) { COLOR.rgb = harita_renk_d(COLOR.rgb, world_pos); } // harita + derin orman bölge renk ayarı (madde 181/359) - fragment()'in EN SONUNDA kalmalı
	}
}
