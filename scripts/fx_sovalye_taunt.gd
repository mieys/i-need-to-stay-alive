extends Node2D

## Şovalye Adam Q - Kışkırtma (kullanıcı isteği 2026-09-25: "tüm yaratıkların dikkatini üstüne çekiyormuş gibi görünecek
## açık kırmızı tonlarda bir efekt"). tools/gen_sovalye_fx.py sayfaları:
##  - taunt_burst (0.7 sn, tek sefer): dışa yayılan savaş çığlığı halkaları + her yönden Şovalye'ye İÇERİ koşan oklar +
##    başının üstünde "!".
##  - taunt_aura (döngü): kışkırtma süresince ayak altında nabız atan elips + içeri süzülen oklar.
## Toplam ömür = kışkırtma süresi (player.gd PALADIN_TAUNT_DURATION, 5 sn), son FADE_TIME'da söner.
## Kaster'da player.gd _play_and_broadcast_skill_fx ile, diğer oyuncularda AYNI sahne "skill_scene" ile oluşur.
## Zemin efekti: karakterin ARKASINDA çizilir (show_behind_parent - negatif z haritanın altına düşerdi).

const BurstFrames := preload("res://assets/fx/sovalye/taunt_burst_frames.tres")
const AuraFrames := preload("res://assets/fx/sovalye/taunt_aura_frames.tres")
const TEXEL := 1.212
## Ayak altı (karakter kökünden +33 yerel birim) - sayfalardaki zemin merkezi bu noktaya oturur.
const GROUND_Y := 33.0
## Sayfalarda zemin merkezinin karenin ortasına göre konumu (sanat pikseli): burst 176x120 (88,80), aura 110x60 (55,30).
const BURST_GROUND_ART := Vector2(0.0, 20.0)
const AURA_GROUND_ART := Vector2(0.0, 0.0)
const LIFETIME := 5.0 ## = player.gd PALADIN_TAUNT_DURATION
const FADE_TIME := 0.4

var _sprite: AnimatedSprite2D = null
var _t: float = 0.0


func _ready() -> void:
	z_index = 0
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.show_behind_parent = true
	_sprite.scale = Vector2.ONE * TEXEL
	add_child(_sprite)
	_set_frames(BurstFrames, "burst", BURST_GROUND_ART)
	_sprite.animation_finished.connect(_on_burst_finished)


func _set_frames(frames: SpriteFrames, anim: StringName, ground_art: Vector2) -> void:
	_sprite.sprite_frames = frames
	_sprite.position = Vector2(0.0, GROUND_Y) - ground_art * TEXEL
	_sprite.play(anim)


func _on_burst_finished() -> void:
	if _sprite.animation == &"burst":
		_set_frames(AuraFrames, "loop", AURA_GROUND_ART)


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	modulate.a = clampf((LIFETIME - _t) / FADE_TIME, 0.0, 1.0)
