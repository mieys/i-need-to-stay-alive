extends Node2D
class_name NecroSkull

## Necromancer ULTİ - Lanetli Kafatası (skill3 id 44). Kullanıcı isteği (2026-09-24): "dev bir kafatasını düşmanlara doğru
## gönderir, kafatası 10 saniye boyunca düşmanlara doğru çarpar (kalabalığa ve bosslara öncelik verir) ve her isabette onlara
## %110 ap hasar vererek 3 saniyeliğine korkutur, korkan düşmanlar etrafa rasgele yönlerde yürümeye çalışır ve hasar veremez.
## (60 saniye yetenek bekleme süresi)".
##
## Hareket DÜZ "bacaklardan" oluşur: hedef noktası seçilir -> kafatası oraya kavis çizerek uçar -> yere çakılır (IMPACT_RADIUS
## içindeki TÜM yaratıklara %110 AP alan hasarı + 3sn rastgele-yürüme korkusu, bkz. enemy.gd apply_fear_wander) -> kısa
## duraklama -> yeni hedef. Hedef puanı = çarpma alanına girecek (henüz korkmamış) yaratık sayısı + boss önceliği - uzaklık
## cezası. Bacak başlangıç/bitiş/süresi ağ üzerinden yayınlandığı için (NetworkManager.broadcast_player_vfx "necro_skull")
## diğer oyunculardaki kozmetik kopya AYNI yolu AYNI sürede uçar ve bacak sonunda AYNI çarpma efektini kendisi oynatır -
## pozisyon akışı gerekmez; kaybolan (unreliable) bir paket sonraki bacakta kendiliğinden düzelir.
## Görseller: tools/gen_necro_fx.py (assets/fx/necro/skull|impact|trail) - hepsi önceden pişirilmiş spritesheet, her karede
## _draw YOK.

const TEXEL := 1.212
const SKULL_FRAMES := preload("res://assets/fx/necro/skull_frames.tres")
const IMPACT_FRAMES := preload("res://assets/fx/necro/impact_frames.tres")
const TRAIL_FRAMES := preload("res://assets/fx/necro/trail_frames.tres")
const FxSprite := preload("res://scripts/fx_enemy_ability.gd")
const VisionFogScript := preload("res://scripts/vision_fog.gd")
const ShamanSfx := preload("res://scripts/shaman_sfx.gd")
const IMPACT_SOUND := "res://assets/audio/topuz_hit.mp3"

const DURATION := 10.0
const DAMAGE_AP_RATIO := 1.10
const FEAR_DURATION := 3.0
## Oyunun genel kuralı: bosslar korkmaz (Melek'in Kutsal Korku'su da böyle, bkz. enemy.gd apply_fear). Kafatası bosslara
## ÖNCELİK verir ve tam hasar vurur ama onları korkutmaz; true yapılırsa bosslar da korkar.
const FEAR_AFFECTS_BOSSES := false
const IMPACT_RADIUS := 68.0 ## çarpma halkası 56 sanat px * TEXEL (bkz. gen_necro_fx.py impact)
const SPEED := 460.0
const MIN_LEG_TIME := 0.22
const IMPACT_PAUSE := 0.24
const SEEK_RANGE := 620.0 ## hedefler Necromancer'ın bu yarıçapından seçilir (ekran dışına kaçmasın)
const BOSS_PRIORITY := 6.0
const FEARED_PENALTY := 0.6
const DIST_PENALTY := 260.0 ## puan: her 260 birim uzaklık -1
const MAX_CENTER_CANDIDATES := 48
const RETRY_INTERVAL := 0.25
## Uçuş yüksekliği (dünya birimi, çene ucunun yerden yüksekliği) - bacak sonunda yere çakılır.
const HOVER_H := 30.0
const ARC_H := 12.0
const SLAM_H := 4.0
const SKULL_BOTTOM := 34.0 * TEXEL ## hücre merkezinden çene ucuna (sanat px 34)
const SHADOW_Y := -28.0 * TEXEL ## gölge elipsinin hücre içi konumu (y=64) yere otursun
const TRAIL_INTERVAL := 0.06
const IDLE_FOLLOW_OFFSET := Vector2(0, -10)

var caster: Node2D = null
var is_network_visual: bool = false

var _sprite: AnimatedSprite2D = null
var _shadow: AnimatedSprite2D = null
var _life: float = DURATION
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


## Gerçek (yetkili) kafatası - Necromancer'ın kendi istemcisinde.
func setup(p_caster: Node2D) -> void:
	caster = p_caster
	global_position = p_caster.global_position
	_broadcast("start", global_position)


## Diğer oyunculardaki kozmetik kopya - hasar/korku yok, sadece yayınlanan bacakları uçar.
func setup_network(start_pos: Vector2) -> void:
	is_network_visual = true
	global_position = start_pos
	_life = DURATION + 1.5 ## "end" paketi kaybolursa emniyet


func _ready() -> void:
	z_index = 12
	_shadow = AnimatedSprite2D.new()
	_shadow.sprite_frames = SKULL_FRAMES
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.scale = Vector2.ONE * TEXEL
	_shadow.position = Vector2(0, SHADOW_Y)
	_shadow.z_as_relative = false
	_shadow.z_index = 1
	_shadow.play(&"shadow")
	add_child(_shadow)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = SKULL_FRAMES
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * TEXEL
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
	_life -= delta
	if _life <= 0.0:
		_end()
		return
	if _in_leg:
		_advance_leg(delta)
	elif _pause > 0.0:
		_pause -= delta
		_height = move_toward(_height, HOVER_H, delta * 90.0)
	elif not is_network_visual:
		_retry -= delta
		if _retry <= 0.0:
			_retry = RETRY_INTERVAL
			var target: Variant = _pick_target_point()
			if target != null:
				_start_leg(global_position, target, maxf(MIN_LEG_TIME, global_position.distance_to(target) / SPEED))
				_broadcast("leg", _leg_to, {"from": _leg_from, "dur": _leg_dur})
		if not _in_leg and is_instance_valid(caster):
			## Hedef yoksa sahibinin yakınında süzülür.
			global_position = global_position.move_toward(caster.global_position + IDLE_FOLLOW_OFFSET, SPEED * 0.5 * delta)
			_height = move_toward(_height, HOVER_H, delta * 90.0)
	_apply_height()
	_trail_acc += delta
	if _trail_acc >= TRAIL_INTERVAL and _sprite.animation == &"fly":
		_trail_acc = 0.0
		var scene: Node = get_tree().current_scene
		if scene:
			FxSprite.spawn(scene, global_position + Vector2(randf_range(-6, 6), -_height - SKULL_BOTTOM * 0.55), TRAIL_FRAMES, &"play", 11)


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
		_pause = IMPACT_PAUSE
		_impact(_leg_to)


func _apply_height() -> void:
	if _sprite:
		_sprite.position = Vector2(0, -roundf(_height + SKULL_BOTTOM))
	if _shadow:
		_shadow.modulate.a = clampf(1.15 - _height / (HOVER_H + ARC_H), 0.45, 1.0)


func _impact(pos: Vector2) -> void:
	var scene: Node = get_tree().current_scene
	if scene:
		FxSprite.spawn(scene, pos, IMPACT_FRAMES, &"play", 11)
		var snd: AudioStreamPlayer2D = ShamanSfx.play_at(scene, IMPACT_SOUND, pos, -9.0, 0.06)
		if snd:
			snd.pitch_scale *= 0.72
	if is_network_visual or not is_instance_valid(caster):
		return
	var ap: float = float(caster.get("damage_bonus")) if caster.get("damage_bonus") != null else 0.0
	var dmg: float = ap * DAMAGE_AP_RATIO
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if pos.distance_to((e as Node2D).global_position) > IMPACT_RADIUS:
			continue
		if dmg > 0.0 and e.has_method("take_damage"):
			var is_crit: bool = caster.has_method("_roll_ability_crit") and caster._roll_ability_crit()
			var hit: float = caster._apply_ability_crit(dmg, is_crit) if caster.has_method("_apply_ability_crit") else dmg
			e.take_damage(hit, is_crit, 0.0, true)
		if e.has_method("apply_fear_wander") and is_instance_valid(e):
			e.apply_fear_wander(FEAR_DURATION, FEAR_AFFECTS_BOSSES)


## Hedef noktası: kalabalığa ve bosslara öncelik (bkz. dosya başı). Sisin gizlediği/hedeflenemeyen yaratıklar sayılmaz.
func _pick_target_point() -> Variant:
	if not is_instance_valid(caster):
		return null
	var origin: Vector2 = caster.global_position
	var cands: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if origin.distance_to((e as Node2D).global_position) > SEEK_RANGE:
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
	var r2: float = IMPACT_RADIUS * IMPACT_RADIUS
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
	if start.distance_to(from) > SEEK_RANGE * 1.5:
		start = from ## çok uzaksa (ör. kopya geç doğdu) yetkilinin başlangıcına geç
	_pause = 0.0
	_start_leg(start, to, dur)


func network_end() -> void:
	_end()


func _broadcast(phase: String, pos: Vector2, extra: Dictionary = {}) -> void:
	if is_network_visual or not NetworkManager.is_multiplayer_active:
		return
	var data: Dictionary = extra.duplicate()
	data["phase"] = phase
	NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "necro_skull", pos, data)
