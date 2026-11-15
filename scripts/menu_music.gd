extends AudioStreamPlayer
## Karakter seçimi müziği (kullanıcı isteği 2026-11-13: "Home Stretch biraz kısık çalsın"; önce ana menü + yükleme dahildi, sonra
## "sadece karakter seçme ekranından yükleme ekranına kadar" dedi). UISound autoload'unun çocuğu (project.godot'a dokunmamak için);
## sahne değişse de kesilmez. Sadece MENU_SCENES'te çalar; ana menüde / yükleme ekranında / oyunda yumuşakça söner.
## Müzik bus'ına (Ayarlar > Müzik Sesi) çalar; boss müziğiyle aynı yol.

const MUSIC_PATH := "res://assets/audio/menu_music_home_stretch.mp3"
## Boss müziği -9,94 dB. İlk hâli -14 idi, kullanıcı "biraz fazla kısık" dedi (2026-11-13) -> -10.
const PLAY_DB := -10.0
const SILENT_DB := -60.0
const FADE_IN_SEC := 0.15 ## 2026-11-13: "hemen başlamıyor, gecikmeli ve soft" -> neredeyse anında (tık sesi olmasın diye 0,15 sn)
const FADE_OUT_SEC := 1.2
const CHECK_INTERVAL := 0.0 ## her karede (ucuz: tek dizgi karşılaştırması); sahne girişinde gecikme olmasın
## 2026-11-15 (kullanıcı): Kevin MacLeod "For Originz" ANA MENÜ müziği - karakter seçim ekranına girene kadar (ana menü, oda listesi, oda lobisi);
## seçim ekranlarında Home Stretch. Sahne -> parça yolu; listede olmayan sahnede (yükleme, oyun, splash) sönük.
const MAIN_TRACK := "res://assets/audio/menu_music_for_originz.mp3"
const MENU_SCENES: Dictionary = {
	"res://scenes/main_menu.tscn": MAIN_TRACK,
	"res://scenes/room_browser.tscn": MAIN_TRACK,
	"res://scenes/room_lobby.tscn": MAIN_TRACK,
	"res://scenes/character_select.tscn": MUSIC_PATH, ## tek oyunculu karakter seçimi
	"res://scenes/lobby_menu.tscn": MUSIC_PATH, ## çok oyunculu karakter seçimi
}

var _check_left: float = 0.0
var _want: bool = false
var _want_track: String = ""
var _track: String = MUSIC_PATH ## şu an `stream`e yüklü parça
var _streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stream = _stream_for(MUSIC_PATH)
	volume_db = SILENT_DB
	bus = preload("res://scripts/audio_buses.gd").music_bus()


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_INTERVAL
		var scene: Node = get_tree().current_scene
		_want_track = str(MENU_SCENES.get(scene.scene_file_path, "")) if scene != null else ""
		_want = _want_track != ""
	if _want and playing and _want_track != _track:
		## parça değişimi (ana menü <-> karakter seçimi): önce eski parça söner, sonra yenisi girer
		volume_db = move_toward(volume_db, SILENT_DB, (PLAY_DB - SILENT_DB) / FADE_OUT_SEC * delta)
		if volume_db <= SILENT_DB:
			stop()
	elif _want:
		if not playing and _want_track != _track:
			_track = _want_track
			stream = _stream_for(_track)
		if not playing and stream:
			play(0.0)
		volume_db = move_toward(volume_db, PLAY_DB, (PLAY_DB - SILENT_DB) / FADE_IN_SEC * delta)
	elif playing:
		volume_db = move_toward(volume_db, SILENT_DB, (PLAY_DB - SILENT_DB) / FADE_OUT_SEC * delta)
		if volume_db <= SILENT_DB:
			stop()


func _stream_for(path: String) -> AudioStream:
	if not _streams.has(path):
		var mp3: AudioStreamMP3 = load(path) as AudioStreamMP3
		if mp3:
			mp3.loop = true
		_streams[path] = mp3
	return _streams[path]
