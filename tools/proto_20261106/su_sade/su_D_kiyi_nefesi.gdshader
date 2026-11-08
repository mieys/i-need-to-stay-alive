shader_type canvas_item;
// D "KIYI NEFESİ" (sade su prototipi, 2026-11-06, oyuna bağlı DEĞİL): suyun ortası tamamen DURGUN; tek hareket
// kıyıda: sabit 1 px kıyı çizgisinin önünde ikinci bir 1 px açık çizgi kıyıdan 2-4,5 px arasında yavaşça açılıp geri gelir
// (oyundaki yalama çizgisinin sakin hâli, koyu ıslak bant yok, kıyı boyunca farklı fazda).
#include "res://tools/proto_20261106/su_sade/su_sade_ortak.gdshaderinc"

uniform float nefes_hiz = 0.8; // rad/sn (~8 sn'de bir gidip gelir)
uniform float nefes_guc = 0.36;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (!mavi_mi(tex.rgb)) {
		COLOR = cimen_karosu(tex);
	} else {
		vec2 px = floor(world_pos);
		float d = kiyi(px);
		vec3 col;
		float a;
		taban(tex, col, a);
		float lap = 3.25 + 1.25 * sin(TIME * nefes_hiz + gnoise(px * 0.03) * 7.0);
		if (d >= lap && d < lap + 1.0) {
			col = mix(col, sirt_renk.rgb, nefes_guc);
			a = max(a, 0.84);
		}
		kiyi_cizgisi(d, col, a);
		COLOR = bitir(tex, col, a);
	}
}
