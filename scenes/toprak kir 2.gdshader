shader_type canvas_item;

uniform vec4 dirt_color : source_color = vec4(0.25, 0.20, 0.15, 1.0); // Kir rengi
uniform float dirt_opacity : hint_range(0.0, 1.0) = 0.35;             // Kir opaklığı

// Piksel ve Sıklık Ayarları
uniform float dirt_pixel_size : hint_range(1.0, 8.0) = 2.0;           // Kir piksellerinin ana boyutu
uniform float dirt_density : hint_range(0.001, 0.05) = 0.015;         // Kir deseni sıklığı (Küçük = geniş ve pürüzsüz)
uniform float noise_threshold : hint_range(0.0, 1.0) = 0.5;           // Kir miktar eşiği

varying vec2 world_pixel_pos;

void vertex() {
    world_pixel_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Güvenilir Pseudorandom Hash
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Sürekli ve dikişsiz geçiş sağlayan Yumuşak Gürültü (Value Noise)
float smooth_noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    // Smoothstep geçişi (Keskin kare sınırları yok eder)
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Kesintisiz Katmanlı Gürültü (FBM)
float fbm(vec2 st) {
    float value = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 3; i++) {
        value += amp * smooth_noise(st);
        st *= 2.0;
        amp *= 0.5;
    }
    return value;
}

void fragment() {
    vec4 texture_color = texture(TEXTURE, UV);

    // 1. Keskin kare sınırlarını engellemek için pikselleri doğrudan kilitliyoruz
    vec2 p = floor(world_pixel_pos / max(1.0, floor(dirt_pixel_size)));

    // 2. Dikişsiz dünya gürültüsünü hesapla
    float noise_val = fbm(p * dirt_density);

    // 3. Pikselli kir maskesi oluştur
    float dirt_mask = 0.0;
    if (noise_val > noise_threshold) {
        // Pikselli kenarları koruyarak yumuşak geçişli alanlar sağla
        dirt_mask = smoothstep(noise_threshold, noise_threshold + 0.2, noise_val);
    }

    // Renk harmanlama
    vec3 final_rgb = mix(texture_color.rgb, dirt_color.rgb, dirt_mask * dirt_opacity);

    COLOR = vec4(final_rgb, texture_color.a);
}