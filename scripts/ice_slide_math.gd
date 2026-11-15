extends RefCounted

## BUZ KAYMASI (madde 680, kullanıcı isteği 2026-11-14): Ayaz Dağı'ndaki donmuş göl / dere buzunun ÜSTÜNDE oyuncu girdisine anında uymaz,
## hız vektörü hedef hıza yavaşça yaklaşır: yön değiştirince eski yöne kayar, bırakınca sürünerek durur (sağa-sola dönüşte "buzda kayıyor" hissi).
## Saf fonksiyon: player.gd her fizik karesinde çağırır, kuklada (remote_player.gd) hesap YOK - konum zaten ağdan gelir, kayma konumda görünür.
const ACCEL_TIME := 0.6 ## girdi varken: hedef hıza (tam hız) ulaşma süresi, sn (ters yöne dönüş ~2 x bu)
const FRICTION_TIME := 1.3 ## girdi yokken: tam hızdan durma süresi, sn
const MIN_SPEED := 40.0 ## hız taban değeri (px/sn): bundan hızlı yürüyene bile ivme hesabı hıza göre oranlanır, yavaş karakterde kaymaz saçmalamasın


## vel: şu anki kayma hızı, target: girdi x hareket hızı (buzsuz hedef hız), speed: karakterin tam hareket hızı.
static func step(vel: Vector2, target: Vector2, delta: float, speed: float) -> Vector2:
	var ref: float = maxf(speed, MIN_SPEED)
	var rate: float = ref / ACCEL_TIME if target.length_squared() > 1.0 else ref / FRICTION_TIME
	return vel.move_toward(target, rate * delta)
