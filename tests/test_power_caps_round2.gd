extends Node

## Güç sınırları turu (2026-10-20, BALANCE_REV 95, madde 346): aynı parçadan en fazla 6 kopya, Canavarlaştırma Özütü tavanı elitlere de,
## Zamanbükenin Eldiveni bekleme azaltması en çok 0,25 sn'de bir, saldırı hızı tavanı %450, kalkan delme etkin değeri (%40).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const StatsPanelScript: GDScript = preload("res://scripts/stats_panel.gd")

var _players: Array = []


class Dummy extends Node:
	var health: float = 100000.0
	var is_boss: bool = false
	var is_elite: bool = false


func _make_player() -> Node:
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_players.append(p)
	p.max_item_slots = 6
	GameManager.gold = 100000
	return p


func _cleanup() -> void:
	for p in _players:
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()
	GameManager.owned_items = []


func test_same_part_is_capped_at_six_copies() -> void:
	var owned: Array = []
	for i in range(Items.PART_MAX_COPIES - 1):
		owned.append({"key": "tornavida"})
	assert(Items.PART_MAX_COPIES == 6, "aynı parçadan en fazla 6")
	assert(Items.purchase_block_reason("tornavida", owned, 64) == "", "5 kopyadan sonra 6. alınabilir")
	owned.append({"key": "tornavida"})
	assert(Items.purchase_block_reason("tornavida", owned, 64) != "", "6 kopyadan sonra 7. alınamaz")
	assert(Items.purchase_block_reason("bile_tasi", owned, 64) == "", "başka parça etkilenmez")
	## Epik tarifte parça tüketilir: 6 Tornavida varken tarifi Tornavida içeren epik yine alınabilir (kapı yalnız doğrudan parça alımında).
	assert(Items.purchase_block_reason("zirh_soken_hancer", owned, 64) == "", "tarifli alımda parça sınırı işlemez")


func test_canavarlastirma_cap_applies_to_elites_and_bosses() -> void:
	GameManager.owned_items = []
	var p: Node = _make_player()
	if p.owned_weapon_nodes.is_empty():
		p.buy_weapon_copy("dagger", 1)
	p.acquire_item("canavarlastirma_ozutu", {}, 0)
	var w: Node = p.owned_weapon_nodes[0]
	var normal := Dummy.new()
	var elite := Dummy.new()
	elite.is_elite = true
	var boss := Dummy.new()
	boss.is_boss = true
	add_child(normal)
	add_child(elite)
	add_child(boss)
	assert(is_equal_approx(float(w.call("_item_hit_bonus", normal, false)), 2000.0), "normal yaratık: canın %2'si tavansız")
	assert(is_equal_approx(float(w.call("_item_hit_bonus", elite, false)), 40.0), "elit: tavan 40")
	assert(is_equal_approx(float(w.call("_item_hit_bonus", boss, false)), 40.0), "boss: tavan 40")
	for n in [normal, elite, boss]:
		n.free()
	_cleanup()


func test_zamanbuken_cooldown_refund_is_rate_limited() -> void:
	GameManager.owned_items = []
	var p: Node = _make_player()
	p.acquire_item("zamanbukenin_eldiveni", {}, 0)
	p.skill_state = "cooldown"
	p.skill_timer = 10.0
	p.skill2_state = "cooldown"
	p.skill2_timer = 10.0
	p._zamanbuken_last_msec = -100000
	p.item_on_weapon_attack()
	assert(absf(p.skill_timer - 9.7) < 0.001, "ilk atış %%3 azaltır: %f" % p.skill_timer)
	for i in range(20):
		p.item_on_weapon_attack() ## aynı anda onlarca atış (çok silah x yüksek hız)
	assert(absf(p.skill_timer - 9.7) < 0.001, "0,25 sn dolmadan tekrar azaltmaz: %f" % p.skill_timer)
	assert(absf(p.skill2_timer - 9.7) < 0.001, "E de aynı kapıdan: %f" % p.skill2_timer)
	p._zamanbuken_last_msec = Time.get_ticks_msec() - 300 ## 0,3 sn geçmiş gibi (headless'te gerçek bekleme zamanı güvenilmez)
	p.item_on_weapon_attack()
	assert(absf(p.skill_timer - 9.7 * 0.97) < 0.001, "0,25 sn sonra yine azaltır: %f" % p.skill_timer)
	_cleanup()


func test_attack_speed_cap_is_450() -> void:
	assert(is_equal_approx(GameManager.ATTACK_SPEED_CAP_PERCENT, 450.0), "saldırı hızı tavanı %450")


func test_displayed_shield_pen_is_the_effective_cap() -> void:
	assert(is_equal_approx(StatsPanelScript.effective_shield_pen(0.96), 0.40), "ham %96 etkin %40 gösterilir")
	assert(is_equal_approx(StatsPanelScript.effective_shield_pen(0.25), 0.25), "tavanın altı aynen")
