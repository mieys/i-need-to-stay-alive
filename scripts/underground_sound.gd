extends Node

## YERALTI CANAVARI sesleri (Kademe 5 bossu, bkz. underground_boss.gd / worm_limb.gd): yeraltı gümbürtüsü, hırıltı, uzuv çıkışı / parçalanması / tükürüğü / savurma uyarısı.
## "korkutucu sesler yeraltından gelecek" - rumble_*/growl_* tools/gen_underground_sounds.py ile (numpy) sentezlendi; "ambient" projedeki Horror paketinin
## "Gore And Larvae Loop" kaydı (larva/kemirme dokusu, düşük sesle). HEPSİ HER istemcide yerel çalar (olay zaten broadcast_enemy_vfx ile herkese geliyor, ayrı ses RPC'si yok).
## Konumlu sesler (uzvun yanında) AudioStreamPlayer2D, konumsuzlar (gümbürtü/hırıltı/ambiyans - yer altından, her yerden) AudioStreamPlayer. Başsız çalışmada sessiz.
## Kullanım: UndergroundSound.play(get_tree(), &"emerge", global_position)   ya da   play(get_tree(), &"rumble_1")

const DIR := "res://assets/audio/underground/"
const PACK_DIR := "res://Sound FX Starter Pack Vol. 1/Horror/"

## anahtar -> [dosya, ses (dB), aynı anahtarın tekrar çalabilmesi için en az bekleme (sn), konumlu mu]
const SOUNDS := {
	&"rumble_1": [DIR + "rumble_1.wav", -7.0, 1.5, false],
	&"rumble_2": [DIR + "rumble_2.wav", -7.0, 1.5, false],
	&"rumble_3": [DIR + "rumble_3.wav", -7.0, 1.5, false],
	&"growl_1": [DIR + "growl_1.wav", -9.0, 2.0, false],
	&"growl_2": [DIR + "growl_2.wav", -9.0, 2.0, false],
	&"ambient": [PACK_DIR + "Gore And Larvae Loop.wav", -17.0, 8.0, false],
	&"emerge": [DIR + "emerge.wav", -9.0, 0.12, true],
	&"burst": [DIR + "burst.wav", -8.0, 0.1, true],
	&"spit": [DIR + "spit.wav", -10.0, 0.15, true],
	&"hiss": [DIR + "hiss.wav", -11.0, 0.2, true],
}
const MAX_VOICES := 8
const MAX_DISTANCE := 1100.0

static var _instance: Node = null
static var _streams: Dictionary = {}
static var _last_play: Dictionary = {} ## anahtar -> Time.get_ticks_msec()

var _voices_2d: Array[AudioStreamPlayer2D] = []
var _voices: Array[AudioStreamPlayer] = []


static func play(tree: SceneTree, key: StringName, pos: Vector2 = Vector2.INF) -> void:
	if tree == null or not SOUNDS.has(key) or DisplayServer.get_name() == "headless":
		return
	var cfg: Array = SOUNDS[key]
	var now: int = Time.get_ticks_msec()
	if now - int(_last_play.get(key, -1000000)) < int(float(cfg[2]) * 1000.0):
		return
	var stream: AudioStream = _stream_for(key)
	if stream == null:
		return
	if _instance == null or not is_instance_valid(_instance):
		_instance = (load("res://scripts/underground_sound.gd") as GDScript).new()
		_instance.name = "UndergroundSound"
		tree.root.add_child(_instance)
	_last_play[key] = now
	if bool(cfg[3]) and pos != Vector2.INF:
		var v2: AudioStreamPlayer2D = _instance.call("_free_voice_2d") as AudioStreamPlayer2D
		if v2 == null:
			return
		v2.stream = stream
		v2.global_position = pos
		v2.volume_db = float(cfg[1])
		v2.pitch_scale = randf_range(0.9, 1.1)
		v2.play()
	else:
		var v: AudioStreamPlayer = _instance.call("_free_voice") as AudioStreamPlayer
		if v == null:
			return
		v.stream = stream
		v.volume_db = float(cfg[1])
		v.pitch_scale = randf_range(0.94, 1.06)
		v.play()


static func _stream_for(key: StringName) -> AudioStream:
	if _streams.has(key):
		return _streams[key]
	var path: String = String(SOUNDS[key][0])
	var s: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	_streams[key] = s
	return s


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(MAX_VOICES):
		var p2 := AudioStreamPlayer2D.new()
		p2.max_distance = MAX_DISTANCE
		p2.attenuation = 1.6
		add_child(p2)
		_voices_2d.append(p2)
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)


func _free_voice_2d() -> AudioStreamPlayer2D:
	for v in _voices_2d:
		if not v.playing:
			return v
	return null


func _free_voice() -> AudioStreamPlayer:
	for v in _voices:
		if not v.playing:
			return v
	return null
