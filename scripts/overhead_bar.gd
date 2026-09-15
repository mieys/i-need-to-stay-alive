extends Node2D

## Karakterin/yaratığın üstünde duran can (+ kalkan) çubuğu - kullanıcı
## isteği üzerine yuvarlak/hap şeklindeki "modern" görünüm yerine PİKSEL
## SANATI oyuna uygun, keskin köşeli, kalın siyah pikselik anahatlı bir
## stile çevrildi (bkz. _draw_pixel_bar - anti-aliasing YOK, tüm koordinatlar
## tam pixel'e yuvarlanıyor). Can çubuğunda ayrıca LoL'daki can çubuğu gibi
## her SEGMENT_HP (40) can başına ince bir bölme çizgisi var (bkz.
## _draw_health_segments) - örn. 200 canlı bir yaratıkta çubuk 5 eşit dilime
## bölünmüş görünür. Shield strip only shows up while there's shield to show.

const WIDTH := 44.0
const HEIGHT := 7.0
const GAP := 2.0
const SHADOW_OFFSET := Vector2(1.0, 1.0)
const OUTLINE := 2.0 ## kalın, piksel-sanatı tarzı siyah çerçeve

## Kaç can biriminde bir bölme çizgisi çizileceği (kullanıcı isteği: "can
## barında her 40 can başına bir çizgi olsun loldeki can barı gibi").
## DÜZELTME (kullanıcı bildirimi: "boss'larda çizgi çok fazla göründüğü için
## can barları simsiyah oluyor, 400 can başına 1 çizgi görünsün, veya
## çizgilerin bir sınırı olsun") - bir süre 40'tan 400'e çıkarılmıştı, ama bu
## küçük canlı yaratıklarda/oyuncuda 40'lık bölünmeyi tamamen kaybettiriyordu.
## Kullanıcı isteği (yeni tur): "40 can başına bir çizgi olmalı ama çizgi
## sayısı 20'yi geçmemeli" - SEGMENT_HP tekrar 40'a döndü, aşırı yüksek canlı
## yaratıklarda (bkz. boss) çizgi patlamasını/simsiyah görünümü önleyen üst
## sınır (MAX_SEGMENT_LINES) 20'ye çekildi (bkz. _draw_health_segments -
## health_max > 20*40=800 olan yaratıklarda çizgiler ilk 800 canla sınırlı
## kalır, geri kalan bar çizgisiz düz görünür).
const SEGMENT_HP := 40.0
const MAX_SEGMENT_LINES := 20

## Above the character's head, with clear breathing room. Default is tuned
## for the player sprite; bosses (much bigger, wildly varying sizes) call
## set_offset() right after this script is attached to push it clear of
## their head instead - see enemy_spawner.gd's _attach_boss_bar.
var y_offset: float = -62.0

var health_current: float = 1.0
var health_max: float = 1.0
var health_ratio: float = 1.0

var shield_current: float = 0.0
var shield_max: float = 0.0
var shield_ratio: float = 0.0
var show_shield: bool = false


func set_offset(offset: float) -> void:
	y_offset = offset
	queue_redraw()


func set_health(current: float, max_value: float) -> void:
	health_current = current
	health_max = max(max_value, 0.001)
	health_ratio = clamp(current / health_max, 0.0, 1.0)
	queue_redraw()


func set_shield(current: float, max_value: float) -> void:
	show_shield = max_value > 0.0
	shield_current = current
	shield_max = max(max_value, 0.001)
	shield_ratio = clamp(current / shield_max, 0.0, 1.0) if show_shield else 0.0
	queue_redraw()


## Kullanıcı isteği: "karakterin üstündeki can ve kalkan barları hafiften
## oval olsun" - eskiden tamamen keskin köşeli dikdörtgenlerdi (bkz. eski
## yorum), artık her katman (gölge/çerçeve/arkaplan/dolu kısım) StyleBoxFlat
## ile ÇOK HAFİF bir köşe yuvarlaklığıyla (bar yüksekliğinin ~%28'i - tam
## "hap" şekli DEĞİL, "hafiften oval" istendiği için bilinçli olarak küçük)
## çiziliyor. Piksel sanatı hissi (kalın siyah çerçeve, sert gölge, üstte
## parlama şeridi) korunuyor - sadece köşeler artık keskin değil.
const CORNER_RATIO := 0.28

func _draw_pixel_bar(rect: Rect2, ratio: float, fill_color: Color, bg_color: Color) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	var corner: float = r.size.y * CORNER_RATIO

	var shadow_rect := Rect2(r.position + SHADOW_OFFSET, r.size)
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.5)
	shadow_style.set_corner_radius_all(int(corner))
	draw_style_box(shadow_style, shadow_rect)

	var outer := r.grow(OUTLINE)
	var outline_style := StyleBoxFlat.new()
	outline_style.bg_color = Color(0, 0, 0, 1.0)
	outline_style.set_corner_radius_all(int(corner + OUTLINE))
	draw_style_box(outline_style, outer)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = bg_color
	bg_style.set_corner_radius_all(int(corner))
	draw_style_box(bg_style, r)

	if ratio > 0.0:
		var fill_w: float = round(r.size.x * ratio)
		if fill_w > 0.0:
			var fill_rect := Rect2(r.position, Vector2(fill_w, r.size.y))
			var fill_style := StyleBoxFlat.new()
			fill_style.bg_color = fill_color
			fill_style.set_corner_radius_all(int(corner))
			draw_style_box(fill_style, fill_rect)
			var glow_rect := Rect2(r.position, Vector2(fill_w, max(1.0, r.size.y * 0.3)))
			var glow_style := StyleBoxFlat.new()
			glow_style.bg_color = fill_color.lightened(0.4)
			glow_style.corner_radius_top_left = int(corner)
			glow_style.corner_radius_top_right = int(corner)
			draw_style_box(glow_style, glow_rect)


## LoL tarzı bölme çizgileri: max_value SEGMENT_HP'den büyükse, her katında
## (40, 80, 120, ...) çubuğun tamamını (dolu/boş fark etmeksizin) dikey ince
## bir çizgiyle böler - büyük can havuzlu yaratıklarda/oyuncuda can çubuğunun
## kaç "parça" olduğu anında okunabilir olur.
func _draw_health_segments(rect: Rect2) -> void:
	if health_max <= SEGMENT_HP:
		return
	var r := Rect2(rect.position.round(), rect.size.round())
	var seg: float = SEGMENT_HP
	var lines_drawn: int = 0
	while seg < health_max and lines_drawn < MAX_SEGMENT_LINES:
		var x: float = round(r.position.x + r.size.x * (seg / health_max))
		draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + r.size.y), Color(0, 0, 0, 0.7), 1.0)
		seg += SEGMENT_HP
		lines_drawn += 1


func _draw() -> void:
	var half_w: float = WIDTH * 0.5
	var health_rect := Rect2(Vector2(-half_w, y_offset), Vector2(WIDTH, HEIGHT))
	_draw_pixel_bar(health_rect, health_ratio, Color(0.30, 0.82, 0.24, 1.0), Color(0.12, 0.04, 0.04, 1.0))
	_draw_health_segments(health_rect)

	if show_shield:
		var shield_rect := Rect2(Vector2(-half_w, y_offset + HEIGHT + GAP), Vector2(WIDTH, HEIGHT * 0.72))
		_draw_pixel_bar(shield_rect, shield_ratio, Color(0.35, 0.72, 1.0, 1.0), Color(0.04, 0.08, 0.14, 1.0))
