shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// GÜN IŞIĞI B - "AĞAÇ ARASI HUZME" (madde 282 prototipi): huzmeler HER YERDE değil, ağaçların / orman parçalarının
// yanında - güneş sağ üstte, ışık ağaç taçlarının arasından süzülüp sol alta doğru ince demetler halinde düşer. Huzmeler
// dünyaya (ağaca) bağlı, yapraklar kıpırdadıkça demetler yavaşça açılıp kapanır. Açık çayırda huzme yok, sadece çok hafif
// sıcak ton. Ağaç maskesi: gunes_sis_capture.gd "Ağaç 0-2" + orman katmanlarının dolu hücrelerinden üretir (1 piksel = 1 hücre).
#include "res://tools/proto_20261019/gunes_sis/gs_ortak.gdshaderinc"

uniform sampler2D agac_maske : filter_linear, repeat_disable;
uniform vec2 maske_koken = vec2(0.0);   // maskenin (0,0) pikselinin sol üst köşesi (dünya px)
uniform vec2 maske_boyut = vec2(1.0);   // maske boyutu (piksel = hücre)
uniform float hucre = 16.0;

uniform float guc = 0.26;
uniform vec3 renk : source_color = vec3(1.0, 0.9, 0.62);
uniform vec2 isik_yonu = vec2(-0.5, 0.866);
uniform float demet_araligi = 30.0;     // demetlere dik ölçek (dünya px)
uniform float menzil = 88.0;            // ağaçtan ne kadar uzağa düşer
uniform float sicaklik = 0.025;

float tac(vec2 p) {
	return texture(agac_maske, (p - maske_koken) / (hucre * maske_boyut)).r;
}

void fragment() {
	vec2 px = gs_texel(SCREEN_UV);
	vec2 dir = normalize(isik_yonu);
	vec2 perp = vec2(-dir.y, dir.x);
	// Güneşe doğru (sağ üst) yürüyüp ağaç tacı ara: yakın tac = güçlü demet, uzak = sönük.
	float kaynak = 0.0;
	for (int k = 1; k <= 8; k++) {
		float d = float(k) * menzil / 8.0;
		float w = 1.0 - float(k - 1) / 8.0;
		kaynak = max(kaynak, tac(px - dir * d) * w);
	}
	float burada = tac(px);
	// Demetler: dik eksende ince bantlar, boyunca çok yavaş değişir; yapraklar kıpırdadıkça açılıp kapanır.
	float u = dot(px, perp) / demet_araligi;
	float v = dot(px, dir);
	float n = vnoise(vec2(u, v / 140.0 + zaman * 0.05)) * 0.75 + vnoise(vec2(u * 0.37 + 4.0, zaman * 0.09)) * 0.25;
	float demet = smoothstep(0.45, 0.8, n);
	// Ağaç tacının tam üstünde demet sönük (ışık tacın arasından ÇIKAR), taçtan uzaklaştıkça sönümlenir.
	float isik = demet * kaynak * (1.0 - burada * 0.65);
	float k3 = isik > 0.4 ? 1.0 : (isik > 0.2 ? 0.6 : (isik > 0.06 ? 0.3 : 0.0));
	float sicak = sicaklik * (1.0 - burada * 0.5);
	COLOR = vec4(renk * (k3 * guc + sicak), 0.0);
}
