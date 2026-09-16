extends Node2D
class_name FxArcaneImpact

## Arcane Lanet kafatası düşmana çarptığında oluşan mor piksel patlama animasyonu.

var anim_sprite: AnimatedSprite2D = null
var elapsed: float = 0.0

func _ready() -> void:
	z_index = 50
	anim_sprite = AnimatedSprite2D.new()
	anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_loop("default", false)
	frames.set_animation_speed("default", 16.0)
	
	var sheet: Texture2D = preload("res://assets/generated/fx_arcane_impact_burst_anim.png")
	if sheet:
		for i in range(6):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * 48, 0, 48, 48)
			frames.add_frame("default", at)
			
	anim_sprite.sprite_frames = frames
	anim_sprite.scale = Vector2(1.2, 1.2)
	add_child(anim_sprite)
	anim_sprite.play("default")
	anim_sprite.animation_finished.connect(func(): queue_free())

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > 0.6:
		queue_free()
