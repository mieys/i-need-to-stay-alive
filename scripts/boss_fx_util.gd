extends RefCounted

## Boss efektleri için ortak yardımcılar (2026-10-09, Balkabağı Kafa vb.): yatay şerit spritesheet'ten SpriteFrames kurar (önbellekli).

static var _cache: Dictionary = {}


## `sheet` tek satırlı yatay şerit, her kare frame_w x frame_h. Önbellek anahtarı: yol + biçim.
static func frames_from_strip(path: String, frame_w: int, frame_h: int, anim: StringName, fps: float, loop: bool, first: int = 0, count: int = -1) -> SpriteFrames:
	var key: String = "%s|%d|%d|%s|%s|%s|%d|%d" % [path, frame_w, frame_h, anim, fps, loop, first, count]
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = load(path) as Texture2D
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	if tex != null:
		var n: int = maxi(int(tex.get_width() / frame_w), 1)
		var last: int = n if count < 0 else mini(first + count, n)
		for i in range(first, last):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * frame_w, 0, frame_w, frame_h)
			sf.add_frame(anim, at)
	_cache[key] = sf
	return sf


## Tek seferlik animasyon efekti (bitince kendini siler).
static func play_once(parent: Node, world_pos: Vector2, frames: SpriteFrames, anim: StringName, scale_mult: float = 1.0, z: int = 12) -> Node2D:
	if parent == null or frames == null:
		return null
	var holder := Node2D.new()
	holder.z_index = z
	parent.add_child(holder)
	holder.global_position = world_pos
	var sp := AnimatedSprite2D.new()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.sprite_frames = frames
	sp.scale = Vector2.ONE * scale_mult
	holder.add_child(sp)
	sp.animation_finished.connect(holder.queue_free)
	sp.play(anim)
	return holder
