shader_type canvas_item;
render_mode unshaded;

// Gün-gece + hava durumu ekran renk geçişi (bkz. scripts/atmosphere_overlay.gd, scripts/atmosphere_math.gd).
//
// Tüm ekranı kaplayan ColorRect bu shader'ı kullanır; vision_fog.gdshader gibi SAHNENİN KENDİSİNİ
// (hint_screen_texture) okuyup renk ayarını uygular - düz siyah bir katman bindirmek yerine: gece sahne kanal kanal
// lacivert bir ortam rengiyle çarpılır (mavi kanal en az kararır), doygunluk düşer, zifiri siyah yerine hafif lacivert
// bir taban eklenir. Gün batımı/doğumu aynı yolla turuncu-pembe, yağmur gri-mavi olur. Tam gündüz + açık havada bu
// geçiş HİÇ çizilmez (atmosphere_overlay.gd gizler).
//
// IŞIKLAR: light_map, ekranın 1/4 çözünürlüğünde her karede çizilen yumuşak ışık lekeleri (karakter etrafı, yetenek/
// mermi/namlu parıltıları; renkleri toplanır). Işık olan yerde ortam çarpanı ışığın rengiyle 1'e doğru kalkar (karanlık
// azalır, sahnenin gerçek renkleri ve doygunluğu geri gelir) + çekirdeğe renkli bir parıltı (glow) eklenir. Gündüz
// light_gain 0 olduğu için ışıklar görünmez.
//
// Bu geçiş sisten (vision_fog) ÖNCE çizilir; sis de kendi BackBufferCopy'si sayesinde bu sonucu okur.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D light_map : filter_linear;

// Sahne rengi kanal kanal bununla çarpılır (1,1,1 = değişiklik yok).
uniform vec3 ambient = vec3(1.0);
// 0 = gri, 1 = aynen.
uniform float saturation = 1.0;
// Işıksız (karanlık) bölgelere eklenen hafif renk - gece siyahlar zifiri değil lacivert kalsın.
uniform vec3 lift = vec3(0.0);
// Işık haritasının karanlığı kaldırma gücü (gündüz 0, gece ~1).
uniform float light_gain = 0.0;
// Işık çekirdeğine eklenen renkli parıltı gücü.
uniform float glow_gain = 0.0;
// Parıltı (bloom) SADECE bu eşiğin üstündeki ışıktan doğar: güçlü yetenek/mermi/namlu çekirdekleri parlar, karakterin
// etrafındaki hafif ışık (atmosphere_overlay.gd PLAYER_LIGHT_*) eşiğin altında kalır - karanlığı biraz açar ama etrafında
// renkli bir hale/leke oluşturup "sırıtmaz" (kullanıcı geri bildirimi 2026-09-25).
uniform float bloom_threshold = 0.2;

// PİKSEL IŞIK (kullanıcı bildirimi 2026-09-27: "parıltıların pixel parıltı olması gerekiyor, normal parıltı olduğu için
// sırıtıyor"): ışık haritası hâlâ yumuşak lekeler olarak çizilir, ama burada (1) DÜNYA piksel ızgarasına oturtulur -
// her light_pixel_size'lık dünya karesi tek bir renk alır (harita karolarıyla aynı piksel, kamera kayınca ızgara zemine
// yapışık kalır), (2) güç light_step'lik düz bantlara bölünür (piksel-art ışığı gibi basamaklı halkalar), (3) bant
// sınırları dünyaya yapışık 4x4 Bayer dither ile kırılır (light_dither = geçiş bandının genişliği, 0 = sert basamak).
// Uniform'ları atmosphere_overlay.gd her karede verir.
uniform float light_pixel_size = 1.0;
uniform float light_step = 0.05;
uniform float light_dither = 0.4;
// Şu anki kamera: ekran(tuval) = dünya * view_zoom + view_origin; view_size = görünür alan (UV 0..1 bunu kaplar).
uniform vec2 view_origin = vec2(0.0);
uniform float view_zoom = 1.0;
uniform vec2 view_size = vec2(1920.0, 1080.0);
// Işık haritasının ÇİZİLDİĞİ andaki kamera (harita LIGHT_MAP_EVERY karede bir güncellenir): dünya noktasını haritada
// doğru yerden okuyup aradaki karede kamera kaymasından doğan titremeyi önler. map_uv_scale = 1 / haritanın tuval boyu.
uniform vec2 map_origin = vec2(0.0);
uniform float map_zoom = 1.0;
uniform vec2 map_uv_scale = vec2(0.000520833, 0.000925926); // 1/1920, 1/1080 (uniform varsayılanı sabit ifade olmalı)

const float BAYER4[16] = {
	0.0 / 16.0, 8.0 / 16.0, 2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0, 6.0 / 16.0,
	3.0 / 16.0, 11.0 / 16.0, 1.0 / 16.0, 9.0 / 16.0,
	15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0, 5.0 / 16.0};

vec3 pixel_light(vec2 uv) {
	vec2 world = (uv * view_size - view_origin) / view_zoom;
	vec2 cell = floor(world / light_pixel_size);
	vec2 center = (cell + 0.5) * light_pixel_size;
	vec3 raw = texture(light_map, (center * map_zoom + map_origin) * map_uv_scale).rgb * light_gain;
	float m = max(raw.r, max(raw.g, raw.b));
	if (m <= 0.0001) {
		return vec3(0.0);
	}
	float x = m / light_step;
	float f = fract(x);
	// Bantların ortası düz, sadece light_dither genişliğindeki sınır bölgesi dither'lı.
	float t = light_dither > 0.001 ? clamp((f - 0.5) / light_dither + 0.5, 0.0, 1.0) : step(0.5, f);
	ivec2 b = ivec2(mod(cell, 4.0));
	float threshold = BAYER4[b.y * 4 + b.x] + 0.5 / 16.0;
	float q = (floor(x) + (t > threshold ? 1.0 : 0.0)) * light_step;
	return raw * (q / m);
}

void fragment() {
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	vec3 light = pixel_light(UV);
	float lit = clamp(max(light.r, max(light.g, light.b)), 0.0, 1.0);

	float luma = dot(scene, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(vec3(luma), scene, mix(saturation, 1.0, lit));

	// Işık ortamı en fazla 1'e (sahnenin gerçek rengine) kadar kaldırır; ortam zaten 1'in üstündeyse (rüzgarlı havanın
	// hafif serin tonu) ona dokunulmaz.
	vec3 illumination = max(ambient, min(ambient + light, vec3(1.0)));
	vec3 bloom = max(light - vec3(bloom_threshold), vec3(0.0)) / (1.0 - bloom_threshold);
	col = col * illumination + lift * (1.0 - lit) + bloom * bloom * glow_gain;
	COLOR = vec4(col, 1.0);
}
