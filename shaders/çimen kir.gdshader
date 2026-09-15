shader_type canvas_item;

// --- 1. ÇİMEN TONLAMA PARAMETRELERİ ---
uniform vec4 dark_grass_color : source_color = vec4(0.35, 0.52, 0.22, 1.0);  // Koyu çim / gölge tonu
uniform vec4 light_grass_color : source_color = vec4(0.55, 0.68, 0.28, 1.0); // Açık / sarımsı çim tonu
uniform float grass_pixel_size : hint_range(1.0, 8.0) = 2.0;                 // Çimen tonlarının piksel boyutu
uniform float grass_patch_opacity : hint_range(0.0, 1.0) = 0.5;              // Çim tonlamasının belirginliği

// Büyük ve Küçük Öbek Parametreleri
uniform float grass_patch_density : hint_range(0.001, 0.05) = 0.015;          // Büyük çim öbeklerinin büyüklüğü
uniform float small_grass_patch_density : hint_range(0.01, 0.2) = 0.06;       // Küçük detay öbeklerinin büyüklüğü
uniform float detail_blend : hint_range(0.0, 1.0) = 0.35;                     // Küçük detayların ana öbeğe etki oranı
uniform float grass_noise_threshold : hint_range(0.0, 1.0) = 0.48;            // Çim ton kümesi yoğunluğu

// --- 2. KİR EFEKTİ PARAMETRELERİ ---
uniform vec4 dirt_color : source_color = vec4(0.25, 0.20, 0.15, 1.0);        // Kir rengi
uniform float dirt_opacity : hint_range(0.0, 1.0) = 0.35;                    // Kir opaklığı
uniform float dirt_min_size : hint_range(1.0, 4.0) = 1.0;                   // Minimum kir piksel boyutu
uniform float dirt_max_size : hint_range(2.0, 8.0) = 4.0;                   // Maksimum kir piksel boyutu
uniform float size_variation : hint_range(0.001, 0.1) = 0.02;               // Kir boyutlarının haritadaki değişim hızı
uniform float dirt_density : hint_range(0.01, 2.0) = 0.5;                    // Kir sıklığı/yoğunluğu
uniform float dirt_noise_threshold : hint_range(0.0, 1.0) = 0.55;            // Kir miktar eşiği

varying vec2 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Basit Hash Fonksiyonu
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Perlin Noise İçin Gradient Hash
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// Dikişsiz Perlin Noise
float perlin_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

// FBM (Fractal Brownian Motion)
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

    // --- AŞAMA 1: TEMİZ KOMBİNE ÇİMEN TONLAMA EFEKTİ ---
    float g_size = max(1.0, floor(grass_pixel_size));
    vec2 snapped_grass_pos = floor(world_pos / g_size) * g_size;

    // 1. Büyük ve Küçük Gürültüleri (Noise) Hesapla
    float big_noise = fbm(snapped_grass_pos * grass_patch_density);
    float small_noise = fbm((snapped_grass_pos + vec2(123.4, 567.8)) * small_grass_patch_density);

    // 2. İki gürültüyü harmanlayarak tek bir nihai gürültü değeri elde et
    float final_grass_noise = mix(big_noise, small_noise, detail_blend);

    // 3. Tek bir renk atama işlemi gerçekleştir (Üst üste binme yapmaz)
    if (final_grass_noise > grass_noise_threshold + 0.06) {
        current_rgb = mix(current_rgb, dark_grass_color.rgb, grass_patch_opacity);
    } else if (final_grass_noise < grass_noise_threshold - 0.06) {
        current_rgb = mix(current_rgb, light_grass_color.rgb, grass_patch_opacity);
    }

    // --- AŞAMA 2: DEĞİŞKEN PİKSEL BOYUTLU KİR EFEKTİ ---
    float size_rand = hash(floor(world_pos * size_variation));
    float current_size = floor(mix(dirt_min_size, dirt_max_size + 0.99, size_rand));
    current_size = max(1.0, current_size);

    vec2 dirt_p = floor(world_pos / current_size);

    float n1 = hash(dirt_p * dirt_density);
    float n2 = hash((dirt_p + vec2(117.3, 314.1)) * dirt_density * 1.31);
    float n3 = hash((dirt_p + vec2(713.7, 91.5)) * dirt_density * 0.73);
    float dirt_noise_val = mix(n1, mix(n2, n3, 0.5), 0.5);

    float dirt_mask = 0.0;
    if (dirt_noise_val > dirt_noise_threshold) {
        dirt_mask = (dirt_noise_val - dirt_noise_threshold) / (1.0 - dirt_noise_threshold);
    }

    vec3 final_rgb = mix(current_rgb, dirt_color.rgb, dirt_mask * dirt_opacity);

    COLOR = vec4(final_rgb, texture_color.a);
}