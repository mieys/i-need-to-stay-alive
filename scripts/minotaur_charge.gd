extends RefCounted

## MINOTAUR (Kademe 3 bossu) hücum durum makinesi - SADECE host / tek oyunculuda çalışır (enemy_abilities.gd her fizik karesinde process()'i
## çağırır; bkz. orada "minotaur" ailesi). Sayılar ve saf hesaplar minotaur_math.gd'de.
##
## AKIŞ:  CHASE (C++ normal kovalama + temas saldırısı) -> WINDUP (durur, eğilir; AIM_LOCK_AT'ta yön kilitlenir, uyarı şeridi belirir)
##        -> CHARGE (hareketi BU betik sürer: ability_move_lock ile C++ hareketi kapalı, konumu her karede elle ilerletir; C++ dışarıdan
##        taşınan konumu benimser, vampir ışınlanmasıyla aynı yol) -> RECOVER (nefes alır; duvara çarptıysa daha uzun) -> CHASE.
##
## ÇOK OYUNCULU (CLAUDE.md "iki yerde aynı bilgi" sınıfı): karar + hasar + savrulma SADECE host'ta. İstemciler üç şeyi alır:
##  - uyarı şeridi: dünyada duran etki olarak (enemy_abilities.gd spawn_synced_world_fx -> "charge_lane", istemcide hasarsız kopya),
##  - boss pozu + dust: broadcast_enemy_vfx "minotaur_pose" (enemy.gd on_ability_vfx -> _apply_minotaur_pose; hücum boyunca ağ hızı
##    tavanı da yükselir, yoksa kukla 3,5x hız sınırında kalıp geriden gelirdi) ve "minotaur_impact" (toz + kamera sarsıntısı),
##  - konum: her zamanki yaratık konum paketi (host düğümü her karede ilerlediği için paketler hücumu izler).
## Oyuncuya hasar: deal_special_damage(kind "minotaur") (uzak oyuncuda RemotePlayer -> forward_special_damage_to_peer), hemen ardından
## savrulma (yerelde player.apply_boss_fling, uzakta NetworkManager.forward_player_fling_to_peer). Savrulma SADECE hasar gerçekten
## işlendiyse uygulanır (player.gd _minotaur_hit_msec damgası) - kaçınılan / dokunulmaz oyuncu savrulmaz.

const MathScript := preload("res://scripts/minotaur_math.gd")

enum Phase { CHASE, WINDUP, CHARGE, RECOVER }

var e: Node2D = null ## sahip yaratık (Enemy)
var phase: int = Phase.CHASE
var mode: int = MathScript.MODE_HORN

var _cd: float = 0.0 ## sonraki hücuma kalan süre (CHASE'te azalır)
var _t: float = 0.0 ## içinde bulunulan fazın süresi
var _dir: Vector2 = Vector2.DOWN
var _speed: float = 0.0
var _planned_length: float = 0.0 ## uyarı şeridinin (duvara kısaltılmış) uzunluğu
var _travel_left: float = 0.0
var _lane_shown: bool = false
var _recover_time: float = MathScript.RECOVER_TIME
var _hit_ids: Dictionary = {} ## bu hücumda vurulan oyuncuların instance id'leri (hücum başına BİR kez)
var _hit_count: int = 0
var _first_hit_t: float = -1.0
var _pose: int = MathScript.POSE_NONE
var _last_process_msec: int = 0
## Test dikişi: >= 0 ise hücum türü rastgele seçilmez, bu değer kullanılır (MathScript.MODE_*).
var forced_mode: int = -1


func setup(owner_enemy: Node2D) -> void:
	e = owner_enemy
	_cd = randf_range(MathScript.FIRST_CD_MIN, MathScript.FIRST_CD_MAX)
	_last_process_msec = Time.get_ticks_msec()


## C++ temas saldırısı olayını (enemy.gd _ew_on_event EW_E_MELEE) bastırır: hücum/toparlanma sırasında yakın dövüş vuruşu yok,
## aksi halde hücum hasarının üstüne bir de temas vuruşu biner ve poz/animasyon bozulur.
func blocks_melee() -> bool:
	return phase != Phase.CHASE


func process(delta: float, player: Node2D, dist: float) -> void:
	var now: int = Time.get_ticks_msec()
	if phase != Phase.CHASE and now - _last_process_msec > MathScript.ABORT_GAP_MSEC:
		_abort() ## yaratık bir süre tiklenmedi (donma/korku/sersemleme): yarım kalan hücumu temizle
	_last_process_msec = now
	match phase:
		Phase.CHASE:
			_process_chase(delta, player, dist)
		Phase.WINDUP:
			_process_windup(delta, player)
		Phase.CHARGE:
			_process_charge(delta, player)
		Phase.RECOVER:
			_process_recover(delta)


# ---------------------------------------------------------------------------------------------------- kovalama
func _process_chase(delta: float, player: Node2D, dist: float) -> void:
	_cd -= delta
	if _cd > 0.0:
		return
	if not _valid_target(player) or dist < MathScript.RANGE_MIN or dist > MathScript.RANGE_MAX:
		return
	if not bool(e.call("_has_line_of_sight", player)):
		_cd = 0.4 ## görüş yok: kısa süre sonra yeniden bak (her kare LOS sorgusu yapma)
		return
	_begin_windup(player, dist)


func _begin_windup(player: Node2D, dist: float) -> void:
	mode = forced_mode if forced_mode >= 0 else MathScript.pick_mode(dist, randf())
	phase = Phase.WINDUP
	_t = 0.0
	_lane_shown = false
	_dir = (player.global_position - e.global_position).normalized()
	_hit_ids.clear()
	_hit_count = 0
	_first_hit_t = -1.0
	_set_pose(MathScript.POSE_CROUCH)
	_lock(0.4)


func _windup_time() -> float:
	return MathScript.STAMPEDE_STOP_TIME if mode == MathScript.MODE_STAMPEDE else MathScript.WINDUP_TIME


func _process_windup(delta: float, player: Node2D) -> void:
	_t += delta
	_lock(0.25)
	var lock_at: float = _windup_time() - (MathScript.WINDUP_TIME - MathScript.AIM_LOCK_AT)
	if _t < lock_at:
		if _valid_target(player):
			_dir = (player.global_position - e.global_position).normalized()
	elif not _lane_shown:
		_lane_shown = true
		_show_lane(player)
	e.call("_update_facing", _dir)
	if _t >= _windup_time():
		_begin_charge()


func _show_lane(player: Node2D) -> void:
	var horn: bool = mode == MathScript.MODE_HORN
	var length: float
	if horn:
		var dist_to: float = e.global_position.distance_to(player.global_position) if _valid_target(player) else MathScript.HORN_MIN_LEN
		length = MathScript.horn_length(dist_to)
	else:
		length = MathScript.STAMPEDE_PREVIEW_LEN
	length = MathScript.clip_travel(e.global_position, _dir, length, _blocked_cb())
	_planned_length = length
	var warn: float = MathScript.WINDUP_TIME - MathScript.AIM_LOCK_AT
	var data: Dictionary = {"dir": _dir, "length": length, "width": MathScript.LANE_WIDTH if horn else MathScript.STAMPEDE_LANE_WIDTH,
			"warn": warn, "mode": mode}
	_abilities_script().spawn_synced_world_fx(e.get_tree(), "charge_lane", e.global_position, data, e)


# ---------------------------------------------------------------------------------------------------- hücum
func _begin_charge() -> void:
	var horn: bool = mode == MathScript.MODE_HORN
	if horn and _planned_length < 60.0:
		_end_charge(true) ## önü hemen duvar: atılacak yer yok, boynuzu duvara vurup sersemler
		return
	phase = Phase.CHARGE
	_t = 0.0
	_speed = MathScript.HORN_START_SPEED if horn else MathScript.STAMPEDE_START_SPEED
	_travel_left = _planned_length
	_set_pose(MathScript.POSE_CHARGE)


func _process_charge(delta: float, player: Node2D) -> void:
	_t += delta
	var horn: bool = mode == MathScript.MODE_HORN
	var toward: Vector2 = Vector2.ZERO
	if _valid_target(player):
		toward = (player.global_position - e.global_position).normalized()
	if horn:
		_speed = MathScript.horn_speed(_t)
		if _t < MathScript.HORN_HOMING_TIME:
			_dir = MathScript.turn_toward(_dir, toward, deg_to_rad(MathScript.HORN_HOMING_DEG) * delta)
	else:
		_speed = MathScript.stampede_speed(_speed, delta)
		_dir = MathScript.turn_toward(_dir, toward, deg_to_rad(MathScript.STAMPEDE_TURN_DEG) * delta)
	var step: float = _speed * delta
	if horn:
		step = minf(step, _travel_left)
	var from: Vector2 = e.global_position
	var to: Vector2 = from + _dir * step
	if MathScript.step_blocked(from, to, _blocked_cb()):
		_end_charge(true) ## duvar/engel: durur, çarpma tozu + sarsıntı, uzun sersemleme
		return
	e.global_position = to
	e.call("_update_facing", _dir)
	_lock(0.25)
	_check_hits(from, to)
	if horn:
		_travel_left -= step
		if _travel_left <= 0.5:
			_end_charge(false)
	else:
		if _first_hit_t < 0.0 and _hit_count > 0:
			_first_hit_t = _t
		if _t >= MathScript.STAMPEDE_MAX_TIME or (_first_hit_t >= 0.0 and _t - _first_hit_t >= MathScript.STAMPEDE_AFTER_HIT):
			_end_charge(false)


func _check_hits(from: Vector2, to: Vector2) -> void:
	var lane_w: float = MathScript.LANE_WIDTH if mode == MathScript.MODE_HORN else MathScript.STAMPEDE_LANE_WIDTH
	var radius: float = lane_w * 0.5 + MathScript.PLAYER_HIT_RADIUS
	for p: Node in _abilities_script().damageable_players(e.get_tree()):
		if not is_instance_valid(p) or not (p is Node2D):
			continue
		var id: int = p.get_instance_id()
		if _hit_ids.has(id):
			continue
		if p.get("is_indoors") == true or p.get("is_in_merchant_zone") == true or p.get("is_downed") == true:
			continue
		if MathScript.segment_distance((p as Node2D).global_position, from, to) > radius:
			continue
		_hit_ids[id] = true
		_hit_player(p as Node2D)


func _hit_player(p: Node2D) -> void:
	_hit_count += 1
	var dmg: float = float(e.get("contact_damage"))
	_abilities_script().deal_special_damage(p, dmg, e, "minotaur")
	var fling: Vector2 = MathScript.fling_direction(_dir, e.global_position, p.global_position)
	if p.is_in_group("remote_players"):
		var peer_id: int = int(p.get("peer_id"))
		if peer_id > 0:
			NetworkManager.forward_player_fling_to_peer.rpc_id(peer_id, fling, MathScript.FLING_DISTANCE)
	elif p.has_method("apply_boss_fling"):
		p.call("apply_boss_fling", fling, MathScript.FLING_DISTANCE)
	_emit_vfx("minotaur_impact", {"pos": p.global_position, "dir": fling, "power": 0.45})


func _end_charge(by_wall: bool) -> void:
	phase = Phase.RECOVER
	_t = 0.0
	_recover_time = MathScript.RECOVER_WALL_TIME if by_wall else MathScript.RECOVER_TIME
	_set_pose(MathScript.POSE_RISE)
	if by_wall:
		_emit_vfx("minotaur_impact", {"pos": e.global_position + _dir * 28.0, "dir": -_dir, "power": 0.6})


# ---------------------------------------------------------------------------------------------------- toparlanma
func _process_recover(delta: float) -> void:
	_t += delta
	_lock(0.25)
	if _t >= _recover_time:
		_finish(randf_range(MathScript.CD_MIN, MathScript.CD_MAX))


func _finish(next_cd: float) -> void:
	phase = Phase.CHASE
	_cd = next_cd
	_set_pose(MathScript.POSE_NONE)
	e.set("ability_move_lock", 0.0)


func _abort() -> void:
	if phase == Phase.CHASE:
		return
	_finish(1.0)


# ---------------------------------------------------------------------------------------------------- yardımcılar
func _valid_target(player: Node2D) -> bool:
	return player != null and is_instance_valid(player) and player.get("is_dead") != true


## C++ kendi hareketini bu süre boyunca kapatır (her tik tazelenir; yetenek tikleri kesilirse kısa süre sonra kendiliğinden açılır).
func _lock(seconds: float) -> void:
	e.set("ability_move_lock", maxf(float(e.get("ability_move_lock")), seconds))


## Duvar sorgusu: oyunda GameManager.is_position_blocked_by_walls (orman + su/bina/ağaç/maden hücreleri); testler kendi engelini verir.
var blocked_override: Callable = Callable()


func _blocked_cb() -> Callable:
	if blocked_override.is_valid():
		return blocked_override
	return func(p: Vector2) -> bool: return GameManager.is_position_blocked_by_walls(p)


func _set_pose(pose: int) -> void:
	_pose = pose
	var cap: float = MathScript.NET_SPEED_CAP if pose == MathScript.POSE_CHARGE else 0.0
	_emit_vfx("minotaur_pose", {"pose": pose, "cap": cap})


## Olayı HOST'ta yerelde işler (enemy.gd on_ability_vfx) ve çok oyunculuda istemcilere yayınlar - iki taraf AYNI işlevi çalıştırır.
func _emit_vfx(kind: String, data: Dictionary) -> void:
	e.call("on_ability_vfx", kind, data)
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		var net_id: int = int(e.get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.broadcast_enemy_vfx.rpc(net_id, kind, data)


## enemy_abilities.gd'yi çalışma anında yükle: o dosya bu betiği preload ediyor (döngüsel preload "Could not preload" verir).
static func _abilities_script() -> GDScript:
	return load("res://scripts/enemy_abilities.gd")
