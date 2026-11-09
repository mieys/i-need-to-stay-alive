shader_type canvas_item;

// GÖRÜNMEZKEN KENDİ EKRANIN KARARIR (madde 533, LoL'deki gizlenme görüşü gibi): tam ekran, yumuşak eliptik kenar karartması.
// Ortası yalnız hafifçe kısılır, kenarlara doğru koyu mor-laciverte döner; ASLA zifiri değil (sis kuralı) ve sert kenar yok.
// Ekran kopyası OKUMAZ (alfa karışımı) - açıkken bile maliyeti tek dörtgen. Sürücü: scripts/stealth_vision.gd (amount 0..1).

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.07, 0.05, 0.13, 1.0);
uniform float center_dark = 0.16; // ortadaki karartma (alfa)
uniform float edge_dark = 0.58;   // kenardaki karartma (alfa)
uniform float inner = 0.30;       // eliptik uzaklık: bu değere kadar orta değer
uniform float outer = 1.30;       // bu değerde tam kenar değeri (köşeler ~1,41)

void fragment() {
	vec2 q = (UV - vec2(0.5)) * 2.0; // ekran şeklinde elips: kenar ortası 1, köşe ~1,41
	float e = length(q);
	float v = smoothstep(inner, outer, e);
	float a = mix(center_dark, edge_dark, v * v * (3.0 - 2.0 * v)) * amount;
	COLOR = vec4(tint.rgb, a);
}
