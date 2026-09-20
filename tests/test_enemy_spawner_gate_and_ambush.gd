extends Node

## Kullanıcı isteği (2026-09-20):
##  1) "Kademe ilerlemelerinde öldüremediğim yaratıkların yerini yeni kademe yaratıklar alıyor, eskilerini
##     öldürmeden yeni kademedekilerin gelememesi lazım" -> Kademe kapısı (enemy_spawner.gd _resolve_spawn_tier).
##  2) "bossların canını ve kalkanını %20 düşür (şuanki değerlerini direkt %20 azalt)".
##  3) "Tüm yaratıkların canını ve kalkanını %10 azalt ancak tekrar spawnlanma hızlarını arttır ve davranışsal
##     olarak gittiğim yönlerdeki duvarların arkasında hızlı hızlı çok sayıda spawnlanıp önünü kesmeye
##     çalışsınlar" -> SPAWN_RATE_MULT ve duvar-arkası pusu paketleri.

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const PathingScript: GDScript = preload("res://scripts/enemy_pathing.gd")
const WallLayerFactory: GDScript = preload("res://tests/wall_layer_factory.gd")
const RatScene: PackedScene = preload("res://scenes/creatures/enemy_rat1.tscn")

## Değişiklikten ÖNCEKİ değerler (oranları doğrulamak için).
const OLD_BOSS_HEALTH_MULT := 158.4
const OLD_HEALTH_SHIELD_MULT := 2.64
const TIER_SECONDS := 100.0


class FakePlayer extends Node2D:
	var is_dead: bool = false
	var velocity: Vector2 = Vector2.ZERO


## Kademe kapısını tutan/tutmayan "sağ kalan" yaratığı taklit eder (sadece is_dead + meta okunuyor).
class FakeEnemy extends Node2D:
	var is_dead: bool = false


var _made: Array[Node] = []


func _track(n: Node) -> Node:
	_made.append(n)
	return n


func _spawner() -> Node:
	## Önceki (başarısız olmuş olabilecek) testten kalan yaratık/oyuncu bu testi kirletmesin.
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	GameManager.game_time = 0.0
	var sp: Node = SpawnerScript.new()
	add_child(sp)
	sp.max_concurrent_enemies = 100000 ## kapasite testlerin konusu değil
	get_tree().current_scene = self ## _spawn_creature current_scene'e ekliyor
	return _track(sp)


func _player(pos: Vector2, vel: Vector2 = Vector2.ZERO) -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = pos
	p.velocity = vel
	return _track(p) as FakePlayer


func _survivor(spawn_tier: int) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	e.set_meta("spawn_tier", spawn_tier)
	add_child(e)
	return _track(e) as FakeEnemy


func _real_enemies() -> Array[Node]:
	var out: Array[Node] = []
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not (e is FakeEnemy):
			out.append(e)
	return out


func _cleanup() -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	GameManager.game_time = 0.0
	GameManager._terrain_forest_layer = null
	GameManager._terrain_layers_searched = false
	PathingScript.reset()
	PathingScript.set_enabled(true)
	NetworkManager.is_multiplayer_active = false


## ---------------------------------------------------------------- 1) kademe kapısı
func test_new_tier_waits_until_older_tier_survivors_are_dead() -> void:
	var sp: Node = _spawner()
	_player(Vector2(500.0, 500.0))
	GameManager.game_time = TIER_SECONDS * 2.0 + 5.0 ## zaman kademesi 3
	assert(sp._current_tier() == 3, "test kurulumu: zaman kademesi 3 olmalı")
	sp._spawn_tier = 1 ## oyun 1. kademede spawn ediyordu
	var alive_old: FakeEnemy = _survivor(1)
	var alive_old2: FakeEnemy = _survivor(2)

	for _i in range(30):
		sp._spawn_regular_enemy()
	assert(_real_enemies().is_empty(), "Eski kademeden sağ kalan varken YENİ kademe yaratığı doğmamalı (doğan: %d)" % _real_enemies().size())
	assert(sp._spawn_tier == 1, "Kapı kapalıyken spawn kademesi ilerlememeli (bulunan: %d)" % sp._spawn_tier)
	assert(sp.is_tier_gate_waiting(), "Kapı 'bekliyor' durumunda olmalı")

	alive_old.is_dead = true
	for _i in range(10):
		sp._spawn_regular_enemy()
	assert(_real_enemies().is_empty(), "Hâlâ bir eski yaratık sağ (2. kademe) - kapı açılmamalı")

	alive_old2.is_dead = true
	sp._spawn_regular_enemy()
	assert(sp._spawn_tier == 3, "Son eski yaratık ölünce spawn kademesi zaman kademesine yetişmeli (bulunan: %d)" % sp._spawn_tier)
	assert(not _real_enemies().is_empty(), "Kapı açılınca yeni kademenin yaratıkları doğmalı")
	for e: Node in _real_enemies():
		assert(int(e.get_meta("spawn_tier", 0)) == 3, "Yeni doğanlar 3. kademeden olmalı")
		assert(sp.TIER_ROSTER[3].has(str(e.get_meta("creature_id", ""))), "3. kademe listesinden bir yaratık olmalı: %s" % str(e.get_meta("creature_id", "")))
	assert(not sp.is_tier_gate_waiting(), "Kapı artık beklemiyor olmalı")
	_cleanup()


## Aynı kademedeyken (kapı hiç devreye girmez) normal spawn aynen sürer.
func test_no_gate_within_the_same_tier() -> void:
	var sp: Node = _spawner()
	_player(Vector2(500.0, 500.0))
	GameManager.game_time = 10.0
	_survivor(1)
	for _i in range(5):
		sp._spawn_regular_enemy()
	assert(_real_enemies().size() >= 5, "Aynı kademede sağ kalan yaratık spawn'ı engellememeli (doğan: %d)" % _real_enemies().size())
	_cleanup()


## Sağ kalan bir BOSS kapıyı tutmamalı (bosslar kendi zaman tetikleyicisiyle gelir); meta'sız yaratıklar da saymaz.
func test_bosses_and_unmarked_creatures_do_not_hold_the_gate() -> void:
	var sp: Node = _spawner()
	_player(Vector2(500.0, 500.0))
	GameManager.game_time = TIER_SECONDS + 5.0 ## zaman kademesi 2
	sp._spawn_tier = 1
	var boss: FakeEnemy = _survivor(1)
	boss.add_to_group("boss")
	var unmarked := FakeEnemy.new()
	unmarked.add_to_group("enemies")
	add_child(unmarked)
	_track(unmarked)
	sp._spawn_regular_enemy()
	assert(sp._spawn_tier == 2, "Boss / meta'sız yaratık kapıyı tutmamalı (spawn kademesi: %d)" % sp._spawn_tier)
	_cleanup()


## ---------------------------------------------------------------- 2) boss -%20, normal -%10
func test_boss_health_and_shield_are_exactly_twenty_percent_lower() -> void:
	assert(is_equal_approx(SpawnerScript.BOSS_HEALTH_MULT, OLD_BOSS_HEALTH_MULT * 0.8),
		"BOSS_HEALTH_MULT eskisinin %%80'i olmalı: %s" % SpawnerScript.BOSS_HEALTH_MULT)
	assert(is_equal_approx(SpawnerScript.BOSS_SHIELD_RATIO, 1.3),
		"BOSS_SHIELD_RATIO değişmemeli (kalkan candan türetilir, ikisini birden düşürmek %%36 yapardı)")
	assert(is_equal_approx(SpawnerScript.BOSS_HEALTH_SHIELD_MULT, OLD_HEALTH_SHIELD_MULT),
		"Bosslar 'tüm yaratıklar %%10' azaltmasına dahil olmamalı (bosslar tam %%20 iner)")

	var sp: Node = _spawner()
	_player(Vector2(500.0, 500.0))
	sp._spawn_boss_group(["iskelet3"], 3)
	var boss: Node = null
	for e: Node in get_tree().get_nodes_in_group("boss"):
		boss = e
	assert(boss != null, "boss doğmalı")
	var family: String = SpawnerScript.ID_FAMILY.get("iskelet3", "")
	var mult: Dictionary = SpawnerScript.FAMILY_MULT.get(family, {"hp": 1.0, "dmg": 1.0})
	var raw: float = (10.0 + 3.0 * 9.0) * float(mult["hp"])
	var expected_old_health: float = raw * OLD_BOSS_HEALTH_MULT * SpawnerScript.GLOBAL_DEFENSE_BUFF * OLD_HEALTH_SHIELD_MULT
	assert(absf(float(boss.max_health) - expected_old_health * 0.8) < 0.01,
		"Boss canı eski değerin TAM %%80'i olmalı: %s (eski %s)" % [boss.max_health, expected_old_health])
	assert(absf(float(boss.item_shield_max) - expected_old_health * SpawnerScript.BOSS_SHIELD_RATIO * 0.8) < 0.01,
		"Boss kalkanı eski değerin TAM %%80'i olmalı: %s" % boss.item_shield_max)
	assert(absf(float(boss.item_shield_max) / float(boss.max_health) - 1.3) < 0.001, "Boss kalkan/can oranı 1.3 olarak kalmalı")
	_cleanup()


func test_regular_creature_health_and_shield_are_ten_percent_lower() -> void:
	assert(is_equal_approx(SpawnerScript.HEALTH_SHIELD_MULT, OLD_HEALTH_SHIELD_MULT * 0.9),
		"Normal yaratık çarpanı eskisinin %%90'ı olmalı: %s" % SpawnerScript.HEALTH_SHIELD_MULT)
	var sp: Node = _spawner()
	var enemy: Node = RatScene.instantiate()
	add_child(enemy)
	_track(enemy)
	enemy.max_health = 100.0
	enemy.item_shield_max = 100.0
	enemy.item_shield_hp = 100.0
	sp._apply_global_buff(enemy)
	var old_health: float = 100.0 * SpawnerScript.GLOBAL_DEFENSE_BUFF * OLD_HEALTH_SHIELD_MULT
	assert(absf(float(enemy.max_health) - old_health * 0.9) < 0.01, "Normal yaratığın canı eskisinin %%90'ı olmalı: %s (eski %s)" % [enemy.max_health, old_health])
	assert(absf(float(enemy.item_shield_max) - old_health * 0.9) < 0.01, "Normal yaratığın kalkanı eskisinin %%90'ı olmalı: %s" % enemy.item_shield_max)
	_cleanup()


## ---------------------------------------------------------------- 3) spawn hızı
func test_spawn_interval_is_one_and_a_half_times_faster() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 0.0
	assert(absf(sp._current_interval() - (sp.base_interval / 1.5)) < 0.0001,
		"Başta aralık eskisinin 1/1.5'i olmalı: %s" % sp._current_interval())
	GameManager.game_time = 1000.0 ## tavan (min_interval) bölgesi
	assert(absf(sp._current_interval() - (sp.min_interval / 1.5)) < 0.0001,
		"Geç oyunda aralık min_interval/1.5 olmalı: %s" % sp._current_interval())
	_cleanup()


## ---------------------------------------------------------------- 4) duvar-arkası pusu
## x=40..41 sütunu (dünya x~640) yüksek bir duvar: oyuncu solda (400,300), sağa gidiyor.
func _wall_ahead() -> TileMapLayer:
	var layer: TileMapLayer = WallLayerFactory.make_layer(self, WallLayerFactory.rect_cells(40, -80, 41, 100))
	_track(layer)
	GameManager._terrain_forest_layer = layer
	GameManager._terrain_layers_searched = true
	PathingScript.reset()
	PathingScript.set_enabled(true)
	return layer


func test_ambush_position_is_behind_a_wall_ahead_of_the_player() -> void:
	var sp: Node = _spawner()
	_wall_ahead()
	var center := Vector2(400.0, 300.0)
	var found: int = 0
	for _i in range(40):
		var pos: Variant = sp._ambush_spawn_position(center, Vector2.RIGHT)
		if pos == null:
			continue
		found += 1
		var p: Vector2 = Vector2(pos)
		assert(PathingScript.line_blocked(center, p), "Pusu noktası ile oyuncu arasında duvar olmalı: %s" % str(p))
		assert(p.x > 660.0, "Pusu noktası duvarın ARKASINDA (sağında) olmalı: %s" % str(p))
		assert(not GameManager.is_position_blocked_by_terrain(p), "Pusu noktası duvarın içinde olmamalı")
		assert(p.distance_to(center) >= sp.min_spawn_distance - 1.0, "Pusu noktası ekranın dışında olmalı")
		assert(absf(rad_to_deg((p - center).angle())) <= sp.AMBUSH_ARC_DEG * 0.5 + 0.5, "Pusu oyuncunun gittiği yönde olmalı")
	assert(found >= 20, "Duvar varken pusu noktası çoğu denemede bulunmalı (%d/40)" % found)
	_cleanup()


func test_no_ambush_position_in_open_terrain() -> void:
	var sp: Node = _spawner()
	## duvar oyuncunun ARKASINDA (sol): gittiği yönde duvar yok
	var layer: TileMapLayer = WallLayerFactory.make_layer(self, WallLayerFactory.rect_cells(5, -80, 6, 100))
	_track(layer)
	GameManager._terrain_forest_layer = layer
	GameManager._terrain_layers_searched = true
	PathingScript.reset()
	for _i in range(20):
		assert(sp._ambush_spawn_position(Vector2(400.0, 300.0), Vector2.RIGHT) == null, "Gittiği yönde duvar yokken pusu noktası olmamalı")
	_cleanup()


## Gerçek akış: hareket eden oyuncu + önünde duvar -> 2-4 kişilik kümeler duvarın ARKASINDA doğar.
func test_moving_player_gets_ambush_packs_behind_the_wall() -> void:
	var sp: Node = _spawner()
	_wall_ahead()
	_player(Vector2(400.0, 300.0), Vector2(220.0, 0.0))
	GameManager.game_time = 10.0
	var calls: int = 60
	for _i in range(calls):
		sp._spawn_regular_enemy()
	var enemies: Array[Node] = _real_enemies()
	assert(enemies.size() > calls, "Pusu paketleri tek spawn'dan fazla yaratık getirmeli (%d yaratık / %d tetiklenme)" % [enemies.size(), calls])
	var behind_wall: int = 0
	var clustered: int = 0
	for e: Node in enemies:
		var p: Vector2 = (e as Node2D).global_position
		if PathingScript.line_blocked(Vector2(400.0, 300.0), p) and p.x > 660.0:
			behind_wall += 1
		var neighbours: int = 0
		for o: Node in enemies:
			if o != e and (o as Node2D).global_position.distance_to(p) <= sp.AMBUSH_PACK_SPREAD * 2.0:
				neighbours += 1
		if neighbours >= 1:
			clustered += 1
	assert(behind_wall >= calls / 2, "Yaratıkların büyük kısmı duvarın arkasında doğmalı (%d/%d)" % [behind_wall, enemies.size()])
	assert(clustered >= 4, "Pusu yaratıkları dar kümeler halinde doğmalı (kümedeki: %d)" % clustered)
	_cleanup()


## Duran oyuncuya pusu yok (önünü kesecek bir 'gidiş yönü' yok) - sadece normal tek spawn.
func test_standing_player_gets_no_ambush_packs() -> void:
	var sp: Node = _spawner()
	_wall_ahead()
	_player(Vector2(400.0, 300.0), Vector2.ZERO)
	GameManager.game_time = 10.0
	for _i in range(40):
		sp._spawn_regular_enemy()
	assert(_real_enemies().size() == 40, "Duran oyuncuya tetiklenme başına TAM 1 yaratık gelmeli (bulunan: %d)" % _real_enemies().size())
	_cleanup()


## Birden fazla dışarıdaki oyuncu varsa çapa hepsi arasından seçilir (çoğul "oyuncuların").
func test_spawn_anchor_is_chosen_among_all_outdoor_players() -> void:
	var sp: Node = _spawner()
	_player(Vector2(0.0, 0.0))
	var remote := FakePlayer.new()
	remote.add_to_group("remote_players")
	add_child(remote)
	remote.global_position = Vector2(5000.0, 0.0)
	_track(remote)
	NetworkManager.is_multiplayer_active = true
	assert(sp._outdoor_living_players().size() == 2, "İki dışarıdaki oyuncu bulunmalı")
	var seen: Dictionary = {}
	for _i in range(60):
		seen[sp._pick_spawn_anchor().global_position.x] = true
	assert(seen.size() == 2, "Çapa iki oyuncu arasında dağılmalı (görülen: %d)" % seen.size())
	remote.is_dead = true
	assert(sp._outdoor_living_players().size() == 1, "Ölü oyuncu çapa adayı olmamalı")
	_cleanup()
