shader_type canvas_item;

// -----------------------------
// SU AYARLARI
// -----------------------------

uniform vec4 water_tint : source_color = vec4(0.18, 0.45, 0.63, 1.0);
uniform float water_alpha : hint_range(0.7, 1.0) = 0.94;

// Parıltı
uniform vec4 ripple_color : source_color = vec4(0.48, 0.76, 0.84, 1.0);
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.22;

// Hareket
uniform float ripple_speed : hint_range(0.0, 2.0) = 0.18;

// Parıltı miktarı
uniform float ripple_amount : hint_range(0.1, 2.0) = 0.75;


// -----------------------------
// HASH
// -----------------------------

float hash21(vec2 p)
{
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);

    return fract(p.x * p.y);
}


// -----------------------------
// ANA SHADER
// -----------------------------

void fragment()
{
    vec4 tex = texture(TEXTURE, UV);

    // -------------------------
    // SU RENGİ
    // -------------------------

    vec3 water = mix(
        tex.rgb,
        water_tint.rgb,
        0.12
    );


    // -------------------------
    // KOORDİNATLAR
    // -------------------------

    vec2 p = UV;

    // Daha fazla küçük ripple
    p *= 38.0;


    // Hafif hareket
    float t = TIME * ripple_speed;

    p.x += t * 0.35;
    p.y += sin(t * 0.7) * 0.15;


    // Grid
    vec2 cell = floor(p);
    vec2 local = fract(p) - 0.5;


    // Her hücreye farklı şekil
    float rnd = hash21(cell);


    // Sadece bazı hücrelerde ripple olsun
    float spawn = step(0.68, rnd);


    // -------------------------
    // KÜÇÜK KIVRIMLI PARILTI
    // -------------------------

    float curve =
        local.y
        + sin(local.x * 5.0 + rnd * 6.28)
        * 0.10;


    // İnce çizgi
    float line =
        1.0 - smoothstep(
            0.025,
            0.075,
            abs(curve)
        );


    // Çizginin uçlarını kes
    float ends =
        smoothstep(
            0.48,
            0.12,
            abs(local.x)
        );


    line *= ends;


    // -------------------------
    // PARILTIYI HAREKET ETTİR
    // -------------------------

    float phase =
        sin(TIME * ripple_speed * 2.0 + rnd * 20.0);


    // Yavaşça ortaya çıkıp kaybolsun
    float visibility =
        smoothstep(
            -0.4,
            0.5,
            phase
        );


    line *= visibility;
    line *= spawn;


    // -------------------------
    // İKİNCİ KÜÇÜK RIPPLE
    // -------------------------

    float curve2 =
        local.x
        + sin(local.y * 6.0 + rnd * 8.0)
        * 0.08;


    float line2 =
        1.0 - smoothstep(
            0.025,
            0.065,
            abs(curve2)
        );


    float ends2 =
        smoothstep(
            0.45,
            0.10,
            abs(local.y)
        );


    line2 *= ends2;


    float phase2 =
        sin(
            TIME * ripple_speed * 1.5
            + rnd * 30.0
        );


    line2 *= smoothstep(
        -0.35,
        0.55,
        phase2
    );


    // Daha az yoğun
    line2 *= spawn * 0.35;


    // -------------------------
    // BİRLEŞTİR
    // -------------------------

    float ripple =
        (line + line2)
        * ripple_strength
        * ripple_amount;


    // -------------------------
    // SUYA EKLE
    // -------------------------

    water +=
        ripple_color.rgb
        * ripple;


    // -------------------------
    // SONUÇ
    // -------------------------

    COLOR = vec4(
        water,
        tex.a * water_alpha
    );
}