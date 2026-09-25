shader_type canvas_item;
render_mode blend_add;

// Ödül kartının arkasındaki dönen ışık huzmeleri + kartın kenarına sarılan hale (bkz. scripts/reward_rays.gd - sandıktan
// çıkan kartlar). Kullanıcı isteği (2026-09-25): "kartın parıltılı ve ödüllendirici gözükmesi gerekiyor ... çıkan tiera bağlı
// olarak kartın arkasındaki ışıkları ayarla". Piksel sanatı: her şey SANAT pikseli ızgarasında hesaplanır ve parlaklık
// birkaç basamağa yuvarlanır - yumuşak/bulanık ışık ya da dama deseni dither yok (bkz. hafıza: pixel-style FX).
// Tüm ölçüler SANAT PİKSELİ cinsinden ve KARTIN DİKDÖRTGENİNE göre: düğüm = kart + her yanda "reach" taşma; huzmeler kartın
// kenarından dışa doğru söner, hale kartın çevresini sarar (kare bir alan uzun kartın üstünden ekranın tepesine taşıyordu).
//  - art_size: düğümün sanat px boyutu. card_half: kartın yarı boyutu (sanat px). reach: kenardan taşma (sanat px).
//  - rays / speed: birinci huzme takımı (sayı, dönüş hızı rad/sn). rays2 > 0 ise ters dönen ikinci takım (Efsanevi / elit).
//  - ray_width: huzmenin açısal kalınlığı (0..1). halo: hale kalınlığı (sanat px). intensity: genel parlaklık, düğümün
//    modulate.a'sı (COLOR.a) ile çarpılır - kart solunca ışık da söner. levels: parlaklık basamak sayısı.
uniform vec4 ray_color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform vec2 art_size = vec2(200.0, 260.0);
uniform vec2 card_half = vec2(60.0, 90.0);
uniform float reach = 40.0;
uniform float rays = 10.0;
uniform float speed = 0.25;
uniform float rays2 = 0.0;
uniform float speed2 = -0.18;
uniform float ray_width = 0.2;
uniform float halo = 8.0;
uniform float intensity = 0.7;
uniform float pulse = 0.0;
uniform float levels = 4.0;

float ray_set(float ang, float count, float spd, float width) {
	float a = fract((ang + TIME * spd) / 6.2831853 * count);
	// Üçgen dalga: huzmenin ortası 1, kenarları 0 - genişlik dışı tamamen kapalı.
	float tri = 1.0 - abs(a - 0.5) * 2.0;
	return clamp((tri - (1.0 - width)) / max(width, 0.001), 0.0, 1.0);
}

void fragment() {
	vec2 p = floor(UV * art_size) + 0.5 - art_size * 0.5;
	float ang = atan(p.y, p.x);
	vec2 q = max(abs(p) - card_half, vec2(0.0));
	float rect_d = length(q);
	float fall = clamp(1.0 - rect_d / max(reach, 1.0), 0.0, 1.0);
	float beams = ray_set(ang, rays, speed, ray_width);
	if (rays2 > 0.0) {
		beams = max(beams, 0.7 * ray_set(ang, rays2, speed2, ray_width * 0.8));
	}
	float breathe = 1.0 + pulse * sin(TIME * 3.0);
	float v = beams * pow(fall, 1.4);
	float h = halo > 0.0 ? clamp(1.0 - rect_d / halo, 0.0, 1.0) : 0.0;
	v = max(v, h * h);
	v = floor(clamp(v * breathe, 0.0, 1.0) * levels + 0.5) / levels;
	vec3 col = mix(ray_color.rgb, core_color.rgb, clamp(h * 1.2, 0.0, 1.0));
	COLOR = vec4(col, v * intensity * COLOR.a);
}
