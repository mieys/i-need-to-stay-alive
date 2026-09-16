extends Node2D

const SOUND_EXPLOSION: AudioStream = preload("res://assets/audio/fire_staff_explosion.mp3")

const HFRAMES := 8
const VFRAMES := 1
const FPS := 14.0

var _frame_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	if sprite:
		var img := Image.load_from_file("res://assets/skills/korsan_explosion_spritesheet.png")
		var tex := ImageTexture.create_from_image(img)
		sprite.texture = tex
		sprite.hframes = HFRAMES
		sprite.vframes = VFRAMES
		sprite.frame = 0
		sprite.scale = Vector2(2.5, 2.5) # Large explosion visual
	
	if sound:
		sound.stream = SOUND_EXPLOSION
		sound.pitch_scale = randf_range(0.9, 1.1)
		sound.play()


func _process(delta: float) -> void:
	_frame_time += delta * FPS
	var col: int = int(_frame_time)
	if col >= HFRAMES:
		# Fade out final frame slightly before freeing
		var fade := 1.0 - (col - HFRAMES) * 0.1
		if sprite:
			sprite.modulate.a = max(0.0, fade)
		if fade <= 0.0:
			queue_free()
	else:
		if sprite:
			sprite.frame = col
