extends Node2D

## Yaratık yeteneklerinin (bkz. enemy_abilities.gd) TEK SEFERLİK / süreli sprite efektlerinin ortak oynatıcısı -
## hayalet kayboluşu/belirişi, vampir ışınlanma sisi, ateş topu isabeti, lazer ağzı/ucu parlaması. Tamamı
## tools/gen_enemy_ability_fx.py'nin pişirdiği spritesheet'lerden TEK bir AnimatedSprite2D ile oynatılır (her karede
## _draw() YOK - kullanıcı isteği: "sprite sheete dönüştür ki performans kaybı yaşamayalım").
## Kullanım: FxEnemyAbility.spawn(parent, world_pos, FRAMES, "anim") - döngüsüz animasyonlar bitince kendini siler,
## döngülü olanlar `lifetime` saniye sonra.

const TEXEL := 1.212 ## PixelDraw.TEXEL - 1 sanat pikseli = bu kadar dünya birimi (Korsan efektleriyle aynı dil)
const SAFETY_LIFETIME := 4.0

var frames: SpriteFrames = null
var anim_name: StringName = &""
var lifetime: float = -1.0
var _anim: AnimatedSprite2D = null


static func spawn(parent: Node, world_pos: Vector2, sprite_frames: SpriteFrames, anim: StringName, z: int = 2,
		scale_mult: float = 1.0, rot: float = 0.0, life: float = -1.0) -> Node2D:
	if parent == null or sprite_frames == null:
		return null
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/fx_enemy_ability.gd"))
	fx.set("frames", sprite_frames)
	fx.set("anim_name", anim)
	fx.set("lifetime", life)
	fx.z_index = z
	fx.rotation = rot
	parent.add_child(fx)
	fx.global_position = world_pos
	fx.scale = Vector2.ONE * scale_mult
	return fx


func _ready() -> void:
	_anim = AnimatedSprite2D.new()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.sprite_frames = frames
	_anim.scale = Vector2.ONE * TEXEL
	add_child(_anim)
	if frames == null or not frames.has_animation(anim_name):
		queue_free()
		return
	_anim.play(anim_name)
	if not frames.get_animation_loop(anim_name):
		_anim.animation_finished.connect(queue_free)
	var t: float = lifetime if lifetime > 0.0 else SAFETY_LIFETIME
	get_tree().create_timer(t, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())
