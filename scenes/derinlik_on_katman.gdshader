shader_type canvas_item;

// ==================================================
// DERİNLİK ÖN KATMANI - bina / maden / çalı karo katmanlarının "oyuncunun ÖNÜNDE kalan" kopyası
// ==================================================
// Kullanıcı isteği (2026-10-08): "y ekseni sorununu çöz: bir şeyin arkasındayken karakter onun altında, önündeyken üstünde görünsün".
// Oyuncular z_index 1'de (haritanın üstünde) çizilir; bu yüzden eskiden her harita nesnesinin (ev, ağaç, maden) üstünde görünüyorlardı.
// Aynı sonucu veren yerel çözüm (sallanan ot.gdshader "ÖN KATMAN" ile aynı fikir): scripts/depth_occluders.gd bu katmanların bir
// KOPYASINI z_index 3'te (oyuncuların VE öne alınmış yaratıkların üstünde) çizer; bu shader kopyada SADECE
//   - nesnenin kökü (yere değdiği çizgi) bir karakterin / yaratığın ayağından AŞAĞIDA (yani onun önünde) olan piksellerini, ve
//   - sadece o varlığın gövde dikdörtgeninin içinde
// bırakır, gerisini atar (varlığın ÖNÜNDEKİ bir başka varlık aynı pikseli içeriyorsa o hep görünür kalır). Böylece kopya yalnızca
// "nesne varlığı örtüyor" durumunda bir şey çizer; yerdeki küreleri ya da başka şeyleri örtmez (Main'e Y-Sort açmadan, bkz. sallanan ot.gdshader).
//
// Nesne kökü hücre başına bir veri dokusundan okunur (depth_occluders.gd oyun başında haritadaki GERÇEK yerleşimden hesaplar):
// RGBA8, R + G*256 = kökün DÜNYA y'si (px), B = 255 dolu hücre.

uniform sampler2D veri : filter_nearest;
uniform vec2 veri_baslangic = vec2(0.0);   // veri dokusunun sol-üst hücresi (harita hücre koordinatı)
uniform vec2 veri_boyut = vec2(1.0);
uniform vec2 hucre_ofset = vec2(0.0);      // hücre (0,0)'ın dünyadaki sol-üstü
uniform int karakter_sayisi = 0;
uniform vec4 karakterler[8];               // (ayak x, ayak y, yarım genişlik, boy) - dünya px (grass_sway.gd ile AYNI)
// YARATIKLAR (2026-10-09, kullanıcı: "yaratıklar ağaçların ve evlerin üstünde yürüyor"): depth_occluders.gd, bir nesne kümesine değen
// (nesnenin kökü ayağından aşağıda ya da hemen yakınında olan) görünür yaratıkların gövde dikdörtgenlerini de yazar - aynı biçim.
uniform int yaratik_sayisi = 0;
uniform vec4 yaratiklar[32];

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Piksel (p), kökü kok_y olan bir nesnenin parçası: BİR varlığın (karakter/yaratık) ARKASINDAKİ nesne pikseli mi (kopya çizilmeli)?
// Kural: pikseli içeren bir varlığın ayağı kökten yukarıdaysa (varlık nesnenin ARKASINDA) kopya onu örter; pikseli içeren bir varlık nesnenin
// ÖNÜNDEYSE (ayağı kökten aşağıda ya da aynı hizada) o varlık hep görünür kalır - kopya o pikselde çizilmez.
bool orter(vec2 p, float kok_y) {
	bool arkada = false;
	for (int i = 0; i < 8; i++) {
		if (i >= karakter_sayisi) { break; }
		vec4 c = karakterler[i];
		if (abs(p.x - c.x) <= c.z && p.y >= c.y - c.w && p.y <= c.y + 1.0) {
			if (kok_y > c.y) { arkada = true; } else { return false; }
		}
	}
	for (int i = 0; i < 32; i++) {
		if (i >= yaratik_sayisi) { break; }
		vec4 c = yaratiklar[i];
		if (abs(p.x - c.x) <= c.z && p.y >= c.y - c.w && p.y <= c.y + 1.0) {
			if (kok_y > c.y) { arkada = true; } else { return false; }
		}
	}
	return arkada;
}

void fragment() {
	vec2 hucre = floor((world_pos - hucre_ofset) / 16.0) - veri_baslangic;
	bool onde = false;
	if (hucre.x >= 0.0 && hucre.y >= 0.0 && hucre.x < veri_boyut.x && hucre.y < veri_boyut.y) {
		vec3 v = texelFetch(veri, ivec2(hucre), 0).rgb * 255.0;
		if (v.b > 128.0) {
			onde = orter(world_pos, v.r + v.g * 256.0);
		}
	}
	if (!onde) { discard; }
}
