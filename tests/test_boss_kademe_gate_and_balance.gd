extends Node

## Kullanıcı istekleri (2026-09-21):
##  1) "mevcut kademenin boss'unu öldürmeden diğer kademeye atlanmamalı"
##  2) "Bossların canını %15 kalkanını %10 azalt"
##  3) "Bossların hasarını %10 arttırıp tüm yaratıkların hasarını %10 azalt"

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const RatScene: PackedScene = preload("res://scenes/creatures/enemy_rat1.tscn")

## Bu turdan ÖNCEKİ değerler.
const PREV_BOSS_HEALTH_MULT := 126.72
const PREV_BOSS_SHIELD_RATIO := 1.3
const PREV_BOSS_DAMAGE_MULT := 2.4
const PREV_GLOBAL_DAMAGE_BUFF := 1.68

const TIER_SECONDS := 100.0

class FakePlayer extends Node2D:
	var is_dead: bool = false
	var velocity: Vector2 = Vector2.ZERO


var _made: Array[Node] = []


func _track(n: Node) -> Node:
	_made.append(n)
	return n


func _cleanup() -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	GameManager.game_time = 0.0
	NetworkManager.is_multiplayer_active = false


func _spawner() -> Node:
	_cleanup()
	var sp: Node = SpawnerScript.new()
	add_child(sp)
	sp.max_concurrent_enemies = 100000
	sp.tier_duration = 100.0 ## testler 100 sn'lik kademelere göre yazıldı (varsayılan 2026-10-10'da 150 oldu; kademe süresi bu testlerin konusu değil)
	get_tree().current_scene = self
	_track(sp)
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = Vector2(500.0, 500.0)
	_track(p)
	return sp


## Nihai statlı OLMAYAN (boss_base_stats yolu) örnek boss: madde 597'de eski 13'lü BOSS_TIERS tablosu kalktı, formül testleri iskelet3'ü doğrudan doğurur.
func _boss_of_tier(sp: Node, tier: int) -> Array:
	sp._spawn_boss_group(["iskelet3"], tier)
	var found: Array = []
	for e: Node in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(e) and e.get("is_dead") != true and not found.has(e):
			found.append(e)
	return found


## ---------------------------------------------------------------- 1) boss kademe kapısı
func test_tier_does_not_advance_while_the_tier_boss_is_alive_and_resumes_after() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 4.0 * TIER_SECONDS + 76.0 ## kademe 5'in %75'i: boss zamanı (madde 597: ilk boss Kademe 5'te)
	sp._check_boss_tiers()
	assert(sp._tier_bosses.has(5), "5. kademenin bossu doğmalı ve kapı için kaydedilmeli")
	assert(sp._current_tier() == 5, "Boss doğduğunda kademe 5")

	## Kademe 5'in sonu geçti (game_time 550) ama boss sağ: kademe 5'te kalmalı.
	GameManager.game_time = 5.0 * TIER_SECONDS + 50.0
	assert(sp._current_tier() == 5, "Boss sağken kademe 6'ya atlanmamalı, bulunan: %d" % sp._current_tier())
	assert(sp.is_tier_held_by_boss(), "Kapı 'boss tutuyor' demeli")
	GameManager.game_time = 5.0 * TIER_SECONDS + 900.0 ## çok uzun süre geçse de
	assert(sp._current_tier() == 5, "Ne kadar beklenirse beklensin kademe 5'te kalmalı")

	## Boss ölünce saat kaldığı yerden devam eder: hemen 6. kademe, ama ATLAMA yok (ör. 6 değil 10 olmaz).
	for b in sp._tier_bosses[5]:
		b.is_dead = true
	assert(not sp.is_tier_held_by_boss(), "Boss ölünce kapı açılmalı")
	## Saat sınırın 0.001sn altında durmuştu: bir sonraki karede (game_time küçük bir adım ilerleyince) kademe 6 olur -
	## oyun zamanı kaç saat geçmiş olursa olsun 6'dan öteye atlanmaz.
	GameManager.game_time += 0.05
	assert(sp._current_tier() == 6, "Boss ölünce kademe 6 olmalı (birden fazla kademe atlanmamalı), bulunan: %d" % sp._current_tier())
	GameManager.game_time += TIER_SECONDS
	assert(sp._current_tier() == 7, "Sonra normal hızla ilerlemeli")
	_cleanup()


func test_killing_the_boss_before_the_boundary_changes_nothing() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 4.0 * TIER_SECONDS + 76.0
	sp._check_boss_tiers()
	for b in sp._tier_bosses[5]:
		b.is_dead = true
	GameManager.game_time = 5.0 * TIER_SECONDS + 10.0
	assert(sp._current_tier() == 6, "Boss sınırdan önce öldüyse kademe zamanında ilerlemeli, bulunan: %d" % sp._current_tier())
	assert(is_equal_approx(sp._held_total, 0.0), "Hiç bekleme birikmemeli")
	_cleanup()


func test_tiers_without_a_boss_are_never_held() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 1.0 * TIER_SECONDS + 99.0
	assert(sp._current_tier() == 2, "kademe 2")
	GameManager.game_time = 2.0 * TIER_SECONDS + 1.0
	assert(sp._current_tier() == 3, "Bosssuz kademe (2) normal geçilmeli")
	_cleanup()


func test_next_boss_and_the_last_boss_wait_for_the_held_tier() -> void:
	var sp: Node = _spawner()
	## Kademe 5 bossu sağ: kademe 10 (SON) bossunun (zaman 975) tetik zamanı gelse bile kademe saati 500'de bekler.
	GameManager.game_time = 4.0 * TIER_SECONDS + 76.0
	sp._check_boss_tiers()
	GameManager.game_time = 6000.0
	sp._check_boss_tiers()
	sp._check_auto_endless()
	assert(not sp._boss_tiers_spawned.has(10), "Kademe 5 bossu sağken 10. kademe bossu doğmamalı")
	assert(not sp._final_spawned, "son boss da beklemeli")
	assert(sp._current_tier() == 5, "Kademe 5'te kalmalı")
	_cleanup()


func test_new_game_resets_the_hold() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 4.0 * TIER_SECONDS + 76.0
	sp._check_boss_tiers()
	GameManager.game_time = 5000.0
	sp._current_tier()
	assert(sp._held_total > 0.0, "Bekleme birikmiş olmalı")
	GameManager.game_time = 0.0 ## yeni oyun
	assert(sp._current_tier() == 1, "game_time sıfırlanınca kademe 1'e dönmeli, bulunan: %d" % sp._current_tier())
	assert(is_equal_approx(sp._held_total, 0.0), "Bekleme sıfırlanmalı")
	_cleanup()


## ---------------------------------------------------------------- 2) boss can -%15, kalkan -%10
func test_boss_health_and_shield_targets() -> void:
	assert(is_equal_approx(SpawnerScript.BOSS_HEALTH_MULT, PREV_BOSS_HEALTH_MULT * 0.85), "Boss can çarpanı x0.85 olmalı: %s" % SpawnerScript.BOSS_HEALTH_MULT)
	var sp: Node = _spawner()
	var bosses: Array = _boss_of_tier(sp, 3)
	assert(not bosses.is_empty(), "boss doğmalı")
	var boss: Node = bosses[0]
	var family: String = SpawnerScript.ID_FAMILY.get("iskelet3", "")
	var mult: Dictionary = SpawnerScript.FAMILY_MULT.get(family, {"hp": 1.0, "dmg": 1.0})
	var raw: float = (10.0 + 3.0 * 9.0) * float(mult["hp"])
	var prev_health: float = raw * PREV_BOSS_HEALTH_MULT * SpawnerScript.GLOBAL_DEFENSE_BUFF * SpawnerScript.BOSS_HEALTH_SHIELD_MULT
	var prev_shield: float = prev_health * PREV_BOSS_SHIELD_RATIO
	## 2026-09-25 ikinci tur: tüm bosslar can/kalkan/hasar x BOSS_CUT_2026_09_25B (0.85).
	var cut: float = SpawnerScript.BOSS_CUT_2026_09_25B
	var cut_0926: float = SpawnerScript.DURABILITY_CUT_2026_09_26 ## 2026-09-26: tüm yaratıklar can/kalkan x0.9
	assert(is_equal_approx(cut, 0.85), "Boss kesintisi x0.85 olmalı")
	## 2026-10-06 (Kademe 3 denge turu): ilk bossların can/kalkanı BOSS_PACING ile ayrıca ölçeklenir (Kademe 3: x0.6) - kalkan candan türediği için ikisi de.
	var pace: float = SpawnerScript.boss_health_pacing(3) * SpawnerScript.late_durability_mult(3) ## 2026-10-06: BOSS_PACING + Kademe 3+ x0.9
	assert(absf(float(boss.max_health) - prev_health * 0.85 * cut * cut_0926 * pace) < 0.01, "Boss canı öncekinin TAM %%85'i x pacing olmalı: %s (önceki %s)" % [boss.max_health, prev_health])
	assert(absf(float(boss.item_shield_max) - prev_shield * 0.90 * cut * cut_0926 * pace) < 0.01, "Boss kalkanı öncekinin TAM %%90'ı x pacing olmalı: %s (önceki %s)" % [boss.item_shield_max, prev_shield])
	_cleanup()


## ---------------------------------------------------------------- 3) hasar
func test_boss_damage_up_ten_and_all_creature_damage_down_ten() -> void:
	## 2026-09-24 denge turu: bu turun x1.1'inin üstüne tüm bosslara +%60 (x1.6).
	assert(is_equal_approx(SpawnerScript.BOSS_DAMAGE_MULT, PREV_BOSS_DAMAGE_MULT * 1.1 * 1.6), "Boss hasar çarpanı x1.1 x1.6: %s" % SpawnerScript.BOSS_DAMAGE_MULT)
	## 2026-09-25: tüm yaratıkların hasarı +%20 (x1.2), bosslar dahil.
	assert(is_equal_approx(SpawnerScript.GLOBAL_DAMAGE_BUFF, PREV_GLOBAL_DAMAGE_BUFF * 0.9 * 1.2), "Global hasar çarpanı x0.9 x1.2: %s" % SpawnerScript.GLOBAL_DAMAGE_BUFF)

	var sp: Node = _spawner()
	var bosses: Array = _boss_of_tier(sp, 3)
	var boss: Node = bosses[0]
	var family: String = SpawnerScript.ID_FAMILY.get("iskelet3", "")
	var mult: Dictionary = SpawnerScript.FAMILY_MULT.get(family, {"hp": 1.0, "dmg": 1.0})
	var raw_damage: float = (3.0 + 3.0 * 2.2) * float(mult["dmg"])
	var prev_boss_damage: float = raw_damage * PREV_BOSS_DAMAGE_MULT * PREV_GLOBAL_DAMAGE_BUFF
	## Net: x1.1 (boss) x0.9 (tüm yaratıklar) = x0.99, üstüne 2026-09-24 denge turunun x1.6'sı.
	assert(absf(float(boss.contact_damage) - prev_boss_damage * 1.1 * 0.9 * 1.6 * 1.2 * SpawnerScript.BOSS_CUT_2026_09_25B * SpawnerScript.boss_damage_pacing(3) * SpawnerScript.LATE_TIER_DAMAGE_MULT * SpawnerScript.CREATURE_DAMAGE_CUT) < 0.001,
		"Boss hasarı öncekinin x1.1 x0.9'u olmalı: %s (önceki %s)" % [boss.contact_damage, prev_boss_damage])

	var rat: Node = RatScene.instantiate()
	add_child(rat)
	_track(rat)
	rat.contact_damage = 10.0
	sp._apply_global_buff(rat)
	## 2026-10-10: sıradan yaratıkların hasarı/canı/kalkanı +%50 (CREATURE_STAT_BOOST); bosslar (yukarıdaki) bu çarpanı almaz.
	assert(is_equal_approx(SpawnerScript.CREATURE_STAT_BOOST, 1.5), "yaratık güç çarpanı 1,5")
	assert(absf(float(rat.contact_damage) - 10.0 * SpawnerScript.GLOBAL_DAMAGE_BUFF * SpawnerScript.CREATURE_STAT_BOOST * SpawnerScript.CREATURE_DAMAGE_CUT) < 0.001, "Normal yaratık hasarı x GLOBAL_DAMAGE_BUFF x CREATURE_STAT_BOOST olmalı")
	assert(absf(float(rat.contact_damage) - 10.0 * PREV_GLOBAL_DAMAGE_BUFF * 0.9 * 1.2 * 1.5) < 0.001, "Normal yaratık hasarı öncekinin %%90'ı x1.2 x1.5 olmalı: %s" % rat.contact_damage)
	_cleanup()
