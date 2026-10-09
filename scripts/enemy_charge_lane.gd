extends Node2D

## Minotaur hücum UYARI ŞERİDİ (bkz. minotaur_charge.gd _show_lane): data.warn saniye boyunca yerde, boss'tan data.dir yönünde
## data.length uzunluğunda, data.width genişliğinde kırmızı şerit; üstündeki oklar hücum yönünde akar, süre bitince hızlı yanıp söner.
## Host'ta ve (spawn_synced_world_fx ile) her istemcide AYNI veriyle doğar; HASAR VERMEZ (isabet kararı boss'un hücum adımında,
## minotaur_charge.gd _check_hits) - authoritative/source/damage alanları spawn_world_fx sözleşmesi için var.
## PERFORMANS: TEK Sprite2D, doku bir kez kodla çizilen küçük bir karo (texture_repeat + region), akış sadece region kaydırması.
## Piksel-art: 1 doku pikseli = TEXEL dünya birimi, en yakın komşu süzme.

const TEXEL := 2.0
const TILE_LEN := 14 ## doku pikseli (ok aralığı)
const SCROLL_TEXELS_PER_SEC := 34.0
const FADE_OUT := 0.12
const BASE_ALPHA := 0.9

static var _tile_cache: Dictionary = {} ## yükseklik (doku px) -> ImageTexture

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _warn: float = 0.55
var _t: float = 0.0
var _sprite: Sprite2D = null
var _length_texels: float = 100.0


func _ready() -> void:
	var dir: Vector2 = Vector2(data.get("dir", Vector2.RIGHT))
	if dir.length() < 0.01:
		dir = Vector2.RIGHT
	rotation = dir.normalized().angle()
	_warn = maxf(float(data.get("warn", 0.55)), 0.05)
	var length: float = maxf(float(data.get("length", 300.0)), 8.0)
	var width: float = maxf(float(data.get("width", 76.0)), 8.0)
	var h_texels: int = maxi(int(round(width / TEXEL)), 6)
	_length_texels = length / TEXEL
	_sprite = Sprite2D.new()
	_sprite.texture = _tile_texture(h_texels)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0.0, 0.0, _length_texels, float(h_texels))
	_sprite.scale = Vector2.ONE * TEXEL
	_sprite.offset = Vector2(0.0, -float(h_texels) * 0.5)
	_sprite.modulate.a = 0.0
	add_child(_sprite)


func _process(delta: float) -> void:
	_t += delta
	var total: float = _warn + FADE_OUT
	if _t >= total:
		queue_free()
		return
	var r: Rect2 = _sprite.region_rect
	r.position.x = -_t * SCROLL_TEXELS_PER_SEC
	_sprite.region_rect = r
	var k: float = clampf(_t / _warn, 0.0, 1.0)
	var alpha: float
	if _t < _warn:
		var fade_in: float = clampf(_t / 0.1, 0.0, 1.0)
		var blink: float = 0.5 + 0.5 * sin(_t * lerpf(9.0, 36.0, k))
		alpha = BASE_ALPHA * fade_in * lerpf(0.78, 1.0, blink * k)
	else:
		alpha = BASE_ALPHA * (1.0 - (_t - _warn) / FADE_OUT)
	_sprite.modulate.a = alpha


## TILE_LEN x h_texels karo: üst/alt kenar parlak, iç dolgu koyu kırmızı yarı saydam, ortada hücum yönüne bakan ok (">").
static func _tile_texture(h_texels: int) -> ImageTexture:
	if _tile_cache.has(h_texels):
		return _tile_cache[h_texels]
	var img: Image = Image.create(TILE_LEN, h_texels, false, Image.FORMAT_RGBA8)
	var fill := Color(0.78, 0.07, 0.05, 0.42)
	var edge := Color(1.0, 0.3, 0.18, 0.9)
	var arrow := Color(1.0, 0.55, 0.3, 0.8)
	img.fill(fill)
	for x in range(TILE_LEN):
		img.set_pixel(x, 0, edge)
		img.set_pixel(x, h_texels - 1, edge)
		img.set_pixel(x, 1, Color(edge.r, edge.g, edge.b, 0.45))
		img.set_pixel(x, h_texels - 2, Color(edge.r, edge.g, edge.b, 0.45))
	var center: float = (h_texels - 1) * 0.5
	var arm: int = maxi(int(center) - 3, 2)
	for yy in range(2, h_texels - 2):
		var dy: float = absf(float(yy) - center)
		if dy > float(arm):
			continue
		var x: int = 9 - int(round(dy * 0.55)) ## uç merkezde (sağda), kollar geriye
		for off in range(2):
			if x - off >= 0 and x - off < TILE_LEN:
				img.set_pixel(x - off, yy, arrow)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tile_cache[h_texels] = tex
	return tex
