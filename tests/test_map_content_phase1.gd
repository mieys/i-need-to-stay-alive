extends Node

## HARİTA İÇERİĞİ Aşama 1 (madde 597, docs/harita_icerik/PLAN.md): oyun 10 kademe, Kademe 5 + 10'da boss (K10 bossu ölünce ZAFER), yalnız çift kademede
## elit (hesaplanan taban P = kademe + 2), boss yuva statları + hasar çarpanı, sonsuz mod ölçeği LAST_TIER'dan başlar, balans kaydında boss dövüşleri.
## (Eski test_elite_pool_and_bosses_off.gd'nin yerine geçer: eski 14'lü elit havuzu, 15 kademe ve "boss/Final kapalı" davranışı kalktı.)

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const EnemyScript: GDScript = preload("res://scripts/enemy.gd")
const EndlessMath: GDScript = preload("res://scripts/endless_math.gd")
const BalanceLogScript: GDScript = preload("res://scripts/balance_log.gd")
const TierDisplayScript: GDScript = preload("res://scripts/tier_display.gd")

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
	sp.tier_duration = 100.0 ## testler 100 sn'lik kademelere göre yazıldı (varsayılan 150; kademe süresi bu testin konusu değil)
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


func _elite_nodes() -> Array:
	var out: Array = []
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.get("is_elite") == true:
			out.append(e)
	return out


# ------------------------------------------------------------------ 10 kademe + havuz

func test_the_game_has_exactly_ten_tiers_and_the_endless_scale_starts_after_them() -> void:
	assert(SpawnerScript.LAST_TIER == 10, "10 kademe: %d" % SpawnerScript.LAST_TIER)
	assert(EndlessMath.BASE_TIER == SpawnerScript.LAST_TIER, "sonsuz ölçek tabanı LAST_TIER ile aynı")
	assert(EndlessMath.scale_tier(1) == 11 and EndlessMath.layer_for_scale_tier(11) == 1, "kat 1 = ölçek kademesi 11")
	assert(TierDisplayScript.FINAL_TIER == SpawnerScript.LAST_TIER, "kademe göstergesi son kademesi aynı")
	assert(is_equal_approx(EndlessMath.creature_health_mult(10), 1.0) and EndlessMath.creature_health_mult(13) > 1.0, "bileşik baskı kat 2'den sonra")


func test_the_roster_table_covers_every_tier_and_only_known_creatures() -> void:
	var keys: Array = SpawnerScript.TIER_ROSTER.keys()
	keys.sort()
	assert(keys == range(1, 11), "TIER_ROSTER 1..10: %s" % str(keys))
	for t in keys:
		var roster: Array = SpawnerScript.TIER_ROSTER[t]
		assert(not roster.is_empty(), "Kademe %d listesi dolu" % t)
		for id in roster:
			assert(SpawnerScript.SCENES.has(id) and SpawnerScript.ID_FAMILY.has(id), "Kademe %d yaratığı tanımlı olmalı: %s" % [t, id])
	assert(SpawnerScript.TIER_ROSTER[1] == ["slime1", "slime1", "iskelet1"], "K1 bugünkü")
	assert(SpawnerScript.TIER_ROSTER[8] == ["lich2", "ork2", "ork3", "slime2", "iskelet3"], "K8 bugünkü")
	assert(SpawnerScript.TIER_ROSTER[9] == ["agac1", "bitki1", "golem1", "mantar1"], "K9 = eski K10 (orman yaratıkları)")
	assert(SpawnerScript.TIER_ROSTER[10] == ["agac2", "bitki2", "bitki3", "golem2", "golem3", "mantar2", "mantar3"], "K10 = eski K11-12 + 3. haller")


func test_the_current_tier_is_capped_at_the_last_tier() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 99999.0
	assert(sp._current_tier() == 10, "kademe 10'da kısılır: %d" % sp._current_tier())
	assert(not SpawnerScript.TIER_ROSTER.get(sp._current_tier(), []).is_empty(), "o kademenin listesi dolu")
	_cleanup()


func test_the_tier_announcement_stops_at_the_last_tier() -> void:
	var sp: Node = _spawner()
	NetworkManager.creature_tier_reached.connect(_on_tier)
	GameManager.game_time = 1250.0 ## kademe saati 10'u çoktan geçti, boss henüz yok (doğmadı)
	sp._check_tier_announcement()
	assert(_heard.max() <= 10, "Kademe XI bildirimi yok: %s" % str(_heard))
	assert(_heard.has(10), "Kademe X duyuruldu: %s" % str(_heard))
	_cleanup()


# ------------------------------------------------------------------ bosslar + zafer

func test_the_boss_table_is_tier_5_and_tier_10_only() -> void:
	assert(SpawnerScript.NEW_BOSS_TIERS.keys() == [5, 10], "yalnız K5 ve K10: %s" % str(SpawnerScript.NEW_BOSS_TIERS.keys()))
	assert(SpawnerScript.NEW_BOSS_TIERS[5] == ["minotaur1"] and SpawnerScript.NEW_BOSS_TIERS[10] == ["kardes_kilic1", "kardes_ok1", "kardes_buyu1"],
			"ana harita bossları Minotaur + Üç Kardeş (2026-11-14, eskiden Wendigo)")
	assert(SpawnerScript.needs_night(["banshee1"]) and not SpawnerScript.needs_night(["wendigo1", "minotaur1"]), "gece kilidi boss KİMLİĞİNE bağlı")


func test_boss_slot_stats_and_damage_multiplier() -> void:
	## K5 yuvası: can 50.000, kalkan 60.000; soğurma bossun kendisinde; hasar = eski x (3 + 2,2 x 5) / (3 + 2,2 x eski kademe).
	var m5: Dictionary = SpawnerScript.boss_fixed_stats("minotaur1", 5)
	assert(is_equal_approx(float(m5["health"]), 50000.0) and is_equal_approx(float(m5["shield"]), 60000.0), "Minotaur K5 can/kalkan")
	assert(is_equal_approx(float(m5["protection"]), 0.8), "soğurma bossun kendi değeri")
	assert(absf(float(m5["damage"]) - 100.0 * 14.0 / 9.6) < 0.01, "Minotaur hasarı x1,458: %s" % str(m5["damage"]))
	## K10 yuvası: can 300.000, kalkan 400.000; Wendigo K12'den iner (x0,850).
	var w10: Dictionary = SpawnerScript.boss_fixed_stats("wendigo1", 10)
	assert(is_equal_approx(float(w10["health"]), 300000.0) and is_equal_approx(float(w10["shield"]), 400000.0), "Wendigo K10 can/kalkan")
	assert(absf(SpawnerScript.boss_slot_damage_mult("wendigo1", 10) - 25.0 / 29.4) < 0.0001, "Wendigo hasar çarpanı")
	assert(absf(float(w10["damage"]) - 120.0 * 25.0 / 29.4) < 0.01, "Wendigo temas hasarı çarpanla")
	## İstisna: Yeraltı Canavarı K5'te daha zayıf (can 36.000 / kalkan 44.000) ve uzuv hasarı x0,8.
	var u5: Dictionary = SpawnerScript.boss_fixed_stats("underground1", 5)
	assert(is_equal_approx(float(u5["health"]), 36000.0) and is_equal_approx(float(u5["shield"]), 44000.0), "Yeraltı K5 istisnası")
	assert(is_equal_approx(SpawnerScript.boss_slot_damage_mult("underground1", 5), 0.8), "Yeraltı uzuv hasarı x0,8")
	## Yuva dışı kademede (sonsuz dalga bossu, test) FIXED_BOSS_STATS aynen.
	var w12: Dictionary = SpawnerScript.boss_fixed_stats("wendigo1", 12)
	assert(is_equal_approx(float(w12["health"]), 200000.0) and is_equal_approx(SpawnerScript.boss_slot_damage_mult("wendigo1", 12), 1.0), "yuva dışı değişmez")
	assert(is_equal_approx(float(SpawnerScript.boss_fixed_stats("banshee1", 16)["health"]), 300000.0), "sonsuz dalga bossu kendi sayılarıyla")


func test_the_tier_5_boss_spawns_with_the_slot_stats_and_does_not_end_the_run() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 480.0 ## K5 tetik zamanı (4 x 100 + %75) = 475
	sp._check_boss_tiers()
	var bosses: Array = _boss_nodes()
	assert(bosses.size() == 1 and str(bosses[0].get_meta("creature_id", "")) == "minotaur1", "Kademe 5'te Minotaur")
	assert(is_equal_approx(float(bosses[0].max_health), 50000.0) and is_equal_approx(float(bosses[0].item_shield_max), 60000.0), "yuva statları (tek oyuncu)")
	assert(is_equal_approx(float(bosses[0].get_meta("boss_damage_mult", 0.0)), 14.0 / 9.6), "hasar çarpanı metası (özel saldırı betikleri okur)")
	assert(not sp._final_spawned and sp._final_bosses.is_empty(), "K5 bossu SON boss değil")
	sp._check_victory()
	assert(sp.get_run_phase() == 0, "K5 bossunun ölümü zafer değil")
	_cleanup()


func test_killing_the_tier_10_boss_is_the_victory_and_the_clock_waits_for_it() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 980.0 ## K10 tetik zamanı (9 x 100 + %75) = 975
	sp._boss_tiers_spawned[5] = true ## zaman atlandığı için K5 bossu da tetik zamanını geçmiş sayılır: onu doğurma
	sp._check_boss_tiers()
	var bosses: Array = _boss_nodes()
	var ids: Array = []
	for b: Node in bosses:
		ids.append(str(b.get_meta("creature_id", "")))
	ids.sort()
	assert(ids == ["kardes_buyu1", "kardes_kilic1", "kardes_ok1"], "Kademe 10'da Üç Kardeş: %s" % str(ids))
	assert(sp._final_spawned and sp._final_bosses.size() == 3, "son boss kaydı = üç kardeş (zafer üçünün ölümüne bakar)")
	for b: Node in bosses:
		assert(is_equal_approx(float(b.max_health), 140000.0) and is_equal_approx(float(b.item_shield_max), 180000.0), "kardeş başına can/kalkan")
	## Biri ya da ikisi ölünce zafer yok, üçü ölünce var (aşağıda)
	bosses[0].is_dead = true
	bosses[1].is_dead = true
	sp._check_victory()
	assert(sp.get_run_phase() == 0, "iki kardeş ölü, biri sağken zafer yok")
	bosses[0].is_dead = false
	bosses[1].is_dead = false
	## Boss sağken saat 10. kademenin sonunda bekler: otomatik sonsuz moda ve 11. kademeye geçilmez.
	GameManager.game_time = 5000.0
	assert(sp._current_tier() == 10 and sp.is_tier_held_by_boss(), "kademe saati K10 sınırında tutuluyor")
	sp._check_auto_endless()
	assert(sp.get_run_phase() == 0 and sp.get_endless_layer() == 0, "son boss tanımlıyken otomatik sonsuz yok")
	sp._check_victory()
	assert(sp.get_run_phase() == 0, "boss sağken zafer yok")
	for b: Node in bosses:
		b.is_dead = true
	sp._check_victory()
	assert(sp.get_run_phase() == 1, "son boss ölünce ZAFER (RunPhase.VICTORY)")
	sp._check_auto_endless() ## zafer evresinde otomatik sonsuz tetiklenmez (yalnız "Sonsuza Devam Et")
	assert(sp.get_run_phase() == 1 and sp.get_endless_layer() == 0, "sonsuza yalnız host kararıyla girilir")
	assert(sp.begin_endless() and sp.get_run_phase() == 2 and sp.get_endless_layer() == 1, "Sonsuza Devam Et -> sonsuz mod Kat 1")
	_cleanup()


func test_the_last_boss_is_remembered_after_a_host_migration_only_when_alive() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 980.0
	sp._boss_tiers_spawned[5] = true
	sp._check_boss_tiers()
	var trio: Array = _boss_nodes()
	var exported: Dictionary = sp.export_handover()
	assert(not (exported["boss_tiers"] as Array).has(10), "sağ son boss 'bitti' listesinde değil (yeni host yeniden doğurur)")
	for boss: Node in trio:
		boss.is_dead = true
	assert((sp.export_handover()["boss_tiers"] as Array).has(10), "ölü son boss 'bitti' listesinde")
	_cleanup()


func test_the_endless_boss_wave_is_built_from_the_maps_own_two_bosses() -> void:
	var sp: Node = _spawner()
	assert(sp._endless_wave_pool() == ["minotaur1", "kardes_kilic1", "kardes_ok1", "kardes_buyu1"], "ana haritanın bossları: %s" % str(sp._endless_wave_pool()))
	sp._run_phase = 2 ## ENDLESS
	sp._endless_start_time = 0.0
	sp._endless_layer = 9 ## 3. dalga: genel formül 4 boss verirdi, havuz 2 olduğundan en çok 2
	GameManager.game_time = 880.0 ## kat 9'un %75'i (875 sn) geçti
	sp._check_endless_boss_wave()
	var ids: Array = []
	for b: Node in _boss_nodes():
		ids.append(str(b.get_meta("creature_id", "")))
	ids.sort()
	assert(ids == ["kardes_buyu1", "kardes_kilic1", "kardes_ok1", "minotaur1"], "dalga haritanın bossları (Üç Kardeş bütün), fazlası yok: %s" % str(ids))
	_cleanup()


# ------------------------------------------------------------------ elit

func test_elites_appear_on_every_tier_from_the_table() -> void:
	assert(SpawnerScript.ELITE_BY_TIER.keys() == [2, 4, 6, 8, 10], "tablo K2/K4/K6/K8/K10")
	for t in range(1, 11):
		assert(SpawnerScript.elite_tier(t), "elit HER kademede (2026-11-13): %d" % t)
	assert(not SpawnerScript.elite_tier(0) and not SpawnerScript.elite_tier(11), "kademe aralığı dışında yok")
	for t in SpawnerScript.ELITE_BY_TIER.keys():
		var id: String = SpawnerScript.ELITE_BY_TIER[t]
		assert(SpawnerScript.SCENES.has(id) and SpawnerScript.ID_FAMILY.has(id), "elit tanımlı: %s" % id)
		assert(SpawnerScript.elite_candidates(t) == [id], "kademenin adayı tablodaki elit: %d" % t)
	for t in [1, 3, 5, 7, 9]:
		assert(SpawnerScript.elite_candidates(t) == [SpawnerScript.ELITE_BY_TIER[t + 1]], "tek kademe = bir sonraki çift kademenin eliti: %d" % t)
	assert(SpawnerScript.ELITE_BY_TIER.values() == ["iskelet3", "zombie3", "lich3", "ork3", "agac3"], "ana harita elitleri")


func test_every_tier_rolls_exactly_one_elite() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 250.0 ## K3
	sp._elite_due_time[3] = 0.0
	assert(sp._roll_elite(3), "tek kademenin de eliti var")
	assert(not sp._roll_elite(3), "kademe başına bir tane (tek)")
	GameManager.game_time = 350.0 ## K4
	sp._elite_due_time[4] = 0.0 ## vade geldi
	assert(sp._roll_elite(4), "çift kademenin eliti")
	assert(not sp._roll_elite(4), "kademe başına bir tane")
	_cleanup()


func test_the_boss_tier_elite_is_due_in_the_first_half_of_the_tier() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 900.0 ## K10 başı (kademe 100 sn): vade en geç 950 (ilk yarı), boss 975'te
	for i in range(30):
		sp._elite_due_time.erase(10)
		sp._elite_spawned_tiers.erase(10)
		sp._roll_elite(10)
		assert(float(sp._elite_due_time[10]) <= 950.001, "K10 eliti kademenin ilk yarısında (boss sonda): %s" % str(sp._elite_due_time[10]))
	sp._elite_due_time.erase(8) ## boss olmayan kademede sınır = kademe sonu - 10 sn
	GameManager.game_time = 700.0
	for i in range(30):
		sp._elite_due_time.erase(8)
		sp._elite_spawned_tiers.erase(8)
		sp._roll_elite(8)
		assert(float(sp._elite_due_time[8]) <= 790.001, "K8 eliti kademe sonundan önce: %s" % str(sp._elite_due_time[8]))
	_cleanup()


func test_elite_base_stats_follow_power_tier_plus_two_and_grow_with_the_tier() -> void:
	## P = kademe + 2; can = (10 + 9P) x max(1, aile can çarpanı); hasar = (3 + 2,2P) x aile hasar çarpanı; xp = 2 + 2P.
	var z: Dictionary = SpawnerScript.pool_stats("zombie3", 4, true) ## P = 6
	assert(absf(float(z["health"]) - 64.0 * 1.3) < 0.001, "zombie3 K4 can: %s" % str(z["health"]))
	assert(absf(float(z["damage"]) - 16.2 * 1.1) < 0.001, "zombie3 K4 hasar: %s" % str(z["damage"]))
	assert(is_equal_approx(float(z["xp"]), 14.0), "zombie3 K4 xp")
	assert(SpawnerScript.pool_stats("slime1", 3, false).is_empty(), "sıradan yaratık SAHNE değerleriyle doğar (ana haritanın bugünkü dengesi)")
	var weak: Dictionary = SpawnerScript.pool_stats("slime2", 2, true) ## slime can çarpanı 0,7 -> elit için en az 1,0
	assert(absf(float(weak["health"]) - (10.0 + 9.0 * 4.0)) < 0.001, "zayıf aile elit olunca can çarpanı en az 1,0: %s" % str(weak["health"]))
	assert(SpawnerScript.pool_stats("agac3", 25, true) == SpawnerScript.pool_stats("agac3", 10, true), "sonsuzda P için ölçek LAST_TIER'da kısılır")
	## Her kademenin eliti bir öncekinden güçlü (kademe ölçeği + make_elite ÖNCESİ taban ve sonrası dayanıklılık).
	var prev_hp: float = 0.0
	for t in [2, 4, 6, 8, 10]:
		var st: Dictionary = SpawnerScript.pool_stats(SpawnerScript.ELITE_BY_TIER[t], t, true)
		var steps: int = maxi(t - 1, 0)
		var hp_with_scale: float = float(st["health"]) * (1.0 + steps * EnemyScript.TIER_HEALTH_RAMP_LINEAR + steps * steps * EnemyScript.TIER_HEALTH_RAMP_QUAD)
		assert(hp_with_scale > prev_hp, "elit gücü artan: K%d %s <= %s" % [t, str(hp_with_scale), str(prev_hp)])
		prev_hp = hp_with_scale


func test_the_spawned_elite_uses_the_table_the_computed_base_and_the_15x_multiplier() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 350.0 ## Kademe 4
	sp._elite_due_time[4] = 0.0
	sp._spawn_regular_enemy()
	var elites: Array = _elite_nodes()
	assert(elites.size() == 1, "vadesi gelen ilk doğum ELİT olmalı")
	var elite: Node = elites[0]
	assert(str(elite.get_meta("creature_id", "")) == "zombie3", "K4 eliti tablodan: %s" % str(elite.get_meta("creature_id", "")))
	assert(elite.is_in_group("elite_enemies") and elite.get("is_boss") != true, "elit, boss değil")
	## Aynı kimlik, aynı hesaplanan taban + ölçek + kalkan + global çarpan: elit tam 15 katı.
	var ref: Node = sp._spawn_creature("zombie3", Vector2(900.0, 900.0), 999001)
	sp._apply_base_stats(ref, SpawnerScript.pool_stats("zombie3", 4, true))
	ref.apply_tier_scaling(4)
	sp._enable_regular_shield(ref, 4)
	sp._apply_global_buff(ref)
	assert(ref.max_health > 0.0 and ref.item_shield_max > 0.0, "referansın canı ve kalkanı var")
	assert(absf(elite.max_health / ref.max_health - 15.0) < 0.01, "can 15 kat: %.3f" % (elite.max_health / ref.max_health))
	assert(absf(elite.xp_value - 14.0) < 0.001, "xp hesaplanan tabandan: %s" % str(elite.xp_value))
	assert(sp._elite_spawned_tiers.has(4), "kademenin eliti kayda geçti")
	_cleanup()


func test_a_failed_elite_spawn_gives_the_slot_back() -> void:
	var sp: Node = _spawner()
	sp._elite_spawned_tiers[4] = true
	sp._unroll_elite(4)
	assert(not sp._elite_spawned_tiers.has(4), "doğmayan elit vadesini geri verir")
	_cleanup()


func test_the_endless_floor_elite_is_one_of_the_five_table_elites() -> void:
	var sp: Node = _spawner()
	sp._run_phase = 2 ## ENDLESS
	sp._endless_layer = 1
	var table_ids: Array = SpawnerScript.ELITE_BY_TIER.values()
	var seen: Dictionary = {}
	for i in range(80):
		var id: String = sp._pick_elite_id(10)
		assert(table_ids.has(id), "sonsuz kat eliti haritanın 5 elitinden biri: %s" % id)
		seen[id] = true
	assert(seen.size() >= 3, "rastgele dağılım: %s" % str(seen.keys()))
	_cleanup()


# ------------------------------------------------------------------ K6-K10 baskı ayarı + denge kaydı

func test_late_pressure_defaults_to_no_change() -> void:
	for t in range(1, 11):
		var lp: Dictionary = SpawnerScript.late_pressure(t)
		assert(is_equal_approx(float(lp["hp"]), 1.0) and is_equal_approx(float(lp["dmg"]), 1.0), "K%d baskı çarpanı varsayılan 1,0 (kendiliğinden sıkılmaz)" % t)


func test_balance_log_records_boss_fights_with_spawn_and_death_seconds() -> void:
	BalanceLogScript.reset()
	BalanceLogScript.note_boss_spawn("wendigo1", 2)
	var rows: Array = BalanceLogScript._boss_fights.get("wendigo1", [])
	assert(rows.size() == 1 and float(rows[0][1]) < 0.0 and int(rows[0][2]) == 2, "açık kayıt: ölüm -1, takım boyu 2: %s" % str(rows))
	BalanceLogScript.note_boss_death("wendigo1")
	assert(float((BalanceLogScript._boss_fights["wendigo1"] as Array)[0][1]) >= 0.0, "ölüm kaydı kapandı")
	BalanceLogScript.note_boss_death("wendigo1") ## kapanmış kaydı ikinci kez ezmez
	assert((BalanceLogScript._boss_fights["wendigo1"] as Array).size() == 1)
	BalanceLogScript.reset()
	assert(BalanceLogScript._boss_fights.is_empty(), "yeni koşuda sıfırlanır")
