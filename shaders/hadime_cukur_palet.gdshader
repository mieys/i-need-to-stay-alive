// Hadime E "Lanet Cukuru" (madde 556): sayfanin toprak / cimen / toz tonlarini harita zeminine gore degistirir (cimen haritalarda
// hic kullanilmaz - malzemesiz cizilir). Sayfa renkleri TAM degerdir (kayipsiz ice aktarma, NEAREST): src[i] ile birebir esleyen
// piksel dst[i] olur; cukurun kara dibi + yesil lanet isigi eslesmez, aynen kalir. Kaynak tonlar tools/gen_hadime_cukur_fx.py
// paleti, hedefler scripts/hadime_black_hole.gd PALETTES. Isiklandirma normal (unshaded degil): gece/zindan ortam isigini alir.
shader_type canvas_item;

uniform vec3 src[12];
uniform vec3 dst[12];

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	for (int i = 0; i < 12; i++) {
		if (all(lessThan(abs(c.rgb - src[i]), vec3(0.003)))) {
			c.rgb = dst[i];
			break;
		}
	}
	COLOR = c;
}
