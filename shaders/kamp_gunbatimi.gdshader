shader_type canvas_item;

// ANA MENÜ "Nehir Kenarı Kampı" GÜNBATIMI (2026-11-15, scripts/menu_camp_scene.gd): sahnenin (taban + ateş çukuru + karakterler) üstüne
// çizilen tam ekran katman; altındaki ekranı okuyup tonlar. Hava HEP "günbatımı olmak üzere": sıcak altın ışık sağ üstten (güneş ağaçların
// ardında), gölgeler mor-lacivert, hafif loş. Ateşin sıcak ışık havuzu (titrer) + nehirde gökyüzü yansıması (dünya pikseline oturan yumuşak
// parıltı bantları, akıntı yönünde kayar). Basamak / Bayer / benek YOK (madde 326, "pixel pixel" ışık istenmiyor); yönlü gölge yok.
// Varsayılanlar GÜNBATIMI; ana menü 2026-11-15'ten beri AY IŞIKLI GECE kullanır: menu_camp_scene.gd SKY bu parametreleri ezer
// (desat / fire_core / fire_falloff / fire_halo / fire_lum ve su-gökyüzü renkleri o seçim için eklendi; varsayılanlarıyla günbatımı aynı).

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
uniform float desat = 0.0;          // ay ışığında renkler solar (gece); ateşin aydınlattığı yer SOLMAMIŞ renkle aydınlanır
uniform vec3 fire_core : source_color = vec3(1.0, 0.62, 0.30); // ateşe yakın ışık rengi (dışı fire_color)
uniform float fire_falloff = 2.0;   // ışık havuzunun sönüşü (küçük = uzun yumuşak kuyruk)
uniform float fire_halo = 0.05;     // havada hafif sıcak hale
uniform float fire_lum = 0.0;       // ışığın yüzey PARLAKLIĞIYLA (rengi değil) eklenen payı: yeşil çimen sarı-yeşile değil turuncuya döner
// "Cozy" gece için (varsayılanları kapalı = günbatımı aynı): sahneyi ateşin sıcaklığına saran çok geniş zayıf ikinci ışık, ateşin üstünde
// havada yumuşak sıcak parıltı, nehirde ateşin sıcak yansıması, kampa odaklı kenar karartması.
uniform float fire_wide_radius = 0.0;      // sahne px (yatay; dikey 0.8 kat); 0 = kapalı
uniform float fire_wide_strength = 0.0;
uniform float fire_bloom = 0.0;            // havadaki parıltı gücü (ekran px dairesi, ateşin biraz üstünde)
uniform float fire_bloom_radius = 90.0;
uniform float water_fire = 0.0;            // nehirde ateş yansıması (geniş ışıkla orantılı)
uniform vec2 vignette_center = vec2(0.5, 0.5);
// İkinci ışık kaynağı: Talon'un yanına dikili meşale (varsayılan kapalı). Ateşle aynı sıcak renk, küçük havuz + havada hafif parıltı,
// kendi titremesi.
uniform vec2 lamp_pos = vec2(0.0, 0.0);   // sahne px
uniform float lamp_radius = 0.0;          // 0 = kapalı (yatay; dikey 0.8 kat)
uniform float lamp_strength = 0.0;
uniform float lamp_bloom = 0.0;

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

	// Ateşin titremesi + çok geniş zayıf sıcak ışık (nehirdeki yansıma da bunu kullanır).
	float flick = 0.93 + 0.045 * sin(TIME * 7.3) + 0.03 * sin(TIME * 12.7 + 1.3) + 0.02 * sin(TIME * 3.1 + 0.4);
	float wl = 0.0;
	if (fire_wide_radius > 0.0) {
		vec2 wd = (p - fire_pos) / vec2(fire_wide_radius, fire_wide_radius * 0.8);
		wl = 1.0 - smoothstep(0.0, 1.0, length(wd));
		wl *= wl;
	}

	// Nehir: yalnız IŞIK (gökyüzü tonu + ateşin sıcak yansıması). Suyun kendisi ve dalgacıkları oyunun su shader'ından (kamp_su.gdshader,
	// tabanın üstünde): 2026-11-16'ya kadar burada kendi "parıltı bantlarım" vardı - kullanıcı: "ana menüdeki su shaderı normal ana haritadaki
	// su shaderı gibi değil" -> kalktı.
	float w = texture(water_mask, UV).r;
	if (w > 0.5) {
		// Suyun mavisi korunur (mor ton griye çekmesin), üstüne gökyüzünün yansıması güneş/ay tarafında artar.
		vec3 sky = mix(sky_far, sky_near, sun);
		col = base * water_tint * dim + sky * (0.06 + 0.10 * sun) * sky_amount;
		col += fire_color * wl * water_fire * 0.18 * flick; // suyun yüzeyinde ateşin sıcak yansıması
	}

	// Ateş ışığı: titreyen sıcak havuz (yüzeyin kendi rengini aydınlatır + az miktar ortam).
	vec2 fd = (p - fire_pos) / vec2(fire_radius, fire_radius * 0.72);
	float d = length(fd);
	float fl = pow(1.0 - smoothstep(0.0, 1.0, d), fire_falloff);
	vec3 fcol = mix(fire_color, fire_core, fl);
	col += c * fcol * fl * fire_strength * flick;
	col += fcol * fl * fire_halo * flick;
	col += vec3(lum) * fcol * fl * fire_lum * flick;
	col += c * fire_color * wl * fire_wide_strength * flick;
	// Meşale ışığı (ateşinkinden bağımsız titrer; su da dahil her yüzeyi kendi rengiyle aydınlatır).
	if (lamp_radius > 0.0) {
		float tflick = 0.95 + 0.03 * sin(TIME * 5.3 + 0.7) + 0.02 * sin(TIME * 11.3 + 2.1);
		float td = length((p - lamp_pos) / vec2(lamp_radius, lamp_radius * 0.8));
		float tl = pow(1.0 - smoothstep(0.0, 1.0, td), 1.4);
		vec3 tcol = mix(fire_color, fire_core, tl);
		col += c * tcol * tl * lamp_strength * tflick;
		col += vec3(lum) * tcol * tl * fire_lum * 0.6 * lamp_strength * tflick;
		float tb = length(p - lamp_pos) / 50.0;
		col += fire_core * exp(-tb * tb) * lamp_bloom * tflick;
	}
	// Havada sıcak parıltı (ateşin biraz üstünde, yumuşak).
	float bd = length(p - fire_pos - vec2(0.0, -18.0)) / fire_bloom_radius;
	col += fire_core * exp(-bd * bd) * fire_bloom * flick;

	// Kenar karartması (yumuşak).
	vec2 vu = (UV - vignette_center) * vec2(1.0, 1.25);
	col *= 1.0 - vignette * smoothstep(0.25, 0.85, length(vu));

	COLOR = vec4(col, 1.0);
}
