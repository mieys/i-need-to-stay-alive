shader_type canvas_item;
render_mode unshaded;

// HARİTA RENK AYARI PROTOTİPİ (2026-10-16, oyuna bağlı DEĞİL; bkz. harita_renk_capture.gd).
// Kullanıcı isteği: "haritayı daha az göz yoracak fakat yine de güzel gösterecek 4 yeni prototip renk ayarı".
// Altındaki sahneyi (hint_screen_texture) okur; SADECE haritanın üstüne çizilir - karakterler/yaratıklar bundan SONRA
// çizildiği için tam renkte kalır (zemin geri çekilir, oynanış öne çıkar).
//
// Sıra: doku sakinleştirme -> pozlama -> ton/doygunluk (yeşil ve toprak ayrı) -> kontrast -> parlak tepe sıkıştırma
// -> gölge/ışık tonlaması -> taban.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// 1 dünya pikselinin ekran UV boyu (oyunda kamera yakınlaştırması 2 -> 2 ekran pikseli).
uniform vec2 texel = vec2(0.00104167, 0.00185185);

uniform float exposure = 1.0;
uniform float contrast = 1.0;
uniform float pivot = 0.45;
// Bu parlaklığın üstü yumuşakça bastırılır (gözü yoran açık sarı-yeşil yüzeyler).
uniform float knee = 1.0;
uniform float knee_strength = 0.0;
uniform float saturation = 1.0;
// Sarı-yeşil (çimen/yaprak) tonlarına EK doygunluk çarpanı ve ton kaydırması (+ = maviye/serine, - = sarıya/sıcağa).
uniform float green_sat = 1.0;
uniform float green_hue = 0.0;
// Sarı-yeşil tonların parlaklık çarpanı (<1 = daha derin yeşil; griye çekmeden parıltıyı azaltır).
uniform float green_val = 1.0;
// Parlak bölgelerde doygunluk çarpanı (göz kamaştıran açık yüzeyler sakinleşir, gölgeler canlı kalır).
uniform float hi_desat = 1.0;
// Turuncu-kahve (toprak/yol) tonlarına ek doygunluk çarpanı.
uniform float warm_sat = 1.0;
// Mavi (su) tonlarına ek doygunluk çarpanı.
uniform float blue_sat = 1.0;
uniform vec3 shadow_tint = vec3(0.0);
uniform vec3 highlight_tint = vec3(0.0);
uniform vec3 lift = vec3(0.0);
// Doku sakinleştirme: küçük, yüksek frekanslı benekler (çiçek/yonca/çakıl/ot tepesi) komşu ortalamasına çekilir;
// büyük kenarlar (ağaç gövdesi, su kıyısı, yol sınırı) calm_edge'den büyük fark olduğu için korunur.
uniform float calm = 0.0;
uniform float calm_edge = 0.12;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;

	if (calm > 0.001) {
		// 5x5 dünya pikseli ortalaması.
		vec3 sum = vec3(0.0);
		for (int y = -2; y <= 2; y++) {
			for (int x = -2; x <= 2; x++) {
				sum += texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * texel).rgb;
			}
		}
		vec3 mean = sum / 25.0;
		vec3 d = c - mean;
		float dev = abs(luma(d)) + 0.5 * length(d);
		float keep = smoothstep(calm_edge * 0.5, calm_edge, dev);
		c = mean + d * mix(1.0 - calm, 1.0, keep);
	}

	c *= exposure;

	vec3 hsv = rgb2hsv(clamp(c, 0.0, 1.0));
	float h = hsv.x;
	// Gri/taş pikseller (doygunluğu düşük) yeşil sayılmasın.
	float wg = smoothstep(0.11, 0.19, h) * (1.0 - smoothstep(0.43, 0.5, h)) * smoothstep(0.08, 0.2, hsv.y);
	float ww = smoothstep(0.0, 0.03, h) * (1.0 - smoothstep(0.1, 0.15, h));
	float wb = smoothstep(0.48, 0.53, h) * (1.0 - smoothstep(0.68, 0.75, h));
	hsv.x = fract(h + green_hue * wg);
	float hi = smoothstep(0.35, 0.75, luma(c));
	hsv.y = clamp(hsv.y * saturation * mix(1.0, green_sat, wg) * mix(1.0, warm_sat, ww) * mix(1.0, blue_sat, wb)
			* mix(1.0, hi_desat, hi), 0.0, 1.0);
	vec3 g = hsv2rgb(hsv);
	// Doygunluk düşünce algılanan parlaklık yükselmesin: luma korunur (yeşiller ayrıca green_val ile koyulaşır).
	float l0 = luma(c) * mix(1.0, green_val, wg);
	float l1 = luma(g);
	c = l1 > 0.0001 ? g * (l0 / l1) : g;

	c = (c - vec3(pivot)) * contrast + vec3(pivot);

	float l = luma(c);
	if (knee_strength > 0.0 && l > knee) {
		float over = l - knee;
		float nl = knee + over / (1.0 + over * knee_strength);
		c *= nl / l;
		l = nl;
	}

	l = clamp(l, 0.0, 1.0);
	c += shadow_tint * (1.0 - l) + highlight_tint * l + lift;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
