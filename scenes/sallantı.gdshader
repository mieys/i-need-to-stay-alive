shader_type canvas_item;

// --- SALLANMA GÜÇ VE HIZ AYARLARI ---
uniform float speed : hint_range(0.0, 10.0) = 3.5;        
uniform float strength : hint_range(0.0, 100.0) = 5.0;     
uniform float detail : hint_range(0.0, 10.0) = 1.5;        
uniform float root_cutoff : hint_range(0.0, 1.0) = 0.93;  
uniform float sway_falloff : hint_range(0.1, 5.0) = 1.5;  

// Grid / Izgara Ayarı
uniform float plant_grid_size : hint_range(4.0, 64.0) = 32.0; 

// --- DOĞAL RENK KAYDIRMA (HSV) AYARLARI ---
uniform float hue_shift_amount : hint_range(0.0, 0.2) = 0.04; 
uniform float sat_shift_amount : hint_range(0.0, 0.5) = 0.12; 
uniform float val_shift_amount : hint_range(0.0, 0.5) = 0.08; 

// --- GÖLGE AYARLARI (GÜNCELLENDİ VE YENİ ÖZELLİKLER EKLENDİ) ---
uniform vec2 shadow_offset = vec2(5.0, 5.0); // Piksel cinsinden offset
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.6); // Temel gölge rengi
uniform float shadow_opacity : hint_range(0.0, 1.0) = 1.0; // Gölge ekstra opaklık ayarı
uniform float shadow_rotation : hint_range(-180.0, 180.0) = 0.0; // Köşeden dönme açısı (Derece)
uniform float shadow_blur : hint_range(0.0, 10.0) = 1.0; // Yumuşaklık derecesi

// Çizgilenmeyi önlemek için her bitkiye tek bir renk ID'si taşıyoruz
varying float v_plant_color_id;

// Rastgelelik (Hash) Fonksiyonu
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

// 2D Rotasyon Fonksiyonu
vec2 rotate_uv(vec2 uv, float angle_degrees, vec2 pivot) {
    float rad = radians(angle_degrees);
    mat2 rotation = mat2(
        vec2(cos(rad), -sin(rad)),
        vec2(sin(rad), cos(rad))
    );
    return rotation * (uv - pivot) + pivot;
}

// RGB'den HSV'ye
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV'den RGB'ye
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void vertex() {
    float height_factor = clamp((root_cutoff - UV.y) / root_cutoff, 0.0, 1.0);
    height_factor = pow(height_factor, sway_falloff);
    
    vec2 actual_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
    vec2 plant_cell = floor(actual_world_pos / plant_grid_size);
    
    v_plant_color_id = hash(plant_cell + vec2(55.3, 114.7));
    
    float direction_sign = sign(hash(plant_cell + vec2(15.3, 42.1)) - 0.5);
    float phase_offset = hash(plant_cell) * 6.28318;
    float individual_speed = speed * (0.8 + hash(plant_cell + vec2(1.0, 2.0)) * 0.4);
    
    float custom_time = (TIME * individual_speed) + phase_offset;
    float main_wave = sin(custom_time);
    float detail_wave = cos(custom_time * 2.3) * (0.2 * detail);
    
    float final_wave = (main_wave + detail_wave) * strength * direction_sign;
    VERTEX.x += final_wave * height_factor;
}

void fragment() {
    vec2 pixel_size = TEXTURE_PIXEL_SIZE;
    vec2 offset_uv = shadow_offset * pixel_size;
    
    // 1. KÖŞEDEN ROTASYONLU VE ÖTELENMİŞ GÖLGE UV HESABI
    // Pivot olarak (0.0, 0.0) yani sol üst köşe seçildi.
    vec2 shadow_uv = rotate_uv(UV, shadow_rotation, vec2(0.0, 0.0)) - offset_uv;
    
    float shadow_alpha = texture(TEXTURE, shadow_uv).a;
    
    // Gölge Yumuşatma (Blur)
    if (shadow_blur > 0.0) {
        float blur_amount = shadow_blur * pixel_size.x;
        shadow_alpha += texture(TEXTURE, shadow_uv + vec2(blur_amount, 0.0)).a;
        shadow_alpha += texture(TEXTURE, shadow_uv - vec2(blur_amount, 0.0)).a;
        shadow_alpha += texture(TEXTURE, shadow_uv + vec2(0.0, blur_amount)).a;
        shadow_alpha += texture(TEXTURE, shadow_uv - vec2(0.0, blur_amount)).a;
        shadow_alpha /= 5.0;
    }
    
    // Ekstra Opaklık (shadow_opacity) çarpan olarak uygulandı
    float final_shadow_alpha = shadow_alpha * shadow_color.a * shadow_opacity;
    vec4 final_shadow = vec4(shadow_color.rgb, final_shadow_alpha);

    // 2. ANA BİTKİ VE RENK DEĞİŞİMİ
    vec4 tex_color = texture(TEXTURE, UV);
    
    if (tex_color.a > 0.3) {
        vec3 hsv = rgb2hsv(tex_color.rgb);
        
        float rand_hue = (v_plant_color_id - 0.5) * 2.0;
        float rand_sat = (fract(v_plant_color_id * 3.7) - 0.5) * 2.0;
        float rand_val = (fract(v_plant_color_id * 7.1) - 0.5) * 2.0;
        
        hsv.x += rand_hue * hue_shift_amount; 
        hsv.y += rand_sat * sat_shift_amount; 
        hsv.z += rand_val * val_shift_amount; 
        
        hsv.y = clamp(hsv.y, 0.0, 1.0);
        hsv.z = clamp(hsv.z, 0.0, 1.0);
        
        tex_color.rgb = hsv2rgb(hsv);
    }
    
    // 3. RENKLERİ BİRLEŞTİRME
    vec4 final_color = mix(final_shadow, tex_color, tex_color.a);
    
    COLOR = final_color;
}