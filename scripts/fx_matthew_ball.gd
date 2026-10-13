extends Node2D

## Matthew E "Elektrik Topu"nun gövdesi (madde 98): form sürerken karakter sprite'ı gizlenir, yerine bu döngü oynar.
## Kasterde player.gd _skill_matthew_ball, diğer ekranlarda remote_player.gd (main.gd extra["mt"][0]) AYNI sahneyi kurar.
## big: final geliştirme "top %50 büyük" - ayrı sayfa (ball_big.png), germe yok. Vızıltı sesi (mevcut elektrik döngüsü) düğümün
## içinde - iki tarafta da duyulur, form bitince düğümle birlikte susar.

const ML := preload("res://scripts/matthew_lightning.gd")
const HUM_PATH := "res://assets/audio/lightning/electric_loop.mp3"

var big: bool = false
var _sprite: AnimatedSprite2D = null


func _ready() -> void:
	position = ML.BODY_CENTER
	_sprite = ML.make_sprite("ball_big" if big else "ball")
	if _sprite == null:
		return
	add_child(_sprite)
	_sprite.play(&"fx")
	if ResourceLoader.exists(HUM_PATH):
		var stream: AudioStream = (load(HUM_PATH) as AudioStream).duplicate() as AudioStream
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		var asp := AudioStreamPlayer2D.new()
		asp.stream = stream
		asp.volume_db = -9.0
		asp.max_distance = 1200.0
		add_child(asp)
		asp.play()
