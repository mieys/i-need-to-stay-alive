shader_type canvas_item;

// ==================================================
// SALLANAN AĞAÇ - Harita > "Shader Eklenecek" > "Ağaç 0" / "Ağaç 1" / "Ağaç 2" karo katmanları
// ==================================================
// Kullanıcı isteği (2026-09-26): "ağaç layerlarına da hafif sallanan ağaç shaderı eklemeni istiyorum".
// Ağaçlar 16x16 karolardan (çoğu 3-4 x 4-6 karo) oluşuyor. Karonun İÇİNDE pikseli kaydırmak (sallanan ot.gdshader gibi) çok
// karolu bir ağacı karo sınırlarında yırtar - bu yüzden burada çizim hiç değişmez, karonun KÖŞELERİ (vertex) kaydırılır:
// her ağaç kökü sabit kalacak şekilde bütün halinde, yumuşakça (texel altı) eğilir. Aynı ağacın komşu karoları ortak köşede
// aynı kaymayı aldığı için dikiş yeri görünmez.
//
// Ağaç kimliği/kök/boy HÜCRE başına bir veri dokusundan okunur - scripts/tree_sway.gd oyun başında haritadaki gerçek
// yerleşimden (atlasta komşu karo = aynı ağaç) hesaplar. Veri yoksa (editör önizlemesi) ağaç durur.
//
// ÖN KATMAN (on_katman = true, 2026-10-08): scripts/depth_occluders.gd bu katmanların bir kopyasını oyuncuların ve öne alınmış yaratıkların ÜSTÜNDE (z_index 3) çizer;
// kopya SADECE kökü bir karakterin ayağından aşağıda (yani karakterin önünde) olan ağaç piksellerini ve sadece o karakterin gövde
// dikdörtgeninin içinde bırakır - karakter ağacın arkasındayken ağaç onu örter (bkz. derinlik_on_katman.gdshader). Kopya AYNI köşe
// kaydırmasını (sallanma) uyguladığı için asıl ağaçla birebir örtüşür.

// ---------------- SALINIM
uniform float strength : hint_range(0.0, 6.0) = 1.4;       // ağacın tepesinin en fazla kayması (texel) - rüzgarda tree_sway.gd büyütür
uniform float salinim_hizi : hint_range(0.0, 4.0) = 0.9;
uniform float egri_ussu : hint_range(0.5, 4.0) = 1.8;      // büyük = gövde daha sabit, sadece taç sallanır
uniform float esinti_gucu : hint_range(0.0, 1.0) = 0.35;   // haritada yavaşça gezen ortak esinti dalgası (ağaçlar birlikte eğilir)

// ---------------- DOLGU: TileSet "use_texture_padding" (varsayılan açık) - shader dolgulu çalışma anı dokusunu görür, karolar
// 18'lik hücrelerde, 1 px içeride (bkz. sallanan ot.gdshader aynı not). tree_sway.gd yazar.
uniform float karo_hucre = 18.0;
uniform float karo_dolgu = 1.0;

// ---------------- HÜCRE VERİSİ (tree_sway.gd yazar), RGBA8:
//   R = ağacın kökünün bu hücrenin üst kenarından uzaklığı (texel, >= 1 -> hücre dolu)
//   G = ağacın boyu (texel, 0 = sallanmaz), B = ortak esinti dalgasının fazı (kökün dünya x'inden), A = genlik (0..254, çift) + yatay çevrilmiş karo biti (1)
uniform sampler2D veri : filter_nearest;
uniform bool veri_var = false;
uniform vec2 veri_baslangic = vec2(0.0);
uniform vec2 veri_boyut = vec2(1.0);
uniform vec2 hucre_ofset = vec2(0.0);                       // hücre (0,0)'ın dünyadaki sol-üstü

// ---------------- ÖN KATMAN (depth_occluders.gd yazar): karakterler[i] = (ayak x, ayak y, yarım genişlik, boy) - dünya px
uniform bool on_katman = false;
uniform int karakter_sayisi = 0;
uniform vec4 karakterler[8];
uniform int yaratik_sayisi = 0;                              // YARATIKLAR (2026-10-09): derinlik_on_katman.gdshader ile AYNI kural/biçim
uniform vec4 yaratiklar[32];

varying vec2 world_orijin; // köşenin sallanmadan ÖNCEki dünya konumu (ön katmanda hücreyi bulmak için)

vec4 hucre_verisi(vec2 hucre) {
	vec2 p = hucre - veri_baslangic;
	if (p.x < 0.0 || p.y < 0.0 || p.x >= veri_boyut.x || p.y >= veri_boyut.y) {
		return vec4(0.0);
	}
	return texelFetch(veri, ivec2(p), 0) * 255.0;
}

void vertex() {
	world_orijin = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	if (veri_var) {
		vec2 dunya = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
		// Bu köşe karonun hangi köşesi: dokudaki karo içi konum 0 (sol/üst) ya da 16 (sağ/alt).
		vec2 a = UV / TEXTURE_PIXEL_SIZE;
		vec2 ic = a - (floor(a / karo_hucre) * karo_hucre + karo_dolgu);
		bool alt_kenar = ic.y > 8.0;
		bool doku_sag = ic.x > 8.0;
		vec2 izgara = floor((dunya - hucre_ofset) / 16.0 + 0.5); // köşenin ızgara noktası
		float satir = izgara.y - (alt_kenar ? 1.0 : 0.0);
		// Sütun: köşe soldaki hücrenin sağ kenarı mı, sağdakinin sol kenarı mı? Çevrilmiş karoda doku yönü terstir.
		vec4 v = vec4(0.0);
		vec4 sol = hucre_verisi(vec2(izgara.x - 1.0, satir));
		vec4 sag = hucre_verisi(vec2(izgara.x, satir));
		bool sol_cevrik = mod(sol.a, 2.0) > 0.5;
		bool sag_cevrik = mod(sag.a, 2.0) > 0.5;
		if (sol.r > 0.5 && doku_sag != sol_cevrik) {
			v = sol;
		} else if (sag.r > 0.5 && doku_sag == sag_cevrik) {
			v = sag;
		}
		if (v.g > 0.5) {
			// Her şey AĞAÇ başına sabit değerlerden (kök y, boy, B) - aynı ağacın tüm köşeleri aynı eğriyle kayar.
			float kok_y = hucre_ofset.y + satir * 16.0 + v.r;
			float h = clamp((kok_y - dunya.y) / v.g, 0.0, 1.0);
			float k = pow(h, egri_ussu);
			float faz = fract(sin(dot(vec2(kok_y, v.b * 7.0 + v.g), vec2(12.9898, 78.233))) * 43758.5453);
			float genlik = floor(v.a * 0.5) / 127.0;
			float t = TIME * salinim_hizi + faz * 6.2832;
			float esinti = sin(TIME * 0.35 - v.b / 255.0 * 6.2832) * esinti_gucu; // B = kökün x'inden dalga fazı
			float sway = strength * genlik * (sin(t) * 0.7 + sin(t * 0.53 + faz * 5.0) * 0.3 + esinti);
			VERTEX.x += sway * k;
		}
	}
}

// Pikseli içeren varlıklardan biri ağacın ARKASINDAYSA (ayağı kökten yukarıda) kopya çizilir; pikseli içeren bir varlık ağacın ÖNÜNDEYSE
// (ayağı kökten aşağıda / aynı hizada) o varlık görünür kalsın diye çizilmez (bkz. derinlik_on_katman.gdshader orter()).
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
	if (on_katman) {
		vec2 hucre = floor((world_orijin - hucre_ofset) / 16.0);
		vec4 v = hucre_verisi(hucre);
		bool onde = false;
		if (v.r > 0.5) {
			onde = orter(world_orijin, hucre_ofset.y + hucre.y * 16.0 + v.r);
		}
		if (!onde) { discard; }
	}
}
