extends Node

## Kalkan efsunları (2026-09-29, bkz. scripts/shield_enchant_defs.gd): havuz kuralları, seçim, limitler, stat toplamı.


func _reset_shield_state() -> void:
	GameManager.shield_standart_level = 1
	GameManager.shield_enchant = ""
	GameManager.shield_enchant_ups = []


func test_start_is_standart_and_pool_offers_three_enchants() -> void:
	_reset_shield_state()
	assert(ShieldEnchantDefs.owned_type() == "shield_standart", "Başlangıç kalkanı Standart olmalı")
	var cards: Array = ShieldEnchantDefs.pool_cards()
	assert(cards.size() == 3, "Efsun seçilmeden 3 kalkan efsunu kartı olmalı, bulunan: %d" % cards.size())
	for c in cards:
		assert(str(c["type"]) == "shield_pick", "Seçim öncesi sadece shield_pick kartları: %s" % str(c))


func test_pick_replaces_standart_and_only_upgrades_follow() -> void:
	_reset_shield_state()
	ShieldEnchantDefs.apply({"type": "shield_pick", "id": "shield_kale"})
	assert(ShieldEnchantDefs.owned_type() == "shield_kale", "Kale seçilince sahip olunan kalkan Kale olmalı")
	var s: Dictionary = ShieldEnchantDefs.stats()
	assert(is_equal_approx(float(s["power"]), 200.0) and is_equal_approx(float(s["absorption"]), 0.75), "Kale tabanı yanlış: %s" % str(s))
	assert(is_equal_approx(float(s["regen"]), 7.0) and is_equal_approx(float(s["delay"]), 8.0), "Kale tabanı yanlış: %s" % str(s))
	## İkinci bir kalkan efsunu seçilemez.
	ShieldEnchantDefs.apply({"type": "shield_pick", "id": "shield_savas"})
	assert(ShieldEnchantDefs.owned_type() == "shield_kale", "İkinci kalkan efsunu öncekinin yerine geçmemeli")
	var cards: Array = ShieldEnchantDefs.pool_cards()
	assert(cards.size() == 3, "Kale'nin 3 geliştirmesi havuzda olmalı, bulunan: %d" % cards.size())
	for c in cards:
		assert(str(c["type"]) == "shield_up", "Seçimden sonra sadece geliştirme kartları: %s" % str(c))


func test_upgrade_limits_and_totals() -> void:
	_reset_shield_state()
	ShieldEnchantDefs.apply({"type": "shield_pick", "id": "shield_enerji"})
	for _i in range(5):
		ShieldEnchantDefs.apply({"type": "shield_up", "index": 1})
	for _i in range(8):
		ShieldEnchantDefs.apply({"type": "shield_up", "index": 2})
	for _i in range(3):
		ShieldEnchantDefs.apply({"type": "shield_up", "index": 0})
	var indices: Array = ShieldEnchantDefs.pool_cards().map(func(c): return int(c["index"]))
	assert(indices == [0], "Limiti dolan geliştirmeler (5 ve 8) havuzdan çıkmalı, sınırsız olan kalmalı: %s" % str(indices))
	var s: Dictionary = ShieldEnchantDefs.stats()
	## 110 + (3+5+8)*50 = 910 kalkan; 9 + 3*4 = 21/sn; %55 + 5*%3 = %70; 6 - 8*0.5 = 2 sn
	assert(is_equal_approx(float(s["power"]), 910.0), "Kalkan toplamı yanlış: %s" % str(s["power"]))
	assert(is_equal_approx(float(s["regen"]), 21.0), "Yenilenme toplamı yanlış: %s" % str(s["regen"]))
	assert(is_equal_approx(float(s["absorption"]), 0.70), "Soğurma toplamı yanlış: %s" % str(s["absorption"]))
	assert(is_equal_approx(float(s["delay"]), 2.0), "Bekleme toplamı yanlış: %s" % str(s["delay"]))
	_reset_shield_state()


func test_savas_has_no_delay_and_two_upgrades() -> void:
	_reset_shield_state()
	ShieldEnchantDefs.apply({"type": "shield_pick", "id": "shield_savas"})
	var s: Dictionary = ShieldEnchantDefs.stats()
	assert(bool(s["always_regen"]), "Savaş Kalkanı savaşta da yenilenmeli")
	assert(ShieldEnchantDefs.pool_cards().size() == 2, "Savaş Kalkanının 2 geliştirmesi olmalı")
	for _i in range(8):
		ShieldEnchantDefs.apply({"type": "shield_up", "index": 1})
	assert(ShieldEnchantDefs.pool_cards().size() == 1, "8 alımdan sonra Geliştirme 2 çıkmamalı")
	_reset_shield_state()


func test_cards_are_epic_and_described() -> void:
	_reset_shield_state()
	var out: Dictionary = {}
	ShieldEnchantDefs.describe({"type": "shield_pick", "id": "shield_savas"}, out)
	assert(str(out.get("title", "")) == "Savaş Kalkanı", "Kart başlığı: %s" % str(out.get("title")))
	## 2026-10-03 sade kart: başlangıç kartı sadece kalkanın nasıl çalıştığını yazar (stat karşılaştırması geliştirme kartında).
	assert(str(out.get("body", "")) == str(ShieldEnchantDefs.TYPES["shield_savas"]["desc"]), "Kalkan seçme kartı çalışma biçimini göstermeli: %s" % str(out.get("body")))
	var up_out: Dictionary = {}
	GameManager.shield_enchant = "shield_savas"
	ShieldEnchantDefs.describe({"type": "shield_up", "index": 0}, up_out)
	assert(str(up_out.get("body", "")).find("→") != -1, "Kalkan geliştirme kartı stat değişimini göstermeli: %s" % str(up_out.get("body")))
	assert(str(up_out.get("lead", "")) == "" and str(up_out.get("note", "")) == "", "Geliştirme kartında açıklama/not olmamalı")
	GameManager.shield_enchant = ""
	assert(ShieldEnchantDefs.CARD_TIER == 3, "Kalkan kartları Epik (mor) görünmeli")
	for key in ShieldEnchantDefs.TYPES:
		assert(float(ShieldEnchantDefs.TYPES[key]["absorption"]) <= 0.92, "%s taban soğurması oyuncu tavanını aşmamalı" % key)
