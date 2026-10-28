extends AudioStreamPlayer

## AKARSU SESİ (kullanıcı isteği 2026-10-11: "akarsu sesi akarsuya yakınken uzaklık farkına göre az/çok çıksın, aşırı fazla olmasın").
## Konumsuz tek bir döngü; ses seviyesi OYUNCUNUN en yakın su karosuna uzaklığıyla değişir:
##   FULL_DISTANCE içinde en yüksek (MAX_DB), MAX_DISTANCE'tan uzakta tamamen susar; arası yumuşak (smoothstep) eğri, KARESİ alınır
##   (kuyruk hızlı söner). 2026-10-17 kullanıcı: "nehrin sesi uzaktayken bile geliyor, yaklaşınca gelmeliydi" - eski 640 px menzil ekranın
##   yarı genişliğinin (240 px) 2,7 katıydı ve harita alanının ~%66'sı bir su karosuna 640 px'ten yakın (ses neredeyse hep açıktı);
##   menzil 320 px'e indi, ekran kenarında (~240 px) neredeyse duyulmaz, ~10 karo yakında belirgin, kıyıda tam.
## Yağmurdan (atmosphere.gd RAIN_VOLUME_DB) daha kısık tutuldu. Seviye değişimi üstel yumuşatılır (suya hızlı yaklaşınca ani sıçrama yok);
## yok olurken -38 dB altında durdurulur (tık sesi olmaz). Kaynak: tools/make_seamless_ambience.py (dikişsiz OGG döngü).
## Yalnız yerel ortam sesi - ağ senkronu gerekmez. Ev içindeyken (player.is_indoors) susar. Ambient yolu: Şovalye kubbesi içinde boğulur.

const STREAM_PATH := "res://assets/audio/stream_loop.ogg"
const FULL_DISTANCE := 48.0 ## px: kıyıya bu kadar yakında tam seviye (bir karo = 16 px)
const MAX_DISTANCE := 320.0 ## px: bundan uzakta duyulmaz
const MAX_DB := -17.0 ## kıyıdaki en yüksek seviye (normalize kaynak -26 dBFS RMS; 2026-10-21 kullanıcı "çok yüksek, rahatsız edici": -7 -> -17)
const SMOOTH_RATE := 3.0 ## 1/sn: hedef seviyeye yaklaşma hızı
const QUERY_INTERVAL := 0.2
const STOP_BELOW := 0.012 ## doğrusal genlik (~-38 dB)

var _water: PackedVector2Array = PackedVector2Array() ## su karolarının dünya merkezleri
var _water_ready: bool = false
var _query_t: float = 0.0
var _target: float = 0.0
var _amount: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS ## duraklatma/seviye atlama ekranlarında ses kesilmesin
	bus = preload("res://scripts/audio_buses.gd").ambient_bus()
	volume_db = -80.0
	if ResourceLoader.exists(STREAM_PATH):
		var s: AudioStream = load(STREAM_PATH) as AudioStream
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
			(s as AudioStreamOggVorbis).loop_offset = 0.0
		stream = s


func _process(delta: float) -> void:
	if stream == null:
		return
	_query_t -= delta
	if _query_t <= 0.0:
		_query_t = QUERY_INTERVAL
		_target = _target_amount()
	_amount += (_target - _amount) * (1.0 - exp(-SMOOTH_RATE * delta))
	if _amount < STOP_BELOW and _target < STOP_BELOW:
		if playing:
			stop()
		return
	volume_db = MAX_DB + linear_to_db(clampf(_amount, STOP_BELOW, 1.0))
	if not playing:
		play(randf() * maxf(stream.get_length() - 0.1, 0.0))


## 0..1: oyuncunun en yakın suya uzaklığına göre hedef genlik (1 = kıyıda).
func _target_amount() -> float:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not is_instance_valid(player):
		return 0.0
	if player.get("is_indoors") == true or str(player.get("in_dungeon") if player.get("in_dungeon") != null else "") != "":
		return 0.0
	if not _water_ready and not _load_water():
		return 0.0
	if _water.is_empty():
		return 0.0
	var p: Vector2 = player.global_position
	var best: float = INF
	for w in _water:
		var d: float = p.distance_squared_to(w)
		if d < best:
			best = d
	var dist: float = sqrt(best) - 8.0 ## karo merkezinden kıyıya (yarım karo)
	var t: float = clampf((dist - FULL_DISTANCE) / (MAX_DISTANCE - FULL_DISTANCE), 0.0, 1.0)
	var near: float = 1.0 - t * t * (3.0 - 2.0 * t)
	return near * near


func _load_water() -> bool:
	var layer: TileMapLayer = GameManager.get_water_layer()
	if layer == null:
		return false
	_water = PackedVector2Array()
	for cell: Vector2i in layer.get_used_cells():
		_water.append(layer.to_global(layer.map_to_local(cell)))
	_water_ready = true
	return true
