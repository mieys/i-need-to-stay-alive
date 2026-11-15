shader_type canvas_item;

// ANA MENÜ "Nehir Kenarı Kampı" GÜNBATIMI (2026-11-15, scripts/menu_camp_scene.gd): sahnenin (taban + ateş çukuru + karakterler) üstüne
// çizilen tam ekran katman; altındaki ekranı okuyup tonlar. Hava HEP "günbatımı olmak üzere": sıcak altın ışık sağ üstten (güneş ağaçların
// ardında), gölgeler mor-lacivert, hafif loş. Ateşin sıcak ışık havuzu (titrer) + nehirde gökyüzü yansıması (dünya pikseline oturan yumuşak
// parıltı bantları, akıntı yönünde kayar). Basamak / Bayer / benek YOK (madde 326, "pixel pixel" ışık istenmiyor); yönlü gölge yok.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D water_mask : filter_nearest;
uniform vec2 stage_size = vec2(1920.0, 1080.0);
uniform vec2 world_size = vec2(320.0, 180.0);
uniform vec2 fire_pos = vec2(1020.0, 768.0); // sahne px
uniform float fire_radius = 330.0;           // sahne px (yatay; dikey 0.72 kat - üstten bakış)
uniform vec3 fire_color : source_color = vec3(1.0, 0.62, 0.30);
uniform float fire_strength = 1.05;
uniform vec3 dusk_color : source_color = vec3(0.56, 0.50, 0.72);  // gölgeler / güneşten uzak
uniform vec3 gold_color : source_color = vec3(1.10, 0.86, 0.62);  // güneş alan yerler
uniform vec2 sun_uv = vec2(0.92, -0.32);     // güneşin (görünmeyen) yeri, ekran UV
uniform float dim = 0.86;                    // genel loşluk
uniform float vignette = 0.32;
// Aşağıdakiler varsayılanıyla günbatımı; gece/gündüz denemeleri (tools/proto_20261115/kamp_menu/menu_capture.gd KAMP_HAVA) bunları ezer.
uniform vec3 warm_glow : source_color = vec3(0.10, 0.04, 0.02);   // açık tonlarda güneş tarafı parlama
uniform vec3 haze_color : source_color = vec3(0.20, 0.09, 0.03);  // güneş tarafı pus
uniform vec3 water_tint : source_color = vec3(0.80, 0.80, 0.98);  // suyun kendi rengi çarpanı
uniform vec3 sky_far : source_color = vec3(0.55, 0.42, 0.66);     // suda gökyüzü yansıması (güneşten uzak)
uniform vec3 sky_near : source_color = vec3(1.0, 0.64, 0.44);     // (güneş tarafı)
uniform float sky_amount = 1.0;
uniform vec3 glint_color : source_color = vec3(1.0, 0.72, 0.48);
uniform float desat = 0.0;          // ay ışığında renkler solar (gece); ateşin aydınlattığı yer SOLMAMIŞ renkle aydınlanır
uniform vec3 fire_core : source_color = vec3(1.0, 0.62, 0.30); // ateşe yakın ışık rengi (dışı fire_color)
uniform float fire_falloff = 2.0;   // ışık havuzunun sönüşü (küçük = uzun yumuşak kuyruk)
uniform float fire_halo = 0.05;     // havada hafif sıcak hale
uniform float fire_lum = 0.0;       // ışığın yüzey PARLAKLIĞIYLA (rengi değil) eklenen payı: yeşil çimen sarı-yeşile değil turuncuya döner

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec2 p = UV * stage_size;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));

	// Güneş tarafı sıcak, uzak taraf mor gölge (geniş, yumuşak geçiş).
	vec2 asp = vec2(stage_size.x / stage_size.y, 1.0);
	float sun = 1.0 - clamp(distance(UV * asp, sun_uv * asp) / 2.05, 0.0, 1.0);
	sun = smoothstep(0.0, 1.0, sun);
	vec3 tint = mix(dusk_color, gold_color, clamp(sun * 0.95 + (lum - 0.35) * 0.6, 0.0, 1.0));
	vec3 base = mix(c, vec3(lum), desat);
	vec3 col = base * tint * dim;
	// Açık tonlarda hafif turuncu-pembe parlama (altın saat havası).
	col += warm_glow * sun * smoothstep(0.35, 0.8, lum);
	// Güneş tarafından gelen yumuşak sıcak pus (gökyüzü görünmese de "güneş batıyor" hissi).
	col += haze_color * pow(sun, 3.0);

	// Nehir: gökyüzünün pembe-turuncu yansıması + akıntı yönünde kayan parıltı bantları (dünya pikselinde).
	float w = texture(water_mask, UV).r;
	if (w > 0.5) {
		// Suyun mavisi korunur (mor ton griye çekmesin), üstüne gökyüzünün sıcak yansıması güneş tarafında artar.
		vec3 sky = mix(sky_far, sky_near, sun);
		col = base * water_tint * dim + sky * (0.06 + 0.10 * sun) * sky_amount;
		vec2 wp = floor(UV * world_size) + 0.5;
		float along = dot(wp, normalize(vec2(-0.78, 0.62)));  // akıntı: sağ üstten sol alta
		float across = dot(wp, normalize(vec2(0.62, 0.78)));
		float a1 = sin(across * 0.9 + along * 0.05 - TIME * 0.7) * 0.5 + 0.5;
		float a2 = sin(along * 0.45 + TIME * 1.1 + across * 0.3) * 0.5 + 0.5;
		float a3 = sin(along * 0.11 - TIME * 0.35 + across * 0.07) * 0.5 + 0.5;
		float glint = smoothstep(0.86, 0.98, a1 * a2) * smoothstep(0.35, 0.8, a3);
		col += glint_color * glint * (0.06 + 0.12 * sun);
	}

	// Ateş ışığı: titreyen sıcak havuz (yüzeyin kendi rengini aydınlatır + az miktar ortam).
	vec2 fd = (p - fire_pos) / vec2(fire_radius, fire_radius * 0.72);
	float d = length(fd);
	float flick = 0.93 + 0.045 * sin(TIME * 7.3) + 0.03 * sin(TIME * 12.7 + 1.3) + 0.02 * sin(TIME * 3.1 + 0.4);
	float fl = pow(1.0 - smoothstep(0.0, 1.0, d), fire_falloff);
	vec3 fcol = mix(fire_color, fire_core, fl);
	col += c * fcol * fl * fire_strength * flick;
	col += fcol * fl * fire_halo * flick;
	col += vec3(lum) * fcol * fl * fire_lum * flick;

	// Kenar karartması (yumuşak).
	vec2 vu = (UV - 0.5) * vec2(1.0, 1.25);
	col *= 1.0 - vignette * smoothstep(0.25, 0.85, length(vu));

	COLOR = vec4(col, 1.0);
}
