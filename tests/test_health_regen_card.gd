extends Node

## Kullanıcı isteği (2026-10-02): can yenilenmesi statı "5 saniyede X can"; can yenilenmesi veren statlar x3 (başlangıç
## 0.5 -> 1.5), tier 1 level atlama kartı +2.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const LevelUpScreenScript = preload("res://scripts/level_up_screen.gd")


func test_health_regen_card_grants_two_per_card() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)

	var start: float = player.heal_regen_card_bonus
	assert(is_equal_approx(start, 1.5), "Başlangıç can yenilenmesi 1.5 olmalı, bulunan: %s" % start)
	player.apply_upgrade("health_regen")
	assert(is_equal_approx(player.heal_regen_card_bonus - start, 2.0),
		"Tier 1 kart +2 vermeli, bulunan: %s" % (player.heal_regen_card_bonus - start))
	player.apply_upgrade("health_regen")
	assert(is_equal_approx(player.heal_regen_card_bonus - start, 4.0),
		"İki kart sonrası +4 olmalı (additive), bulunan: %s" % (player.heal_regen_card_bonus - start))
	player.queue_free()


## Madde 475: stat değeri "5 sn'de toplam can" ama HER SANİYE beşte biri işler (3 -> saniyede 0,6), toplu 5 sn tiki yok.
func test_stat_regen_heals_every_second() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.heal_regen_bonus = 0.0
	player.heal_regen_card_bonus = 3.0
	player.max_health = 100.0
	player.health = 50.0
	player._health_regen_tick_timer = 0.0
	player._health_regen_tick_pending = 0.0
	var per_sec: float = 3.0 / 5.0 * player.heal_power_mult()
	for i in 11: ## ilk saniyelik tik (0,1'lik adımlar toplamı 1,0'a 11. adımda ulaşır)
		player._process_regen(0.1)
	assert(player.health > 50.0 + per_sec * 0.95 and player.health < 50.0 + per_sec * 1.15, "1. saniyede ~+0,6 can olmalı: %s" % player.health)
	for i in 44: ## toplam 5,5 sn, 5 tik
		player._process_regen(0.1)
	assert(player.health > 50.0 + per_sec * 4.95 and player.health < 50.0 + per_sec * 5.55, "5,5 sn'de ~+3 can olmalı (toplam hız aynı): %s" % player.health)
	assert(absf(float(player.call("get_health_regen_per_sec")) - per_sec) < 0.001, "HUD göstergesi saniyelik hızı okumalı")
	player.queue_free()


func test_level_up_screen_description_matches() -> void:
	assert(LevelUpScreenScript.UPGRADES.any(func(u): return u["id"] == "health_regen" and u["desc"] == "+2"),
		"health_regen kartının açıklaması +2 olmalı")


## 2026-10-10 (kullanıcı): Can Yenilenmesi kartı kademe 1-4 = 2 / 4 / 6 / 8 (kartta yazan ile uygulanan TEK kaynak: TierSystem.regen_card_for_tier).
func test_health_regen_card_tiers_give_2_4_6_8() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	var want: Array = [2.0, 4.0, 6.0, 8.0]
	for tier in range(1, 5):
		assert(is_equal_approx(TierSystem.regen_card_for_tier(tier), want[tier - 1]), "kademe %d tablo" % tier)
		var before: float = player.heal_regen_card_bonus
		player.apply_upgrade("health_regen", tier)
		assert(is_equal_approx(player.heal_regen_card_bonus - before, want[tier - 1]), "kademe %d kartı +%s vermeli: %s" % [tier, want[tier - 1], player.heal_regen_card_bonus - before])
	player.free()


## 2026-10-10 (kullanıcı): kalkan delme üst sınırı %40 ve level atlama havuzunda Kalkan Delme kartı yok.
func test_shield_pen_card_removed_and_total_pen_capped_at_forty_percent() -> void:
	for u: Dictionary in LevelUpScreenScript.UPGRADES:
		assert(str(u["id"]) != "shield_pen_percent", "Kalkan Delme kartı havuzda olmamalı")
	var W: GDScript = load("res://scripts/weapon.gd")
	assert(is_equal_approx(W.SHIELD_PEN_CAP, 0.40))
	assert(is_equal_approx(W.cap_shield_pen(0.95), 0.40) and is_equal_approx(W.cap_shield_pen(0.25), 0.25), "toplam delme en çok %40")
	assert(is_equal_approx(W.cap_shield_pen(0.0, true), 1.0), "gerçek hasar silahı (Tüftüf) istisna")
