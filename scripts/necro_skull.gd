extends Node2D
class_name NecroSkull
const BalanceLogScript: GDScript = preload("res://scripts/balance_log.gd")

## Necromancer ULTİ - Lanetli Kafatası (skill3 id 44). Kullanıcı isteği (2026-10-11, ULTİ REWORK): kafatası %50 KÜÇÜLDÜ.
##  PASİF (R açıldıktan sonra HER ZAMAN): küçük kafatası Necromancer'ın etrafında döner; yakında yaratık görünce ona doğru uçup yere
##    çakılır (alan hasarı: saldırı gücünün %60'ı, vuruş alanı küçük). Eski ulti gibi 10sn'lik bir yetenek DEĞİL - kalıcı bir eşlikçi.
##  AKTİF (R tuşu, 10sn aktif + 60sn bekleme): kafatası %100 büyür, vuruş alanı %100 artar, hasar saldırı gücünün %150'si olur.
##  Eski korku (3sn rastgele yürüme) TEMEL'den KALDIRILDI - evrim "Korku Darbesi" (1sn) olarak geri gelir. Diğer evrimler: "Hızlı Ezme"
##  (vuruş hızı saldırı hızına bağlı), "Lanetli Mühür" (10sn %10 fazla hasar + %1 ölürse iskelet, bkz. player.gd _necro_curse_mark).
##
## Hareket DÜZ "bacaklardan" oluşur: hedef noktası seçilir -> kafatası oraya kavis çizerek uçar -> yere çakılır (vuruş alanındaki TÜM
## yaratıklara alan hasarı) -> kısa duraklama -> yeni hedef; hedef yoksa sahibinin etrafında döner. Hedef puanı = çarpma alanına girecek
## yaratık sayısı + boss önceliği - uzaklık cezası. Bacak başlangıç/bitiş/süresi ağ üzerinden yayınlandığı için
## (NetworkManager.send_player_vfx "necro_skull" / sık olan bacaklar "necro_skull_leg" = güvenilmez) diğer oyunculardaki kozmetik kopya
## AYNI yolu AYNI sürede uçar, boştayken KENDİ kuklasının etrafında döner ve bacak sonunda AYNI çarpma efektini oynatır. 4 sn'de bir "hb"
## (kalp atışı) paketi sonradan katılan/yeniden bağlanan oyuncularda kopyayı kurar. Görseller: tools/gen_necro_fx.py (assets/fx/necro/...).

const TEXEL := 1.212
const SKULL_FRAMES := preload("res://assets/fx/necro/skull_frames.tres")
const IMPACT_FRAMES := preload("res://assets/fx/necro/impact_frames.tres")
const TRAIL_FRAMES := preload("res://assets/fx/necro/trail_frames.tres")
const FxSprite := preload("res://scripts/fx_enemy_ability.gd")
const VisionFogScript := preload("res://scripts/vision_fog.gd")
const ShamanSfx := preload("res://scripts/shaman_sfx.gd")
const IMPACT_SOUND := "res://assets/audio/topuz_hit.mp3"

const DURATION := 10.0 ## AKTİF (R) süresi - player.gd SKILL3_TIMING[44] ile aynı
const PASSIVE_DAMAGE_AP_RATIO := 0.50 ## 2026-10-13 denge: 0,60 -> 0,50 (kullanıcı: "necromancera dengeleme şart", zayıflat)
const ACTIVE_DAMAGE_AP_RATIO := 1.25 ## 2026-10-13 denge: 1,50 -> 1,25
const PASSIVE_SCALE := 0.5 ## kafatası boyutu çarpanı (aktifte 1.0 = eski boyut)
const SCALE_RATE := 1.4 ## 1/sn: pasif <-> aktif geçişinde boyut yumuşatma
const EVO_FEAR_DURATION := 1.0 ## R1 Korku Darbesi
const EVO_CURSE_DURATION := 10.0 ## RF Lanetli Mühür
const EVO_CURSE_VULN := 0.10
const EVO_CURSE_SKELETON_CHANCE := 0.01
const EVO_SPEED_CAP := 8.0 ## R2 Hızlı Ezme: saldırı hızı çarpanı üst sınırı
## Oyunun genel kuralı: bosslar korkmaz (Melek'in Kutsal Korku'su da böyle, bkz. enemy.gd apply_fear). Kafatası bosslara
## ÖNCELİK verir ve tam hasar vurur ama onları korkutmaz; true yapılırsa bosslar da korkar.
const FEAR_AFFECTS_BOSSES := false
const IMPACT_RADIUS := 68.0 ## AKTİF vuruş yarıçapı (çarpma halkası 56 sanat px * TEXEL); pasifte x0.5, bkz. _impact_radius
const SPEED := 460.0
const MIN_LEG_TIME := 0.22
const IMPACT_PAUSE := 0.24
const SEEK_RANGE := 620.0 ## AKTİF: hedefler Necromancer'ın bu yarıçapından seçilir (ekran dışına kaçmasın)
const PASSIVE_SEEK_RANGE := 380.0 ## PASİF: "etrafta bir yaratık gördüğünde"
const BOSS_PRIORITY := 6.0
const FEARED_PENALTY := 0.6
const DIST_PENALTY := 260.0 ## puan: her 260 birim uzaklık -1
const MAX_CENTER_CANDIDATES := 48
const RETRY_INTERVAL := 0.25
## Boştayken sahibin etrafında dönüş (dünya birimi / rad/sn); yassı elips = yukarıdan bakış.
const ORBIT_RADIUS := 46.0
const ORBIT_SPEED := 1.9
const ORBIT_SQUASH := 0.62
const CATCHUP_SPEED := 520.0
const HEARTBEAT_INTERVAL := 4.0
## Uçuş yüksekliği (dünya birimi, çene ucunun yerden yüksekliği) - bacak sonunda yere çakılır.
const HOVER_H := 30.0
const ARC_H := 12.0
const SLAM_H := 4.0
const SKULL_BOTTOM := 34.0 * TEXEL ## hücre merkezinden çene ucuna (sanat px 34)
const SHADOW_Y := -28.0 * TEXEL ## gölge elipsinin hücre içi konumu (y=64) yere otursun
const TRAIL_INTERVAL := 0.06
const IDLE_FOLLOW_OFFSET := Vector2(0, -10)
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")

var caster: Node2D = null
var is_network_visual: bool = false
var owner_peer: int = 0 ## kozmetik kopya: sahibinin peer id'si (boşta dönmek için kuklasını bulur)

var _sprite: AnimatedSprite2D = null
var _shadow: AnimatedSprite2D = null
var _active_left: float = 0.0 ## >0 = AKTİF mod (R basıldı); kopyada da aynı sayaç ("mode"/"hb" paketi sıfırlar)
var _scale_f: float = PASSIVE_SCALE
var _orbit_angle: float = 0.0
var _hb_t: float = 0.0
var _owner_cache: Node2D = null
var _leg_from: Vector2 = Vector2.ZERO
var _leg_to: Vector2 = Vector2.ZERO
var _leg_dur: float = 0.0
var _leg_t: float = 0.0
var _in_leg: bool = false
var _pause: float = 0.0
var _retry: float = 0.0
var _trail_acc: float = 0.0
var _height: float = HOVER_H
var _ending: bool = false


## Gerçek (yetkili) kafatası - Necromancer'ın kendi istemcisinde (R açılınca player.gd kurar, sonra kalıcıdır).
func setup(p_caster: Node2D) -> void:
	caster = p_caster
	global_position = p_caster.global_position
	_orbit_angle = randf() * TAU
	_broadcast("start", global_position, {"active": false})


## Diğer oyunculardaki kozmetik kopya - hasar/korku yok, sadece yayınlanan bacakları uçar, boştayken sahibinin kuklasının etrafında döner.
func setup_network(start_pos: Vector2, peer_id: int = 0) -> void:
	is_network_visual = true
	owner_peer = peer_id
	global_position = start_pos
	_orbit_angle = randf() * TAU


## AKTİF mod: R'ye basınca (player.gd _skill_necro_skull). Süre dolunca kafatası kendiliğinden pasife döner.
func set_active(duration: float = DURATION) -> void:
	_active_left = maxf(0.0, duration)
	if not is_network_visual:
		_broadcast("mode", global_position, {"active": _active_left > 0.0, "t": _active_left})


func is_active() -> bool:
	return _active_left > 0.0


## Mekanik çarpan: pasif 0.5, aktif 1.0 (görsel boyut _scale_f ile yumuşakça yaklaşır, vuruş alanı/hasar ANINDA geçer).
func _target_scale() -> float:
	return 1.0 if _active_left > 0.0 else PASSIVE_SCALE


func _impact_radius() -> float:
	return IMPACT_RADIUS * _target_scale()


func _damage_ratio() -> float:
	return ACTIVE_DAMAGE_AP_RATIO if _active_left > 0.0 else PASSIVE_DAMAGE_AP_RATIO


func _seek_range() -> float:
	return SEEK_RANGE if _active_left > 0.0 else PASSIVE_SEEK_RANGE


func _has_evo(id: String) -> bool:
	return is_instance_valid(caster) and caster.has_method("has_evo") and bool(caster.call("has_evo", id))


## R2 Hızlı Ezme: vuruş hızı (uçuş hızı + duraklama + yeniden hedefleme) saldırı hızıyla ölçeklenir (kartsız 1.0).
func _speed_mult() -> float:
	if _has_evo("necro_r2") and caster.has_method("get_attack_interval_mult"):
		return clampf(1.0 / maxf(0.1, float(caster.call("get_attack_interval_mult"))), 1.0, EVO_SPEED_CAP)
	return 1.0


## Boşta dönülecek/askıya alınacak sahip düğümü (kopyada sahibin kuklası).
func _owner_node() -> Node2D:
	if not is_network_visual:
		return caster if is_instance_valid(caster) else null
	if is_instance_valid(_owner_cache):
		return _owner_cache
	if owner_peer > 0:
		_owner_cache = NetworkManager._find_remote_player(owner_peer) as Node2D
	return _owner_cache


## Ölü / yere düşmüş / ev içindeki sahibin kafatası görünmez ve saldırmaz.
func _suspended(own: Node2D) -> bool:
	if own == null:
		return false
	return own.get("is_dead") == true or own.get("is_downed") == true or own.get("is_indoors") == true


func _ready() -> void:
	z_index = 12
	_shadow = AnimatedSprite2D.new()
	_shadow.sprite_frames = SKULL_FRAMES
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.scale = Vector2.ONE * TEXEL * _scale_f
	_shadow.position = Vector2(0, SHADOW_Y * _scale_f)
	_shadow.z_as_relative = false
	_shadow.z_index = 1
	_shadow.play(&"shadow")
	add_child(_shadow)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = SKULL_FRAMES
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * TEXEL * _scale_f
	add_child(_sprite)
	_sprite.play(&"appear")
	_sprite.animation_finished.connect(_on_sprite_anim_finished)
	_pause = 0.4 ## belirme animasyonu bitene kadar ilk hedefe fırlama
	_apply_height()


func _on_sprite_anim_finished() -> void:
	if _sprite.animation == &"appear":
		_sprite.play(&"fly")
	elif _sprite.animation == &"vanish":
		queue_free()


func _process(delta: float) -> void:
	if _ending:
		return
	if not is_network_visual and not is_instance_valid(caster):
		_end()
		return
	if _active_left > 0.0:
		_active_left -= delta
		if _active_left <= 0.0:
			_active_left = 0.0
			if not is_network_visual:
				_broadcast("mode", global_position, {"active": false, "t": 0.0})
	_scale_f = move_toward(_scale_f, _target_scale(), delta * SCALE_RATE)
	if _sprite:
		_sprite.scale = Vector2.ONE * TEXEL * _scale_f
	if _shadow:
		_shadow.scale = Vector2.ONE * TEXEL * _scale_f
		_shadow.position = Vector2(0, SHADOW_Y * _scale_f)
	var own: Node2D = _owner_node()
	var susp: bool = _suspended(own)
	visible = not susp
	if susp:
		_in_leg = false
		return
	if not is_network_visual:
		_hb_t -= delta
		if _hb_t <= 0.0:
			_hb_t = HEARTBEAT_INTERVAL
			_broadcast("hb", global_position, {"active": _active_left > 0.0, "t": _active_left})
	var mult: float = _speed_mult()
	if _in_leg:
		_advance_leg(delta)
	elif _pause > 0.0:
		_pause -= delta
		_height = move_toward(_height, HOVER_H, delta * 90.0)
	else:
		if not is_network_visual:
			_retry -= delta
			if _retry <= 0.0:
				_retry = RETRY_INTERVAL / mult
				var target: Variant = _pick_target_point()
				if target != null:
					_start_leg(global_position, target, maxf(MIN_LEG_TIME / mult, global_position.distance_to(target) / (SPEED * mult)))
					_broadcast("leg", _leg_to, {"from": _leg_from, "dur": _leg_dur})
		if not _in_leg and own != null:
			## Hedef yoksa sahibinin etrafında (yassı elips) döner.
			_orbit_angle = fposmod(_orbit_angle + ORBIT_SPEED * delta, TAU)
			var r: float = ORBIT_RADIUS * (0.8 + _scale_f * 0.4)
			var spot: Vector2 = own.global_position + IDLE_FOLLOW_OFFSET + Vector2(cos(_orbit_angle), sin(_orbit_angle) * ORBIT_SQUASH) * r
			global_position = global_position.move_toward(spot, CATCHUP_SPEED * delta)
			_height = move_toward(_height, HOVER_H, delta * 90.0)
	_apply_height()
	_trail_acc += delta
	if _trail_acc >= TRAIL_INTERVAL and _sprite.animation == &"fly" and _in_leg:
		_trail_acc = 0.0
		var scene: Node = get_tree().current_scene
		if scene:
			FxSprite.spawn(scene, global_position + Vector2(randf_range(-6, 6), -(_height + SKULL_BOTTOM * 0.55) * _scale_f), TRAIL_FRAMES, &"play", 11, _scale_f)


func _start_leg(from: Vector2, to: Vector2, dur: float) -> void:
	_leg_from = from
	_leg_to = to
	_leg_dur = maxf(0.05, dur)
	_leg_t = 0.0
	_in_leg = true
	global_position = from


func _advance_leg(delta: float) -> void:
	_leg_t = minf(1.0, _leg_t + delta / _leg_dur)
	global_position = _leg_from.lerp(_leg_to, _leg_t)
	## Kavis: süzülme yüksekliği + ortada yükselip sona doğru yere çakılma.
	var slam: float = smoothstep(0.62, 1.0, _leg_t)
	_height = lerpf(HOVER_H, SLAM_H, slam) + sin(_leg_t * PI) * ARC_H * (1.0 - slam)
	if _leg_t >= 1.0:
		_in_leg = false
		_pause = IMPACT_PAUSE / _speed_mult()
		_impact(_leg_to)


func _apply_height() -> void:
	if _sprite:
		_sprite.position = Vector2(0, -roundf((_height + SKULL_BOTTOM) * _scale_f))
	if _shadow:
		_shadow.modulate.a = clampf(1.15 - _height / (HOVER_H + ARC_H), 0.45, 1.0)


func _impact(pos: Vector2) -> void:
	var scene: Node = get_tree().current_scene
	if scene:
		FxSprite.spawn(scene, pos, IMPACT_FRAMES, &"play", 11, _scale_f)
		var snd: AudioStreamPlayer2D = ShamanSfx.play_at(scene, IMPACT_SOUND, pos, -9.0 if _active_left > 0.0 else -13.0, 0.06)
		if snd:
			snd.pitch_scale *= 0.72 if _active_left > 0.0 else 0.95
	if is_network_visual or not is_instance_valid(caster):
		return
	var ap: float = float(caster.get("damage_bonus")) if caster.get("damage_bonus") != null else 0.0
	var dmg: float = ap * _damage_ratio()
	var radius: float = _impact_radius()
	var fear: bool = _has_evo("necro_r1")
	var curse: bool = _has_evo("necro_rf")
	for e in EnemyQueryScript.candidates(get_tree(), pos, radius):
		if not (e is Node2D) or not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if pos.distance_to((e as Node2D).global_position) > radius:
			continue
		if dmg > 0.0 and e.has_method("take_damage"):
			var is_crit: bool = caster.has_method("_roll_ability_crit") and caster._roll_ability_crit()
			var hit: float = caster._apply_ability_crit(dmg, is_crit) if caster.has_method("_apply_ability_crit") else dmg
			BalanceLogScript.tag(&"s:necro_kafatasi")
			e.take_damage(hit, is_crit, 0.0, true)
		if not is_instance_valid(e):
			continue
		if fear and e.has_method("apply_fear_wander"):
			e.apply_fear_wander(EVO_FEAR_DURATION, FEAR_AFFECTS_BOSSES)
		if curse and e.get("is_dead") != true:
			if e.has_method("apply_element"):
				e.apply_element("vuln", {"pct": EVO_CURSE_VULN, "dur": EVO_CURSE_DURATION})
			if caster.has_method("_necro_curse_mark"):
				caster.call("_necro_curse_mark", e, EVO_CURSE_DURATION)


## Hedef noktası: kalabalığa ve bosslara öncelik (bkz. dosya başı). Sisin gizlediği/hedeflenemeyen yaratıklar sayılmaz.
func _pick_target_point() -> Variant:
	if not is_instance_valid(caster):
		return null
	var origin: Vector2 = caster.global_position
	var seek: float = _seek_range()
	var cands: Array = []
	for e in EnemyQueryScript.candidates(get_tree(), origin, seek):
		if not (e is Node2D) or not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if origin.distance_to((e as Node2D).global_position) > seek:
			continue
		if not VisionFogScript.can_target(e):
			continue
		cands.append(e)
	if cands.is_empty():
		return null
	## Merkez adayları: kafatasına en yakın MAX_CENTER_CANDIDATES yaratık (+ tüm bosslar) - komşu sayımı tüm adaylarla.
	var centers: Array = cands
	if cands.size() > MAX_CENTER_CANDIDATES:
		var here: Vector2 = global_position
		centers = cands.duplicate()
		centers.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return here.distance_squared_to(a.global_position) < here.distance_squared_to(b.global_position))
		var bosses: Array = cands.filter(func(e: Node) -> bool: return e.get("is_boss") == true)
		centers = centers.slice(0, MAX_CENTER_CANDIDATES)
		for b in bosses:
			if not centers.has(b):
				centers.append(b)
	var impact_r: float = _impact_radius()
	var r2: float = impact_r * impact_r
	var best: Node2D = null
	var best_score: float = -INF
	for c in centers:
		var cp: Vector2 = (c as Node2D).global_position
		var score: float = 0.0
		for o in cands:
			if cp.distance_squared_to((o as Node2D).global_position) <= r2:
				## zaten korkmuş yaratık daha az değerli (korkuyu yaymak için) - istemcide is_feared hep false, zararsız
				score += (1.0 - FEARED_PENALTY) if o.get("is_feared") == true else 1.0
		if c.get("is_boss") == true:
			score += BOSS_PRIORITY
		score -= global_position.distance_to(cp) / DIST_PENALTY
		if score > best_score:
			best_score = score
			best = c
	return best.global_position if best else null


func _end() -> void:
	if _ending:
		return
	_ending = true
	if not is_network_visual:
		_broadcast("end", global_position)
	if _sprite:
		_sprite.play(&"vanish")
	if _shadow:
		create_tween().tween_property(_shadow, "modulate:a", 0.0, 0.4)
	get_tree().create_timer(1.5, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


## Kozmetik kopya: yetkili kafatasının yayınladığı bir bacak. Kopya HER ZAMAN kendi bulunduğu yerden uçar (yetkili kafatası
## hedefsizken sahibine doğru süzüldüyse ya da bir paket kaybolduysa ışınlanmasın) - süre aynı, yani hedefe eşzamanlı çakılır.
## Önceki bacak henüz bitmemişse (gecikmiş paket) o bacağın çarpması şimdi oynatılır, atlanmaz.
func network_leg(from: Vector2, to: Vector2, dur: float) -> void:
	if _ending:
		return
	if _in_leg:
		_impact(_leg_to)
	var start: Vector2 = global_position
	if start.distance_to(from) > PASSIVE_SEEK_RANGE * 1.5:
		start = from ## çok uzaksa (ör. kopya geç doğdu) yetkilinin başlangıcına geç
	_pause = 0.0
	_start_leg(start, to, dur)


## "mode" / "hb" paketi: yetkili kafatasının aktif durumu (kalan süreyle) - kopya aynı anda büyür/küçülür.
func network_mode(active: bool, left: float = DURATION) -> void:
	_active_left = maxf(0.0, left) if active else 0.0


func network_end() -> void:
	_end()


func _broadcast(phase: String, pos: Vector2, extra: Dictionary = {}) -> void:
	if is_network_visual or not NetworkManager.is_multiplayer_active:
		return
	var data: Dictionary = extra.duplicate()
	data["phase"] = phase
	## Sık bacak paketleri güvenilmez kanaldan (kaybı sonraki bacakta kendiliğinden düzelir); start/mode/hb/end güvenilir.
	NetworkManager.send_player_vfx(multiplayer.get_unique_id(), "necro_skull_leg" if phase == "leg" else "necro_skull", pos, data)
