shader_type canvas_item;

// GÖKKUŞAĞI ASASI ışın gövdesi (madde 306; prototip tools/proto_20261019/gokkusagi_proto.py Style "C"): krem çekirdek (1 px) + açık renkli orta
// bant + yarı saydam renkli dış bant; renk dilimleri (13 px) hedefe doğru 110 px/sn akar. Izgara = 1 dünya px, ışın ekseninde (dönük
// karo gibi; Yıldırım ışını da dönük piksel karo). Quad: fx_rainbow_beam.gd Body - yerel x = ışın boyu (0 namlu), y = -quad_h/2..quad_h/2.
// Başta 5 px incelme; temelde hedefte yuvarlak uç, finalde (spear) menzil sonunda sivri mızrak ucu.

uniform float beam_len = 100.0;
uniform float quad_len = 104.0;
uniform float quad_h = 12.0;
uniform float width = 3.0;
uniform float t = 0.0;
uniform float flicker = 0.0;
uniform float bright = 0.0;
uniform bool spear = false;

const vec3 CREAM = vec3(1.0, 0.980, 0.941);
const vec3 RB[6] = vec3[6](
	vec3(0.941, 0.416, 0.353), vec3(0.969, 0.635, 0.290), vec3(0.957, 0.847, 0.353),
	vec3(0.525, 0.824, 0.431), vec3(0.384, 0.698, 0.925), vec3(0.659, 0.478, 0.902));

void fragment() {
	float s = floor(UV.x * quad_len) + 0.5;
	float d = floor((UV.y - 0.5) * quad_h + 0.5);
	float ad = abs(d);
	// Geniş ışında incelme ve sivri uç da orantılı uzar (madde 331: yarı genişlik 3 -> 6).
	float w = width * clamp((s + 0.5) / max(5.0, width * 1.2), 0.35, 1.0);
	bool inside;
	if (spear) {
		w *= pow(clamp((beam_len - s) / max(14.0, width * 2.8), 0.0, 1.0), 0.7);
		inside = s <= beam_len && ad <= w + 0.15;
	} else if (s <= beam_len) {
		inside = ad <= w + 0.15;
	} else {
		float e = s - beam_len;
		inside = d * d + e * e <= w * w;
	}
	int h = int(mod(floor((s - t * 110.0) / 13.0), 6.0));
	vec3 rb = RB[h];
	vec3 col;
	float a;
	if (ad < max(0.5, w * 0.22)) {
		col = CREAM;
		a = 1.0;
	} else if (ad <= max(1.0, w * 0.58)) {
		col = mix(rb, CREAM, 0.5);
		a = 1.0;
	} else {
		col = rb;
		a = 0.5;
	}
	col = mix(col, CREAM, clamp(flicker * 0.3 + bright * 0.15, 0.0, 0.45));
	COLOR = vec4(col, inside ? a : 0.0);
}
