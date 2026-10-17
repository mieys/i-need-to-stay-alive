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
