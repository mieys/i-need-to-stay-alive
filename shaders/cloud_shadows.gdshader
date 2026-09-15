shader_type canvas_item;
render_mode world_vertex_coords;

// Uniforms from cloud_shadows_material.tres
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.15;
uniform float cloud_scale = 900.0;
uniform float softness : hint_range(0.0, 1.0) = 0.02;
uniform float movement_speed = 0.004;
uniform float pixel_size = 3.0;

// Uniforms from cloud_test.tscn
uniform float cloud_size = 760.0;
uniform float coverage = 0.5;
uniform vec4 shadow_tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float drift_speed = 0.0;
uniform vec2 drift_direction = vec2(1.0, 0.35);
uniform vec2 noise_offset = vec2(0.0, 0.0);

varying vec2 world_pos;

void vertex() {
    world_pos = VERTEX;
}

// Simple pseudo-random hash
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// 2D Noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // Smoothstep interpolation
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(mix(hash(i + vec2(0.0, 0.0)), 
                   hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), 
                   hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Fractal Brownian Motion (FBM)
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    // Get the base texture color
    vec4 tex_color = texture(TEXTURE, UV);
    
    vec2 current_pos = world_pos;
    
    // If pixel_size is positive, pixelate the coordinates
    if (pixel_size > 1.0) {
        current_pos = floor(current_pos / pixel_size) * pixel_size;
    }
    
    // Use either cloud_scale or cloud_size (whichever is configured/greater)
    float scale = (cloud_scale > 0.0) ? cloud_scale : cloud_size;
    if (scale <= 0.0) {
        scale = 900.0;
    }
    
    // Calculate drift/movement offset
    vec2 movement = vec2(0.0);
    if (movement_speed > 0.0) {
        movement = vec2(TIME * movement_speed * 100.0);
    } else if (drift_speed > 0.0) {
        movement = drift_direction * drift_speed * TIME;
    } else {
        // Fallback movement so clouds drift slightly
        movement = vec2(TIME * 2.0);
    }
    
    vec2 uv = (current_pos + noise_offset + movement) / scale;
    
    // Generate noise value
    float n = fbm(uv);
    
    // Calculate shadow factor based on coverage/softness
    float c_val = (coverage > 0.0) ? coverage : 0.5;
    float soft = (softness > 0.0) ? softness : 0.1;
    
    // Threshold with smoothstep
    float shadow = smoothstep(c_val - soft, c_val + soft, n);
    
    // Apply shadow strength
    float final_strength = shadow_strength * (1.0 - shadow);
    
    // Use shadow tint if specified
    vec3 tint = shadow_tint.rgb;
    if (shadow_tint.a == 0.0 || (shadow_tint.r == 0.0 && shadow_tint.g == 0.0 && shadow_tint.b == 0.0)) {
        tint = vec3(0.0); // Pure dark shadow
    }
    
    // Mix texture color with shadow color/tint
    vec3 shadow_color = mix(tex_color.rgb, tint, final_strength);
    
    COLOR = vec4(shadow_color, tex_color.a);
}
