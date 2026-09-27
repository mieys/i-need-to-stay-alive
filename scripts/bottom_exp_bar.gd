extends Control

## Kullanıcı isteği: "oyun ekranının en altına ekranın genişliğiyle aynı
## olacak şekilde ince ve geniş bir exp bar eklenecek ... ekranın alt
## kısmının 20 pixellik bir uzunluğunun tamamını kaplamalı ve exp dolunca
## orda gözükmeli artış animasyonuna sahip olmalı pixel tarzı." - tam ekran
## genişliğinde, 20px yükseklikte, dolum arttıkça (level atlama / xp
## toplama) yumuşak bir tween ile büyüyen piksel-sanatı bir XP çubuğu.

## Kullanıcı isteği (güncelleme): "exp barı çok kalın olmuş birazcık incelt" -
## eski 20px'ten 10px'e indirildi.
## Kullanıcı isteği (2026-09-27): "exp barını %20 inceltip rengini mor exp tonlarında yap" - 12 -> 10 px (tam %20 = 9.6,
## piksel ızgarasında kalsın diye 10), altın/turuncu yerine mor tonlar. hud.gd DOCK_BOTTOM_MARGIN bu yüksekliğe göre boşluk bırakır.
const BAR_HEIGHT := 10.0
const OUTLINE := 1.0
const C_BG := Color(0.11, 0.07, 0.15, 1.0)
const C_OUTLINE := Color(0.52, 0.34, 0.74, 1.0)
const C_FILL := Color(0.6, 0.33, 0.93, 1.0)
const C_SHINE := Color(0.82, 0.66, 1.0, 0.9)
const C_FLASH := Color(0.95, 0.86, 1.0, 1.0)

## Görünen dolum oranı - gerçek orana (target_ratio) doğru tween ile
## yumuşakça ilerler, ani bir sıçrama yerine "akan" bir dolum animasyonu
## hissi verir (bkz. _set_display_ratio).
var _display_ratio: float = 0.0
var _target_ratio: float = 0.0
var _tween: Tween = null

## Level atlandığında (yeni bir dilime geçildiğinde) çubuğun kısaca
## parlayıp/titreşmesi için - "exp dolunca orda gözükmeli" isteğiyle uyumlu
## küçük bir "level up flash" efekti.
var _flash_alpha: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -BAR_HEIGHT
	offset_bottom = 0.0
	offset_left = 0.0
	offset_right = 0.0
	resized.connect(queue_redraw)
	queue_redraw()


func set_xp(current: float, needed: float) -> void:
	var ratio: float = clamp(current / max(needed, 0.001), 0.0, 1.0)
	var leveled_up: bool = ratio < _target_ratio - 0.001 ## dolup taşıp sıfırlandıysa (yeni seviye)
	_target_ratio = ratio
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_set_display_ratio, _display_ratio, _target_ratio, 0.45)
	if leveled_up:
		_flash_alpha = 1.0
		var flash_tween := create_tween()
		flash_tween.tween_method(_set_flash_alpha, 1.0, 0.0, 0.6)
	queue_redraw()


func _set_display_ratio(v: float) -> void:
	_display_ratio = v
	queue_redraw()


func _set_flash_alpha(v: float) -> void:
	_flash_alpha = v
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = BAR_HEIGHT

	## Arka plan (boş kısım) - koyu mor.
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), C_BG)

	## Üst piksel çerçevesi (açık mor) - siyah zeminler ve
	## ekran kenarlıkları üzerinde belirgin bir sınır çizgisi oluşturur.
	draw_rect(Rect2(Vector2(0, 0), Vector2(w, OUTLINE)), C_OUTLINE)

	if _display_ratio > 0.0:
		var fill_w: float = round(w * _display_ratio)
		var fill_rect := Rect2(Vector2(0, OUTLINE), Vector2(fill_w, h - OUTLINE))
		## Ana dolum rengi - mor EXP tonu.
		draw_rect(fill_rect, C_FILL)
		## Üstte ince, daha açık bir "parlama" şeridi (klasik piksel bar derinliği).
		draw_rect(Rect2(Vector2(0, OUTLINE), Vector2(fill_w, max(1.0, h * 0.25))), C_SHINE)
		## Piksel-sanatı bölme çizgileri - her %10'da ince bir çizgi.
		for i in range(1, 10):
			var seg_x: float = round(w * (i / 10.0))
			if seg_x <= fill_w:
				draw_line(Vector2(seg_x, OUTLINE), Vector2(seg_x, h), Color(0, 0, 0, 0.18), 1.0)

	## Level-up flash: dolum sıfırlanıp yeni seviyeye geçtiği anda tüm
	## çubuğun üstünde beyazımsı bir parlama söner (kullanıcı isteği:
	## "exp dolunca orda gözükmeli artış animasyonuna sahip olmalı").
	if _flash_alpha > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(C_FLASH.r, C_FLASH.g, C_FLASH.b, 0.35 * _flash_alpha))
