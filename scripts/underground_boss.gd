extends "res://scripts/enemy.gd"

## YERALTI CANAVARI (Kademe 5 bossu, kullanıcı isteği 2026-10-09; sayılar worm_boss_math.gd, uzuv worm_limb.gd). Boss yeraltında ve yeryüzüne ÇIKAMIYOR:
## bu düğüm GÖRÜNMEZ ve VURULAMAZ bir "havuz" - can + kalkan (üstteki boss barı bunu okur), konumu oyuncuların ortasında. Kendini yeryüzüne SOLUCAN UZUVLARI (worm_limb.gd)
## çıkararak gösterir; uzuvların yediği hasar buraya (absorb_limb_damage) AYNEN düşer, havuz bitince boss ölür (standart Enemy.die(): XP/altın/sandık, uzuvlar dağılır).
##
## YÖNETMEN (SADECE host / tek oyunculu, _physics_process): oyuncuların hızını izler; her 1,3-2 sn'de bir uzvu bir oyuncunun GİTTİĞİ YÖNÜN ÖNÜNDE (yolunu keser; duruyorsa çevresinde)
## çıkarır, 13-19 sn'de bir yolun önüne DÜMDÜZ SIRA (5 uzuv, 46 px aralık, sırayla) kurar. Aynı anda en çok MAX_ACTIVE (+ekstra oyuncu başına 2) uzuv. 5-9 sn'de bir yeraltı
## gümbürtüsü, 9-15 sn'de bir hırıltı, 16-26 sn'de bir "larva" katmanı çalar (broadcast_enemy_vfx -> her peer yerelde; ses dosyaları tools/gen_underground_sounds.py + Horror paketi).
## Boss hiçbir şeyi doğrudan YEMEZ: weapon/alan hasarı take_damage'a gelse bile yok sayılır (sadece uzuvlar havuzu eritir), C++ EnemyWorld'e KAYITLI DEĞİL (mermileri yutmaz).

const MathScript := preload("res://scripts/worm_boss_math.gd")
const SoundScript := preload("res://scripts/underground_sound.gd")
const LIMB_ID := "sandworm1"
const LIMB_TIER := 5 ## uzuvların yaratık kademesi (spawn_tier meta KONMAZ: Kademe kapısı sayımına girmesin)

var _limbs: Array = [] ## host: canlı (gömülmeyen) uzuv düğümleri
var _track: Dictionary = {} ## oyuncu instance id -> {"pos": Vector2, "vel": Vector2}
var _spawn_timer: float = MathScript.FIRST_SPAWN_DELAY
var _line_timer: float = MathScript.FIRST_LINE_DELAY
var _line_queue: Array = [] ## [{"pos": Vector2, "t": float}]
var _rumble_timer: float = 2.5
var _growl_timer: float = 7.0
var _ambient_timer: float = 11.0
var _follow_timer: float = 0.0
var _rr: int = 0


# ---------------------------------------------------------------------------------------------------- görünmez / vurulamaz havuz
func _ready() -> void:
	set_meta(&"hide_on_minimap", true) ## minimap.gd: havuz düğümü çizilmez
	set_meta(&"untargetable", true) ## silah hedeflemesi (vision_fog.gd can_target) bossu seçmez
	super._ready()


func _ew_try_register() -> void:
	pass ## C++ EnemyWorld'e KAYIT YOK: hedeflenmez, mermi/alan sorgularında görünmez, hareket etmez


func _ew_warn_unregistered() -> void:
	pass


func _create_overhead_bar() -> void:
	pass ## yeraltında: üstünde kafatası plakası yok (can/kalkan sadece üst boss barında)


func take_damage(_amount: float, _is_crit: bool = false, _shield_pen_percent: float = 0.0, _is_area: bool = false) -> void:
	return ## doğrudan hasar yok sayılır: boss sadece uzuvlar üzerinden azalır


func take_damage_host(_amount: float, _is_crit: bool, _shield_pen_percent: float, _attacker_id: int = 0) -> void:
	return


func _take_dot_damage(_amount: float, _shield_pen: float = 0.0) -> void:
	return


func _show_hit_number(_shown_amount: float, _is_crit: bool) -> void:
	pass ## uzuv vuruşunda sayı zaten uzvun üstünde çıkar


## Uzuvların yediği hasar (host): bossun kalkan/can havuzundan AYNEN düşer (kalkan emilimi/yenilenme gecikmesi normal boss gibi).
func absorb_limb_damage(amount: float, attacker_peer: int = 0) -> void:
	if is_dead or amount <= 0.0:
		return
	if attacker_peer > 0:
		last_attacker_peer_id = attacker_peer
	_apply_damage(amount, false, 0.0)


func on_limb_gone(limb: Node) -> void:
	_limbs.erase(limb)


# ---------------------------------------------------------------------------------------------------- ölüm
func die() -> void:
	if is_dead:
		return
	if _is_authority():
		for l in _limbs.duplicate():
			if is_instance_valid(l) and l.get("is_dead") != true:
				l.die() ## havuz bitti: tüm uzuvlar parçalanır (her biri death_state yayınlar)
		_limbs.clear()
	if is_inside_tree():
		SoundScript.play(get_tree(), &"rumble_1")
		SoundScript.play(get_tree(), &"growl_2")
	super.die()


func _is_authority() -> bool:
	return not NetworkManager.is_multiplayer_active or NetworkManager.is_host


# ---------------------------------------------------------------------------------------------------- yönetmen (host)
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead or not _is_authority():
		return
	_director_tick(delta)


func _director_tick(delta: float) -> void:
	var targets: Array = _targets()
	_track_targets(targets, delta)
	_follow_players(targets, delta)
	_limbs = _limbs.filter(func(l: Variant) -> bool: return is_instance_valid(l) and l.get("is_dead") != true)
	_sound_tick(delta)
	if targets.is_empty():
		return
	## sıradaki uzuvlar tek tek (sırayla) çıkar
	for item: Dictionary in _line_queue:
		item["t"] = float(item["t"]) - delta
	while not _line_queue.is_empty() and float(_line_queue[0]["t"]) <= 0.0:
		var item: Dictionary = _line_queue.pop_front()
		var p: Vector2 = item["pos"]
		if MathScript.spawn_ok(p, _target_positions(targets), _limb_positions(), _blocked_cb(), 30.0):
			_spawn_limb(p, MathScript.KIND_LASHER, MathScript.pick_fate(randf()), randf_range(MathScript.LINE_LIFETIME_MIN, MathScript.LINE_LIFETIME_MAX))
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _limbs.size() < MathScript.max_active(maxi(1, NetworkManager.game_player_count())):
		_spawn_timer = randf_range(MathScript.SPAWN_INTERVAL_MIN, MathScript.SPAWN_INTERVAL_MAX)
		_spawn_cutting_limb(targets)
	_line_timer -= delta
	if _line_timer <= 0.0 and _line_queue.is_empty():
		if _start_line(targets):
			_line_timer = randf_range(MathScript.LINE_INTERVAL_MIN, MathScript.LINE_INTERVAL_MAX)
		else:
			_line_timer = 3.0 ## kimse hareket etmiyor: kısa süre sonra yeniden bak


## Hedef olabilecek oyuncular: canlı, dışarıda (evde / satıcı bölgesinde değil), yerde yatmıyor.
func _targets() -> Array:
	var out: Array = []
	for p: Node in EnemyAbilitiesScript.damageable_players(get_tree()):
		if not (p is Node2D) or p.get("is_indoors") == true or p.get("is_in_merchant_zone") == true or p.get("is_downed") == true:
			continue
		out.append(p)
	return out


func _target_positions(targets: Array) -> Array:
	return targets.map(func(p: Node) -> Vector2: return (p as Node2D).global_position)


func _limb_positions() -> Array:
	return _limbs.map(func(l: Node) -> Vector2: return (l as Node2D).global_position)


func _track_targets(targets: Array, delta: float) -> void:
	var seen: Dictionary = {}
	for p: Node in targets:
		var id: int = p.get_instance_id()
		var pos: Vector2 = (p as Node2D).global_position
		seen[id] = true
		if _track.has(id):
			var rec: Dictionary = _track[id]
			rec["vel"] = MathScript.smooth_velocity(rec["vel"], rec["pos"], pos, delta)
			rec["pos"] = pos
		else:
			_track[id] = {"pos": pos, "vel": Vector2.ZERO}
	for id in _track.keys():
		if not seen.has(id):
			_track.erase(id)


func _velocity_of(p: Node) -> Vector2:
	var rec: Variant = _track.get(p.get_instance_id())
	return rec["vel"] if rec != null else Vector2.ZERO


## Boss konumu oyuncuların ortasında (yeraltında onların altında): üstteki boss barı en yakın bossu seçer, çıkan ganimet de oyuncuların yanına düşer.
func _follow_players(targets: Array, delta: float) -> void:
	_follow_timer -= delta
	if _follow_timer > 0.0 or targets.is_empty():
		return
	_follow_timer = 0.25
	var sum := Vector2.ZERO
	for p: Node in targets:
		sum += (p as Node2D).global_position
	global_position = sum / float(targets.size())


## Bir oyuncunun yolunu keser: gidiş yönünün önünde (duruyorsa çevresinde) uygun bir nokta bulup uzuv çıkarır.
func _spawn_cutting_limb(targets: Array) -> void:
	_rr = (_rr + 1) % targets.size()
	var p: Node2D = targets[_rr] as Node2D
	var vel: Vector2 = _velocity_of(p)
	var positions: Array = _target_positions(targets)
	for _i in range(MathScript.PLACE_TRIES):
		var pos: Vector2 = MathScript.path_cut_position(p.global_position, vel, randf_range(MathScript.LEAD_MIN, MathScript.LEAD_MAX),
				randf_range(-MathScript.LATERAL, MathScript.LATERAL), randf() * TAU, randf_range(MathScript.STILL_RING_MIN, MathScript.STILL_RING_MAX))
		if MathScript.spawn_ok(pos, positions, _limb_positions(), _blocked_cb()):
			_spawn_limb(pos, MathScript.pick_kind(randf()), MathScript.pick_fate(randf()), randf_range(MathScript.LIFETIME_MIN, MathScript.LIFETIME_MAX))
			return


## Hareket eden bir oyuncunun önüne DAĞINIK bir sıra kurar (aralıklar/kaymalar/çıkış sırası rastgele, bkz. worm_boss_math.gd scattered_line); engelli noktalar atlanır.
func _start_line(targets: Array) -> bool:
	var movers: Array = targets.filter(func(p: Node) -> bool: return _velocity_of(p).length() > MathScript.STILL_SPEED)
	if movers.is_empty():
		return false
	var p: Node2D = movers[randi() % movers.size()] as Node2D
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spots: Array[Dictionary] = MathScript.scattered_line(p.global_position, _velocity_of(p), rng)
	var queued: int = 0
	var delay_shift: float = 0.0 ## engelli nokta atlanınca sonraki gecikmeler geriye kaysın (boş bekleme olmasın)
	var last_delay: float = 0.0
	for spot: Dictionary in spots:
		if bool(_blocked_cb().call(spot["pos"])):
			delay_shift += float(spot["delay"]) - last_delay
		else:
			_line_queue.append({"pos": spot["pos"], "t": float(spot["delay"]) - delay_shift})
			queued += 1
		last_delay = float(spot["delay"])
	return queued >= 2


func _blocked_cb() -> Callable:
	return func(q: Vector2) -> bool: return GameManager.is_position_blocked_by_terrain(q) \
			or (GameManager.merchant_zone_active and q.distance_to(GameManager.merchant_zone_pos) <= GameManager.MERCHANT_ZONE_RADIUS + 40.0)


## Bir uzuv doğurur: spawner'ın normal doğuş yolu (ağ kimliği + istemcilere yayın), ardından uzvun kendi kurulumu.
func _spawn_limb(pos: Vector2, limb_kind: int, limb_fate: int, lifetime: float) -> Node:
	var sp: Node = get_tree().get_first_node_in_group("enemy_spawner")
	if sp == null:
		return null
	var net_id: int = int(sp.get("_next_network_enemy_id"))
	sp.set("_next_network_enemy_id", net_id + 1)
	var limb: Node = sp.call("_spawn_creature", LIMB_ID, pos, net_id)
	if limb == null:
		return null
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		sp.call("_announce_spawn", limb, LIMB_ID, pos, LIMB_TIER, false, net_id, false, false)
	limb.begin_limb(self, limb_kind, limb_fate, lifetime)
	_limbs.append(limb)
	return limb


# ---------------------------------------------------------------------------------------------------- sesler (korkutucu yeraltı sesleri)
func _sound_tick(delta: float) -> void:
	_rumble_timer -= delta
	if _rumble_timer <= 0.0:
		_rumble_timer = randf_range(MathScript.RUMBLE_MIN, MathScript.RUMBLE_MAX)
		emit_ability_vfx("worm_rumble", {"v": randi_range(1, 3)})
	_growl_timer -= delta
	if _growl_timer <= 0.0:
		_growl_timer = randf_range(MathScript.GROWL_MIN, MathScript.GROWL_MAX)
		emit_ability_vfx("worm_growl", {"v": randi_range(1, 2)})
	_ambient_timer -= delta
	if _ambient_timer <= 0.0:
		_ambient_timer = randf_range(MathScript.AMBIENT_MIN, MathScript.AMBIENT_MAX)
		emit_ability_vfx("worm_ambient", {})


func on_ability_vfx(vfx_kind: String, data: Dictionary) -> void:
	match vfx_kind:
		"worm_rumble":
			if is_inside_tree():
				SoundScript.play(get_tree(), StringName("rumble_%d" % clampi(int(data.get("v", 1)), 1, 3)))
				CameraShakeScript.add_limited("worm_rumble", 0.12, 2.0) ## yer sarsılıyor (çok hafif)
		"worm_growl":
			if is_inside_tree():
				SoundScript.play(get_tree(), StringName("growl_%d" % clampi(int(data.get("v", 1)), 1, 2)))
		"worm_ambient":
			if is_inside_tree():
				SoundScript.play(get_tree(), &"ambient")
		_:
			super.on_ability_vfx(vfx_kind, data)
