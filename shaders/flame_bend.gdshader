shader_type canvas_item;
// Önceden çarpılmış alfa: alev NORMAL kaplanır, etrafındaki parıltı EKLENİR (tek geçiş, ikinci düğüm yok).
render_mode blend_premul_alpha;

// Ateş Asası alevinin BÜKÜLMESİ (madde 640): alevin ağızdan x uzaklıktaki parçası theta(x) kadar dönük çizilir (uç geride kalıp kavis çizer).
// Hesap scripts/weapon_traits/flame_bend.gd unbend() ile AYNI (hasar alanı da onu kullanır). Dörtlü ağız merkezli, alevin dönebileceği
// her yeri kapsayan kare; her çıktı SANAT pikseli tek kaynak pikseli örnekler (piksel ızgarası bozulmaz). Kaynak = o anki animasyon
// karesi (fx_enchant_sprite her karede region'ı yazar).

uniform sampler2D sheet : filter_nearest;
uniform vec4 region;      // karenin sayfadaki yeri (px)
uniform vec2 sheet_size;
uniform vec2 nozzle;      // ağzın karedeki yeri (px)
uniform vec2 quad_px;     // dörtlünün boyu (sanat px)
uniform float flen = 177.0;
uniform float flip_y = 1.0; // sola bakarken -1 (bulut yine yukarıda)
uniform float bend[16];
// PARILTI (2026-11-13, kullanıcı: "ateş asasının ateş efekti hafif parıltılı gözüksün, çok çiğ"): alevin kendi renginden SANAT pikseli
// ızgarasında yumuşak hale (2 ve 4 px halkada 16 örnek), çekirdekte hafif ışıma, yavaş nefes. 0 = eski çiğ görünüm.
uniform float glow = 0.55;
uniform float glow_core = 0.22;   // opak alev piksellerine eklenen ışıma payı
uniform float breath_speed = 5.0;

vec4 src_px(vec2 s) {
	if (s.x < 0.0 || s.y < 0.0 || s.x >= region.z || s.y >= region.w) {
		return vec4(0.0);
	}
	return texture(sheet, (region.xy + s) / sheet_size);
}

float theta(float x) {
	float f = clamp(x / flen, 0.0, 1.0) * 15.0;
	int i = int(floor(f));
	int j = min(i + 1, 15);
	return mix(bend[i], bend[j], f - float(i));
}

void fragment() {
	vec2 p = floor((UV - 0.5) * quad_px) + 0.5;
	vec2 q = p;
	float x = length(p);
	for (int k = 0; k < 3; k++) {
		float a = -theta(x);
		float c = cos(a);
		float s = sin(a);
		q = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
		x = max(q.x, 0.0);
	}
	vec2 src = floor(nozzle + vec2(q.x, q.y * flip_y)) + 0.5;
	if (src.x < -5.0 || src.y < -5.0 || src.x >= region.z + 5.0 || src.y >= region.w + 5.0) {
		COLOR = vec4(0.0);
	} else {
		vec4 mod_col = COLOR;
		vec4 f = src_px(src) * mod_col;
		vec3 halo = vec3(0.0);
		if (glow > 0.0) {
			for (int k = 0; k < 8; k++) {
				float ang = float(k) * 0.785398;
				vec2 d = vec2(cos(ang), sin(ang));
				vec4 a = src_px(src + floor(d * 2.0 + 0.5));
				vec4 b = src_px(src + floor(d * 4.0 + 0.5));
				halo += a.rgb * a.a * 0.09 + b.rgb * b.a * 0.035;
			}
			float breath = 0.85 + 0.15 * sin(TIME * breath_speed);
			halo *= glow * breath * mod_col.rgb * mod_col.a;
		}
		COLOR = vec4(f.rgb * f.a + halo * (1.0 - f.a * (1.0 - glow_core)), f.a);
	}
}
