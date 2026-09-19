shader_type canvas_item;

// LoL tarzı "savaş sisi" çizim geçişi (bkz. scripts/vision_fog.gd).
//
// Tüm ekranı kaplayan ColorRect bu shader'ı kullanır. Sisin NEREDE olduğunu
// kendisi hesaplamaz: vision_fog_mask.gdshader'ın bir SubViewport'ta her karede
// güncellediği "görünürlük maskesini" (fog_mask: 1 = görünür, 0 = sisli) okur.
// Maske kare kare yumuşakça değiştiği için görüş alanı sert bir spot ışığı gibi
// karaktere kilitli durmaz; girilen yer yavaşça açılır, terk edilen yer yavaşça
// kararır.
//
// Sis, ekranın üstüne düz siyah bir alfa katmanı bindirmek yerine SAHNENİN
// KENDİSİNİ (hint_screen_texture) koyulaştırıp biraz renksizleştirip soğuk bir
// tona çeker - LoL'deki sis de böyle: arazi hâlâ seçilir ama donuk ve karanlık.
// Bu shader HUD'dan ÖNCE çizilir (bkz. main.gd), yani HUD'u etkilemez.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
// Maske düşük çözünürlüklü (ekranın 1/4'ü); bilinear filtre onu pürüzsüzce büyütür.
uniform sampler2D fog_mask : filter_linear;

// Sis platosunun rengi: sahne bu tona doğru fog_darkness kadar karıştırılır.
uniform vec4 fog_tint : source_color = vec4(0.04, 0.07, 0.16, 1.0);
// 0 = sis yok, 1 = tamamen fog_tint (arazi hiç seçilmez).
uniform float fog_darkness : hint_range(0.0, 1.0) = 0.70;
// Sisteki arazinin renk doygunluğunu ne kadar azaltacağı (0 = aynen, 1 = gri).
uniform float fog_desaturation : hint_range(0.0, 1.0) = 0.35;
// Maskeyi okurken uygulanan yumuşatmanın UV yarıçapı (bkz. vision_fog.gd MASK_BLUR_WORLD,
// dünya biriminden zoom/ekran boyuyla çevrilir). 0 = yumuşatma yok. Görüşü kesen
// duvarların gölge kenarları hücre-hücre/ikili (var-yok) hesaplandığı için ham hâlleriyle
// merdiven basamaklı ve sert çıkıyor (kullanıcı bildirimi: "çok keskin çizgiler,
// anormal gözüküyor"); bu geçiş onları yumuşak bir penumbraya çevirir. Stateless
// (geri beslemesiz): sadece okuma anında, maskenin kendisine yazılmaz.
uniform vec2 mask_blur_uv = vec2(0.0);

const int BLUR_TAPS = 16;
// Altın açı (radyan) - örnekleri disk üzerinde eşit dağıtan spiral.
const float GOLDEN_ANGLE = 2.39996323;

float blurred_visibility(vec2 uv) {
	float sum = texture(fog_mask, uv).r;
	for (int i = 0; i < BLUR_TAPS; i++) {
		float radius = sqrt((float(i) + 0.5) / float(BLUR_TAPS));
		float angle = float(i) * GOLDEN_ANGLE;
		vec2 offset = vec2(cos(angle), sin(angle)) * radius * mask_blur_uv;
		sum += texture(fog_mask, uv + offset).r;
	}
	return sum / float(BLUR_TAPS + 1);
}

void fragment() {
	float fog = 1.0 - (mask_blur_uv.x > 0.0 ? blurred_visibility(UV) : texture(fog_mask, UV).r);

	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(scene, vec3(0.299, 0.587, 0.114));
	vec3 fogged = mix(mix(scene, vec3(luma), fog_desaturation), fog_tint.rgb, fog_darkness);
	COLOR = vec4(mix(scene, fogged, fog), 1.0);
}
