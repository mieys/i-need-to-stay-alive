shader_type canvas_item;

// Magic Fox Shield Dome Shader
// Clean, simple, translucent blue/cyan force field matching reference image
// with subtle pulse and glowing rim

uniform vec4 inner_color : source_color = vec4(0.72, 0.70, 0.98, 0.22);
uniform vec4 mid_color : source_color = vec4(0.28, 0.65, 0.98, 0.65);
uniform vec4 rim_color : source_color = vec4(0.40, 0.90, 1.0, 0.95);
uniform vec4 rim_glow : source_color = vec4(0.75, 0.96, 1.0, 1.0);

uniform float pulse_speed : hint_range(0.0, 10.0) = 3.5;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.08;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    if (tex_color.a <= 0.001) {
        discard;
    }
    
    // Pulse animation
    float pulse = sin(TIME * pulse_speed) * pulse_intensity;
    vec3 out_rgb = tex_color.rgb + vec3(pulse * 0.1, pulse * 0.15, pulse * 0.2);
    float out_a = clamp(tex_color.a + pulse * 0.05, 0.0, 1.0);
    
    COLOR = vec4(out_rgb, out_a);
}
