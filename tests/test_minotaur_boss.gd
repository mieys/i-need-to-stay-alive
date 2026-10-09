extends Node

## Kullanıcı isteği (2026-10-08): masaüstündeki minotaur paketiyle Kademe 3'ün yeni bossu - "oyuncuya doğru hızlı bir şekilde boynuz atılması: geniş bir
## çizgi halinde oyuncuya yetişebilecek şekilde boynuzlu dash; bazen durur, hızlanarak koşar; boynuz darbesiyle vurunca hasar verip etrafa savurur
## (collision shapelerin içine girememeli kimse); Canı 80.000 Kalkanı 90.000 Kalkan Soğurması %80 Hasarı 100"; sonra "canını ve kalkanını %60 azalt" -> 32.000 / 36.000.
## Kapsam: saf hesaplar (minotaur_math.gd), hücum durum makinesi (minotaur_charge.gd, sahte yaratık/oyuncuyla - zamanlama, isabet, duvar,
## ivmelenen koşu, iptal), gerçek boss doğuşu (sabit statlar, ödül eşitliği, kademe kapısı), pozlar/kare aralıkları/ağ hızı tavanı, uyarı şeridi,
## oyuncu savrulması (hasar işlendiyse), RPC.

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const EnemyScript: GDScript = preload("res://scripts/enemy.gd")
const AbilitiesScript: GDScript = preload("res://scripts/enemy_abilities.gd")
const MathScript: GDScript = preload("res://scripts/minotaur_math.gd")
const ChargeScript: GDScript = preload("res://scripts/minotaur_charge.gd")
const DustScript: GDScript = preload("res://scripts/minotaur_dust.gd")
const BossBarArtScript: GDScript = preload("res://scripts/boss_bar_art.gd")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const MinotaurScene: PackedScene = preload("res://scenes/creatures/enemy_minotaur1.tscn")
const HaritaScene: PackedScene = preload("res://scenes/harita_baked.tscn")
const TerrainCollisionScript: GDScript = preload("res://scripts/terrain_collision.gd")
const EnemyPathingScript: GDScript = preload("res://scripts/enemy_pathing.gd")
const DT := 1.0 / 60.0
const ASSASIN := 5

var _made: Array[Node] = []
var _prev_scene: Node = null
var _prev_char_id: int = 1
var _prev_character: int = 1
var _harita: Node = null


## Hücum durum makinesinin konuştuğu yüzey (enemy.gd'nin ilgili üyeleri).
class StubEnemy extends Node2D:
	var ability_move_lock: float = 0.0
	var contact_damage: float = 100.0
	var is_dead: bool = false
	var los: bool = true
	var vfx: Array = []
	var facing: Vector2 = Vector2.ZERO

	func _has_line_of_sight(_t: Node2D) -> bool:
		return los

	func _update_facing(d: Vector2) -> void:
		facing = d

	func on_ability_vfx(kind: String, data: Dictionary) -> void:
		vfx.append([kind, data])

	func kinds() -> Array:
		return vfx.map(func(v: Array) -> String: return v[0])

	func poses() -> Array:
		var out: Array = []
		for v: Array in vfx:
			if v[0] == "minotaur_pose":
				out.append(int(v[1]["pose"]))
		return out


class StubPlayer extends Node2D:
	var is_dead: bool = false
	var is_indoors: bool = false
	var is_in_merchant_zone: bool = false
	var is_downed: bool = false
	var hits: Array = []
	var flings: Array = []

	func take_special_damage(amount: float, _source: Node2D, kind: String) -> void:
		hits.append([amount, kind])

	func apply_boss_fling(dir: Vector2, dist: float) -> void:
		flings.append([dir, dist])


class FakePlayer extends Node2D:
	var is_dead: bool = false
	var velocity: Vector2 = Vector2.ZERO


func _cleanup() -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	for c: Node in get_children():
		if is_instance_valid(c) and c.get_script() != null and str(c.get_script().resource_path).ends_with("enemy_charge_lane.gd"):
			c.free()
	GameManager.bosses_enabled = false
	GameManager.game_time = 0.0
	NetworkManager.is_multiplayer_active = false
	Input.action_release("skill")


func _add(n: Node) -> Node:
	add_child(n)
	_made.append(n)
	return n


func _scene_self() -> void:
	get_tree().current_scene = self


## Sahte yaratık + hücum makinesi + (isteğe bağlı) hedef oyuncu: boss (0,0)'da, hedef target_pos'ta.
func _rig(target_pos: Vector2, with_target: bool = true) -> Array:
	_cleanup()
	_scene_self()
	var e := StubEnemy.new()
	_add(e)
	e.global_position = Vector2.ZERO
	var mc: RefCounted = ChargeScript.new()
	mc.setup(e)
	mc._cd = 0.0
	var p: StubPlayer = null
	if with_target:
		p = StubPlayer.new()
		p.add_to_group("player")
		_add(p)
		p.global_position = target_pos
	return [e, mc, p]


## Hücum makinesini adım adım işletir; cond() true olunca ya da süre dolunca durur. Döner: geçen süre.
func _run_until(mc: RefCounted, e: StubEnemy, p: Node2D, cond: Callable, max_seconds: float) -> float:
	var t: float = 0.0
	while t < max_seconds and not bool(cond.call()):
		var d: float = e.global_position.distance_to(p.global_position) if p != null else INF
		mc.process(DT, p, d)
		t += DT
	return t


# ------------------------------------------------------------------ saf hesaplar

func test_math_mode_pick_speed_curves_and_geometry() -> void:
	assert(MathScript.pick_mode(100.0, 0.0) == MathScript.MODE_HORN, "yakın hedefte koşu seçilmez")
	assert(MathScript.pick_mode(400.0, 0.1) == MathScript.MODE_STAMPEDE, "uzak hedef + düşük zar = koşu")
	assert(MathScript.pick_mode(400.0, 0.9) == MathScript.MODE_HORN, "uzak hedef + yüksek zar = boynuz hücumu")
	assert(is_equal_approx(MathScript.horn_speed(0.0), MathScript.HORN_START_SPEED), "hücum yavaş başlar")
	assert(is_equal_approx(MathScript.horn_speed(MathScript.HORN_EASE_TIME), MathScript.HORN_SPEED) and is_equal_approx(MathScript.horn_speed(5.0), MathScript.HORN_SPEED), "sonra sabit tam hız")
	assert(MathScript.HORN_SPEED >= 252.0 * 1.5 * 1.5, "boynuz hücumu oyuncunun (252, eşyalarla ~380) çok üstünde: yetişebilir (%.0f)" % MathScript.HORN_SPEED)
	var v: float = MathScript.STAMPEDE_START_SPEED
	var steps: int = 0
	while v < MathScript.STAMPEDE_TOP_SPEED - 0.01 and steps < 1000:
		var nv: float = MathScript.stampede_speed(v, DT)
		assert(nv > v, "koşu hızı sürekli artar")
		v = nv
		steps += 1
	assert(absf(float(steps) * DT - (MathScript.STAMPEDE_TOP_SPEED - MathScript.STAMPEDE_START_SPEED) / MathScript.STAMPEDE_ACCEL) < 0.05, "tam hıza ~1,5 sn: %.2f" % (steps * DT))
	assert(MathScript.stampede_speed(MathScript.STAMPEDE_TOP_SPEED, DT) == MathScript.STAMPEDE_TOP_SPEED, "tavanı aşmaz")
	assert(MathScript.horn_length(50.0) == MathScript.HORN_MIN_LEN and MathScript.horn_length(9999.0) == MathScript.HORN_MAX_LEN and MathScript.horn_length(300.0) == 300.0 + MathScript.HORN_OVERSHOOT, "şerit uzunluğu hedefin ötesine, sınırlar içinde")
	## Dönüş sınırı: 90 derece uzaktaki hedefe tek adımda en fazla max_angle döner.
	var d: Vector2 = MathScript.turn_toward(Vector2.RIGHT, Vector2.DOWN, 0.2)
	assert(absf(d.angle() - 0.2) < 0.001, "dönüş max_angle ile sınırlı: %.3f" % d.angle())
	assert(MathScript.turn_toward(Vector2.RIGHT, Vector2.RIGHT.rotated(0.05), 0.2).is_equal_approx(Vector2.RIGHT.rotated(0.05)), "hedef yakınsa tam hizalanır")
	assert(is_equal_approx(MathScript.segment_distance(Vector2(5, 3), Vector2.ZERO, Vector2(10, 0)), 3.0), "doğru parçası içindeki nokta")
	assert(is_equal_approx(MathScript.segment_distance(Vector2(14, 3), Vector2.ZERO, Vector2(10, 0)), 5.0), "uçtan taşan nokta uç noktaya ölçülür")
	## Savrulma yönü: hücum yönüne ileri + şeridin hangi yanındaysa o yana.
	var f_left: Vector2 = MathScript.fling_direction(Vector2.RIGHT, Vector2.ZERO, Vector2(40, -20))
	var f_right: Vector2 = MathScript.fling_direction(Vector2.RIGHT, Vector2.ZERO, Vector2(40, 20))
	assert(f_left.x > 0.5 and f_left.y < -0.3, "sol yandaki yukarı savrulur: %s" % str(f_left))
	assert(f_right.x > 0.5 and f_right.y > 0.3, "sağ yandaki aşağı savrulur: %s" % str(f_right))
	assert(is_equal_approx(f_left.length(), 1.0), "birim vektör")


func test_math_clipping_never_reaches_a_blocked_cell_and_fling_speed_matches_the_distance() -> void:
	var wall: Callable = func(p: Vector2) -> bool: return p.x > 300.0
	var open: Callable = func(_p: Vector2) -> bool: return false
	assert(MathScript.clip_travel(Vector2.ZERO, Vector2.RIGHT, 500.0, open) == 500.0, "engel yoksa tam uzunluk")
	var l: float = MathScript.clip_travel(Vector2.ZERO, Vector2.RIGHT, 500.0, wall)
	assert(l > 200.0 and l + MathScript.WALL_MARGIN <= 300.0, "boss merkezi + pay duvara girmez: %.1f" % l)
	assert(MathScript.clip_travel(Vector2(400, 0), Vector2.RIGHT, 100.0, wall) == 0.0, "zaten engelin içinden/yanından başlayan hücum ilerlemez")
	var fl: float = MathScript.clip_fling_distance(Vector2.ZERO, Vector2.RIGHT, 190.0, wall)
	assert(fl == 190.0, "duvara 300 px uzaktaki oyuncu tam savrulur")
	var fl_near: float = MathScript.clip_fling_distance(Vector2(250, 0), Vector2.RIGHT, 190.0, wall)
	assert(fl_near + MathScript.FLING_WALL_MARGIN <= 50.0 + 0.001 and fl_near >= 0.0, "duvara 50 px kala savrulma kısalır: %.1f" % fl_near)
	assert(MathScript.step_blocked(Vector2(270, 0), Vector2(280, 0), wall), "adımın önü engelliyse durur")
	assert(not MathScript.step_blocked(Vector2(100, 0), Vector2(110, 0), wall), "açık adım geçer")
	## Savrulma hızı: v^2 = 2 a d  -> mesafeyi sönümle tam kat eder (player.gd KNOCKBACK_DECAY ile aynı model).
	var decay: float = 800.0
	var v: float = MathScript.fling_speed(190.0, decay)
	var travelled: float = 0.0
	while v > 0.0:
		travelled += v * DT
		v = maxf(v - decay * DT, 0.0)
	assert(absf(travelled - 190.0) < 12.0, "savrulma mesafesi: %.1f" % travelled)
	assert(MathScript.fling_speed(MathScript.FLING_DISTANCE, decay) <= 560.0, "hız tavanı (karede <= ~9,3 px) mesafeyi kısmaz")


# ------------------------------------------------------------------ hücum durum makinesi

func test_horn_charge_full_cycle_windup_lane_charge_hit_recover() -> void:
	var r: Array = _rig(Vector2(200, 0))
	var e: StubEnemy = r[0]
	var mc: RefCounted = r[1]
	var p: StubPlayer = r[2]
	mc.forced_mode = MathScript.MODE_HORN
	assert(not mc.blocks_melee(), "kovalamada temas vuruşu serbest")
	var phases: Array = []
	var lane_seen: bool = false
	var lane_len: float = 0.0
	var t: float = 0.0
	var locked_always: bool = true
	while t < 6.0:
		mc.process(DT, p, e.global_position.distance_to(p.global_position))
		t += DT
		if phases.is_empty() or phases[-1] != mc.phase:
			phases.append(mc.phase)
		if mc.phase != ChargeScript.Phase.CHASE and e.ability_move_lock <= 0.0:
			locked_always = false
		if mc.phase != ChargeScript.Phase.CHASE:
			assert(mc.blocks_melee(), "hücum/toparlanma sırasında temas vuruşu bastırılır")
		if not lane_seen:
			for c: Node in get_children():
				if c.get_script() != null and str(c.get_script().resource_path).ends_with("enemy_charge_lane.gd"):
					lane_seen = true
					lane_len = float(c.get("data")["length"])
		if phases.size() >= 4 and mc.phase == ChargeScript.Phase.CHASE:
			break
	assert(phases == [ChargeScript.Phase.WINDUP, ChargeScript.Phase.CHARGE, ChargeScript.Phase.RECOVER, ChargeScript.Phase.CHASE], "faz sırası: %s" % str(phases))
	assert(locked_always, "hücum boyunca C++ hareketi kilitli (ability_move_lock)")
	assert(lane_seen, "uyarı şeridi doğdu (dünyada duran etki)")
	assert(absf(lane_len - MathScript.horn_length(200.0)) < 0.01, "şerit uzunluğu: %.1f" % lane_len)
	assert(e.poses() == [MathScript.POSE_CROUCH, MathScript.POSE_CHARGE, MathScript.POSE_RISE, MathScript.POSE_NONE], "poz sırası (host ve istemci aynı olayı işler): %s" % str(e.poses()))
	var charge_vfx: Array = e.vfx.filter(func(v: Array) -> bool: return v[0] == "minotaur_pose" and int(v[1]["pose"]) == MathScript.POSE_CHARGE)
	assert(float(charge_vfx[0][1]["cap"]) == MathScript.NET_SPEED_CAP, "hücum pozunda istemci ağ hızı tavanı yükselir")
	var other_caps: Array = e.vfx.filter(func(v: Array) -> bool: return v[0] == "minotaur_pose" and int(v[1]["pose"]) != MathScript.POSE_CHARGE and float(v[1]["cap"]) != 0.0)
	assert(other_caps.is_empty(), "diğer pozlarda tavan sıfırlanır")
	assert(p.hits.size() == 1 and p.hits[0][0] == 100.0 and p.hits[0][1] == "minotaur", "oyuncu hücum başına BİR kez, 100 hasarla vuruldu: %s" % str(p.hits))
	assert(p.flings.size() == 1 and p.flings[0][0].x > 0.4 and absf(p.flings[0][1] - MathScript.FLING_DISTANCE) < 0.01, "ve savruldu: %s" % str(p.flings))
	assert(e.kinds().has("minotaur_impact"), "isabette toz/sarsıntı olayı")
	assert(absf(e.global_position.x - lane_len) < 12.0 and absf(e.global_position.y) < 0.01, "boss şerit boyunca (tam uzunlukta) ilerledi: %s" % str(e.global_position))
	assert(e.facing.x > 0.99, "hücum yönüne baktı")
	assert(e.ability_move_lock >= 0.0 and mc._cd >= MathScript.CD_MIN and mc._cd <= MathScript.CD_MAX, "sonraki hücum için bekleme: %.2f" % mc._cd)
	assert(not mc.blocks_melee(), "kovalamaya dönünce temas vuruşu yeniden açık")
	_cleanup()


func test_charge_only_hits_players_inside_the_lane_and_each_only_once() -> void:
	var r: Array = _rig(Vector2(220, 0))
	var e: StubEnemy = r[0]
	var mc: RefCounted = r[1]
	var inside: StubPlayer = r[2]
	mc.forced_mode = MathScript.MODE_HORN
	var beside := StubPlayer.new() ## şeridin 110 px yanında: yarı genişlik 38 + oyuncu 11 = 49'dan uzak
	beside.add_to_group("remote_players") ## damageable_players uzak oyuncuları da tarar (hasar RemotePlayer'a gider)
	_add(beside)
	beside.global_position = Vector2(150, 110)
	var downed := StubPlayer.new()
	downed.is_downed = true
	downed.add_to_group("remote_players")
	_add(downed)
	downed.global_position = Vector2(150, 0)
	_run_until(mc, e, inside, func() -> bool: return mc.phase == ChargeScript.Phase.RECOVER, 4.0)
	assert(inside.hits.size() == 1, "şeritteki oyuncu vuruldu")
	assert(beside.hits.is_empty() and beside.flings.is_empty(), "şeridin yanındaki vurulmaz")
	assert(downed.hits.is_empty(), "yerde yatan oyuncuya vurulmaz")
	assert(mc._hit_ids.size() == 1, "yalnız bir kayıt")
	_cleanup()


func test_charge_stops_before_a_wall_and_the_boss_never_enters_it() -> void:
	## Boğa koşusu: önizleme şeridi kısa, ama koşu planlanan uzunlukla sınırlı değil - duvar ancak çarpınca fark edilir. Hedef duvarın ARKASINDA (vuruş yok).
	var r: Array = _rig(Vector2(500, 0))
	var e: StubEnemy = r[0]
	var mc: RefCounted = r[1]
	var p: StubPlayer = r[2]
	mc.forced_mode = MathScript.MODE_STAMPEDE
	mc.blocked_override = func(q: Vector2) -> bool: return q.x > 300.0
	var max_x: float = 0.0
	var t: float = 0.0
	var ended_by_wall: bool = false
	while t < 12.0:
		mc.process(DT, p, e.global_position.distance_to(p.global_position))
		t += DT
		max_x = maxf(max_x, e.global_position.x)
		if mc.phase == ChargeScript.Phase.RECOVER:
			ended_by_wall = mc._recover_time == MathScript.RECOVER_WALL_TIME
			break
	assert(ended_by_wall, "duvara çarpınca uzun sersemleme (RECOVER_WALL_TIME)")
	assert(max_x + MathScript.WALL_MARGIN <= 300.0 + 0.001, "boss merkezi + pay engelin içine HİÇ girmedi: max x %.2f" % max_x)
	assert(max_x > 240.0, "ama engele kadar yaklaştı: %.2f" % max_x)
	var impacts: Array = e.vfx.filter(func(v: Array) -> bool: return v[0] == "minotaur_impact")
	assert(impacts.size() == 1 and float(impacts[0][1]["power"]) > 0.5, "duvar çarpma tozu + sarsıntı")
	_cleanup()


func test_horn_charge_into_a_wall_right_in_front_just_staggers() -> void:
	var r: Array = _rig(Vector2(200, 0))
	var e: StubEnemy = r[0]
	var mc: RefCounted = r[1]
	var p: StubPlayer = r[2]
	mc.forced_mode = MathScript.MODE_HORN
	mc.blocked_override = func(q: Vector2) -> bool: return q.x > 60.0 ## önü hemen duvar: şerit < 60 px
	_run_until(mc, e, p, func() -> bool: return mc.phase == ChargeScript.Phase.RECOVER, 3.0)
	assert(mc.phase == ChargeScript.Phase.RECOVER and mc._recover_time == MathScript.RECOVER_WALL_TIME, "atılacak yer yok: duvara vurup sersemler")
	assert(e.global_position.x <= 60.0 - MathScript.WALL_MARGIN + 0.001, "hiç ilerlemeden durdu: %s" % str(e.global_position))
	assert(p.hits.is_empty(), "duvarın arkasındaki oyuncuya vurulmaz")
	_cleanup()


func test_stampede_accelerates_gradually_turns_with_a_limited_rate_and_ends_after_a_hit() -> void:
	var r: Array = _rig(Vector2(500, 0))
	var e: StubEnemy = r[0]
	var mc: RefCounted = r[1]
	var p: StubPlayer = r[2]
	mc.forced_mode = MathScript.MODE_STAMPEDE
	_run_until(mc, e, p, func() -> bool: return mc.phase == ChargeScript.Phase.CHARGE, 3.0)
	assert(mc.mode == MathScript.MODE_STAMPEDE and mc.phase == ChargeScript.Phase.CHARGE, "uzun duruş (windup) sonrası koşuya geçti")
	var steps: Array = []
	var prev: Vector2 = e.global_position
	var max_turn: float = 0.0
	var prev_dir: Vector2 = mc._dir
	p.global_position = Vector2(900, 700) ## hedef yana kaçtı: boss en fazla dönüş hızı kadar kıvrılır
	var elapsed: float = 0.0
	while elapsed < 1.6 and mc.phase == ChargeScript.Phase.CHARGE:
		mc.process(DT, p, 1000.0)
		elapsed += DT
		steps.append(e.global_position.distance_to(prev))
		prev = e.global_position
		max_turn = maxf(max_turn, absf(wrapf(mc._dir.angle() - prev_dir.angle(), -PI, PI)))
		prev_dir = mc._dir
	assert(steps.size() > 60, "koşu en az 1 sn sürdü")
	assert(steps[5] < steps[40] and steps[40] < steps[steps.size() - 1] + 0.001, "adım boyu giderek büyür (yavaş yavaş hızlanır): %.2f < %.2f < %.2f" % [steps[5], steps[40], steps[-1]])
	assert(steps[0] < MathScript.STAMPEDE_TOP_SPEED * DT * 0.4, "yavaş başlar: %.2f px/kare" % steps[0])
	assert(max_turn <= deg_to_rad(MathScript.STAMPEDE_TURN_DEG) * DT + 0.0001, "dönüş hızı sınırlı: %.4f" % max_turn)
	assert(mc._dir.y > 0.05, "hedefe doğru kıvrıldı")
	## Birine vurunca koşu kısa süre sonra biter.
	p.global_position = e.global_position + mc._dir * 40.0
	var after: float = _run_until(mc, e, p, func() -> bool: return mc.phase == ChargeScript.Phase.RECOVER, 2.0)
	assert(p.hits.size() == 1, "koşu da vurur ve savurur: %s" % str(p.hits))
	assert(after <= MathScript.STAMPEDE_AFTER_HIT + 0.1, "vurduktan en çok %.2f sn sonra biter: %.2f" % [MathScript.STAMPEDE_AFTER_HIT, after])
	_cleanup()


func test_no_charge_without_line_of_sight_or_outside_range_and_aborts_cleanly_when_ticks_stop() -> void:
	var r: Array = _rig(Vector2(200, 0))
	var e: StubEnemy = r[0]
	var mc: RefCounted = r[1]
	var p: StubPlayer = r[2]
	e.los = false
	mc.process(DT, p, 200.0)
	assert(mc.phase == ChargeScript.Phase.CHASE and mc._cd > 0.0, "görüş yoksa hücum başlamaz, kısa süre sonra yeniden bakar")
	e.los = true
	mc._cd = 0.0
	mc.process(DT, p, MathScript.RANGE_MAX + 50.0)
	assert(mc.phase == ChargeScript.Phase.CHASE, "menzil dışında hücum yok")
	mc.process(DT, p, MathScript.RANGE_MIN - 10.0)
	assert(mc.phase == ChargeScript.Phase.CHASE, "dibindeyken hücum yok (yakın dövüş)")
	mc.process(DT, null, 200.0)
	assert(mc.phase == ChargeScript.Phase.CHASE, "hedef yoksa hücum yok")
	mc.process(DT, p, 200.0)
	assert(mc.phase == ChargeScript.Phase.WINDUP, "koşullar uygunsa windup")
	e.ability_move_lock = 0.4
	mc._last_process_msec = Time.get_ticks_msec() - 2000 ## yetenek tiki uzun süre sessiz kaldı (donma/korku)
	mc.process(DT, p, 200.0)
	assert(mc.phase == ChargeScript.Phase.CHASE, "yarım kalan hücum iptal edilir")
	assert(e.ability_move_lock == 0.0, "kilit açılır")
	assert(e.poses().back() == MathScript.POSE_NONE, "poz normale döner: %s" % str(e.poses()))
	_cleanup()


# ------------------------------------------------------------------ gerçek boss: sahne, statlar, kademe kapısı

func _spawner() -> Node:
	_cleanup()
	_scene_self()
	var sp: Node = SpawnerScript.new()
	_add(sp)
	sp.max_concurrent_enemies = 100000
	var fp := FakePlayer.new()
	fp.add_to_group("player")
	_add(fp)
	fp.global_position = Vector2(500.0, 500.0)
	return sp


func _boss_nodes() -> Array:
	var out: Array = []
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and (e.get("is_boss") == true or e.is_in_group("boss")):
			out.append(e)
	return out


func test_sheets_and_scene_follow_the_project_conventions() -> void:
	var sizes: Dictionary = {"walk": Vector2i(640, 320), "idle": Vector2i(320, 320), "attack": Vector2i(480, 320), "death": Vector2i(480, 320), "hurt": Vector2i(160, 320)}
	for k: String in sizes.keys():
		var tex: Texture2D = load("res://assets/enemies/minotaur/minotaur_%s.png" % k) as Texture2D
		assert(tex != null, "sayfa yüklenir: %s" % k)
		assert(Vector2i(tex.get_width(), tex.get_height()) == sizes[k], "%s boyutu: %s" % [k, str(Vector2i(tex.get_width(), tex.get_height()))])
		assert(tex.get_height() == 4 * 80, "4 yön satırı x 80 px hücre")
	var m: Node = MinotaurScene.instantiate()
	add_child(m)
	_made.append(m)
	assert(m.cell_size == 80, "hücre boyu 80")
	assert(m.walk_texture != null and m.idle_texture != null and m.attack_texture != null and m.death_texture != null and m.hurt_texture != null, "tüm doku alanları dolu")
	assert(m.frame_sprite != null and m.frame_sprite.hframes == 8 and m.frame_sprite.vframes == 4, "yürüme sayfası 8x4")
	assert(EnemyScript.family_of_id("minotaur1") == "minotaur" and AbilitiesScript.family_has_ability("minotaur"), "aile 'minotaur', yeteneği var")
	assert(SpawnerScript.SCENES.has("minotaur1") and SpawnerScript.ID_FAMILY["minotaur1"] == "minotaur", "doğuş tablolarında kayıtlı")
	assert(BossBarArtScript.display_name("minotaur1") == "MİNOTAUR", "üst boss barında adı: %s" % BossBarArtScript.display_name("minotaur1"))
	assert(not SpawnerScript.ELITE_POOL.has("minotaur1"), "boss elit havuzunda değil")
	for tier: int in SpawnerScript.TIER_ROSTER.keys():
		assert(not SpawnerScript.TIER_ROSTER[tier].has("minotaur1"), "sıradan doğuşta çıkmaz")
	_cleanup()


func test_boss_has_exactly_the_requested_stats_in_single_player_and_scales_with_players_like_other_creatures() -> void:
	var sp: Node = _spawner()
	var spawned: Array = sp._spawn_boss_group(["minotaur1"], 3)
	assert(spawned.size() == 1, "boss doğdu")
	var b: Node = spawned[0]
	assert(b.is_boss and b.is_in_group("boss"), "boss grubunda")
	assert(b.max_health == 32000.0 and b.health == 32000.0, "can 32.000: %.1f" % b.max_health)
	assert(b.item_shield_max == 36000.0 and b.item_shield_hp == 36000.0, "kalkan 36.000: %.1f" % b.item_shield_max)
	assert(is_equal_approx(b.shield_protection, 0.8), "kalkan soğurması yüzde 80: %.2f" % b.shield_protection)
	assert(b.contact_damage == 100.0, "hasar 100: %.1f" % b.contact_damage)
	assert(b._current_tier == 3, "Kademe 3 bossu")
	## Boyut: sahne 1,6 x global küçültme x boss ek küçültmesi (eski boyutun %80'i) x boss 1,7
	assert(absf(b.frame_sprite.scale.x - 1.6 * EntityScale.SIZE * EntityScale.BOSS_EXTRA * 1.7) < 0.001, "boss boyutu: %.3f" % b.frame_sprite.scale.x)
	## Çok oyunculu: TÜM yaratıklarla aynı kural, ekstra oyuncu başına can/kalkan +%50 (3 oyuncu = x2); hasar büyümez.
	var c: Node = sp._spawn_creature("minotaur1", Vector2(900, 900), 999002)
	c.add_to_group("boss")
	sp._setup_boss_enemy(c, "minotaur1", 3, 3)
	assert(absf(c.max_health - 64000.0) < 0.5 and absf(c.item_shield_max - 72000.0) < 0.5, "3 oyuncuda can/kalkan x2: %.0f / %.0f" % [c.max_health, c.item_shield_max])
	assert(c.contact_damage == 100.0 and is_equal_approx(c.shield_protection, 0.8), "hasar ve soğurma oyuncu sayısıyla değişmez")
	## Ödül, Kademe 3'ün referans bossuyla (iskelet3) aynı - boss canına göre şişmez.
	var ref: Node = sp._spawn_creature("iskelet3", Vector2(1000, 1000), 999003)
	ref.add_to_group("boss")
	sp._setup_boss_enemy(ref, "iskelet3", 3, 1)
	assert(b.xp_value == ref.xp_value and b.gold_min == ref.gold_min and b.gold_max == ref.gold_max and b.gold_chance == 1.0, "ödül referansla aynı: xp %s/%s altın %d-%d / %d-%d" % [b.xp_value, ref.xp_value, b.gold_min, b.gold_max, ref.gold_min, ref.gold_max])
	assert(b.xp_value > 0.0 and b.xp_value < 1000.0, "ödül makul: %s" % b.xp_value)
	_cleanup()


func test_shield_absorbs_80_percent_of_every_hit_until_it_breaks() -> void:
	var sp: Node = _spawner()
	var b: Node = sp._spawn_boss_group(["minotaur1"], 3)[0]
	b._apply_damage(1000.0, false, 0.0)
	assert(absf(b.item_shield_hp - (36000.0 - 800.0)) < 0.5, "vuruşun yüzde 80'i kalkana: %.1f" % b.item_shield_hp)
	assert(absf(b.health - (32000.0 - 200.0)) < 0.5, "yüzde 20'si cana: %.1f" % b.health)
	## Kalkan bitince tüm hasar cana gider.
	b.item_shield_hp = 0.0
	var before: float = b.health
	b._apply_damage(1000.0, false, 0.0)
	assert(absf(before - b.health - 1000.0) < 0.5, "kalkan yokken tam hasar: %.1f" % (before - b.health))
	_cleanup()


func test_the_tier_3_boss_spawns_on_time_holds_the_tier_clock_and_no_other_tier_has_a_boss() -> void:
	var sp: Node = _spawner()
	GameManager.bosses_enabled = false
	assert(SpawnerScript.NEW_BOSS_TIERS[3] == ["minotaur1"], "yeni boss tablosu: Kademe 3 = Minotaur")
	assert(sp._active_boss_tiers() == SpawnerScript.NEW_BOSS_TIERS, "bosses_enabled kapalıyken sadece yeni bosslar")
	GameManager.game_time = 270.0 ## tetik (2 x 100 + 100 x 0,75 = 275 sn) öncesi
	sp._check_boss_tiers()
	assert(_boss_nodes().is_empty(), "tetikten önce boss yok")
	GameManager.game_time = 280.0
	sp._check_boss_tiers()
	var bosses: Array = _boss_nodes()
	assert(bosses.size() == 1 and str(bosses[0].get_meta("creature_id", "")) == "minotaur1", "Kademe 3'te tek boss: Minotaur: %s" % str(bosses))
	assert(sp._boss_tiers_spawned.has(3) and sp._tier_bosses.has(3), "kayıtlı")
	sp._check_boss_tiers()
	assert(_boss_nodes().size() == 1, "ikinci kez doğmaz")
	## Boss sağken Kademe saati kademe sonunda (300 sn) durur; ölünce devam eder.
	GameManager.game_time = 350.0
	assert(sp._tier_time() < 300.0 and sp._tier_time() > 299.9 and sp.is_tier_held_by_boss(), "Kademe 4 boss ölmeden açılmaz: %.3f" % sp._tier_time())
	bosses[0].set("is_dead", true)
	GameManager.game_time = 360.0
	assert(sp._tier_time() > 305.0 and not sp.is_tier_held_by_boss(), "boss ölünce kademe saati devam eder: %.3f" % sp._tier_time())
	## Diğer boss kademelerinde (6/8/12/15) ve Final'de hâlâ boss yok (zaman atlandığı için Kademe 5'in Yeraltı Canavarı da tetik zamanını geçmiş sayılır).
	for time in [590.0, 790.0, 1190.0, 1490.0]:
		GameManager.game_time = time
		sp._check_boss_tiers()
	for b: Node in _boss_nodes():
		assert(["minotaur1", "underground1"].has(str(b.get_meta("creature_id", ""))), "yeni bosslar dışında boss doğmadı: %s" % str(b.get_meta("creature_id", "")))
	assert(_boss_nodes().size() <= 2, "Kademe 3 + 5 dışında boss yok")
	## Eski tablo (bosses_enabled açıkken) değişmedi.
	GameManager.bosses_enabled = true
	assert(sp._active_boss_tiers() == SpawnerScript.BOSS_TIERS, "bosses_enabled açıkken eski bosslar")
	_cleanup()


func test_debug_menu_spawns_the_minotaur_as_a_real_boss() -> void:
	var sp: Node = _spawner()
	assert(sp.get_debug_creature_ids().has("minotaur1"), "debug yaratık listesinde")
	assert(sp.debug_spawn_creature("minotaur1", 3, 1, Vector2(500.0, 500.0)) == 1, "debug doğuşu")
	var bosses: Array = _boss_nodes()
	assert(bosses.size() == 1 and bosses[0].is_boss and bosses[0].max_health == 32000.0 and bosses[0].item_shield_max == 36000.0, "gerçek boss statlarıyla doğar: %s" % str(bosses))
	assert(bosses[0].get_node_or_null("EliteStar") == null, "elit değil")
	_cleanup()


func test_a_boss_that_failed_to_spawn_is_retried() -> void:
	var sp: Node = _spawner()
	for p: Node in get_tree().get_nodes_in_group("player"):
		p.remove_from_group("player") ## canlı oyuncu çapası yok: _spawn_boss_group boş döner
	GameManager.game_time = 280.0
	sp._check_boss_tiers()
	assert(_boss_nodes().is_empty() and not sp._boss_tiers_spawned.has(3), "doğmadıysa 'doğdu' sayılmaz")
	for p: Node in _made:
		if p is FakePlayer:
			p.add_to_group("player")
	sp._check_boss_tiers()
	assert(_boss_nodes().size() == 1, "çapa gelince boss doğar")
	_cleanup()


func test_real_boss_creates_the_charge_ability_and_blocks_contact_hits_only_while_charging() -> void:
	var sp: Node = _spawner()
	var b: Node = sp._spawn_boss_group(["minotaur1"], 3)[0]
	b._init_abilities()
	assert(b._abilities != null and b._abilities._minotaur != null, "yetenek nesnesi kuruldu")
	assert(not b._abilities.melee_blocked(), "kovalamada temas vuruşu açık")
	b._abilities._minotaur.phase = ChargeScript.Phase.CHARGE
	assert(b._abilities.melee_blocked(), "hücumda temas vuruşu kapalı")
	b._ew_on_event(EnemyScript.EW_E_MELEE, get_tree().get_first_node_in_group("player") as Node2D)
	assert(b._state != EnemyScript.State.ATTACK, "bastırılan temas olayı saldırı animasyonuna girmedi")
	_cleanup()


# ------------------------------------------------------------------ pozlar / kareler / ağ hızı / toz

func _advance(b: Node, seconds: float) -> Array:
	var cols: Array = []
	var t: float = 0.0
	while t < seconds:
		b._advance_frame_sprite(DT)
		cols.append(b.frame_sprite.frame % b.frame_sprite.hframes)
		t += DT
	return cols


func test_poses_play_the_right_attack_sheet_frames_and_return_to_walking() -> void:
	_cleanup()
	_scene_self()
	var b: Node = MinotaurScene.instantiate()
	_add(b)
	b._apply_minotaur_pose(MathScript.POSE_CROUCH, 0.0)
	assert(b._state == EnemyScript.State.ATTACK and b._state_duration == 0.0 and b.frame_sprite.hframes == 6, "poz = saldırı sayfası, süresiz")
	var crouch: Array = _advance(b, 1.2)
	assert(crouch.all(func(c: int) -> bool: return c == 1 or c == 2) and crouch.has(1) and crouch.has(2), "eğilme: kare 1-2 arası kazıma: %s" % str(crouch.slice(0, 12)))
	b._apply_minotaur_pose(MathScript.POSE_CHARGE, MathScript.NET_SPEED_CAP)
	var charge: Array = _advance(b, 1.0)
	assert(charge.all(func(c: int) -> bool: return c >= 0 and c <= 2) and charge.has(0) and charge.has(1) and charge.has(2), "hücum: kare 0-2 döngü: %s" % str(charge.slice(0, 12)))
	assert(b._net_speed_cap_override == MathScript.NET_SPEED_CAP, "ağ hızı tavanı yükseldi")
	b._apply_minotaur_pose(MathScript.POSE_RISE, 0.0)
	var rise: Array = _advance(b, 2.0)
	assert(rise[0] == 3 and rise[-1] == 5 and rise.all(func(c: int) -> bool: return c >= 3 and c <= 5), "doğrulma: 3 -> 5, son karede kalır: %s" % str(rise.slice(0, 6)))
	assert(b._net_speed_cap_override == 0.0, "tavan sıfırlandı")
	b._apply_minotaur_pose(MathScript.POSE_NONE, 0.0)
	assert(b._state == EnemyScript.State.WALK and b.frame_sprite.hframes == 8, "poz bitince yürümeye döner")
	assert(b.get_node_or_null("MinotaurDust") != null, "toz izi kuruldu")
	_cleanup()


func test_an_interrupted_charge_pose_is_ignored_once_dead_and_dust_follows_the_charge_pose() -> void:
	_cleanup()
	_scene_self()
	var b: Node = MinotaurScene.instantiate()
	_add(b)
	b._apply_minotaur_pose(MathScript.POSE_CHARGE, MathScript.NET_SPEED_CAP)
	await get_tree().process_frame
	await get_tree().process_frame
	var dust: Node = b.get_node("MinotaurDust")
	assert(dust._trail.emitting, "hücum pozunda toz çıkar")
	b._apply_minotaur_pose(MathScript.POSE_RISE, 0.0)
	await get_tree().process_frame
	assert(not dust._trail.emitting, "poz bitince toz kesilir")
	b._apply_minotaur_pose(MathScript.POSE_CHARGE, MathScript.NET_SPEED_CAP)
	b.is_dead = true
	await get_tree().process_frame
	assert(not dust._trail.emitting, "ölü boss toz bırakmaz")
	var state_before: int = b._state
	b._apply_minotaur_pose(MathScript.POSE_CROUCH, 0.0)
	assert(b._state == state_before, "ölü boss poza girmez")
	DustScript.burst(get_tree(), Vector2(10, 10), Vector2.UP, 0.4) ## başsızda sadece sarsıntı: hata vermemeli
	_cleanup()


func test_client_puppet_velocity_cap_lets_the_charge_through() -> void:
	_cleanup()
	_scene_self()
	var b: Node = MinotaurScene.instantiate()
	_add(b)
	b._ew_unregister() ## C++ kuklasının zamanı yerine test zamanı kullanılsın (update_network_state _ew_slot'a bakar)
	b.global_position = Vector2.ZERO
	b.update_network_state(Vector2.ZERO)
	b._network_time_since_update = 0.15
	b.update_network_state(Vector2(100.0, 0.0)) ## 666 px/sn
	var capped: float = b._network_velocity.length()
	assert(capped < 400.0 and absf(capped - maxf(b.speed, 40.0) * 3.5) < 0.5, "tavansız hız yürüme sınırında kalır: %.1f" % capped)
	b._net_speed_cap_override = MathScript.NET_SPEED_CAP
	b._network_time_since_update = 0.15
	b.update_network_state(Vector2(200.0, 0.0))
	assert(absf(b._network_velocity.length() - 100.0 / 0.15) < 1.0, "hücum tavanıyla gerçek hız korunur: %.1f" % b._network_velocity.length())
	_cleanup()


# ------------------------------------------------------------------ uyarı şeridi

func test_warning_lane_matches_the_data_and_frees_itself() -> void:
	_cleanup()
	_scene_self()
	var data: Dictionary = {"dir": Vector2(0, 1), "length": 300.0, "width": 76.0, "warn": 0.55}
	var lane: Node2D = AbilitiesScript.spawn_world_fx(get_tree(), "charge_lane", Vector2(100, 100), data, true)
	assert(lane != null, "şerit doğdu")
	_made.append(lane)
	assert(absf(lane.rotation - PI * 0.5) < 0.001, "yön: aşağı")
	var spr: Sprite2D = lane.get_child(0) as Sprite2D
	assert(absf(spr.region_rect.size.x - 150.0) < 0.5 and spr.region_rect.size.y == 38.0 and spr.scale == Vector2(2, 2), "300 x 76 dünya birimi = 150 x 38 doku pikseli x2")
	assert(spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "piksel-art süzme")
	lane._process(0.3)
	assert(spr.modulate.a > 0.2, "uyarı görünür: %.2f" % spr.modulate.a)
	lane._process(0.5)
	lane._process(0.3)
	assert(lane.is_queued_for_deletion(), "süre bitince kendini siler")
	var lane2: Node2D = AbilitiesScript.spawn_world_fx(get_tree(), "charge_lane", Vector2.ZERO, {"dir": Vector2.ZERO, "length": 0.0, "width": 0.0}, false)
	assert(lane2 != null, "bozuk veriyle de çökmez (yön/uzunluk/genişlik düzeltilir)")
	_made.append(lane2)
	_cleanup()


# ------------------------------------------------------------------ oyuncu savrulması (gerçek Player)

func _make_player() -> Node:
	_cleanup()
	_prev_scene = get_tree().current_scene
	get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = ASSASIN
	GameManager.selected_character = int(Characters.DEFS[ASSASIN]["skill"])
	NetworkManager.is_multiplayer_active = false
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_made.append(p)
	p.global_position = Vector2(1000.0, 1000.0)
	p.max_health = 5000.0 ## 100 hasarlık vuruş oyuncuyu öldürmesin (öldürürse savrulma da yok, ayrı kural)
	p.health = 5000.0
	p.item_shield_max = 1000.0
	p.item_shield_hp = 1000.0
	return p


func _restore_player_env() -> void:
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	if _prev_scene != null and is_instance_valid(_prev_scene) and _prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = _prev_scene


func test_real_player_is_flung_only_when_the_hit_actually_landed() -> void:
	var p: Node = _make_player()
	var dir: Vector2 = Vector2(1.0, 0.5).normalized()
	## Hasar işlenmeden savrulma yok (kaçınan/dokunulmaz oyuncu savrulmaz).
	p.apply_boss_fling(dir, 190.0)
	assert(p._knockback_velocity == Vector2.ZERO, "hasarsız savrulma yok")
	p._item_invuln_timer = 2.0 ## Zaman Kıran: hasar işlenmez
	p.take_special_damage(100.0, null, "minotaur")
	p.apply_boss_fling(dir, 190.0)
	assert(p._knockback_velocity == Vector2.ZERO, "dokunulmazken savrulmaz")
	p._item_invuln_timer = 0.0
	## Hasar işlendi -> savrulma: hız, mesafeyi tam 190 px yapacak şekilde ve yönde.
	var before: float = p.health + p.item_shield_hp
	p.take_special_damage(100.0, null, "minotaur")
	assert(p.health + p.item_shield_hp < before, "hasar işlendi")
	p.apply_boss_fling(dir, 190.0)
	var kv: Vector2 = p._knockback_velocity
	assert(kv.normalized().is_equal_approx(dir), "savrulma yönü: %s" % str(kv))
	assert(absf(kv.length() - MathScript.fling_speed(190.0, p.KNOCKBACK_DECAY)) < 0.5 and kv.length() <= p.BOSS_FLING_MAX_SPEED, "hız mesafeye göre: %.1f" % kv.length())
	## Aynı vuruş için ikinci savrulma yok (damga tüketildi).
	p._knockback_velocity = Vector2.ZERO
	p.apply_boss_fling(dir, 190.0)
	assert(p._knockback_velocity == Vector2.ZERO, "damga tek kullanımlık")
	## Gerçekten ilerler: birkaç fizik karesi sonra konum dir yönünde kaydı ve savrulma bitince durur.
	p._last_damage_taken_at_msec = -100000 ## temas kilidi (iframe) sıfırlansın: yoksa ikinci vuruş işlenmez ve savrulma da olmaz (doğru davranış)
	p.take_special_damage(100.0, null, "minotaur")
	var start: Vector2 = p.global_position
	p.apply_boss_fling(dir, 190.0)
	for i in range(60):
		await get_tree().physics_frame
	var moved: Vector2 = p.global_position - start
	assert(moved.length() > 120.0 and moved.length() < 215.0 and moved.normalized().dot(dir) > 0.98, "oyuncu savruldu: %s (%.1f px)" % [str(moved), moved.length()])
	p.free()
	_made.erase(p)
	_restore_player_env()
	_cleanup()


func test_rpc_delivers_the_fling_to_the_local_player_in_single_player() -> void:
	_cleanup()
	_scene_self()
	var sp := StubPlayer.new()
	sp.add_to_group("player")
	_add(sp)
	NetworkManager.forward_player_fling_to_peer(Vector2.RIGHT, 190.0)
	assert(sp.flings.size() == 1 and sp.flings[0][0] == Vector2.RIGHT and sp.flings[0][1] == 190.0, "RPC yerel oyuncuya savrulmayı iletir: %s" % str(sp.flings))
	_cleanup()


# ------------------------------------------------------------------ GERÇEK HARİTA: duvara/engele yakın savrulma ve hücum

func _load_map() -> void:
	_harita = HaritaScene.instantiate()
	_harita.name = "Harita"
	(_harita as Node2D).position = Vector2(-2.0, 21.0) ## gerçek oyundaki konum (main.tscn)
	add_child(_harita)
	GameManager._terrain_su_layer = _harita.get_node("Su/Su")
	GameManager._terrain_ev_layer = _harita.get_node("ev/Ev")
	var forest: TileMapLayer = _harita.get_node("Orman parçaları/Orman parçaları")
	GameManager._terrain_forest_layer = forest
	GameManager._terrain_layers_searched = true
	TerrainCollisionScript.reset()
	EnemyPathingScript.reset()
	TerrainCollisionScript.ensure(forest)


func _unload_map() -> void:
	if is_instance_valid(_harita):
		_harita.free()
	_harita = null
	GameManager._terrain_su_layer = null
	GameManager._terrain_ev_layer = null
	GameManager._terrain_forest_layer = null
	GameManager._terrain_layers_searched = false
	GameManager._map_world_rect_searched = false ## harita sınırı önbelleği (get_map_world_rect) bu haritayla kalmasın
	TerrainCollisionScript.reset()
	EnemyPathingScript.reset()


## Gerçek haritada: dir yönünde 50-110 px ileride ilk engel hücresi olan, arkası ve yolu temiz bir nokta. [nokta, engele_uzaklık] ya da null.
func _find_wall_spot(dir: Vector2) -> Variant:
	var rect: Rect2 = GameManager.get_map_world_rect()
	var x: float = rect.position.x + 200.0
	while x < rect.end.x - 200.0:
		var y: float = rect.position.y + 200.0
		while y < rect.end.y - 200.0:
			var p := Vector2(x, y)
			if not GameManager.is_position_blocked_by_walls(p):
				var open_run: float = 0.0
				var d: float = 6.0
				var found: float = -1.0
				while d <= 110.0:
					if GameManager.is_position_blocked_by_walls(p + dir * d):
						found = d
						break
					d += 6.0
				if found >= 50.0 and not GameManager.is_position_blocked_by_walls(p - dir * 60.0):
					return [p, found]
			y += 24.0
		x += 24.0
	return null


func test_on_the_real_map_a_flung_player_stops_before_the_wall_and_never_enters_it() -> void:
	var p: Node = _make_player()
	_load_map()
	var found: Variant = _find_wall_spot(Vector2.RIGHT)
	assert(found != null, "gerçek haritada duvar kenarı bulundu")
	var spot: Vector2 = found[0]
	var wall_dist: float = found[1]
	p.global_position = spot
	p.take_special_damage(100.0, null, "minotaur")
	p.apply_boss_fling(Vector2.RIGHT, 190.0)
	var kv: float = p._knockback_velocity.length()
	assert(kv > 0.0 and kv < MathScript.fling_speed(190.0, p.KNOCKBACK_DECAY) - 1.0, "mesafe duvara göre kısaltıldı: %.1f (duvar %.0f px ileride)" % [kv, wall_dist])
	var worst: bool = false
	for i in range(90):
		await get_tree().physics_frame
		if GameManager.is_position_blocked_by_walls(p.global_position):
			worst = true
	assert(not worst, "savrulan oyuncu HİÇBİR karede engel hücresine girmedi")
	assert(p.global_position.x - spot.x < wall_dist + 0.01, "duvara ulaşmadı: %.1f px gitti, duvar %.0f px ileride" % [p.global_position.x - spot.x, wall_dist])
	p.free()
	_made.erase(p)
	_unload_map()
	_restore_player_env()
	_cleanup()


func test_on_the_real_map_the_boss_charge_is_clipped_by_the_wall_and_never_enters_it() -> void:
	_cleanup()
	_scene_self()
	_load_map()
	var found: Variant = _find_wall_spot(Vector2.RIGHT)
	assert(found != null, "gerçek haritada duvar kenarı bulundu")
	var spot: Vector2 = found[0]
	var wall_dist: float = found[1]
	var e := StubEnemy.new()
	_add(e)
	e.global_position = spot
	var mc: RefCounted = ChargeScript.new()
	mc.setup(e)
	mc._cd = 0.0
	mc.forced_mode = MathScript.MODE_STAMPEDE ## koşu: duvarı ancak çarpınca fark eder (şerit sadece önizleme)
	var target := StubPlayer.new()
	target.add_to_group("player")
	_add(target)
	target.global_position = spot + Vector2(300.0, 0.0) ## duvarın ötesinde
	var inside: bool = false
	var t: float = 0.0
	while t < 8.0:
		mc.process(DT, target, e.global_position.distance_to(target.global_position))
		t += DT
		if GameManager.is_position_blocked_by_walls(e.global_position):
			inside = true
		if mc.phase == ChargeScript.Phase.RECOVER:
			break
	assert(not inside, "boss düğümü hücum boyunca engel hücresine girmedi")
	assert(mc.phase == ChargeScript.Phase.RECOVER and mc._recover_time == MathScript.RECOVER_WALL_TIME, "duvara çarpıp sersemledi")
	assert(e.global_position.x - spot.x < wall_dist, "duvara ulaşmadı: %.1f px, duvar %.0f px ileride" % [e.global_position.x - spot.x, wall_dist])
	_unload_map()
	_cleanup()
