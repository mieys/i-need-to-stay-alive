shader_type canvas_item;

// Talon Ayna Formu (R) silah boyaması (kullanıcı 2026-10-12: "silahlar da kırmızı beyaz görünecek kendisi gibi", prototip A):
// piksel parlaklığı -> koyu kızıl / kırmızı / açık kırmızı / beyaz rampası (tools/proto_20261012/gen_talon_form_zincir.py form_weapon ile
// AYNI duraklar). Parlak yerler (kılıç ağzı, namlu parlaması) beyaza döner, gerisi kırmızı kalır.
// scripts/fx_talon_form.gd form sürerken silah ikonlarına takar (yetkili silahlar + uzak kukladaki ikonlar; kopyalar dahil).
// Düğümün modulate'i (Kan Aynası kopya tonu, saydamlık...) korunur: vertex COLOR = modulate * self_modulate.

uniform float amount : hint_range(0.0, 1.0) = 1.0;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

vec3 ramp(float t) {
	const vec3 c0 = vec3(0.2745, 0.0235, 0.0549);
	const vec3 c1 = vec3(0.6902, 0.0627, 0.102);
	const vec3 c2 = vec3(0.9333, 0.1804, 0.1804);
	const vec3 c3 = vec3(1.0, 0.6588, 0.6196);
	if (t < 0.3) {
		return mix(c0, c1, t / 0.3);
	} else if (t < 0.55) {
		return mix(c1, c2, (t - 0.3) / 0.25);
	} else if (t < 0.78) {
		return mix(c2, c3, (t - 0.55) / 0.23);
	}
	return mix(c3, vec3(1.0), (t - 0.78) / 0.22);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float t = clamp((dot(tex.rgb, vec3(0.299, 0.587, 0.114)) - 0.05) / 0.85, 0.0, 1.0);
	COLOR = vec4(mix(tex.rgb, ramp(t), amount), tex.a) * modulate;
}
