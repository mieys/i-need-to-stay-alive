extends AnimatedSprite2D

## Kullanıcı isteği ("efekt sistemi" - kalp.png): "bu efekt bir karakter
## diğerini dirilttikten SONRA diriltilen kişinin nickinin üzerinde 3 saniye
## boyunca aktif olacak." - "appear" animasyonu (9 kare) bir kez oynar, kalan
## süre boyunca son karede sabit kalır, TOPLAM 3 saniye sonra kendini siler.

const TOTAL_DURATION := 3.0

func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	play("appear")
	get_tree().create_timer(TOTAL_DURATION).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)


func _on_animation_finished() -> void:
	pause()
