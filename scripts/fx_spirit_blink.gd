extends Node2D

## Ruhani Yetenek ışınlanma efektleri - DÜNYA konumunda tek seferlik (top_level), kozmetik (1 texel detay, bkz. hafıza
## "Pixel density 48x48"). player.gd _spirit_blink_fx() yerelde doğurur, network_manager.gd "spirit_blink" dalı uzakta.
##  kind "streak" (Taktiksel): from -> to arasında solan ince turkuaz/beyaz iz + iki uçta genişleyen halka ve kıvılcım
##  (eski kind "column" Dükkan ruhani yeteneğiyle birlikte silindi, madde 543)

const PixelDraw := preload("res://scripts/pixel_draw.gd")

var kind: String = "streak"
var from_pos: Vector2 = Vector2.ZERO
var to_pos: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _life: float = 0.45


func setup(p_kind: String, p_from: Vector2, p_to: Vector2) -> void:
	kind = p_kind
	from_pos = p_from
	to_pos = p_to
	_life = 0.45
	global_position = Vector2.ZERO


func _ready() -> void:
	top_level = true
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	global_position = Vector2.ZERO


## Gece ışığı (bkz. night_glow.gd): kök (0,0)'da - ışık ışınlanma izi boyunca.
func get_glow_segment() -> Array:
	return [from_pos, to_pos]


func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	_draw_streak(_t / _life)


func _draw_streak(k: float) -> void:
	var texel: float = PixelDraw.TEXEL
	var fade: float = 1.0 - k
	## İz: from -> to, kuyruk (from) hızlı söner; 3 paralel ince çizgi
	var dir: Vector2 = (to_pos - from_pos)
	if dir.length() > 1.0:
		var normal: Vector2 = Vector2(-dir.y, dir.x).normalized()
		var tail: Vector2 = from_pos.lerp(to_pos, clampf(k * 1.4, 0.0, 1.0))
		PixelDraw.line(self, tail, to_pos, Color(0.7, 0.97, 1.0, fade * 0.9), 1)
		PixelDraw.line(self, tail + normal * texel * 2.0, to_pos + normal * texel * 2.0, Color(0.5, 0.85, 1.0, fade * 0.5), 1)
		PixelDraw.line(self, tail - normal * texel * 2.0, to_pos - normal * texel * 2.0, Color(0.5, 0.85, 1.0, fade * 0.5), 1)
		## iz boyunca dağılan kıvılcım pikselleri
		for i in range(10):
			var f: float = PixelDraw.hash01(i * 13 + 3)
			var p: Vector2 = from_pos.lerp(to_pos, f) + normal * (PixelDraw.hash01(i * 7 + 1) - 0.5) * 14.0
			if f * 1.0 > k * 1.4 - 0.1:
				PixelDraw.px(self, p, 1, Color(1.0, 1.0, 1.0, fade))
	## Uç halkaları: from'da içe/dışa dağılan, to'da genişleyen
	PixelDraw.ring(self, from_pos, 4.0 + k * 30.0, Color(0.6, 0.9, 1.0, fade * 0.8), 1, 3, 2, _t * 20.0)
	PixelDraw.ring(self, to_pos, 4.0 + k * 38.0, Color(1.0, 1.0, 1.0, fade), 1)
	if k < 0.25:
		PixelDraw.disc_dither(self, to_pos + Vector2(0, -6), 20.0 * (1.0 - k * 2.0), Color(0.85, 1.0, 1.0, 0.8), int(_t * 50.0), 1)
