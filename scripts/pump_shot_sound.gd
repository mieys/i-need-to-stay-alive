extends Node2D

const AudioBuses := preload("res://scripts/audio_buses.gd")

## Pompalı Tüfek atış sesi: ATIŞ + POMPA ÇEKİŞİ (madde 448 ek, 2026-11-08; kullanıcı: "pompalı tüfeğin çekiş sesi de vardı attığım
## seste, ateşledikten sonra hemen o oynatılıyordu"). İki ses kullanıcının dosyasından ayrıldı (tools/gen_pompali_ses.py): pompa tıkları
## patlamanın yankısına gömülüydü, oyunda duyulmuyordu. Atış hemen, pompa `pump_delay` sonra AYRI çalıcıdan çalar - sonraki atış
## atış çalıcısını baştan başlatsa da pompa kesilmez.
## weapon_pompali.tscn'de "AttackSound" adıyla durur; weapon.gd _play_attack_sound play_swing() çağırır, dönen adımları TEK
## "weapon_sound" mesajında "chain" olarak yollar (network_manager.gd aynı gecikmeyle çalar - madde 406 zinciri, protokol değişmedi).

@export var fire_stream: AudioStream
@export var pump_stream: AudioStream
@export var fire_volume_db: float = -8.0
@export var pump_volume_db: float = -9.0
@export var pump_delay: float = 0.2 ## atıştan pompanın ilk tıkına (sn)
@export var max_distance: float = 1500.0

var _fire: AudioStreamPlayer2D
var _pump: AudioStreamPlayer2D
var _shot: int = 0 ## gecikmeli pompa yalnız EN SON atışınki çalsın (çok hızlı atışta pompa üst üste binmesin)


func _ready() -> void:
	_fire = _make(fire_stream, fire_volume_db)
	_pump = _make(pump_stream, pump_volume_db)


func _make(stream: AudioStream, db: float) -> AudioStreamPlayer2D:
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.volume_db = db
	p.max_distance = max_distance
	add_child(p)
	return p


## Dönüş: [{sound_path, pitch, delay, volume_db}, ...] (melee_swing_sound.gd ile aynı biçim; yerel çalış ve ağ aynı değerleri kullanır).
func play_swing() -> Array:
	var steps: Array = []
	if _fire == null or _fire.stream == null:
		return steps
	var fire_pitch: float = randf_range(0.88, 1.12) ## eski tek ses kuralı: art arda atışlar tekdüze olmasın
	_fire.pitch_scale = fire_pitch
	_fire.play()
	steps.append({"sound_path": _fire.stream.resource_path, "pitch": fire_pitch, "delay": 0.0, "volume_db": _fire.volume_db})
	if _pump != null and _pump.stream != null:
		var pump_pitch: float = randf_range(0.95, 1.05)
		_shot += 1
		get_tree().create_timer(pump_delay).timeout.connect(_play_pump.bind(_shot, pump_pitch))
		steps.append({"sound_path": _pump.stream.resource_path, "pitch": pump_pitch, "delay": pump_delay, "volume_db": _pump.volume_db})
	return steps


func _play_pump(shot: int, pitch: float) -> void:
	if shot != _shot or not is_instance_valid(_pump) or not _pump.is_inside_tree():
		return
	_pump.pitch_scale = pitch
	_pump.play()


## Şovalye kubbesinin halkasından ateşte sert boğuk yol (audio_buses.gd route_rim_sound) - diğer çok sesli çalıcılarla aynı kanca.
func set_rim_muffled(on: bool) -> void:
	for p: AudioStreamPlayer2D in [_fire, _pump]:
		if p != null:
			AudioBuses.route_rim_sound(p, on)
