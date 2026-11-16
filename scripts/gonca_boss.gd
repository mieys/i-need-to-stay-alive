extends RefCounted

## ZEHİRLİ GONCA (madde 682, 2026-11-14) - Kara Bataklık Kademe 5 bossu. SADECE host / tek oyunculuda çalışır (enemy_abilities.gd her fizik karesinde
## process()'i çağırır, "gonca" ailesi). Kullanıcı: "çiçek canavarının etrafa saçtığı tohumlar yeni yeni çiçek canavarlarına dönüşsün ve giderek
## çoğalsın, her çoğalttıklarını öldürdüğümüzde canı ve kalkanı azalsın. bitkiler yaklaşınca saldırıp ısırsın ve zehirlesin. oldukça zor bir boss
## olmalı". Sanatta yürüme yok: yerinden KIPIRDAMAZ (sahnede hız 0).
##   - TOHUM SAÇMA ("spit" = başını soğana çekip tükürür): SEED_COUNT tohum havada kavis çizip etrafa düşer (yarısı oyuncuların yakınına), yerde
##     SEED_SPROUT sn sonra FİLİZ'e dönüşür (gonca_filiz.gd: kıpırdamaz, yaklaşanı ısırıp zehirler, kendisi de tohum saçar -> giderek çoğalır).
##     Düştüğü yerde oyuncu varsa SEED_DAMAGE + zehir ve tohum filizlenmez; yerdeki tohumun üstüne basan oyuncu onu EZER (gonca_seed.gd).
##   - KAN BAĞI: her Filiz öldürüldüğünde boss azami canının VE azami kalkanının DRAIN_FRACTION'ı kadar kaybeder (gonca_filiz.gd on_owner_died ->
##     drain_boss). Soğurma %92 (FIXED_BOSS_STATS): doğrudan vuruş zayıf, asıl yol yavruları kesmek. Yaşayan her Filiz bossa REGEN_PER_FILIZ can verir.
##   - DİKEN HALKASI (saldırı klibi, pembe halka): yakına gelen oyunculara RING_DAMAGE alan hasarı + zehir (uyarı halkası, gonca_ring.gd).
##   - KÖK GÖÇÜ: yakınında oyuncu varken bir Filiz'in yerine göçer (o Filiz bossun içine çekilir, ödülsüz) - kovalamaca.
##   - FAZ 2 (can + kalkan yarının altında): daha çok tohum, tüm beklemeler x0,65, Filiz tavanı + FILIZ_CAP_P2_BONUS.
## Isırık (normal saldırı) = C++ temas saldırısı (FIXED_BOSS_STATS "damage"), zehir handle_melee_hit'te ("gonca_bite", player.gd).
## ÇOK OYUNCULU: karar/hasar/doğuş host'ta. İstemciler: animasyon ("boss_event" anim), göç (boss_event "blink"), tohum / halka / öz akışı (dünya efekti
## yayını), Filizler (normal yaratık doğuş RPC'si), can/kalkan (yaratık senkronu).

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")

const SEED_FIRST := 2.5
const SEED_CD_MIN := 4.0
const SEED_CD_MAX := 5.2
const SEED_COUNT := 4
const SEED_COUNT_P2 := 6
const SEED_PER_EXTRA_PLAYER := 1
const SEED_WINDUP := 0.45 ## spit klibinin baş-içeri karesi (8 kare / 9 fps)
const SEED_GAP := 0.07
const SEED_BUSY := 0.95
const SEED_RANGE_MIN := 110.0
const SEED_RANGE_MAX := 360.0
const SEED_AT_PLAYER_CHANCE := 0.6 ## tohumların bu kadarı bir oyuncunun yakınına düşer
const SEED_LEAD_MAX := 110.0 ## yürüyen oyuncuya nişan: gideceği yere (hız x uçuş süresi) atılır, en fazla bu kadar önde
const SEED_NEAR_PLAYER_SPREAD := 70.0
const SEED_FLIGHT := 0.85
const SEED_SPROUT := 1.6 ## yere düştükten sonra filizlenme süresi (bu sürede ezilebilir)
const SEED_DAMAGE := 60.0
const SEED_ARC := 70.0 ## kavis tepesi (px)
const MOUTH := Vector2(0.0, -46.0)

const FILIZ_ID := "filiz1"
const FILIZ_MAX_ALIVE := 14
const FILIZ_PER_EXTRA_PLAYER := 4
const FILIZ_CAP_P2_BONUS := 6

const DRAIN_FRACTION := 0.03 ## Filiz başına azami can VE azami kalkanın %3'ü
const REGEN_PER_FILIZ := 0.0005 ## yaşayan Filiz başına saniyede azami canın %0,05'i (can; kalkan değil)
const COUNT_INTERVAL := 0.5

const RING_RANGE := 150.0 ## bu mesafede oyuncu varsa
const RING_RADIUS := 140.0
const RING_DAMAGE := 110.0
const RING_FIRST := 3.0
const RING_CD := 4.5
const RING_WINDUP := 0.5
const RING_BUSY := 0.8

const MIGRATE_FIRST := 28.0 ## 2026-11-14 kullanıcı: "çok hızlı kaçıyor" - eskiden 14 sn'de bir, ekran dışına bile ışınlanıyordu
const MIGRATE_CD_MIN := 24.0
const MIGRATE_CD_MAX := 30.0
const MIGRATE_NEAR := 220.0
const MIGRATE_MAX_DIST := 300.0 ## yalnız bossa bu kadar yakındaki Filiz'e göçer (uzağa kaçış yok)
const MIGRATE_MIN_DIST := 110.0 ## bundan yakın Filiz'e göçmek anlamsız
const MIGRATE_SINK := 0.6
const MIGRATE_RISE := 0.45

const PHASE2_RATIO := 0.5
const PHASE2_CD_MULT := 0.65

var e: Node2D = null
var _seed_cd: float = SEED_FIRST
var _ring_cd: float = RING_FIRST
var _migrate_cd: float = MIGRATE_FIRST
var _busy: float = 0.0
var _queue: Array = []
var _count_t: float = 0.0
var _alive_filiz: int = 0


func setup(owner_enemy: Node2D) -> void:
	e = owner_enemy


func process(delta: float, player: Node2D, dist: float) -> void:
	_run_queue(delta)
	_count_t -= delta
	if _count_t <= 0.0:
		_count_t = COUNT_INTERVAL
		_alive_filiz = filiz_count(e)
	_regen(delta)
	if _busy > 0.0:
		_busy -= delta
		return
	_seed_cd -= delta
	_ring_cd -= delta
	_migrate_cd -= delta
	var near: float = _nearest_player_dist()
	if _ring_cd <= 0.0 and near <= RING_RANGE:
		_begin_ring()
		return
	if _migrate_cd <= 0.0 and near <= MIGRATE_NEAR and _alive_filiz > 0:
		if _begin_migrate():
			return
		_migrate_cd = 1.0
	if _seed_cd <= 0.0 and _valid_target(player):
		_begin_seeds()


# ---------------------------------------------------------------------------------------------------- yardımcılar
func _phase2() -> bool:
	var total: float = float(e.get("max_health")) + float(e.get("item_shield_max"))
	if total <= 0.0:
		return false
	return (float(e.get("health")) + float(e.get("item_shield_hp"))) / total <= PHASE2_RATIO


func haste() -> float:
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
	e.set("_ranged_timer", maxf(float(e.get("_ranged_timer")), seconds)) ## ısırık animasyonun üstüne binmesin


func _nearest_player_dist() -> float:
	var best: float = INF
	for p in AbilitiesScript.damageable_players(e.get_tree()):
		best = minf(best, e.global_position.distance_to((p as Node2D).global_position))
	return best


func _player_count() -> int:
	return maxi(1, NetworkManager.game_player_count() if NetworkManager.is_multiplayer_active else 1)


## Filiz tavanı (oyuncu sayısı + faz 2).
func filiz_cap() -> int:
	var cap: int = FILIZ_MAX_ALIVE + maxi(0, _player_count() - 1) * FILIZ_PER_EXTRA_PLAYER
	return cap + (FILIZ_CAP_P2_BONUS if _phase2() else 0)


## `boss`un yaşayan Filiz sayısı.
static func filiz_count(boss: Node) -> int:
	if boss == null or not is_instance_valid(boss) or not boss.is_inside_tree():
		return 0
	var n: int = 0
	for m: Node in boss.get_tree().get_nodes_in_group("summons"):
		if is_instance_valid(m) and m.get("is_dead") != true and str(m.get_meta("creature_id", "")) == FILIZ_ID and (m.get_meta("summoner") if m.has_meta("summoner") else null) == boss:
			n += 1
	return n


func _regen(delta: float) -> void:
	if _alive_filiz <= 0:
		return
	var mh: float = float(e.get("max_health"))
	var h: float = float(e.get("health"))
	if h >= mh or h <= 0.0:
		return
	e.set("health", minf(mh, h + mh * REGEN_PER_FILIZ * float(_alive_filiz) * delta))
	e.emit_signal("health_changed", e.get("health"), mh)


## KAN BAĞI: Filiz öldü (host, gonca_filiz.gd on_owner_died) -> bossun canından ve kalkanından azami değerlerinin `frac`ı düşer. Can 0'a inerse boss ölür.
## Can/kalkan istemcilere normal yaratık senkronuyla gider.
static func drain_boss(boss: Node, frac: float) -> void:
	if boss == null or not is_instance_valid(boss) or boss.get("is_dead") == true or frac <= 0.0:
		return
	var sh_max: float = float(boss.get("item_shield_max"))
	if sh_max > 0.0:
		boss.set("item_shield_hp", maxf(0.0, float(boss.get("item_shield_hp")) - sh_max * frac))
		boss.emit_signal("item_shield_changed", boss.get("item_shield_hp"), sh_max)
	var mh: float = float(boss.get("max_health"))
	var h: float = float(boss.get("health")) - mh * frac
	boss.set("health", maxf(h, 0.0))
	boss.emit_signal("health_changed", boss.get("health"), mh)
	if h <= 0.0 and boss.has_method("die"):
		boss.call("die")


## Bir tohum fırlat (boss ya da Filiz; host). `boss` her zaman Zehirli Gonca'nın kendisi (filizler ona bağlanır).
static func throw_seed(boss: Node2D, from: Vector2, to: Vector2) -> void:
	if boss == null or not is_instance_valid(boss) or not boss.is_inside_tree():
		return
	var mult: float = float(boss.get_meta("boss_damage_mult", 1.0))
	var data: Dictionary = {"to": to, "flight": SEED_FLIGHT, "sprout": SEED_SPROUT, "arc": SEED_ARC, "sid": next_seed_id()}
	AbilitiesScript.spawn_world_fx(boss.get_tree(), "gonca_seed", from, data, true, boss, SEED_DAMAGE * mult)
	AbilitiesScript._broadcast_world_fx("gonca_seed", from, data)


static var _seed_seq: int = 0


static func next_seed_id() -> int:
	_seed_seq += 1
	return _seed_seq


## Duvar / orman içine düşmesin: engelliyse kaynağa doğru yaklaştırır.
static func free_landing(from: Vector2, to: Vector2) -> Vector2:
	var p: Vector2 = to
	for i in 6:
		if not GameManager.is_position_blocked_by_walls(p):
			return p
		p = p.lerp(from, 0.3)
	return from


# ---------------------------------------------------------------------------------------------------- tohum saçma
func _begin_seeds() -> void:
	_busy = SEED_BUSY
	_seed_cd = randf_range(SEED_CD_MIN, SEED_CD_MAX) * haste()
	_lock(SEED_BUSY)
	_anim("spit", 0.9)
	var count: int = (SEED_COUNT_P2 if _phase2() else SEED_COUNT) + maxi(0, _player_count() - 1) * SEED_PER_EXTRA_PLAYER
	var players: Array = AbilitiesScript.damageable_players(e.get_tree())
	for k in range(count):
		var to: Vector2
		if not players.is_empty() and randf() < SEED_AT_PLAYER_CHANCE:
			var p: Node2D = players[randi() % players.size()] as Node2D
			to = p.global_position + _lead(p) + Vector2.from_angle(randf() * TAU) * randf_range(0.0, SEED_NEAR_PLAYER_SPREAD)
		else:
			to = e.global_position + Vector2.from_angle(randf() * TAU) * randf_range(SEED_RANGE_MIN, SEED_RANGE_MAX)
		_after(SEED_WINDUP + k * SEED_GAP, _throw.bind(to))


## Oyuncunun kurulum + uçuş süresince gideceği yer (hız x süre, SEED_LEAD_MAX ile kırpılı): tohum eski konuma düşüp boşa gitmesin.
func _lead(p: Node2D) -> Vector2:
	var v: Variant = p.get("velocity")
	if not (v is Vector2):
		return Vector2.ZERO
	return ((v as Vector2) * (SEED_WINDUP + SEED_FLIGHT)).limit_length(SEED_LEAD_MAX)


func _throw(to: Vector2) -> void:
	throw_seed(e, e.global_position + MOUTH, free_landing(e.global_position, to)) ## MOUTH dünya biriminde (boss boyu dahil)


# ---------------------------------------------------------------------------------------------------- diken halkası
func _begin_ring() -> void:
	_busy = RING_BUSY
	_ring_cd = RING_CD * haste()
	_lock(RING_BUSY)
	_anim("ring", 0.8) ## saldırı klibi (kollar kıvrılır, pembe halka)
	var data: Dictionary = {"radius": RING_RADIUS, "warn": RING_WINDUP}
	var mult: float = float(e.get_meta("boss_damage_mult", 1.0))
	AbilitiesScript.spawn_world_fx(e.get_tree(), "gonca_ring", e.global_position, data, true, e, RING_DAMAGE * mult)
	AbilitiesScript._broadcast_world_fx("gonca_ring", e.global_position, data)


# ---------------------------------------------------------------------------------------------------- kök göçü
## Bossa MIGRATE_MIN..MAX_DIST yakınındaki, oyunculara en uzak Filiz'in yerine göçer; o Filiz ödülsüz kaybolur (bossun içine çekilir - kan bağı kesintisi YOK).
func _begin_migrate() -> bool:
	var best: Node2D = null
	var best_d: float = -1.0
	var players: Array = AbilitiesScript.damageable_players(e.get_tree())
	for m: Node in e.get_tree().get_nodes_in_group("summons"):
		if not is_instance_valid(m) or m.get("is_dead") == true or str(m.get_meta("creature_id", "")) != FILIZ_ID or (m.get_meta("summoner") if m.has_meta("summoner") else null) != e:
			continue
		var from_boss: float = e.global_position.distance_to((m as Node2D).global_position)
		if from_boss < MIGRATE_MIN_DIST or from_boss > MIGRATE_MAX_DIST:
			continue
		var d: float = INF
		for p in players:
			d = minf(d, (m as Node2D).global_position.distance_to((p as Node2D).global_position))
		if d > best_d:
			best_d = d
			best = m as Node2D
	if best == null:
		return false
	_migrate_cd = randf_range(MIGRATE_CD_MIN, MIGRATE_CD_MAX) * haste()
	_seed_cd = minf(_seed_cd, 0.8) ## yerleşir yerleşmez tohum yağdırır
	_busy = MIGRATE_SINK + MIGRATE_RISE
	_lock(_busy)
	_anim("spit", MIGRATE_SINK) ## baş soğana çekilir: toprağa gömülüyor
	_after(MIGRATE_SINK, _migrate_to.bind(weakref(best)))
	return true


func _migrate_to(target_ref: WeakRef) -> void:
	var f: Node2D = target_ref.get_ref() as Node2D
	if f == null or f.get("is_dead") == true:
		_busy = 0.0
		return
	var to: Vector2 = f.global_position
	f.set_meta("gonca_absorbed", true) ## kan bağı kesintisi yapmaz (gonca_filiz.gd)
	f.call("emit_ability_vfx", "boss_event", {"k": "dismiss"})
	e.call("emit_ability_vfx", "boss_event", {"k": "blink", "to": to})
	_anim("grow", MIGRATE_RISE)
