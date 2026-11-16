extends RefCounted

## Corvina birliklerinin dünya efektleri (2026-11-16): ok, ateş sütunu (Kemik Büyücüsü), yeniden doğuş oku. Kasterde ve diğer
## oyuncularda AYNI fonksiyon çağrılır (MP iki-yer kuralı): kaster send_player_vfx "necro_fx" {t, to, ghost} yollar, network_manager.gd
## o dalda buradaki spawn_* ile aynısını kurar (owner_player null = kozmetik, hasar yok).
## Dokular: assets/pets/necro_iskelet/fx/*.png (tools/necro_iskelet/build_frames.py), boyları NecroUnits.FX.

const NecroUnits := preload("res://scripts/necro_units.gd")
const ArrowScript := preload("res://scripts/necro_arrow.gd")

const FX_FPS := 14.0

static var _frames_cache: Dictionary = {}


## Tek satırlık şeritten (NecroUnits.FX[key]) bir kez SpriteFrames kurar.
static func strip_frames(key: String) -> SpriteFrames:
	if _frames_cache.has(key):
		return _frames_cache[key]
	var row: Array = NecroUnits.FX[key]
	var tex: Texture2D = load(row[0])
	var sf := SpriteFrames.new()
	sf.add_animation(&"play")
	sf.set_animation_loop(&"play", false)
	sf.set_animation_speed(&"play", FX_FPS)
	for i in int(row[3]):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * int(row[1]), 0, int(row[1]), int(row[2]))
		sf.add_frame(&"play", at)
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")
	_frames_cache[key] = sf
	return sf


## Ok yönü karesi: şerit sırası e, se, s, ne, n -> doğu karesini döndürüp kullanırız (5 karenin ilki).
static func arrow_texture(ghost: bool) -> Texture2D:
	var key: String = "ghost_arrow" if ghost else "arrow"
	var sf: SpriteFrames = strip_frames(key)
	return sf.get_frame_texture(&"play", 0)


static func _one_shot(tree: SceneTree, key: String, pos: Vector2, bottom_anchor: bool) -> AnimatedSprite2D:
	if tree == null or tree.current_scene == null:
		return null
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = strip_frames(key)
	spr.scale = Vector2.ONE * NecroUnits.WORLD_SCALE
	spr.z_as_relative = false
	spr.z_index = 2
	if bottom_anchor:
		## ayak noktası = şeridin alt kenarı
		spr.offset = Vector2(0.0, -float(NecroUnits.FX[key][2]) * 0.5)
	tree.current_scene.add_child(spr)
	spr.global_position = pos
	spr.animation_finished.connect(spr.queue_free)
	spr.play(&"play")
	return spr


## Kemik Büyücüsü ateş sütunu (hedefin ayağında).
static func spawn_fire(tree: SceneTree, pos: Vector2) -> void:
	_one_shot(tree, "fire", pos, true)


## Yeniden doğuş oku (büyücü bir iskeleti diriltince, ayak noktasında).
static func spawn_reborn(tree: SceneTree, pos: Vector2) -> void:
	_one_shot(tree, "reborn", pos, true)


## Ok: owner_player verilirse hasar verir (kaster), null ise yalnız uçar (kozmetik kopya).
static func spawn_arrow(tree: SceneTree, from: Vector2, to: Vector2, ghost: bool, owner_player: Node = null,
		damage: float = 0.0, pierce: int = 0, max_dist: float = 360.0) -> Node2D:
	if tree == null or tree.current_scene == null:
		return null
	var a: Node2D = ArrowScript.new()
	a.setup(from, to, ghost, owner_player, damage, pierce, max_dist)
	tree.current_scene.add_child(a)
	return a
