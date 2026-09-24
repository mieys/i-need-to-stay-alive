extends Control

## Menülerde bir karakteri piksel-tam çizen kontrol (kart portresi + vitrin sahnesi). Karakterin oyundaki SpriteFrames'inden
## (Characters.DEFS[id]["frames"]) "idle_down" klibini kullanır: durağanken ilk kare (= portre PNG'siyle aynı kare),
## playing=true iken klibi kendi hızında döngüde oynatır (kart üstüne gelince / seçiliyken, vitrinde hep).
## Ölçek her zaman TAM SAYI (48x48 sprite'lar için pixel_scale; 64x64 çerçeveli eski Oakley kiti orana göre yuvarlanır) -
## böylece her sanat pikseli eşit sayıda ekran pikseli olur (bkz. 2026-09-24 "düşük kalitede görünüyor" düzeltmesi).
## Yerleşim: karakterin dolu piksellerinin ALT kenarı ground_y'ye (yerel px), yatay merkezi center_x'e oturur - her
## karakter kendi sprite'ındaki boşluktan bağımsız olarak zemine basar.

const ANIM := &"idle_down"

var frames: SpriteFrames = null
var pixel_scale: int = 3
var ground_y: float = 0.0
var center_x: float = -1.0 ## < 0: kontrolün yatay ortası
var playing: bool = false: set = set_playing

var _anim: StringName = ANIM
var _frame: int = 0
var _time: float = 0.0
var _frame_size: Vector2 = Vector2(48, 48)
var _feet_row: float = 41.0
var _content_cx: float = 24.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


func setup(def: Dictionary, scale_px: int, ground: float) -> void:
	pixel_scale = scale_px
	ground_y = ground
	var path: String = str(def.get("frames", ""))
	frames = load(path) as SpriteFrames if path != "" and ResourceLoader.exists(path) else null
	_anim = ANIM
	if frames and not frames.has_animation(_anim):
		var names: PackedStringArray = frames.get_animation_names()
		_anim = StringName(names[0]) if names.size() > 0 else ANIM
	_frame = 0
	_time = 0.0
	_measure()
	queue_redraw()


func set_playing(value: bool) -> void:
	if playing == value:
		return
	playing = value
	set_process(value)
	if not value:
		_frame = 0
		_time = 0.0
	queue_redraw()


func _frame_texture(i: int) -> Texture2D:
	if frames == null or not frames.has_animation(_anim):
		return null
	var n: int = frames.get_frame_count(_anim)
	if n <= 0:
		return null
	return frames.get_frame_texture(_anim, i % n)


## İlk karenin dolu piksel kutusu: ayak satırı + yatay merkez (tüm kareler aynı hizada kabul edilir - idle nefes animasyonu).
func _measure() -> void:
	var t: Texture2D = _frame_texture(0)
	if t == null:
		return
	_frame_size = t.get_size()
	var img: Image = t.get_image()
	if img == null:
		return
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return
	_feet_row = float(used.end.y)
	_content_cx = used.position.x + used.size.x * 0.5


## 48 px'lik kareler için pixel_scale aynen; farklı kare boyutunda (Oakley 64) karakter boyu diğerleriyle orantılı kalsın
## diye oranla ölçeklenip EN YAKIN tam sayıya yuvarlanır.
func effective_scale() -> int:
	return maxi(1, roundi(pixel_scale * 48.0 / maxf(1.0, _frame_size.y)))


func _process(delta: float) -> void:
	if frames == null or not frames.has_animation(_anim):
		return
	var n: int = frames.get_frame_count(_anim)
	if n <= 1:
		return
	var fps: float = maxf(0.1, frames.get_animation_speed(_anim))
	var dur: float = frames.get_frame_duration(_anim, _frame) / fps
	_time += delta
	if _time >= dur:
		_time -= dur
		_frame = (_frame + 1) % n
		queue_redraw()


func _draw() -> void:
	var t: Texture2D = _frame_texture(_frame)
	if t == null:
		return
	var k: float = float(effective_scale())
	var cx: float = center_x if center_x >= 0.0 else size.x * 0.5
	## x, menü dokularının 3 px'lik texel ızgarasına oturtulur (kart çerçevesi ile karakter pikselleri aynı ızgarada kalsın).
	var pos := Vector2(roundf((cx - _content_cx * k) / 3.0) * 3.0, roundf(ground_y - _feet_row * k))
	draw_texture_rect(t, Rect2(pos, _frame_size * k), false)
