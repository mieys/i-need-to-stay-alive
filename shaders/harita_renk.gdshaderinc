// HARİTA RENK AYARI - "A - Derin Çayır" (madde 181, 2026-10-16; prototip ve karşılaştırma: tools/proto_20261016/harita_renk/).
// Kullanıcı isteği: "haritayı daha az göz yoracak fakat yine de güzel gösterecek" renk ayarı; 4 prototipten A seçildi.
//
// Haritanın TÜM shader'ları fragment()'in EN SONUNDA `COLOR.rgb = harita_renk(COLOR.rgb);` çağırır: zemin (toprak kir, çimen yaprak),
// çimen kümeleri (mini çim renk), su, sallanan ot, sallanan ağaç, saklanma çalılığı, ön katman kopyaları (derinlik_on_katman) ve orman
// dokusu (orman_parcalari_doku). Materyalsiz katmanlar (orman, ev, köprü, maden, dış orman...) harita_renk_duz.gdshader'ı alır
// (bkz. scripts/map_color_grade.gd). Yeni bir harita shader'ı eklersen aynı satırı ekle, yoksa o katman eski parlak renkte kalır.
// Karakter/yaratık/efekt/HUD bundan ETKİLENMEZ - zemin geri çekilir, oynanış öne çıkar. Gece/yağmur rengi (atmosphere_grade) bunun
// üstüne çarpılır.
//
// Ne yapar: parlak sarı-yeşil çimen gözü yoruyordu -> yeşil griye çekilmeden KOYULAŞIR (%12) ve gerçek yeşile döner, parlak yüzeylerin
// doygunluğu ve en parlak tepeler bastırılır, gölgelere çok hafif serin ton. Kontrast aynı (piksel sanatı keskin kalır).
// Prototipteki "doku sakinleştirme" (calm 0,25) komşu pikselleri okuduğu için katman shader'ında YOK.
//
// HR_GUC = 0.0 -> ayar kapalı (eski renkler, karşılaştırma için).

const float HR_GUC = 1.0;
// Sarı-yeşil tonların kayması (+ = maviye doğru: sarımsı çimen gerçek yeşile döner).
const float HR_YESIL_TON = 0.02;
// Sarı-yeşil tonların parlaklık ve doygunluk çarpanı.
// Doygunluk 2026-10-16 (madde 191, kullanıcı: "renk doygunluğu çok düştü... biraz solgun"): 0,92 -> 0,97, parlak 0,85 -> 0,93
// (parlak yeşilde toplam x0,78 -> x0,90; kaybın yarısından fazlası geri, koyulaşma/diz aynı).
const float HR_YESIL_PARLAKLIK = 0.88;
const float HR_YESIL_DOYGUNLUK = 0.97;
// Parlak bölgelerde (luma 0,35 -> 0,75) doygunluk çarpanı.
const float HR_PARLAK_DOYGUNLUK = 0.93;
// Bu parlaklığın üstü yumuşakça bastırılır.
const float HR_DIZ = 0.7;
const float HR_DIZ_GUC = 1.2;
// Karanlık bölgelere eklenen hafif serin ton.
const vec3 HR_GOLGE_TONU = vec3(0.0, 0.003, 0.01);

float hr_luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 hr_rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hr_hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 harita_renk(vec3 src) {
	if (HR_GUC <= 0.0) {
		return src;
	}
	vec3 c = clamp(src, 0.0, 1.0);
	vec3 hsv = hr_rgb2hsv(c);
	// Gri/taş pikseller (doygunluğu düşük) yeşil sayılmaz.
	float wg = smoothstep(0.11, 0.19, hsv.x) * (1.0 - smoothstep(0.43, 0.5, hsv.x)) * smoothstep(0.08, 0.2, hsv.y);
	float l0 = hr_luma(c);
	hsv.x = fract(hsv.x + HR_YESIL_TON * wg);
	hsv.y = clamp(hsv.y * mix(1.0, HR_YESIL_DOYGUNLUK, wg) * mix(1.0, HR_PARLAK_DOYGUNLUK, smoothstep(0.35, 0.75, l0)), 0.0, 1.0);
	vec3 g = hr_hsv2rgb(hsv);
	// Doygunluk düşünce algılanan parlaklık yükselmesin: luma korunur, yeşiller ayrıca koyulaşır.
	float lt = l0 * mix(1.0, HR_YESIL_PARLAKLIK, wg);
	float l1 = hr_luma(g);
	c = l1 > 0.0001 ? g * (lt / l1) : g;
	float l = hr_luma(c);
	if (l > HR_DIZ) {
		float over = l - HR_DIZ;
		float nl = HR_DIZ + over / (1.0 + over * HR_DIZ_GUC);
		c *= nl / l;
		l = nl;
	}
	c += HR_GOLGE_TONU * (1.0 - clamp(l, 0.0, 1.0));
	return mix(src, clamp(c, 0.0, 1.0), HR_GUC);
}

// ---------------------------------------------------------------------------------------------------------------------------------
// DERİN ORMAN bölge renk ayarı (madde 359, prototip madde 358 "B - Kadim Kara Orman"). Haritanın tepe arkası bölgeleri kendi renginde:
// Kuzey "Kadim Kara Orman" = koyu yeşil-camgöbeği, gölge lekeli; Batı "Kızıl Bataklık" = karanlık, kızıla/mora çalan hastalıklı ton;
// Doğu "Işıyan Kayalıklar" = soğuk, hafif açık taş tonu. Işıyan pikseller (doygun mavi/turuncu ve parlak: mantar, kristal) karanlıktan muaf.
// Bölge = global `derin_orman_maske` (project.godot [shader_globals], assets/map/derin_orman_bolge.png, tools/derin_orman/gen_bolge_maskesi.py):
// 256x256, hücre başına 1 px, R = Kuzey, G = Batı, B = Doğu (madde 360), A = Güney "Sisli Sazlık" (madde 361), yumuşak kenarlı; kanallar sınırda
// üst üste binerse toplam 1'e bölünür (geçit/uçurum hattında yavaş başlar). Dünya -> doku: Harita düğümü main.tscn'de
// (-2, 21) ofsetinde (hücre (0,0) sol üst köşesi), 256 hücre x 16 px. Bölge dışında renk aynen döner.
// KULLANIM: harita shader'ları fragment()'in EN SONUNDA `COLOR.rgb = harita_renk_d(COLOR.rgb, <dünya konumu varying'i>);`
// (dünya konumu = vertex()'te MODEL_MATRIX * VERTEX; sallanan katmanlarda sallanma ÖNCESİ). Karakter/yaratık/efekt etkilenmez.
// Bitki katmanları (çimen kümeleri, çalılar, saklanma çalılığı) önce do_bitki ile bölgenin bitki rengine boyanır: harita_renk_bitki_d;
// ağaç katmanları (madde 365) do_agac_guc ile bölgenin ağaç paletine: harita_renk_agac_d.
// ZEMİN (madde 361/363): Harita.tmx'te gerçek karolar (tools/derin_orman/zemin_karolari.py) - shader'da hesaplanmaz.
global uniform sampler2D derin_orman_maske : filter_linear, repeat_disable;
const vec2 DO_HARITA_KOKU = vec2(-2.0, 21.0);
const float DO_HARITA_BOYU = 4096.0;
// Oyun alanı dışındaki dış çerçeve (32/20 hücre, madde 119) maskenin KENAR değerini alır (bölge harita kenarında kesilmesin);
// daha uzağı (iç mekanlar 20000+ px uzakta) ayarsız kalır.
const float DO_KENAR_PAYI = 0.14;
// Kuzey ayarı: doygunluk payı, ton çarpanı, koyuluk (taban + gürültü payı, 60 px'lik gölge lekeleri), kontrast üssü, gölge tonu. Madde 361: zemin artık bölgenin kendi dokusu -> ayar yumuşatıldı (koyuluk 0,55 -> 0,66, ton daha az camgöbeği).
const float DO_K_DOYGUNLUK = 0.85;
const vec3 DO_K_TON = vec3(0.86, 0.98, 0.96);
const float DO_K_KOYU = 0.66;
const float DO_K_LEKE = 0.13;
const float DO_K_LEKE_BOY = 60.0;
const float DO_K_US = 1.08;
const vec3 DO_K_GOLGE = vec3(0.004, 0.012, 0.022);
// Batı ayarı (madde 360): doygunluk payı, ton çarpanı (yeşil -> pas/kızıl), koyuluk + leke payı, üs, mor gölge. Madde 361: yumuşatıldı (şeftali toprak kendi renginde kalsın).
const float DO_B_DOYGUNLUK = 0.9;
const vec3 DO_B_TON = vec3(1.0, 0.94, 0.88);
const float DO_B_KOYU = 0.8;
const float DO_B_LEKE = 0.12;
const float DO_B_US = 1.05;
const vec3 DO_B_GOLGE = vec3(0.015, 0.0, 0.01);
// Doğu ayarı (madde 360): soğuk taş, kuzeyden ve batıdan açık. Madde 361: daha az soğuk (bej taş grileşmesin).
const float DO_D_DOYGUNLUK = 0.85;
const vec3 DO_D_TON = vec3(0.93, 0.97, 1.02);
const float DO_D_KOYU = 0.88;
const float DO_D_LEKE = 0.06;
const float DO_D_US = 1.0;
const vec3 DO_D_GOLGE = vec3(0.0, 0.01, 0.03);
// Güney ayarı (madde 361): sisli, hafif serin yeşil - tehlikesi az, en hafif ayar.
const float DO_G_DOYGUNLUK = 0.9;
const vec3 DO_G_TON = vec3(0.93, 1.0, 0.95);
const float DO_G_KOYU = 0.9;
const float DO_G_LEKE = 0.06;
const float DO_G_US = 1.0;
const vec3 DO_G_GOLGE = vec3(0.0, 0.012, 0.012);
// Işıyan piksellerin karanlıktan muaf payı (1 = hiç kararmaz).
const float DO_ISIK_MUAF = 0.8;

// TAM SAYI hash (madde 361 2. tur): eski `fract(sin(dot(p, k)) * 43758)` hash'i büyük argümanda o kadar hassas ki ekran kartı aynı kafes
// noktasını iki komşu hücreden (floor(p) ile i + (1, 0)) bir ulp farkla hesaplayınca bambaşka değer veriyordu -> değer gürültüsü kafes
// çizgilerinde SIÇRIYORDU: gölcükler/yamalar/bölge sınırı düz çizgilerle kesiliyor, gölcük kenarı karo karo bloğa yayılıyordu. Girdi
// floor'lanıp tam sayıyla karıştırılır (orman_parcalari_doku.gdshader ile aynı fikir); negatif koordinatlar kaydırılır.
float do_hash(vec2 p) {
	uvec2 u = uvec2(ivec2(floor(p)) + ivec2(1048576));
	uint h = u.x * 1597334677u ^ u.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	h ^= h >> 16u;
	return float(h & 16777215u) / 16777215.0;
}

float do_gurultu(vec2 p) {
	p = vec2(0.8 * p.x - 0.6 * p.y, 0.6 * p.x + 0.8 * p.y); // kafes eksenine hizalı lekeler görünmesin (değer gürültüsü)
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(do_hash(i), do_hash(i + vec2(1.0, 0.0)), f.x), mix(do_hash(i + vec2(0.0, 1.0)), do_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 do_ayar(vec3 c, float l, float n, float doy, vec3 ton, float koyu, float leke, float us, vec3 golge) {
	vec3 g = mix(vec3(l), c, doy);
	return pow(clamp(g * ton * (koyu + leke * n), 0.0, 1.0), vec3(us)) + golge;
}

// Dünya konumundaki bölge payları (r Kuzey, g Batı, b Doğu, a Güney); toplam 1'i aşmaz. Harita/çerçeve dışında 0.
vec4 do_bolge(vec2 dunya) {
	vec2 uv = (dunya - DO_HARITA_KOKU) / DO_HARITA_BOYU;
	if (uv.x < -DO_KENAR_PAYI || uv.y < -DO_KENAR_PAYI || uv.x > 1.0 + DO_KENAR_PAYI || uv.y > 1.0 + DO_KENAR_PAYI) {
		return vec4(0.0);
	}
	vec4 z = texture(derin_orman_maske, clamp(uv, vec2(0.5 / 256.0), vec2(1.0 - 0.5 / 256.0)));
	float top = z.r + z.g + z.b + z.a;
	return top > 1.0 ? z / top : z;
}

vec3 derin_orman_renk(vec3 c, vec2 dunya) {
	vec4 z = do_bolge(dunya);
	if (z.r + z.g + z.b + z.a <= 0.003) {
		return c;
	}
	float l = hr_luma(c);
	float n = do_gurultu(dunya / DO_K_LEKE_BOY);
	vec3 d = vec3(0.0);
	if (z.r > 0.003) {
		d += z.r * (clamp(do_ayar(c, l, n, DO_K_DOYGUNLUK, DO_K_TON, DO_K_KOYU, DO_K_LEKE, DO_K_US, DO_K_GOLGE), 0.0, 1.0) - c);
	}
	if (z.g > 0.003) {
		d += z.g * (clamp(do_ayar(c, l, n, DO_B_DOYGUNLUK, DO_B_TON, DO_B_KOYU, DO_B_LEKE, DO_B_US, DO_B_GOLGE), 0.0, 1.0) - c);
	}
	if (z.b > 0.003) {
		d += z.b * (clamp(do_ayar(c, l, n, DO_D_DOYGUNLUK, DO_D_TON, DO_D_KOYU, DO_D_LEKE, DO_D_US, DO_D_GOLGE), 0.0, 1.0) - c);
	}
	if (z.a > 0.003) {
		d += z.a * (clamp(do_ayar(c, l, n, DO_G_DOYGUNLUK, DO_G_TON, DO_G_KOYU, DO_G_LEKE, DO_G_US, DO_G_GOLGE), 0.0, 1.0) - c);
	}
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.0001);
	bool mavi = c.b > c.r + 0.12 && c.b > c.g - 0.05;
	bool turuncu = c.r > 0.75 && c.g > 0.35 && c.b < 0.35 && c.r > c.g + 0.2;
	float isik = ((mavi || turuncu) && sat > 0.45 && mx > 0.55) ? 1.0 : 0.0;
	return clamp(c + d * (1.0 - isik * DO_ISIK_MUAF), 0.0, 1.0);
}

// BÖLGE ZEMİNİ (madde 361) artık burada HESAPLANMAZ (madde 363): aynı hesap tools/derin_orman/zemin_karolari.py'de (numpy, GPU ile piksel
// piksel aynı) karolara pişirilir -> Harita.tmx "Yer/Derin orman zemini" + yerinde değişen kıyı/plato/uçurum karoları (Tiled'da da görünür).

// Bitki boyası (madde 361): çimen kümeleri / çalılar / saklanma çalılığı bölgede o bölgenin bitki rengine (parlaklık -> 3 duraklı renk).
const vec3 DOB_K_KOYU = vec3(0.10, 0.11, 0.10);
const vec3 DOB_K_ORTA = vec3(0.30, 0.31, 0.25);
const vec3 DOB_K_ACIK = vec3(0.56, 0.54, 0.43);
const vec3 DOB_B_KOYU = vec3(0.22, 0.06, 0.07);
const vec3 DOB_B_ORTA = vec3(0.45, 0.15, 0.13);
const vec3 DOB_B_ACIK = vec3(0.70, 0.32, 0.24);
const vec3 DOB_D_KOYU = vec3(0.06, 0.17, 0.15);
const vec3 DOB_D_ORTA = vec3(0.21, 0.44, 0.34);
const vec3 DOB_D_ACIK = vec3(0.52, 0.74, 0.52);
const vec3 DOB_G_KOYU = vec3(0.15, 0.19, 0.06);
const vec3 DOB_G_ORTA = vec3(0.40, 0.47, 0.15);
const vec3 DOB_G_ACIK = vec3(0.70, 0.75, 0.33);
// Bölge başına boyama gücü (Doğu yeşili zaten uyuyor: yarı).
const vec4 DOB_GUC = vec4(1.0, 1.0, 0.5, 0.85);
// AĞAÇ YAPRAKLARI (madde 365; kullanıcı: "bazı bölgelerde ağaçlar bölgeleriyle uyumsuz görünüyor"): haritanın kendi ağaçları (Ağaç 0/1/2) ve dış
// çerçeve ormanı (Dış orman 1-4) bölgede bölgenin AĞAÇ paletine boyanır (aynı parlaklık -> 3 duraklı renk kuralı, sadece yeşil pikseller; gövde,
// çiçek, taş kendi renginde). Kuzey kara iğne yaprak, Batı kızıl (eski dış orman rengi), Doğu kayalık paketinin çamları, Güney bataklık
// paketinin ağaçları (paletler o paketlerin yapraklarından ölçüldü). Paketten gelen bölge ağaçları ("Ağaç ölü") boyanmaz (tree_sway.gd).
const vec3 DOA_K_KOYU = vec3(0.05, 0.09, 0.09);
const vec3 DOA_K_ORTA = vec3(0.14, 0.24, 0.21);
const vec3 DOA_K_ACIK = vec3(0.36, 0.46, 0.38);
const vec3 DOA_D_KOYU = vec3(0.08, 0.18, 0.19);
const vec3 DOA_D_ORTA = vec3(0.10, 0.30, 0.27);
const vec3 DOA_D_ACIK = vec3(0.24, 0.54, 0.38);
const vec3 DOA_G_KOYU = vec3(0.07, 0.15, 0.09);
const vec3 DOA_G_ORTA = vec3(0.24, 0.43, 0.18);
const vec3 DOA_G_ACIK = vec3(0.44, 0.63, 0.26);
// Ağaç katmanları (Batı'da haritanın ağacı kalmadı: 0) / dış çerçeve ormanı (Batı kızıl yaprak, 2. tur) boyama gücü.
const vec4 DOA_GUC = vec4(0.85, 0.0, 0.8, 0.6);
const vec4 DOB_AGAC_GUC = vec4(0.85, 0.85, 0.8, 0.6);

vec3 dob_harita(float t, vec3 k, vec3 o, vec3 a) {
	return t < 0.5 ? mix(k, o, t * 2.0) : mix(o, a, t * 2.0 - 1.0);
}

vec3 do_agac_guc(vec3 c, vec2 dunya, vec4 guc) {
	vec4 z = do_bolge(dunya) * guc * smoothstep(-0.02, 0.05, c.g - max(c.r, c.b));
	float top = z.r + z.g + z.b + z.a;
	if (top <= 0.003) {
		return c;
	}
	float t = clamp((hr_luma(c) - 0.1) / 0.62, 0.0, 1.0);
	vec3 r = c * (1.0 - top);
	r += z.r * dob_harita(t, DOA_K_KOYU, DOA_K_ORTA, DOA_K_ACIK);
	r += z.g * dob_harita(t, DOB_B_KOYU, DOB_B_ORTA, DOB_B_ACIK);
	r += z.b * dob_harita(t, DOA_D_KOYU, DOA_D_ORTA, DOA_D_ACIK);
	r += z.a * dob_harita(t, DOA_G_KOYU, DOA_G_ORTA, DOA_G_ACIK);
	return r;
}

vec3 do_bitki_guc(vec3 c, vec2 dunya, vec4 guc) {
	// sadece yeşil (yaprak) pikseller: çalıdaki çiçek, taş, çakıl kendi renginde kalır
	vec4 z = do_bolge(dunya) * guc * smoothstep(-0.02, 0.05, c.g - max(c.r, c.b));
	float top = z.r + z.g + z.b + z.a;
	if (top <= 0.003) {
		return c;
	}
	float t = clamp((hr_luma(c) - 0.1) / 0.62, 0.0, 1.0);
	vec3 r = c * (1.0 - top);
	r += z.r * dob_harita(t, DOB_K_KOYU, DOB_K_ORTA, DOB_K_ACIK);
	r += z.g * dob_harita(t, DOB_B_KOYU, DOB_B_ORTA, DOB_B_ACIK);
	r += z.b * dob_harita(t, DOB_D_KOYU, DOB_D_ORTA, DOB_D_ACIK);
	r += z.a * dob_harita(t, DOB_G_KOYU, DOB_G_ORTA, DOB_G_ACIK);
	return r;
}

vec3 do_bitki(vec3 c, vec2 dunya) {
	return do_bitki_guc(c, dunya, DOB_GUC);
}

vec3 harita_renk_d(vec3 src, vec2 dunya) {
	return derin_orman_renk(harita_renk(src), dunya);
}

// Bitki katmanları: önce bölgenin bitki rengi, sonra harita + bölge renk ayarı.
vec3 harita_renk_bitki_d(vec3 src, vec2 dunya) {
	return harita_renk_d(do_bitki(src, dunya), dunya);
}

// Ağaç katmanları (madde 365): önce bölgenin ağaç paleti (guc 0 = boyanmaz, "Ağaç ölü"), sonra harita + bölge renk ayarı.
vec3 harita_renk_agac_d(vec3 src, vec2 dunya, float guc) {
	return harita_renk_d(guc > 0.0 ? do_agac_guc(src, dunya, DOA_GUC * guc) : src, dunya);
}
