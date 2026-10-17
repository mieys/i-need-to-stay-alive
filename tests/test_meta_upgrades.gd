extends Node

## KALICI GELİŞTİRMELER (Ruh Mağazası, scripts/meta_upgrades.gd; kullanıcı isteği 2026-10-13). Hepsi GEÇİCİ kayıt dosyasında.

const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")
const MetaUpgradesScript: GDScript = preload("res://scripts/meta_upgrades.gd")
const SoulShopScript: GDScript = preload("res://scripts/soul_shop_screen.gd")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _tmp: String = ""


func _begin(shards: int = 0) -> void:
	_tmp = "user://test_upgrades_%d.cfg" % Time.get_ticks_usec()
	MetaProgressScript.set_path_override(_tmp)
	MetaProgressScript.set_unlock_all(false)
	if shards > 0:
		var data: Dictionary = MetaProgressScript.load_all()
		data["shards"] = shards
		MetaProgressScript.commit(data)


func _end() -> void:
	if _tmp != "" and FileAccess.file_exists(_tmp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_tmp))
	MetaProgressScript.set_path_override("")
	_tmp = ""


func test_table_is_sane() -> void:
	var seen: Dictionary = {}
	for d: Dictionary in MetaUpgradesScript.LIST:
		var id: String = str(d["id"])
		assert(not seen.has(id), "tekrarlı id: %s" % id)
		seen[id] = true
		assert(int(d["max"]) >= 1 and float(d["per"]) > 0.0 and int(d["first"]) > 0 and int(d["step"]) >= 0, "geçersiz satır: %s" % id)
		assert(str(d["name"]) != "" and str(d["desc"]) != "", "ad/açıklama boş: %s" % id)
	assert(MetaUpgradesScript.LIST.size() == 20, "kullanıcı listesi 20 geliştirme: %d" % MetaUpgradesScript.LIST.size())
	var want: Dictionary = {"pickup": 10, "attack": 15, "atk_speed": 10, "regen": 10, "health": 15, "lifesteal": 10, "speed": 8,
			"shield_amount": 8, "shield_regen": 10, "heal_power": 8, "crit_chance": 10, "crit_damage": 10, "luck": 10, "discount": 5,
			"shield_protection": 5, "free_reroll": 1, "revive": 1, "cooldown": 8, "skill_cost": 5, "shield_pen": 5}
	for id: String in want.keys():
		assert(MetaUpgradesScript.max_level(id) == int(want[id]), "%s seviye sayısı %d olmalı" % [id, int(want[id])])


func test_price_rises_with_level_and_fewer_levels_cost_more() -> void:
	_begin()
	for d: Dictionary in MetaUpgradesScript.LIST:
		if int(d["max"]) > 1:
			assert(int(d["step"]) > 0, "%s: seviye atladıkça fiyat artmalı" % str(d["id"]))
	## Tek seferlik ve az seviyeli geliştirmeler çok seviyelilerin ilk basamağından pahalı olmalı.
	assert(MetaUpgradesScript.next_cost("revive") > MetaUpgradesScript.next_cost("attack"), "tek seferlik dirilme pahalı olmalı")
	assert(MetaUpgradesScript.next_cost("shield_pen") > MetaUpgradesScript.next_cost("pickup"), "5 seviyeli 10 seviyeliden pahalı olmalı")
	_end()


func test_buy_deducts_and_levels_up() -> void:
	_begin(500)
	assert(MetaUpgradesScript.level("pickup") == 0 and is_equal_approx(MetaUpgradesScript.bonus("pickup"), 0.0))
	var c1: int = MetaUpgradesScript.next_cost("pickup")
	assert(MetaUpgradesScript.buy("pickup"))
	assert(MetaUpgradesScript.level("pickup") == 1)
	assert(MetaProgressScript.shards() == 500 - c1, "bakiye düşmedi")
	var c2: int = MetaUpgradesScript.next_cost("pickup")
	assert(c2 > c1, "2. seviye 1.'den pahalı olmalı")
	assert(MetaUpgradesScript.buy("pickup"))
	assert(is_equal_approx(MetaUpgradesScript.bonus("pickup"), 0.16), "2 seviye = %%16: %s" % MetaUpgradesScript.bonus("pickup"))
	assert(MetaUpgradesScript.total_spent() == c1 + c2)
	_end()


func test_cannot_buy_without_shards_or_past_max() -> void:
	_begin(5)
	assert(not MetaUpgradesScript.can_buy("pickup") and not MetaUpgradesScript.buy("pickup"), "5 kıymıkla alınmamalı")
	assert(MetaUpgradesScript.level("pickup") == 0 and MetaProgressScript.shards() == 5)
	_end()
	_begin(100000)
	assert(MetaUpgradesScript.buy("free_reroll"))
	assert(MetaUpgradesScript.next_cost("free_reroll") == 0 and not MetaUpgradesScript.buy("free_reroll"), "tek seferlik ikinci kez alınmamalı")
	assert(MetaUpgradesScript.level("free_reroll") == 1)
	_end()


func test_persists_to_disk() -> void:
	_begin(500)
	assert(MetaUpgradesScript.buy("health") and MetaUpgradesScript.buy("health"))
	var shards_after: int = MetaProgressScript.shards()
	MetaProgressScript.set_path_override(_tmp) ## önbelleği at: dosyadan yeniden oku
	assert(MetaUpgradesScript.level("health") == 2, "seviye diskten gelmedi")
	assert(MetaProgressScript.shards() == shards_after)
	assert(MetaUpgradesScript.total_spent() > 0)
	_end()


func test_reset_charges_a_fee_and_refunds_the_rest() -> void:
	_begin(10000)
	assert(not MetaUpgradesScript.can_reset() and MetaUpgradesScript.reset_all() == -1, "harcama yokken sıfırlanacak şey yok")
	for i in 6:
		assert(MetaUpgradesScript.buy("attack"))
	assert(MetaUpgradesScript.buy("crit_chance"))
	var spent: int = MetaUpgradesScript.total_spent()
	var fee: int = MetaUpgradesScript.reset_fee()
	assert(fee > 0 and fee < spent, "ücret var ve harcanandan az olmalı: %d / %d" % [fee, spent])
	assert(fee >= MetaUpgradesScript.RESET_FEE_MIN or fee == spent)
	var before: int = MetaProgressScript.shards()
	var refund: int = MetaUpgradesScript.reset_all()
	assert(refund == spent - fee, "iade = harcanan - ücret")
	assert(MetaProgressScript.shards() == before + refund)
	assert(MetaUpgradesScript.level("attack") == 0 and MetaUpgradesScript.total_spent() == 0 and MetaUpgradesScript.total_levels() == 0)
	## Sıfırdan tekrar alınabilir, fiyat basamağı başa döner.
	assert(MetaUpgradesScript.next_cost("attack") == int(MetaUpgradesScript.def("attack")["first"]))
	_end()


func test_reset_fee_never_exceeds_spent() -> void:
	_begin(100)
	assert(MetaUpgradesScript.buy("pickup")) ## 10 kıymık: asgari ücret (20) harcanandan büyük -> harcanana kırpılır
	assert(MetaUpgradesScript.reset_fee() == MetaUpgradesScript.total_spent())
	assert(MetaUpgradesScript.reset_refund() == 0)
	_end()


func test_inactive_in_plain_headless_gives_no_bonus() -> void:
	## Yol geçersiz kılması yokken başsız koşu gerçek kaydı okumaz (stat testleri kararlı kalsın).
	MetaProgressScript.set_path_override("")
	if OS.get_environment(MetaProgressScript.ENV_PATH) == "" and DisplayServer.get_name() == "headless":
		assert(not MetaUpgradesScript.active() and is_equal_approx(MetaUpgradesScript.bonus("attack"), 0.0))


func test_format_value() -> void:
	assert(MetaUpgradesScript.format_value("pickup", 0.08) == "+%8", MetaUpgradesScript.format_value("pickup", 0.08))
	assert(MetaUpgradesScript.format_value("lifesteal", 0.002) == "+%0.2", MetaUpgradesScript.format_value("lifesteal", 0.002))
	assert(MetaUpgradesScript.format_value("attack", 6.0) == "+6", MetaUpgradesScript.format_value("attack", 6.0))
	assert(MetaUpgradesScript.format_value("revive", 1.0) == "+1")
	assert(MetaUpgradesScript.format_value("regen", 1.5) == "+1.5")


func test_shop_discount_stacks_with_para_and_caps() -> void:
	_begin(100000)
	var saved: String = GameManager.selected_spiritual
	GameManager.selected_spiritual = "can"
	assert(GameManager.apply_shop_discount(100) == 100, "geliştirme yokken indirim yok")
	assert(MetaUpgradesScript.buy("discount"))
	assert(GameManager.apply_shop_discount(100) == 98, "1 seviye %2: %d" % GameManager.apply_shop_discount(100))
	GameManager.selected_spiritual = "para"
	assert(GameManager.apply_shop_discount(100) == 88, "Para %10 + %2 toplanır: %d" % GameManager.apply_shop_discount(100))
	for i in 4:
		assert(MetaUpgradesScript.buy("discount"))
	assert(GameManager.apply_shop_discount(100) == 80, "Para %10 + 5 seviye %10 = %20: %d" % GameManager.apply_shop_discount(100))
	assert(GameManager.apply_shop_discount(1) == 1, "1 altın 0'a düşmemeli")
	GameManager.selected_spiritual = saved
	_end()


func test_free_reroll_and_revive_are_applied_on_run_reset() -> void:
	_begin(100000)
	var saved_revives: int = GameManager.max_revives
	GameManager.reset()
	assert(GameManager.max_revives == 3 and GameManager.free_rerolls_left == 0 and GameManager.revives_remaining == 3)
	assert(not GameManager.try_use_free_reroll())
	assert(MetaUpgradesScript.buy("free_reroll") and MetaUpgradesScript.buy("revive"))
	GameManager.reset()
	assert(GameManager.max_revives == 4 and GameManager.revives_remaining == 4, "dirilme hakkı +1")
	assert(GameManager.free_rerolls_left == 1)
	assert(GameManager.try_use_free_reroll() and not GameManager.try_use_free_reroll(), "bedava karıştırma koşuda tek kez")
	assert(GameManager.get_peer_revives(12345) == 3, "bildirilmemiş başka oyuncunun hakkı taban 3")
	MetaUpgradesScript.reset_all()
	GameManager.reset()
	GameManager.max_revives = saved_revives
	_end()


func test_player_gets_every_stat_bonus() -> void:
	_begin(1000000)
	var saved_id: int = GameManager.selected_char_id
	GameManager.selected_char_id = 1
	## Önce geliştirmesiz taban.
	var base: Node = PlayerScene.instantiate()
	add_child(base)
	base.set_process(false)
	base.set_physics_process(false)
	var b: Dictionary = {
		"pickup": base.pickup_range_percent, "ap": base.damage_bonus, "fr": base.fire_rate_mult, "regen": base.heal_regen_card_bonus,
		"hp": base.max_health, "ls": base.lifesteal_percent, "spd": base.speed_card_percent, "sh": base.shield_max_percent,
		"shr": base.item_shield_regen_flat, "hsp": base.heal_shield_power, "cc": base.crit_chance_bonus, "cd": base.crit_damage_bonus,
		"luck": base.luck, "prot": base.shield_protection_bonus, "cdr": base.cooldown_reduction_percent,
		"cost": base.item_skill_shield_cost_reduction, "pen": base.shield_pen_percent}
	base.queue_free()
	for id: String in MetaUpgradesScript.ids():
		for i in MetaUpgradesScript.max_level(id):
			assert(MetaUpgradesScript.buy(id), "%s %d. seviye alınamadı" % [id, i + 1])
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	p.set_process(false)
	p.set_physics_process(false)
	assert(is_equal_approx(p.pickup_range_percent, float(b["pickup"]) + 0.8), "toplama: %s" % p.pickup_range_percent)
	assert(is_equal_approx(p.damage_bonus, float(b["ap"]) + 30.0), "saldırı gücü +30: %s" % p.damage_bonus)
	assert(absf(p.fire_rate_mult - float(b["fr"]) * 0.8) < 0.0001, "saldırı hızı: %s" % p.fire_rate_mult)
	assert(is_equal_approx(p.heal_regen_card_bonus, float(b["regen"]) + 5.0), "can yenilenmesi: %s" % p.heal_regen_card_bonus)
	assert(is_equal_approx(p.max_health, float(b["hp"]) + 75.0) and is_equal_approx(p.health, p.max_health), "can +75 ve dolu: %s/%s" % [p.health, p.max_health])
	assert(absf(p.lifesteal_percent - (float(b["ls"]) + 0.02)) < 0.0001, "can çalma: %s" % p.lifesteal_percent)
	assert(absf(p.speed_card_percent - (float(b["spd"]) + 0.12)) < 0.0001, "hareket hızı: %s" % p.speed_card_percent)
	assert(absf(p.shield_max_percent - (float(b["sh"]) + 0.32)) < 0.0001, "kalkan miktarı: %s" % p.shield_max_percent)
	assert(absf(p.item_shield_regen_flat - (float(b["shr"]) + 4.0)) < 0.0001, "kalkan yenilenmesi: %s" % p.item_shield_regen_flat)
	assert(absf(p.heal_shield_power - (float(b["hsp"]) + 0.2)) < 0.0001, "iyileştirme gücü: %s" % p.heal_shield_power)
	assert(absf(p.crit_chance_bonus - (float(b["cc"]) + 0.1)) < 0.0001, "kritik oran: %s" % p.crit_chance_bonus)
	assert(absf(p.crit_damage_bonus - (float(b["cd"]) + 0.3)) < 0.0001, "kritik hasar: %s" % p.crit_damage_bonus)
	assert(absf(p.luck - (float(b["luck"]) + 5.0)) < 0.0001, "şans: %s" % p.luck)
	assert(absf(p.shield_protection_bonus - (float(b["prot"]) + 0.1)) < 0.0001, "kalkan soğurma: %s" % p.shield_protection_bonus)
	assert(absf(p.cooldown_reduction_percent - (float(b["cdr"]) + 0.12)) < 0.0001, "bekleme: %s" % p.cooldown_reduction_percent)
	assert(absf(p.item_skill_shield_cost_reduction - (float(b["cost"]) + 0.2)) < 0.0001, "yetenek bedeli: %s" % p.item_skill_shield_cost_reduction)
	assert(absf(p.shield_pen_percent - (float(b["pen"]) + 0.1)) < 0.0001, "kalkan delme: %s" % p.shield_pen_percent)
	p.queue_free()
	GameManager.selected_char_id = saved_id
	_end()


func test_shop_upgrades_tab_builds_and_buys() -> void:
	_begin(2000)
	var screen: Node = SoulShopScript.new()
	add_child(screen)
	screen._on_tab_pressed("upgrades")
	## 20 geliştirme satırı (açıklama ve sıfırla satırı ızgaranın dışında).
	assert(screen._list.get_child_count() == 20, "satır sayısı: %d" % screen._list.get_child_count())
	var before: int = MetaProgressScript.shards()
	screen._on_upgrade_pressed("pickup")
	assert(MetaUpgradesScript.level("pickup") == 1 and MetaProgressScript.shards() < before)
	## Sıfırlama iki adımlı: ilk basış sadece onay ister.
	screen._on_reset_pressed()
	assert(MetaUpgradesScript.level("pickup") == 1 and screen._confirm_id == "reset")
	screen._on_reset_pressed()
	assert(MetaUpgradesScript.level("pickup") == 0)
	screen.queue_free()
	_end()
