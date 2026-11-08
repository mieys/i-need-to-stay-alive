extends Node2D

const AudioBuses := preload("res://scripts/audio_buses.gd")

## Yakın dövüş kombo ses çalıcısı: her saldırıda verilen seslerin HEPSİ
## çalar, rastgele sırayla ama art arda bindirmeli - bir ses süresinin
## %25'ine geldiğinde bir sonraki başlar (böylece 3 ses üst üste, kombo
## hissi vererek duyulur). Her ses kendi rastgele perdesiyle (0.9-1.1) çalar.
## weapon.gd configure_melee() bu script'i "AttackSound" adıyla ekler,
## _play_attack_sound() her saldırıda play_swing() çağırır - yani her
## saldırı kendi 3'lü zincirini baştan başlatır.
## AĞ (2026-11-06, madde 406): play_swing() zincirin adımlarını (dosya, perde, gecikme, ses seviyesi) döner; weapon.gd onları TEK
## "weapon_sound" mesajında "chain" olarak yollar, network_manager.gd aynı gecikmelerle çalar (eskiden Bıçak/Pençe/Mızrak arkadaşta sessizdi).

const CHAIN_PROGRESS := 0.25

var _players: Array = []


func setup(paths: Array, volume_db: float = -12.0) -> void:
	for p in paths:
		var s := AudioStreamPlayer2D.new()
		s.stream = load(p)
		s.volume_db = volume_db
		s.max_distance = 1500.0
		add_child(s)
		_players.append(s)


## Silah Şovalye kubbesinin halkasındaysa sesler sert boğuk yola gider (audio_buses.gd route_rim_sound).
func set_rim_muffled(on: bool) -> void:
	for s: AudioStreamPlayer2D in _players:
		AudioBuses.route_rim_sound(s, on)


## Her saldırıda çağrılır: sesleri rastgele sırayla, zincirleme başlatır. Dönüş: [{sound_path, pitch, delay, volume_db}, ...]
## (gecikme saldırı anından saniye; ilk adım 0). Sıra/perde/gecikme burada BİR KEZ seçilir, yerel çalış ve ağ aynı değerleri kullanır.
func play_swing() -> Array:
	var steps: Array = []
	if _players.is_empty():
		return steps
	var order: Array = range(_players.size())
	order.shuffle()
	var t: float = 0.0
	for i: int in order:
		var s: AudioStreamPlayer2D = _players[i]
		var pitch: float = randf_range(0.9, 1.1)
		var path: String = s.stream.resource_path if s.stream != null else ""
		steps.append({"sound_path": path, "pitch": pitch, "delay": t, "volume_db": s.volume_db})
		if t <= 0.0:
			_play_one(s, pitch)
		else:
			get_tree().create_timer(t).timeout.connect(_play_one.bind(s, pitch))
		if s.stream != null:
			t += s.stream.get_length() / pitch * CHAIN_PROGRESS
	return steps


func _play_one(s: AudioStreamPlayer2D, pitch: float) -> void:
	if not is_instance_valid(s):
		return
	s.pitch_scale = pitch
	s.play()
