extends Node2D
class_name MissionTree

## Yaratık aday sorgusu (yeni yolda C++ ızgarası, eski yolda tüm "enemies" grubu; süzgeçler çağıranda aynen kalır).
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const BoltScript := preload("res://scripts/mission_tree_bolt.gd")

## "Ağacı Koru" görevi (bkz. world_event_manager.gd).
##
## 2026-10-10 YENİ SANAT (kullanıcının "görev agaç" klasörü; tools/import_mission_tree.py -> assets/fx/mission_tree/): görev başlayınca 3 karelik BÜYÜME
## (kaynak sayfa ters sıralı - araç küçükten büyüğe çevirir ve gövde diplerini hizalar) sonra 6 karelik AKTİF hâl döngüde. Ağacın ortasındaki MAVİ KRİSTAL
## yaklaşan yaratıklara kristal mermisi atar (mission_tree_bolt.gd; HER istemcide yerel çizilir, hasarı SADECE host işler - eski düz projectile'ı istemciler
## göremiyordu). Can/kalkan/hasar görev başında o anki yaratıklardan ölçülür (bkz. _calibrate - "ne çok güçlü ne çok zayıf"). Derinlik: yerel oyuncu
## ağacın kökünün arkasındaysa (ayağı yukarıda) ağaç onun ÜSTÜNE çizilir. Çarpışma: "move_blockers" grubu, gövde çemberi (player.gd _block_movement_into_blockers).
##
## AĞ MİMARİSİ: bu Node HER istemcide (host dahil) world_event_started ile aynı konumda yerel olarak kuruluyor (bkz. main.gd _on_world_event_started) - SADECE
## HOST'ta gerçek simülasyon (can/kalkan/hasar) çalışır, istemcide salt görsel kopya. Can/kalkan görüntüsü world_event_progress (value=health+shield,
## target=max_health+max_shield) ile senkron (world_event_manager.gd _tick_mission). Kristal atışları istemcide AYNI hedefleme kuralıyla kozmetik (hasarsız).

const NUM_PHASES := 5 ## eski 5 fazlı büyüme (görev süresi world_event_manager.gd TREE_DURATION; görsel artık ilk saniyelerde büyür)
const PHASE_DURATION := 10.0
const ACTIVE_SHEET := preload("res://assets/fx/mission_tree/tree_active.png")
const GROW_SHEET := preload("res://assets/fx/mission_tree/tree_grow_aligned.png")
const FRAME := 160
const ACTIVE_FRAMES := 6
const GROW_FRAMES := 3
const ACTIVE_FPS := 7.0
const GROW_FPS := 2.5 ## 3 kare ~1,2 sn
const SHEET_BASE := Vector2(87.0, 153.0) ## gövde dibi (kare içinde) - tools/import_mission_tree.py çıktısı
const TREE_SCALE := 0.7 ## 160 px'lik sanat -> ~105 dünya px boy (oyuncu ~40)
const CRYSTAL_LOCAL := Vector2(-7.0, -115.0) ## kristalin ortası, gövde dibine göre (sanat px; ölçekten önce)
const TRUNK_RADIUS := 15.0 ## çarpışma çemberi (dünya px, gövde dibinin biraz üstü)
const TRUNK_CENTER_UP := 6.0
const DEPTH_HALF_WIDTH := 48.0 ## derinlik: oyuncu bu yatay aralıkta + kökün arkasındaysa ağaç üstte çizilir
const DEPTH_HEIGHT := 110.0

const ATTACK_RANGE := 300.0
const ATTACK_INTERVAL := 0.8
## Kademeye göre uyum (2026-10-10, kullanıcı: "canı/kalkanı/hasarı mevcut kademeye uyumlu olmalı, ne çok güçlü ne çok zayıf, biz yetişene kadar başının çaresine
## bakabilsin"): görev başında host yaşayan SIRADAN yaratıkların ortalama azami canını ve temas hasarını ölçer.
##  - can = ort. hasar x HP_PER_ENEMY_HIT, kalkan = ort. hasar x SHIELD_PER_ENEMY_HIT (ölçek x oyuncu çarpanı): ~6 yaratık aynı anda vururken ~7-9 sn dayanır.
##  - kristal vuruşu = ort. yaratık canı x BOLT_HP_RATIO (sıradan bir yaratığı ~3 atışta, 0,8 sn aralıkla ~2,4 sn'de öldürür).
## Ölçülecek yaratık yoksa (başta) FALLBACK_* (eski sabitler).
## 2026-10-17 (kullanıcı: "ağaç çok dayanıklı, biraz hassaslaşsın"): can/kalkan ~%25 düştü (70 -> 52, 22 -> 16, yedek 3000/800 -> 2250/600), görev süresi 50 -> 170 sn.
const HP_PER_ENEMY_HIT := 52.0
const SHIELD_PER_ENEMY_HIT := 16.0
const BOLT_HP_RATIO := 0.34
const FALLBACK_MAX_HEALTH := 2250.0
const FALLBACK_MAX_SHIELD := 600.0
const FALLBACK_BOLT_DAMAGE := 35.0
## Kullanıcı isteği (2026-09-24): hasar almadığında 7 sn sonra kalkan yavaşça (max'ın %5'i/sn) yenilenir.
const SHIELD_REGEN_DELAY := 7.0
const SHIELD_REGEN_RATE_RATIO := 0.05

var max_health: float = FALLBACK_MAX_HEALTH
var health: float = FALLBACK_MAX_HEALTH
var max_shield: float = FALLBACK_MAX_SHIELD
var shield: float = FALLBACK_MAX_SHIELD
var bolt_damage: float = FALLBACK_BOLT_DAMAGE
var phase: int = 0
var is_dead: bool = false
var block_radius: float = TRUNK_RADIUS ## "move_blockers" sözleşmesi (player.gd)

var _phase_timer: float = PHASE_DURATION
var _attack_timer: float = 0.4
var _no_damage_timer: float = 0.0
var _is_host_simulated: bool = true
var _anim: AnimatedSprite2D = null
var _overhead_bar: Node2D = null


func setup(player_count: int, simulated: bool) -> void:
	_is_host_simulated = simulated
	var mult: float = 1.0 + float(max(0, player_count - 1)) * 0.3
	var cal: Dictionary = _calibrate() if simulated else {}
	if not cal.is_empty():
		max_health = float(cal["dmg"]) * HP_PER_ENEMY_HIT * mult
		max_shield = float(cal["dmg"]) * SHIELD_PER_ENEMY_HIT * mult
		bolt_damage = float(cal["hp"]) * BOLT_HP_RATIO
	else:
		max_health = FALLBACK_MAX_HEALTH * mult
		max_shield = FALLBACK_MAX_SHIELD * mult
	health = max_health
	shield = max_shield
	if _overhead_bar:
		_overhead_bar.call("set_health", health, max_health)
		_overhead_bar.call("set_shield", shield, max_shield)


## Yaşayan sıradan yaratıkların (boss/uzuv/minyon/bekçi değil) ortalama azami canı ve temas hasarı - görev başında BİR kez. {} = ölçülecek yaratık yok.
func _calibrate() -> Dictionary:
	if not is_inside_tree():
		return {}
	var hp_sum: float = 0.0
	var dmg_sum: float = 0.0
	var n: int = 0
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true or e.get("is_boss") == true or e.is_in_group("summons") or e.is_in_group("guards"):
			continue
		var mh: float = float(e.get("max_health")) if e.get("max_health") != null else 0.0
		var cd: float = float(e.get("contact_damage")) if e.get("contact_damage") != null else 0.0
		if mh <= 0.0 or cd <= 0.0:
			continue
		hp_sum += mh
		dmg_sum += cd
		n += 1
		if n >= 60:
			break
	if n == 0:
		return {}
	return {"hp": hp_sum / n, "dmg": dmg_sum / n}


func _ready() -> void:
	add_to_group("move_blockers")
	_anim = AnimatedSprite2D.new()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.sprite_frames = _build_frames()
	_anim.centered = true
	_anim.scale = Vector2.ONE * TREE_SCALE
	## Gövde dibi (SHEET_BASE) bu düğümün konumuna (zemin noktası) denk gelsin.
	_anim.position = (Vector2(FRAME, FRAME) * 0.5 - SHEET_BASE) * TREE_SCALE
	add_child(_anim)
	_anim.play(&"grow")
	_anim.animation_finished.connect(func() -> void:
		if _anim.animation == &"grow":
			_anim.play(&"active"))
	_overhead_bar = Node2D.new()
	_overhead_bar.set_script(preload("res://scripts/overhead_bar.gd"))
	add_child(_overhead_bar)
	_overhead_bar.visible = true
	_overhead_bar.call("set_offset", -(SHEET_BASE.y - 6.0) * TREE_SCALE - 8.0)
	_overhead_bar.call("set_health", health, max_health)
	_overhead_bar.call("set_shield", shield, max_shield)
	set_physics_process(true)


static func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for spec: Array in [[&"grow", GROW_SHEET, GROW_FRAMES, GROW_FPS, false], [&"active", ACTIVE_SHEET, ACTIVE_FRAMES, ACTIVE_FPS, true]]:
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], spec[3])
		sf.set_animation_loop(spec[0], spec[4])
		for i in range(int(spec[2])):
			var at := AtlasTexture.new()
			at.atlas = spec[1]
			at.region = Rect2(i * FRAME, 0, FRAME, FRAME)
			sf.add_frame(spec[0], at)
	return sf


## Kristalin dünya konumu (mermiler buradan çıkar).
func crystal_position() -> Vector2:
	return global_position + CRYSTAL_LOCAL * TREE_SCALE


## Çarpışma çemberinin merkezi ("move_blockers" sözleşmesi).
func block_center() -> Vector2:
	return global_position - Vector2(0.0, TRUNK_CENTER_UP)


func _physics_process(delta: float) -> void:
	_update_depth()
	if is_dead:
		return
	_phase_timer -= delta
	if _phase_timer <= 0.0 and phase < NUM_PHASES - 1:
		phase += 1
		_phase_timer = PHASE_DURATION
	## Kristal atışı: büyüme bitince (aktif hâl) - host hasarlı, istemci kozmetik (aynı hedef kuralı).
	if _anim and _anim.animation == &"active":
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_timer = ATTACK_INTERVAL
			_try_fire_at_nearest_enemy()
	if not _is_host_simulated:
		return
	if shield < max_shield:
		_no_damage_timer += delta
		if _no_damage_timer >= SHIELD_REGEN_DELAY:
			shield = min(max_shield, shield + max_shield * SHIELD_REGEN_RATE_RATIO * delta)
			if _overhead_bar:
				_overhead_bar.call("set_shield", shield, max_shield)


## Derinlik: yerel oyuncu ağacın arkasındaysa (ayağı kökün yukarısında ve ağacın genişliğinde) ağaç z 2'de (oyuncu z 1) onun üstüne çizilir; önündeyse z 0.
func _update_depth() -> void:
	if _anim == null:
		return
	var behind: bool = false
	for group_name in ["player", "remote_players"]:
		for p: Node in get_tree().get_nodes_in_group(group_name):
			if not (p is Node2D) or not is_instance_valid(p):
				continue
			var feet: Vector2 = (p as Node2D).global_position + Vector2(0.0, 12.75)
			if feet.y < global_position.y and feet.y > global_position.y - DEPTH_HEIGHT and absf(feet.x - global_position.x) < DEPTH_HALF_WIDTH:
				behind = true
	_anim.z_index = 2 if behind else 0


func _try_fire_at_nearest_enemy() -> void:
	var from: Vector2 = crystal_position()
	var best: Node2D = null
	var best_d: float = ATTACK_RANGE
	for e: Node in EnemyQueryScript.candidates(get_tree(), global_position, ATTACK_RANGE + 1.0):
		if not is_instance_valid(e) or e.get("is_dead") == true or e.get("untargetable") == true:
			continue
		var d: float = global_position.distance_to((e as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return
	var bolt: Node2D = BoltScript.new()
	bolt.setup(best, bolt_damage if _is_host_simulated else 0.0)
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = from


## Oyuncu take_damage(amount, source) imzasıyla AYNI (yaratıklar ağaca bir oyuncuya saldırdıkları gibi saldırır - GameManager.defend_tree_ref).
func take_damage(amount: float, _source: Node2D = null) -> void:
	if is_dead or not _is_host_simulated:
		return
	_no_damage_timer = 0.0
	if shield > 0.0:
		var absorbed: float = min(shield, amount)
		shield -= absorbed
		amount -= absorbed
	if amount > 0.0:
		health = max(0.0, health - amount)
	if _overhead_bar:
		_overhead_bar.call("set_health", health, max_health)
		_overhead_bar.call("set_shield", shield, max_shield)
	if health <= 0.0:
		is_dead = true


## Sadece görsel senkron (istemci): host'un gerçek can/kalkanı world_event_progress'ten.
func apply_synced_health(total: float, max_total: float) -> void:
	if max_total <= 0.0:
		return
	var ratio: float = clamp(total / max_total, 0.0, 1.0)
	health = max_health * ratio
	shield = max_shield * ratio
	if _overhead_bar:
		_overhead_bar.call("set_health", health, max_health)
		_overhead_bar.call("set_shield", shield, max_shield)
