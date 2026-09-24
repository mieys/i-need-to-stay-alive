extends Node2D
class_name AssasinShadowHitFx

## Assasin Çocuk'un ULTİ'si (Gölge Hücumu) her yaratığa vurduğunda çıkan GÖLGE HANÇER KESİĞİ.
## Kullanıcı isteği (2026-09-24): "pixel tarzda yeniden tasarla, sonrasında spritesheete dönüştür performans sorunu
## olmaması için" - eski sürüm her karede _draw() ile yumuşak draw_line/draw_rect çiziyordu. Artık
## tools/gen_assasin_hit_fx.py'nin pişirdiği 9 karelik (30 fps, ~0.3 sn) animasyon TEK bir AnimatedSprite2D ile
## oynatılır: isabet parlaması -> iki çapraz hilal kesik sırayla çizilir -> incelip piksel piksel kopar, hamle yönüne
## saçılan gölge kıymıkları ve sönen gölge dumanı. 1 sanat pikseli = TEXEL dünya birimi (48x48 piksel dili).
## YÖN: sprite +x'e (hamle yönüne) bakar - çağıran rotation'ı DOĞRUDAN hamle açısı yapar (player.gd
## _spawn_assasin_dash_hit_fx ve network_manager.gd "melee_hit" aynı açıyı kullanır; eskiden yerelde +45° ekleniyor,
## diğer oyuncularda eklenmiyordu - efekt iki ekranda farklı açıda görünüyordu).

const TEXEL := 1.212
const FRAMES := preload("res://assets/fx/assasin/shadow_hit_frames.tres")
const SAFETY_LIFETIME := 1.0

var _anim: AnimatedSprite2D = null


func _ready() -> void:
	_anim = AnimatedSprite2D.new()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.sprite_frames = FRAMES
	_anim.scale = Vector2.ONE * TEXEL
	add_child(_anim)
	_anim.play(&"hit")
	_anim.animation_finished.connect(queue_free)
	get_tree().create_timer(SAFETY_LIFETIME, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())
