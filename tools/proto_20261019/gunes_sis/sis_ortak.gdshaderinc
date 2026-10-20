// SİSLİ HAVA prototipleri ortak (madde 282, oyuna bağlı DEĞİL). gs_ortak.gdshaderinc'ten SONRA eklenir.
// Sis katmanı gün-gece renk geçişinden SONRA çizilir (renk geçişi uygulanmış sahneyi okur), HUD'dan önce.

uniform sampler2D ekran : hint_screen_texture, filter_nearest;
uniform float sis_k = 1.0;   // havanın sis şiddeti (geçişte 0 -> 1)

// Kasvetli renk: renksizleştir + serin/yeşilimsi ton + biraz karart.
vec3 sis_renk_ayari(vec3 c, float renksiz, vec3 ton, float karart) {
	vec3 g = mix(c, vec3(gs_lum(c)), renksiz * sis_k);
	return mix(c, g * ton * karart, sis_k);
}

// Sis rengi gece koyulaşır (gece sisi koyu mavi-gri, parlamaz).
vec3 sis_rengi(vec3 gunduz) {
	return mix(gunduz, gunduz * vec3(0.3, 0.34, 0.42), karanlik);
}

// Yer sisi kütlesi: zemine bağlı, rüzgarla çok yavaş sürüklenir, kendi içinde kıvrılır. 0..1.
float yer_sisi(vec2 px, float olcek) {
	vec2 p = (px + ruzgar_ofset) * olcek;
	vec2 warp = vec2(fbm(p * 0.8 + vec2(zaman * 0.03, 0.0)), fbm(p * 0.8 + vec2(5.2, 1.3) - vec2(0.0, zaman * 0.025))) - 0.5;
	return fbm(p + warp * 1.1);
}

// Karakterin etrafında sis biraz aralanır (yürürken sisin içinden geçiyor hissi). 0 = tam açık, 1 = etkisiz.
float aralik(vec2 px, float ic, float dis) {
	vec2 d = (px - oyuncu) * vec2(1.0, 1.8);
	return smoothstep(ic, dis, length(d));
}

// Kenar kararması (hafif, yuvarlak değil yatay elips).
float vinyet(vec2 uv, float guc) {
	vec2 d = (uv - 0.5) * vec2(1.0, 0.75);
	return 1.0 - guc * smoothstep(0.25, 0.62, length(d));
}
