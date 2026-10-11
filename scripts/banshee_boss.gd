extends RefCounted

## BANSHEE (Kademe 15 bossu, kullanıcı isteği 2026-10-09, masaüstü "boss ve yetenekleri.txt") - SADECE host / tek oyunculuda çalışır (enemy_abilities.gd "banshee" ailesi).
## Belge: "zifiri gece olduğunda doğar, var olduğu sürece asla gündüz olmaz (atmosphere.gd gece kilidi, doğuş kapısı enemy_spawner.gd _check_boss_tiers). Gece oyunculara doğru hızlı uçarak içlerinden
## geçip hasar vermeye çalışır; oyuncu sağa sola atlayarak kaçabilir: ivmeli şekilde oyuncuya uçar, yavaşlayıp döner, tekrar eder. Belli aralıklarla durup oyuncuya doğru çığlık atar: bunu yaparken
## oyuncudan uzakta ve yavaş uçar; ses dalgasının yönü önceden UYARILIR, düz ve kalın şeritler halinde gider, duvarların arkasından geçemez ama Banshee duvarların üstünden uçar.
## Can 300.000 Kalkan 480.000" (belgede soğurma ve hasar YOK: benim seçimim soğurma %90, atılış hasarı = contact_damage 120, çığlık 130 - FIXED_BOSS_STATS "banshee1").
## Hareketi BU betik sürer: yaratık C++'ta "uykuda" (set_dormant: hedef/temas yok, oyuncuların içinden geçer, duvara takılmaz), konumu her karede elle ilerletilir (C++ benimser).
## Durumlar: APPEAR -> APPROACH -> WINDUP (durur, nişan alır) -> DASH (ivmelenir, içinden geçer) -> SLOW (yavaşlar) -> PAUSE -> [her SCREAM_EVERY atılıştan sonra: RETREAT (yavaş geri çekil) -> SCREAM
## (uyarı şeritleri + ses dalgası) -> PAUSE] -> APPROACH.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const EnemyWorldBridgeScript := preload("res://scripts/enemy_world/enemy_world_bridge.gd")

enum S { APPEAR, APPROACH, WINDUP, DASH, SLOW, PAUSE, RETREAT, SCREAM }

## KULLANICI İSTEĞİ (2026-10-10): "banshee çok güçsüzdü, boyutunu %30 küçültüp daha agresif daha hızlı olmalı, hasarını 2 kat arttır": boyut x0,7 (FIXED_BOSS_STATS scale 3.0 -> 2.1; çığlık çıkış
## ofseti BODY_SCALE_REL ile), hasar x2 (atılış 120 -> 240, çığlık 130 -> 260), yaklaşma/atılış/yavaşlama çok daha hızlı, bekleme ve nişan süreleri kısa (atılış döngüsü ~3 sn -> ~1,4 sn),
## çığlık her 2 atılışta bir (eskiden 3), 5 şeritli (eskiden 3), daha kalın ve daha kısa uyarılı; yavaş geri çekilme de hızlandı. Eski değerler: APPROACH 190, ENGAGE 250, WINDUP 0,55, DASH 580/780,
## SLOW 820, PAUSE 0,3, OVERSHOOT 260, SCREAM_EVERY 3, RETREAT 120/3,5 sn, LANE_WARN 1,0, LANE_WIDTH 44, 3 şerit, 3 oyuncu.
const SCREAM_DAMAGE := 260.0 ## 2026-10-11: x0,8 kesintisi iptal edildi (208 -> 260). ## 2026-10-11: x0,8 (kullanıcı: "tüm yaratıkların hasarını %20 azalt"), 260 -> 208
const BODY_SCALE_REL := 0.7       ## boss eskisinden %30 küçük
const APPEAR_TIME := 1.0
const APPROACH_SPEED := 340.0
const ENGAGE_DIST := 380.0
const WINDUP_TIME := 0.28
const DASH_MAX_SPEED := 860.0
const DASH_ACCEL := 1500.0
const DASH_OVERSHOOT := 140.0 ## oyuncunun ne kadar ötesine uçar (eskiden 260: yavaşlama dahil ~520 px ötede kalıp geri dönmek uzun sürüyordu)
const DASH_MIN_LEN := 380.0
const DASH_MAX_LEN := 820.0
const DASH_HIT_RADIUS := 28.0
const DASH_HIT_MIN_SPEED := 110.0
const SLOW_DECEL := 2200.0
const PAUSE_TIME := 0.1
const SCREAM_EVERY := 2
const RETREAT_SPEED := 200.0
const SCREAM_DIST := 340.0
const RETREAT_MAX := 2.2
const SCREAM_ANIM := 1.0
const LANE_WARN := 0.8
const LANE_FIRE := 0.45
const LANE_WIDTH := 54.0
const LANE_LENGTH := 820.0
const LANE_FAN := 0.32            ## yan şeritlerin açısı (rad, ~18 derece); 5 şeritte 0, +-LANE_FAN, +-2 LANE_FAN
const LANE_COUNT := 5
const LANE_MAX_PLAYERS := 4
const SCREAM_AFTER := 1.3         ## çığlık fazı toplam süresi (uyarı + dalga + kısa nefes)

var e: Node2D = null
var _state: int = S.APPEAR
var _t: float = 0.0
var _v: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.DOWN
var _dash_left: float = 0.0
var _dash_count: int = 0
var _hit: Dictionary = {}
var _slot_ready: bool = false
var _scream_started: bool = false
var _appear_played: bool = false


func setup(owner_enemy: Node2D) -> void:
	e = owner_enemy
	e.add_to_group("night_lock_boss") ## atmosphere.gd: kilit, bu gruptaki canlı boss sürdükçe tutar
	e.set("no_body_block", true)       ## oyuncular içinden geçebilir (player.gd _block_movement_into_enemies)
	_lock_night(true)


## Dövüş bitti / boss öldü (enemy.gd die()): gece kilidi açılır.
func on_owner_died() -> void:
	_lock_night(false)


## Yakın dövüş (C++ temas) bastırılır: atılış hasarı bu betikte, boss zaten uykuda.
func blocks_melee() -> bool:
	return true


func _lock_night(on: bool) -> void:
	if e == null or not e.is_inside_tree():
		return
	var atmo: Node = e.get_tree().get_first_node_in_group("atmosphere")
	if atmo != null and atmo.has_method("set_night_lock"):
		atmo.call("set_night_lock", on)


func process(delta: float, _player: Node2D, _dist: float) -> void:
	if not _prepare():
		return
	_t += delta
	var target: Node2D = _nearest_target()
	match _state:
		S.APPEAR:
			if not _appear_played:
				_appear_played = true
				_anim("appear", APPEAR_TIME)
			_v = Vector2.ZERO
			if _t >= APPEAR_TIME:
				_go(S.APPROACH)
		S.APPROACH:
			_process_approach(delta, target)
		S.WINDUP:
			_process_windup(delta, target)
		S.DASH:
			_process_dash(delta)
		S.SLOW:
			_process_slow(delta)
		S.PAUSE:
			_v = _v.move_toward(Vector2.ZERO, 900.0 * delta)
			_apply_motion(delta)
			if _t >= PAUSE_TIME:
				_go(S.APPROACH)
		S.RETREAT:
			_process_retreat(delta, target)
		S.SCREAM:
			_process_scream(delta, target)


## C++ tarafı: uykuya al + her karede hareket kilidi. Slot henüz yoksa (ilk kare) bekler.
func _prepare() -> bool:
	if e.get("is_dead") == true:
		return false
	var slot: int = int(e.get("_ew_slot")) if e.get("_ew_slot") != null else -1
	if slot < 0:
		return false
	if not _slot_ready:
		var world: Object = EnemyWorldBridgeScript.fog_world(e.get_tree())
		if world == null:
			return false
		world.set_dormant(slot, true)
		_slot_ready = true
	e.set("ability_move_lock", maxf(float(e.get("ability_move_lock")), 0.3))
	return true


func _go(state: int) -> void:
	_state = state
	_t = 0.0
	_scream_started = false


func _anim(anim_name: String, duration: float) -> void:
	e.call("emit_ability_vfx", "boss_event", {"k": "anim", "n": anim_name, "d": duration})


func _nearest_target() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for p in AbilitiesScript.damageable_players(e.get_tree()):
		var pn := p as Node2D
		if pn.get("is_indoors") == true or pn.get("is_downed") == true:
			continue
		var d: float = pn.global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = pn
	return best


func _face(dir: Vector2) -> void:
	if dir.length() < 0.01:
		return
	var slot: int = int(e.get("_ew_slot"))
	var world: Object = EnemyWorldBridgeScript.fog_world(e.get_tree())
	if world != null and slot >= 0:
		world.set_face(slot, dir.normalized())


## Hızı konuma işler (harita dikdörtgeni içinde kalır: duvarlar engel DEĞİL, Banshee uçar). true = hareket edildi.
func _apply_motion(delta: float) -> void:
	if _v.length() < 0.5:
		return
	var next: Vector2 = e.global_position + _v * delta
	var rect: Rect2 = GameManager.get_map_world_rect()
	if rect.size != Vector2.ZERO:
		next = Vector2(clampf(next.x, rect.position.x + 24.0, rect.end.x - 24.0), clampf(next.y, rect.position.y + 24.0, rect.end.y - 24.0))
	e.global_position = next
	_face(_v)


func _process_approach(delta: float, target: Node2D) -> void:
	if target == null:
		_v = _v.move_toward(Vector2.ZERO, 600.0 * delta)
		_apply_motion(delta)
		return
	var to_t: Vector2 = target.global_position - e.global_position
	if to_t.length() <= ENGAGE_DIST or _t > 3.0:
		_go(S.WINDUP)
		return
	_v = _v.move_toward(to_t.normalized() * APPROACH_SPEED, 1200.0 * delta)
	_apply_motion(delta)


func _process_windup(delta: float, target: Node2D) -> void:
	_v = _v.move_toward(Vector2.ZERO, 1500.0 * delta)
	_apply_motion(delta)
	if target != null:
		_dir = (target.global_position - e.global_position).normalized()
	_face(_dir)
	if _t >= WINDUP_TIME:
		var dist: float = target.global_position.distance_to(e.global_position) if target != null else DASH_MIN_LEN
		_dash_left = clampf(dist + DASH_OVERSHOOT, DASH_MIN_LEN, DASH_MAX_LEN)
		_hit.clear()
		_v = _dir * 60.0
		_anim("dash", 0.9)
		_go(S.DASH)


func _process_dash(delta: float) -> void:
	var speed: float = minf(_v.length() + DASH_ACCEL * delta, DASH_MAX_SPEED)
	_v = _dir * speed
	var before: Vector2 = e.global_position
	_apply_motion(delta)
	_dash_left -= before.distance_to(e.global_position)
	if speed >= DASH_HIT_MIN_SPEED:
		_check_hits()
	if _dash_left <= 0.0 or before.distance_to(e.global_position) < 0.01 and speed > 100.0:
		_go(S.SLOW)


func _process_slow(delta: float) -> void:
	_v = _v.move_toward(Vector2.ZERO, SLOW_DECEL * delta)
	_apply_motion(delta)
	if _v.length() < 25.0:
		_v = Vector2.ZERO
		_dash_count += 1
		_go(S.PAUSE if _dash_count % SCREAM_EVERY != 0 else S.RETREAT)


func _check_hits() -> void:
	for p in AbilitiesScript.damageable_players(e.get_tree()):
		var id: int = (p as Node).get_instance_id()
		if _hit.has(id):
			continue
		if e.global_position.distance_to((p as Node2D).global_position) <= DASH_HIT_RADIUS + AbilitiesScript.TARGET_BODY_RADIUS:
			_hit[id] = true
			AbilitiesScript.deal_special_damage(p, float(e.get("contact_damage")), e, "banshee")


func _process_retreat(delta: float, target: Node2D) -> void:
	if target == null:
		_go(S.SCREAM)
		return
	var away: Vector2 = e.global_position - target.global_position
	if away.length() >= SCREAM_DIST or _t >= RETREAT_MAX:
		_go(S.SCREAM)
		return
	_v = _v.move_toward(away.normalized() * RETREAT_SPEED, 500.0 * delta)
	_apply_motion(delta)


func _process_scream(delta: float, target: Node2D) -> void:
	_v = _v.move_toward(Vector2.ZERO, 500.0 * delta)
	_apply_motion(delta)
	if not _scream_started:
		_scream_started = true
		_anim("scream", SCREAM_ANIM)
		_spawn_lanes()
	if _t >= SCREAM_AFTER:
		_go(S.PAUSE)


## Her hedef oyuncuya (en çok LANE_MAX_PLAYERS) LANE_COUNT düz şerit: tam üstüne + iki yana LANE_FAN'ın katlarıyla. Uzunluk duvara kadar kısaltılır.
func _spawn_lanes() -> void:
	var origin: Vector2 = e.global_position + Vector2(0.0, -20.0 * BODY_SCALE_REL)
	var count: int = 0
	var targets: Array = []
	for p in AbilitiesScript.damageable_players(e.get_tree()):
		var pn := p as Node2D
		if pn.get("is_indoors") == true or pn.get("is_downed") == true:
			continue
		targets.append(pn)
	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.distance_to(origin) < b.global_position.distance_to(origin))
	for pn: Node2D in targets:
		if count >= LANE_MAX_PLAYERS:
			break
		count += 1
		var base: Vector2 = (pn.global_position - origin).normalized()
		for lane in range(LANE_COUNT):
			var a: float = (float(lane) - float(LANE_COUNT - 1) * 0.5) * LANE_FAN ## 5 şeritte -2,-1,0,1,2 x LANE_FAN
			var dir: Vector2 = base.rotated(a)
			var length: float = AbilitiesScript.clip_ray_to_domes(e.get_tree(), origin, dir, AbilitiesScript.clip_ray_to_walls(origin, dir, LANE_LENGTH)) ## duvarda VE Şovalye baloncuğunda biter
			var data: Dictionary = {"dir": dir, "length": length, "width": LANE_WIDTH, "warn": LANE_WARN, "fire": LANE_FIRE}
			AbilitiesScript.spawn_world_fx(e.get_tree(), "banshee_wave", origin, data, true, e, SCREAM_DAMAGE)
			AbilitiesScript._broadcast_world_fx("banshee_wave", origin, data)
