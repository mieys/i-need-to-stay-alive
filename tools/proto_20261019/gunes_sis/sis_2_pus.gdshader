shader_type canvas_item;
render_mode unshaded;

// SİSLİ HAVA 2 - "ÖLÜ PUS" (madde 282 prototipi): sis oyuncudan uzaklaştıkça koyulaşır (yakın çevre net, uzak ağaçlar/evler
// soluk gri-yeşil perdeye gömülür; sınır düzensiz ve kıpırdar, halka çizmez), renkler belirgin solgun ve yeşilimsi, kenarlar
// kararır. Önde (kameraya yakın) ince sis telleri zeminden HIZLI kayar -> derinlik + "içinden geçiyorsun" hissi.
// En ürkütücü renk ayarı; görüş mekaniği DEĞİŞMEZ (sadece görsel).
#include "res://tools/proto_20261019/gunes_sis/gs_ortak.gdshaderinc"
#include "res://tools/proto_20261019/gunes_sis/sis_ortak.gdshaderinc"

uniform vec3 sis_gunduz : source_color = vec3(0.56, 0.63, 0.62);
uniform float uzak_yogunluk = 0.58;
uniform vec2 net_yaricap = vec2(170.0, 95.0);  // bu elipsin içi neredeyse net (dünya px)

void fragment() {
	vec2 px = gs_texel(SCREEN_UV);
	vec2 uv = gs_uv(px);
	vec3 base = texture(ekran, SCREEN_UV).rgb;
	vec3 col = sis_renk_ayari(base, 0.45, vec3(0.88, 0.97, 0.93), 0.88);
	// uzaklık sisi: düzensiz kenar (gürültüyle bozulmuş uzaklık), 4 düz kademe
	float d = length((px - oyuncu) / net_yaricap);
	// büyük, sürüklenen kümelerle bozulur (halka / hedef tahtası gibi okunmasın); oyuncunun dibi açık kalır
	float bozul = (yer_sisi(px, 0.0055) - 0.5) * 1.5 * smoothstep(0.3, 1.0, d);
	float uz = smoothstep(0.75, 2.1, d + bozul);
	float k = gs_kademe(uz, 4.0);
	vec3 sr = sis_rengi(sis_gunduz);
	col = mix(col, sr, k * uzak_yogunluk * sis_k);
	// ön sis telleri: paralaks -0,35 (zeminden hızlı), yatay uzun ince kütleler
	vec2 wp = gs_paralaks(px, -0.35);
	float tel = fbm(wp * vec2(0.0042, 0.013) + vec2(zaman * 0.035, 0.0));
	float tk = gs_kademe(smoothstep(0.58, 0.76, tel), 3.0);
	col = mix(col, sr * 1.08, tk * 0.22 * sis_k);
	col *= mix(1.0, vinyet(uv, 0.3), sis_k);
	COLOR = vec4(col, 1.0);
}
