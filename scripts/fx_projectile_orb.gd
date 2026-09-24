extends Node2D

## Menzilli yaratık mermisinin (enemy_projectile.gd) görseli - aile rengine (glow_color: Lich/Demon/Röntgen/İblis)
## boyanan küçük bir enerji küresi.
## Kullanıcı isteği (2026-09-23): "mermileri pixel tarzda yeniden tasarlar mısın" - eskiden üç pürüzsüz draw_circle
## (yumuşak kenarlı ışıma) idi; artık karakter dokusunun piksel boyutunda (PixelDraw.TEXEL, 1 sanat pikseli
## detay - bkz. hafıza "Pixel density 48x48") katmanlı piksel küre + uçuş yönünün tersine solan 3 piksellik iz.
## Çizim bir kez yapılır (mermi sabit yönde uçar), her karede yeniden çizilmez.

const PixelDraw := preload("res://scripts/pixel_draw.gd")

@export var glow_color: Color = Color(1.0, 0.55, 0.15, 1.0)
## Uçuş yönü (enemy_projectile.gd _ready'de atanır) - izin hangi tarafa düşeceği.
var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	var T: float = PixelDraw.TEXEL
	var c: Color = glow_color
	var dir: Vector2 = direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT
	## İz: kürenin arkasında, gittikçe küçülüp solan pikseller.
	for i in range(3):
		var d: float = (6.0 + float(i) * 2.5) * T
		var a: float = 0.55 - float(i) * 0.17
		PixelDraw.px(self, -dir * d, 2 if i == 0 else 1, Color(c.r, c.g, c.b, a))
	## Dış hale -> gövde -> parlak iç -> beyaz çekirdek.
	PixelDraw.disc(self, Vector2.ZERO, 5.0 * T, Color(c.r, c.g, c.b, 0.3))
	PixelDraw.disc(self, Vector2.ZERO, 3.5 * T, Color(c.r, c.g, c.b, 0.85))
	var hot: Color = c.lightened(0.45)
	PixelDraw.disc(self, Vector2.ZERO, 2.0 * T, Color(hot.r, hot.g, hot.b, 0.95))
	PixelDraw.px(self, Vector2.ZERO, 2, Color(1.0, 1.0, 1.0, 0.95))
	## Hale üstünde dört köşegen kıvılcım pikseli.
	for k in range(4):
		var ang: float = PI * 0.25 + float(k) * PI * 0.5
		PixelDraw.px(self, Vector2(cos(ang), sin(ang)) * 5.0 * T, 1, Color(hot.r, hot.g, hot.b, 0.5))
