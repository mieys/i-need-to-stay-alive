extends AnimatedSprite2D

## Delirmiş yaratığın başının üstünde dönen hipnoz sarmalı + iki baş dönmesi yıldızı (tools/gen_cadi_fx.py "mad_status" -
## 20x16, 8 kare döngü). Cadı'nın Delilik İksiri (enemy.gd apply_madness) kullanır. Host başlatır, broadcast_enemy_vfx
## "mad_start"/"mad_stop" ile diğer istemcilere yayınlanır. Korku göstergesiyle (fx_fear_status.gd) aynı yaşam döngüsü.

const CadiMath := preload("res://scripts/cadi_math.gd")
const TEXEL := 1.212 ## 1 sanat pikseli = bu kadar dünya birimi (ebeveyn ölçeğinden bağımsız tutulur)
const HEAD_RATIO := 0.45 ## bkz. fx_fear_status.gd

var _timer: float = 0.0
var _parent_body: Node2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_frames = CadiMath.frames("mad_status")
	_parent_body = get_parent() as Node2D
	if _parent_body:
		var ps: float = absf(_parent_body.global_scale.x)
		scale = Vector2.ONE * (TEXEL / (ps if ps > 0.01 else 1.0))
	_update_position()
	play(&"loop")


func setup(duration: float) -> void:
	_timer = maxf(_timer, duration)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0 or (is_instance_valid(_parent_body) and _parent_body.get("is_dead") == true):
		queue_free()
		return
	_update_position()


func _update_position() -> void:
	if is_instance_valid(_parent_body) and _parent_body.has_method("get_overhead_bar_offset"):
		position = Vector2(0, roundf(_parent_body.get_overhead_bar_offset() * HEAD_RATIO))
