extends Node

## Şans dengesi (madde 595, 2026-11-11): şans kartı 3 / 3,9 / 4,8 / 5,7 (kartta yazan = uygulanan, tek kaynak TierSystem.luck_card_for_tier) ve
## kademe ağırlığına sayılan şans EN ÇOK 20 puan (TierSystem.TIER_LUCK_CAP). Düşme çarpanları sınırsız kalır (test_luck_chest_bonus.gd).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const LevelUpScreenScript = preload("res://scripts/level_up_screen.gd")


func test_luck_card_tiers_give_3_39_48_57() -> void:
	var want: Array = [3.0, 3.9, 4.8, 5.7]
	for tier in range(1, 5):
		assert(is_equal_approx(TierSystem.luck_card_for_tier(tier), want[tier - 1]), "kademe %d tablo: %s" % [tier, TierSystem.luck_card_for_tier(tier)])
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	for tier in range(1, 5):
		var before: float = player.luck
		player.apply_upgrade("luck", tier)
		assert(is_equal_approx(player.luck - before, want[tier - 1]), "kademe %d kartı +%s vermeli: %s" % [tier, want[tier - 1], player.luck - before])
	player.free()


## Kartta gösterilen sayı = uygulanan (eskiden kart "+1" yazıp 1,5 veriyordu).
func test_luck_card_shown_value_matches_applied() -> void:
	assert(LevelUpScreenScript.UPGRADES.any(func(u): return u["id"] == "luck" and u["desc"] == "+3"), "şans kartının ham açıklaması +3 olmalı")
	var screen: Node = LevelUpScreenScript.new()
	var shown: Array = ["+3", "+3.9", "+4.8", "+5.7"]
	for tier in range(1, 5):
		assert(screen._scaled_desc_value("+3", tier, "luck") == shown[tier - 1], "kademe %d kartta yazan: %s" % [tier, screen._scaled_desc_value("+3", tier, "luck")])
	screen.free()


## 20 şanstan fazlası kademe ağırlığını büyütmez (aynı tohumla aynı zar dizisi), 20 altı hâlâ fark yaratır.
func test_tier_roll_counts_at_most_twenty_luck() -> void:
	assert(is_equal_approx(TierSystem.TIER_LUCK_CAP, 20.0))
	seed(4242)
	var capped: Array = []
	for i in 400:
		capped.append(TierSystem.roll(20.0))
	seed(4242)
	var over: Array = []
	for i in 400:
		over.append(TierSystem.roll(60.0))
	assert(capped == over, "60 şans 20 şansla AYNI sonucu vermeli (tavan)")
	seed(4242)
	var mid: Array = []
	for i in 400:
		mid.append(TierSystem.roll(10.0))
	assert(mid != capped, "10 şans 20 şanstan farklı olmalı (tavan altında etki sürer)")


## Efsanevi oranı: 0 şans ~%4, 20 şans ~%13 (tavan); 60 şans da ~%13 (eskiden ~%34).
func test_legendary_share_is_capped() -> void:
	seed(99)
	var n: int = 20000
	var counts := {0.0: 0, 20.0: 0, 60.0: 0}
	for luck_value in counts.keys():
		for i in n:
			if TierSystem.roll(luck_value) == 4:
				counts[luck_value] += 1
	var s0: float = float(counts[0.0]) / n
	var s20: float = float(counts[20.0]) / n
	var s60: float = float(counts[60.0]) / n
	assert(s0 > 0.03 and s0 < 0.05, "0 şans Efsanevi ~%%4: %s" % s0)
	assert(s20 > 0.115 and s20 < 0.15, "20 şans Efsanevi ~%%13: %s" % s20)
	assert(s60 > 0.115 and s60 < 0.15, "60 şans da ~%%13 (tavan): %s" % s60)
