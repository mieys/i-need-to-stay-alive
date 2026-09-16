shader_type canvas_item;

// Hafif, piksel-art dostu vignette: saf UV matematiğiyle hesaplanır,
// hiçbir texture örneklemesi (sampling) yapmaz - bu yüzden oyunun pikselleri
// bulanıklaşmaz, sadece ekran kenarlarına yarı saydam koyu bir gradyan
// bindirilir (alpha blend). ColorRect tüm ekranı kaplayacak şekilde
// yerleştirilip bu shader'ı kullanır.

uniform float intensity : hint_range(0.0, 1.0) = 0.35; // vignette'in en koyu noktadaki opaklığı
uniform float radius : hint_range(0.0, 1.5) = 0.85; // vignette'in başladığı merkezden uzaklık
uniform float softness : hint_range(0.01, 1.5) = 0.65; // radius'tan itibaren ne kadar yumuşak koyulaşacağı
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 centered_uv = (UV - 0.5) * 2.0; // -1..1 aralığına merkezlenir
	float dist = length(centered_uv);
	float vig = smoothstep(radius, radius + softness, dist);
	COLOR = vec4(vignette_color.rgb, vig * intensity);
}
