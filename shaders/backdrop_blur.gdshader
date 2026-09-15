shader_type canvas_item;

// Basit ekran-uzayı bulanıklaştırma - seviye atlama ekranı (kart seçimi VE
// geri sayım aşaması) açıkken arkadaki oyun sahnesini hafifçe bulanıklaştırır
// (kullanıcı isteği: "arkaplan azıcık bulanıklaşsın"). Tek geçişli 3x3
// ağırlıklı (Gauss benzeri) çekirdek kullanır - "azıcık" istendiği için
// bilinçli olarak HAFİF (blur_amount küçük), ağır/çok geçişli bir blur değil.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_amount : hint_range(0.0, 8.0) = 4.0;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur_amount;
	vec4 sum = vec4(0.0);
	sum += textureLod(screen_texture, SCREEN_UV + vec2(-px.x, -px.y), 0.0) * 0.0625;
	sum += textureLod(screen_texture, SCREEN_UV + vec2(0.0, -px.y), 0.0) * 0.125;
	sum += textureLod(screen_texture, SCREEN_UV + vec2(px.x, -px.y), 0.0) * 0.0625;
	sum += textureLod(screen_texture, SCREEN_UV + vec2(-px.x, 0.0), 0.0) * 0.125;
	sum += textureLod(screen_texture, SCREEN_UV, 0.0) * 0.25;
	sum += textureLod(screen_texture, SCREEN_UV + vec2(px.x, 0.0), 0.0) * 0.125;
	sum += textureLod(screen_texture, SCREEN_UV + vec2(-px.x, px.y), 0.0) * 0.0625;
	sum += textureLod(screen_texture, SCREEN_UV + vec2(0.0, px.y), 0.0) * 0.125;
	sum += textureLod(screen_texture, SCREEN_UV + vec2(px.x, px.y), 0.0) * 0.0625;
	// Guvenlik payi: ekran dokusu ornegi beklenmedik bicimde bos/saydam
	// gelirse bile bulaniklastirma tamamen gorunmez kalmasin diye sonuc
	// her zaman hafif koyu bir tonla harmanlaniyor.
	COLOR = mix(sum, vec4(0.05, 0.04, 0.07, 1.0), 0.12);
}
