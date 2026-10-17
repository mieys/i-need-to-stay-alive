extends RefCounted

## Pişirilmiş efekt oynatıcı (madde 215): kare kare `_draw` + parçacık benzetimi yapan efektler `tools/fx_bake.ps1` ile
## SpriteFrames sayfasına pişirilir (assets/fx/baked/<ad>_frames.tres, merkez = efekt orijini); bu yardımcı o sayfayı
## efekt düğümünün altında TEK AnimatedSprite2D olarak oynatır. class_name yok (preload ile kullanılır).

static func attach(host: Node2D, frames: SpriteFrames, texel: float = 1.0, smooth: bool = true) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.centered = true
	s.scale = Vector2(texel, texel)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if smooth else CanvasItem.TEXTURE_FILTER_NEAREST
	host.add_child(s)
	s.play(&"play")
	return s
