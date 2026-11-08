shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://shaders/toprak_desen.gdshaderinc"

// ==================================================
// ZEMİN TOPRAK - kuru çatlak + çakıl (Harita > Yer > "Zemin Toprak")
// ==================================================
// Kullanıcı isteği (2026-10-02): "çimen ve toprak için ayarladığımız shaderların daha iyi olmasını istiyorum" - 4 prototipten
// "B - Kuru çatlak" ile "C - Çakıllı" karıştırıldı: "toprakta B yi ve C yi karıştırıp uyumlu hale getir ve çatlakları biraz
// azalt". Önceki "Canlı" tasarımı git'te (d65010a); onun kusuru 4x4 Bayer dither'lı leke kenarları + minik topak
// benekleriydi (yakından grenli/dağınık piksel) - burada HİÇ dither yok, her geçiş tek adımda düz piksel.
//
// Tasarım (iki desen birbirini tamamlar, üst üste binmez):
//  - Desen DÜNYA koordinatından (1 dünya pikseli = 1 texel, karolar arası kesintisiz).
//  - Kıvrımlı lekeler: sıkışık koyu / taban / açık / kuru (tozlu) - keskin kenar.
//  - ÇATLAKLAR sadece en kuru (açık) lekelerde, kesik kesik: 1 px koyu çizgi + altında 1 px kalkık açık kenar (Voronoi
//    hücre sınırları).
//  - ÇAKILLAR çoğunlukla koyu (sıkışık) lekelerde: ince çakıl (1-2 px, üç ton, altında 1 px gölge) + seyrek iri çakıl
//    (3x2, sol-üst ışık). Çatlak bölgesinde çakıl çok seyrek.
//  - Tonlar karonun kendi rengine GÖRE uygulanır (çarpan): düz karoda paletin aynısı, kenar karolarındaki ayrıntı korunur.
// Parametre adları eski shader'ınkilerle BİLEREK çakışmıyor (toprak_ / catlak_ / cakil_ önekleri, eski cakil_rengi/
// cakil_golge/cakil_yogunlugu yok): harita_baked.tscn'deki eski kayıtlı değerler yeni varsayılanları ezmesin.
// Desen + tekdüzeler: shaders/toprak_desen.gdshaderinc (madde 475: kıyı karolarının kumu da aynı deseni kullanır).

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 c = toprak_desen(tex.rgb, floor(world_pos));
	COLOR = vec4(mix(tex.rgb, c, toprak_maske(tex.rgb) * toprak_efekt), tex.a);
	if (COLOR.a > 0.0) { COLOR.rgb = harita_renk_d(COLOR.rgb, world_pos); } // harita renk ayarı (madde 181) - fragment()'in EN SONUNDA kalmalı
}
