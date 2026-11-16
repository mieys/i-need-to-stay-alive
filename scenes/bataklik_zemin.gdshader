shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://shaders/bataklik_zemin_desen.gdshaderinc"
// 2026-11-16 BULANIK SU: kıyı karolarının ("Su/Su ayrıntılar 2") çimen saçağının altındaki eski su gölgesi / köpüğü yeni bulanık suya
// boyanır (shaders/su_bulanik.gdshaderinc su_bulanik_karo; su_rengi + bulanik parametreleri water_fx.gd attach yazar). Zemin karolarında
// setin su paleti yok -> onlarda etkisiz.
#include "res://shaders/su_bulanik.gdshaderinc"
uniform vec4 su_rengi : source_color = vec4(0.169, 0.337, 0.255, 1.0);

// KARA BATAKLIK ZEMİNİ (madde 524): "Yer/Zemin Toprak" (çamur dolgu) + "Yer/Zemin Çimen" (çimen saçaklı karolar) + kıyı karoları
// ("Su/Su ayrıntılar 2", madde 526'dan beri - kıyı çimeni de iç çimenle aynı desende) AYNI malzeme. Bataklık setinin zemin karoları DÜZ RENK
// (çimen #90a347, çamur #7c7538) - doku yalnız saçaklarda.
// Desen "C - Sakin Doku" (madde 583, 4 prototipten seçildi): çimen + çamur (patikalar / açıklıklar / koru altı), bkz.
// shaders/bataklik_zemin_desen.gdshaderinc. Önceki: çimen "B - Ot Tutamları" (madde 526) + çamurda ana haritanın toprak_desen'i ve su birikintileri.
// Yalnız taban rengine yakın pikseller değişir (bz_cim_maske / bz_camur_maske): saçak ve kenar çizimleri aynen kalır.

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = floor(world_pos);
	vec3 rgb = tex.rgb;
	if (bulanik) {
		rgb = su_bulanik_karo(rgb, su_rengi.rgb, px, TIME);
	}
	float mc = bz_cim_maske(tex.rgb);
	if (mc > 0.0) {
		rgb = mix(rgb, bz_cimen(tex.rgb, px), mc);
	}
	float mm = bz_camur_maske(tex.rgb);
	if (mm > 0.0) {
		rgb = mix(rgb, bz_camur(tex.rgb, px), mm);
	}
	COLOR = vec4(rgb, tex.a);
	if (COLOR.a > 0.0) { COLOR.rgb = harita_renk(COLOR.rgb); } // harita renk ayarı (madde 181) - fragment()'in EN SONUNDA
}
