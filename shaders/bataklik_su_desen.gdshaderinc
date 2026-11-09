// KARA BATAKLIK SUYU DESENİ (madde 524) - ortak: "Su/Su" katmanı (scenes/bataklik_su.gdshader) ve suya giren karakterin ayak örtüsü
// (scenes/bataklik_su_ayak.gdshader) AYNI rengi dünya pikseline ve zamana göre hesaplar -> örtü çevresindeki suyla piksel piksel aynı.
// Tasarım notu: scenes/bataklik_su.gdshader başı. Kullanım: vec3 c = bs_su_rengi(floor(world_pos), TIME); sonra harita_renk().

uniform vec4 su_rengi : source_color = vec4(0.141, 0.404, 0.294, 1.0);    // #24674b - setin su karosu
uniform vec4 su_koyu : source_color = vec4(0.129, 0.378, 0.278, 1.0);     // derin / çürük yaprak lekesi (kısık: göz yormasın)
uniform vec4 su_daha_koyu : source_color = vec4(0.118, 0.349, 0.259, 1.0);
uniform vec4 su_acik : source_color = vec4(0.153, 0.420, 0.306, 1.0);     // yüzeyde açık bulanıklık
uniform vec4 parilti_rengi : source_color = vec4(0.537, 0.729, 0.569, 1.0);
uniform float leke_olcegi : hint_range(0.002, 0.04) = 0.011;              // küçük = büyük lekeler
uniform float kivrim : hint_range(0.0, 60.0) = 26.0;
uniform float akis_hizi : hint_range(0.0, 10.0) = 2.2;                    // lekelerin kayma hızı (dünya px / sn)
uniform float koyu_esik : hint_range(0.3, 0.9) = 0.61;
uniform float daha_koyu_esik : hint_range(0.3, 0.95) = 0.74;
uniform float acik_esik : hint_range(0.05, 0.6) = 0.35;
uniform float parilti_yogunlugu : hint_range(0.0, 0.2) = 0.018;           // 9 px hücre başına
uniform float parilti_hizi : hint_range(0.05, 2.0) = 0.33;                // yanıp sönme döngüsü / sn

float bs_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bs_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = bs_hash12(i);
	float b = bs_hash12(i + vec2(1.0, 0.0));
	float c = bs_hash12(i + vec2(0.0, 1.0));
	float d = bs_hash12(i + vec2(1.0, 1.0));
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float bs_fbm(vec2 p) {
	return bs_vnoise(p) * 0.55 + bs_vnoise(p * 2.03) * 0.30 + bs_vnoise(p * 4.01) * 0.15;
}

// px = floor(dünya konumu), t = TIME. Döner: suyun o pikseldeki rengi (renk ayarı uygulanmamış).
vec3 bs_su_rengi(vec2 px, float t) {
	// Lekeler: iki katman farklı yönde, çok yavaş kayar (zaman TEK yönlü artar ama desen kıvrımlı olduğu için tekrar fark edilmez)
	vec2 akis = vec2(t * akis_hizi, t * akis_hizi * 0.37);
	vec2 w = vec2(bs_fbm((px + akis * 0.5) * 0.013), bs_fbm((px - akis * 0.3) * 0.013 + vec2(17.3, 5.1))) - 0.5;
	float z = bs_fbm((px + akis + w * kivrim) * leke_olcegi);
	vec3 c = su_rengi.rgb;
	if (z > koyu_esik) { c = su_koyu.rgb; }
	if (z > daha_koyu_esik) { c = su_daha_koyu.rgb; }
	if (z < acik_esik) { c = su_acik.rgb; }
	// Pırıltı: 9x9 hücrede en fazla bir nokta, döngünün kısa bir anında 1 px, tepe anında artı biçimi (3 px kol)
	const float HC = 9.0;
	vec2 hc = floor(px / HC);
	float h = bs_hash12(hc + vec2(7.7, 1.9));
	if (h < parilti_yogunlugu) {
		vec2 o = floor(vec2(bs_hash12(hc + vec2(2.3, 9.1)), bs_hash12(hc + vec2(5.6, 3.3))) * (HC - 2.0)) + 1.0;
		vec2 l = px - hc * HC - o;
		float ph = fract(t * parilti_hizi + h * 31.0);
		if (ph < 0.10) {
			bool merkez = l == vec2(0.0);
			bool kol = ph > 0.03 && ph < 0.07 && (abs(l.x) + abs(l.y) == 1.0);
			if (merkez || kol) {
				c = mix(c, parilti_rengi.rgb, merkez ? 0.85 : 0.5);
			}
		}
	}
	return c;
}
