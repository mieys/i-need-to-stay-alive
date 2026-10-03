extends Node

## Kullanıcı isteği doğrulaması:
## 1) Yaratıkların kalkan miktarı can miktarından fazla olmalı, kalkanları
##    hasarı SADECE %30 azaltmalı (eskiden %40; kullanıcı: "yaratıklar aşırı dayanıklı" - bkz. enemy_spawner.gd SHIELD_PROTECTION/
##    REGULAR_SHIELD_RATIO/BOSS_SHIELD_RATIO).
## 2) Can+kalkan barı artık SADECE bosslarda (enemy.gd _create_overhead_bar: "Only bosses keep an overhead bar") ve
##    hep görünür; normal yaratıkta bar yok (2026-10-03 test güncellemesi).

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_rat1.tscn")
const EnemySpawnerScript = preload("res://scripts/enemy_spawner.gd")


func _make_enemy() -> Node:
	var enemy: Node = EnemyScene.instantiate()
	add_child(enemy)
	enemy._ready()
	return enemy


func test_shield_protection_is_fixed_30_percent() -> void:
	assert(is_equal_approx(EnemySpawnerScript.SHIELD_PROTECTION, 0.3),
		"SHIELD_PROTECTION 0.3 (%%30) olmalı, bulunan: %s" % EnemySpawnerScript.SHIELD_PROTECTION)


func test_shield_ratio_exceeds_health_for_regular_and_boss() -> void:
	assert(EnemySpawnerScript.REGULAR_SHIELD_RATIO > 1.0,
		"Normal yaratık kalkan oranı can miktarından fazla olmalı (>1.0), bulunan: %s" % EnemySpawnerScript.REGULAR_SHIELD_RATIO)
	assert(EnemySpawnerScript.BOSS_SHIELD_RATIO > 1.0,
		"Boss kalkan oranı can miktarından fazla olmalı (>1.0), bulunan: %s" % EnemySpawnerScript.BOSS_SHIELD_RATIO)


func test_enable_item_shield_produces_shield_bigger_than_health() -> void:
	var enemy: Node = _make_enemy()
	enemy.enable_item_shield(EnemySpawnerScript.SHIELD_PROTECTION, EnemySpawnerScript.REGULAR_SHIELD_RATIO)
	assert(enemy.item_shield_max > enemy.max_health,
		"Kalkan miktarı can miktarından fazla olmalı: shield=%s health=%s" % [enemy.item_shield_max, enemy.max_health])
	enemy.queue_free()


## Kalkanın emdiği pay = SHIELD_PROTECTION (zırh/kritik/efsun hesabına girmeyen doğrudan hasar yolu).
func test_shield_absorbs_exactly_protection_share_of_hit() -> void:
	var enemy: Node = _make_enemy()
	## kalkan havuzu = can x oran: fare tier 1'de ~6 can (havuz ~7) - 100'lük vuruş havuzu bitirirdi, oran ölçülemezdi
	enemy.max_health = 1000.0
	enemy.health = 1000.0
	enemy.enable_item_shield(EnemySpawnerScript.SHIELD_PROTECTION, EnemySpawnerScript.REGULAR_SHIELD_RATIO)
	var health_before: float = enemy.health
	var shield_before: float = enemy.item_shield_hp
	enemy._apply_damage(100.0, false, 0.0)
	assert(absf((shield_before - enemy.item_shield_hp) - 30.0) < 0.01,
		"100 hasarın %%30'u (30) kalkana gitmeli, bulunan: %s" % (shield_before - enemy.item_shield_hp))
	assert(absf((health_before - enemy.health) - 70.0) < 0.01,
		"Cana 70 kalmalı, bulunan: %s" % (health_before - enemy.health))
	enemy.queue_free()


func test_regular_enemy_has_no_overhead_bar() -> void:
	var enemy: Node = _make_enemy()
	assert(enemy._overhead_bar == null, "Normal yaratıkta can barı olmamalı (sadece bosslar)")
	enemy.take_damage(1.0)
	assert(enemy._overhead_bar == null, "Hasar alınca da normal yaratıkta bar oluşmamalı")
	enemy.queue_free()


func test_boss_bar_always_visible_and_never_auto_hides() -> void:
	var enemy: Node = _make_enemy()
	enemy.apply_boss_stats(1000.0, 10.0, 1.7, 5)
	enemy.set_overhead_bar_always_visible()
	assert(enemy._overhead_bar != null and enemy._overhead_bar.visible == true, "Boss barı hemen görünür olmalı")
	enemy.take_damage(1.0)
	## kaybolma sayacını işleten tik (C++'a kayıtlıysa köprünün tiki, değilse fizik adımı)
	if int(enemy.get("_ew_slot")) >= 0:
		enemy._ew_tick(100.0)
	else:
		enemy._physics_process(100.0)
	assert(enemy._overhead_bar.visible == true, "Boss barı asla otomatik kaybolmamalı")
	enemy.queue_free()