shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://shaders/bataklik_su_desen.gdshaderinc"

// KARA BATAKLIK SUYU (madde 524, 2026-11-09). "Su/Su" katmanı DÜZ MAVİ karo (ana haritanın "Su" katmanıyla aynı düzen; madde 525'ten beri
// bataklıkta su YÜRÜNÜR - map_profiles "su_yurunur", collision suyu saymaz); görünüş tamamen burada:
//  - bataklık setinin kendi su rengi (#24674b: kıyı karolarının su çizgisi bu renge göre çizilmiş -> dikişsiz),
//  - çok yavaş kayan, kıvrımlı koyu / açık lekeler: dibi görünmeyen, yer yer çürük yaprak birikmiş durgun su hissi (kontrast düşük),
//  - seyrek, kısa yanıp sönen 1-3 px ışık pırıltısı (yüzeyde böcek / damla).
// Desen dünya pikselinde (1 texel = 1 dünya px, kamera 2x'te 2x2 ekran pikseli), dither yok - her ton geçişi tek adımda düz piksel
// (oyunun "sade su" kararı, madde 424: göz yormayan, tek hareket fikri). Dalga izleri / nilüfer / su mercimeği ayrı katmanda ("Su süsleri").
// Desen + uniform'lar shaders/bataklik_su_desen.gdshaderinc'te: suya giren karakterin ayak örtüsü (scenes/bataklik_su_ayak.gdshader) aynı rengi
// çizer - ikisinden birini değiştirirsen öbürü otomatik aynı kalır (uniform değerleri malzemede DEĞİL, varsayılanlarda tutulur).

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(bs_su_rengi(floor(world_pos), TIME), tex.a);
	if (COLOR.a > 0.0) { COLOR.rgb = harita_renk(COLOR.rgb); } // harita renk ayarı (madde 181): kıyı karoları (düz materyal) ile aynı
}
