extends AnimatedSprite2D

## Kullanıcı isteği ("efekt sistemi" - ölüm.png): "bu efekt karakter
## öldüğünde üstünde yavaşça çıkacak ve son 5 frame karakter ölü olduğu
## sürece looplu bir biçimde döngüde kalacak. fazla hızlı bir animasyon
## olmamalı. Karakter dirilince bu efekt kalkar." - "intro" bir kez oynar
## (3 kare, yavaş), bitince "loop" (son 5 kare, fx_death_frames.tres'te
## loop=1) devralır ve karakter tekrar canlanana kadar (bkz. player.gd/
## remote_player.gd _update_death_status_fx - is_dead false olunca bu
## node'u queue_free eder) sürer.

func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	position = Vector2.ZERO
	play("intro")


func _on_animation_finished() -> void:
	if animation == "intro":
		play("loop")
