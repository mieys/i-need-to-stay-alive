extends "res://scripts/mission_target.gd"

## RİTÜEL KRİSTALİ (madde 496, "Ritüeli Boz"): heykelin çevresindeki mor kristal; üçü de kırılınca ritüel bozulur. Görsel mevcut mor kristal
## sayfası (assets/fx/enchant/crystal_arcane_*), kırılınca kristal kırılma halkası. Heykele giden enerji ipi mission_ritual_altar.gd'de çizilir.

const FRAMES: SpriteFrames = preload("res://assets/fx/enchant/crystal_arcane_frames.tres")
const EventSfx := preload("res://scripts/event_sfx.gd")
## Kare 20x30: taban (y 29) düğüm noktasına otursun.
const SPRITE_OFFSET := Vector2(0, -14)
const DEATH_TINT := Color(0.95, 0.7, 1.0)

var _anim: AnimatedSprite2D = null


func _init() -> void:
	_body_radius = 12.0
	block_radius = 9.0
	bar_offset = -36.0
	dmg_spawn_offset = Vector2(0, -34)


func _build_visual() -> void:
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = FRAMES
	_anim.offset = SPRITE_OFFSET
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_anim)
	_anim.play(&"loop")
	_anim.frame = randi() % 6 ## üç kristal aynı karede parlamasın


## Enerji ipinin kristal ucu (heykel çizer).
func beam_anchor() -> Vector2:
	return global_position + Vector2(0, -16)


func _on_death_fx() -> void:
	spawn_burst(get_tree(), global_position + Vector2(0, -14), DEATH_TINT, 1.0)
	EventSfx.play(get_tree(), &"crystal_collect")


func _on_vanish_fx() -> void:
	spawn_burst(get_tree(), global_position + Vector2(0, -14), Color(1, 1, 1, 0.6), 0.8)
