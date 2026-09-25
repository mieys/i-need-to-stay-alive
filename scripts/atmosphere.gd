extends Node2D

## Gün-gece döngüsü + hava durumu yöneticisi (kullanıcı isteği 2026-09-25: "oyunuma hava durumu ve gündüz-gece-gün
## doğumu-gün batımına uyumlu renklere sahip doğal gündönümü sistemi ... hava durumları rastgele rüzgarlı veya yağmurlu
## olacak, renk ayarları buna göre değişecek ... gece olunca görüş açısı %25 azalacak").
##
## PARÇALAR (hepsi bu düğümün kurduğu/yönettiği):
##  - atmosphere_math.gd     : saf formüller (karanlık, renk anahtarları, görüş çarpanı, hava seçimi) - TEK kaynak.
##  - atmosphere_overlay.gd  : ekran renk geçişi + gece ışık haritası (main.gd VisionFog'un hemen önüne koyar).
##  - weather_rain.gd / weather_wind.gd : dünyada çizilen piksel yağmur (damlacık sıçramaları) / rüzgar akıntıları.
##  - night_glow.gd + night_glow_catalog.gd : yetenek/mermi/namlu/görev/düşman büyüsü ışıkları - SceneTree.node_added
##    ile her yeni düğüme katalogdan OTOMATİK takılır (yerel ve uzak kopyalar aynı yoldan üretildiği için ikisine de).
##  - vision_fog.gd get_vision_multiplier() ile görüş yarıçapını buradan okur (gece x0.75, kademeli).
##
## AĞ (host-yetkili, traveling_merchant.gd/enemy_spawner.gd ile aynı desen): saat ve hava durumunu SADECE host (ya da
## tek oyunculu) ilerletir/seçer; NetworkManager.broadcast_atmosphere_state ile SYNC_INTERVAL'da bir + her hava
## değişiminde tüm istemcilere gönderir, sonradan katılana peer_needs_game_catchup ile hedefli gönderir. İstemciler
## aradaki karelerde saati kendileri yürütür (akıcı), gelen değere küçük farkta yumuşakça (birkaç saniyede), büyük farkta
## anında uyar. Renk/görüş formülü her istemcide yerel (atmosphere_math.gd) - aynı saat = aynı karanlık/görüş.
##
## Ev içi: yerel oyuncu evdeyken renk geçişi, yağmur/rüzgar ve sesleri kapanır (evin içi hep aydınlık/kuru); saat
## dışarıda işlemeye devam eder.

const AtmosphereMath := preload("res://scripts/atmosphere_math.gd")
const OverlayScript := preload("res://scripts/atmosphere_overlay.gd")
const RainScript := preload("res://scripts/weather_rain.gd")
const WindScript := preload("res://scripts/weather_wind.gd")
const StormScript := preload("res://scripts/weather_storm.gd")
const AudioBuses := preload("res://scripts/audio_buses.gd")
const NightGlowScript := preload("res://scripts/night_glow.gd")
const GlowCatalog := preload("res://scripts/night_glow_catalog.gd")

const GROUP := &"atmosphere"
const SYNC_INTERVAL := 4.0
## İstemci saati host'tan bu kadar saniyeden fazla saparsa anında atlar, azsa yumuşakça yetişir.
const SNAP_THRESHOLD := 30.0
const CORRECTION_RATE := 1.2
## İstemcinin kendi yürüttüğü hava şiddeti host'unkinden bu kadar saparsa doğrudan host değeri alınır.
const INTENSITY_SNAP := 0.2

## Kullanıcı seçimi (2026-09-25): yağmur ve rüzgar sesi Claude tarafından üretildi (tools/gen_weather_sounds.py).
## Dosya yoksa/henüz import edilmediyse sessiz kalınır (hata yok).
const RAIN_SOUND_PATH := "res://assets/audio/weather_rain_loop.wav"
const WIND_SOUND_PATH := "res://assets/audio/weather_wind_loop.wav"
## Kullanıcı bildirimi (2026-09-25): "hava durumu sesleri biraz fazla oyunda" - bütün hava sesleri ~5 dB kısıldı
## (yağmur -10 -> -15, rüzgar -12 -> -17, sağanak eki +3 -> +2, fırtına uğultusu -3 -> -9 / hamle ±3 -> ±2; yıldırım ve uzak
## gök gürültüsü weather_storm.gd / fx_storm_strike.gd'de aynı oranda).
const RAIN_VOLUME_DB := -15.0
const WIND_VOLUME_DB := -17.0
## Sağanak (kullanıcı isteği 2026-09-25): yağmur ve rüzgar BİRLİKTE, ikisi de daha gür; yağmur damlası yoğunluğu x1.6.
const STORM_EXTRA_DB := 2.0
const STORM_RAIN_DENSITY := 1.6
## Kullanıcı bildirimi (2026-09-25): "rüzgar fırtına sesi gelmiyor fazla" - sağanakta normal rüzgarın ÜSTÜNE ayrı, gür bir
## fırtına uğultusu katmanı (tools/gen_weather_sounds.py storm_wind); ses seviyesi yavaş bir hamle dalgasıyla ±GUST_DB oynar.
const STORM_WIND_SOUND_PATH := "res://assets/audio/storm/storm_wind_loop.wav"
const STORM_WIND_VOLUME_DB := -9.0
const STORM_WIND_GUST_DB := 2.0
## Sağanakta bitkiler rüzgarlı havadan da sert sallanır.
const SWAY_STORM_MULT := 2.8

## Haritanın ESKİ rüzgar çizgisi kaplaması (harita_baked.tscn "CanvasLayer/ColorRect", rüzgar efekti.gdshader) kullanıcı
## isteğiyle (2026-09-25) haritadan KALDIRILDI - yerini weather_wind.gd'nin her havada esen "pasif esinti"si aldı. Godot
## editörü sahneyi açık tutup eski hâliyle yeniden kaydederse (bkz. CLAUDE.md) katman geri gelebilir: bulunursa çalışma
## anında silinir ki iki rüzgar üst üste binmesin.
const LEGACY_WIND_LAYER_PATH := "Harita/CanvasLayer"
const LEGACY_WIND_SHADER_PATH := "res://scenes/rüzgar efekti.gdshader"
## Bitki/çalı sallanma shader'ı (sallantı.gdshader) - rüzgarlı havada salınım gücü bu kadar artar. SADECE "strength"
## değişir: "speed" TIME ile çarpıldığı için değiştirmek fazı zıplatırdı.
const SWAY_SHADER_PATH := "res://scenes/sallantı.gdshader"
const SWAY_WINDY_MULT := 1.9
## Ekran kenarı karartması (VignetteOverlay) gece bu kadar koyulaşır - dar görüşü destekleyen yumuşak bir çerçeve.
## 2026-09-25: 1.8 -> 1.6 (kullanıcı: "gece aşırı karanlık", bkz. atmosphere_math.gd DARKNESS_SCALE).
const VIGNETTE_PATH := "VignetteOverlay/Vignette"
const VIGNETTE_NIGHT_MULT := 1.6

var cycle_time: float = AtmosphereMath.START_TIME
var weather: int = AtmosphereMath.Weather.CLEAR
var rain_intensity: float = 0.0
var wind_intensity: float = 0.0
## Sağanak şiddeti (0..1) - yağmur/rüzgarın ÜSTÜNE ek kararma, daha yoğun yağmur ve yıldırım (bkz. weather_storm.gd).
var storm_intensity: float = 0.0
var wind_angle: float = 0.0
## Debug menüsü: saati hızlandırır (1 = normal). Host'ta ayarlanır, istemcilere de gider.
var debug_time_scale: float = 1.0

var _weather_remaining: float = 0.0
var _sync_timer: float = 0.0
var _time_fix: float = 0.0
var _received_first_sync: bool = false
var _grade: Dictionary = {}

var _overlay: CanvasLayer = null
var _rain: Node2D = null
var _wind: Node2D = null
var _storm: Node = null
var _rain_player: AudioStreamPlayer = null
var _wind_player: AudioStreamPlayer = null
var _storm_wind_player: AudioStreamPlayer = null
var _gust_t: float = 0.0
var _last_sway_k: float = -1.0
var _last_vignette_k: float = -1.0

var _sway_materials: Array = [] ## [ShaderMaterial, taban strength]
var _vignette_material: ShaderMaterial = null
var _vignette_base: float = 0.0
var _map_refs_searched: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	_weather_remaining = randf_range(AtmosphereMath.WEATHER_MIN_DURATION, AtmosphereMath.WEATHER_MAX_DURATION)
	wind_angle = _random_wind_angle()

	_rain = Node2D.new()
	_rain.name = "Rain"
	_rain.set_script(RainScript)
	add_child(_rain)
	_wind = Node2D.new()
	_wind.name = "Wind"
	_wind.set_script(WindScript)
	add_child(_wind)
	_storm = Node.new()
	_storm.name = "Storm"
	_storm.set_script(StormScript)
	add_child(_storm)

	_rain_player = _make_loop_player("RainSound", RAIN_SOUND_PATH)
	_wind_player = _make_loop_player("WindSound", WIND_SOUND_PATH)
	_storm_wind_player = _make_loop_player("StormWindSound", STORM_WIND_SOUND_PATH)

	NetworkManager.atmosphere_state_received.connect(_on_state_received)
	NetworkManager.peer_needs_game_catchup.connect(_on_peer_needs_game_catchup)
	get_tree().node_added.connect(_on_node_added)
	_scan_existing.call_deferred()
	_grade = AtmosphereMath.grade(cycle_time, rain_intensity, wind_intensity)


func _exit_tree() -> void:
	if get_tree() and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


## main.gd çağırır: ekran geçişi katmanını üretir; main.gd onu VisionFog'un hemen önüne yerleştirir (bkz. main.gd).
func create_overlay_layer() -> CanvasLayer:
	_overlay = CanvasLayer.new()
	_overlay.name = "AtmosphereOverlay"
	_overlay.set_script(OverlayScript)
	return _overlay


## vision_fog.gd'nin görüş yarıçapı çarpanı (1.0 gündüz -> 0.75 gece, kademeli).
func get_vision_multiplier() -> float:
	return AtmosphereMath.vision_multiplier(cycle_time)


func get_darkness() -> float:
	return AtmosphereMath.darkness(cycle_time)


func is_authority() -> bool:
	return not NetworkManager.is_multiplayer_active or NetworkManager.is_host


func _process(delta: float) -> void:
	cycle_time = AtmosphereMath.wrap_time(cycle_time + delta * debug_time_scale)
	if is_authority():
		_process_weather_authority(delta)
	elif _time_fix != 0.0:
		var step: float = _time_fix * minf(1.0, delta * CORRECTION_RATE)
		cycle_time = AtmosphereMath.wrap_time(cycle_time + step)
		_time_fix -= step
		if absf(_time_fix) < 0.01:
			_time_fix = 0.0

	var fade_step: float = delta / AtmosphereMath.WEATHER_FADE_TIME
	var targets: Vector3 = AtmosphereMath.weather_targets(weather)
	rain_intensity = move_toward(rain_intensity, targets.x, fade_step)
	wind_intensity = move_toward(wind_intensity, targets.y, fade_step)
	storm_intensity = move_toward(storm_intensity, targets.z, fade_step)

	var indoors: bool = _local_player_indoors()
	_storm.call("set_storm", storm_intensity, indoors)
	_grade = AtmosphereMath.grade(cycle_time, rain_intensity, wind_intensity, storm_intensity, float(_storm.get("flash")))
	if _overlay and is_instance_valid(_overlay) and _overlay.has_method("apply"):
		_overlay.call("apply", _grade, indoors)
	var outdoor_k: float = 0.0 if indoors else 1.0
	_rain.call("set_intensity", rain_intensity * lerpf(1.0, STORM_RAIN_DENSITY, storm_intensity) * outdoor_k, 1.0 if cos(wind_angle) >= 0.0 else -1.0, storm_intensity)
	_wind.call("set_wind", wind_intensity * outdoor_k, wind_angle, outdoor_k, storm_intensity)
	_gust_t += delta
	_update_sounds(rain_intensity * outdoor_k, wind_intensity * outdoor_k, storm_intensity * outdoor_k)
	_update_map_atmosphere()


func _process_weather_authority(delta: float) -> void:
	_weather_remaining -= delta
	if _weather_remaining <= 0.0:
		weather = AtmosphereMath.pick_weather(randf())
		_weather_remaining = randf_range(AtmosphereMath.WEATHER_MIN_DURATION, AtmosphereMath.WEATHER_MAX_DURATION)
		if weather != AtmosphereMath.Weather.CLEAR:
			wind_angle = _random_wind_angle()
		_broadcast_state()
		return
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_broadcast_state()


## Rüzgar çoğunlukla yatay (sağa ya da sola), hafif eğik.
static func _random_wind_angle() -> float:
	var base: float = 0.0 if randf() < 0.5 else PI
	return base + randf_range(-0.28, 0.28)


func _state() -> Dictionary:
	return {
		"t": cycle_time,
		"w": weather,
		"ri": rain_intensity,
		"wi": wind_intensity,
		"si": storm_intensity,
		"wa": wind_angle,
		"wr": _weather_remaining,
		"ts": debug_time_scale,
	}


func _broadcast_state() -> void:
	_sync_timer = SYNC_INTERVAL
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		NetworkManager.broadcast_atmosphere_state.rpc(_state())


func _on_peer_needs_game_catchup(peer_id: int) -> void:
	if not NetworkManager.is_host:
		return
	NetworkManager.broadcast_atmosphere_state.rpc_id(peer_id, _state())


func _on_state_received(state: Dictionary) -> void:
	if is_authority():
		return
	var host_t: float = float(state.get("t", cycle_time))
	var diff: float = wrapf(host_t - cycle_time, -AtmosphereMath.CYCLE_LENGTH * 0.5, AtmosphereMath.CYCLE_LENGTH * 0.5)
	if not _received_first_sync or absf(diff) > SNAP_THRESHOLD:
		cycle_time = AtmosphereMath.wrap_time(host_t)
		_time_fix = 0.0
	else:
		_time_fix = diff
	weather = int(state.get("w", weather))
	wind_angle = float(state.get("wa", wind_angle))
	_weather_remaining = float(state.get("wr", _weather_remaining))
	debug_time_scale = float(state.get("ts", 1.0))
	var ri: float = float(state.get("ri", rain_intensity))
	var wi: float = float(state.get("wi", wind_intensity))
	var si: float = float(state.get("si", storm_intensity))
	if not _received_first_sync or absf(si - storm_intensity) > INTENSITY_SNAP:
		storm_intensity = si
	if not _received_first_sync or absf(ri - rain_intensity) > INTENSITY_SNAP:
		rain_intensity = ri
	if not _received_first_sync or absf(wi - wind_intensity) > INTENSITY_SNAP:
		wind_intensity = wi
	_received_first_sync = true


func _local_player_indoors() -> bool:
	var p: Node = get_tree().get_first_node_in_group("player")
	return p != null and p.has_method("is_indoors_now") and bool(p.call("is_indoors_now"))


## ------------------------------------------------------------------ Debug (bkz. debug_menu.gd "Atmosfer")
## Çok oyunculuda SADECE host değiştirebilir (debug_menu.gd'nin görev/yaratık kuralıyla aynı) - false = izin yok.
func debug_set_time(t: float) -> bool:
	if not is_authority():
		return false
	cycle_time = AtmosphereMath.wrap_time(t)
	_broadcast_state()
	return true


func debug_set_weather(kind: int) -> bool:
	if not is_authority():
		return false
	weather = clampi(kind, 0, AtmosphereMath.WEATHER_NAMES.size() - 1)
	_weather_remaining = AtmosphereMath.WEATHER_MAX_DURATION
	if weather != AtmosphereMath.Weather.CLEAR:
		wind_angle = _random_wind_angle()
	_broadcast_state()
	return true


## Debug menüsü: yerel oyuncunun yakınına hemen bir yıldırım (sadece yetkili, hava fark etmez).
func debug_force_strike(_unused: Variant = null) -> bool:
	return _storm != null and bool(_storm.call("debug_force_strike"))


func debug_set_time_scale(scale: float) -> bool:
	if not is_authority():
		return false
	debug_time_scale = maxf(scale, 0.0)
	_broadcast_state()
	return true


func debug_describe() -> String:
	return "%s (%d:%02d / 10:00) - %s" % [AtmosphereMath.phase_name(cycle_time), int(cycle_time) / 60, int(cycle_time) % 60,
			AtmosphereMath.WEATHER_NAMES[weather]]


## ------------------------------------------------------------------ Gece ışıklarının otomatik takılması
## Her yeni düğüm: silah sahnesiyse ikonunun ucuna, katalogdaki bir efekt/mermi/objeyse kendisine ışık. Işık bir sonraki
## boşta (deferred) takılır: (1) ağaca giriş sırasında ebeveyn "çocuk ekleniyor" kilidindeyken add_child yapılmasın,
## (2) efektin setup(...)'ı (renk/yarıçap) çağrılmış olsun, (3) uzak oyuncunun silah ikonu weapon_root'tan alınıp
## RemotePlayer'a taşınmış olsun (bkz. remote_player.gd update_weapon_visuals) - ışık ikonla birlikte gider.
func _on_node_added(node: Node) -> void:
	var scene_path: String = node.scene_file_path
	if not scene_path.is_empty() and GlowCatalog.WEAPON_TIPS.has(scene_path):
		var icon: Node = node.get_node_or_null("Icon")
		if icon != null:
			_attach_glow.call_deferred(icon, GlowCatalog.WEAPON_TIPS[scene_path])
		return
	var raw: Dictionary = GlowCatalog.profile_for(node)
	if not raw.is_empty():
		_attach_glow.call_deferred(node, raw)


func _attach_glow(target: Node, raw: Dictionary) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():
		return
	if target.has_node("NightGlow"):
		return
	var profile: Dictionary = GlowCatalog.resolve(target, raw)
	if profile.is_empty():
		return
	NightGlowScript.attach(target, profile)


## Atmosfer kurulmadan ÖNCE sahnede zaten olan silahlar/efektler (ör. yeniden başlatmada geri yüklenen silahlar).
func _scan_existing() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != root:
			_on_node_added(n)
		for c: Node in n.get_children():
			stack.append(c)


## ------------------------------------------------------------------ Ses
func _make_loop_player(node_name: String, path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	## Ortam sesi yolu: Şovalye kubbesinin içindeyken boğulur (bkz. audio_buses.gd).
	player.bus = AudioBuses.ambient_bus()
	## Seviye atlama/duraklatma ekranlarında yağmur birden susmasın (WindBreezeAmbient ile aynı).
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path) as AudioStream
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(round(wav.get_length() * float(wav.mix_rate)))
		player.stream = stream
	player.volume_db = -80.0
	add_child(player)
	return player


func _update_sounds(rain: float, wind: float, storm: float = 0.0) -> void:
	_set_loop_volume(_rain_player, rain, RAIN_VOLUME_DB + STORM_EXTRA_DB * storm)
	_set_loop_volume(_wind_player, wind, WIND_VOLUME_DB + STORM_EXTRA_DB * storm)
	## Hamle dalgası: iki farklı periyotlu sinüs (tekrar etmeyen, doğal hissettiren kabarma/dinme).
	var gust: float = 0.6 * sin(_gust_t * 0.9) + 0.4 * sin(_gust_t * 2.3 + 1.1)
	_set_loop_volume(_storm_wind_player, storm, STORM_WIND_VOLUME_DB + STORM_WIND_GUST_DB * gust)


static func _set_loop_volume(player: AudioStreamPlayer, amount: float, full_db: float) -> void:
	if player == null or player.stream == null:
		return
	if amount <= 0.01:
		if player.playing:
			player.stop()
		return
	## Kulak logaritmik duyar: şiddet 0..1 doğrusal genliğe çevrilip dB'ye.
	player.volume_db = full_db + linear_to_db(clampf(amount, 0.01, 1.0))
	if not player.playing:
		player.play(randf() * maxf(player.stream.get_length() - 0.1, 0.0))


## ------------------------------------------------------------------ Harita atmosferi (bitki salınımı, vinyet)
## bkz. LEGACY_WIND_LAYER_PATH notu - sadece gerçekten eski rüzgar shader'ını taşıyan katmanı siler.
func _remove_legacy_wind_layer(root: Node) -> void:
	var layer: Node = root.get_node_or_null(LEGACY_WIND_LAYER_PATH)
	if layer == null or not (layer is CanvasLayer):
		return
	for c: Node in layer.get_children():
		var ci := c as CanvasItem
		if ci and ci.material is ShaderMaterial and (ci.material as ShaderMaterial).shader \
				and (ci.material as ShaderMaterial).shader.resource_path == LEGACY_WIND_SHADER_PATH:
			layer.queue_free()
			return


func _find_map_refs() -> void:
	_map_refs_searched = true
	var root: Node = get_parent()
	if root == null:
		return
	_remove_legacy_wind_layer(root)
	var map_root: Node = root.get_node_or_null("Harita")
	if map_root:
		var stack: Array[Node] = [map_root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c2: Node in n.get_children():
				stack.append(c2)
			var ci := n as CanvasItem
			if ci == null or not (ci.material is ShaderMaterial):
				continue
			var mat := ci.material as ShaderMaterial
			if mat.shader == null or mat.shader.resource_path != SWAY_SHADER_PATH:
				continue
			var already: bool = false
			for entry: Array in _sway_materials:
				if entry[0] == mat:
					already = true
			if not already:
				_sway_materials.append([mat, float(mat.get_shader_parameter("strength"))])
	var vig := root.get_node_or_null(VIGNETTE_PATH) as CanvasItem
	if vig and vig.material is ShaderMaterial:
		_vignette_material = vig.material as ShaderMaterial
		_vignette_base = float(_vignette_material.get_shader_parameter("intensity"))


func _update_map_atmosphere() -> void:
	if not _map_refs_searched:
		_find_map_refs()
	var darkness: float = AtmosphereMath.darkness(cycle_time)
	## PERF (kullanıcı bildirimi 2026-09-25 "hava durumları fpsi düşürüyor"): shader parametreleri eskiden HER karede
	## (değişmese bile) yazılıyordu - artık sadece değer gerçekten değişince.
	var sway_k: float = lerpf(1.0, SWAY_WINDY_MULT, wind_intensity) * lerpf(1.0, SWAY_STORM_MULT / SWAY_WINDY_MULT, storm_intensity)
	if absf(sway_k - _last_sway_k) > 0.005:
		_last_sway_k = sway_k
		for entry: Array in _sway_materials:
			(entry[0] as ShaderMaterial).set_shader_parameter("strength", float(entry[1]) * sway_k)
	if _vignette_material and absf(darkness - _last_vignette_k) > 0.002:
		_last_vignette_k = darkness
		_vignette_material.set_shader_parameter("intensity", _vignette_base * lerpf(1.0, VIGNETTE_NIGHT_MULT, darkness))
