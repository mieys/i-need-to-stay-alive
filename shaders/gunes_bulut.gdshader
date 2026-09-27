shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// ==================================================
// GÜNEŞ IŞIĞI + BULUT GÖLGELERİ (scripts/sun_clouds.gd) - kullanıcı isteği (2026-09-26): "sağ üstten güneş ışığı süzülecek
// gökyüzünden ve bazı yerlerde bulut gölgeleri olacak ... oyuncunun hareketine göre hafif şekillenmeli ve göz yormamalı"
// (kullanıcının verdiği referans görüntüdeki gibi; ilk 3 prototip - sade leke / çapraz huzme / yaprak arası benek - reddedildi).
//
// Tek tam ekran geçiş, ekranı OKUMAZ (ucuz): premultiplied alpha karışımıyla çıktı = ışık + sahne x (1 - gölge).
// Dünyadan sonra, gün-gece renk geçişinden (atmosphere_grade) ve sisten ÖNCE çizilir; HUD etkilenmez.
//  - GÜNEŞ: sağ üstten sol alta akan paralel, yumuşak ışık demetleri; paralaksla dünyaya bağlı (zeminin yarı hızında kayar
//    -> oyuncu yürüdükçe şekillenir), bölge bölge yoğunlaşır. Sağ üste doğru hafif güçlenir (sabit spot değil).
//  - (Güneş köşesine prosedürel yaprak gölgesi de denendi - daire kümeleri yapay durdu, huzmeleri örttü; kaldırıldı.
//    İstenirse elle çizilmiş piksel yaprak dokusuyla eklenmeli.)
//  - BULUT GÖLGESİ: zemine bağlı (dünya koordinatı) büyük, yumuşak koyu alanlar; rüzgarla yavaşça sürüklenir.
//  Hepsi dünya texel ızgarasına oturur (piksel oyun), düşük kontrastlı ve yavaş (göz yormasın). Huzmeler ayrıca basamaklı +
//  dither'lı piksel ışık (bkz. piksel_basamak).

// ---------------- GEÇİŞ: 0 = bulut gölgesi (dünyadan sonra, renk geçişi + sisten ÖNCE - zemine düşen gölge);
// 1 = güneş huzmesi + parıltı (sisin ÜSTÜNDE, HUD'un altında - gökyüzünden gelen ışık; sis köşeleri
// koyulaştırdığı için sisten önce çizilen huzmeler görünmüyordu). İkisi aynı değerleri alır (sun_clouds.gd).
uniform int gecis = 0;

// ---------------- DÜNYA <-> EKRAN (sun_clouds.gd her karede)
uniform vec2 dunya_sol_ust = vec2(0.0);
uniform vec2 dunya_boyut = vec2(960.0, 540.0);
uniform vec2 kamera = vec2(0.0);
uniform float zaman = 0.0;

// ---------------- BULUT GÖLGELERİ
uniform vec2 bulut_ofset = vec2(0.0);                              // rüzgarla birikmiş sürüklenme (dünya px)
uniform float bulut_guc : hint_range(0.0, 0.4) = 0.15;             // gölgenin en koyu yeri (0.15 = %15 karartma)
uniform float bulut_kaplama : hint_range(0.0, 1.0) = 0.4;          // gökyüzünün ne kadarı bulut
uniform float bulut_olcegi : hint_range(0.0002, 0.005) = 0.0018;   // küçük = daha büyük bulutlar
uniform float bulut_yumusaklik : hint_range(0.02, 0.4) = 0.1;     // gölge kenarının genişliği

// ---------------- GÜNEŞ HUZMELERİ
// 2026-09-26 ikinci tur (kullanıcı: "çok parlak ve harekete göre fazla değişimi olmuyor, sağ üstten sabit bir spot ışığı
// gibi"): huzmeler artık EKRANA değil, paralaksla DÜNYAYA bağlı paralel ışık demetleri (sağ üstten sol alta) - oyuncu
// yürüdükçe zeminden daha yavaş kayıp değişir, bazı bölgelerde yoğun bazılarında seyrek. Sabit köşe parıltısı kaldırıldı;
// "güneş sağ üstte" hissini sadece hafif bir yön eğimi verir.
uniform float gunes_guc : hint_range(0.0, 0.5) = 0.16;             // huzme gücü (sun_clouds.gd yazar)
uniform vec3 gunes_renk : source_color = vec3(1.0, 0.91, 0.62);
uniform vec2 isik_yonu = vec2(-0.55, 0.835);                       // huzmelerin aktığı yön (ekran: sağ üstten sol alta)
uniform float huzme_genisligi : hint_range(4.0, 80.0) = 26.0;      // demetlerin tipik genişliği (dünya px)
uniform float huzme_boyu : hint_range(40.0, 1200.0) = 420.0;       // demetlerin tipik uzunluğu (dünya px)
uniform float paralaks : hint_range(0.0, 1.0) = 0.5;               // 0 = zemine yapışık, 1 = ekrana yapışık
uniform float yon_egimi : hint_range(0.0, 1.0) = 0.45;             // sağ üst ne kadar daha aydınlık (0 = her yer eşit)
uniform float sicaklik : hint_range(0.0, 0.3) = 0.05;              // güneşli (bulutsuz) her yere çok hafif sıcak ton
// PARLAMA SINIRI (kullanıcı 2026-09-26: "çok parlak olduğu anları kısalım sadece"): ışık bu eşiğin altında AYNEN kalır;
// üstündeki kısım (demetlerin üst üste bindiği / sağ üstte en yoğun yerler) yumuşakça tavana doğru sıkıştırılır.
uniform float parlaklik_esigi : hint_range(0.1, 1.0) = 0.45;
uniform float parlaklik_tavani : hint_range(0.2, 1.5) = 0.7;
// PİKSEL IŞIN (kullanıcı isteği 2026-09-27: "güneş ışınlarını pixel ışıklara dönüştür uyumlu görünmesini sağla"): demetin
// gücü isin_basamak'lık DÜZ bantlara bölünür (piksel-art ışık huzmesi gibi basamaklı), bant sınırları dünyaya yapışık 4x4
// Bayer dither ile kırılır (isin_dither = geçiş bandının genişliği, 0 = sert basamak). Gece ışıklarıyla aynı dil
// (atmosphere_grade.gdshader pixel_light). Hafif sıcak ton (sicaklik) düz bir taban olduğu için basamaklanmaz.
uniform float isin_basamak : hint_range(0.05, 0.5) = 0.2;
uniform float isin_dither : hint_range(0.0, 1.0) = 0.45;

const float BAYER4[16] = {
	0.0 / 16.0, 8.0 / 16.0, 2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0, 6.0 / 16.0,
	3.0 / 16.0, 11.0 / 16.0, 1.0 / 16.0, 9.0 / 16.0,
	15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0, 5.0 / 16.0};

float piksel_basamak(float x, vec2 cell) {
	if (x <= 0.0001) {
		return 0.0;
	}
	float k = x / isin_basamak;
	float f = fract(k);
	float t = isin_dither > 0.001 ? clamp((f - 0.5) / isin_dither + 0.5, 0.0, 1.0) : step(0.5, f);
	ivec2 b = ivec2(mod(cell, 4.0));
	float esik = BAYER4[b.y * 4 + b.x] + 0.5 / 16.0;
	return (floor(k) + (t > esik ? 1.0 : 0.0)) * isin_basamak;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03 + 17.1) * 0.30 + vnoise(p * 4.01 + 5.3) * 0.15;
}

void fragment() {
	vec2 world = dunya_sol_ust + SCREEN_UV * dunya_boyut;
	vec2 px = floor(world) + 0.5;                              // dünya texel ızgarası
	// Ekran konumu da texel ızgarasından (huzme kenarları piksel piksel).
	vec2 uv = (px - dunya_sol_ust) / dunya_boyut;

	// ---------- BULUT GÖLGESİ (zemine bağlı)
	vec2 cp = (px + bulut_ofset) * bulut_olcegi;
	vec2 warp = vec2(fbm(cp * 0.7 + zaman * 0.004), fbm(cp * 0.7 + vec2(9.2, 3.7) - zaman * 0.003)) - 0.5;
	float c = fbm(cp + warp * 0.9);
	float esik = 1.0 - bulut_kaplama;
	float bulut_k = smoothstep(esik - bulut_yumusaklik * 0.5, esik + bulut_yumusaklik, c);

	// ---------- BİRLEŞTİR (her geçiş sadece kendi işini hesaplar)
	if (gecis == 0) {
		COLOR = vec4(0.0, 0.0, 0.0, bulut_k * bulut_guc);
	} else {
		// ---------- GÜNEŞ HUZMELERİ: paralaks uzayında (zeminden yavaş kayar) paralel demetler.
		vec2 sp = px - (px - kamera) * paralaks;
		vec2 dir = normalize(isik_yonu);
		vec2 perp = vec2(-dir.y, dir.x);
		float u = dot(sp, perp) / huzme_genisligi;                    // demetlere dik (demetleri ayırır)
		float v = dot(sp, dir) / huzme_boyu;                          // demet boyunca
		// Demetler: dik eksende iki ölçekli gürültü (geniş demetler + ince yarıklar), çok yavaş kıpırdar.
		float n = vnoise(vec2(u, v * 0.35 + zaman * 0.05)) * 0.75 + vnoise(vec2(u * 2.6 + 11.0, v * 0.5 - zaman * 0.07)) * 0.25;
		float huzme = smoothstep(0.46, 0.8, n);
		// Demetlerin boyu: demet boyunca ara ara kesilir (sonsuz düz çizgi olmasın).
		huzme *= smoothstep(0.3, 0.6, vnoise(vec2(u * 0.5 + 5.0, v * 2.0)));
		// Bölgesel yoğunluk: bazı yerlerde (ağaç tacı aralığı) demetler yoğun, bazılarında yok - yürüdükçe değişir.
		huzme *= 0.25 + 0.75 * smoothstep(0.3, 0.58, fbm(sp * 0.0022 + vec2(3.0, 7.0)));
		// Güneş sağ üstte: o yöne doğru biraz daha güçlü (spot değil, ekran boyunca yumuşak eğim).
		float egim = mix(1.0 - yon_egimi, 1.0, clamp(uv.x * 0.7 + (1.0 - uv.y) * 0.5, 0.0, 1.0));
		float golge = 1.0 - bulut_k * 0.75;
		float gunes = piksel_basamak(huzme * egim * golge, floor(px)) + sicaklik * golge;
		if (gunes > parlaklik_esigi) {
			float fazla = gunes - parlaklik_esigi;
			gunes = parlaklik_esigi + fazla / (1.0 + fazla / max(parlaklik_tavani - parlaklik_esigi, 0.001));
		}
		COLOR = vec4(gunes_renk * gunes * gunes_guc, 0.0);
	}
}
