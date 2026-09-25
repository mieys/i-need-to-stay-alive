shader_type canvas_item;

// Tier savaş kartının (assets/ui/game/tier_card_*.png) ışıltısı - bkz. level_up_screen.gd _apply_card_tier_frame / _celebrate_pick.
//  - shine_pos: kartın üzerinden çapraz geçen parlama bandının konumu (0..1, dışı = görünmez). Bant SANAT pikseli ızgarasında
//    hesaplanır (art_size = dokunun sanat px boyutu), yani kenarları kartın kendi 3 px'lik pikselleriyle aynı basamaklı -
//    bulanık/yumuşak bir ışık süzmesi değil (bkz. hafıza: pixel-style FX).
//  - flash: seçim anındaki beyaz-altın parlama (0..1).
// COLOR zaten doku x modulate: kartın hover/karartma modulate'i bozulmaz, saydam pikseller saydam kalır.
uniform vec2 art_size = vec2(100.0, 160.0);
uniform float shine_pos = -1.0;
uniform float shine_strength = 0.0;
uniform float flash = 0.0;

void fragment() {
	vec4 c = COLOR;
	vec2 px = floor(UV * art_size);
	float d = (px.x + px.y * 0.5) / (art_size.x + art_size.y * 0.5);
	float band = 1.0 - step(0.045, abs(d - shine_pos));
	float band2 = 1.0 - step(0.014, abs(d - (shine_pos - 0.075)));
	c.rgb += vec3(band + band2 * 0.6) * shine_strength;
	c.rgb = mix(c.rgb, vec3(1.0, 0.97, 0.86), clamp(flash, 0.0, 1.0));
	COLOR = c;
}
