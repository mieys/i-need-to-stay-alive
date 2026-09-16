shader_type canvas_item;

// --- 1. ÇİMEN TONLAMA PARAMETRELERİ (ÖBEKLER) ---
uniform vec4 dark_grass_color : source_color = vec4(0.35, 0.52, 0.22, 1.0);  
uniform vec4 light_grass_color : source_color = vec4(0.55, 0.68, 0.28, 1.0); 
uniform float grass_pixel_size : hint_range(1.0, 8.0) = 2.0;                 
uniform float grass_patch_opacity : hint_range(0.0, 1.0) = 0.5;              

uniform float grass_patch_density : hint_range(0.001, 0.05) = 0.015;         
uniform float small_grass_patch_density : hint_range(0.01, 0.2) = 0.06;       
uniform float detail_blend : hint_range(0.0, 1.0) = 0.35;                    
uniform float grass_noise_threshold : hint_range(0.0, 1.0) = 0.48;           

// --- 2. ŞİRİN ÇİMEN DOKUSU PARAMETRELERİ ---
uniform vec4 blade_color : source_color = vec4(0.65, 0.78, 0.32, 1.0);       
uniform float blade_density : hint_range(0.0, 1.0) = 0.6;                    
uniform float blade_opacity : hint_range(0.0, 1.0) = 0.9;                    

// --- 3. YER YER BELİREN GERÇEK TEK PİKSEL NOKTALAR ---
uniform vec4 point_color : source_color = vec4(0.42, 0.32, 0.22, 1.0);       
uniform float point_density : hint_range(0.0, 1.0) = 0.3;                    
uniform float point_opacity : hint_range(0.0, 1.0) = 0.8;                    

// --- 4. YENİ: ÖZELLEŞTİRİLEBİLİR ZEMİN NOISE PARAMETRELERİ ---
uniform vec4 noise_color : source_color = vec4(0.25, 0.38, 0.15, 1.0);       // Noise rengi
uniform float noise_opacity : hint_range(0.0, 1.0) = 0.6;                     // Noise görünürlüğü
uniform float noise_pixel_size : hint_range(1.0, 16.0) = 1.0;                 // Noise piksellerinin büyüklüğü (genişlik)
uniform float noise_scale : hint_range(0.01, 0.5) = 0.1;                     // Noise yayılım genişliği (dalgalanma boyutu)
uniform float noise_density : hint_range(0.0, 1.0) = 0.3;                     // Ne kadar sık görüneceği
uniform float noise_randomness : hint_range(0.0, 1.0) = 0.5;                 // 0 = Doğal kümelenme (FBM), 1 = Saf karıncalanma (White Noise)

varying vec2 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Negatif koordinat hatasını ve float hassasiyet kaybını çözen tam sayı (integer) hash
float hash(vec2 p) {
    uvec2 u = uvec2(ivec2(p) + ivec2(0x7FFFFFFF)); // Negatif koordinatları güvenli pozitif aralığa taşır
    u = u * 1664525u + 1013904223u;
    u.x += u.y * 1664525u;
    u.y += u.x * 1664525u;
    u = u ^ (u >> 16u);
    u.x += u.y * 1664525u;
    u.y += u.x * 1664525u;
    return float(u.x) / 4294967295.0;
}

// Dikey çizgilenmeyi sıfırlayan hassas vec2 hash2
vec2 hash2(vec2 p) {
    uvec2 u = uvec2(ivec2(p) + ivec2(0x7FFFFFFF));
    u = u * 1664525u + 1013904223u;
    u.x += u.y * 1664525u;
    u.y += u.x * 1664525u;
    u = u ^ (u >> 16u);
    u.x += u.y * 1664525u;
    u.y += u.x * 1664525u;
    return -1.0 + 2.0 * vec2(u) / 4294967295.0;
}

float perlin_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float val = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 3; i++) {
        val += amp * perlin_noise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return val * 0.5 + 0.5;
}

void fragment() {
    vec4 texture_color = texture(TEXTURE, UV);
    vec3 current_rgb = texture_color.rgb;

    vec2 crisp_world_pos = floor(world_pos) + 0.5;
    float g_size = max(1.0, floor(grass_pixel_size));

    // --- AŞAMA 1: ZEMİN TONLAMASI (ÖBEKLER) ---
    vec2 snapped_grass_pos = floor(crisp_world_pos / g_size) * g_size;

    float big_noise = fbm(snapped_grass_pos * grass_patch_density);
    float small_noise = fbm((snapped_grass_pos + vec2(123.4, 567.8)) * small_grass_patch_density);

    float final_grass_noise = mix(big_noise, small_noise, detail_blend);

    if (final_grass_noise > grass_noise_threshold + 0.06) {
        current_rgb = mix(current_rgb, dark_grass_color.rgb, grass_patch_opacity);
    } else if (final_grass_noise < grass_noise_threshold - 0.06) {
        current_rgb = mix(current_rgb, light_grass_color.rgb, grass_patch_opacity);
    }

    // --- AŞAMA 2: HÜCRESEL (CELL-BASED) ŞİRİN ÇİMEN KÜMELERİ ---
    float cell_size = 8.0; 
    vec2 pixel_pos = floor(crisp_world_pos / g_size);
    vec2 cell_pos = floor(pixel_pos / cell_size);
    vec2 local_pos = floor(mod(pixel_pos, vec2(cell_size))); 

    float cell_rand = hash(cell_pos * 12.34);
    bool draw_blade = false;

    if (cell_rand < blade_density) {
        vec2 start_offset = floor((hash2(cell_pos) * 0.5 + 0.5) * 5.0);
        float type_rand = hash(cell_pos * 91.23);
        
        if (type_rand > 0.5) {
            if ((local_pos.x == start_offset.x + 1.0 && local_pos.y == start_offset.y + 2.0) || 
                (local_pos.x == start_offset.x + 0.0 && local_pos.y == start_offset.y + 1.0) || 
                (local_pos.x == start_offset.x + 2.0 && local_pos.y == start_offset.y + 1.0)) { 
                draw_blade = true;
            }
        } else {
            if ((local_pos.x == start_offset.x + 1.0 && local_pos.y == start_offset.y + 2.0) || 
                (local_pos.x == start_offset.x + 2.0 && local_pos.y == start_offset.y + 1.0)) {
                draw_blade = true;
            }
        }
    }

    if (draw_blade) {
        current_rgb = mix(current_rgb, blade_color.rgb, blade_opacity);
    }

    // --- AŞAMA 3: GERÇEK TEK PİKSEL NOKTALAR (1x1) ---
    float point_rand = hash(crisp_world_pos * 43.17);
    float point_cluster = fbm(crisp_world_pos * 0.05);

    if (point_rand < (point_density * 0.05) && point_cluster > 0.50) {
        current_rgb = mix(current_rgb, point_color.rgb, point_opacity);
    }

    // --- AŞAMA 4: YENİ ÖZELLEŞTİRİLEBİLİR ZEMİN NOISE ---
    float n_size = max(1.0, floor(noise_pixel_size));
    vec2 n_pos = floor(crisp_world_pos / n_size) * n_size;
    
    float structured_noise = fbm(n_pos * noise_scale);
    float chaotic_noise = hash(n_pos * 88.88);
    
    float blended_noise = mix(structured_noise, chaotic_noise, noise_randomness);
    
    if (blended_noise > (1.0 - noise_density)) {
        current_rgb = mix(current_rgb, noise_color.rgb, noise_opacity);
    }

    COLOR = vec4(current_rgb, texture_color.a);
}