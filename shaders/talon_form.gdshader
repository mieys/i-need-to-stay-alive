shader_type canvas_item;

// Talon Ayna Formu (R) karakter boyaması (kullanıcı 2026-10-12: "ultisinde kırmızı-siyah bir forma geçip gözleri beyaz parıldayacak",
// prototip A · Kızıl seçildi - tools/proto_20261012/gen_talon_form_zincir.py form_char ile AYNI kural):
//  - gövde: piksel parlaklığı -> siyahtan kızıla 5 duraklı rampa (saç/gölgeler siyah, ten ve açık yerler kızıl)
//  - gözler: göz akı rengi (255,240,247) Talon sayfalarında SADECE gözde geçer -> renk anahtarı; ona yatayda komşu koyu piksel göz bebeği.
//    İkisi de bembeyaz, 4 komşusu kızıl hale, 1,3 sn'de bir kısa "+" çakması
//  - gövdenin dışında 1 piksel kızıl ışıma (kareler 48x48, kenarları boş - komşu kareye sızmaz; tek istisna kullanılmayan "strike")
// scripts/fx_talon_form.gd karakterin AnimatedSprite2D'sine takar (yerel oyuncu + uzak kukla AYNI sahne); amount ile açılır/kapanır.
// Düğümün modulate'i (saydamlık, hasar tonu...) korunur: vertex COLOR = modulate * self_modulate.

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0; // dönüşüm anı: beyaz siluet

const vec3 EYE = vec3(1.0, 0.9412, 0.9686);
const vec3 HALO = vec3(1.0, 0.502, 0.4706);
const vec3 GLOW = vec3(1.0, 0.2196, 0.1882);
const vec3 FLASH = vec3(1.0, 0.925, 0.91);

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 ramp(float t) {
	const vec3 c0 = vec3(0.0549, 0.0157, 0.0314);
	const vec3 c1 = vec3(0.2745, 0.0314, 0.0627);
	const vec3 c2 = vec3(0.5333, 0.0549, 0.0863);
	const vec3 c3 = vec3(0.7451, 0.102, 0.1176);
	const vec3 c4 = vec3(0.8392, 0.1412, 0.149);
	if (t < 0.25) {
		return mix(c0, c1, t / 0.25);
	} else if (t < 0.5) {
		return mix(c1, c2, (t - 0.25) / 0.25);
	} else if (t < 0.75) {
		return mix(c2, c3, (t - 0.5) / 0.25);
	}
	return mix(c3, c4, (t - 0.75) / 0.25);
}

bool eye_white(vec4 c) {
	return c.a > 0.5 && distance(c.rgb, EYE) < 0.03;
}

// Piksel göz mü: göz akı ya da ona yatayda komşu koyu göz bebeği (c = pikselin kendisi, l/r = yatay komşuları)
bool eye_pixel(vec4 c, vec4 l, vec4 r) {
	if (c.a < 0.5) {
		return false;
	}
	if (distance(c.rgb, EYE) < 0.03) {
		return true;
	}
	if (lum(c.rgb) >= 0.2) {
		return false;
	}
	return eye_white(l) || eye_white(r);
}

// Makro (işlev DEĞİL): TEXTURE yerleşiğini sampler2D parametresi olarak işleve geçirmek "tex_builtin" derleyici hatası veriyordu.
#define IS_EYE(uv) eye_pixel(texture(TEXTURE, (uv)), texture(TEXTURE, (uv) - vec2(px.x, 0.0)), texture(TEXTURE, (uv) + vec2(px.x, 0.0)))

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 tex = texture(TEXTURE, UV);
	float pulse = 0.5 + 0.5 * sin(TIME * 5.0);
	float gk = mod(TIME, 1.3) / 0.16;
	float glint = (gk < 1.0 ? sin(gk * PI) : 0.0) * step(0.999, amount);
	bool eye_h = IS_EYE(UV + vec2(px.x, 0.0)) || IS_EYE(UV - vec2(px.x, 0.0));
	bool eye_v = IS_EYE(UV + vec2(0.0, px.y)) || IS_EYE(UV - vec2(0.0, px.y));
	vec4 outc;
	if (tex.a > 0.01) {
		float t = pow(clamp((lum(tex.rgb) - 0.04) / 0.66, 0.0, 1.0), 0.75);
		vec3 c = ramp(t);
		if (IS_EYE(UV)) {
			c = vec3(1.0);
		} else if (eye_h || eye_v) {
			c = mix(c, HALO, 0.42 * (0.7 + 0.3 * pulse));
			c = eye_h ? mix(c, vec3(1.0), glint) : mix(c, vec3(1.0, 0.839, 0.824), 0.6 * glint);
		}
		c = mix(tex.rgb, c, amount);
		outc = vec4(mix(c, FLASH, flash), tex.a);
	} else {
		float near = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
				max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
		float ga = step(0.5, near) * 0.588 * amount * (0.6 + 0.4 * pulse);
		outc = vec4(GLOW, ga);
		if (eye_h) { // göz çakması gövdenin dışına taşarsa (yandan bakış)
			outc = vec4(mix(GLOW, vec3(1.0), glint), max(ga, glint));
		}
	}
	COLOR = outc * modulate;
}
