shader_type canvas_item;

// Kir dokusunu kontrol eden parametreler
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 dirt_color : source_color = vec4(0.25, 0.20, 0.15, 1.0); // Kir rengi (Kahverengi/Gri)
uniform float dirt_opacity : hint_range(0.0, 1.0) = 0.35;             // Kirin yoğunluğu
uniform float dirt_scale : hint_range(1.0, 100.0) = 20.0;             // Kir deseninin boyutu
uniform float noise_threshold : hint_range(0.0, 1.0) = 0.45;          // Kirin yayılma eşiği

// Basit 2D Pseudorandom Gürültü (Noise) Fonksiyonu
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float value_noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Dört köşedeki değerler
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    // Yumuşak geçiş (Smoothstep)
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Katmanlı Gürültü (Fractal Brownian Motion - FBM) ile daha doğal kir görünümü
float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 3; i++) {
        value += amplitude * value_noise(st);
        st *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    // Ekrandaki mevcut görüntüyü al
    vec4 screen_color = texture(screen_texture, SCREEN_UV);

    // Kir deseni için UV hesapla
    vec2 dirt_uv = UV * dirt_scale;
    float noise_val = fbm(dirt_uv);

    // Kir eşiğini uygula ve maske oluştur
    float dirt_mask = smoothstep(noise_threshold, noise_threshold + 0.3, noise_val);

    // Sadece ekranın şeffaf olmayan (TileMap pikseli olan) yerlerine kir uygula
    vec3 final_rgb = mix(screen_color.rgb, dirt_color.rgb, dirt_mask * dirt_opacity);

    COLOR = vec4(final_rgb, screen_color.a);
}