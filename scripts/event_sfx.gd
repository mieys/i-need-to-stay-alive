extends Node

## Oyun olayı geri bildirim sesleri (kullanıcı isteği 2026-10-01: görev başlamak üzere/başladı/başarılı/başarısız,
## seyyar satıcı geldi/gitti/panel açıldı, boss geldi, altın hediyesi, sohbet mesajı, takım arkadaşı düştü, sen düştün,
## dirildin + oyun bitti ekranı). Sesler numpy ile sentezlendi ve kullanıcı dinleme sayfasında tek tek seçti; üreticiler
## tools/event_sfx/ altında (hangi dosyanın hangi fonksiyondan geldiği aşağıdaki SOUNDS yorumlarında).
##
## Hepsi konumsuz (arayüz sesi gibi) ve HER istemcide yerel çalar - olayların kendisi zaten tüm peer'lere ulaşıyor
## (görev/satıcı/sohbet call_local RPC'leri, boss spawn RPC'si, uzak oyuncunun durum paketi), ayrı bir ses RPC'si yok.
## Kullanım: EventSfx.play(get_tree(), &"mission_start")

const DIR := "res://assets/audio/events/"

## anahtar -> [ses (dB), aynı sesin tekrar çalabilmesi için en az bekleme (sn)]
## Kaynaklar: mission_warn = gen_event_sfx.mission_warn_B, mission_start = round4 R4D, mission_success = round6 R6A,
## mission_fail = gen B, merchant_arrive/leave = round2 C, shop_open = gen A, boss = gen A, gold_gift = gen B,
## chat = gen B, ally_down = round4 R4C, self_down = gen B, revive = gen B, game_over = round3 ally_down_G (çello).
const SOUNDS := {
	&"mission_warn": [-6.0, 1.0],
	&"mission_start": [-2.7, 1.0], ## kullanıcı 2026-10-01: %30 daha yüksek (-5.0 -> x1.3 genlik = +2.3 dB)
	&"mission_success": [-4.0, 1.0],
	&"mission_fail": [-5.0, 1.0],
	&"merchant_arrive": [-6.0, 2.0],
	&"merchant_leave": [-7.0, 2.0],
	&"shop_open": [-8.0, 0.3],
	&"boss": [-4.0, 4.0], ## boss grubu birkaç yaratık = istemcide birkaç spawn RPC'si -> tek ses
	&"gold_gift": [-5.0, 0.4],
	&"chat": [-10.0, 0.25],
	&"ally_down": [-6.0, 0.6],
	&"self_down": [-4.0, 1.0],
	&"revive": [-4.0, 1.0],
	&"game_over": [-4.0, 3.0],
	## Topla görevi kristali (2026-10-01, round7_sfx.py crystal_B "Kristal şıkırtı") - sadece toplayan oyuncuda; görev başına ~50 kez.
	&"crystal_collect": [-8.0, 0.05],
}
const MAX_VOICES := 4

static var _instance: Node = null
static var _streams: Dictionary = {}
static var _last_play: Dictionary = {} ## anahtar -> Time.get_ticks_msec()

var _voices: Array[AudioStreamPlayer] = []


static func play(tree: SceneTree, key: StringName) -> void:
	if tree == null or not SOUNDS.has(key) or DisplayServer.get_name() == "headless":
		return
	var now: int = Time.get_ticks_msec()
	var cfg: Array = SOUNDS[key]
	if now - int(_last_play.get(key, -1000000)) < int(float(cfg[1]) * 1000.0):
		return
	var stream: AudioStream = _stream_for(key)
	if stream == null:
		return
	if _instance == null or not is_instance_valid(_instance):
		_instance = (load("res://scripts/event_sfx.gd") as GDScript).new()
		_instance.name = "EventSfx"
		tree.root.add_child(_instance)
	var voice: AudioStreamPlayer = _instance.call("_free_voice") as AudioStreamPlayer
	if voice == null:
		return
	_last_play[key] = now
	voice.stream = stream
	voice.volume_db = float(cfg[0])
	voice.play()


static func _stream_for(key: StringName) -> AudioStream:
	if _streams.has(key):
		return _streams[key]
	var path: String = DIR + String(key) + ".wav"
	var s: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	_streams[key] = s
	return s


func _ready() -> void:
	## Dükkan / duraklatma gibi get_tree().paused yapan ekranlarda da duyulsun.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(MAX_VOICES):
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_voices.append(p)


## Boşta ses yoksa en eski çalanı kes (olay sesleri nadir; kaybolmasındansa yenisi duyulsun).
func _free_voice() -> AudioStreamPlayer:
	var oldest: AudioStreamPlayer = null
	for v in _voices:
		if not v.playing:
			return v
		if oldest == null or v.get_playback_position() > oldest.get_playback_position():
			oldest = v
	return oldest
