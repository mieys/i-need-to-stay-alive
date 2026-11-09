shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://shaders/toprak_desen.gdshaderinc"
#include "res://shaders/bataklik_cimen.gdshaderinc"

// KARA BATAKLIK ZEMİNİ (madde 524): "Yer/Zemin Toprak" (çamur dolgu) + "Yer/Zemin Çimen" (çimen saçaklı karolar) + kıyı karoları
// ("Su/Su ayrıntılar 2", madde 526'dan beri - kıyı çimeni de iç çimenle aynı desende) AYNI malzeme. Bataklık setinin zemin karoları DÜZ RENK
// (çimen #90a347, çamur #7c7538) - doku yalnız saçaklarda.
//  - ÇİMEN: "B - Ot Tutamları" (madde 526, 4 prototipten seçildi): setin saçak çizim dilinde küçük V tutamlar, kümeler hâlinde (bkz.
//    shaders/bataklik_cimen.gdshaderinc). Önceki: ana haritanın "Canlı çayır" deseni bataklık paletine oranlanmış (kullanıcı beğenmedi).
//  - ÇAMUR: ana haritanın toprak_desen'i, ton oranları bataklık tabanına taşınmış (değerler malzemede, tools/bataklik/bake_bataklik.gd;
//    çatlak yok - ıslak çamur kurumaz, çakıl seyrek) + koyu çamur lekelerinde küçük su birikintileri (2-5 px, üstte bir parlak piksel).
// Yalnız taban rengine yakın pikseller değişir (bc_maske / toprak_maske): saçak ve kenar çizimleri aynen kalır.

uniform vec4 birikinti_rengi : source_color = vec4(0.153, 0.400, 0.306, 1.0);
uniform vec4 birikinti_kenar : source_color = vec4(0.290, 0.290, 0.161, 1.0);
uniform vec4 birikinti_isik : source_color = vec4(0.420, 0.600, 0.480, 1.0);
uniform float birikinti_yogunlugu : hint_range(0.0, 1.0) = 0.22;  // 15 px hücre başına (yalnız koyu çamur lekesinde)

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Su birikintisi: 15x15 hücrede en fazla bir tane, yassı elips. Döner: 0 yok, 1 su, 2 kenar (ıslak çamur), 3 ışık.
int birikinti(vec2 px) {
	const float HC = 15.0;
	vec2 hc = floor(px / HC);
	if (td_hash12(hc + vec2(4.4, 8.8)) >= birikinti_yogunlugu) { return 0; }
	if (td_lekeler(hc * HC + 7.0) < toprak_koyu_esik) { return 0; }
	vec2 merkez = hc * HC + 4.0 + floor(vec2(td_hash12(hc + vec2(1.1, 3.3)), td_hash12(hc + vec2(6.6, 2.2))) * (HC - 8.0));
	float rx = 1.5 + floor(td_hash12(hc + vec2(9.9, 0.7)) * 2.0);
	float ry = 1.0 + floor(td_hash12(hc + vec2(0.3, 5.5)) * 1.5);
	vec2 d = (px + 0.5 - merkez) / vec2(rx, ry);
	float r = dot(d, d);
	if (r < 0.75) {
		return (px.x == merkez.x - 1.0 && px.y == merkez.y - ry + 0.0) ? 3 : 1;
	}
	if (r < 1.25 && d.y > -0.2) { return 2; }
	return 0;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = floor(world_pos);
	vec3 rgb = tex.rgb;
	float mc = bc_maske(tex.rgb);
	if (mc > 0.0) {
		rgb = mix(rgb, bc_cimen(tex.rgb, px), mc);
	}
	float mt = toprak_maske(tex.rgb);
	if (mt > 0.0) {
		vec3 t = toprak_desen(tex.rgb, px);
		int b = birikinti(px);
		if (b == 1) { t = birikinti_rengi.rgb; }
		else if (b == 3) { t = birikinti_isik.rgb; }
		else if (b == 2) { t = birikinti_kenar.rgb; }
		rgb = mix(rgb, t, mt * toprak_efekt);
	}
	COLOR = vec4(rgb, tex.a);
	if (COLOR.a > 0.0) { COLOR.rgb = harita_renk(COLOR.rgb); } // harita renk ayarı (madde 181) - fragment()'in EN SONUNDA
}
