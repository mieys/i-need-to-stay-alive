extends RefCounted

## MEDUSA (madde 682, 2026-11-14) - Altın Kumlar Kademe 10 = SON boss (ölünce zafer). SADECE host / tek oyunculuda çalışır (enemy_abilities.gd, "medusa" ailesi).
## Kullanıcı: "uzun mesafeli taşlaştırıcı geniş açılı göz ışınları olsun (ona doğru yürürken isabet ederse 2 saniyeliğine taşlaşırsın ve hiçbirşey
## yapamazsın, ona doğru koşmuyorken isabet ederse 2 saniyeliğine %30 yavaşlarsın. 2 şekilde de iyi miktarda hasar vermeli). Ayrıca ekstra eklemen
## gereken birkaç özellik bul çok zor olsun öldürmesi."
##   - TAŞLAŞTIRAN BAKIŞ ("gaze" klibi): hedefe doğru GAZE_FAN_DEG genişliğinde yelpaze, GAZE_BEAMS göz ışını, GAZE_LENGTH uzunluğunda (duvarda biter).
##     GAZE_WARN sn uyarı çizgileri, sonra ışınlar: değdiği oyuncuya GAZE_DAMAGE ("medusa_gaze"); taşlaşma / yavaşlama kararı vurulanın kendi
##     makinesinde (player.gd: o an Medusa'ya doğru yürüyor muydu). Dünya efekti medusa_gaze.gd.
##   EKSTRA (benim seçimim, "çok zor olsun"):
##   - YILAN KIRBACI ("snake" klibi): yakındaki oyunculara önünde 80°'lik koni, SNAKE_DAMAGE + güçlü zehir; TAŞLAŞMIŞ oyuncuya x2 ("taş kırılması",
##     player.gd MEDUSA_SHATTER_MULT) - bakışa yakalanıp donan oyuncuya hemen saldırır. Normal ısırığı (C++ temas) da aynı türde işlenir.
##   - KUM SÜZÜLÜŞÜ: hedef uzaktaysa (DASH_MIN_RANGE) kısa hazırlık sonra DASH_TIME sn hızla süzülür; yaklaşınca anında Yılan Kırbacı.
##   - FAZ 2 (can + kalkan yarının altında): beklemeler x0,65, yelpaze genişler (GAZE_BEAMS_P2 / GAZE_FAN_DEG_P2), her bakışın ardından ikinci
##     bakış (yeniden nişanlı, GAZE_SECOND_DELAY sonra) ve her GAZE_RING_EVERY. bakış 360° TAŞ HALKASI (her yöne ışın - durmak / uzaklaşmak taşlaşmaktan kurtarır).
## ÇOK OYUNCULU: karar/hasar host'ta; istemciler animasyon (boss_event anim) + ışın görseli (dünya efekti yayını) alır; taşlaşma görseli vurulanın yayını.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")

const GAZE_FIRST := 3.0
const GAZE_CD_MIN := 6.0
const GAZE_CD_MAX := 8.0
const GAZE_MAX_RANGE := 820.0 ## hedef bundan uzaktaysa bakmaz (önce süzülür)
const GAZE_LENGTH := 760.0
const GAZE_WIDTH := 26.0
const GAZE_BEAMS := 7
const GAZE_FAN_DEG := 100.0
const GAZE_BEAMS_P2 := 9
const GAZE_FAN_DEG_P2 := 130.0
const GAZE_RING_BEAMS := 16
const GAZE_RING_EVERY := 3
const GAZE_WARN := 0.9
const GAZE_FIRE := 0.3
const GAZE_DAMAGE := 240.0
const GAZE_SECOND_DELAY := 0.75
const GAZE_ANIM_LEAD := 0.33 ## klibin dalga karesi (3. kare, 9 fps) ışınlarla aynı anda gelsin
const EYE := Vector2(0.0, -36.0) ## gözlerin dünya ofseti (boss boyu dahil; oyun içi yakalamada ölçüldü, tools/boss_gorsel/boss_682_capture.ps1)

const SNAKE_RANGE := 170.0
const SNAKE_CONE_DEG := 80.0
const SNAKE_DAMAGE := 200.0
const SNAKE_FIRST := 2.0
const SNAKE_CD := 3.2
const SNAKE_HIT_AT := 0.38 ## klibin ısırık karesi (6 kare / 9 fps)
const SNAKE_BUSY := 0.7

const DASH_FIRST := 6.0
const DASH_CD_MIN := 7.0
const DASH_CD_MAX := 9.0
const DASH_MIN_RANGE := 420.0
const DASH_WINDUP := 0.35
const DASH_TIME := 1.1
const DASH_MULT := 3.2
const DASH_MULT_P2 := 3.8
const DASH_ARRIVE := 130.0 ## bu kadar yaklaşınca süzülüş biter, Yılan Kırbacı gelir

const PHASE2_RATIO := 0.5
const PHASE2_CD_MULT := 0.65

var e: Node2D = null
var _gaze_cd: float = GAZE_FIRST
var _snake_cd: float = SNAKE_FIRST
var _dash_cd: float = DASH_FIRST
var _busy: float = 0.0
var _queue: Array = []
var _gaze_count: int = 0
var _dash_left: float = 0.0


func setup(owner_enemy: Node2D) -> void:
	e = owner_enemy


func process(delta: float, player: Node2D, dist: float) -> void:
	_run_queue(delta)
	if _dash_left > 0.0:
		_dash_left -= delta
		if _dash_left <= 0.0 or (_valid_target(player) and dist <= DASH_ARRIVE):
			_end_dash()
			_snake_cd = 0.0
		else:
			return
	if _busy > 0.0:
		_busy -= delta
		return
	_gaze_cd -= delta
	_snake_cd -= delta
	_dash_cd -= delta
	if not _valid_target(player):
		return
	if _snake_cd <= 0.0 and dist <= SNAKE_RANGE:
		_begin_snake(player)
		return
	if _gaze_cd <= 0.0 and dist <= GAZE_MAX_RANGE:
		if bool(e.call("_has_line_of_sight", player)):
			_begin_gaze(player)
			return
		_gaze_cd = 0.5
	if _dash_cd <= 0.0 and dist >= DASH_MIN_RANGE:
		_begin_dash()


# ---------------------------------------------------------------------------------------------------- yardımcılar
func _phase2() -> bool:
	var total: float = float(e.get("max_health")) + float(e.get("item_shield_max"))
	if total <= 0.0:
		return false
	return (float(e.get("health")) + float(e.get("item_shield_hp"))) / total <= PHASE2_RATIO


func _haste() -> float:
	return PHASE2_CD_MULT if _phase2() else 1.0


func _dmg(v: float) -> float:
	return v * float(e.get_meta("boss_damage_mult", 1.0))


func _run_queue(delta: float) -> void:
	var i: int = 0
	while i < _queue.size():
		_queue[i]["t"] = float(_queue[i]["t"]) - delta
		if float(_queue[i]["t"]) <= 0.0:
			var fn: Callable = _queue[i]["fn"]
			_queue.remove_at(i)
			if e != null and is_instance_valid(e) and e.get("is_dead") != true:
				fn.call()
		else:
			i += 1


func _after(seconds: float, fn: Callable) -> void:
	_queue.append({"t": seconds, "fn": fn})


func _valid_target(player: Node2D) -> bool:
	return player != null and is_instance_valid(player) and player.get("is_dead") != true


func _anim(anim_name: String, duration: float) -> void:
	e.call("emit_ability_vfx", "boss_event", {"k": "anim", "n": anim_name, "d": duration})


func _lock(seconds: float) -> void:
	e.set("ability_move_lock", maxf(float(e.get("ability_move_lock")), seconds))
	e.set("_ranged_timer", maxf(float(e.get("_ranged_timer")), seconds))


## Isırık (normal C++ temas saldırısı): Yılan Kırbacı ile aynı tür - zehir + taşlaşmışa x2. true = vuruş burada işlendi.
func handle_melee_hit(target: Node) -> bool:
	AbilitiesScript.deal_special_damage(target, float(e.get("contact_damage")), e, "medusa_snake")
	return true


# ---------------------------------------------------------------------------------------------------- taşlaştıran bakış
func _begin_gaze(player: Node2D) -> void:
	_gaze_count += 1
	_gaze_cd = randf_range(GAZE_CD_MIN, GAZE_CD_MAX) * _haste()
	var p2: bool = _phase2()
	var ring: bool = p2 and _gaze_count % GAZE_RING_EVERY == 0
	var total: float = GAZE_WARN + GAZE_FIRE + (GAZE_SECOND_DELAY if p2 else 0.0) + 0.2
	_busy = total
	_lock(total)
	_fire_gaze(player, ring)
	if p2 and not ring:
		_after(GAZE_SECOND_DELAY, _fire_gaze.bind(weakref(player), false))


## Bir bakış: ring = her yöne GAZE_RING_BEAMS ışın; değilse hedefe doğru yelpaze. player: Node2D ya da WeakRef (ikinci bakış yeniden nişan alır).
func _fire_gaze(target: Variant, ring: bool) -> void:
	var p: Node2D = null
	if target is WeakRef:
		p = (target as WeakRef).get_ref() as Node2D
	else:
		p = target as Node2D
	var origin: Vector2 = e.global_position + EYE
	var angles: Array = []
	if ring:
		var base: float = randf() * TAU
		for k in GAZE_RING_BEAMS:
			angles.append(base + TAU * float(k) / float(GAZE_RING_BEAMS))
	else:
		var aim: float = (p.global_position - origin).angle() if _valid_target(p) else randf() * TAU
		var n: int = GAZE_BEAMS_P2 if _phase2() else GAZE_BEAMS
		var fan: float = deg_to_rad(GAZE_FAN_DEG_P2 if _phase2() else GAZE_FAN_DEG)
		for k in n:
			var t: float = 0.0 if n <= 1 else float(k) / float(n - 1) - 0.5
			angles.append(aim + fan * t)
	var data: Dictionary = {"angles": angles, "length": GAZE_LENGTH, "width": GAZE_WIDTH, "warn": GAZE_WARN, "fire": GAZE_FIRE}
	AbilitiesScript.spawn_world_fx(e.get_tree(), "medusa_gaze", origin, data, true, e, _dmg(GAZE_DAMAGE))
	AbilitiesScript._broadcast_world_fx("medusa_gaze", origin, data)
	_after(maxf(GAZE_WARN - GAZE_ANIM_LEAD, 0.0), _anim.bind("gaze", 0.8))


# ---------------------------------------------------------------------------------------------------- yılan kırbacı
func _begin_snake(player: Node2D) -> void:
	_snake_cd = SNAKE_CD * _haste()
	_busy = SNAKE_BUSY
	_lock(SNAKE_BUSY)
	_anim("snake", 0.7)
	var dir: Vector2 = (player.global_position - e.global_position).normalized()
	_after(SNAKE_HIT_AT, _snake_hit.bind(dir))


func _snake_hit(dir: Vector2) -> void:
	var half: float = deg_to_rad(SNAKE_CONE_DEG) * 0.5
	for p in AbilitiesScript.damageable_players(e.get_tree()):
		var to: Vector2 = (p as Node2D).global_position - e.global_position
		if to.length() > SNAKE_RANGE + AbilitiesScript.TARGET_BODY_RADIUS:
			continue
		if to.length() > 24.0 and absf(dir.angle_to(to)) > half:
			continue
		AbilitiesScript.deal_special_damage(p, _dmg(SNAKE_DAMAGE), e, "medusa_snake")


# ---------------------------------------------------------------------------------------------------- kum süzülüşü
func _begin_dash() -> void:
	_dash_cd = randf_range(DASH_CD_MIN, DASH_CD_MAX) * _haste()
	_busy = DASH_WINDUP
	_lock(DASH_WINDUP)
	_after(DASH_WINDUP, _dash_go)


func _dash_go() -> void:
	e.set("ability_move_lock", 0.0)
	e.set("_ranged_timer", 0.0)
	e.call("set_gate_rush", DASH_MULT_P2 if _phase2() else DASH_MULT)
	_dash_left = DASH_TIME


func _end_dash() -> void:
	_dash_left = 0.0
	e.call("set_gate_rush", 1.0)
