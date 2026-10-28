shader_type canvas_item;
#include "res://shaders/harita_renk.gdshaderinc"

// Oakley R "Hayat Ağacı" (madde 266): sanat haritanın meyve ağacı (sadece agac golgeli tileseti) - haritadaki ağaçlarla AYNI renk
// ayarından geçer (madde 181, yoksa yanlarındaki ağaçlardan canlı/açık görünür) ve onlar gibi hafifçe sallanır. Sallanma
// "sallanan ağaç.gdshader" fikriyle aynı: çizim değişmez, dörtgenin KÖŞELERİ kaydırılır - gövde dibi (alt kenar) sabit, tepe en çok.
uniform float strength : hint_range(0.0, 6.0) = 1.4; // tepenin en fazla kayması (doku pikseli)
uniform float salinim_hizi : hint_range(0.0, 4.0) = 0.9;
uniform float faz = 0.0;
varying vec2 hr_dunya; // derin orman bölge renk ayarı için sallanma ÖNCESİ dünya konumu (madde 359)

void vertex() {
	hr_dunya = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float k = clamp(1.0 - UV.y, 0.0, 1.0);
	VERTEX.x += sin(TIME * salinim_hizi * 1.7 + faz) * strength * k;
}

void fragment() {
	if (COLOR.a > 0.0) { COLOR.rgb = harita_renk_d(COLOR.rgb, hr_dunya); } // fragment()'in EN SONUNDA (harita_renk.gdshaderinc kuralı; madde 359 bölge ayarı dahil)
}
