shader_type canvas_item;

// GÖKKUŞAĞI ASASI ışın gövdesi (madde 306; prototip tools/proto_20261019/gokkusagi_proto.py Style "C"): krem çekirdek (1 px) + açık renkli orta
// bant + yarı saydam renkli dış bant; renk dilimleri (13 px) hedefe doğru 110 px/sn akar. Izgara = 1 dünya px, ışın ekseninde (dönük
// karo gibi; Yıldırım ışını da dönük piksel karo). Quad: fx_rainbow_beam.gd Body - yerel x = ışın boyu (0 namlu), y = -quad_h/2..quad_h/2.
// Başta 5 px incelme; temelde hedefte yuvarlak uç, finalde (spear) menzil sonunda sivri mızrak ucu.
// FİNAL "Lux Huzmesi" (lux, madde 551; prototip tools/proto_20261110/gokkusagi_v2 Final "A2"): görüş elipsinin kenarına kadar kalın düz ışın -
// krem çekirdek + açık bant + renk (ışın boyunca 40 px dilimlerden 5 adımlı geçişle akar) + yarı saydam dış hale, akan pırıltı çizgileri,
// son 28 px sise karışarak söner (full_len), gönderilişte (launching) uç parlak; üstünde her vuruşta asadan uca koşan rengarenk HALKALAR (rings).

uniform float beam_len = 100.0;
uniform float quad_len = 104.0;
uniform float quad_h = 12.0;
uniform float width = 3.0;
uniform float t = 0.0;
uniform float flicker = 0.0;
uniform float bright = 0.0;
uniform bool spear = false;
uniform bool lux = false;
uniform float full_len = 100.0; // lux: tam boy (görüş kenarı); gönderilişte beam_len bundan kısa
uniform bool launching = false;
uniform float ring_fade = 1.0; // bırakışta halkalar ışınla söner
uniform float ring_h = 17.0; // halka yarı yüksekliği (ışın yarı genişliği + 6)
uniform float ring_alpha = 0.75; // ön yarının saydamlığı (arka yarı x0,3); kullanıcı 2026-11-10 "halkaları biraz daha saydam" (eski 1,0 / 0,5)
uniform vec4 rings[9]; // x = halkanın ışın boyundaki yeri (px), yzw = renk
uniform int ring_n = 0;

const vec3 CREAM = vec3(1.0, 0.980, 0.941);
const vec3 RB[6] = vec3[6](
	vec3(0.941, 0.416, 0.353), vec3(0.969, 0.635, 0.290), vec3(0.957, 0.847, 0.353),
	vec3(0.525, 0.824, 0.431), vec3(0.384, 0.698, 0.925), vec3(0.659, 0.478, 0.902));

float qa(float a) {
	return ceil(clamp(a, 0.0, 1.0) * 4.0 - 1e-6) / 4.0;
}

vec4 lux_beam(float s, float d) {
	float ad = abs(d);
	float w = width * clamp((s + 0.5) / 16.0, 0.35, 1.0);
	if (launching) {
		w = w * pow(clamp((beam_len - s) / 10.0, 0.0, 1.0), 0.5) + (abs(s - beam_len) < 6.0 ? 2.0 : 0.0);
	}
	float u = ad / max(w, 0.6);
	bool inside = s >= 0.0 && s <= beam_len && ad <= w + 0.15;
	float x = (s - t * 160.0) / 40.0;
	int h0 = int(mod(floor(x), 6.0));
	int h1 = (h0 + 1) % 6;
	vec3 hue = mix(RB[h0], RB[h1], floor(fract(x) * 5.0) / 5.0);
	vec3 col = u < 0.22 ? CREAM : (u < 0.5 ? mix(hue, CREAM, 0.5) : hue);
	float a = u < 0.22 ? 1.0 : (u < 0.85 ? 0.75 : 0.5);
	if (mod(s - t * 260.0, 54.0) < 4.0 && u < 0.85) {
		col = mix(col, CREAM, 0.5);
	}
	float e = clamp((full_len - s) / 28.0, 0.0, 1.0);
	a *= e > 0.75 ? 1.0 : (e > 0.5 ? 0.75 : (e > 0.25 ? 0.5 : (e > 0.0 ? 0.25 : 0.0)));
	if (launching && abs(s - beam_len) < 5.0) {
		col = mix(col, CREAM, 0.7);
	}
	col = mix(col, CREAM, clamp(flicker * 0.3 + bright * 0.15, 0.0, 0.45));
	a = inside ? qa(a) : 0.0;
	vec4 outc = vec4(col * a, a);
	// halkalar: ön yarı (uca bakan) dolu, arka yarı soluk (ışının arkasından geçer)
	for (int i = 0; i < 9; i++) {
		if (i >= ring_n) {
			break;
		}
		float pos = rings[i].x;
		if (pos <= 4.0 || pos >= beam_len - 4.0) {
			continue;
		}
		float rr = length(vec2((s - pos) / 3.2, d / ring_h));
		if (abs(rr - 1.0) > 0.3) {
			continue;
		}
		float ee = clamp((full_len - pos) / 40.0, 0.0, 1.0);
		float al = (ee > 0.5 ? 1.0 : (ee > 0.25 ? 0.75 : 0.5)) * ring_fade;
		vec3 rc = rings[i].yzw;
		vec3 c2 = s < pos ? rc * 0.8 : (ad < 2.0 ? mix(rc, CREAM, 0.6) : rc);
		float a2 = qa((s < pos ? 0.3 : 1.0) * ring_alpha * al);
		outc = vec4(c2 * a2, a2) + outc * (1.0 - a2);
	}
	return outc.a > 0.0 ? vec4(outc.rgb / outc.a, outc.a) : vec4(0.0);
}

void fragment() {
	float s = floor(UV.x * quad_len) + 0.5;
	float d = floor((UV.y - 0.5) * quad_h + 0.5);
	if (lux) {
		COLOR = lux_beam(s, d);
	} else {
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
}
