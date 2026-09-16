extends Control

## Draws a bar using a frame texture (border + icon + empty track) and a
## fill texture that gets revealed left-to-right according to value/max_value.
## Source art dimensions and the track window are configurable per-instance
## (defaults match the original 73x19 placeholder art) so different bars can
## use differently-sized sprite sheets.

@export var frame_texture: Texture2D
@export var fill_texture: Texture2D

## Optional: when set, the fill is tinted along this gradient based on
## display_ratio (0.0 = empty end of the gradient, 1.0 = full end). Leave
## unset to draw the fill texture with its own baked-in color (e.g. shield).
@export var color_gradient: Gradient

@export var src_w: float = 73.0
@export var src_h: float = 19.0
@export var track_x: float = 19.0
@export var track_y: float = 7.0
@export var track_w: float = 50.0
@export var track_h: float = 6.0

## Karakter panosunun İKİ YANINDAKİ kanat çubukları (can barı solda, kalkan
## barı sağda) merkeze (karaktere) yakın ucundan hep dolu kalıp, DIŞ uca
## doğru boşalsın diye - can barı bu bayrağı true yapar, dolgu track'in SAĞ
## kenarına yaslanıp sola doğru büzülür/büyür (normal davranış - shield barı
## gibi - hep SOL kenara yaslanıp sağa büyür/büzülür).
@export var fill_align_right: bool = false

var value: float = 100.0
var max_value: float = 100.0
var display_ratio: float = 1.0


func set_value(v: float, mv: float) -> void:
	value = v
	max_value = max(mv, 0.001)


func _process(delta: float) -> void:
	var target_ratio: float = clamp(value / max_value, 0.0, 1.0)
	if abs(display_ratio - target_ratio) > 0.001:
		display_ratio = move_toward(display_ratio, target_ratio, delta * 1.6)
		queue_redraw()
	elif display_ratio != target_ratio:
		display_ratio = target_ratio
		queue_redraw()


func _draw() -> void:
	var s: float = size.x / src_w

	## frame_texture boş bırakılabilir - bu, aynı karakter panosu üzerinde
	## İKİNCİ bir sprite_bar'ı (ör. kalkan barını, can barının hemen üstüne
	## aynı boyutta bindirilmiş) SADECE kendi dolgusunu çizip alttaki panoyu
	## (zaten başka bir node çizdiği için) tekrar çizmeden kullanmayı sağlar.
	if frame_texture:
		draw_texture_rect(frame_texture, Rect2(Vector2.ZERO, size), false)

	if not fill_texture or display_ratio <= 0.0:
		return

	var fill_full_w: float = track_w * s
	var fill_h: float = track_h * s
	var fill_x: float = track_x * s
	var fill_y: float = track_y * s
	var w: float = fill_full_w * display_ratio

	if fill_align_right:
		fill_x += fill_full_w - w

	if w > 0.5:
		var tex_src_w: float = fill_texture.get_width() * display_ratio
		var tex_src_h: float = fill_texture.get_height()
		var tint: Color = Color.WHITE
		if color_gradient:
			tint = color_gradient.sample(clamp(display_ratio, 0.0, 1.0))
		var region_x: float = 0.0
		if fill_align_right:
			region_x = fill_texture.get_width() - tex_src_w
		draw_texture_rect_region(fill_texture, Rect2(fill_x, fill_y, w, fill_h), Rect2(region_x, 0, tex_src_w, tex_src_h), tint)


func _get_minimum_size() -> Vector2:
	return Vector2(src_w, src_h)
