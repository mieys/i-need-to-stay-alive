extends RefCounted

## ORTAK KAFATASI İKONU (kullanıcı çizimi, 2026-11-11: "zorluk seviyesini ve bosslardaki kafatası ikonlarını bununla değiştir").
## Kaynak: tools/skull_ikon/skull_kaynak.png (32x32) -> `python -I tools/gen_skull_icons.py` -> assets/ui/skull/:
##   skull.png (22x30, kaynağın opak alanı birebir) / skull_red.png (Final kademe) / skull_s.png + skull_s_red.png (11x15, 2x2 ortalama).
## Kademe satırı (tier_display.gd), boss işareti + boss barı madalyonu (boss_bar_art.gd), oyun sonu panosu (game_over_board.gd),
## rekor ekranı ve telefon oyun sonu karoları bunu çizer; eski 9x9 ASCII kafatası (boss_bar_art.gd SKULL_ROWS) kalktı.
## Boyutlar TAM KATLARDA çizilir (nearest): küçük yerler 11x15 doku, normal 22x30, büyük yerler 2x/3x - piksel ızgarası bozulmaz.

const BIG: Texture2D = preload("res://assets/ui/skull/skull.png")
const BIG_RED: Texture2D = preload("res://assets/ui/skull/skull_red.png")
const SMALL: Texture2D = preload("res://assets/ui/skull/skull_s.png")
const SMALL_RED: Texture2D = preload("res://assets/ui/skull/skull_s_red.png")

const BIG_SIZE := Vector2(22, 30)
const SMALL_SIZE := Vector2(11, 15)

## Boş kafa (kademe satırında henüz dolmamış, yarım kafanın sağ yarısı): koyu, saydam hayalet.
const GHOST := Color(0.3, 0.27, 0.24, 0.6)

## (küçük doku mu, kat, ekran px yüksekliği) - büyükten küçüğe en uygun boyu seçmek için, artan sırada.
const STEPS: Array = [[true, 1, 15.0], [false, 1, 30.0], [false, 2, 60.0], [false, 3, 90.0], [false, 4, 120.0]]
const FIT_SLACK := 1.12 ## hedef yüksekliği en çok bu kadar aşan boy de seçilir (iskelet 27 px'lik yuvada 30 px'lik kafa gibi)


static func tex(red: bool = false, small: bool = false) -> Texture2D:
	if small:
		return SMALL_RED if red else SMALL
	return BIG_RED if red else BIG


## Hedef yükseklik (ekran px) için en uygun [küçük?, kat] çifti.
static func pick(target_h: float) -> Array:
	var best: Array = STEPS[0]
	for st: Array in STEPS:
		if float(st[2]) <= target_h * FIT_SLACK:
			best = st
	return [best[0], int(best[1])]


## Kafayı `pos` (sol-üst) noktasına k katında çizer. fill: 2 dolu, 1 yarım (sol yarı dolu, sağ hayalet), 0 boş (hayalet).
## mod: renk çarpanı (kilitli / solgun yerler için).
static func draw(ci: CanvasItem, pos: Vector2, k: float, fill: int = 2, red: bool = false, small: bool = false,
		mod: Color = Color.WHITE) -> void:
	var t: Texture2D = tex(red, small)
	var sz: Vector2 = t.get_size()
	var ghost := Color(GHOST.r * mod.r, GHOST.g * mod.g, GHOST.b * mod.b, GHOST.a * mod.a)
	if fill >= 2:
		ci.draw_texture_rect(t, Rect2(pos, sz * k), false, mod)
		return
	if fill <= 0:
		ci.draw_texture_rect(t, Rect2(pos, sz * k), false, ghost)
		return
	var left_w: float = ceilf(sz.x * 0.5) ## orta sütun sol yarıda
	ci.draw_texture_rect_region(t, Rect2(pos, Vector2(left_w, sz.y) * k), Rect2(0.0, 0.0, left_w, sz.y), mod)
	ci.draw_texture_rect_region(t, Rect2(pos + Vector2(left_w * k, 0.0), Vector2(sz.x - left_w, sz.y) * k),
			Rect2(left_w, 0.0, sz.x - left_w, sz.y), ghost)


## Merkezi `center` olan, `target_h` ekran px yüksekliğindeki yere en uygun tam katlı boyda çizer.
static func draw_fit(ci: CanvasItem, center: Vector2, target_h: float, fill: int = 2, red: bool = false,
		mod: Color = Color.WHITE) -> void:
	var p: Array = pick(target_h)
	var small: bool = p[0]
	var k: float = float(p[1])
	var sz: Vector2 = (SMALL_SIZE if small else BIG_SIZE) * k
	draw(ci, (center - sz * 0.5).round(), k, fill, red, small, mod)
