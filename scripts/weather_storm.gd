extends Node

## Sağanak havasının yıldırım yöneticisi (kullanıcı isteği 2026-09-25: "yeni hava durumu: sağanak yağış ... rasgele
## aralıklarla rasgele konumlara yıldırım düşmeli, yıldırım düştüğü yerdeki yaratıklara ciddi hasar vermeli ve düşmeden
## önce düşeceği yerde hafif elektriklenme olmalı ki dikkatli olalım ... herşeyin optimize olması gerekiyor").
## atmosphere.gd'nin çocuğu; atmosphere her karede set_storm() ile sağanak şiddetini verir, grade() için flash'ı okur.
##
## AĞ (atmosphere.gd ile aynı host-yetkili desen): yıldırımın ZAMANI ve KONUMU sadece host'ta (tek oyunculuda yerel)
## seçilir, NetworkManager.broadcast_lightning_strike (call_local, reliable) ile herkese gider -> her istemci aynı noktada
## aynı uyarı+yıldırımı kendi yerel olarak oynatır (fx_storm_strike.tscn). Hasar:
##  - yaratıklar: SADECE host uygular (yaratık canı host-yetkili, take_damage_host) - istemcilerde çift hasar olmaz.
##  - oyuncular: her istemci KENDİ oyuncusuna uygular (take_special_damage, tipi "lightning") - oyuncu canı zaten her
##    istemcide yerel; uyarı herkeste aynı anda başladığı için kaçma şansı herkeste aynı.
## Uzak gök gürültüsü + gökyüzü parlaması (yıldırımsız, kozmetik) her istemcide yerel rastgele - senkron gerekmez.
##
## Maliyet: yıldırım başına 1 kök düğüm + en fazla 4 sprite/ses çocuğu, birkaç saniyede bir; yaratık taraması SADECE
## çarpma anında, host'ta, tek geçiş (enemies grubu). Kare başına iş: birkaç sayaç.

const StrikeScene := preload("res://scenes/fx_storm_strike.tscn")
const DropAttraction := preload("res://scripts/drop_attraction.gd")
const DISTANT_SOUNDS := ["res://assets/audio/storm/thunder_distant_1.wav", "res://assets/audio/storm/thunder_distant_2.wav"]

## Etki alanı: STRIKE_RADIUS x (STRIKE_RADIUS * STRIKE_Y_RATIO) elipsi (dünya birimi) - uyarı halkasının çizdiği alanla
## BİREBİR aynı (tools/gen_storm_fx.py STRIKE_RX/RY 56x34).
const STRIKE_RADIUS := 56.0
const STRIKE_Y_RATIO := 34.0 / 56.0
const WARN_TIME := 1.3
## Sağanak tam oturunca (şiddet >= STRIKE_MIN_STORM) yıldırım aralığı (sn).
const STRIKE_MIN_INTERVAL := 3.5
const STRIKE_MAX_INTERVAL := 8.0
const STRIKE_MIN_STORM := 0.7
## Konum: dışarıdaki canlı oyunculardan rastgele birinin etrafında bu uzaklık aralığında (ekranda görünür, bazen yakın).
const STRIKE_MAX_OFFSET := 460.0
## "Ciddi hasar" (Claude'un yorumu): sıradan yaratık maks. canının %40'ı, boss %6'sı; kalkanın yarısını deler.
const ENEMY_DAMAGE_RATIO := 0.40
const BOSS_DAMAGE_RATIO := 0.06
const ENEMY_SHIELD_PEN := 0.5
## "dikkatli olalım" -> oyuncuya da çarpar (Claude'un yorumu): maks. canın %12'si (uyarıdan kaçılabilir).
const PLAYER_DAMAGE_RATIO := 0.12
## Yıldırım ekranda/yakında ise ekran flaşı + ses; uzaktaysa (bu kadar birimden) sadece ses.
const FLASH_RANGE := 1100.0
const FLASH_DECAY := 3.2
## Kozmetik uzak gök gürültüsü aralığı (sn).
const DISTANT_MIN_INTERVAL := 6.0
const DISTANT_MAX_INTERVAL := 14.0

var storm: float = 0.0
var indoors: bool = false
## Ekran flaşı 0..1 (atmosphere_math.gd grade "flash").
var flash: float = 0.0

var _strike_timer: float = 4.0
var _distant_timer: float = 5.0
var _flash_queue: Array = [] ## [gecikme, güç] - yıldırımın ikinci titremesi
var _distant_player: AudioStreamPlayer = null


func _ready() -> void:
	NetworkManager.lightning_strike_received.connect(_on_strike_received)
	_distant_player = AudioStreamPlayer.new()
	_distant_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_distant_player.bus = preload("res://scripts/audio_buses.gd").ambient_bus() ## kubbe içinde boğulur
	add_child(_distant_player)


func set_storm(value: float, p_indoors: bool) -> void:
	storm = value
	indoors = p_indoors


func is_authority() -> bool:
	return not NetworkManager.is_multiplayer_active or NetworkManager.is_host


func _process(delta: float) -> void:
	_update_flash(delta)
	if storm <= 0.01:
		return
	if is_authority() and storm >= STRIKE_MIN_STORM:
		_strike_timer -= delta
		if _strike_timer <= 0.0:
			_strike_timer = randf_range(STRIKE_MIN_INTERVAL, STRIKE_MAX_INTERVAL)
			var pos: Variant = _pick_strike_position()
			if pos != null:
				_announce_strike(pos as Vector2)
	if not indoors:
		_distant_timer -= delta
		if _distant_timer <= 0.0:
			_distant_timer = randf_range(DISTANT_MIN_INTERVAL, DISTANT_MAX_INTERVAL)
			_distant_thunder()


func _announce_strike(pos: Vector2) -> void:
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_lightning_strike.rpc(pos)
	else:
		_on_strike_received(pos)


## Debug menüsü: yerel oyuncunun yakınına hemen bir yıldırım (sadece yetkili).
func debug_force_strike() -> bool:
	if not is_authority():
		return false
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return false
	_announce_strike(p.global_position + Vector2.from_angle(randf() * TAU) * randf_range(40.0, 120.0))
	return true


func _pick_strike_position() -> Variant:
	var anchors: Array[Node2D] = []
	for n: Node in [get_tree().get_first_node_in_group("player")] + get_tree().get_nodes_in_group("remote_players"):
		var p := n as Node2D
		if p == null or not is_instance_valid(p) or p.get("is_dead") == true:
			continue
		if p.has_method("is_indoors_now") and bool(p.call("is_indoors_now")):
			continue
		if p.get("is_indoors") == true:
			continue
		anchors.append(p)
	if anchors.is_empty():
		return null
	var a: Node2D = anchors[randi() % anchors.size()]
	## sqrt: alana eşit dağılım (merkeze yığılmaz) - bazen dibine, çoğunlukla ekranın bir yerine.
	return a.global_position + Vector2.from_angle(randf() * TAU) * STRIKE_MAX_OFFSET * sqrt(randf())


func _on_strike_received(pos: Vector2) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var fx: Node2D = StrikeScene.instantiate()
	fx.set("warn_time", WARN_TIME)
	fx.set("on_strike", _on_strike_landed)
	## Ev içindeyken dışarıdaki yıldırımın sesi/flaşı yok (atmosphere.gd ev içi kuralı), görsel zaten görünmez.
	fx.set("play_sounds", not indoors)
	scene_root.add_child(fx)
	fx.global_position = pos
	DropAttraction.place_on_ground(fx)


func _on_strike_landed(pos: Vector2) -> void:
	_apply_damage(pos)
	if indoors:
		return
	var cam := get_viewport().get_camera_2d()
	if cam and cam.get_screen_center_position().distance_to(pos) <= FLASH_RANGE:
		flash = 1.0
		_flash_queue = [[0.12, 0.75]]


static func in_strike_area(point: Vector2, center: Vector2) -> bool:
	var d: Vector2 = point - center
	return (d.x / STRIKE_RADIUS) ** 2 + (d.y / (STRIKE_RADIUS * STRIKE_Y_RATIO)) ** 2 <= 1.0


func _apply_damage(pos: Vector2) -> void:
	if is_authority():
		for n: Node in get_tree().get_nodes_in_group("enemies"):
			var e := n as Node2D
			if e == null or not is_instance_valid(e) or e.get("is_dead") == true:
				continue
			if not in_strike_area(e.global_position, pos) or not e.has_method("take_damage_host"):
				continue
			var ratio: float = BOSS_DAMAGE_RATIO if e.get("is_boss") == true else ENEMY_DAMAGE_RATIO
			e.call("take_damage_host", float(e.get("max_health")) * ratio, false, ENEMY_SHIELD_PEN, 0)
	var lp := get_tree().get_first_node_in_group("player") as Node2D
	if lp == null or lp.get("is_dead") == true or lp.get("is_downed") == true:
		return
	if in_strike_area(lp.global_position, pos) and lp.has_method("take_special_damage"):
		lp.call("take_special_damage", float(lp.get("max_health")) * PLAYER_DAMAGE_RATIO, null, "lightning")


func _update_flash(delta: float) -> void:
	if not _flash_queue.is_empty():
		var q: Array = _flash_queue[0]
		q[0] = float(q[0]) - delta
		if float(q[0]) <= 0.0:
			flash = maxf(flash, float(q[1]))
			_flash_queue.pop_front()
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * FLASH_DECAY)


func _distant_thunder() -> void:
	## Yıldırımsız uzak gürültü + hafif gökyüzü parlaması (flaş gürültüden biraz önce - ışık sesten hızlı).
	flash = maxf(flash, randf_range(0.2, 0.35))
	var path: String = DISTANT_SOUNDS[randi() % DISTANT_SOUNDS.size()]
	if not ResourceLoader.exists(path) or _distant_player.playing:
		return
	_distant_player.stream = load(path)
	_distant_player.volume_db = -16.0 + 4.0 * (storm - 1.0) ## 2026-09-25: -5 dB ("hava sesleri biraz fazla")
	_distant_player.pitch_scale = randf_range(0.85, 1.05)
	get_tree().create_timer(randf_range(0.3, 0.9), false).timeout.connect(func() -> void:
		if is_instance_valid(_distant_player) and not indoors:
			_distant_player.play())
