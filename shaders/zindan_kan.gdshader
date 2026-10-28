shader_type canvas_item;

// ZİNDAN KAN KANALI (madde 373, Et Kuyusu "Kan" katmanı): batık zemin dokusunun üstünde yavaş akan koyu kan yüzeyi - iki dalga bandı +
// ince parıltı (dünya pikseline yuvarlı, piksel sanatıyla uyumlu), basamaksız. DungeonManager._load_dungeon "Kan" katmanına verir.

uniform vec4 surface : source_color = vec4(0.42, 0.04, 0.06, 1.0);
uniform vec4 shine : source_color = vec4(0.95, 0.32, 0.28, 1.0);
uniform float flow = 6.0; // px/sn akış (x)

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 p = floor(world) + vec2(TIME * flow, 0.0);
	// ince, seyrek parıltı çizgileri (yakalamada iri lekeler gibi duruyordu): yüksek frekans + dar eşik + düşük karışım
	float w1 = sin(p.x * 0.21 + p.y * 0.07 + TIME * 0.9) * 0.5 + 0.5;
	float w2 = sin(p.x * 0.05 - p.y * 0.17 - TIME * 0.6) * 0.5 + 0.5;
	float band = smoothstep(0.9, 0.98, w1 * w2 + 0.18 * w1);
	float ripple = sin(p.x * 0.09 + p.y * 0.21 - TIME * 1.3) * 0.5 + 0.5;
	vec3 col = mix(base.rgb, surface.rgb, 0.55);
	col *= 0.94 + 0.06 * ripple;
	col = mix(col, shine.rgb, band * 0.3);
	COLOR = vec4(col, base.a);
}
