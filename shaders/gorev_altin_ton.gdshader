// Kaçan Hazine altın slime tonu (madde 496, mission_treasure_runner.gd)
shader_type canvas_item;
void fragment() {
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float t = clamp((lum - 0.12) / 0.8, 0.0, 1.0);
	t = t * t;
	vec3 ramp = t < 0.55 ? mix(vec3(0.40, 0.19, 0.02), vec3(0.98, 0.68, 0.10), t / 0.55)
			: mix(vec3(0.98, 0.68, 0.10), vec3(1.0, 0.95, 0.60), (t - 0.55) / 0.45);
	COLOR = vec4(mix(c.rgb, ramp, 0.95), c.a);
}
