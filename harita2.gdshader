shader_type canvas_item;

uniform float variation : hint_range(0.0, 0.2) = 0.04;
uniform vec2 tile_size = vec2(32.0, 32.0);

float hash(vec2 p)
{
    p = fract(p * vec2(0.1031, 0.1030));
    p += dot(p, p.yx + 33.33);
    return fract((p.x + p.y) * p.x);
}

void fragment()
{
    vec4 tex = texture(TEXTURE, UV);

    // Dünya koordinatını kullan
    vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;

    // Hangi tile üzerinde olduğumuzu bul
    vec2 tile = floor(world / tile_size);

    // Her tile için sabit rastgele sayı
    float r = hash(tile);

    // Parlaklığı değiştir
    float b = mix(1.0 - variation, 1.0 + variation, r);

    tex.rgb *= b;

    COLOR = tex;
}
