extends Node

## Otomatik kart seçimi (2026-10-19, auto_pick.gd): ayar UISound.auto_pick_cards; puan = kademe x statın durum değeri.

const AutoPick = preload("res://scripts/auto_pick.gd")


func _fake_player(hp: float, max_hp: float, capped: Array) -> Node:
	var s := GDScript.new()
	s.source_code = "extends Node\nvar health: float = 0.0\nvar max_health: float = 0.0\nvar capped: Array = []\n" \
			+ "func is_stat_capped(n: String) -> bool:\n\treturn capped.has(n)\n"
	s.reload()
	var n := Node.new()
	n.set_script(s)
	n.set("health", hp)
	n.set("max_health", max_hp)
	n.set("capped", capped)
	return n


func test_higher_tier_and_better_stat_wins() -> void:
	var p: Node = _fake_player(100.0, 100.0, [])
	assert(AutoPick.best_upgrade_index(["speed", "damage", "luck"], [1, 1, 1], [true, true, true], p) == 1, "aynı kademede saldırı gücü")
	assert(AutoPick.best_upgrade_index(["speed", "damage", "luck"], [3, 1, 1], [true, true, true], p) == 0, "Epik Hız > Sıradan Saldırı Gücü")
	assert(AutoPick.best_upgrade_index(["speed", "damage", "luck"], [1, 1, 1], [true, false, true], p) == 0, "basılamayan kart atlanır")
	assert(AutoPick.best_upgrade_index([], [], [], p) == -1, "kart yoksa -1")
	p.free()


func test_low_health_prefers_defense_and_capped_stats_are_skipped() -> void:
	var low: Node = _fake_player(30.0, 100.0, [])
	assert(AutoPick.best_upgrade_index(["damage", "max_health"], [1, 1], [true, true], low) == 1, "can yarının altında: Can kartı")
	low.free()
	var capped: Node = _fake_player(100.0, 100.0, ["dodge_chance", "crit_chance_bonus"])
	assert(AutoPick.best_upgrade_index(["dodge", "crit_chance", "luck"], [4, 4, 1], [true, true, true], capped) == 2, "sınırdaki statlar boşa gitmez")
	capped.free()


func test_evolution_prefers_the_final_card_and_setting_round_trips() -> void:
	assert(AutoPick.best_tier_index([3, 4, 3], [true, true, true]) == 1, "FİNAL evrim önce")
	assert(AutoPick.best_tier_index([3, 3], [false, true]) == 1, "gizli kart atlanır")
	var before: bool = UISound.auto_pick_cards
	UISound.auto_pick_cards = true
	assert(AutoPick.enabled(), "ayar açık")
	UISound.auto_pick_cards = false
	assert(not AutoPick.enabled(), "ayar kapalı")
	UISound.auto_pick_cards = before
