extends Node2D

## Oakley Koruyucu Büyü (R) kullanım anı - Oakley'nin KENDİ üstünde: ayak altında açılan altın mühür + yükselen yaprak
## girdabı (tools/gen_oakley_fx.py "ward_cast", 12 kare, tek sefer). Kullanıcı isteği 2026-09-25 (Oakley efektlerinin
## pixel yeniden tasarımı) - eskiden Melek'le paylaşılan fx_wave_beam ışını + genel yeşil CPUParticles patlaması vardı.
## player.gd _skill_oakley_bond bunu _play_and_broadcast_skill_fx ile kurar (yerel + diğer oyuncular tek çağrıda).

const FRAMES := preload("res://assets/fx/oakley/ward_cast_frames.tres")
const TEXEL := 1.212
## fx_oakley_leaf_barrier.gd ile aynı kare/ayak hizası (72x96, ayak (36,84) = kök +33).
const CENTER := Vector2(0.0, 33.0 - 36.0 * TEXEL)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var s := AnimatedSprite2D.new()
	s.sprite_frames = FRAMES
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * TEXEL
	s.position = CENTER
	add_child(s)
	s.animation_finished.connect(queue_free)
	s.play(&"cast")
