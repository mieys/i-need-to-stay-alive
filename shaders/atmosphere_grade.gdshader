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

void fragment() {
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	vec3 light = texture(light_map, UV).rgb * light_gain;
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
