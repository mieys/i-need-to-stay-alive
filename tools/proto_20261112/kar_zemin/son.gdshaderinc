// AYAZ DAĞI KAR ZEMİNİ PROTOTİPLERİ - vertex/fragment (her zemin_X.gdshader en sonda içerir). Prototip şunları tanımlar:
//  vec3 rampa(vec3 tex)                         kar ailesinin yeni tonu (kz_rampa ile)
//  vec3 kar_desen(vec3 taban, vec2 px, float t) düz taban pikselinin rengi (taban = rampa(kar_taban))
//  vec3 toprak(vec3 tex, vec2 px)               toprak ailesinin rengi (kz_toprak ile)

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = floor(world_pos);
	vec3 rgb = tex.rgb;
	if (kz_kar_aile(tex.rgb)) {
		rgb = rampa(tex.rgb);
		float mk = kz_kar_maske(tex.rgb);
		if (mk > 0.0) {
			rgb = mix(rgb, kar_desen(rampa(kar_taban.rgb), px, TIME), mk);
		}
	} else if (kz_toprak_aile(tex.rgb)) {
		rgb = toprak(tex.rgb, px);
	}
	COLOR = vec4(rgb, tex.a);
	if (COLOR.a > 0.0) { COLOR.rgb = harita_renk(COLOR.rgb); } // harita renk ayarı (madde 181) - fragment()'in EN SONUNDA
}
