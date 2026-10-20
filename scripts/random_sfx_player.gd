extends Node2D

const AudioBuses := preload("res://scripts/audio_buses.gd")

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
## melee_swing_sound.gd ile paylaşılıyor). Çalınan çalıcıyı döner: weapon.gd onu diğer oyunculara "weapon_sound" olarak yayınlar
## (2026-10-20, madde 344: Kılıç/Yay/Arbalet sesleri çok oyunculuda hiç gitmiyordu - arkadaşın bu silahları sessizdi).
func play_swing() -> AudioStreamPlayer2D:
	if _players.is_empty():
		return null
	var p: AudioStreamPlayer2D = _players[randi() % _players.size()]
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()
	return p


## Şovalye kubbesinin tacından ateşte sert boğuk yol (audio_buses.gd route_rim_sound) - melee_swing_sound.gd ile aynı kanca.
func set_rim_muffled(on: bool) -> void:
	for p: AudioStreamPlayer2D in _players:
		AudioBuses.route_rim_sound(p, on)
