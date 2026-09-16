extends Control

## Açılış logosu: oyun başladığında saydamdan görünür hale gelip (fade in),
## 3 saniye tam görünür kalıp, sonra tekrar saydamlaşarak (fade out) ana
## menüye geçer. Kullanıcı isteği - bkz. assets/ui/studio_logo.png.

const NEXT_SCENE := "res://scenes/main_menu.tscn"
const FADE_IN_TIME := 0.8
const HOLD_TIME := 2.5
const FADE_OUT_TIME := 1.5

@onready var logo: TextureRect = $CenterContainer/Logo
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var background: ColorRect = $Background


func _ready() -> void:
	# Arkaplan rengini logonun merkezine yakın bir arka plan rengiyle aynı yapıyoruz
	background.color = Color(0.0, 0.0, 0.0, 1.0)
	
	logo.modulate.a = 0.0
	audio.play() # Logo belirmeye başladığı anda ses çalsın
	
	var tween: Tween = create_tween()
	tween.tween_property(logo, "modulate:a", 1.0, FADE_IN_TIME)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(logo, "modulate:a", 0.0, FADE_OUT_TIME)
	tween.tween_callback(_go_to_main_menu)


func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)
