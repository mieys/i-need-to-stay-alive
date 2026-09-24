extends Node2D

## Korsan'ın Bombardıman'ı (R) tek bir mermisi: yerde kırmızı-turuncu pixel hedef işareti (daralan kesikli halka + köşe
## çentikleri + ortada yanıp sönen artı), gökten dumanlı bir top mermisi iner, tam STRIKE_FALL_TIME sonunda patlar
## (fx_korsan_explosion.tscn). player.gd hasarı AYNI süre sonra uygular (KorsanFxMath.STRIKE_FALL_TIME tek kaynak).
## Diğer istemcilerde de network_manager.gd "hitscan_impact" ile bu sahne doğar; setup(radius, color) patlama yarıçapını
## verir.
## Kullanıcı isteği (2026-09-24): Korsan'ın TÜM efektleri spritesheet - eskiden her karede halka + gölge dither'ı + gülle
## ASCII sanatı + ateş izi pixel_draw.gd ile çiziliyordu. Artık tools/gen_korsan_fx_sprites.py'nin pişirdiği 8 karelik
## "play" animasyonu (tam STRIKE_FALL_TIME sürer), ardından patlama sahnesi.

const KorsanFxMath := preload("res://scripts/korsan_fx_math.gd")
const EXPLOSION_SCENE := preload("res://scenes/fx_korsan_explosion.tscn")
const STRIKE_FRAMES := preload("res://assets/fx/korsan/strike_frames.tres")
const TEXEL := 1.212 ## PixelDraw.TEXEL
## Karede hedef merkezi (patlama noktası) karenin ortasının 50 sanat pikseli altında (bkz. gen_korsan_fx_sprites.py
## strike_frames "anchor") - node orijini hedef merkezine denk gelsin.
const SHEET_OFFSET := Vector2(0, -50)

var blast_radius: float = KorsanFxMath.STRIKE_RADIUS
var _t: float = 0.0
var _exploded: bool = false
var _anim: AnimatedSprite2D = null


func setup(radius: float, _color: Color = Color.WHITE) -> void:
	blast_radius = radius
	_apply_scale()


func _ready() -> void:
	z_index = 11
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = STRIKE_FRAMES
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.offset = SHEET_OFFSET
	add_child(_anim)
	_apply_scale()
	_anim.play("play")


func _apply_scale() -> void:
	if _anim:
		_anim.scale = Vector2.ONE * TEXEL * (blast_radius / KorsanFxMath.STRIKE_RADIUS)


func _process(delta: float) -> void:
	_t += delta
	if not _exploded and _t >= KorsanFxMath.STRIKE_FALL_TIME:
		_exploded = true
		if _anim:
			_anim.queue_free()
			_anim = null
		var boom: Node2D = EXPLOSION_SCENE.instantiate() as Node2D
		add_child(boom)
		boom.position = Vector2.ZERO
		if boom.has_method("setup"):
			boom.setup(blast_radius, Color(1.0, 0.6, 0.2))
	## patlama efekti kendi ömrünü bitirince (çocuk silinince) bu düğüm de gider
	if _exploded and get_child_count() == 0:
		queue_free()
