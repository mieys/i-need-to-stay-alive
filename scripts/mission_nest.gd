extends "res://scripts/mission_target.gd"

## YARATIK YUVASI (madde 496, "Yuvaları Kapat"): yıkılana kadar yakınında oyuncu varken yaratık çıkarır (doğurma world_event_manager.gd'de,
## host). Görsel tools/gen_gorev_sanat.py yuva.png: 0-3 nabız döngüsü, 4 = çökmüş yuva (ölünce yerde kalıp söner). Hareket etmez.

const SHEET: Texture2D = preload("res://assets/fx/gorev/yuva.png")
const HFRAMES := 5
const FPS := 5.0
## Kare 44x32: höyük ortası (22, 21) düğüm noktasına otursun (kare ortası y 16 -> 5 px yukarı).
const SPRITE_OFFSET := Vector2(0, -5)
const DEATH_TINT := Color(0.85, 0.55, 1.0)

var _spr: Sprite2D = null
var _t: float = 0.0
var _pulse_boost: float = 0.0 ## yaratık çıkarınca kısa parlama (host + istemci: doğuşu ağdan bilmiyoruz -> yalnız host'ta, yeterli)


func _init() -> void:
	_body_radius = 18.0
	block_radius = 15.0
	bar_offset = -24.0
	dmg_spawn_offset = Vector2(0, -26)


func _build_visual() -> void:
	_spr = Sprite2D.new()
	_spr.texture = SHEET
	_spr.hframes = HFRAMES
	_spr.offset = SPRITE_OFFSET
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)


func _process(delta: float) -> void:
	if _spr == null or is_dead:
		return
	_t += delta * (FPS + _pulse_boost * 6.0)
	_pulse_boost = maxf(0.0, _pulse_boost - delta * 2.0)
	_spr.frame = int(_t) % 4


func on_spawned_wave() -> void:
	_pulse_boost = 1.0


func _on_death_fx() -> void:
	var tree: SceneTree = get_tree()
	spawn_burst(tree, global_position + Vector2(0, -4), DEATH_TINT, 1.3)
	spawn_fading_sprite(tree, global_position, SHEET, HFRAMES, 4, SPRITE_OFFSET, 2.5, 1.2)


func _on_vanish_fx() -> void:
	spawn_fading_sprite(get_tree(), global_position, SHEET, HFRAMES, 0, SPRITE_OFFSET, 0.0, 0.8)
