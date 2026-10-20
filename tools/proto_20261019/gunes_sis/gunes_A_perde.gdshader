shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// GÜN IŞIĞI A - "IŞIK PERDESİ" (madde 282 prototipi): az sayıda GENİŞ, temiz kenarlı ışık perdesi (sağ üstten sol alta),
// 3 düz kademe (çekirdek / gövde / hale), her perde kendi ritminde yavaşça nefes alır ve boyu boyunca söner. Perdelerin
// İÇİNDE yüzen toz zerreleri ışığa girince parlar (perde dışında görünmez). Paralaks 0,55 (yürüdükçe zeminden yavaş kayar).
// Ekranı OKUMAZ: çıktı = sahne + ışık.
#include "res://tools/proto_20261019/gunes_sis/gs_ortak.gdshaderinc"

uniform float guc = 0.2;
uniform vec3 renk : source_color = vec3(1.0, 0.88, 0.6);
uniform vec2 isik_yonu = vec2(-0.5, 0.866);
uniform float aralik = 95.0;       // perdeler arası tipik uzaklık (dünya px)
uniform float paralaks = 0.55;
uniform float zerre_guc = 0.5;

float perde(vec2 sp) {
	vec2 dir = normalize(isik_yonu);
	vec2 perp = vec2(-dir.y, dir.x);
	float u = dot(sp, perp) / aralik;
	float v = dot(sp, dir);
	float i = floor(u);
	float f = fract(u);
	float toplam = 0.0;
	for (int j = -1; j <= 1; j++) {
		float id = i + float(j);
		if (hash12(vec2(id, 7.3)) > 0.72) {
			continue;
		}
		float merkez = 0.2 + 0.6 * hash12(vec2(id, 1.7));
		float yari = 0.11 + 0.12 * hash12(vec2(id, 3.1));
		float d = abs(f - float(j) - merkez) / yari;
		float prof = 1.0 - smoothstep(0.0, 1.0, d);
		// boyu boyunca: uzun yumuşak parçalar (sonsuz şerit olmasın)
		prof *= smoothstep(0.32, 0.68, vnoise(vec2(id * 3.7, v / 560.0 + zaman * 0.012)));
		// nefes: her perde kendi fazında
		prof *= 0.72 + 0.28 * sin(zaman * 0.33 + hash12(vec2(id, 9.0)) * 6.283);
		toplam = max(toplam, prof);
	}
	return toplam;
}

// Toz zerresi: zemine yakın havada, ışık yönünde çok yavaş süzülür; 1 texel, göz kırpar.
float zerre(vec2 px) {
	vec2 mp = px + vec2(4.0, -7.0) * zaman;
	vec2 cell = floor(mp / 22.0);
	float h = hash12(cell + 31.0);
	if (h > 0.4) {
		return 0.0;
	}
	vec2 c = (cell + 0.2 + 0.6 * hash22(cell)) * 22.0;
	c += vec2(sin(zaman * 0.7 + h * 40.0), cos(zaman * 0.5 + h * 23.0)) * 3.0;
	if (any(notEqual(floor(mp), floor(c)))) {
		return 0.0;
	}
	return 0.5 + 0.5 * sin(zaman * 2.2 + h * 61.0);
}

void fragment() {
	vec2 px = gs_texel(SCREEN_UV);
	vec2 uv = gs_uv(px);
	float p = perde(gs_paralaks(px, paralaks));
	float egim = mix(0.6, 1.0, clamp(uv.x * 0.7 + (1.0 - uv.y) * 0.5, 0.0, 1.0));
	float lv = p * egim;
	float k = lv > 0.55 ? 1.0 : (lv > 0.3 ? 0.66 : (lv > 0.1 ? 0.33 : 0.0));   // hale / gövde / çekirdek
	float isik = k * guc;
	float z = zerre(px);
	if (k > 0.0) {
		isik += z * zerre_guc * (0.4 + 0.6 * k);
	}
	COLOR = vec4(renk * isik, 0.0);
}
