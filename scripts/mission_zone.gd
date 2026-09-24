extends Node2D

## "Bayrağı Ele Geçir" (capture_point) ve "Alanı Güvenceye Al" (secure_area) görevlerinin DÜNYADAKİ görseli.
## Kullanıcı bildirimi (2026-09-24): "bayrak kapmacada bayrak yok" / "alanı güvenceye al görevinde alan yok" - bu iki
## tür için sahnede HİÇBİR şey çizilmiyordu (sadece minimap işareti vardı), oyuncu alanın sınırını göremiyordu.
## SALT GÖRSEL - gerçek "alanın içinde mi" hesabı world_event_manager.gd'de (host) yapılır; bu Node HER istemcide
## (host dahil) main.gd _on_world_event_started'da kurulur, ilerlemeyi world_event_progress'ten alır (set_progress).
##
## PERF (kullanıcı isteği aynı gün: "pixeldraw sistemine ait görsel efektler oyunu çok kastırıyor, spritesheete
## dönüştürüp kullanmalıyız"): her karede PixelDraw ile yüzlerce draw_rect YERİNE halka/bayrak/kılıç görselleri
## setup'ta BİR KEZ bir Image'e piksel piksel çizilip ImageTexture olarak Sprite2D'lerde gösteriliyor (1 sanat pikseli =
## PixelDraw.TEXEL dünya birimi, NEAREST filtre - pixel görünüm aynı). Karede yapılan tek iş bayrağın yüksekliği/rengi
## ve 3 karelik dalga animasyonunun kare seçimi.

const PixelDraw := preload("res://scripts/pixel_draw.gd")

const RING_CAPTURE := Color(0.55, 0.85, 1.0, 0.85)
const RING_SECURE := Color(1.0, 0.42, 0.25, 0.85)
const POLE_COLOR := Color(0.36, 0.24, 0.13)
const POLE_DARK := Color(0.2, 0.13, 0.07)
const FLAG_NEUTRAL := Color(0.92, 0.9, 0.84)
const FLAG_CAPTURED := Color(1.0, 0.78, 0.2)
const POLE_H := 34 ## sanat pikseli
const FLAG_W := 12
const FLAG_H := 8
const FLAG_WAVE_FPS := 6.0
const FLAG_SCALE := 2.0 ## bayrak+direk karakter boyunda okunsun diye 2 kat (1x'te uzaktan fark edilmiyordu)

const SWORDS_ART: Array = [
	"s.........s",
	".s.......s.",
	"..s.....s..",
	"...s...s...",
	"....s.s....",
	".....x.....",
	"....s.s....",
	"..hh...hh..",
	"..h.....h..",
	".g.......g.",
	"g.........g",
]
const SWORDS_PAL := {
	"s": Color(0.85, 0.88, 0.95),
	"x": Color(1.0, 1.0, 1.0),
	"h": Color(0.55, 0.35, 0.15),
	"g": Color(1.0, 0.8, 0.3),
}

var kind: String = "capture_point"
var radius: float = 240.0
var _progress: float = 0.0
var _t: float = 0.0
var _flag: Sprite2D = null
var _flag_frames: Array[ImageTexture] = []
var _flag_frame: int = -1


func setup(p_kind: String, p_radius: float) -> void:
	kind = p_kind
	radius = maxf(p_radius, 16.0)
	_build()


func _ready() -> void:
	z_index = 0 ## negatif z harita katmanlarının altında kalır (bkz. fx_korsan_zone.gd notu)


func set_progress(value: float, target: float) -> void:
	_progress = clampf(value / maxf(target, 0.001), 0.0, 1.0)
	_update_flag()


func _process(delta: float) -> void:
	if _flag == null:
		return
	_t += delta
	var f: int = int(_t * FLAG_WAVE_FPS) % _flag_frames.size()
	if f != _flag_frame:
		_flag_frame = f
		_flag.texture = _flag_frames[f]


static func _sprite_for(tex: Texture2D, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * PixelDraw.TEXEL
	s.position = pos
	return s


## Tek sanat pikseli (Image pikseli) yaz - sınır dışını sessizce atla.
static func _put(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_flag = null
	var ring_col: Color = RING_CAPTURE if kind == "capture_point" else RING_SECURE
	add_child(_sprite_for(_bake_ring(radius, ring_col), Vector2.ZERO))
	if kind == "capture_point":
		var pole := _sprite_for(_bake_pole(), Vector2(0, -float(POLE_H) * 0.5 * PixelDraw.TEXEL * FLAG_SCALE))
		pole.scale *= FLAG_SCALE
		add_child(pole)
		_flag_frames.clear()
		for i in range(3):
			_flag_frames.append(_bake_flag_frame(i))
		_flag = _sprite_for(_flag_frames[0], Vector2.ZERO)
		_flag.centered = false
		_flag.scale *= FLAG_SCALE
		add_child(_flag)
		_update_flag()
	else:
		var h: int = SWORDS_ART.size()
		var w: int = str(SWORDS_ART[0]).length()
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in range(h):
			for x in range(w):
				var ch: String = str(SWORDS_ART[y]).substr(x, 1)
				if SWORDS_PAL.has(ch):
					img.set_pixel(x, y, SWORDS_PAL[ch])
		var sw := _sprite_for(ImageTexture.create_from_image(img), Vector2(0, -4.0))
		sw.scale *= 2.0
		add_child(sw)


## Kesikli dış halka + soluk iç halka + 8 yönde çentik, tek bir doku olarak.
func _bake_ring(r_world: float, col: Color) -> ImageTexture:
	var r: float = r_world / PixelDraw.TEXEL ## sanat pikseli cinsinden
	var size: int = int(ceil(r * 2.0 + 14.0))
	var c: float = float(size) * 0.5
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var inner := Color(col, 0.35)
	var outer_count: int = maxi(16, int(TAU * r / 2.0))
	for i in range(outer_count):
		if i % 11 >= 6: ## 6 açık, 5 boş kesik
			continue
		var a: float = TAU * float(i) / float(outer_count)
		var px: int = int(round(c + cos(a) * r))
		var py: int = int(round(c + sin(a) * r))
		for ox in range(2):
			for oy in range(2):
				_put(img, px + ox - 1, py + oy - 1, col)
	var ri: float = r - 5.0
	var inner_count: int = maxi(16, int(TAU * ri))
	for i in range(inner_count):
		if i % 7 >= 2:
			continue
		var a: float = TAU * float(i) / float(inner_count)
		_put(img, int(round(c + cos(a) * ri)), int(round(c + sin(a) * ri)), inner)
	for k in range(8):
		var a: float = float(k) * TAU / 8.0
		for d in range(-3, 5):
			var px: int = int(round(c + cos(a) * (r + float(d))))
			var py: int = int(round(c + sin(a) * (r + float(d))))
			for ox in range(2):
				for oy in range(2):
					_put(img, px + ox - 1, py + oy - 1, col)
	return ImageTexture.create_from_image(img)


## Toprak tümseği + 2 piksellik direk + tepe topuzu. Doku merkezi direğin ortası.
func _bake_pole() -> ImageTexture:
	var w: int = 11
	var h: int = POLE_H + 4
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx: int = w / 2
	for i in range(POLE_H):
		var y: int = h - 3 - i
		_put(img, cx - 1, y, POLE_COLOR)
		_put(img, cx, y, POLE_DARK)
	for ox in range(-1, 1):
		for oy in range(2):
			_put(img, cx + ox, 1 + oy, FLAG_CAPTURED)
	for x in range(w):
		_put(img, x, h - 2, Color(0.3, 0.22, 0.12))
		_put(img, x, h - 1, Color(0.0, 0.0, 0.0, 0.25))
	for x in range(cx - 2, cx + 3):
		_put(img, x, h - 3, Color(0.38, 0.28, 0.15))
	return ImageTexture.create_from_image(img)


## Beyaz bayrak kumaşı (renk modulate ile verilir), dalga fazı frame'e göre. Sol üst köşe = direğe tutunan nokta.
func _bake_flag_frame(frame: int) -> ImageTexture:
	var img := Image.create(FLAG_W, FLAG_H + 2, false, Image.FORMAT_RGBA8)
	for x in range(FLAG_W):
		var wave: int = int(round(sin(float(frame) * TAU / 3.0 - float(x) * 0.7)))
		var h: int = FLAG_H - int(float(x) / 3.0)
		for y in range(h):
			var shade: bool = y == h - 1 or x == FLAG_W - 1
			_put(img, x, y + 1 + wave, Color(0.75, 0.75, 0.75) if shade else Color(1, 1, 1))
	return ImageTexture.create_from_image(img)


## İlerlemeyle bayrak direğin dibinden tepesine yükselir, beyazdan altına döner.
func _update_flag() -> void:
	if _flag == null:
		return
	var texel: float = PixelDraw.TEXEL * FLAG_SCALE
	var lift: float = lerpf(6.0, float(POLE_H) - 3.0, _progress)
	_flag.position = Vector2(texel * 0.5, -texel * (lift + 2.0))
	_flag.modulate = FLAG_NEUTRAL.lerp(FLAG_CAPTURED, _progress)
