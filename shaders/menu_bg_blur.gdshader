shader_type canvas_item;
// MENÜ ARKA PLANI BULANIKLIĞI (2026-11-16, kullanıcı: "ana menü haricinde bir menüdeyken arkaplan blurlansın"). menu_bg_blur.gd kurar:
// önünde BackBufferCopy (kamp sahnesinin kendi ekran okuyan ışık geçişi kamp_gunbatimi.gdshader ekranı ÖNCE kopyalıyor; yeniden
// kopyalanmazsa alev/ateş böceği bu kopyada olmazdı). Ekran dokusunun mip zinciri (Godot arka tamponda gauss ile küçültür) + mip
// pikseli aralıklı 3x3 çadır süzgeci (mip blokları görünmesin). Bulanıklık TASARIM pikselinde sabit: pencere büyüdükçe mip düzeyi artar.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod = 2.6; // 1080 piksel yükseklikte mip düzeyi (2^lod ~ bulanıklık yarıçapı, ekran px)

void fragment() {
	float ui_scale = 1.0 / max(1080.0 * SCREEN_PIXEL_SIZE.y, 0.0001);
	float lod = max(blur_lod + log2(ui_scale), 0.0);
	vec2 d = SCREEN_PIXEL_SIZE * exp2(lod);
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb * 0.25;
	c += textureLod(screen_tex, SCREEN_UV + vec2(d.x, 0.0), lod).rgb * 0.125;
	c += textureLod(screen_tex, SCREEN_UV - vec2(d.x, 0.0), lod).rgb * 0.125;
	c += textureLod(screen_tex, SCREEN_UV + vec2(0.0, d.y), lod).rgb * 0.125;
	c += textureLod(screen_tex, SCREEN_UV - vec2(0.0, d.y), lod).rgb * 0.125;
	c += textureLod(screen_tex, SCREEN_UV + d, lod).rgb * 0.0625;
	c += textureLod(screen_tex, SCREEN_UV - d, lod).rgb * 0.0625;
	c += textureLod(screen_tex, SCREEN_UV + vec2(d.x, -d.y), lod).rgb * 0.0625;
	c += textureLod(screen_tex, SCREEN_UV + vec2(-d.x, d.y), lod).rgb * 0.0625;
	COLOR = vec4(c, 1.0);
}
