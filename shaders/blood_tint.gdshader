shader_type canvas_item;

// Yaratık kanı rengi (kullanıcı isteği 2026-09-27: "yaratıklara birşey isabet edince çıkan kanların rengi yaratığın rengiyle
// benzer olsun ... sadece renk değişikliğiyle ayarla, yeni kan efekti yapma"). fx_hit_blood_* dokuları 4 tonlu kırmızı piksel
// sanat (212,42,65 / 252,88,66 / 252,156,126 / 253,205,190). Her ton YEŞİL kanalından ayırt edilip hedef rengin aynı
// kademesine eşlenir - yine 4 düz ton, piksel yapısı aynı kalır.
// Hedef renk düğümün self_modulate'inden gelir (scripts/fx_hit_blood.gd, scripts/creature_blood.gd). self_modulate BEYAZ ise
// (yaratık bulunamadı) doku olduğu gibi (kırmızı) çizilir. modulate.a solmaları normal çalışır.

varying vec4 tint;

void vertex() {
	tint = COLOR; // vertex COLOR = modulate * self_modulate
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 c = tint.rgb;
	vec3 outc = tex.rgb;
	if (any(lessThan(c, vec3(0.995)))) {
		float g = tex.g;
		if (g < 0.25) {
			outc = c * 0.9;
		} else if (g < 0.47) {
			outc = mix(c, vec3(1.0), 0.22);
		} else if (g < 0.7) {
			outc = mix(c, vec3(1.0), 0.45);
		} else {
			outc = mix(c, vec3(1.0), 0.7);
		}
	}
	COLOR = vec4(outc, tex.a * tint.a);
}
