extends Node

## Kullanıcı isteği (2026-09-25): "yaratıkların türlerine bağlı olarak öldüklerinde fazla dikkat çekmeyen bir ölüm sesi
## çıkarsınlar. mesela slime yapışkan bişeyin patlama sesi gibi, iskelet iskelet yıkılma sesi gibi".
## Sesler tools/gen_creature_death_sounds.py ile üretilir: assets/audio/creature_death/<aile>_<n>.wav (aile = enemy.gd
## family_of_id, ör. "slime3" -> "slime"). enemy.gd die() çağırır - die() host'ta VE istemcilerde (death_state RPC'si)
## çalıştığı için her oyuncu sesi kendi ekranında duyar, ayrı bir ağ mesajı yok.
##
## "Dikkat çekmesin" + FPS: AoE ile aynı karede onlarca yaratık ölebilir. Bu yüzden:
##  - sabit küçük bir AudioStreamPlayer2D havuzu (MAX_VOICES) - doluysa ses atlanır, yeni düğüm açılmaz;
##  - aynı aileden art arda sesler arasında en az FAMILY_GAP sn (toplu ölüm tek bir "yığılma" gibi duyulur);
##  - dinleyiciden (kamera) MAX_DISTANCE'tan uzaktaki ölüm hiç çalmaz;
##  - kısık ses (VOLUME_DB) + hafif rastgele perde.

const DIR := "res://assets/audio/creature_death/"
const VARIANTS := 2
const MAX_VOICES := 5
const FAMILY_GAP := 0.07
const VOLUME_DB := -13.0
const BOSS_VOLUME_DB := -8.0
const MAX_DISTANCE := 1000.0

static var _instance: Node = null
static var _streams: Dictionary = {} ## aile -> Array[AudioStream] (boş dizi = bu ailenin sesi yok)
static var _last_play: Dictionary = {} ## aile -> Time.get_ticks_msec()

var _voices: Array[AudioStreamPlayer2D] = []


static func play(tree: SceneTree, family: String, pos: Vector2, is_boss: bool = false) -> void:
	if tree == null or family.is_empty() or DisplayServer.get_name() == "headless":
		return
	var streams: Array = _streams_for(family)
	if streams.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_play.get(family, -100000)) < int(FAMILY_GAP * 1000.0):
		return
	var vp: Viewport = tree.root.get_viewport()
	var cam: Camera2D = vp.get_camera_2d() if vp else null
	if cam and cam.get_screen_center_position().distance_to(pos) > MAX_DISTANCE:
		return
	if _instance == null or not is_instance_valid(_instance):
		_instance = (load("res://scripts/creature_death_sound.gd") as GDScript).new()
		_instance.name = "CreatureDeathSound"
		tree.root.add_child(_instance)
	var voice: AudioStreamPlayer2D = _instance.call("_free_voice") as AudioStreamPlayer2D
	if voice == null:
		return
	_last_play[family] = now
	voice.stream = streams[randi() % streams.size()]
	voice.global_position = pos
	voice.volume_db = BOSS_VOLUME_DB if is_boss else VOLUME_DB
	voice.pitch_scale = randf_range(0.72, 0.8) if is_boss else randf_range(0.92, 1.08)
	voice.play()


static func _streams_for(family: String) -> Array:
	if _streams.has(family):
		return _streams[family]
	var list: Array = []
	for i in range(1, VARIANTS + 1):
		var path: String = "%s%s_%d.wav" % [DIR, family, i]
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path) as AudioStream
			if s:
				list.append(s)
	_streams[family] = list
	return list


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(MAX_VOICES):
		var p := AudioStreamPlayer2D.new()
		p.max_distance = MAX_DISTANCE
		p.attenuation = 1.5
		add_child(p)
		_voices.append(p)


func _free_voice() -> AudioStreamPlayer2D:
	for v in _voices:
		if not v.playing:
			return v
	return null
