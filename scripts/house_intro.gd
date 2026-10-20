extends Node
class_name HouseIntro

## OYUN AÇILIŞI (kullanıcı isteği 2026-10-19, madde 313): "oyuncular bu evin içinde spawnlanacak ... bazıları kanepede oturacak bazıları
## kenarda duracak bazıları şöminenin yanında. oyun başlangıcının hikayesi herkes huzurluyken birden depreme benzer seslerin gelmesi ve
## 30 saniyelik geri sayımın başlayıp yaratıkların adaya saldırdığının bildirimi gelmesi ile olacak. deprem esnasında oyuncular ve
## büyükanne endişeli görünecek (üstlerinde korktuklarına dair emoji) ... büyükanne pencereden bakarak adaya canavarların saldırdığını
## söyleyecek ve oyuncular dışarı çıkıp savaşa koyulacak."
##  - Evreler: PEACE (huzur, PEACE_SECONDS) -> COUNTDOWN (deprem + bildirim + 30 sn geri sayım; ilk QUAKE_SECONDS'i sarsıntı) -> DONE.
##  - GameManager.invasion_pending açılış boyunca true: yaratık doğmaz, oyun saati işlemez (enemy_spawner.gd / game_manager.gd).
##  - Zaman HOST'ta: çok oyunculuda huzur saati herkesin Main'i hazır olunca (ya da READY_TIMEOUT) başlar; evre geçişleri güvenilir RPC
##    (bu düğüm: Main/HouseInterior/HouseIntro). İstemci aldığı evreyi kendi saatiyle de sürdürür (paket kaçsa da geri sayım biter);
##    sonradan katılana yakalama ile o anki evre + kalan süre gider.
##  - Görünenler her peer'de YEREL (ağ trafiği yok): oyuncu oturuş/duruş yerleri (kendi oyuncusunu dizinine göre yerleştirir - oturuş
##    klibi ride_<yön> ağdan klip adıyla gider), deprem sesi + kamera sarsıntısı + tavandan toz (house_damage_fx.gd), korku balonları
##    (fear_emote.gd), babaanne (babaanne_npc.gd evreyi okur: endişe -> pencereden bakar -> "canavarlar saldırıyor").

signal phase_changed(phase: int)

enum Phase { NONE, PEACE, COUNTDOWN, DONE }

const PEACE_SECONDS := 9.0
const COUNTDOWN_SECONDS := 30.0
const QUAKE_SECONDS := 5.5
const READY_TIMEOUT := 20.0 ## çok oyunculu: yavaş yükleyen oyuncuyu bundan uzun beklemez
const QUAKE_SOUND: AudioStream = preload("res://assets/audio/ev/deprem.wav")
const FearEmoteScript := preload("res://scripts/fear_emote.gd")
const CameraShakeScript := preload("res://scripts/camera_shake.gd")

var phase: int = Phase.NONE
var _t: float = 0.0 ## evrenin içinde geçen süre
var _wait_ready: float = 0.0
var _quake_fx_done: bool = false
var _house: Node = null
var _quake_player: AudioStreamPlayer = null
var _shake_acc: float = 0.0


func _ready() -> void:
	name = "HouseIntro"
	if not NetworkManager.peer_needs_game_catchup.is_connected(_send_catchup):
		NetworkManager.peer_needs_game_catchup.connect(_send_catchup)


func setup(house: Node) -> void:
	_house = house


func is_authority() -> bool:
	return not NetworkManager.is_multiplayer_active or NetworkManager.is_host


func is_active() -> bool:
	return phase == Phase.PEACE or phase == Phase.COUNTDOWN


## Geri sayım evresinde geçen süre (değilse -1) - babaanne'nin endişe -> pencere -> konuşma sırası bunu okur.
func countdown_elapsed() -> float:
	return _t if phase == Phase.COUNTDOWN else -1.0


func countdown_left() -> float:
	return maxf(0.0, COUNTDOWN_SECONDS - _t) if phase == Phase.COUNTDOWN else 0.0


## house_interior.gd: yeni koşunun başında (geri katılım değilken) bir kez.
func begin() -> void:
	GameManager.invasion_pending = true
	_set_phase(Phase.PEACE, 0.0)


func _process(delta: float) -> void:
	match phase:
		Phase.PEACE:
			if is_authority() and NetworkManager.is_multiplayer_active and not _all_ready():
				_wait_ready += delta
				if _wait_ready < READY_TIMEOUT:
					return ## huzur saati herkes yüklenince başlar
			_t += delta
			if is_authority() and _t >= PEACE_SECONDS:
				_host_advance(Phase.COUNTDOWN)
		Phase.COUNTDOWN:
			_t += delta
			_tick_quake(delta)
			if _t >= COUNTDOWN_SECONDS:
				if is_authority():
					_host_advance(Phase.DONE)
				elif _t >= COUNTDOWN_SECONDS + 3.0:
					_set_phase(Phase.DONE, 0.0) ## host paketi kaçtı/gecikti: yerelde de bitir


func _all_ready() -> bool:
	var expected: int = maxi(0, NetworkManager.lobby_players.size() - 1)
	return NetworkManager.game_ready_peers().size() >= expected


func _host_advance(p: int) -> void:
	_set_phase(p, 0.0)
	if NetworkManager.is_multiplayer_active:
		for pid in NetworkManager.game_ready_peers():
			_rpc_phase.rpc_id(int(pid), p, 0.0)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_phase(p: int, elapsed: float) -> void:
	if not NetworkManager._from_host():
		return
	if p == phase and absf(elapsed - _t) < 1.0:
		return
	_set_phase(p, elapsed)


func _set_phase(p: int, elapsed: float) -> void:
	var changed: bool = p != phase
	phase = p
	_t = elapsed
	match p:
		Phase.PEACE:
			GameManager.invasion_pending = true
		Phase.COUNTDOWN:
			GameManager.invasion_pending = true
			if changed:
				_start_countdown(elapsed)
		Phase.DONE:
			GameManager.invasion_pending = false
			_stop_quake()
	if changed:
		phase_changed.emit(p)


# ------------------------------------------------------------------ geri sayım + deprem

func _start_countdown(elapsed: float) -> void:
	_quake_fx_done = false
	var main: Node = _main()
	var left: float = maxf(0.0, COUNTDOWN_SECONDS - elapsed)
	if main != null and main.has_method("_show_banner_notice"):
		main.call("_show_banner_notice", "fail", "ADAYA CANAVARLAR SALDIRIYOR!",
				"Yaratıklar kıyıya vurdu - evden çık ve savaşa hazırlan!", 5.0)
	if main != null and main.has_method("_show_notice"):
		main.call("_show_notice", "warn", "CANAVARLAR GELİYOR", "Saldırı başlıyor", left, left)
	if elapsed < QUAKE_SECONDS:
		_start_quake()


func _start_quake() -> void:
	if _quake_fx_done:
		return
	_quake_fx_done = true
	_shake_acc = 0.0
	if _quake_player == null:
		_quake_player = AudioStreamPlayer.new()
		_quake_player.name = "DepremSesi"
		_quake_player.stream = QUAKE_SOUND
		_quake_player.volume_db = -3.0
		add_child(_quake_player)
	_quake_player.play()
	CameraShakeScript.add(0.55)
	var fx: Node = _house.call("get_damage_fx") if _house != null and _house.has_method("get_damage_fx") else null
	if fx != null:
		fx.call("quake", QUAKE_SECONDS)
	_show_fear_emotes()


func _tick_quake(delta: float) -> void:
	if _t > QUAKE_SECONDS:
		return
	_shake_acc -= delta
	if _shake_acc <= 0.0:
		_shake_acc = 0.25
		## sarsıntı dalgalı söner: başta güçlü, sonlara doğru hafif artçılar
		var k: float = 1.0 - _t / QUAKE_SECONDS
		if CameraShakeScript.trauma < 0.5 * k:
			CameraShakeScript.add(0.18 * k + 0.04)


func _stop_quake() -> void:
	if _quake_player != null and _quake_player.playing:
		var tw: Tween = _quake_player.create_tween()
		tw.tween_property(_quake_player, "volume_db", -40.0, 0.8)
		tw.tween_callback(_quake_player.stop)


## "bazılarının" üstünde korku balonu: oyuncu dizinine göre (her peer aynı seçer) - 3 oyuncudan 2'si; babaanne her zaman.
func _show_fear_emotes() -> void:
	if not is_inside_tree():
		return
	var i: int = 0
	for p: Node2D in NpcActor.live_players(get_tree()):
		var pid: int = int(p.get("peer_id")) if p.get("peer_id") != null else 0
		if p.is_in_group("player"):
			pid = multiplayer.get_unique_id() if NetworkManager.is_multiplayer_active else 1
		if FearEmoteScript.picks_peer(pid):
			FearEmoteScript.show_on(p, FearEmoteScript.kind_for(pid), 3.2, 0.25 + 0.35 * float(i % 3))
		i += 1
	var granny: Node2D = _house.call("get_babaanne") if _house != null and _house.has_method("get_babaanne") else null
	if is_instance_valid(granny):
		FearEmoteScript.show_on(granny, FearEmoteScript.KIND_FACE, 3.0, 0.1)


func _main() -> Node:
	if _house != null and is_instance_valid(_house) and _house.get_parent() != null:
		return _house.get_parent()
	return null


# ------------------------------------------------------------------ yakalama

func _send_catchup(peer_id: int) -> void:
	if not is_inside_tree() or not NetworkManager.is_host:
		return
	_rpc_phase.rpc_id(peer_id, phase if phase != Phase.NONE else Phase.DONE, _t)
