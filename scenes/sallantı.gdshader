shader_type canvas_item;

// Sallanma Güç ve Hız Ayarları
uniform float speed : hint_range(0.0, 10.0) = 4.0;       // Sallanma hızı
uniform float strength : hint_range(0.0, 100.0) = 10.0;   // Sallanma şiddeti
uniform float detail : hint_range(0.0, 10.0) = 2.0;      // Küçük kıpırdama

// Kök Kilit ve Esnetme Ayarları
uniform float root_cutoff : hint_range(0.0, 1.0) = 0.95; 
uniform float sway_falloff : hint_range(0.1, 5.0) = 1.5; 

// Grid / Izgara Ayarı (Görseldeki bitkileri birbirinden ayırmak için)
// Bitkilerinizin ortalama piksel boyutuna göre ayarlayın (örn: 16.0 veya 32.0)
uniform float plant_grid_size : hint_range(4.0, 64.0) = 16.0; 

// Basit Rastgelelik (Hash) Fonksiyonu
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

void vertex() {
    // 1. Köklerin sabit kalması
    float height_factor = clamp((root_cutoff - UV.y) / root_cutoff, 0.0, 1.0);
    height_factor = pow(height_factor, sway_falloff);
    
    // 2. HER BİTKİ İÇİN BENZERSİZ DÜNYA KOORDİNATI
    // VERTEX ve MODEL_MATRIX birleştirilerek tam piksel konumu elde edilir.
    vec2 actual_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
    
    // Yakındaki pikselleri aynı bitki grubunda toplamak için Grid'e bölüyoruz
    vec2 plant_cell = floor(actual_world_pos / plant_grid_size);
    
    // 3. HER BİTKİYE ÖZEL RASTGELE YÖN VE ZAMAN
    // -1.0 ile 1.0 arası değer: BAZILARI SAĞA, BAZILARI SOLA YATAR
    float direction_sign = sign(hash(plant_cell + vec2(15.3, 42.1)) - 0.5);
    
    // Her bitkinin başlama anı (phase) ve hızı farklı olur
    float phase_offset = hash(plant_cell) * 6.28318;
    float individual_speed = speed * (0.8 + hash(plant_cell + vec2(1.0, 2.0)) * 0.4);
    
    float custom_time = (TIME * individual_speed) + phase_offset;
    
    // 4. Dalga Hesaplaması
    float main_wave = sin(custom_time);
    float detail_wave = cos(custom_time * 2.3) * (0.2 * detail);
    
    // direction_sign ile çarparak bazı bitkileri varsayılan olarak tam zıt yöne yönlendiriyoruz
    float final_wave = (main_wave + detail_wave) * strength * direction_sign;
    
    // 5. Kaydırma
    VERTEX.x += final_wave * height_factor;
}