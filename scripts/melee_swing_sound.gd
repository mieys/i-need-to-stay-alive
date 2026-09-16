extends Node2D

## Yakın dövüş kombo ses çalıcısı: her saldırıda verilen seslerin HEPSİ
## çalar, rastgele sırayla ama art arda bindirmeli - bir ses süresinin
## %60'ına geldiğinde bir sonraki başlar (böylece 3 ses üst üste, kombo
## hissi vererek duyulur). Her ses kendi rastgele perdesiyle (0.9-1.1) çalar.
## weapon.gd configure_melee() bu script'i "AttackSound" adıyla ekler,
## _play_attack_sound() her saldırıda play_swing() çağırır - yani her
## saldırı kendi 3'lü zincirini baştan başlatır.

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


## Her saldırıda çağrılır: 3 sesi rastgele sırayla, zincirleme başlatır.
func play_swing() -> void:
	if _players.is_empty():
		return
	var order: Array = range(_players.size())
	order.shuffle()
	_play_step(order, 0)


func _play_step(order: Array, idx: int) -> void:
	if idx >= order.size():
		return
	var s: AudioStreamPlayer2D = _players[order[idx]]
	s.pitch_scale = randf_range(0.9, 1.1)
	s.play()
	if idx + 1 < order.size():
		var length: float = s.stream.get_length() / s.pitch_scale
		get_tree().create_timer(length * CHAIN_PROGRESS).timeout.connect(
			_play_step.bind(order, idx + 1))
