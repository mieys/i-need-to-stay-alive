shader_type canvas_item;
render_mode blend_premul_alpha;

// YUMUŞAK PARILTI (kullanıcı bildirimi 2026-11-08: "parlaklığı olan şeyler üst üste binince çok parlak oluyor"): toplamalı
// (BLEND_MODE_ADD) parıltıların yerine "ekran" (screen) benzeri karışım. Toplamada sonuç = zemin + parıltı (üst üste binen
// her kopya ekler, beyaza kırpılır); burada sonuç = zemin * (1 - m) + parıltı, m = parıltının en güçlü kanalı. Tek kopya
// karanlık zeminde toplamayla neredeyse aynı, ama sonuç hiçbir zaman 1'i geçmez ve üst üste binen kopyalar parıltının
// KENDİ rengine yaklaşır (beyaza değil). Tek kaynak scripts/soft_glow_blend.gd (paylaşılan materyal).
void fragment() {
	// COLOR = doku * köşe rengi (modulate dahil).
	vec3 rgb = COLOR.rgb * COLOR.a;
	COLOR = vec4(rgb, max(rgb.r, max(rgb.g, rgb.b)));
}
