shader_type canvas_item;

// Buz donma efektinin DİBİ (madde 544, kullanıcı: "buzların dibi aniden kesik bir şekilde başladığı için hiç doğal
// durmuyor"): buz sayfasının alt satırları tam genişlikte dolu, yere düz bir çizgiyle oturuyordu. Burada dip sütun
// sütun düzensiz kırılır (kenar sütunlar biraz daha - yuvarlak taban) ve kalan alt satırlar sanat pikseli
// basamaklarıyla söner. Dither YOK; kırılma her karede aynı (sütun + varyasyon tohumu), oluşum karelerinde titremez.
// UV = atlas koordinatı (AtlasTexture): fx_freeze_variants.png tek satır, 27 kare x 16x32.

uniform float frame_w = 16.0;
uniform float atlas_w = 432.0;
uniform float atlas_h = 32.0;
uniform float frames_per_variant = 9.0;
uniform float fade_px = 4.0;  // basamaklı solmanın yüksekliği (sanat pikseli)
uniform float jag_px = 2.0;   // sütun başına rastgele kırılma (0..jag_px)
uniform float round_px = 3.0; // kenar sütunlara ek kırılma

float hash1(float n) {
	// tam sayı girdili hash (sin-hash kafes çizgisinde sıçrıyordu, madde 362)
	n = fract(n * 0.1031);
	n *= n + 33.33;
	n *= n + n;
	return fract(n);
}

void fragment() {
	float col = floor(UV.x * atlas_w);
	float lx = mod(col, frame_w);
	float variant = floor(col / (frame_w * frames_per_variant));
	float d = atlas_h - 1.0 - floor(UV.y * atlas_h); // 0 = en alt satır
	float half_w = (frame_w - 1.0) * 0.5;
	float edge = abs(lx - half_w) / half_w; // 0 orta, 1 kenar
	float cut = floor(hash1(lx + 17.0 * variant + 3.0) * (jag_px + 1.0)) + floor(edge * edge * round_px + 0.5);
	float a = d < cut ? 0.0 : clamp((d - cut + 1.0) / (fade_px + 1.0), 0.0, 1.0);
	COLOR.a *= a; // COLOR zaten doku x modulate (Godot 4); yeniden örnekleme kareli renk verir
}
