shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float brightness = max(max(tex.r, tex.g), tex.b);
	COLOR = vec4(vec3(1.0, 0.78, 0.08) * brightness, tex.a);
}
