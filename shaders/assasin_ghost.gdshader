shader_type canvas_item;

// Assasin Çocuk ULTİ (Gölge Hücumu) sıçrayış hayaleti - kullanıcı isteği 2026-10-16 ("suikastçı hızını hissettirmiyor").
// Karakterin o anki karesinden düz mor SİLÜET + 1 texel açık kenar; sönerken saydamlaşmaz, Bayer deseniyle piksel piksel
// dağılır (oyunun piksel dili). Sönme miktarı düğümün modulate.a'sından gelir (vertex rengi -> varying): tüm hayaletler
// TEK malzemeyi paylaşır (bkz. scripts/fx_assasin_ult_streak.gd). fragment()'teki COLOR zaten vertex x doku olduğu için
// alfa vertex()'te okunur.

uniform vec4 fill_color : source_color = vec4(0.157, 0.071, 0.259, 1.0);
uniform vec4 rim_color : source_color = vec4(0.588, 0.392, 0.863, 1.0);

varying float fade;

void vertex() {
	fade = COLOR.a;
}

// 4x4 Bayer eşiği (0..1) - matris dizisi yerine bit örgüsü: [0 8 2 10; 12 4 14 6; 3 11 1 9; 15 7 13 5].
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int xy = x ^ y;
	int v = ((xy & 1) << 3) | ((y & 1) << 2) | (((xy >> 1) & 1) << 1) | ((y >> 1) & 1);
	return (float(v) + 0.5) / 16.0;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (t.a < 0.5) {
		discard;
	}
	vec2 px = TEXTURE_PIXEL_SIZE;
	if (bayer4(floor(UV / px)) >= fade) {
		discard;
	}
	float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a * texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			* texture(TEXTURE, UV + vec2(0.0, px.y)).a * texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	COLOR = vec4(n < 0.25 ? rim_color.rgb : fill_color.rgb, 1.0);
}
