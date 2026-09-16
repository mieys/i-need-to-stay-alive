shader_type canvas_item;

// --- DÜNYA SABİTLEME AYARI ---
uniform vec2 camera_pos = vec2(0.0, 0.0);                            // Kameranın oyundaki gerçek konumu
// DÜZELTME: ekran-uzayı VERTEX'i dünyaya çevirirken kameranın zoom/ölçeği de
// gerekiyor (bkz. kamera takip.gd) - yoksa sadece ekranın (0,0) köşesi doğru
// çıkıyor, geri kalan her piksel (özellikle ekran ORTASI - karakterin
// durduğu yer) orantısız kayıyordu.
uniform vec2 camera_scale = vec2(1.0, 1.0);

uniform vec4 wind_color : source_color = vec4(1.0, 1.0, 1.0, 0.35); // Rüzgar rengi ve şeffaflığı
uniform float pixel_size : hint_range(1.0, 16.0) = 2.0;             // Pikselizasyon boyutu

// --- HARİTA VE BOYUT AYARLARI ---
uniform float world_scale : hint_range(0.001, 0.1) = 0.01;           
uniform float line_thickness : hint_range(0.001, 0.05) = 0.008;      
uniform float wind_length : hint_range(1.0, 50.0) = 12.0;           

// --- AKIŞ VE SIKLIK AYARLARI ---
uniform float speed : hint_range(0.1, 50.0) = 15.0;                 
uniform float wind_angle : hint_range(-45.0, 45.0) = -8.0;          
uniform float density_threshold : hint_range(0.1, 0.99) = 0.82;     

float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.34));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); 
    
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

varying vec2 world_position;

void vertex() {
    // Ekran-uzayı (piksel) konumunu ÖNCE zoom/ölçeğe bölüp gerçek dünya
    // birimine çeviriyoruz, SONRA kameranın (ekranın sol üst köşesinin)
    // dünya konumunu ekleyerek rüzgarı haritaya (dünyaya) sabitliyoruz.
    world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy / camera_scale + camera_pos;
}

void fragment() {
    vec2 p_uv = floor(world_position / pixel_size) * pixel_size;
    
    float rad = radians(wind_angle);
    mat2 rot = mat2(vec2(cos(rad), -sin(rad)), vec2(sin(rad), cos(rad)));
    vec2 uv = rot * p_uv * world_scale;
    
    float movement = TIME * speed * 0.1;
    vec2 move_uv = vec2(uv.x - movement, uv.y);
    
    move_uv.y += sin(move_uv.x * 2.0 + movement * 0.5) * 0.15;
    
    vec2 noise_uv = vec2(move_uv.x / wind_length, move_uv.y * 8.0);
    float n = value_noise(noise_uv);
    
    float mask = smoothstep(density_threshold, density_threshold + 0.05, n);
    
    if (mask > 0.0) {
        float line_center = fract(move_uv.y * 8.0);
        float d = abs(line_center - 0.5);
        float line_shape = smoothstep(line_thickness, 0.0, d);
        
        float head_tail_fade = sin(fract(noise_uv.x) * 3.14159);
        
        mask *= line_shape * head_tail_fade;
    }
    
    COLOR = vec4(wind_color.rgb, mask * wind_color.a);
}