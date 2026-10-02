extends Node2D

## Yetenek evrimlerinin karaktere bağlı SÜREKLİ efektleri (2026-09-30 - ilk kullanıcı Assasin "Pusu", fx_evo_assasin_empower):
## çocuk "Sprite" (AnimatedSprite2D) "loop" animasyonunu yetenek sürdükçe oynatır, stop() ile solarak kaybolur. Kaster
## player.gd _play_and_broadcast_skill_fx ile kurar, bitişte _stop_and_broadcast_skill_fx -> stop(); diğer oyuncular AYNI
## sahneyi "skill_scene" ile kurar ve kapanışı broadcast_player_fx_stop ile alır. Kapanış paketi kaybolursa safety_lifetime'da
## kendi kendine söner.
## DİKKAT: kök AnimatedSprite2D OLAMAZ - stop() onun yerel stop()'unu ezer, projede bu uyarı hata sayılır (script hiç
## yüklenmez, düğüm scriptsiz kalır ve stop() sadece animasyonu dondurur - efekt hiç silinmez). Bkz. fx_evo_talon_ward.gd.

@export var fade_in: float = 0.2
@export var fade_out: float = 0.3
@export var safety_lifetime: float = 12.0 ## en uzun Gölge Adımı ("Uzun Gölge") 8 sn

var _t: float = 0.0
var _stopping: bool = false
var _stop_t: float = 0.0


func _ready() -> void:
	modulate.a = 0.0
	var spr: AnimatedSprite2D = get_node_or_null("Sprite") as AnimatedSprite2D
	if spr != null:
		spr.play(&"loop")


func stop() -> void:
	_stopping = true


func _process(delta: float) -> void:
	_t += delta
	if _stopping:
		_stop_t += delta
		modulate.a = clampf(1.0 - _stop_t / maxf(0.01, fade_out), 0.0, 1.0)
		if _stop_t >= fade_out:
			queue_free()
		return
	modulate.a = clampf(_t / maxf(0.01, fade_in), 0.0, 1.0)
	if _t >= safety_lifetime:
		_stopping = true
