shader_type canvas_item;

// Grid / Izgara Ayarı (Bitkileri birbirinden ayırmak için)
uniform float plant_grid_size : hint_range(4.0, 64.0) = 32.0; 

// --- DOĞAL RENK KAYDIRMA (HSV) AYARLARI ---
uniform float hue_shift_amount : hint_range(0.0, 0.2) = 0.04; 
uniform float sat_shift_amount : hint_range(0.0, 0.5) = 0.12; 
uniform float val_shift_amount : hint_range(0.0, 0.5) = 0.08; 

// Çizgilenmeyi önlemek için her bitkiye tek bir renk ID'si taşıyoruz
varying float v_plant_color_id;

// Rastgelelik (Hash) Fonksiyonu
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
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
    // Animasyon (Sallanma) tamamen kaldırıldı, VERTEX olduğu gibi bırakılıyor.
    
    // Dünya konumuna göre bitki hücresini buluyoruz
    vec2 actual_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
    vec2 plant_cell = floor(actual_world_pos / plant_grid_size);
    
    // Bu bitkiye dünya konumuna bağlı TEK bir rastgele ID veriyoruz (Çizgileri önler)
    v_plant_color_id = hash(plant_cell + vec2(55.3, 114.7));
}

void fragment() {
    vec4 tex_color = textureLod(TEXTURE, UV, 0.0);
    
    // Şeffaf olmayan pikselleri, o bitkinin tekil ID'sini kullanarak boyuyoruz
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
    
    COLOR = tex_color;
}