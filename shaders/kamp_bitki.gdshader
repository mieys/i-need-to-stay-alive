shader_type canvas_item;

// ==================================================
// ANA MENÜ "Nehir Kenarı Kampı" - SALLANAN BİTKİLER (2026-11-16, kullanıcı: "ağaçlar ve çalılar sallanmıyor, sallanmalıydı ama yavaşça")
// ==================================================
// Taban (nehir_kamp.png) haritanın durağan yakalaması olduğu için bitkiler donuktu. Artık taban BİTKİSİZ zemin; oyunda sallanan ağaç / çalı /
// çiçek pikselleri ayrı doku (nehir_kamp_bitki.png) ve bu shader onları kökünden sallar (oyunun sallanan ağaç.gdshader eğrisi: kök sabit,
// tepe en çok, pow(h, egri_ussu)). Üretim: tools/proto_20261115/kamp_menu/kamp_capture.gd KAMP_ZEMIN=1 + gen_nehir_kamp.py bitki_katmani.
//
// veri (nehir_kamp_bitki_veri.png), RGBA8 dünya pikseli başına: R = bitkinin kök satırı (en alt opak satır + 1), G = boyu, B = faz,
// A = 255 geçerli. Veri bitkinin BITKI_PAY px yanına da yayılmış: bitki sallanınca kenarının dışına düşen ekran pikseli kendi bitkisini bulur.
// Kayma dünya pikselinin altında (ekran pikseli adımlı) - oyundaki ağaç köşe kaydırması gibi.

uniform sampler2D veri : filter_nearest;
uniform vec2 dunya_size = vec2(384.0, 216.0);
uniform float strength = 1.4;       // en uzun bitkinin tepesinin en fazla kayması (dünya px) - oyundaki ağaç strength'i
uniform float kisa_genlik = 0.35;   // genlik = min(strength, kisa_genlik + boy x boy_genlik): fide ~0,6, ağaç 1,4
uniform float boy_genlik = 0.022;
uniform float hiz = 0.54;           // oyunda 0,9 rad/sn; menüde yavaş (menu_camp_scene.gd BITKI_HIZ)
uniform float egri_ussu = 1.8;
uniform float esinti_gucu = 0.35;   // sahnede yavaşça gezen ortak esinti dalgası (bitkiler birlikte eğilir)

void fragment() {
	vec2 p = UV * dunya_size;
	ivec2 c = ivec2(floor(p));
	vec4 v = texelFetch(veri, c, 0) * 255.0;
	COLOR = vec4(0.0);
	if (v.a > 127.0) {
		float h = clamp((v.r - (float(c.y) + 0.5)) / max(v.g, 1.0), 0.0, 1.0);
		float k = pow(h, egri_ussu);
		float faz = v.b / 255.0;
		float genlik = min(strength, kisa_genlik + v.g * boy_genlik);
		float t = TIME * hiz + faz * 6.2832;
		float esinti = sin(TIME * hiz * 0.39 - p.x * 0.004 * 6.2832) * esinti_gucu;
		float sway = genlik * (sin(t) * 0.7 + sin(t * 0.53 + faz * 5.0) * 0.3 + esinti) * k;
		ivec2 sc = ivec2(floor(p - vec2(sway, 0.0)));
		sc.x = clamp(sc.x, 0, int(dunya_size.x) - 1);
		vec4 v2 = texelFetch(veri, sc, 0) * 255.0;
		// Yalnız AYNI bitkinin pikseli alınır (komşu bitkinin ya da boşluğun yerine zemin görünür).
		if (v2.a > 127.0 && abs(v2.r - v.r) < 0.5 && abs(v2.g - v.g) < 0.5 && abs(v2.b - v.b) < 0.5) {
			COLOR = texelFetch(TEXTURE, sc, 0);
		}
	}
}
