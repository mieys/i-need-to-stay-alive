extends Node2D

## Sırayla oynayan iki VFX - Tabanca'nın "mermi patlama ARDINDAN mini
## kıvılcım" isabet efekti için (bkz. "isabet halinde efektler" metni:
## "tabanca: mermi patlama ardından mini kıvılcım").
## ÖNEMLİ (güncelleme): eskiden ikinci (Second) efekt, BİRİNCİNİN (First)
## TÜM animasyonu bitene kadar hiç başlamıyordu - kullanıcı bildirimi:
## "kıvılcım ondan sadece 0.1 saniye sonra aktifleşsin" - yani artık First'in
## bitmesini beklemiyor, First başladıktan SECOND_DELAY kadar sonra (First
## hâlâ kendi animasyonunu oynatırken, üstüne binerek) Second de oynamaya
## başlıyor. Node, HER İKİ animasyon da kendi başına bitince serbest
## bırakılır (hangisi önce biterse bitsin, sadece bir bayrak işaretler).
const SECOND_DELAY := 0.1

@onready var first: AnimatedSprite2D = $First
@onready var second: AnimatedSprite2D = $Second

var _first_done: bool = false
var _second_done: bool = false


func _ready() -> void:
	second.visible = false
	first.animation_finished.connect(_on_first_finished, CONNECT_ONE_SHOT)
	first.play("play")
	get_tree().create_timer(SECOND_DELAY).timeout.connect(_start_second)


func _start_second() -> void:
	if not is_instance_valid(self):
		return
	second.visible = true
	second.animation_finished.connect(_on_second_finished, CONNECT_ONE_SHOT)
	second.play("play")


func _on_first_finished() -> void:
	_first_done = true
	if _second_done:
		queue_free()


func _on_second_finished() -> void:
	_second_done = true
	if _first_done:
		queue_free()
