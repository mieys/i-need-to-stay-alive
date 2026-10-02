extends AnimatedSprite2D

## Kullanıcı isteği ("efekt sistemi" - diriltme.png): "bir karakter öldüğünde
## arkadaşları onu diriltmeye çalıştığında diritme süresi boyunca ölen
## karakterin üstünde TERSTEN başa doğru oynatılacak, diriltme yarıda
## kesilirse efekt de diritlme barıyla beraber eski haline dönmeli... süresi
## tam olarak müttefik diriltme süresiyle eşdeğer olacak müttefik
## diriltilince efektteki spritesheetler de bitmiş olmalı, yarıda kesilirse
## ve diriltme barı eksilmeye başlarsa bar ileri doğru sarılıp sona gelerek
## barla beraber kapanır."
##
## Bu "zamanı geri alma" hissi kare indeksini doğrudan diriltme oranından
## (get_revive_progress_ratio, 0=daha yeni düştü, 1=diriltme tamam) TÜRETEREK
## elde edilir - oran=0 iken SON kare (29. kare), oran=1 iken İLK kare (0.
## kare) gösterilir. Bu formül tamamen REAKTİF olduğu için oran hangi yöne
## giderse gitsin (ilerlerken/gerilerken) otomatik doğru davranır, ayrı bir
## "geri sar" durumuna gerek yok.

const FRAME_COUNT := 29
const OverheadBarScript := preload("res://scripts/overhead_bar.gd")
## Kullanıcı isteği (2026-10-02): "diriltilirkenki saat efektinin de karakterin can ve kalkan barının üst kısımlarında
## olmasını istiyorum durum etkisi gibi görünmesi için" - gövdenin ortası yerine can/kalkan barının (yerdeyken gizli) hemen
## üstünde küçük bir durum simgesi. Ebeveyn: Player/RemotePlayer kökü ya da Hadime cesedi (ikisi de aynı yerel ölçekte).
const STATUS_SCALE := 0.5
const STATUS_GAP := 2.0
const FRAME_PX := 64.0

func _ready() -> void:
	scale = Vector2.ONE * STATUS_SCALE
	position = Vector2(0.0, OverheadBarScript.CHARACTER_Y_OFFSET - STATUS_GAP - FRAME_PX * STATUS_SCALE * 0.5)
	animation = "all"
	frame = FRAME_COUNT - 1


func set_progress(ratio: float) -> void:
	var idx: int = int(round((1.0 - clampf(ratio, 0.0, 1.0)) * float(FRAME_COUNT - 1)))
	frame = clampi(idx, 0, FRAME_COUNT - 1)
