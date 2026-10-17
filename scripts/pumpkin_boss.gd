extends RefCounted

## BALKABAĞI KAFA (Kademe 8 bossu, kullanıcı isteği 2026-10-09) - SADECE host / tek oyunculuda çalışır (enemy_abilities.gd her fizik karesinde process()'i çağırır, "balkabagi" ailesi).
## Kullanıcı: "belli aralıklarla bol sayıda balkabağı yaratığı ve yarasa spawnlar, bunları ayrı aralıklarla; belli aralıklarla bol bol ateş topu atar (isabette 10 hasar);
## oyuncuya yaklaşırsa normal saldırı (20 hasar)". Normal saldırı = C++ temas saldırısı (sahnede contact_damage; FIXED_BOSS_STATS "damage" 20). Burada:
##   - ATEŞ TOPU SALVOSU: cast animasyonu (yerde durur), SALVO_SHOTS top yelpaze halinde, SHOT_GAP aralıkla; her biri 10 hasar (boss_spell.gd, kind "bossfire").
##   - KABAK DALGASI / YARASA DALGASI: ayrı zamanlayıcılar (PUMPKIN_*/BAT_*), summon animasyonu, halka şeklinde doğuş. Minyonlar enemy_spawner.gd spawn_summon ile
##     kademe ölçekli ama canları kabak %70 / yarasa %30 (pumpkin_minions.gd davranışları: kabak yaklaşınca patlar 20, yarasa ısırıp kanatır 5/sn).
## Sayılar tek yerde (aşağıdaki sabitler). Boss ölünce minyonlar kendiliğinden dağılır (pumpkin_minions.gd).
##
## ÇOK OYUNCULU: karar/hasar/doğuş host'ta. İstemciler: animasyon (emit_ability_vfx "boss_event" anim), ateş topu/patlama (broadcast world fx), minyonlar (normal yaratık RPC'si).

## KULLANICI İSTEĞİ (2026-10-10): "balkabağı bossunun boyutunu %30 küçült ve daha güçlü olması gerekiyor, yeteri kadar yetenek ve yaratık spamlamıyor, hasarını 2 kat arttır":
## boyut x0,7 (enemy_spawner.gd FIXED_BOSS_STATS scale 2.0 -> 1.4; ağız konumu/halka mesafeleri BODY_SCALE_REL ile küçüldü), hasar x2 (normal saldırı 20 -> 40, ateş topu 10 -> 20,
## kabak patlaması 20 -> 40, yarasa ısırığı x2 + kanama 5 -> 10/sn), ateş topu salvosu ~2 kat sık ve 7 toplu, YENİ halka salvosu (16 top her yöne), kabak/yarasa dalgaları ~2 kat sık ve büyük,
## canı yarıya inince (can + kalkan toplamı) tüm bekleme süreleri x0,65. (Dosya başındaki 5 top / 10 hasar / 11-14 sn gibi eski sayılar artık bunlardır.)
const FIREBALL_DAMAGE := 30.0 ## 2026-10-17: +%50 (kullanici), 20 -> 30.  2026-10-11: x0,8 kesintisi iptal edildi (kullanıcı), 16 -> 20
const BODY_SCALE_REL := 0.7       ## boss eskisinden %30 küçük: ağız ofseti ve minyon halkası bu kadar yaklaştı
const SALVO_COOLDOWN_MIN := 1.8
const SALVO_COOLDOWN_MAX := 2.8
const SALVO_MIN_RANGE := 90.0
const SALVO_MAX_RANGE := 620.0
const SALVO_SHOTS := 7
const SALVO_SHOTS_P2 := 11        ## faz 2 (can yarıya inince)
const SALVO_FAN_DEG := 34.0       ## dış toplar merkezden en çok bu kadar sapar
const SALVO_GAP := 0.09
const SALVO_WINDUP := 0.45        ## cast animasyonu başladıktan sonra ilk top
const SALVO_BUSY := 0.9
const FIREBALL_SPEED := 250.0   ## 2026-10-11: 190 -> 250 (kullanıcı: "balkabağı bossu çok güçsüz")
const LEAD_FACTOR := 0.85        ## nişan: hedefin hareket yönünü bu oranda önden alır (düz yürüyerek kaçmak işe yaramasın)
const FIREBALL_LIFE := 3.4
const FIREBALL_RADIUS := 9.0

## HALKA SALVOSU (yeni, 2026-10-10): cast animasyonu, RING_SHOTS top her yöne eşit aralıkla (yavaş toplar, aralarından geçilebilir).
const RING_FIRST := 7.0
const RING_CD_MIN := 8.0
const RING_CD_MAX := 11.0
const RING_SHOTS := 16
const RING_SHOTS_P2 := 24         ## faz 2: daha sık halka + ikinci (kaydırılmış) halka
const RING_SECOND_DELAY := 0.7
const RING_SPEED := 190.0
const RING_WINDUP := 0.55
const RING_BUSY := 1.0
const RING_MAX_RANGE := 760.0     ## hedef bu mesafeden uzaktaysa halka atmaz
const PHASE2_RATIO := 0.5         ## (can + kalkan) / (azami can + azami kalkan) bunun altına inince
const PHASE2_CD_MULT := 0.65      ## ... tüm bekleme süreleri bu çarpanla kısalır
const PUMPKIN_FIRST := 3.0
const PUMPKIN_CD_MIN := 6.0
const PUMPKIN_CD_MAX := 8.0
const P2_WAVE_MULT := 1.5        ## faz 2: kabak/yarasa dalgaları bu kadar büyük (tavanlar aynı)
const PUMPKIN_COUNT := 9          ## + her ekstra oyuncu için PUMPKIN_PER_EXTRA_PLAYER
const PUMPKIN_PER_EXTRA_PLAYER := 3
const PUMPKIN_MAX_ALIVE := 30
const BAT_FIRST := 5.0
const BAT_CD_MIN := 8.0
const BAT_CD_MAX := 11.0
const BAT_COUNT := 6
const BAT_PER_EXTRA_PLAYER := 3
const BAT_MAX_ALIVE := 18
const SUMMON_WINDUP := 0.55
const SUMMON_BUSY := 1.1
const SUMMON_RING_MIN := 70.0 * BODY_SCALE_REL
const SUMMON_RING_MAX := 140.0 * BODY_SCALE_REL

## ATILIŞ (yeni, 2026-10-11): kısa hazırlık (durur), sonra C++ hareket hız çarpanı (set_gate_rush) DASH_MULT x DASH_TIME sn - oyuncuya doğru koşar,
## temas saldırısı (contact_damage) zaten C++'ta. Durup bekleyen oyuncu cezalandırılır; boss artık oyuncuyu yerinden oynatır.
const DASH_FIRST := 5.0
const DASH_CD_MIN := 6.0
const DASH_CD_MAX := 8.0
const DASH_MIN_RANGE := 120.0
const DASH_MAX_RANGE := 560.0
const DASH_WINDUP := 0.55
const DASH_TIME := 1.0
const DASH_MULT := 4.5
const DASH_MULT_P2 := 5.5

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")

var e: Node2D = null ## sahip yaratık (Enemy)
var _salvo_cd: float = 0.0
var _ring_cd: float = RING_FIRST
var _pumpkin_cd: float = PUMPKIN_FIRST
var _bat_cd: float = BAT_FIRST
var _dash_cd: float = DASH_FIRST
var _busy: float = 0.0
var _queue: Array = [] ## [{"t": kalan sn, "fn": Callable}]


func setup(owner_enemy: Node2D) -> void:
	e = owner_enemy
	_salvo_cd = randf_range(1.5, 3.0)


func process(delta: float, player: Node2D, dist: float) -> void:
	_run_queue(delta)
	if _busy > 0.0:
		_busy -= delta
		return
	_salvo_cd -= delta
	_ring_cd -= delta
	_pumpkin_cd -= delta
	_bat_cd -= delta
	_dash_cd -= delta
	if _pumpkin_cd <= 0.0 and _alive_count("kabak1") < PUMPKIN_MAX_ALIVE:
		_begin_summon("kabak1")
		return
	if _bat_cd <= 0.0 and _alive_count("yarasa1") < BAT_MAX_ALIVE:
		_begin_summon("yarasa1")
		return
	if _dash_cd <= 0.0 and _valid_target(player) and dist >= DASH_MIN_RANGE and dist <= DASH_MAX_RANGE:
		if bool(e.call("_has_line_of_sight", player)):
			_begin_dash()
			return
		_dash_cd = 0.5
	if _ring_cd <= 0.0 and _valid_target(player) and dist <= RING_MAX_RANGE:
		_begin_ring()
		return
	if _salvo_cd <= 0.0 and _valid_target(player) and dist >= SALVO_MIN_RANGE and dist <= SALVO_MAX_RANGE:
		if bool(e.call("_has_line_of_sight", player)):
			_begin_salvo(player)
		else:
			_salvo_cd = 0.5


## Canı (can + kalkan) yarıya indi mi: tüm bekleme süreleri PHASE2_CD_MULT ile kısalır.
func _phase2() -> bool:
	var total: float = float(e.get("max_health")) + float(e.get("item_shield_max"))
	if total <= 0.0:
		return false
	return (float(e.get("health")) + float(e.get("item_shield_hp"))) / total <= PHASE2_RATIO


func _haste() -> float:
	return PHASE2_CD_MULT if _phase2() else 1.0


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
	e.set("_ranged_timer", maxf(float(e.get("_ranged_timer")), seconds)) ## temas saldırısı da animasyonun üstüne binmesin


# ---------------------------------------------------------------------------------------------------- ateş topu salvosu
func _begin_salvo(player: Node2D) -> void:
	_busy = SALVO_BUSY
	_salvo_cd = randf_range(SALVO_COOLDOWN_MIN, SALVO_COOLDOWN_MAX) * _haste()
	_lock(SALVO_BUSY)
	_anim("cast", 0.8)
	var shots: int = SALVO_SHOTS_P2 if _phase2() else SALVO_SHOTS
	for k in range(shots):
		_after(SALVO_WINDUP + k * SALVO_GAP, _fire_one.bind(player, k, shots))


func _fire_one(player: Node2D, k: int, shots: int) -> void:
	var aim: Vector2 = Vector2.DOWN
	if _valid_target(player):
		aim = (_lead_point(player) - e.global_position).normalized()
	var t: float = 0.0 if shots <= 1 else float(k) / float(shots - 1) * 2.0 - 1.0 ## -1..1
	var dir: Vector2 = aim.rotated(deg_to_rad(SALVO_FAN_DEG) * t)
	_spawn_fireball(dir, FIREBALL_SPEED, FIREBALL_LIFE)


## Hedefin, topun varış süresi kadar ilerisi (LEAD_FACTOR): hedefin hızı CharacterBody2D.velocity'den.
func _lead_point(player: Node2D) -> Vector2:
	var v: Variant = player.get("velocity")
	if typeof(v) != TYPE_VECTOR2:
		return player.global_position
	var d: float = player.global_position.distance_to(e.global_position)
	return player.global_position + (v as Vector2) * (d / FIREBALL_SPEED) * LEAD_FACTOR


## Boss'un ağzından bir ateş topu (host + istemci kopyası).
func _spawn_fireball(dir: Vector2, speed: float, life: float) -> void:
	var pos: Vector2 = e.global_position + (Vector2(0.0, -34.0) + dir * 26.0) * BODY_SCALE_REL
	var data: Dictionary = {"dir": dir, "speed": speed, "life": life, "radius": FIREBALL_RADIUS}
	AbilitiesScript.spawn_world_fx(e.get_tree(), "boss_spell", pos, data, true, e, FIREBALL_DAMAGE)
	AbilitiesScript._broadcast_world_fx("boss_spell", pos, data)


# ---------------------------------------------------------------------------------------------------- halka salvosu (2026-10-10)
func _begin_ring() -> void:
	_busy = RING_BUSY
	_ring_cd = randf_range(RING_CD_MIN, RING_CD_MAX) * _haste()
	_lock(RING_BUSY)
	_anim("cast", 0.8)
	_after(RING_WINDUP, _fire_ring)


func _fire_ring() -> void:
	var shots: int = RING_SHOTS_P2 if _phase2() else RING_SHOTS
	var base: float = randf() * TAU
	for k in range(shots):
		_spawn_fireball(Vector2.from_angle(base + float(k) / float(shots) * TAU), RING_SPEED, FIREBALL_LIFE + 0.4)
	if _phase2():
		_after(RING_SECOND_DELAY, _fire_ring_second.bind(base + PI / float(shots)))


## Faz 2: ilk halkanın araları dolsun diye yarım adım kaydırılmış ikinci halka.
func _fire_ring_second(base: float) -> void:
	for k in range(RING_SHOTS_P2):
		_spawn_fireball(Vector2.from_angle(base + float(k) / float(RING_SHOTS_P2) * TAU), RING_SPEED * 0.8, FIREBALL_LIFE + 0.4)


# ---------------------------------------------------------------------------------------------------- atılış (2026-10-11)
func _begin_dash() -> void:
	_busy = DASH_WINDUP + DASH_TIME
	_dash_cd = randf_range(DASH_CD_MIN, DASH_CD_MAX) * _haste()
	_lock(DASH_WINDUP)
	_anim("cast", DASH_WINDUP)
	_after(DASH_WINDUP, _dash_go)
	_after(DASH_WINDUP + DASH_TIME, _dash_end)


func _dash_go() -> void:
	e.set("ability_move_lock", 0.0)
	e.set("_ranged_timer", 0.0)
	e.call("set_gate_rush", DASH_MULT_P2 if _phase2() else DASH_MULT)


func _dash_end() -> void:
	e.call("set_gate_rush", 1.0)


# ---------------------------------------------------------------------------------------------------- minyon dalgaları
func _begin_summon(kind: String) -> void:
	_busy = SUMMON_BUSY
	_lock(SUMMON_BUSY)
	if kind == "kabak1":
		_pumpkin_cd = randf_range(PUMPKIN_CD_MIN, PUMPKIN_CD_MAX) * _haste()
		_anim("cast", 0.8)
	else:
		_bat_cd = randf_range(BAT_CD_MIN, BAT_CD_MAX) * _haste()
		_anim("summon", 1.1)
	_after(SUMMON_WINDUP, _spawn_wave.bind(kind))


func _spawn_wave(kind: String) -> void:
	var spawner: Node = _spawner()
	if spawner == null:
		return
	var extra: int = maxi(0, _player_count() - 1)
	var count: int = PUMPKIN_COUNT + extra * PUMPKIN_PER_EXTRA_PLAYER if kind == "kabak1" else BAT_COUNT + extra * BAT_PER_EXTRA_PLAYER
	var cap: int = PUMPKIN_MAX_ALIVE if kind == "kabak1" else BAT_MAX_ALIVE
	if _phase2():
		count = int(ceil(float(count) * P2_WAVE_MULT))
	count = mini(count, cap - _alive_count(kind))
	var base: float = randf() * TAU
	for i in range(maxi(count, 0)):
		var ang: float = base + float(i) / float(maxi(count, 1)) * TAU + randf_range(-0.2, 0.2)
		var pos: Vector2 = e.global_position + Vector2.from_angle(ang) * randf_range(SUMMON_RING_MIN, SUMMON_RING_MAX)
		if GameManager.is_position_blocked_by_walls(pos):
			pos = e.global_position + Vector2.from_angle(ang) * 40.0
		spawner.spawn_summon(kind, pos, e)


func _spawner() -> Node:
	var scene: Node = e.get_tree().current_scene
	if scene == null:
		return null
	var s: Node = scene.get_node_or_null("EnemySpawner")
	return s if s != null and s.has_method("spawn_summon") else null


func _player_count() -> int:
	return maxi(1, NetworkManager.game_player_count() if NetworkManager.is_multiplayer_active else 1)


## Bu bossun yaşayan minyonlarından `kind` türünde olanların sayısı.
func _alive_count(kind: String) -> int:
	var n: int = 0
	for m: Node in e.get_tree().get_nodes_in_group("summons"):
		if is_instance_valid(m) and m.get("is_dead") != true and str(m.get_meta("creature_id", "")) == kind and m.get_meta("summoner", null) == e:
			n += 1
	return n
