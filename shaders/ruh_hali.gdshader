shader_type canvas_item;
render_mode unshaded;

// RUH HÂLİ (madde 438/439, 2026-11-07): level/sandık menüsündeki oyuncu dünyada değilmiş gibi MAVİ RUH olarak görünür.
// Kullanıcının seçtiği prototip "A - Hayalet" (tools/proto_20261107/ruh_hali/ruh_proto_fx.gd style 0): karakterin o anki
// karesinin kopyası (scripts/limbo_fx.gd) çizilir - her piksel kendi çiziminden parlak camgöbeğine döner (detay korunur),
// yarı saydam, bacaklar aşağı doğru 4 basamakta silinir (hayalet kuyruğu), dışta 1 texel soluk hale. Dither/bulanıklık yok.
// Süzülme ve gölgenin gizlenmesi limbo_fx.gd'de.

uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0); // karenin atlastaki UV dikdörtgeni (komşu kareden örnek almasın)
uniform vec2 body_y = vec2(0.0, 1.0);           // karedeki opak gövdenin üst/alt UV y'si (kuyruk gövde boyuna göre)

bool inr(vec2 uv) {
	return uv.x >= region.x && uv.y >= region.y && uv.x < region.x + region.z && uv.y < region.y + region.w;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	float v = clamp((UV.y - body_y.x) / max(body_y.y - body_y.x, 0.0001), 0.0, 1.0);
	float fade = v < 0.62 ? 1.0 : (v < 0.76 ? 0.7 : (v < 0.88 ? 0.4 : 0.15));
	if (c.a > 0.5) {
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		vec3 g = mix(vec3(0.30, 0.58, 0.98), vec3(0.90, 0.99, 1.0), clamp(l * 1.5, 0.0, 1.0));
		COLOR = vec4(mix(c.rgb, g, 0.88), 0.74 * fade);
	} else {
		float n = 0.0;
		if (inr(UV + vec2(px.x, 0.0))) { n += texture(TEXTURE, UV + vec2(px.x, 0.0)).a; }
		if (inr(UV - vec2(px.x, 0.0))) { n += texture(TEXTURE, UV - vec2(px.x, 0.0)).a; }
		if (inr(UV + vec2(0.0, px.y))) { n += texture(TEXTURE, UV + vec2(0.0, px.y)).a; }
		if (inr(UV - vec2(0.0, px.y))) { n += texture(TEXTURE, UV - vec2(0.0, px.y)).a; }
		COLOR = n > 0.5 ? vec4(0.70, 0.93, 1.0, 0.6 * fade) : vec4(0.0);
	}
}
