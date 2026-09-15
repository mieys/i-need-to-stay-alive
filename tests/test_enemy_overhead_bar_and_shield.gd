extends Node

## Kullanıcı isteği doğrulaması:
## 1) Yaratıkların kalkan miktarı can miktarından fazla olmalı, kalkanları
##    hasarı SADECE %40 azaltmalı (bkz. enemy_spawner.gd SHIELD_PROTECTION/
##    REGULAR_SHIELD_RATIO/BOSS_SHIELD_RATIO).
## 2) Hasar alan yaratığın üstünde can+kalkan barı görünmeli, hasarsız 1sn
##    sonra kaybolmalı (bkz. enemy.gd _create_overhead_bar/_show_overhead_bar).

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_rat1.tscn")
const EnemySpawnerScript = preload("res://scripts/enemy_spawner.gd")


func _make_enemy() -> Node:
	var enemy: Node = EnemyScene.instantiate()
	add_child(enemy)
	enemy._ready()
	return enemy


func test_shield_protection_is_fixed_40_percent() -> void:
	assert(is_equal_approx(EnemySpawnerScript.SHIELD_PROTECTION, 0.4),
		"SHIELD_PROTECTION 0.4 (%%40) olmalı, bulunan: %s" % EnemySpawnerScript.SHIELD_PROTECTION)


func test_shield_ratio_exceeds_health_for_regular_and_boss() -> void:
	assert(EnemySpawnerScript.REGULAR_SHIELD_RATIO > 1.0,
		"Normal yaratık kalkan oranı can miktarından fazla olmalı (>1.0), bulunan: %s" % EnemySpawnerScript.REGULAR_SHIELD_RATIO)
	assert(EnemySpawnerScript.BOSS_SHIELD_RATIO > 1.0,
		"Boss kalkan oranı can miktarından fazla olmalı (>1.0), bulunan: %s" % EnemySpawnerScript.BOSS_SHIELD_RATIO)


func test_enable_item_shield_produces_shield_bigger_than_health() -> void:
	var enemy: Node = _make_enemy()
	enemy.enable_item_shield(0.4, 1.3)
	assert(enemy.item_shield_max > enemy.max_health,
		"Kalkan miktarı can miktarından fazla olmalı: shield=%s health=%s" % [enemy.item_shield_max, enemy.max_health])
	enemy.queue_free()


func test_shield_reduces_damage_by_exactly_40_percent_of_hit() -> void:
	var enemy: Node = _make_enemy()
	enemy.enable_item_shield(0.4, 1.3)
	var health_before: float = enemy.health
	var shield_before: float = enemy.item_shield_hp
	enemy.take_damage(100.0)
	var shield_absorbed: float = shield_before - enemy.item_shield_hp
	assert(is_equal_approx(shield_absorbed, 40.0),
		"100 hasarın %%40'ı (40) kalkana gitmeli, bulunan: %s" % shield_absorbed)
	enemy.queue_free()


func test_overhead_bar_created_and_hidden_by_default() -> void:
	var enemy: Node = _make_enemy()
	assert(enemy._overhead_bar != null, "Overhead bar oluşturulmalı")
	assert(enemy._overhead_bar.visible == false,
		"Normal yaratıkta bar başlangıçta gizli olmalı")
	enemy.queue_free()


func test_overhead_bar_shows_on_damage_and_hides_after_delay() -> void:
	var enemy: Node = _make_enemy()
	enemy.take_damage(1.0)
	assert(enemy._overhead_bar.visible == true,
		"Hasar alınca bar görünür olmalı")
	assert(is_equal_approx(enemy._overhead_bar_hide_timer, enemy.OVERHEAD_BAR_HIDE_DELAY),
		"Hasar alınca kaybolma sayacı sıfırlanmalı")

	# Simulate _physics_process ticking the hide timer past the delay.
	enemy._physics_process(enemy.OVERHEAD_BAR_HIDE_DELAY + 0.1)
	assert(enemy._overhead_bar.visible == false,
		"1 saniye hasarsız kalınca bar kaybolmalı")
	enemy.queue_free()


func test_boss_bar_always_visible_and_never_auto_hides() -> void:
	var enemy: Node = _make_enemy()
	enemy.set_overhead_bar_always_visible()
	assert(enemy._overhead_bar.visible == true, "Boss barı hemen görünür olmalı")
	enemy._physics_process(100.0)
	assert(enemy._overhead_bar.visible == true, "Boss barı asla otomatik kaybolmamalı")
	enemy.queue_free()
