shader_type canvas_item;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	// Use the Green channel as the primary brightness (since original is mostly green)
	// or use standard luminance: float lum = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
	// But since it's glowing green, the G channel represents the detail perfectly.
	float brightness = tex_color.g;
	
	COLOR = vec4(COLOR.rgb * brightness, tex_color.a * COLOR.a);
}
