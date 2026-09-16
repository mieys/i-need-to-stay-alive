extends AnimatedSprite2D
class_name StunStarsFx

## Yaratıklar/oyuncular sersemletildiğinde (stun) başlarının üstünde çıkan
## efekt - enemy.gd apply_stun VE player.gd apply_stun, ikisi de AYNI
## StunStatusFxScene'i (bu sahne) kullanıyor (bkz. oralardaki _spawn_stun_
## status_fx/_remove_stun_status_fx).
##
## DÜZELTME (kullanıcı isteği: "efekt sistemi" - stun.png): eskiden burada
## _draw() ile elle çizilen, dönen 3 piksel-yıldız vardı (bkz. yorum
## geçmişi). Artık fx_stun_new_frames.tres'teki 8 karelik döngü kullanılıyor
## - davranış (setup(duration), overhead_bar'ın hemen altında konumlanma)
## AYNI kaldı, sadece görsel kaynağı değişti.

var _active_duration: float = 0.0
var _active_timer: float = 0.0
var _parent_body: Node2D = null


func _ready() -> void:
	_parent_body = get_parent() as Node2D
	_update_position()
	play("loop")


func setup(duration: float) -> void:
	_active_duration = duration
	_active_timer = duration


func _process(delta: float) -> void:
	_active_timer -= delta
	if _active_timer <= 0.0:
		queue_free()
		return
	_update_position()


func _update_position() -> void:
	if is_instance_valid(_parent_body) and _parent_body.has_method("get_overhead_bar_offset"):
		# Overhead bar'ın hemen altında, kafanın hemen üstünde dursun diye
		# (bkz. eski _draw tabanlı sürümün AYNI yerleşimi).
		position = Vector2(0, _parent_body.get_overhead_bar_offset() + 14.0)
