extends AnimatedSprite2D

## Kullanıcı isteği ("efekt sistemi" - kan.png): "Bu efektler rasgele olarak
## karakter kalkansızken hasar aldığında bedeninin rasgele kısımlarından
## çıkacak. Her hasar alışta bir kan efekti çıkacak ve rasgele konumda
## rasgele 4 efektten biri olarak çıkacak." - bkz. player.gd take_damage()
## "not shield_absorbed_hit" dalı (no_shield_damage_sound ile AYNI koşul -
## kalkanın HİÇ emmediği, cana gerçekten işleyen isabetler).
##
## Kaster/hedef zaten AYNI kişi olduğu için (kendi hasarını kendi client'ı
## işliyor) _play_and_broadcast_skill_fx ile diğer istemcilere de gidiyor -
## her istemci varyantı/konumu KENDİ tarafında bağımsız rastgele seçiyor
## (tıpkı donma efektindeki freeze1/2/3 seçimi gibi); bu tek karelik, atılan
## bir kozmetik için (CLAUDE.md'nin uyardığı "kaster ekranında doğru diğerinde
## eski/yok" hatasının aksine burada paylaşılan bir oyun durumu YOK) fark
## edilmeyecek kadar önemsiz bir sapma.

const VARIANTS := ["blood1", "blood2", "blood3", "blood4"]
const SCATTER_RADIUS := 12.0


func _ready() -> void:
	animation_finished.connect(queue_free)
	var variant: String = VARIANTS[randi() % VARIANTS.size()]
	position = Vector2(randf_range(-SCATTER_RADIUS, SCATTER_RADIUS), randf_range(-SCATTER_RADIUS, SCATTER_RADIUS))
	play(variant)
