// SU DALGACIKLARI - ortak kod (2026-11-16): scenes/su.gdshader (oyunun bütün suları) + shaders/kamp_su.gdshader (ana menü kamp sahnesinin
// nehri, kullanıcı: "ana menüdeki su shaderı normal ana haritadaki su shaderı gibi değil"). Önceden yalnız su.gdshader'ın içindeydi; menü aynı
// dalgacıkları birebir çizebilsin diye buraya taşındı - davranış DEĞİŞMEDİ (aynı uniform adları, aynı formül). Ayrıntılı açıklama su.gdshader başında.
// Dünya koordinatında, harita karolarının piksel ızgarasında (1 dünya birimi = 1 karo pikseli) çalışır.

uniform sampler2D su_mesafe : hint_default_white, filter_linear, repeat_disable; // R = kıyıya uzaklık / 64 dünya px (2 px/teksel)
uniform sampler2D su_akis : hint_default_black, filter_linear, repeat_disable; // RG = 0,5 + 0,5 akış, B = dalgacık doğabilir (4 px/teksel)
uniform vec2 doku_origin = vec2(-576.0, -384.0);
uniform vec2 doku_size = vec2(5248.0, 4864.0);
uniform bool dalgacik_acik = true;
uniform vec4 sirt_renk : source_color = vec4(0.6, 0.79, 0.9, 1.0);
uniform float sirt_guc = 0.6;
uniform vec2 hucre = vec2(26.0, 14.0);
uniform float yogunluk = 0.22;
uniform float omur_hiz = 0.2; // döngü/sn; döngünün %55'i görünür (~2,75 sn)
uniform float akis_hiz = 6.0; // kanal ortasında px/sn (piksel arama alanı 3x5 hücre: akis_hiz x ömür <= ~16 px)

vec2 doku_uv(vec2 px) {
	return (px + 0.5 - doku_origin) / doku_size;
}

// Dünya pikselinin kıyıya uzaklığı (dünya px); kıyı çizgisi ~0, kıyı sanatının altı < 0.
float kiyi(vec2 px) {
	return texture(su_mesafe, doku_uv(px)).r * 64.0 - 1.0;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + vec2(19.19, 7.73)));
}

// dx = sırt boyunca uzaklık (mutlak), dy = -1 tepe, 0 gövde, +1 kıvrık uç; gölge satırı yok.
bool sekil(float dx, float dy, float hw) {
	return (dy == -1.0 && dx <= hw - 3.0) || (dy == 0.0 && dx <= hw - 1.0) || (dy == 1.0 && dx == hw);
}

bool dalgacik(vec2 px, float t) {
	vec2 base = floor(px / hucre);
	for (int j = -2; j <= 2; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			float r = hash21(cell);
			if (r >= yogunluk) {
				continue;
			}
			float dongu = t * omur_hiz + r / yogunluk * 7.0;
			float phase = fract(dongu);
			if (phase >= 0.55) {
				continue;
			}
			float k = floor(dongu);
			vec2 h = hash22(cell + vec2(k * 3.17, k * 1.93));
			float r2 = hash21(cell + vec2(5.7 + k * 0.731, 13.1));
			float w = 3.0 + floor(r2 * 3.0); // yarı genişlik 3-5 (7-11 px)
			vec2 dogum = cell * hucre + floor(h * hucre);
			vec3 ak = texture(su_akis, doku_uv(dogum)).rgb;
			if (ak.b < 0.5) {
				continue; // kıyıya çok yakın / su dışı
			}
			vec2 f = ak.rg * 2.0 - 1.0;
			vec2 c = floor(dogum + f * akis_hiz * (phase / omur_hiz) + 0.5);
			float hw = floor(w * sin(phase / 0.55 * 3.14159) + 0.5);
			if (hw < 1.0) {
				continue;
			}
			vec2 dp = px - c;
			if (sekil(abs(dp.x), dp.y, hw)) {
				return true;
			}
		}
	}
	return false;
}
