shader_type canvas_item;
// Önceden çarpılmış alfa: sprite NORMAL kaplanır, etrafındaki parıltı EKLENİR (tek geçiş, ikinci düğüm yok).
render_mode blend_premul_alpha;

// Sayfa tabanlı piksel efekte HAFİF PARILTI (2026-11-16, kullanıcı: "matthewin tüm yıldırım efektleri hafiften parıldasın ... ateş asasının
// ateşine uyguladığımız türden bir parıltı"): shaders/flame_bend.gdshader'daki Ateş Asası halesinin (madde 642) DÜZ SPRITE sürümü - aynı
// formül, aynı varsayılanlar. Hale = efektin kendi rengi, SANAT pikseli (doku pikseli) ızgarasında 2 ve 4 px halkada 16 örnek (piksel stili
// bozulmaz); opak piksellere hafif ışıma; yavaş nefes. Karanlıktaki gece ışığından (night_glow) ayrı: gündüz de görünür. glow = 0 eski görünüm.
// Malzemeyi veren TEK yer: scripts/fx_pixel_glow.gd material() (Matthew şimşek efektleri madde 723, Büyücü Arcane Patlama madde 739).
// cell_px: sayfanın tek karesinin boyu (doku pikseli). Sayfalar (0,0)'dan başlayan düzenli ızgara - komşu örnek BAŞKA kareye düşerse sayılmaz
// (AtlasTexture / region_rect bitişik karenin pikselini haleye sızdırmasın). Tek kareli doku için büyük bir değer bırak.

uniform float glow = 0.55;
uniform float glow_core = 0.22;   // opak efekt piksellerine eklenen ışıma payı
uniform float breath_speed = 5.0;
uniform vec2 cell_px = vec2(100000.0);
// Toplamalı çizilen sayfa (Büyücü Arcane Patlama; eskiden shaders/toplamali.gdshader blend_add): alfa 0 yazılır -> önceden çarpılmış
// karışımda renk zemine EKLENİR (blend_add ile aynı sonuç: zemin + renk x alfa), hale de üstüne eklenir.
uniform bool additive = false;

varying vec4 v_mod;

void vertex() {
	v_mod = COLOR; // modulate (fragment'taki COLOR doku rengiyle çarpılmış gelir)
}

void fragment() {
	vec4 f = texture(TEXTURE, UV) * v_mod;
	vec3 halo = vec3(0.0);
	if (glow > 0.0) {
		vec2 t = UV / TEXTURE_PIXEL_SIZE; // doku pikseli koordinatı (en yakın örnekleme: t + tam sayı = komşu piksel)
		vec2 cell = floor(t / cell_px);
		for (int k = 0; k < 8; k++) {
			float ang = float(k) * 0.785398;
			vec2 d = vec2(cos(ang), sin(ang));
			vec2 ta = t + floor(d * 2.0 + 0.5);
			vec2 tb = t + floor(d * 4.0 + 0.5);
			// başka kareye düşen komşu sayılmaz (0 ağırlık)
			float wa = all(equal(floor(ta / cell_px), cell)) ? 0.09 : 0.0;
			float wb = all(equal(floor(tb / cell_px), cell)) ? 0.035 : 0.0;
			vec4 a = texture(TEXTURE, ta * TEXTURE_PIXEL_SIZE);
			vec4 b = texture(TEXTURE, tb * TEXTURE_PIXEL_SIZE);
			// alfa KARESİ: opak çizgiler (şimşek) alevdeki gibi parlar, yarı saydam dolgular (kalkan patlamasının içi) sütümsü açılmaz
			halo += a.rgb * (a.a * a.a) * wa + b.rgb * (b.a * b.a) * wb;
		}
		float breath = 0.85 + 0.15 * sin(TIME * breath_speed);
		halo *= glow * breath * v_mod.rgb * v_mod.a;
	}
	COLOR = vec4(f.rgb * f.a + halo * (1.0 - f.a * (1.0 - glow_core)), additive ? 0.0 : f.a);
}
