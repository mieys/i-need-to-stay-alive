shader_type canvas_item;

// Melek Q/E bağı sürerken halesi bağın rengine bürünür (madde 212; kullanıcı: "bağ kafasının üstündeki melek halkasında olsun").
// melek_halo_fx.gd karakterin O ANKİ karesinin kopyasını bu shader'la çizer: SADECE hale pikselleri görünür, gerisi saydam.
// Hale renkleri Melek sayfalarında yalnızca halede geçer (tools/gen_melek_bond_fx.py ile ölçüldü): 3 altın ton -> ring_col,
// tek tonlu koyu kahve kontur (80,54,21; iç satır dahil) -> edge_col. Hale büyümez, sadece boyanır.

uniform vec4 ring_col : source_color;
uniform vec4 edge_col : source_color;

bool near(vec3 c, vec3 ref) {
	return distance(c, ref / 255.0) < 0.016;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (t.a < 0.5) {
		discard;
	}
	if (near(t.rgb, vec3(247.0, 203.0, 63.0)) || near(t.rgb, vec3(243.0, 204.0, 65.0)) || near(t.rgb, vec3(239.0, 216.0, 47.0))) {
		COLOR = vec4(ring_col.rgb, COLOR.a);
	} else if (near(t.rgb, vec3(80.0, 54.0, 21.0))) {
		COLOR = vec4(edge_col.rgb, COLOR.a);
	} else {
		discard;
	}
}
