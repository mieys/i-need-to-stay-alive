extends Node2D

## Assasin Çocuk ULTİ (Gölge Hücumu) tek seferlik sayfa efekti: hedefteki kesik (ult_cut) ya da cast/dönüş gölge patlaması
## (ult_blink). Kurulum ve ağ kopyası scripts/assasin_ult_fx.gd'de - burası sadece oynatıcı. Sayfalar +x'e (hamle yönüne)
## bakar: çağıran rotation'ı hamle açısı yapar, `flip` kesiği aynalar (iki ekranda AYNI değer gider).
## Gece ışığı: night_glow_catalog.gd BY_SCRIPT (bu betiğin yolu).

const TEXEL := 1.212
const SAFETY_LIFETIME := 1.0

var frames: SpriteFrames = null
var flip: bool = false


func _ready() -> void:
	if frames == null:
		queue_free()
		return
	var anim := AnimatedSprite2D.new()
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim.sprite_frames = frames
	anim.scale = Vector2.ONE * TEXEL
	anim.flip_v = flip
	add_child(anim)
	anim.play(frames.get_animation_names()[0])
	anim.animation_finished.connect(queue_free)
	get_tree().create_timer(SAFETY_LIFETIME, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())
