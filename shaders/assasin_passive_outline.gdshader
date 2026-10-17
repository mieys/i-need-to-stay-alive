shader_type canvas_item;

// Assasin Çocuk pasifi "Bıçak Uzmanlığı" (3 sn garantili kritik) - kullanıcı isteği 2026-10-16: "pasifi için de özel efekt
// hazırlayalım, varlığı hiç belli olmuyor". Karakterin O ANKİ karesinin kopyası (scripts/assasin_passive_fx.gd her karede
// eşitler) üzerinde SADECE dış hat çizilir: saydam texel'in 4 komşusundan biri doluysa kritik kırmızısı, gövdenin kendisi
// çizilmez (kopya gövdenin önünde dursa da onu örtmez). Yukarıdan aşağı kayan 2 texel'lik parıltı bandı, hat texel satırına
// oturur (piksel dili). Renk/alfa düğümün modulate'iyle (görünmezlik 0,35, ulti koyu tonu) çarpılır.

uniform vec4 edge_color : source_color = vec4(0.87, 0.23, 0.18, 1.0);
uniform vec4 shine_color : source_color = vec4(1.0, 0.84, 0.7, 1.0);
uniform float shine_period = 0.9;   // bandın bir tur süresi (sn)
uniform float frame_half = 24.0;    // karenin yarı yüksekliği (texel) - bant -frame_half..+frame_half arasında kayar

varying float local_y;
varying vec4 vcol; // modulate: fragment()'teki COLOR saydam texel'de zaten 0 alfalı (vertex x doku) - çarpım için ayrı taşınır

void vertex() {
	local_y = VERTEX.y;
	vcol = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (t.a > 0.5) {
		discard;
	}
	vec2 px = TEXTURE_PIXEL_SIZE;
	float n = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
			max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	if (n < 0.5) {
		discard;
	}
	float band = -frame_half + mod(TIME / shine_period, 1.0) * frame_half * 2.0;
	float row = floor(local_y);
	vec3 col = abs(row - floor(band)) < 1.5 ? shine_color.rgb : edge_color.rgb;
	COLOR = vec4(col, 1.0) * vcol;
}
