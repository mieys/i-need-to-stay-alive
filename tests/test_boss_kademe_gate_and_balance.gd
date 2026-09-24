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
	get_tree().current_scene = self
	_track(sp)
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = Vector2(500.0, 500.0)
	_track(p)
	return sp


func _boss_of_tier(sp: Node, tier: int) -> Array:
	sp._spawn_boss_group(SpawnerScript.BOSS_TIERS[tier], tier)
	var found: Array = []
	for e: Node in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(e) and e.get("is_dead") != true and not found.has(e):
			found.append(e)
	return found


## ---------------------------------------------------------------- 1) boss kademe kapısı
func test_tier_does_not_advance_while_the_tier_boss_is_alive_and_resumes_after() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 2.0 * TIER_SECONDS + 76.0 ## kademe 3'ün %75'i: boss zamanı
	sp._check_boss_tiers()
	assert(sp._tier_bosses.has(3), "3. kademenin bossu doğmalı ve kapı için kaydedilmeli")
	assert(sp._current_tier() == 3, "Boss doğduğunda kademe 3")

	## Kademe 3'ün sonu geçti (game_time 350) ama boss sağ: kademe 3'te kalmalı.
	GameManager.game_time = 3.0 * TIER_SECONDS + 50.0
	assert(sp._current_tier() == 3, "Boss sağken kademe 4'e atlanmamalı, bulunan: %d" % sp._current_tier())
	assert(sp.is_tier_held_by_boss(), "Kapı 'boss tutuyor' demeli")
	GameManager.game_time = 3.0 * TIER_SECONDS + 900.0 ## çok uzun süre geçse de
	assert(sp._current_tier() == 3, "Ne kadar beklenirse beklensin kademe 3'te kalmalı")

	## Boss ölünce saat kaldığı yerden devam eder: hemen 4. kademe, ama ATLAMA yok (ör. 4 değil 10 olmaz).
	for b in sp._tier_bosses[3]:
		b.is_dead = true
	assert(not sp.is_tier_held_by_boss(), "Boss ölünce kapı açılmalı")
	## Saat sınırın 0.001sn altında durmuştu: bir sonraki karede (game_time küçük bir adım ilerleyince) kademe 4 olur -
	## oyun zamanı kaç saat geçmiş olursa olsun 4'ten öteye atlanmaz.
	GameManager.game_time += 0.05
	assert(sp._current_tier() == 4, "Boss ölünce kademe 4 olmalı (birden fazla kademe atlanmamalı), bulunan: %d" % sp._current_tier())
	GameManager.game_time += TIER_SECONDS
	assert(sp._current_tier() == 5, "Sonra normal hızla ilerlemeli")
	_cleanup()


func test_killing_the_boss_before_the_boundary_changes_nothing() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 2.0 * TIER_SECONDS + 76.0
	sp._check_boss_tiers()
	for b in sp._tier_bosses[3]:
		b.is_dead = true
	GameManager.game_time = 3.0 * TIER_SECONDS + 10.0
	assert(sp._current_tier() == 4, "Boss sınırdan önce öldüyse kademe zamanında ilerlemeli, bulunan: %d" % sp._current_tier())
	assert(is_equal_approx(sp._held_total, 0.0), "Hiç bekleme birikmemeli")
	_cleanup()


func test_tiers_without_a_boss_are_never_held() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 1.0 * TIER_SECONDS + 99.0
	assert(sp._current_tier() == 2, "kademe 2")
	GameManager.game_time = 2.0 * TIER_SECONDS + 1.0
	assert(sp._current_tier() == 3, "Bosssuz kademe (2) normal geçilmeli")
	_cleanup()


func test_next_boss_and_final_wait_for_the_held_tier() -> void:
	var sp: Node = _spawner()
	## Kademe 3 bossu sağ: kademe 6 bossunun (zaman 575) ve Final'in (1500) tetik zamanı gelse bile kademe saati 300'de bekler.
	GameManager.game_time = 2.0 * TIER_SECONDS + 76.0
	sp._check_boss_tiers()
	GameManager.game_time = 6000.0
	sp._check_boss_tiers()
	sp._check_final_tier()
	assert(not sp._boss_tiers_spawned.has(6), "Kademe 3 bossu sağken 6. kademe bossu doğmamalı")
	assert(not sp._final_spawned, "Final Kademe de beklemeli")
	assert(sp._current_tier() == 3, "Kademe 3'te kalmalı")
	_cleanup()


func test_new_game_resets_the_hold() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 2.0 * TIER_SECONDS + 76.0
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
	assert(absf(float(boss.max_health) - prev_health * 0.85) < 0.01, "Boss canı öncekinin TAM %%85'i olmalı: %s (önceki %s)" % [boss.max_health, prev_health])
	assert(absf(float(boss.item_shield_max) - prev_shield * 0.90) < 0.01, "Boss kalkanı öncekinin TAM %%90'ı olmalı: %s (önceki %s)" % [boss.item_shield_max, prev_shield])
	_cleanup()


## ---------------------------------------------------------------- 3) hasar
func test_boss_damage_up_ten_and_all_creature_damage_down_ten() -> void:
	## 2026-09-24 denge turu: bu turun x1.1'inin üstüne tüm bosslara +%60 (x1.6).
	assert(is_equal_approx(SpawnerScript.BOSS_DAMAGE_MULT, PREV_BOSS_DAMAGE_MULT * 1.1 * 1.6), "Boss hasar çarpanı x1.1 x1.6: %s" % SpawnerScript.BOSS_DAMAGE_MULT)
	assert(is_equal_approx(SpawnerScript.GLOBAL_DAMAGE_BUFF, PREV_GLOBAL_DAMAGE_BUFF * 0.9), "Global hasar çarpanı x0.9: %s" % SpawnerScript.GLOBAL_DAMAGE_BUFF)

	var sp: Node = _spawner()
	var bosses: Array = _boss_of_tier(sp, 3)
	var boss: Node = bosses[0]
	var family: String = SpawnerScript.ID_FAMILY.get("iskelet3", "")
	var mult: Dictionary = SpawnerScript.FAMILY_MULT.get(family, {"hp": 1.0, "dmg": 1.0})
	var raw_damage: float = (3.0 + 3.0 * 2.2) * float(mult["dmg"])
	var prev_boss_damage: float = raw_damage * PREV_BOSS_DAMAGE_MULT * PREV_GLOBAL_DAMAGE_BUFF
	## Net: x1.1 (boss) x0.9 (tüm yaratıklar) = x0.99, üstüne 2026-09-24 denge turunun x1.6'sı.
	assert(absf(float(boss.contact_damage) - prev_boss_damage * 1.1 * 0.9 * 1.6) < 0.001,
		"Boss hasarı öncekinin x1.1 x0.9'u olmalı: %s (önceki %s)" % [boss.contact_damage, prev_boss_damage])

	var rat: Node = RatScene.instantiate()
	add_child(rat)
	_track(rat)
	rat.contact_damage = 10.0
	sp._apply_global_buff(rat)
	assert(absf(float(rat.contact_damage) - 10.0 * SpawnerScript.GLOBAL_DAMAGE_BUFF) < 0.001, "Normal yaratık hasarı x GLOBAL_DAMAGE_BUFF olmalı")
	assert(absf(float(rat.contact_damage) - 10.0 * PREV_GLOBAL_DAMAGE_BUFF * 0.9) < 0.001, "Normal yaratık hasarı öncekinin TAM %%90'ı olmalı: %s" % rat.contact_damage)
	_cleanup()
