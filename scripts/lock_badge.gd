extends Control

## KİLİT ROZETİ (Ruh Mağazası kilitleri, bkz. meta_progress.gd): kilitli bir kart/ikon/düğmenin üstüne yarı saydam karartma + piksel asma kilit.
## Sanat dosyası yok - kodla çizilir (kare piksel birimi, menü kitinin kahve/altın tonları). Fare olaylarını GEÇİRİR (alttaki düğme tıklanabilir
## kalır: kilitli içerik incelenebilir, sadece seçilemez).

const DIM := Color(0.10, 0.06, 0.03, 0.5)
const BODY := Color("#b07a22")
const BODY_LIGHT := Color("#d9a843")
const OUTLINE := Color("#4a2c1a")
const KEYHOLE := Color("#4a2c1a")


## `parent`'a tam boy ekler ve döner. dim: karartma açık mı (küçük ikonlarda da açık; sadece kilit istenirse false).
static func attach(parent: Control, dim: bool = true) -> Control:
	var badge: Control = (load("res://scripts/lock_badge.gd") as GDScript).new()
	badge.name = "LockBadge"
	badge.set_meta("dim", dim)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return badge


func _draw() -> void:
	if bool(get_meta("dim", true)):
		draw_rect(Rect2(Vector2.ZERO, size), DIM)
	var u: float = maxf(2.0, floorf(minf(size.x, size.y) / 14.0))
	var cx: float = roundf(size.x * 0.5 / u) * u
	var cy: float = roundf(size.y * 0.45 / u) * u
	## Gövde: 8x6 birim; kanca: 6 birim genişlik, 4 birim yükseklik (3 birim kalınlığında kontur çerçevesi 1 birim).
	var body := Rect2(cx - 4.0 * u, cy, 8.0 * u, 6.0 * u)
	var shackle_outer := Rect2(cx - 3.0 * u, cy - 4.0 * u, 6.0 * u, 5.0 * u)
	draw_rect(shackle_outer.grow(u), OUTLINE)
	draw_rect(shackle_outer, BODY_LIGHT)
	## Kancanın iç boşluğunu karartarak aç (içi koyu, kanca = 1 birim kalın çerçeve).
	draw_rect(Rect2(shackle_outer.position + Vector2(u, u), shackle_outer.size - Vector2(2.0 * u, u)), OUTLINE)
	draw_rect(body.grow(u), OUTLINE)
	draw_rect(body, BODY)
	draw_rect(Rect2(body.position, Vector2(body.size.x, u)), BODY_LIGHT)
	draw_rect(Rect2(cx - u, cy + 2.0 * u, 2.0 * u, 2.0 * u), KEYHOLE)
