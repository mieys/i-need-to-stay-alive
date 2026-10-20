extends AudioStreamPlayer
## Boss müziği (kullanıcı isteği 2026-10-13: "boss geldiğinde ParagonX9 müziği çalsın").
## "boss" grubunda yaşayan bir yaratık varsa çalar; son boss ölünce yumuşakça söner. Her peer KENDİ sahnesindeki gruptan okur
## (boss_bar_top.gd ile aynı kural; host/istemci boss'u zaten aynı grupla kurar) - ağdan bir şey gitmez.

## WAV (kırpılmış, başı/sonu sessizliksiz, içe aktarımda ileri döngü): MP3 kodlayıcı dolgusu döngü başında/sonunda ~0,45 sn boşluk bırakıyordu.
const MUSIC_PATH := "res://assets/audio/boss_music_haunted_woods.wav"
## 2026-10-19 (kullanıcı: "boss müziğinin sesini %20 azalt"): eski -8,0 dB x 0,8 genlik (-1,94 dB). Ayarlar'daki Müzik Sesi ayrıca bus'ta uygulanır.
const PLAY_DB := -9.94
const SILENT_DB := -60.0
const FADE_IN_SEC := 1.5
const FADE_OUT_SEC := 3.0
const CHECK_INTERVAL := 0.25

var _check_left: float = 0.0
var _boss_alive: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS ## seviye atlama ekranında müzik kesilmesin
	var stream_res: AudioStreamWAV = load(MUSIC_PATH) as AudioStreamWAV
	if stream_res:
		stream = stream_res
	volume_db = SILENT_DB
	bus = preload("res://scripts/audio_buses.gd").music_bus() ## Ayarlar > Müzik Sesi bu yoldan


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_INTERVAL
		_boss_alive = _any_boss_alive()
	if _boss_alive:
		if not playing and stream:
			play(0.0)
		volume_db = move_toward(volume_db, PLAY_DB, (PLAY_DB - SILENT_DB) / FADE_IN_SEC * delta)
	elif playing:
		volume_db = move_toward(volume_db, SILENT_DB, (PLAY_DB - SILENT_DB) / FADE_OUT_SEC * delta)
		if volume_db <= SILENT_DB:
			stop()


func _any_boss_alive() -> bool:
	for b in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(b) and not b.is_queued_for_deletion() and b.get("is_dead") != true:
			return true
	return false
