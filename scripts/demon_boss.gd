extends RefCounted

## UÇAN ŞEYTAN (FİNAL bossu, kullanıcı isteği 2026-10-09, masaüstü "boss ve yetenekleri.txt") - SADECE host / tek oyunculuda çalışır ("ucansetan" ailesi). Tüm kademeler bittikten sonra çıkar;
## ÖLÜNCE zafer penceresi açılır ve "Sonsuza Devam Et" ile sonsuz mod başlar (enemy_spawner.gd _check_victory -> _begin_victory, kullanıcı: "final bossu öldürdükten sonra sonsuz mod açılacak").
## Belge: "normal halinden 4 kat, dışa doğru parıltılı. Belli aralıklarla oyunculara doğru çok seri ateş topları (çarpınca patlayıp 200 hasar, sonra yakarak saniyede 50); belli aralıklarla geniş açılı
## Kozmik ışın, yavaşça 360 derece döner (temas edene her 0,5 sn'de 100); belli aralıklarla oyunculara uçarak normal saldırı (150). Canı %50'nin altına düşünce form değiştirir (gözler hafif kırmızı),
## özellikleri daha sık, ve bazen kendini saniyede %1 iyileştiren büyü yapar (yaparken saldırmaz). Can 1.000.000 Kalkan 1.200.000 Soğurma %90."
## Hareketi bu betik sürer (Banshee gibi): yaratık C++'ta UYKUDA (set_dormant), uçar (duvarlara takılmaz), oyuncuların içinden geçilebilir (no_body_block).
## Durumlar: HOVER (oyuncudan ~HOVER_DIST uzakta yavaşça daire çizer) -> FIRE / BEAM / DASH_IN->STRIKE->DASH_OUT / HEAL (faz 2). Sayılar sabitlerde.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const EnemyWorldBridgeScript := preload("res://scripts/enemy_world/enemy_world_bridge.gd")
const GlowScript := preload("res://scripts/boss_glow.gd")

enum S { HOVER, FIRE, BEAM, DASH_IN, STRIKE, DASH_OUT, HEAL }

const FIREBALL_DAMAGE := 200.0 ## x0,8 kesintisi iptal edildi (160 -> 200). ## 2026-10-11: x0,8 (kullanıcı: "tüm yaratıkların hasarını %20 azalt"), 200 -> 160
const BEAM_DAMAGE := 100.0 ## x0,8 kesintisi iptal edildi (80 -> 100). ## 2026-10-11: x0,8 (kullanıcı: "tüm yaratıkların hasarını %20 azalt"), 100 -> 80
const MELEE_DAMAGE := 150.0 ## x0,8 kesintisi iptal edildi (120 -> 150). ## 2026-10-11: x0,8 (kullanıcı: "tüm yaratıkların hasarını %20 azalt"), 150 -> 120
const HOVER_DIST := 330.0
const HOVER_SPEED := 150.0
const STRAFE_SPEED := 70.0

const FIRE_CD_MIN := 5.0
const FIRE_CD_MAX := 7.0
const FIRE_COUNT := 10
const FIRE_COUNT_P2 := 14
const FIRE_GAP := 0.09
const FIRE_WINDUP := 0.4
const FIRE_SPEED := 300.0
const FIRE_SPREAD := 0.1           ## rad (+-)
const FIRE_BLAST := 44.0
const BEAM_FIRST := 8.0
const BEAM_CD_MIN := 16.0
const BEAM_CD_MAX := 20.0
const BEAM_WARN := 1.2
const BEAM_SPIN := 10.0            ## tam tur süresi (sn): yavaşça
const BEAM_HALF_ANGLE := 0.35      ## rad (~20 derece: toplam ~40 derece geniş açı)
const BEAM_LENGTH := 820.0
const BEAM_TICK := 0.5
const MELEE_FIRST := 4.0
const MELEE_CD_MIN := 8.0
const MELEE_CD_MAX := 11.0
const DASH_SPEED := 620.0
const STRIKE_RANGE := 70.0
const STRIKE_HIT_AT := 0.2
const STRIKE_TIME := 0.55
const HEAL_CD_MIN := 24.0
const HEAL_CD_MAX := 32.0
const HEAL_TIME := 5.0
const HEAL_PER_SEC := 0.01         ## azami canın %1'i / sn
const PHASE2_AT := 0.5
const CD_MULT_P2 := 0.65

var e: Node2D = null
var _state: int = S.HOVER
var _t: float = 0.0
var _v: Vector2 = Vector2.ZERO
var _slot_ready: bool = false
var _fire_cd: float = 2.0
var _beam_cd: float = BEAM_FIRST
var _melee_cd: float = MELEE_FIRST
var _heal_cd: float = 10.0
var _phase2: bool = false
var _fired: int = 0
var _fire_count: int = FIRE_COUNT
var _fire_clock: float = 0.0
var _struck: bool = false
var _hover_sign: float = 1.0
var _glow: Node2D = null


func setup(owner_enemy: Node2D) -> void:
	e = owner_enemy
	e.set("no_body_block", true)
	_glow = GlowScript.attach(e)
	_hover_sign = 1.0 if randf() < 0.5 else -1.0


func blocks_melee() -> bool:
	return true


## Her peer: faz 2 görseli ve iyileşme rengi (host'ta yerelde, istemcide boss_event ile).
func on_boss_event(data: Dictionary) -> void:
	match str(data.get("k", "")):
		"phase2":
			_set_look(true)
		"heal":
			if _glow != null and is_instance_valid(_glow):
				_glow.call("set_glow_color", Color(0.4, 1.0, 0.5) if bool(data.get("on", true)) else (Color(1.0, 0.3, 0.3) if _phase2 else Color(0.5, 0.4, 1.0)))


func _set_look(p2: bool) -> void:
	_phase2 = p2
	if p2:
		for spr: CanvasItem in [e.get("frame_sprite"), e.get("anim_sprite")]:
			if spr != null:
				spr.self_modulate = Color(1.0, 0.82, 0.82) ## gözler hafif kırmızılaşır
		if _glow != null and is_instance_valid(_glow):
			_glow.call("set_glow_color", Color(1.0, 0.3, 0.3))


func process(delta: float, _player: Node2D, _dist: float) -> void:
	if not _prepare():
		return
	_t += delta
	_check_phase()
	var target: Node2D = _nearest_target()
	_fire_cd -= delta
	_beam_cd -= delta
	_melee_cd -= delta
	_heal_cd -= delta
	match _state:
		S.HOVER:
			_process_hover(delta, target)
		S.FIRE:
			_process_fire(delta, target)
		S.BEAM:
			_v = _v.move_toward(Vector2.ZERO, 600.0 * delta)
			_apply_motion(delta)
			if _t >= BEAM_WARN + BEAM_SPIN + 0.4:
				_go(S.HOVER)
		S.DASH_IN:
			_process_dash_in(delta, target)
		S.STRIKE:
			_process_strike(delta)
		S.DASH_OUT:
			_process_dash_out(delta, target)
		S.HEAL:
			_process_heal(delta)


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


func _check_phase() -> void:
	if _phase2:
		return
	var max_hp: float = float(e.get("max_health"))
	if max_hp > 0.0 and float(e.get("health")) <= max_hp * PHASE2_AT:
		e.call("emit_ability_vfx", "boss_event", {"k": "phase2"})
		_heal_cd = randf_range(6.0, 12.0)


func _cd_mult() -> float:
	return CD_MULT_P2 if _phase2 else 1.0


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


func _apply_motion(delta: float) -> void:
	if _v.length() < 0.5:
		return
	var next: Vector2 = e.global_position + _v * delta
	var rect: Rect2 = GameManager.get_map_world_rect()
	if rect.size != Vector2.ZERO:
		next = Vector2(clampf(next.x, rect.position.x + 30.0, rect.end.x - 30.0), clampf(next.y, rect.position.y + 30.0, rect.end.y - 30.0))
	e.global_position = next
	_face(_v)


# ---------------------------------------------------------------------------------------------------- bekleme + seçim
func _process_hover(delta: float, target: Node2D) -> void:
	if target == null:
		_v = _v.move_toward(Vector2.ZERO, 400.0 * delta)
		_apply_motion(delta)
		return
	var to_t: Vector2 = target.global_position - e.global_position
	var d: float = to_t.length()
	var want: Vector2 = Vector2.ZERO
	if d > HOVER_DIST + 40.0:
		want = to_t.normalized() * HOVER_SPEED
	elif d < HOVER_DIST - 70.0:
		want = -to_t.normalized() * HOVER_SPEED * 0.8
	else:
		want = to_t.normalized().orthogonal() * STRAFE_SPEED * _hover_sign
	_v = _v.move_toward(want, 500.0 * delta)
	_apply_motion(delta)
	if _t < 0.6:
		return
	## Eylem seçimi (öncelik: iyileşme büyüsü > ışın > uçarak saldırı > ateş topu)
	if _phase2 and _heal_cd <= 0.0 and float(e.get("health")) < float(e.get("max_health")):
		_begin_heal()
	elif _beam_cd <= 0.0:
		_begin_beam(target)
	elif _melee_cd <= 0.0:
		_go(S.DASH_IN)
	elif _fire_cd <= 0.0:
		_begin_fire()


# ---------------------------------------------------------------------------------------------------- ateş topu yağmuru
func _begin_fire() -> void:
	_fire_cd = randf_range(FIRE_CD_MIN, FIRE_CD_MAX) * _cd_mult()
	_fire_count = FIRE_COUNT_P2 if _phase2 else FIRE_COUNT
	_fired = 0
	_fire_clock = 0.0
	_anim("cast", 0.75)
	_go(S.FIRE)


func _process_fire(delta: float, target: Node2D) -> void:
	_v = _v.move_toward(Vector2.ZERO, 600.0 * delta)
	_apply_motion(delta)
	if _t < FIRE_WINDUP:
		return
	_fire_clock += delta
	while _fire_clock >= FIRE_GAP and _fired < _fire_count:
		_fire_clock -= FIRE_GAP
		_fired += 1
		_launch_fireball(target)
	if _fired >= _fire_count and _fire_clock >= 0.3:
		_go(S.HOVER)


func _launch_fireball(target: Node2D) -> void:
	var origin: Vector2 = e.global_position + Vector2(0.0, -34.0)
	var aim: Vector2 = Vector2.DOWN
	if target != null and is_instance_valid(target):
		aim = (target.global_position - origin).normalized()
	var dir: Vector2 = aim.rotated(randf_range(-FIRE_SPREAD, FIRE_SPREAD))
	var pos: Vector2 = origin + dir * 40.0
	var data: Dictionary = {"dir": dir, "speed": FIRE_SPEED, "life": 3.2, "radius": 9.0, "blast": FIRE_BLAST}
	AbilitiesScript.spawn_world_fx(e.get_tree(), "demon_fire", pos, data, true, e, FIREBALL_DAMAGE)
	AbilitiesScript._broadcast_world_fx("demon_fire", pos, data)


# ---------------------------------------------------------------------------------------------------- kozmik ışın
func _begin_beam(target: Node2D) -> void:
	_beam_cd = randf_range(BEAM_CD_MIN, BEAM_CD_MAX) * _cd_mult()
	var origin: Vector2 = e.global_position + Vector2(0.0, -34.0)
	var angle: float = (target.global_position - origin).angle() if target != null else randf() * TAU
	var data: Dictionary = {"angle": angle, "sign": 1.0 if randf() < 0.5 else -1.0, "half_angle": BEAM_HALF_ANGLE, "length": BEAM_LENGTH,
			"warn": BEAM_WARN, "spin_time": BEAM_SPIN, "tick": BEAM_TICK, "boss": int(e.get_meta("network_enemy_id", 0))}
	AbilitiesScript.spawn_world_fx(e.get_tree(), "cosmic_beam", origin, data, true, e, BEAM_DAMAGE)
	AbilitiesScript._broadcast_world_fx("cosmic_beam", origin, data)
	_anim("cast", 0.75)
	_go(S.BEAM)


# ---------------------------------------------------------------------------------------------------- uçarak saldırı
func _process_dash_in(delta: float, target: Node2D) -> void:
	if target == null:
		_go(S.HOVER)
		return
	var to_t: Vector2 = target.global_position - e.global_position
	if to_t.length() <= STRIKE_RANGE or _t > 1.6:
		_struck = false
		_melee_cd = randf_range(MELEE_CD_MIN, MELEE_CD_MAX) * _cd_mult()
		e.call("_play_ability_attack_anim")
		_v = Vector2.ZERO
		_go(S.STRIKE)
		return
	_v = _v.move_toward(to_t.normalized() * DASH_SPEED, 1400.0 * delta)
	_apply_motion(delta)


func _process_strike(delta: float) -> void:
	_v = _v.move_toward(Vector2.ZERO, 1500.0 * delta)
	_apply_motion(delta)
	if not _struck and _t >= STRIKE_HIT_AT:
		_struck = true
		for p in AbilitiesScript.damageable_players(e.get_tree()):
			if e.global_position.distance_to((p as Node2D).global_position) <= STRIKE_RANGE + AbilitiesScript.TARGET_BODY_RADIUS + 14.0:
				AbilitiesScript.deal_special_damage(p, MELEE_DAMAGE, e, "demonslash")
	if _t >= STRIKE_TIME:
		_go(S.DASH_OUT)


func _process_dash_out(delta: float, target: Node2D) -> void:
	if target == null:
		_go(S.HOVER)
		return
	var away: Vector2 = e.global_position - target.global_position
	if away.length() >= HOVER_DIST - 20.0 or _t > 1.2:
		_go(S.HOVER)
		return
	_v = _v.move_toward(away.normalized() * 420.0, 1000.0 * delta)
	_apply_motion(delta)


# ---------------------------------------------------------------------------------------------------- iyileşme büyüsü (faz 2)
func _begin_heal() -> void:
	_heal_cd = randf_range(HEAL_CD_MIN, HEAL_CD_MAX)
	_anim("cast", 0.75)
	e.call("emit_ability_vfx", "boss_event", {"k": "heal", "on": true})
	_go(S.HEAL)


func _process_heal(delta: float) -> void:
	_v = _v.move_toward(Vector2.ZERO, 600.0 * delta)
	_apply_motion(delta)
	var max_hp: float = float(e.get("max_health"))
	e.set("health", minf(max_hp, float(e.get("health")) + max_hp * HEAL_PER_SEC * delta))
	e.emit_signal("health_changed", e.get("health"), max_hp)
	if _t >= HEAL_TIME:
		e.call("emit_ability_vfx", "boss_event", {"k": "heal", "on": false})
		_go(S.HOVER)


## Sahip öldü: ışın vb. kendiliğinden söner (cosmic_beam.gd boss ölünce kapanır); iyileşme rengi sıfırlanır.
func on_owner_died() -> void:
	pass
