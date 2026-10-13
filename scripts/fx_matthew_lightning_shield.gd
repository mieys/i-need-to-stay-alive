extends Node2D

## Matthew R "Yıldırım Kalkanı"nın halkası (madde 98; tilki kulaklı fx_matthew_fox_shield.gd'nin yerine - o dosya duruyor, ileride
## köpekle birlikte kullanılabilir). Kasterde player.gd _skill_shield_dome, diğer ekranlarda remote_player.gd
## _ensure_matthew_dome_visual (main.gd extra["matthew_dome"]) AYNI sahneyi kurar. Yarıçap kullanıcının seçtiği dar halka
## (prototipte gövdeye göre 26 px = oyunda 34 efekt pikseli, bkz. tools/gen_matthew_lightning_fx.py ORAN DÜZELTMESİ).
## pop(): kırılma / süre bitişi - halka hilallere ayrılıp dağılır, sonra düğüm kendini siler.

const ML := preload("res://scripts/matthew_lightning.gd")

var popping: bool = false
var _sprite: AnimatedSprite2D = null


func _ready() -> void:
	position = ML.BODY_CENTER
	_sprite = ML.make_sprite("shield_loop")
	if _sprite == null:
		return
	add_child(_sprite)
	_sprite.play(&"fx")
	## Birden fazla Matthew aynı anda kalkan açarsa hepsi tıpatıp aynı karede olmasın.
	_sprite.frame = randi() % _sprite.sprite_frames.get_frame_count(&"fx")


func pop() -> void:
	if popping:
		return
	popping = true
	var pop_frames: SpriteFrames = ML.frames("shield_pop")
	if _sprite == null or pop_frames == null:
		queue_free()
		return
	_sprite.sprite_frames = pop_frames
	_sprite.animation_finished.connect(queue_free)
	_sprite.play(&"fx")
