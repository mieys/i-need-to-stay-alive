extends Node2D

## Korsan'ın Bombardıman (R) alanı: kanal boyunca (8sn) Korsan'ın çevresinde bombardıman yarıçapını gösteren pixel-art
## uyarı çemberi - dıştaki kalın turuncu kesikli halka "yürüyen karıncalar" gibi kayar, içteki ince kırmızı halka ters
## yönde kayar, halkada eşit aralıklı 16 bomba/elmas işareti. Açılırken merkezden yarıçapa genişler, son 0.7sn'de yanıp
## sönerek kapanır. Player'ın (yerel) ya da RemotePlayer'ın (uzak) ÇOCUĞU olarak doğar; yarıçap/süre KorsanFxMath'tan.
## Kullanıcı isteği (2026-09-24): Korsan'ın TÜM efektleri spritesheet - eskiden her karede ~2000 draw_rect'lik iki halka
## + işaretler pixel_draw.gd ile çiziliyordu. Artık tools/gen_korsan_fx_sprites.py'nin pişirdiği 6 karelik kusursuz
## döngü ("loop"); açılma ölçekle, kapanış görünürlükle yapılır (karede ek çizim yok).

const KorsanFxMath := preload("res://scripts/korsan_fx_math.gd")
const ZONE_FRAMES := preload("res://assets/fx/korsan/zone_frames.tres")
const TEXEL := 1.212 ## PixelDraw.TEXEL

const OPEN_TIME := 0.35
const BLINK_TIME := 0.7
const BODY_CENTER := Vector2(0, 4)

var _t: float = 0.0
var _anim: AnimatedSprite2D = null


func _ready() -> void:
	z_index = 0 ## negatif z harita altında kalır (bkz. weapon.gd gölge notu)
	show_behind_parent = true ## alan karakterin ARKASINDA çizilir
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = ZONE_FRAMES
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.position = BODY_CENTER
	_anim.show_behind_parent = true
	_anim.scale = Vector2.ZERO
	add_child(_anim)
	_anim.play("loop")


func _process(delta: float) -> void:
	_t += delta
	var total: float = KorsanFxMath.BOMBARDMENT_DURATION
	if _t >= total:
		queue_free()
		return
	var open: float = clampf(_t / OPEN_TIME, 0.0, 1.0)
	open = 1.0 - (1.0 - open) * (1.0 - open)
	_anim.scale = Vector2.ONE * TEXEL * open
	var remaining: float = total - _t
	_anim.visible = not (remaining < BLINK_TIME and int(_t * 12.0) % 2 == 0) ## kapanırken yanıp söner
