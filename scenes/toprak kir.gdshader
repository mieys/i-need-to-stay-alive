shader_type canvas_item;

// ==================================================
// MEVCUT AYARLAR
// ==================================================

uniform float detail_strength : hint_range(0.0, 1.0) = 0.16;
uniform float speckle_amount : hint_range(0.0, 1.0) = 0.10;
uniform float pixel_size : hint_range(1.0, 8.0) = 2.0;

uniform float large_variation : hint_range(0.0, 1.0) = 0.18;
uniform float patch_amount : hint_range(0.0, 1.0) = 0.20;

// YENİ: Shader efektinin kendi opaklığı (Orijinal doku ile efekt arası geçiş)
uniform float soil_opacity : hint_range(0.0, 1.0) = 1.0;

// ==================================================
// KURU TOPRAK GENEL RASTGELELİĞİ
// ==================================================

uniform float dry_amount : hint_range(0.0, 1.0) = 0.28;
uniform float dry_strength : hint_range(0.0, 1.0) = 0.28;

// Lekenin genel büyüklüğü
uniform float dry_scale : hint_range(0.01, 0.15) = 0.045;

// Ovalite
uniform float dry_ovalness : hint_range(0.2, 2.0) = 1.15;

// Kenarın yumuşaklığı (Aktif)
uniform float dry_softness : hint_range(0.01, 0.5) = 0.12;

// ==================================================
// RENKLER
// ==================================================

uniform vec4 dark_soil : source_color = vec4(0.38, 0.31, 0.22, 1.0);
uniform vec4 light_soil : source_color = vec4(0.55, 0.46, 0.34, 1.0);
// Aktif
uniform vec4 dry_soil : source_color = vec4(0.59, 0.49, 0.35, 1.0);

// ==================================================
// RANDOM
// ==================================================

float hash21(vec2 p)
{
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 74.7);
	return fract(p.x * p.y);
}

// ==================================================
// NOISE
// ==================================================

float noise(vec2 p)
{
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	f = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(a, b, f.x),
		mix(c, d, f.x),
		f.y
	);
}

// ==================================================
// FBM
// ==================================================

float fbm(vec2 p)
{
	float value = 0.0;
	value += noise(p) * 0.55;
	value += noise(p * 2.0) * 0.30;
	value += noise(p * 4.0) * 0.15;
	return value;
}

// ==================================================
// GENEL ORGANİK KURU TOPRAK ALANI
// ==================================================

float dry_field(vec2 p)
{
	// Domain Warp
	float warp_x = fbm(p * 0.018);
	float warp_y = fbm(p * 0.018 + vec2(43.7, 17.2));

	vec2 warped_p = p + vec2(warp_x - 0.5, warp_y - 0.5) * 24.0;

	// ANA GENİŞ RASTGELE ALAN
	float broad = fbm(warped_p * dry_scale);

	// İKİNCİ, DAHA UZUN NOISE
	vec2 stretched = warped_p;
	stretched.x *= dry_ovalness;
	stretched.y *= 0.72;

	float elongated = fbm(stretched * dry_scale * 1.35);

	// NOISE'LARI BİRLEŞTİR
	float field = broad * 0.68 + elongated * 0.32;

	// SADECE BAZI BÖLGELERİ SEÇ
	float dry_mask = smoothstep(
		1.0 - dry_amount - 0.12,
		1.0 - dry_amount + 0.08,
		field
	);

	// ORGANİK KENAR
	float edge_noise = fbm(warped_p * 0.055);
	dry_mask += (edge_noise - 0.5) * 0.18;

	// SOFT EDGE (dry_softness kullanılıyor)
	float soft_lower = clamp(0.5 - dry_softness, 0.0, 0.49);
	float soft_upper = clamp(0.5 + dry_softness, 0.51, 1.0);
	dry_mask = smoothstep(soft_lower, soft_upper, dry_mask);

	return clamp(dry_mask, 0.0, 1.0);
}

// ==================================================
// FRAGMENT
// ==================================================

void fragment()
{
	vec4 tex = texture(TEXTURE, UV);

	// TOPRAK MASKESİ
	float soil_mask = smoothstep(0.18, 0.38, tex.r - tex.g * 0.55);

	// PIXEL KOORDİNATLARI
	vec2 pixel_uv = UV / TEXTURE_PIXEL_SIZE;
	vec2 p = floor(pixel_uv / pixel_size);

	// MEVCUT BÜYÜK VARYASYON
	float large_noise = fbm(p * 0.018);
	float large_change = (large_noise - 0.5) * large_variation;

	// MEVCUT ORTA LEKELER
	float patch_noise = fbm(p * 0.055);
	float patch_dark = smoothstep(0.68, 0.82, patch_noise);
	float patch_light = smoothstep(0.20, 0.34, patch_noise);

	// MEVCUT KÜÇÜK DETAY
	float small_noise = noise(p * 0.23);
	float small_variation = (small_noise - 0.5) * detail_strength;

	// ANA TOPRAK
	vec3 soil_color = tex.rgb;

	soil_color += large_change * vec3(0.10, 0.075, 0.045);

	soil_color = mix(
		soil_color,
		soil_color * vec3(0.84, 0.82, 0.76),
		patch_dark * patch_amount
	);

	soil_color = mix(
		soil_color,
		soil_color + vec3(0.055, 0.045, 0.030),
		patch_light * patch_amount * 0.7
	);

	soil_color += small_variation * vec3(0.08, 0.06, 0.035);

	// RASTGELE KURU TOPRAK ALANI (dry_soil bağlandı)
	float dry = dry_field(p);

	vec3 dry_color = dry_soil.rgb;

	// İçerideki varyasyon
	float dry_inside = fbm(p * 0.035);
	dry_color += (dry_inside - 0.5) * vec3(0.035, 0.025, 0.015);

	// Kuru bölgeleri mevcut shaderın üzerine ekle
	soil_color = mix(
		soil_color,
		dry_color,
		dry * dry_strength
	);

	// MEVCUT KÜÇÜK PIXEL DETAYLARI
	float speckle = hash21(p * 1.91);
	float local_density = noise(floor(p * 0.16) + 42.7);
	float local_amount = speckle_amount * (0.35 + local_density * 1.35);

	if (speckle > 1.0 - local_amount)
	{
		float type = hash21(p + 91.73);

		if (type < 0.52)
		{
			soil_color = mix(soil_color, dark_soil.rgb, 0.22);
		}
		else
		{
			soil_color = mix(soil_color, light_soil.rgb, 0.14);
		}
	}

	// SEYREK PIXEL KÜMELERİ
	vec2 cluster_cell = floor(p * 0.35);
	float cluster_random = hash21(cluster_cell + 17.31);

	if (cluster_random > 0.90)
	{
		float cluster_pixel = hash21(p + cluster_cell * 7.13);

		if (cluster_pixel > 0.58)
		{
			soil_color *= 0.90;
		}
	}

	// TOPRAK EFEKTİNİN OPAKLIĞI (soil_opacity burada maskeyi etkiliyor)
	vec3 final_color = mix(
		tex.rgb,
		soil_color,
		soil_mask * soil_opacity
	);

	// Orijinal doku alfa kanalı aynen korunuyor
	COLOR = vec4(final_color, tex.a);
}