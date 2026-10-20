shader_type canvas_item;

// Ana menü "Ocak Başı" sahnesinin IŞIĞI (2026-10-20, kullanıcı: "ana menüdeki ışıklandırmanın pixel pixel olmasını istemiyorum").
// Eskiden gen_ana_menu_bg.py lit_pass 480x270 tuvale Bayer titreşimli 7 basamak pişiriyordu (x4 ölçekte 4 px'lik dama deseni).
// Şimdi doku IŞIKSIZ taban (assets/ui/ana_menu/ocak_basi.png), ışık burada EKRAN pikselinde sürekli: formül lit_pass'in basamaksız hâli
// (renk = taban * min(ortam + havuzlar, tavan) * (1 - kenar karartması)). Konumlar tuval pikselinde, gen_ana_menu_bg.py bg_c ile AYNI.
// Kullanan: main_menu.gd scene_background() (ana menü + menu_hearth_bg.gd).

uniform sampler2D lamp_tex : filter_nearest; // ocak_lamba.png: ayaklı lamba, ışıktan etkilenmez (en üstte)

const vec2 ART = vec2(480.0, 270.0);
const vec3 AMBIENT = vec3(0.30, 0.27, 0.36);
const vec3 LIGHT_CAP = vec3(1.35, 1.3, 1.3);
const float VIG = 0.35;

// (merkez, yarıçap, renk, şiddet, dikey basıklık) - lit_pass ile aynı düşüş: (1 - d)^1.7 * şiddet, 1'de kesilir.
vec3 pool(vec2 p, vec2 c, float rad, vec3 col, float inten, float squash) {
	vec2 d = vec2(p.x - c.x, (p.y - c.y) / squash);
	float k = clamp(pow(max(1.0 - length(d) / rad, 0.0), 1.7) * inten, 0.0, 1.0);
	return col * k;
}

void fragment() {
	vec4 base = COLOR;
	vec2 p = UV * ART - 0.5; // tuval pikseli (lit_pass piksel köşesinde örnekler)
	vec3 l = AMBIENT
		+ pool(p, vec2(324.0, 116.0), 190.0, vec3(1.0, 0.66, 0.36), 1.15, 0.72) // şömine alevi
		+ pool(p, vec2(202.0, 177.0), 70.0, vec3(1.0, 0.72, 0.42), 0.9, 0.85); // lamba başı
	l = min(l, LIGHT_CAP);
	vec2 v2 = (p / ART - 0.5) * 2.0;
	float v = max(0.0, v2.x * v2.x * 0.35 + v2.y * v2.y * 0.45 - 0.2) * VIG;
	vec3 c = base.rgb * l * (1.0 - v);
	// Lamba başının parıltısı (eklenen ışık): lamba sprite'ının kendi basamaklı halesi üreticide silindi (strip_glow), yerine bu.
	vec2 h = vec2(p.x - 199.0, (p.y - 177.0) / 1.05);
	c += vec3(1.0, 0.85, 0.5) * pow(max(1.0 - length(h) / 13.0, 0.0), 1.6) * 0.42;
	c = min(c, vec3(1.0));
	vec4 lamp = texture(lamp_tex, UV);
	COLOR = vec4(mix(c, lamp.rgb, lamp.a), base.a);
}
