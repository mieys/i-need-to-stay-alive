extends Node2D

## Oyuncunun üstünde yanan alevler - İblis ateş topunun "3 saniye boyunca yakarak hasar verir" etkisinin görseli
## (bkz. player.gd apply_enemy_burn). Oyuncuya (ya da uzak kopyasına, "skill_scene" yayınıyla - bkz. player.gd
## _play_and_broadcast_skill_fx) çocuk olarak eklenir; DURATION sonunda kendini siler. Görsel tek bir AnimatedSprite2D
## (tools/gen_enemy_ability_fx.py burn_sheet) - her karede _draw() yok.

const TEXEL := 1.212 ## oyuncu kökü 0.5 ölçekli: 1.212 yerel birim = karakterin kendi sanat pikseli
const BURN_FRAMES := preload("res://assets/fx/enemy_abilities/burn_frames.tres")
const DURATION := 3.0
const FADE_TIME := 0.3
## burn_sheet karesi 34x42, alevlerin tabanı y=36 - taban karakterin bel/ayak arasına (yerel y ~ +22) gelsin.
const LOCAL_OFFSET := Vector2(0.0, 22.0 - (36.0 - 21.0) * TEXEL)

var _anim: AnimatedSprite2D = null
var _t: float = 0.0


func _ready() -> void:
	z_index = 1
	position = LOCAL_OFFSET
	_anim = AnimatedSprite2D.new()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.scale = Vector2.ONE * TEXEL
	_anim.sprite_frames = BURN_FRAMES
	add_child(_anim)
	_anim.play(&"loop")


## Yanma yeniden uygulanınca (yerel oyuncu) süre baştan başlar.
func refresh() -> void:
	_t = 0.0
	modulate.a = 1.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	modulate.a = clampf((DURATION - _t) / FADE_TIME, 0.0, 1.0)
