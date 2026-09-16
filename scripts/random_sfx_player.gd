extends Node2D

## Yay (Bow) fırlatma sesi: melee_swing_sound.gd'nin aksine burada 3 ses
## ZİNCİRLENMEZ - her atışta bunlardan sadece BİRİ rastgele seçilip çalınır
## (basit "her atışta 1 tık sesi" ihtiyacı, kombo hissi gerekmiyor). weapon.gd
## configure_melee() dışında, weapon_yay.tscn'de doğrudan "AttackSound" adıyla
## eklenir - _play_attack_sound() her ateşte play_swing() çağırır.

@export var streams: Array[AudioStream] = []
@export var volume_db: float = -10.0
@export var max_distance: float = 1500.0

var _players: Array[AudioStreamPlayer2D] = []


func _ready() -> void:
	for s in streams:
		var p := AudioStreamPlayer2D.new()
		p.stream = s
		p.volume_db = volume_db
		p.max_distance = max_distance
		add_child(p)
		_players.append(p)


## weapon.gd'nin _play_attack_sound() dispatch'i bu metodu arar (aynı hook,
## melee_swing_sound.gd ile paylaşılıyor).
func play_swing() -> void:
	if _players.is_empty():
		return
	var p: AudioStreamPlayer2D = _players[randi() % _players.size()]
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()
