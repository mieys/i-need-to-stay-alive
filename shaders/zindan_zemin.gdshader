shader_type canvas_item;
// ZİNDAN ZEMİNİ "C - Döşeme Taşları" (madde 449, 4 prototipten seçildi): düzensiz taş derzleri (Voronoi, dünya pikselinde) + taş başına ton +
// duvar dibinde ince gölge (kuzeydeki duvar uzun, yanlar kısa, güney çok kısa). Zemin katmanlarına (Zemin / Zemin ayrıntı / Zemin desen /
// Zemin süsü) materyal: scripts/dungeon/dungeon_floor.gd takar. zemin_maske: hücre başına 1 piksel, R = duvar, G = su (DungeonData.cells).
// Taş derzi YALNIZ KUM rengindeki piksellere (kum_renk: zemin, kıyı karosunun zemin kısmı, kürsü üstü); kenar
// çizgileri, taş yüzler, çatlak süsleri dokunulmaz. (Önce hücre başına "döşeli" maskesi vardı: levhanın çevresinde taşsız kum şeridi kalıp
// desen aniden değişiyordu - kullanıcı: "geçiş uyumsuz görünüyor".) Gri levha + "Kesme Taş" deseni haritadan kaldırıldı (kullanıcı: "bazı
// yerlerde çok absürt"), plaka döşeme de; zemin her yerde bu taş derzi. Dither YOK. tas_acik = Grafik > Zemin ayrıntısı (kapalıyken yalnız duvar gölgesi kalır).
uniform sampler2D zemin_maske : filter_nearest, repeat_disable;
uniform vec2 harita_origin = vec2(0.0);
uniform vec2 harita_hucre = vec2(214.0, 214.0);
uniform bool tas_acik = true;
uniform vec3 kum_renk = vec3(0.4, 0.368627, 0.333333); // taş derzi çizilen kum rengi; varsayılan Dungeon3 (102,94,85), profil "zemin_rengi"
uniform float tas_olcek = 21.0; // döşeme taşı ortalama boyu (dünya px)
uniform float derz_guc = 0.16;
uniform float tas_ton = 0.05;
uniform float golge_guc = 0.18; // 1. bant karartma (2. bant yarısı)
uniform float golge_bant1 = 5.0; // dünya px (kuzey duvarı ağırlığı 1: yüzün dibinde)
uniform float golge_bant2 = 8.0;
varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + vec2(17.13, 3.71)));
}

vec2 maske(vec2 c) {
	if (c.x < 0.0 || c.y < 0.0 || c.x >= harita_hucre.x || c.y >= harita_hucre.y) {
		return vec2(1.0, 0.0);
	}
	return texelFetch(zemin_maske, ivec2(c), 0).rg;
}

// komşu duvara/suya uzaklık (dünya px), yöne göre ağırlıklı: kuzeydeki duvar (yüz) uzun gölge, yanlar kısa, güney çok kısa
float yakinlik(vec2 px, int kanal, float w_kuzey, float w_yan, float w_guney) {
	vec2 rel = px - harita_origin;
	vec2 c = floor(rel / 16.0);
	vec2 l = rel - c * 16.0;
	float best = 999.0;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			if (dx == 0 && dy == 0) {
				continue;
			}
			vec2 m = maske(c + vec2(float(dx), float(dy)));
			float v = kanal == 0 ? m.r : m.g;
			if (v < 0.5) {
				continue;
			}
			float ddx = dx < 0 ? l.x : (dx > 0 ? 16.0 - l.x : 0.0);
			float ddy = dy < 0 ? l.y : (dy > 0 ? 16.0 - l.y : 0.0);
			float d = (dx != 0 && dy != 0) ? length(vec2(ddx, ddy)) : max(ddx, ddy);
			float w = dy < 0 ? w_kuzey : (dy == 0 ? w_yan : w_guney);
			best = min(best, d / max(w, 0.001));
		}
	}
	return best;
}

void fragment() {
	vec4 t = COLOR; // Godot 4: COLOR zaten doku x köşe rengi
	vec2 px = floor(world_pos) + 0.5;
	vec3 k = vec3(1.0);
	if (tas_acik && distance(t.rgb, kum_renk) < 0.02) {
		vec2 q = px / tas_olcek;
		vec2 qi = floor(q);
		float f1 = 99.0;
		float f2 = 99.0;
		vec2 id = vec2(0.0);
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 o = qi + vec2(float(x), float(y));
				vec2 p = (o + 0.15 + 0.7 * hash22(o)) * tas_olcek;
				float d = length(px - p);
				if (d < f1) {
					f2 = f1;
					f1 = d;
					id = o;
				} else if (d < f2) {
					f2 = d;
				}
			}
		}
		k *= 1.0 + (hash21(id + 3.1) - 0.5) * 2.0 * tas_ton;
		k *= (f2 - f1) < 1.2 ? 1.0 - derz_guc : 1.0;
	}
	float g = yakinlik(px, 0, 1.0, 0.55, 0.25);
	k *= g < golge_bant1 ? 1.0 - golge_guc : (g < golge_bant2 ? 1.0 - golge_guc * 0.5 : 1.0);
	t.rgb *= k;
	COLOR = t;
}
