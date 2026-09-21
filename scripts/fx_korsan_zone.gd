extends Node2D

## Korsan'ın Bombardıman (R) alanı: kanal boyunca (8sn) Korsan'ın çevresinde bombardıman yarıçapını gösteren pixel-art
## uyarı çemberi. Dıştaki kalın turuncu kesikli halka döner ("yürüyen karıncalar"), içteki ince kırmızı halka ters döner,
## halkada eşit aralıklı küçük bomba/elmas işaretleri ve 4 yönde büyük köşe çentikleri var. Açılırken merkezden yarıçapa
## genişler, son 0.7sn'de yanıp sönerek kapanır. Player'ın (yerel) ya da RemotePlayer'ın (uzak) ÇOCUĞU olarak doğar;
## yarıçap/süre KorsanFxMath'tan (player.gd ile paylaşılan tek kaynak).

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const KorsanFxMath := preload("res://scripts/korsan_fx_math.gd")

const OPEN_TIME := 0.35
const BLINK_TIME := 0.7
const BODY_CENTER := Vector2(0, 4)

var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 0 ## negatif z harita altında kalır (bkz. weapon.gd gölge notu)
	show_behind_parent = true ## alan karakterin ARKASINDA çizilir


func _process(delta: float) -> void:
	_t += delta
	if _t >= KorsanFxMath.BOMBARDMENT_DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var total: float = KorsanFxMath.BOMBARDMENT_DURATION
	var open: float = clampf(_t / OPEN_TIME, 0.0, 1.0)
	open = 1.0 - (1.0 - open) * (1.0 - open)
	var remaining: float = total - _t
	if remaining < BLINK_TIME and int(_t * 12.0) % 2 == 0:
		return ## kapanırken yanıp söner
	var r: float = KorsanFxMath.BOMBARDMENT_RADIUS * open
	var texel: float = PixelDraw.TEXEL
	## Dış halka: kalın turuncu kesikli, saat yönünde kayar
	PixelDraw.ring(self, BODY_CENTER, r, Color(1.0, 0.55, 0.12), 2, 7, 6, _t * 18.0)
	## İç halka: ince kırmızı, ters yönde kayar
	PixelDraw.ring(self, BODY_CENTER, r - texel * 7.0, Color(0.85, 0.2, 0.08), 1, 2, 6, -_t * 26.0)
	## Halkada 16 eşit aralıklı işaret: bomba (elmas) - yavaşça döner
	for k in range(16):
		var a: float = float(k) * TAU / 16.0 + _t * 0.35
		var p: Vector2 = BODY_CENTER + Vector2(cos(a), sin(a)) * r
		var big: bool = k % 4 == 0
		var col: Color = Color(1.0, 0.85, 0.35) if big else Color(1.0, 0.6, 0.15)
		PixelDraw.px(self, p, 3 if big else 2, col)
		if big:
			for o in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
				PixelDraw.px(self, p + o * texel, 1, Color(0.8, 0.18, 0.08))
