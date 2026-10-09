extends Node

## Kullanıcı isteği (2026-10-08): "tüm bosslar bundan sonra elit yaratıkların yerine geçsin; elitler gibi hafif büyük ve yıldızlı olacaklar. yeni bossları sana
## sonradan atacağım" + "canları ve kalkanları o kademedeki yaratıkların 15 katı" + (soru) "her kademenin tek eliti boss havuzundan gelsin" + "Final ve zafer
## geçici kapansın" (Kademe XV bitince doğrudan sonsuz mod). Kapsam: ELITE_POOL, elite_candidates (kademe ailelerine göre), elit doğumunun havuzdan gelmesi ve 15 kat
## can/kalkan, boss/Final/zafer/boss dalgası KAPALI (GameManager.bosses_enabled = false), Kademe XV sonunda otomatik sonsuz mod, "Kademe XVI" bildirimi yok.

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const EnemyScript: GDScript = preload("res://scripts/enemy.gd")

var _made: Array[Node] = []
var _heard: Array = []


class FakePlayer extends Node2D:
	var is_dead: bool = false
	var velocity: Vector2 = Vector2.ZERO


func _on_tier(t: int) -> void:
	_heard.append(t)


func _cleanup() -> void:
	if NetworkManager.creature_tier_reached.is_connected(_on_tier):
		NetworkManager.creature_tier_reached.disconnect(_on_tier)
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	GameManager.bosses_enabled = false
	GameManager.game_time = 0.0
	GameManager.victory_reached = false
	GameManager.endless_active = false
	GameManager.endless_layer = 0
	NetworkManager.is_multiplayer_active = false


func _spawner() -> Node:
	_cleanup()
	_heard.clear()
	var sp: Node = SpawnerScript.new()
	add_child(sp)
	sp.max_concurrent_enemies = 100000
	get_tree().current_scene = self
	_made.append(sp)
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = Vector2(500.0, 500.0)
	_made.append(p)
	return sp


func _boss_nodes() -> Array:
	var out: Array = []
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and (e.get("is_boss") == true or e.is_in_group("boss")):
			out.append(e)
	return out


# ------------------------------------------------------------------ havuz + adaylar

func test_elite_pool_is_the_old_boss_roster() -> void:
	var pool: Array = SpawnerScript.ELITE_POOL
	assert(pool.size() == 14, "14 yaratık: %d" % pool.size())
	var uniq: Dictionary = {}
	for id in pool:
		uniq[id] = true
		assert(SpawnerScript.ID_FAMILY.has(id) and SpawnerScript.SCENES.has(id), "havuz yaratığı oyunda tanımlı olmalı: %s" % id)
	assert(uniq.size() == pool.size(), "tekrar yok")
	var old: Dictionary = {}
	for tier in SpawnerScript.BOSS_TIERS:
		for id in SpawnerScript.BOSS_TIERS[tier]:
			old[id] = true
	for id in SpawnerScript.FINAL_CREATURES:
		old[id] = true
	for id in old.keys():
		assert(uniq.has(id), "eski boss havuzda olmalı: %s" % id)
	for id in uniq.keys():
		assert(old.has(id), "havuzda eski bossta olmayan yaratık var: %s" % id)


func test_elite_candidates_follow_the_tier_families_and_never_leave_the_pool() -> void:
	for t in range(1, 16):
		var c: Array = SpawnerScript.elite_candidates(t)
		assert(not c.is_empty(), "Kademe %d için aday var" % t)
		for id in c:
			assert(SpawnerScript.ELITE_POOL.has(id), "aday havuzdan olmalı: %s (Kademe %d)" % [id, t])
	assert(SpawnerScript.elite_candidates(1) == ["rat3"], "Kademe 1 (fare + slime): sadece fare: %s" % str(SpawnerScript.elite_candidates(1)))
	var c13: Array = SpawnerScript.elite_candidates(13)
	for id in c13:
		assert(["demon", "hayalet", "rontgen", "vampire", "iblis"].has(SpawnerScript.ID_FAMILY[id]), "Kademe 13 ailesi: %s" % id)
	assert(c13.has("demon3") and c13.has("iblis3"), "Kademe 13: şeytan/iblis adayları var")
	var c12: Array = SpawnerScript.elite_candidates(12)
	assert(c12.has("agac3") and c12.has("golem3") and c12.has("mantar3") and not c12.has("demon3"), "Kademe 12 orman yaratıkları: %s" % str(c12))
	var c9: Array = SpawnerScript.elite_candidates(9)
	assert(not c9.is_empty() and not c9.has("demon3"), "Kademe 9 (sadece slime) komşu kademelerin ailelerine genişler: %s" % str(c9))


func test_elite_defense_multiplier_is_15() -> void:
	assert(is_equal_approx(EnemyScript.ELITE_DEFENSE_MULT, 15.0), "can ve kalkan 15 kat: %s" % EnemyScript.ELITE_DEFENSE_MULT)


# ------------------------------------------------------------------ elit doğumu

func test_the_tier_elite_comes_from_the_pool_with_15x_health_and_shield_and_the_elite_look() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 450.0 ## Kademe 5
	sp._elite_due_time[5] = 0.0 ## vade geldi
	sp._spawn_regular_enemy()
	var elite: Node = null
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.get("is_elite") == true:
			elite = e
	assert(elite != null, "vadesi gelen ilk doğum ELİT olmalı")
	var cid: String = str(elite.get_meta("creature_id", ""))
	assert(SpawnerScript.elite_candidates(5).has(cid), "elit havuzdan, Kademe 5 ailelerinden: %s" % cid)
	assert(elite.is_in_group("elite_enemies") and not elite.is_in_group("boss") and elite.get("is_boss") != true, "elit, boss değil")
	assert(elite.get_node_or_null("EliteStar") != null and elite.get_node_or_null("EliteAura") != null, "yıldız + aura")
	## Aynı kimlikli sıradan yaratık, aynı kademe ölçeği + kalkan + global çarpanla: elit tam 15 katı.
	var ref: Node = sp._spawn_creature(cid, Vector2(900.0, 900.0), 999001)
	ref.apply_tier_scaling(5)
	sp._enable_regular_shield(ref, 5)
	sp._apply_global_buff(ref)
	assert(ref.max_health > 0.0 and ref.item_shield_max > 0.0, "Kademe 5'te sıradan yaratığın canı ve kalkanı var")
	assert(absf(elite.max_health / ref.max_health - 15.0) < 0.01, "can 15 kat: %.3f" % (elite.max_health / ref.max_health))
	assert(absf(elite.item_shield_max / ref.item_shield_max - 15.0) < 0.01, "kalkan 15 kat: %.3f" % (elite.item_shield_max / ref.item_shield_max))
	assert(elite.contact_damage > ref.contact_damage * 1.4, "hasar +%50")
	assert(_boss_nodes().is_empty(), "boss yok")
	assert(sp._elite_spawned_tiers.has(5), "kademenin eliti kayda geçti (ikincisi doğmaz)")
	_cleanup()


func test_a_failed_elite_spawn_gives_the_slot_back() -> void:
	var sp: Node = _spawner()
	sp._elite_spawned_tiers[4] = true
	sp._unroll_elite(4)
	assert(not sp._elite_spawned_tiers.has(4), "doğmayan elit vadesini geri verir")
	_cleanup()


# ------------------------------------------------------------------ boss/Final kapalı

func test_bosses_are_off_by_default_and_only_the_new_tier_3_boss_spawns() -> void:
	## Varsayılan, çalışan autoload'dan değil script'in kendisinden okunur (diğer testler anahtarı geçici açıp kapatır).
	var fresh: Node = (GameManager.get_script() as GDScript).new()
	assert(fresh.get("bosses_enabled") == false, "boss sistemi varsayılan KAPALI")
	fresh.free()
	_cleanup()
	var sp: Node = _spawner()
	GameManager.bosses_enabled = false
	## 2026-10-08: yeni bosslar tek tek veriliyor - şimdilik SADECE Kademe 3 (Minotaur, bkz. NEW_BOSS_TIERS / test_minotaur_boss); eski bosslar elit oldu.
	for time in [590.0, 790.0, 1190.0, 1490.0]: ## Kademe 6/8/12/15 boss tetik zamanları (zaman atlandığı için Kademe 3'ün Minotaur'u da tetik zamanını geçmiş sayılır)
		GameManager.game_time = time
		sp._check_boss_tiers()
	for b: Node in _boss_nodes():
		assert(["minotaur1", "underground1"].has(str(b.get_meta("creature_id", ""))), "yeni bosslar dışında boss yok: %s" % str(b.get_meta("creature_id", "")))
	assert(_boss_nodes().size() <= 2, "Kademe 6/8/12/15'te boss doğmaz")
	assert(sp._boss_tiers_spawned.keys().all(func(k: int) -> bool: return k == 3 or k == 5), "boss kaydı yalnız Kademe 3 + 5: %s" % str(sp._boss_tiers_spawned.keys()))
	assert(SpawnerScript.NEW_BOSS_TIERS.keys() == [3, 5], "yeni boss tablosunda Kademe 3 (Minotaur) + 5 (Yeraltı Canavarı): %s" % str(SpawnerScript.NEW_BOSS_TIERS.keys()))
	_cleanup()


func test_after_tier_15_the_run_continues_straight_into_endless_without_final_or_victory() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 1400.0
	sp._check_final_tier()
	assert(sp.get_endless_layer() == 0, "Kademe XV bitmeden sonsuz yok")
	GameManager.game_time = 1501.0 ## 15 kademe x 100 sn doldu
	assert(not sp._final_pending(), "Final yok: yeni yaratık doğumu durmaz")
	sp._check_final_tier()
	assert(sp.get_endless_layer() == 1, "doğrudan sonsuz Kat 1: %d" % sp.get_endless_layer())
	assert(GameManager.endless_active, "herkeste sonsuz mod bayrağı")
	assert(not sp._final_spawned and sp._final_bosses.is_empty() and not GameManager.victory_reached, "Final dalgası ve zafer penceresi yok")
	assert(_boss_nodes().is_empty(), "13'lü boss dalgası doğmadı")
	sp._check_final_tier() ## ikinci çağrı sonsuzu yeniden başlatmaz
	assert(sp.get_endless_layer() == 1)
	_cleanup()


func test_no_final_tier_announcement_and_no_endless_boss_wave_while_bosses_are_off() -> void:
	var sp: Node = _spawner()
	NetworkManager.creature_tier_reached.connect(_on_tier)
	GameManager.game_time = 1600.0
	sp._check_tier_announcement()
	assert(not _heard.has(16), "Final (XVI) bildirimi yok: %s" % str(_heard))
	sp._check_final_tier()
	GameManager.game_time = 1501.0 + 250.0 ## sonsuz Kat 3 = boss dalgası katı
	sp._process_endless()
	sp._check_endless_boss_wave()
	assert(_boss_nodes().is_empty() and sp._endless_bosses_spawned.is_empty(), "sonsuzda boss dalgası doğmaz")
	_cleanup()


func test_endless_elite_also_comes_from_the_pool_with_the_tier_15_families() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 1501.0
	sp._check_final_tier()
	GameManager.game_time = 1501.0 + 99.0
	sp._spawn_regular_enemy()
	var found: bool = false
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.get("is_elite") == true:
			found = true
			assert(SpawnerScript.elite_candidates(15).has(str(e.get_meta("creature_id", ""))), "sonsuz katın eliti de havuzdan: %s" % str(e.get_meta("creature_id", "")))
	assert(found, "katın eliti doğmalı")
	_cleanup()
