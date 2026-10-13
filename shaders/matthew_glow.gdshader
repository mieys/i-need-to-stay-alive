shader_type canvas_item;

// Matthew R "Yıldırım Kalkanı" (madde 98, kullanıcı: "Matthew bu esnada sarı parıldasın ... kalkanın kırılma noktasına
// yaklaşmasına bağlı olarak artsın"): level 0 = kalkan dolu (parıltı yok), 1 = kırılmak üzere.
// Prototipteki glow_char ile AYNI formül (tools/proto_20261012/gen_matthew_simsek.py):
//  - gövde sarıyla AYDINLANIR (screen karışımı; koyu çizgiler daha az, yüz kaybolmasın),
//  - dış kontur: level %12'den sonra, koyu altından kreme açılır,
//  - level %70'ten sonra ikinci, nabızla yanıp sönen dış halka.
// Nabız kırılmaya yaklaştıkça hızlanır (periyot 1 sn -> 0,25 sn). level 0 iken sprite olduğu gibi çizilir.
uniform float level : hint_range(0.0, 1.0) = 0.0;

const vec3 GLOW = vec3(1.0, 0.8706, 0.3137);
const vec3 PAL1 = vec3(0.8, 0.5333, 0.0784);
const vec3 PAL2 = vec3(0.9804, 0.8157, 0.2039);
const vec3 PAL3 = vec3(1.0, 0.9412, 0.549);
const vec3 PAL4 = vec3(1.0, 1.0, 0.9098);

vec3 pal(int i) {
	if (i <= 1) { return PAL1; }
	if (i == 2) { return PAL2; }
	if (i == 3) { return PAL3; }
	return PAL4;
}

// Makro (işlev DEĞİL): TEXTURE yerleşiğini sampler2D parametresi olarak işleve geçirmek bazı sürücülerde/başsız modda
// "tex_builtin" derleyici hatası veriyor.
#define ALPHA_AT(uv) texture(TEXTURE, (uv)).a

// Godot 4'te fragment() başında COLOR = köşe rengi x DOKU rengi. Dış kontur pikselinde doku saydam olduğu için COLOR ile çarpmak
// konturu siler - bu yüzden köşe rengi (modulate: görünmezlik, ton) ayrı taşınır ve sonuç yalnız onunla çarpılır.
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (level > 0.02) {
		float period = 1.0 - 0.75 * level;
		float pulse = 0.5 + 0.5 * sin(TIME * 6.2831853 / period);
		vec2 px = TEXTURE_PIXEL_SIZE;
		if (c.a > 0.5) {
			float luma = dot(c.rgb, vec3(0.3, 0.59, 0.11));
			float t = level * (0.5 + 0.28 * pulse) * (0.55 + 0.45 * luma);
			c.rgb = 1.0 - (1.0 - c.rgb) * (1.0 - GLOW * t);
		} else {
			float n1 = max(max(ALPHA_AT(UV + vec2(px.x, 0.0)), ALPHA_AT(UV - vec2(px.x, 0.0))),
					max(ALPHA_AT(UV + vec2(0.0, px.y)), ALPHA_AT(UV - vec2(0.0, px.y))));
			if (n1 > 0.5) {
				if (level > 0.12) {
					c = vec4(pal(1 + min(3, int(level * 3.2 + 0.5 * pulse))), 1.0);
				}
			} else if (level > 0.7 && pulse > 0.45) {
				// ikinci halka: 2 piksel uzaktaki (4-komşuluğun iki kez genişletilmişi) gövde
				float n2 = 0.0;
				n2 = max(n2, ALPHA_AT(UV + vec2(2.0 * px.x, 0.0)));
				n2 = max(n2, ALPHA_AT(UV - vec2(2.0 * px.x, 0.0)));
				n2 = max(n2, ALPHA_AT(UV + vec2(0.0, 2.0 * px.y)));
				n2 = max(n2, ALPHA_AT(UV - vec2(0.0, 2.0 * px.y)));
				n2 = max(n2, ALPHA_AT(UV + px));
				n2 = max(n2, ALPHA_AT(UV - px));
				n2 = max(n2, ALPHA_AT(UV + vec2(px.x, -px.y)));
				n2 = max(n2, ALPHA_AT(UV + vec2(-px.x, px.y)));
				if (n2 > 0.5) {
					c = vec4(level < 0.9 ? PAL2 : PAL3, 1.0);
				}
			}
		}
	}
	COLOR = c * v_modulate;
}
