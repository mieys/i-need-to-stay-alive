// Prototiplerin ortak vertex/fragment'ı: çimen = cimen(), çamur = bugünkü desen (bkz. ortak.gdshaderinc başı).
varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = floor(world_pos);
	vec3 rgb = tex.rgb;
	float mc = pc_cimen_maske(tex.rgb);
	if (mc > 0.0) {
		rgb = mix(rgb, cimen(tex.rgb, px), mc);
	}
	float mt = toprak_maske(tex.rgb);
	if (mt > 0.0) {
		vec3 t = toprak_desen(tex.rgb, px);
		int b = pc_birikinti(px);
		if (b == 1) { t = birikinti_rengi.rgb; }
		else if (b == 3) { t = birikinti_isik.rgb; }
		else if (b == 2) { t = birikinti_kenar.rgb; }
		rgb = mix(rgb, t, mt * toprak_efekt);
	}
	COLOR = vec4(rgb, tex.a);
	if (COLOR.a > 0.0) { COLOR.rgb = harita_renk(COLOR.rgb); }
}
