// Gezici Işık karanlık halkası (madde 496 / 534, mission_light.gd): yumuşak kenar, zifiri değil + ışık sınırında parıltı.
// EKRAN DÜZEYİNDE (madde 534): zemin sprite'ı değil, dünyanın üstündeki bir CanvasLayer'daki dörtgen - yaratık, oyuncu, ağaç
// tepesi, efekt, can çubuğu... halkanın içindeki HER ŞEY zemin gibi kararır (ilk sürüm yalnız zemini karartıyordu, üstündeki
// her şey aydınlık kalıyordu). Ekran kopyası OKUMAZ (alfa karışımı, stealth_vision.gdshader gibi): maliyeti tek dörtgen.
// Dünya konumu: tuval pikseli (dörtgen konumu + UV * boyut) -> kamera dönüşümünün tersi; mission_light.gd her karede verir.
shader_type canvas_item;
uniform float r_light = 150.0;
uniform float r_outer = 620.0;
uniform float feather = 40.0;
uniform float outer_fade = 170.0;
uniform vec2 rect_pos = vec2(0.0);   // dörtgenin sol üstü (tuval pikseli)
uniform vec2 rect_size = vec2(1920.0, 1080.0);
uniform vec2 view_origin = vec2(0.0); // kamera: tuval = dünya * view_zoom + view_origin
uniform float view_zoom = 1.0;
uniform vec2 light_pos = vec2(0.0);   // ışığın dünya konumu
uniform float t = 0.0;
uniform vec4 dark : source_color = vec4(0.05, 0.03, 0.09, 0.42);
uniform vec4 rim : source_color = vec4(0.62, 0.95, 1.0, 0.55);
void fragment() {
	vec2 world = (rect_pos + UV * rect_size - view_origin) / view_zoom;
	vec2 p = floor(world) + 0.5 - light_pos; // dünya piksel ızgarası: halka kenarı kamerayla kaymaz
	float d = length(p);
	float a = dark.a * smoothstep(r_light, r_light + feather, d) * (1.0 - smoothstep(r_outer - outer_fade, r_outer, d));
	// parıltı yalnız ışık sınırında (atan + sin tam ekran her pikselde gereksiz - telefon)
	float rd = abs(d - r_light);
	float ra = 0.0;
	if (rd < 1.6) {
		float wob = 0.75 + 0.25 * sin(t * 3.0 + atan(p.y, p.x) * 6.0);
		ra = (1.0 - smoothstep(0.5, 1.6, rd)) * rim.a * wob;
	}
	if (a <= 0.0 && ra <= 0.0) {
		discard;
	}
	vec3 col = mix(dark.rgb, rim.rgb, ra / max(ra + a, 0.001));
	COLOR = vec4(col, max(a, ra));
}
