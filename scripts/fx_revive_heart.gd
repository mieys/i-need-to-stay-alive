extends AnimatedSprite2D

## Kullanıcı isteği ("efekt sistemi" - kalp.png): "bu efekt bir karakter
## diğerini dirilttikten SONRA diriltilen kişinin nickinin üzerinde 3 saniye
## boyunca aktif olacak." - "appear" animasyonu (9 kare) bir kez oynar, kalan
## süre boyunca son karede sabit kalır, TOPLAM 3 saniye sonra kendini siler.
## 2026-10-13 (kullanıcı: "kalp efektlerinin looplu olması gerekiyor ama bir kez oynatılıp duruyorlar"): animasyon artık DÖNGÜDE (kareler kendi
## içinde döngü: çerçeve -> noktalar -> kalp dolar -> parlar) ve 3 sn boyunca döner, son 0,4 sn solarak biter. Aynı sahne diriltmede, Anka
## Mührü'nde ve arkadaştan altın hediyesi alınca (player.gd play_heart_fx) kullanılır.

const TOTAL_DURATION := 3.0
## 2026-10-10 (kullanıcı: "kalpler oynatılmıyor"): animasyon oynuyordu ama kalp 50 px karede ~14 px'ti ve -165'te (karakterler %15 küçüldükten sonra
## can çubuğunun ~65 px üstünde, ekran kenarına yakın) zor seçiliyordu. Sahne artık -88 + x1,75 (can çubuğunun hemen üstü); uzak oyuncu kopyasında
## isim yazısının üstüne çıkarılır (remote_player.gd REMOTE_HEART_Y).

const FADE_TIME := 0.4


func _ready() -> void:
	play("appear")
	var tw: Tween = create_tween()
	tw.tween_interval(TOTAL_DURATION - FADE_TIME)
	tw.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(queue_free)
