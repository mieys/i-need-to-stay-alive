shader_type canvas_item;
// A "YAVAŞ IŞIK" (sade su prototipi, 2026-11-06, oyuna bağlı DEĞİL): suyun kendi rengi + 1 px kıyı çizgisi + suyun üstünden yavaşça
// geçen büyük, tek kademe açık lekeler (keskin kenar, nokta yok). Küçük öğe yok: dalgacık/çizgi/pırıltı hiç yok.
#include "res://tools/proto_20261106/su_sade/su_sade_ortak.gdshaderinc"

uniform float leke_esik = 0.6; // fbm bu değerin üstünde = açık leke (alanın ~%20'si)
uniform float leke_guc = 0.07; // +%7 parlaklık
uniform vec2 leke_hiz = vec2(2.2, 0.9); // dünya px/sn

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
		vec2 wp = (px - leke_hiz * TIME) * vec2(0.016, 0.032);
		col *= 1.0 + step(leke_esik, fbm2(wp)) * leke_guc;
		kiyi_cizgisi(d, col, a);
		COLOR = bitir(tex, col, a);
	}
}
