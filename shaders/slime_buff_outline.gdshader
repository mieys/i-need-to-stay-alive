shader_type canvas_item;

// Minik Cadı büyüsü aktifken karakterin görünüşü (madde 523, scripts/slime_buff_fx.gd). Karakterin O ANKİ karesinin kopyası üzerinde:
//  - silhouette = 0: SADECE dış hat - saydam texel'in 4 komşusundan biri doluysa pembe (1. halka), 2 texel uzaktaysa soluk pembe
//    (2. halka, ışıma gibi; düz bant, dither yok). Gövde çizilmez (kopya önde dursa da örtmez). Yukarıdan aşağı kayan krem parıltı
//    bandı 1. halkanın texel satırına oturur (piksel dili; assasin_passive_outline.gdshader ile aynı kural).
//  - silhouette = 1: dolu silüet (büyü varış anındaki güç dalgası) - opak texel'ler düz pembe.
// Renk/alfa düğümün modulate'iyle çarpılır (görünmezlik, çalı/Hayalet saydamlığı slime_buff_fx.gd'de kopyalanır).

uniform vec4 edge_color : source_color = vec4(1.0, 0.44, 0.73, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.62, 0.84, 0.45);
uniform vec4 shine_color : source_color = vec4(1.0, 0.96, 0.98, 1.0);
uniform float shine_period = 1.1;
uniform float frame_half = 24.0;
uniform float silhouette = 0.0;

varying float local_y;
varying vec4 vcol;

void vertex() {
	local_y = VERTEX.y;
	vcol = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	if (silhouette > 0.5) {
		if (t.a < 0.5) {
			discard;
		}
		COLOR = vec4(edge_color.rgb, 1.0) * vcol;
	} else {
		if (t.a > 0.5) {
			discard;
		}
		float n1 = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
				max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
		if (n1 > 0.5) {
			float band = -frame_half + mod(TIME / shine_period, 1.0) * frame_half * 2.0;
			vec3 col = abs(floor(local_y) - floor(band)) < 1.5 ? shine_color.rgb : edge_color.rgb;
			COLOR = vec4(col, 1.0) * vcol;
		} else {
			float n2 = max(max(texture(TEXTURE, UV + vec2(px.x * 2.0, 0.0)).a, texture(TEXTURE, UV - vec2(px.x * 2.0, 0.0)).a),
					max(texture(TEXTURE, UV + vec2(0.0, px.y * 2.0)).a, texture(TEXTURE, UV - vec2(0.0, px.y * 2.0)).a));
			n2 = max(n2, max(max(texture(TEXTURE, UV + px).a, texture(TEXTURE, UV - px).a),
					max(texture(TEXTURE, UV + vec2(px.x, -px.y)).a, texture(TEXTURE, UV + vec2(-px.x, px.y)).a)));
			if (n2 < 0.5) {
				discard;
			}
			COLOR = glow_color * vcol;
		}
	}
}
