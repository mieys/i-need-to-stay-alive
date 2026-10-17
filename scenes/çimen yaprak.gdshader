shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"
#include "res://shaders/cimen_desen.gdshaderinc"

// ==================================================
// ZEMİN ÇİMEN - "Canlı çayır" (Harita > Yer > "Zemin Çimen", "Su ayrıntılar 2" de aynı materyali paylaşır)
// ==================================================
// Kullanıcı isteği (2026-10-02): "çimen ve toprak için ayarladığımız shaderların daha iyi olmasını istiyorum" - 4 prototipten
// "C - Canlı çayır" seçildi, düzeltmeyle: "C çok iyi ama parlaklar aşırı parlak ve göz alıyor" -> güneşli/açık lekeler,
// yaprak ışığı ve çiçekler yumuşatıldı, güneşli alan küçültüldü.
// Önceki "Yaprak Kümesi" tasarımı git'te (d65010a). Onun asıl kusuru leke kenarlarındaki 4x4 Bayer dither'dı: yakından
// dağınık piksel kırıntısı gibi görünüyordu (kullanıcı gölgelerde de aynısını istemedi) - burada HİÇ dither yok, her ton
// geçişi tek adımda düz piksel.
//
// Tasarım:
//  - Desen DÜNYA koordinatından (1 dünya pikseli = 1 texel; karolar arası kesintisiz, kamera 2x'te her texel 2x2 ekran pikseli).
//  - Kıvrımlı (domain warp) lekeler: derin yeşil / daha derin yeşil / açık / güneşli (sıcak sarımsı) - keskin kenar.
//  - Karo setindeki çalı yaprağının minik hali (yaprak kümesi), koyu lekelerde sık ve gruplu.
//  - Açık lekelerde seyrek minik çiçekler (3x3 artı: beyaz/sarı/pembe), koyu lekelerde üç yapraklı yonca.
//  - Sadece DÜZ çimen piksellerine uygulanır (cim_taban'a yakın): patika/çalı kenarı karolarındaki çizimler aynen kalır.
//  - Tonlar karonun kendi rengine GÖRE uygulanır (çarpan): düz karoda paletin birebir aynısı.
// Parametre adları eski shader'ınkilerle BİLEREK çakışmıyor (cim_ / kume_ önekleri): harita_baked.tscn'deki materyalde eski
// adlarla kayıtlı değerler (renk_koyu, koyu_esik ...) yeni varsayılanları ezmesin - o eski kayıtlar artık kullanılmıyor, zararsız.
// Desen, renk/eşik/yoğunluk uniform'ları ve fonksiyonlar: shaders/cimen_desen.gdshaderinc (plato tepeleriyle ortak, madde 186).

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float maske = cimen_maske(tex.rgb);
	vec3 c = cimen_desen(tex.rgb, floor(world_pos));
	COLOR = vec4(mix(tex.rgb, c, maske * cim_efekt), tex.a);
	COLOR.rgb = harita_renk(COLOR.rgb); // harita renk ayarı (madde 181) - fragment()'in EN SONUNDA kalmalı
}
