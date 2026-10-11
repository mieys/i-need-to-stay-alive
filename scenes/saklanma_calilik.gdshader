shader_type canvas_item;

// ==================================================
// SAKLANMA ÇALILIĞI - rüzgarda ve içinden yürüyünce sallanan çalılık + karakteri YARI SAYDAM örten ön kopya
// ==================================================
// Kullanıcı isteği (2026-10-10): "çalıların içine girince bedenimizin yarısı görünmüyor; sadece hafif saydam olalım ... içindeyken çalılar
// sallansın ve bedenimiz çalıların içinde yürüyormuş gibi görünsün".
// İKİ KULLANIM (aynı shader, scripts/hide_brush_visual.gd kurar):
//   - YER katmanı (on_katman = false): çalılık karoları, bütün BİR çalı (komşu hücrelerin bağlı kümesi) tek parça olarak kökten eğilir (sway).
//   - ÖN KOPYA (on_katman = true; scripts/depth_occluders.gd "brush" kipi karakter/yaratık listesini yazar): kökü bir karakterin/yaratığın ayağından AŞAĞIDA
//     kalan çalı piksellerini sadece o varlığın gövdesinde çizer (derinlik_on_katman.gdshader ile AYNI kural). ÇALININ İÇİNDEKİ karakter için
//     (karakter_orter[i] < 1) yapraklar o oranda saydam çizilir: gövde silinmez, yaprakların arkasında görünür.
// Neden sallanan ot.gdshader değil: o shader atlasta YAN YANA duran karoları aynı bitki sayar (sarmaşık/ot); çalılık karoları atlasta benzersiz ve sıralı
// (komşuluğu haritadadır), bu yüzden komşu karo atlas konumu `komsu_veri` dokusunda AÇIKÇA verilir.

// ---------------- SALINIM (sallanan ot.gdshader ile aynı eğri)
uniform float strength : hint_range(0.0, 6.0) = 1.35;
uniform float salinim_hizi : hint_range(0.0, 8.0) = 1.5;
uniform float egri_ussu : hint_range(0.5, 4.0) = 1.3;

// Atlas dolgusu (grass_sway.gd ile aynı): karolar karo_hucre aralıklı hücrelerde, hücrenin karo_dolgu px içinde.
uniform float karo_hucre = 18.0;
uniform float karo_dolgu = 1.0;

// Hücre verisi (hide_brush_visual.gd yazar): R = kökün karonun üstünden uzaklığı (px, KÜMENİN en alt satırı), G = kümenin boyu (kökten en üst piksele),
// B = küme fazı (1..255). Komşu verisi: R,G = SOLdaki hücrenin atlas (sütun+1, satır+1), B,A = SAĞdaki (0 = komşu yok).
uniform sampler2D veri_sway : filter_nearest;
uniform sampler2D komsu_veri : filter_nearest;
uniform sampler2D egilme_veri : filter_linear;    // R8 = 128 + eğilme x 16, HÜCRE başına (içinden yürüyen karakterin etrafındaki hışırtı); doğrusal süzgeç = hücreler arası yumuşak dalga
uniform bool sway_var = false;
uniform vec2 sway_baslangic = vec2(0.0);
uniform vec2 sway_boyut = vec2(1.0);
uniform vec2 sway_ofset = vec2(0.0);              // hücre (0,0)'ın dünyadaki sol-üstü

// ---------------- ÖN KOPYA (depth_occluders.gd yazar; adlar derinlik_on_katman.gdshader ile AYNI)
uniform bool on_katman = false;
uniform sampler2D veri : filter_nearest;           // R + G*256 = nesne kökünün dünya y'si, B = dolu hücre
uniform vec2 veri_baslangic = vec2(0.0);
uniform vec2 veri_boyut = vec2(1.0);
uniform vec2 hucre_ofset = vec2(0.0);
uniform int karakter_sayisi = 0;
uniform vec4 karakterler[8];                       // (ayak x, ayak y, yarım genişlik, boy)
uniform float karakter_orter[8];                   // 0 = yazılmadı (tam örter), 2 = dışarıdaki karakter (tam örter), aradaki değer = ÇALININ İÇİNDEKİ karakter: yaprak opaklığı + 1, sadece bacaklarını örter (ICERDE_ORTU_ORANI)
const float ICERDE_ORTU_ORANI = 0.75;            // 2026-10-10: 0,5 -> 0,75 (kullanıcı: "karakterler içinde saklanmış gibi görünmüyor"); gövdenin alt %75'i               // içerideki karakterin gövdesinin ALT yarısı yapraklarla örtülür, üst yarısı açıkta kalır
uniform int yaratik_sayisi = 0;
uniform vec4 yaratiklar[32];

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Piksel (p), kökü kok_y olan bir çalının parçası: -1 = çizme; yoksa yaprak opaklığı.
// 2026-10-10 (kullanıcı: "birden fazla kişi çalıya girince çalının görüntüsü tuhaflaşıyor"): eskiden piksel HERHANGİ bir karakterin önündeyse hemen -1
// dönülüyordu -> iki karakterin dikdörtgeni üst üste binince öndekinin dikdörtgeni arkadakinin bacak örtüsünü dikdörtgen şeklinde deliyordu. Artık pikseli
// içeren varlıklardan AYAĞI EN AŞAĞIDA olan (o pikseli büyük olasılıkla çizen, en öndeki sprite) karar verir.
float orter(vec2 p, float kok_y) {
	float best_y = -1.0e9;
	float best_v = -2.0; // -2 = hiçbiri; 2 = tam örten (dışarıdaki karakter / yaratık); aradaki = içerideki karakterin yaprak opaklığı + 1
	float best_w = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= karakter_sayisi) { break; }
		vec4 c = karakterler[i];
		if (abs(p.x - c.x) <= c.z && p.y >= c.y - c.w && p.y <= c.y + 1.0 && c.y > best_y) {
			best_y = c.y;
			best_v = karakter_orter[i];
			best_w = c.w;
		}
	}
	for (int i = 0; i < 32; i++) {
		if (i >= yaratik_sayisi) { break; }
		vec4 c = yaratiklar[i];
		if (abs(p.x - c.x) <= c.z && p.y >= c.y - c.w && p.y <= c.y + 1.0 && c.y > best_y) {
			best_y = c.y;
			best_v = 2.0;
			best_w = c.w;
		}
	}
	if (best_v < -1.0 || kok_y <= best_y) { return -1.0; }
	if (best_v > 0.0 && best_v < 1.99) {
		// çalının içindeki karakter: sadece bacak kısmı, saydam yaprakla
		return (p.y >= best_y - best_w * ICERDE_ORTU_ORANI) ? best_v - 1.0 : -1.0;
	}
	return 1.0;
}

void fragment() {
	vec2 a = UV / TEXTURE_PIXEL_SIZE;
	vec2 karo = floor(a / karo_hucre) * karo_hucre + karo_dolgu;
	vec2 ac = a - karo;
	vec2 yerel = floor(ac);
	vec2 karo_dunya = floor(world_pos - vec2(ac.x, ac.y) + 0.5);

	float opak = 1.0;
	if (on_katman) {
		vec2 h2 = floor((world_pos - hucre_ofset) / 16.0) - veri_baslangic;
		opak = -1.0;
		if (h2.x >= 0.0 && h2.y >= 0.0 && h2.x < veri_boyut.x && h2.y < veri_boyut.y) {
			vec3 v = texelFetch(veri, ivec2(h2), 0).rgb * 255.0;
			if (v.b > 128.0) { opak = orter(world_pos, v.r + v.g * 256.0); }
		}
		if (opak < 0.0) { discard; }
	}

	float kok = 15.0;
	float boy = 13.0;
	float faz = 0.0;
	float egilme = 0.0;
	vec4 komsu = vec4(0.0);
	if (sway_var) {
		vec2 hucre = floor((karo_dunya - sway_ofset) / 16.0 + 0.5) - sway_baslangic;
		if (hucre.x >= 0.0 && hucre.y >= 0.0 && hucre.x < sway_boyut.x && hucre.y < sway_boyut.y) {
			vec4 v4 = texelFetch(veri_sway, ivec2(hucre), 0) * 255.0;
			if (v4.g > 0.5) {
				kok = v4.r;
				boy = v4.g;
				faz = fract(v4.b * 0.6180339);
				komsu = floor(texelFetch(komsu_veri, ivec2(hucre), 0) * 255.0 + 0.5);
			}
			// doğrusal süzgeçle örneklenir: hücre merkezleri arası sürekli dalga (hücre sınırında kayma farkı/kopma olmasın)
			vec2 hucre_surekli = (karo_dunya + vec2(ac.x, ac.y) - sway_ofset) / 16.0 - sway_baslangic;
			egilme = (texture(egilme_veri, hucre_surekli / sway_boyut).r * 255.0 - 128.0) / 16.0;
		}
	}
	float h = kok + 1.0 - ac.y;
	float k = pow(clamp(h / max(boy, 1.0), 0.0, 1.0), egri_ussu);
	float t = TIME * salinim_hizi + faz * 6.2832;
	float sway = strength * (sin(t) * 0.8 + sin(t * 2.3 + faz * 3.1) * 0.2) + egilme;
	float kaynak = ac.x - sway * k;
	float kaynak_x = floor(kaynak);
	vec2 doku = vec2(karo.x + kaynak_x, karo.y + yerel.y);
	if (kaynak < 0.0) {
		if (komsu.r < 0.5) { discard; }
		doku = vec2((komsu.r - 1.0) * karo_hucre + karo_dolgu + 16.0 + kaynak_x, (komsu.g - 1.0) * karo_hucre + karo_dolgu + yerel.y);
	} else if (kaynak >= 16.0) {
		if (komsu.b < 0.5) { discard; }
		doku = vec2((komsu.b - 1.0) * karo_hucre + karo_dolgu + (kaynak_x - 16.0), (komsu.a - 1.0) * karo_hucre + karo_dolgu + yerel.y);
	}
	vec4 col = textureLod(TEXTURE, (doku + 0.5) * TEXTURE_PIXEL_SIZE, 0.0);
	if (col.a < 0.01) { discard; }
	col.a *= opak;
	COLOR = col;
}
