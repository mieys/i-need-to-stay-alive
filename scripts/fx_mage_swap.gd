extends AnimatedSprite2D

## Büyücü Kız her Q ile TEMEL yeteneğini değiştirdiğinde (bkz. player.gd
## _skill_buyucu_switch_variation) üstünde bir kez oynayan gösterge efekti.
## Kullanıcı isteği ("efekt sistemi"): "bu efekt büyücü kız her Q ile
## yeteneklerini değiştirdiğinde üstünde gösterilecek o kadar" - tek seferlik,
## süreye/duruma bağlı değil.

func _ready() -> void:
	animation_finished.connect(queue_free)
	position = Vector2.ZERO
	play("swap")
