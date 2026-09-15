shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform vec2 offset = vec2(3.0, 3.0);
uniform float blur_radius : hint_range(0.0, 10.0) = 2.0;
uniform float shadow_opacity : hint_range(0.0, 1.0) = 0.7;

// Kırpma (Cropping) Sınırları (0.0 ile 1.0 arasında UV değerleri)
uniform float crop_left : hint_range(0.0, 1.0) = 0.0;
uniform float crop_right : hint_range(0.0, 1.0) = 1.0;
uniform float crop_top : hint_range(0.0, 1.0) = 0.0;
uniform float crop_bottom : hint_range(0.0, 1.0) = 1.0;
uniform float crop_feather : hint_range(0.0, 0.5) = 0.05; // Kırpma kenarının yumuşaklığı

void fragment() {
    vec4 current_color = texture(TEXTURE, UV);
    
    if (current_color.a > 0.01) {
        COLOR = current_color;
    } else {
        vec2 shadow_uv = UV - (offset * TEXTURE_PIXEL_SIZE);
        float alpha_sum = 0.0;
        float samples = 0.0;
        
        // Blur hesaplaması
        if (blur_radius > 0.0) {
            for (float x = -blur_radius; x <= blur_radius; x += 1.0) {
                for (float y = -blur_radius; y <= blur_radius; y += 1.0) {
                    vec2 sample_offset = vec2(x, y) * TEXTURE_PIXEL_SIZE;
                    alpha_sum += texture(TEXTURE, shadow_uv + sample_offset).a;
                    samples += 1.0;
                }
            }
            alpha_sum /= samples;
        } else {
            alpha_sum = texture(TEXTURE, shadow_uv).a;
        }
        
        // Kırpma Maskesi (Cropping Mask) Hesaplama
        float mask_left = smoothstep(crop_left, crop_left + crop_feather, UV.x);
        float mask_right = 1.0 - smoothstep(crop_right - crop_feather, crop_right, UV.x);
        float mask_top = smoothstep(crop_top, crop_top + crop_feather, UV.y);
        float mask_bottom = 1.0 - smoothstep(crop_bottom - crop_bottom * 0.0 - crop_feather, crop_bottom, UV.y);
        
        // Bütün kenar maskelerini birleştir
        float crop_mask = mask_left * mask_right * mask_top * mask_bottom;
        
        if (alpha_sum > 0.0) {
            float final_alpha = alpha_sum * shadow_color.a * shadow_opacity * crop_mask;
            COLOR = vec4(shadow_color.rgb, final_alpha);
        } else {
            COLOR = vec4(0.0);
        }
    }
}