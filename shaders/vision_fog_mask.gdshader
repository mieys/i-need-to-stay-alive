shader_type canvas_item;

// LoL tarzı savaş sisinin "görünürlük maskesi" güncelleme geçişi (bkz.
// scripts/vision_fog.gd). Bir SubViewport içinde, ekranı kaplayan bir ColorRect
// tarafından çizilir; render_target_clear_mode = NEVER olduğu için önceki karenin
// içeriği hafızada kalır ve BU shader onu her karede biraz günceller.
//
// Her piksel (= ekrandaki bir dünya noktası) için tek bir sayı tutulur:
//   0 = tamamen sisli, 1 = tamamen görünür.
// Bu sayı HER KARE anlık HEDEFE (görüş elipsi: içi 1, dışı 0, kenarda yumuşak)
// doğru sınırlı bir hızla yaklaşır:
//   - hedef büyükse (görüş alanına GİRDİ)  -> up_step kadar artar  = yavaşça AÇILIR
//   - hedef küçükse (görüş alanından ÇIKTI) -> down_step kadar azalır = yavaşça SÖNER
// Böylece görüş alanı karaktere kilitli sert bir spot ışığı gibi durmaz: ilerlerken
// önündeki yer kademeli açılır, arkanda bıraktığın yer kademeli kararır (LoL gibi).
//
// Görüşü kesen duvarlar (orman/uçurum katmanı, bkz. scripts/vision_occluders.gd):
// bir duvarın ARKASI, görüş elipsinin dışıyla AYNI sayılır (hedef 0 = normal sis:
// soluk arazi, düşman gizli) - ayrıca kapkara yapılmaz (kullanıcı isteği: "direkt
// kapkara yapma, görünmeyen yerler görüş alanının dışındakiyle aynı olsun").
// occluders texture'ında 1 texel = 1 harita karosu. Her kaynaktan piksele karo karo
// (DDA) bir ışın yürütülür; ışın bir duvara GİRİP sonra duvarsız bir karoya ÇIKARSA
// piksel duvarın arkasındadır. Duvarın kendisi (ışın hiç çıkmıyorsa) görünür kalır.
// CPU'daki eşi: vision_occluders.gd is_ray_blocked() - ikisi AYNI kuralı uygular.
//
// Maske ekran uzayında tutulur; kamera hareket edince içerik shift_uv kadar
// kaydırılarak okunur (dünya noktası ekranda kayar, maske onunla birlikte kayar).

uniform sampler2D history : hint_screen_texture, filter_linear;

// NetworkManager.MAX_PLAYERS (8) ile aynı - vision_fog.gd MAX_SOURCES da eşleşmeli.
uniform vec2 sources[8];
uniform int source_count = 0;

// Görüş elipsinin UV uzayındaki yarı-eksenleri (bkz. vision_fog.gd
// _update_half_extent). Maske ekranla AYNI en-boy oranında olduğu için UV uzayı
// ekranınkiyle aynıdır.
uniform vec2 half_extent = vec2(0.3, 0.4);

// Elips kenarındaki geçiş bandı (yarıçapın oranı; band sınırın iki yanına eşit).
uniform float edge_softness : hint_range(0.0, 1.0) = 0.2;

// Bir önceki karenin içeriği bu karede ekranda ne kadar kaymış: geçmişi
// UV + shift_uv konumundan okuruz (bkz. vision_fog.gd).
uniform vec2 shift_uv = vec2(0.0);
// 0 = geçmişi tamamen unut (ilk kare, ışınlanma, ev çıkışı): maske karanlıktan
// başlayıp yavaşça açılır. 1 = normal.
uniform float history_keep : hint_range(0.0, 1.0) = 1.0;

// Bu karedeki en büyük artış/azalış (= delta / açılma süresi, delta / sönme süresi).
uniform float up_step = 0.03;
uniform float down_step = 0.02;

// --- Görüşü kesen duvarlar (bkz. dosya başı) ---------------------------------------
// R8, 1 texel = 1 karo, 255 = engel. Izgaranın sol-üst karosu occluder_grid_origin.
uniform sampler2D occluders : filter_nearest, repeat_disable;
uniform bool occluder_enabled = false;
uniform vec2 occluder_grid_origin = vec2(0.0);
uniform vec2 occluder_grid_size = vec2(1.0);
// Ekran UV'si -> harita karo koordinatı: karo = UV * uv_to_cell_scale + uv_to_cell_offset.
uniform vec2 uv_to_cell_scale = vec2(1.0);
uniform vec2 uv_to_cell_offset = vec2(0.0);
// `sources` ile aynı sıra/sayıda kaynaklar, ama karo koordinatında.
uniform vec2 source_cells[8];
// Işının bir duvardan "arkasında sayılması" için o duvarın içinden kat etmesi gereken
// en az karo mesafesi (köşe sürtünmesi engellemesin) - vision_occluders.gd MIN_WALL_CROSSING.
uniform float min_wall_crossing = 0.75;

bool is_occluder(ivec2 cell) {
	vec2 rel = vec2(cell) - occluder_grid_origin;
	if (rel.x < 0.0 || rel.y < 0.0 || rel.x >= occluder_grid_size.x || rel.y >= occluder_grid_size.y) {
		return false;
	}
	return texelFetch(occluders, ivec2(rel), 0).r > 0.5;
}

// a'dan b'ye (karo koordinatı) görüş bir duvarın ARKASINDAN geçiyor mu? (DDA ışın
// yürütme; kural için dosya başına bak.) Döngü sınırı vision_occluders.gd
// MAX_RAY_STEPS ile AYNI olmalı.
bool ray_blocked(vec2 a, vec2 b) {
	vec2 d = b - a;
	ivec2 cell = ivec2(floor(a));
	ivec2 end_cell = ivec2(floor(b));
	ivec2 stp = ivec2(d.x > 0.0 ? 1 : -1, d.y > 0.0 ? 1 : -1);
	vec2 inv = 1.0 / max(abs(d), vec2(0.000001));
	vec2 to_edge = vec2(
		d.x > 0.0 ? float(cell.x + 1) - a.x : a.x - float(cell.x),
		d.y > 0.0 ? float(cell.y + 1) - a.y : a.y - float(cell.y));
	vec2 t_max = to_edge * inv;
	float ray_length = length(d);
	bool entered = false;
	float t_enter = 0.0;
	for (int i = 0; i < 96; i++) {
		if (cell == end_cell || min(t_max.x, t_max.y) > 1.0) {
			break;
		}
		float t_cross = min(t_max.x, t_max.y);
		if (t_max.x < t_max.y) {
			cell.x += stp.x;
			t_max.x += inv.x;
		} else {
			cell.y += stp.y;
			t_max.y += inv.y;
		}
		if (is_occluder(cell)) {
			if (!entered) {
				entered = true;
				t_enter = t_cross;
			}
		} else if (entered) {
			// Duvardan çıkış: yeterince kalın bir gövdeden mi geçtik, köşesine mi sürtündük?
			if ((t_cross - t_enter) * ray_length >= min_wall_crossing) {
				return true;
			}
			entered = false;
		}
	}
	return false;
}

void fragment() {
	float half_band = max(edge_softness, 0.01) * 0.5;
	vec2 pixel_cell = UV * uv_to_cell_scale + uv_to_cell_offset;

	// En iyi kaynağın görünürlüğü: elips görünürlüğü, ARADA görüşü kesen bir duvar varsa 0
	// (takım görüşü: başka bir kaynak pikseli görüyorsa o kazanır). Duvar taraması sadece
	// kaynak şu ana kadarki en iyiyi geçebiliyorsa (yani elipsin içindeyse) yapılır.
	float target_v = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= source_count) {
			break;
		}
		float dist = length((UV - sources[i]) / half_extent);
		float vis = 1.0 - smoothstep(1.0 - half_band, 1.0 + half_band, dist);
		if (vis <= target_v) {
			continue;
		}
		if (occluder_enabled && ray_blocked(source_cells[i], pixel_cell)) {
			continue;
		}
		target_v = vis;
	}

	float old_v = texture(history, SCREEN_UV + shift_uv).r * history_keep;
	float v = target_v > old_v ? min(old_v + up_step, target_v) : max(old_v - down_step, target_v);
	COLOR = vec4(v, v, v, 1.0);
}
