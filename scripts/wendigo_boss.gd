extends RefCounted

## WENDİGO (Kademe 12 bossu, kullanıcı isteği 2026-10-09, masaüstü "boss ve yetenekleri.txt") - SADECE host / tek oyunculuda çalışır (enemy_abilities.gd "wendigo" ailesi).
## Belge: "yerden oyuncunun gideceği yönlere doğru sürekli sarmaşıklar çıkarır; belli aralıklarla yere vurarak oyuncunun üstüne gökten kayalar indirir; oyuncuya yürüyüp yaklaşınca
## normal saldırı. Sarmaşık 100, taş 130, normal saldırı 120 hasar. Can 200.000 Kalkan 280.000 Kalkan soğurması %85" (statlar FIXED_BOSS_STATS["wendigo1"], normal saldırı = C++ temas).
##   - SARMAŞIK ÇEVRİMİ (sürekli): VINE_CD sn'de bir, "vine" animasyonu (yerde durur) + 3 patlama x 3 sarmaşık; sarmaşıklar oyuncunun HAREKET yönünün ÖNÜNE yelpaze/duvar gibi çıkar
##     (oyuncu duruyorsa çevresine halka); uyarı + çıkış sürelerinde kaçılabilir (wendigo_vine.gd).
##   - KAYA YAĞMURU: ROCK_CD sn'de bir, "slam" animasyonu, vuruş karesinde her oyuncunun üstüne + çevresine ROCKS_PER_PLAYER kaya düşer (wendigo_rock.gd, uyarı halkası 1 sn).
## Hareket: C++ kovalama; animasyonlar boyunca ability_move_lock. Sayılar tek yerde (sabitler).

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")

const VINE_DAMAGE := 100.0 ## x0,8 kesintisi iptal edildi (80 -> 100). ## 2026-10-11: x0,8 (kullanıcı: "tüm yaratıkların hasarını %20 azalt"), 100 -> 80
const ROCK_DAMAGE := 130.0 ## x0,8 kesintisi iptal edildi (104 -> 130). ## 2026-10-11: x0,8 (kullanıcı: "tüm yaratıkların hasarını %20 azalt"), 130 -> 104
const VINE_CD_MIN := 2.4
const VINE_CD_MAX := 3.0
const VINE_RANGE := 760.0
const VINE_ANIM := 1.3
const VINE_LOCK := 1.0
const VINE_BURSTS := [0.35, 0.65, 0.95]
const VINE_PER_BURST := 3
const VINE_SPREAD := 52.0          ## yan yana sarmaşıklar arası (px)
const VINE_WARN := 0.7
const VINE_GROW := 0.8
const VINE_RADIUS := 26.0
const VINE_MAX_ALIVE := 16
const ROCK_FIRST := 6.0
const ROCK_CD_MIN := 9.0
const ROCK_CD_MAX := 12.0
const ROCK_RANGE := 820.0
const SLAM_ANIM := 0.95
const SLAM_LOCK := 1.0
const SLAM_HIT_AT := 0.5
const ROCKS_PER_PLAYER := 4
const ROCK_SCATTER_MIN := 50.0
const ROCK_SCATTER_MAX := 120.0
const ROCK_WARN := 1.0
const ROCK_FALL := 0.28
const ROCK_RADIUS := 44.0
const ROCK_MAX_ALIVE := 20

var e: Node2D = null
var _vine_cd: float = 1.5
var _rock_cd: float = ROCK_FIRST
var _busy: float = 0.0
var _queue: Array = []
var _last_pos: Dictionary = {}   ## hedef kimliği -> son konum (hareket yönü tahmini)
var _vel: Dictionary = {}        ## hedef kimliği -> süzülmüş hız (px/sn)


func setup(owner_enemy: Node2D) -> void:
	e = owner_enemy


func process(delta: float, _player: Node2D, _dist: float) -> void:
	_track(delta)
	_run_queue(delta)
	if _busy > 0.0:
		_busy -= delta
		return
	_vine_cd -= delta
	_rock_cd -= delta
	if _rock_cd <= 0.0 and _has_target_in(ROCK_RANGE):
		_begin_slam()
		return
	if _vine_cd <= 0.0 and _has_target_in(VINE_RANGE):
		_begin_vines()


## Hedef oyuncuların hızını süzer (sarmaşıklar gidilecek yöne çıksın).
func _track(delta: float) -> void:
	if delta <= 0.0:
		return
	for p in AbilitiesScript.damageable_players(e.get_tree()):
		var pn := p as Node2D
		var id: int = pn.get_instance_id()
		if _last_pos.has(id):
			var v: Vector2 = (pn.global_position - Vector2(_last_pos[id])) / delta
			_vel[id] = Vector2(_vel.get(id, Vector2.ZERO)).lerp(v, clampf(delta * 6.0, 0.0, 1.0))
		_last_pos[id] = pn.global_position


func _targets_in(radius: float) -> Array:
	var out: Array = []
	for p in AbilitiesScript.damageable_players(e.get_tree()):
		var pn := p as Node2D
		if (pn.get("is_indoors") == true) or pn.get("is_downed") == true:
			continue
		if pn.global_position.distance_to(e.global_position) <= radius:
			out.append(pn)
	return out


func _has_target_in(radius: float) -> bool:
	return not _targets_in(radius).is_empty()


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


func _anim(anim_name: String, duration: float) -> void:
	e.call("emit_ability_vfx", "boss_event", {"k": "anim", "n": anim_name, "d": duration})


func _lock(seconds: float) -> void:
	e.set("ability_move_lock", maxf(float(e.get("ability_move_lock")), seconds))
	e.set("_ranged_timer", maxf(float(e.get("_ranged_timer")), seconds))


func _alive_in_group(group: String) -> int:
	var n: int = 0
	for m: Node in e.get_tree().get_nodes_in_group(group):
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			n += 1
	return n


func _spawn_fx(kind: String, pos: Vector2, data: Dictionary, dmg: float) -> Node2D:
	var node: Node2D = AbilitiesScript.spawn_world_fx(e.get_tree(), kind, pos, data, true, e, dmg)
	AbilitiesScript._broadcast_world_fx(kind, pos, data)
	return node


# ---------------------------------------------------------------------------------------------------- sarmaşıklar
func _begin_vines() -> void:
	_vine_cd = randf_range(VINE_CD_MIN, VINE_CD_MAX)
	_busy = VINE_LOCK
	_lock(VINE_LOCK)
	_anim("vine", VINE_ANIM)
	for k in range(VINE_BURSTS.size()):
		_after(float(VINE_BURSTS[k]), _vine_burst.bind(k))


func _vine_burst(k: int) -> void:
	if _alive_in_group("wendigo_vines") >= VINE_MAX_ALIVE:
		return
	for pn: Node2D in _targets_in(VINE_RANGE + 200.0):
		var vel: Vector2 = Vector2(_vel.get(pn.get_instance_id(), Vector2.ZERO))
		var speed: float = vel.length()
		var centers: Array = []
		if speed > 25.0:
			## Gidilen yönün önünde: her patlama biraz daha ileride, yan yana VINE_PER_BURST sarmaşık
			var dir: Vector2 = vel / speed
			var side: Vector2 = dir.orthogonal()
			var lead: float = clampf(speed * (0.75 + 0.35 * float(k)) + 40.0, 60.0, 280.0)
			var mid: Vector2 = pn.global_position + dir * lead
			for j in range(VINE_PER_BURST):
				centers.append(mid + side * (float(j) - float(VINE_PER_BURST - 1) * 0.5) * VINE_SPREAD)
		else:
			## Duran oyuncu: çevresinde halka
			var base: float = randf() * TAU
			for j in range(VINE_PER_BURST):
				centers.append(pn.global_position + Vector2.from_angle(base + float(j) * TAU / float(VINE_PER_BURST)) * randf_range(60.0, 120.0))
		for c in centers:
			var pos: Vector2 = c
			if GameManager.is_position_blocked_by_walls(pos):
				continue
			_spawn_fx("wendigo_vine", pos, {"warn": VINE_WARN, "grow": VINE_GROW, "radius": VINE_RADIUS, "scale": 2.6}, VINE_DAMAGE)


# ---------------------------------------------------------------------------------------------------- kaya yağmuru
func _begin_slam() -> void:
	_rock_cd = randf_range(ROCK_CD_MIN, ROCK_CD_MAX)
	_busy = SLAM_LOCK
	_lock(SLAM_LOCK)
	_anim("slam", SLAM_ANIM)
	_after(SLAM_HIT_AT, _drop_rocks)


func _drop_rocks() -> void:
	for pn: Node2D in _targets_in(ROCK_RANGE + 200.0):
		for i in range(ROCKS_PER_PLAYER):
			if _alive_in_group("wendigo_rocks") >= ROCK_MAX_ALIVE:
				return
			var pos: Vector2 = pn.global_position
			if i > 0:
				pos += Vector2.from_angle(randf() * TAU) * randf_range(ROCK_SCATTER_MIN, ROCK_SCATTER_MAX)
			if GameManager.is_position_blocked_by_walls(pos):
				pos = pn.global_position
			var node: Node2D = _spawn_fx("wendigo_rock", pos, {"warn": ROCK_WARN, "fall": ROCK_FALL, "radius": ROCK_RADIUS}, ROCK_DAMAGE)
			if node != null:
				node.add_to_group("wendigo_rocks")
