shader_type canvas_item;

uniform vec4 shield_color : source_color = vec4(0.3, 0.75, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.85, 0.98, 1.0, 1.0);
uniform float pixel_size = 54.0; // grid size for pixel art look
uniform float time_speed = 2.2;
uniform float flash_amount = 0.0;
uniform float pulse = 0.0;

void fragment() {
	// Pixelate the UV coordinates to get crisp pixel art blocks
	vec2 grid_uv = floor(UV * pixel_size) / pixel_size;
	
	// Distance from the center of the UV square (0.5, 0.5)
	vec2 center = vec2(0.5);
	float dist = distance(grid_uv, center);
	
	// Hard cutoff at the circular radius of 0.5 for crisp pixel edges
	if (dist > 0.5) {
		discard;
	}
	
	// Spherical height (z) using hemisphere formula: z^2 + x^2 + y^2 = r^2
	// offset from center is between -0.5 and 0.5
	vec2 offset = grid_uv - center;
	float r = 0.5;
	float z_sq = r * r - dot(offset, offset);
	float z = sqrt(max(0.0, z_sq));
	
	// Fresnel / Rim glow: higher glow at the edges where z is close to 0
	float rim = 1.0 - (z / r);
	rim = pow(rim, 2.5); // sharpen the rim transition
	
	// Shimmering plasma / water ripples using intersecting sin/cos waves
	float time = TIME * time_speed;
	float ripple = sin(grid_uv.x * 24.0 + time) * cos(grid_uv.y * 24.0 - time * 0.7);
	ripple += sin((grid_uv.x - grid_uv.y) * 18.0 + time * 1.4);
	ripple = (ripple + 2.0) / 4.0; // normalize to 0.0 - 1.0
	
	// Pixelated sparkles (individual flashing pixels)
	float spark_noise = fract(sin(dot(grid_uv + floor(time * 6.0) * 0.1, vec2(12.9898, 78.233))) * 43758.5453);
	float spark = step(0.97, spark_noise);
	
	// Combine base color and glow color based on the rim and ripples
	vec4 final_color = mix(shield_color, glow_color, rim + ripple * 0.35);
	
	// Flash white when hit/damaged
	if (flash_amount > 0.0) {
		final_color = mix(final_color, vec4(1.0, 1.0, 1.0, 1.0), flash_amount * 0.75);
	}
	
	// Compute alpha
	// Outer edge rim is mostly opaque, center is translucent with shimmering currents
	float alpha = mix(0.15, 0.85, rim);
	alpha += ripple * 0.18;
	alpha += spark * 0.18;
	
	// Pulse scaling
	alpha *= (0.85 + pulse * 0.15);
	
	// Apply alpha limits
	alpha = clamp(alpha, 0.0, 1.0);
	
	COLOR = vec4(final_color.rgb, final_color.a * alpha);
}
