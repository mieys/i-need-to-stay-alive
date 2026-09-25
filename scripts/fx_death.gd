extends AnimatedSprite2D

## Kullanıcı isteği ("efekt sistemi" - ölüm.png): "bu efekt karakter
## öldüğünde üstünde yavaşça çıkacak ve son 5 frame karakter ölü olduğu
## sürece looplu bir biçimde döngüde kalacak. fazla hızlı bir animasyon
## olmamalı. Karakter dirilince bu efekt kalkar." - "intro" bir kez oynar
## (3 kare, yavaş), bitince "loop" (son 5 kare, fx_death_frames.tres'te
## loop=1) devralır ve karakter tekrar canlanana kadar (bkz. player.gd/
## remote_player.gd _update_death_status_fx - is_dead false olunca bu
## node'u queue_free eder) sürer.

## Kullanıcı isteği (2026-09-25): "ölünce üstteki ölüm efekti 1 saniye kalsın sonra görünmesin" - düğüm (ölü kaldıkça)
## yerinde durur ki player.gd/remote_player.gd _update_death_status_fx her karede yenisini kurmasın; sadece VISIBLE_TIME
## sonunda FADE_TIME'da söner ve gizlenir.
const VISIBLE_TIME := 1.0
const FADE_TIME := 0.25

var _t: float = 0.0


func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	position = Vector2.ZERO
	play("intro")


func _process(delta: float) -> void:
	_t += delta
	var fade_start: float = VISIBLE_TIME - FADE_TIME
	if _t >= fade_start:
		modulate.a = clampf(1.0 - (_t - fade_start) / FADE_TIME, 0.0, 1.0)
	if _t >= VISIBLE_TIME:
		visible = false
		stop()
		set_process(false)


func _on_animation_finished() -> void:
	if animation == "intro":
		play("loop")
