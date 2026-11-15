// Prototiplerin ortak vertex/fragment'ı: düz çimen pikseli = cimen(), düz çamur pikseli = yol() (bkz. ortak.gdshaderinc başı).
varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = floor(world_pos);
	vec3 rgb = tex.rgb;
	float mc = pz_cim_maske(tex.rgb);
	if (mc > 0.0) {
		rgb = mix(rgb, cimen(tex.rgb, px), mc);
	}
	float mm = pz_camur_maske(tex.rgb);
	if (mm > 0.0) {
		rgb = mix(rgb, yol(tex.rgb, px), mm);
	}
	COLOR = vec4(rgb, tex.a);
	if (COLOR.a > 0.0) { COLOR.rgb = harita_renk(COLOR.rgb); }
}
