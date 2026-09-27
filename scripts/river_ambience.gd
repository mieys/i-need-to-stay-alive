extends Node2D

## Nehir akıntısı sesi (kullanıcı isteği 2026-09-27: "oyunda nehire yaklaşınca nehir su akıntısı sesi eklemeni istiyorum").
## Ses: assets/audio/river_flow_loop.wav (tools/gen_river_sound.py, dikişsiz döngü).
##
## Haritanın "Su" katmanlarındaki (harita_baked.tscn: Su/Su, Su/Su altı) dolu hücrelerden kaba bir ızgara (GRID_CELL dünya
## birimi) kurulur; her UPDATE_INTERVAL'da YEREL oyuncuya en yakın su noktası bulunur ve tek bir AudioStreamPlayer2D oraya
## (yumuşakça) taşınır - ses nehre yaklaştıkça artar, sağdan/soldan geldiği duyulur (2D kaynak kamerayı dinleyici alır).
## Ev içindeyken ya da yakında su yokken ses kısılır. Ortam yolu (Ambient bus) - Şovalye kubbesinde boğulur, ayarlardaki
## ses düzeyleri geçerli. Her istemci kendi oyuncusu için yerel hesaplar (ağ yok).

const SOUND_PATH := "res://assets/audio/river_flow_loop.wav"
const WATER_LAYER_NAMES: Array[String] = ["Su", "Su altı"]
const GRID_CELL := 64.0 ## dünya birimi - her ızgara hücresi o hücredeki suyun ortalama noktasını tutar
const HEAR_RADIUS := 460.0 ## bu mesafeden uzakta su yok sayılır (ses tamamen söner)
const MAX_DISTANCE := 520.0 ## AudioStreamPlayer2D duyulma mesafesi
const ATTENUATION := 1.6
const VOLUME_DB := -8.0
const UPDATE_INTERVAL := 0.2
const FOLLOW_RATE := 6.0 ## ses kaynağının hedef noktaya kayma hızı (1/sn) - nehir boyunca yürürken sıçramasın
const FADE_RATE := 1.5 ## 0..1 / sn

const AudioBuses := preload("res://scripts/audio_buses.gd")

var _grid: Dictionary = {} ## Vector2i -> Vector2 (o hücredeki su noktalarının ortalaması, dünya)
var _player: AudioStreamPlayer2D = null
var _timer: float = 0.0
var _target_pos: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _level: float = 0.0


func setup(harita: Node) -> void:
	for n: String in WATER_LAYER_NAMES:
		var layer: TileMapLayer = harita.get_node_or_null("Su/" + n) as TileMapLayer
		if layer:
			_add_layer(layer)
	## Her hücre toplamı -> ortalama.
	for k in _grid.keys():
		var acc: Vector3 = _grid[k]
		_grid[k] = Vector2(acc.x, acc.y) / maxf(acc.z, 1.0)


func _add_layer(layer: TileMapLayer) -> void:
	var xf: Transform2D = layer.global_transform
	for cell: Vector2i in layer.get_used_cells():
		var wp: Vector2 = xf * layer.map_to_local(cell)
		var g := Vector2i(floori(wp.x / GRID_CELL), floori(wp.y / GRID_CELL))
		var acc: Vector3 = _grid.get(g, Vector3.ZERO)
		_grid[g] = acc + Vector3(wp.x, wp.y, 1.0)


func _ready() -> void:
	_player = AudioStreamPlayer2D.new()
	_player.name = "RiverFlow"
	_player.bus = AudioBuses.ambient_bus()
	_player.max_distance = MAX_DISTANCE
	_player.attenuation = ATTENUATION
	_player.volume_db = -80.0
	if ResourceLoader.exists(SOUND_PATH):
		var stream: AudioStream = load(SOUND_PATH) as AudioStream
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(round(wav.get_length() * float(wav.mix_rate)))
		_player.stream = stream
	add_child(_player)
	## Seviye atlama / duraklatma ekranlarında akıntı birden susmasın (hava sesleriyle aynı).
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _player == null or _player.stream == null or _grid.is_empty():
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = UPDATE_INTERVAL
		_refresh_target()
	if _has_target:
		_player.global_position = _player.global_position.lerp(_target_pos, clampf(FOLLOW_RATE * delta, 0.0, 1.0))
	var want: float = 1.0 if _has_target else 0.0
	_level = move_toward(_level, want, FADE_RATE * delta)
	if _level <= 0.001:
		if _player.playing:
			_player.stop()
		return
	if not _player.playing:
		_player.play()
	_player.volume_db = VOLUME_DB + linear_to_db(maxf(_level, 0.001))


func _refresh_target() -> void:
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if p == null or p.get("is_indoors") == true:
		_has_target = false
		return
	var pos: Vector2 = p.global_position
	var r: int = ceili(HEAR_RADIUS / GRID_CELL)
	var c := Vector2i(floori(pos.x / GRID_CELL), floori(pos.y / GRID_CELL))
	var best_d: float = HEAR_RADIUS * HEAR_RADIUS
	var best := Vector2.ZERO
	var found: bool = false
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var g: Variant = _grid.get(c + Vector2i(dx, dy))
			if g == null:
				continue
			var d: float = pos.distance_squared_to(g)
			if d < best_d:
				best_d = d
				best = g
				found = true
	if found and not _has_target:
		_player.global_position = best ## ilk bulunuşta kaymadan oraya
	_has_target = found
	if found:
		_target_pos = best
