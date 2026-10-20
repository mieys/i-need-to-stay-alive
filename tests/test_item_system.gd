extends Node

## Yeni eşya sistemi (kullanıcı tasarımı 2026-10-02, bkz. scripts/items.gd): veri bütünlüğü, tarifli satın alma
## (sahip olunan parçalar tüketilip fiyattan düşülür), kademe slot sınırları, satış, pasifler, sandık altını paylaşımı.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const ChestDropScript: GDScript = preload("res://scripts/chest_drop.gd")

var _players: Array = []


func _reset() -> void:
	GameManager.owned_items = []
	GameManager.gold = 100000


func _make_player() -> Node:
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_players.append(p)
	p.max_item_slots = 6
	return p


func _cleanup() -> void:
	for p in _players:
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()
	_reset()


## 2026-10-13: eşya kaynaklı bekleme azaltma da %60'ta kırpılır (eskiden sadece kart yolu kırpıyordu; 20 Kol Saati beklemeyi sıfırlıyordu).
func test_item_cooldown_reduction_is_capped_but_raw_stays_symmetric() -> void:
	var p: Node = _make_player()
	p._apply_item_stats("kol_saati", 1.0)
	assert(is_equal_approx(p.get_cooldown_reduction(), 0.05), "tek Kol Saati %5")
	p.cooldown_reduction_percent = 1.5 ## 30 Kol Saati
	assert(is_equal_approx(p.get_cooldown_reduction(), p.COOLDOWN_REDUCTION_CAP), "etkin azaltma %60'ı aşmamalı")
	p._apply_item_stats("kol_saati", -1.0)
	assert(is_equal_approx(p.cooldown_reduction_percent, 1.45), "satış ham değeri simetrik geri almalı")
	p.cooldown_reduction_percent = 0.0
	_cleanup()


## 2026-10-13: sınırına ulaşmış stat içeren eşyalar sandık havuzundan elenir.
func test_chest_pool_skips_items_with_capped_stats() -> void:
	var ChestMenu: GDScript = preload("res://scripts/chest_menu.gd")
	var p: Node = _make_player()
	assert(ChestMenu.item_pool(false, 1, p).has("kol_saati"), "sınır dolmadan Kol Saati çıkabilir")
	p.cooldown_reduction_percent = p.COOLDOWN_REDUCTION_CAP
	assert(p.is_stat_capped("cooldown_reduction_percent") and p.item_has_capped_stat("kol_saati"))
	var pool: Array = ChestMenu.item_pool(false, 1, p)
	assert(not pool.has("kol_saati") and not pool.is_empty(), "bekleme sınırı dolunca Kol Saati çıkmaz, diğerleri çıkar")
	## Kaçınma sınırı dolunca Ayakkabı Bağcığı (hız + kaçınma) da elenir.
	p.dodge_chance = p.dodge_cap()
	assert(not ChestMenu.item_pool(false, 1, p).has("ayakkabi_bagcigi"), "kaçınma sınırında Ayakkabı Bağcığı elenir")
	assert(ChestMenu.item_pool(false, 1).has("kol_saati"), "oyuncu verilmezse süzme yok")
	_cleanup()


# ------------------------------------------------------------------ veri
func test_defs_are_consistent() -> void:
	assert(Items.KEYS.size() == 50, "11 parça + 15 epik + 24 efsanevi = 50 (2026-10-10: +1 epik, +7 efsanevi tarifsiz; 2026-10-18: Ruhların Maskesi efsanevi), bulunan %d" % Items.KEYS.size())
	assert(Items.KEYS.size() == Items.DEFS.size(), "KEYS ile DEFS aynı eşyalar")
	var counts: Array = [0, 0, 0]
	var player: Node = _make_player()
	for k in Items.KEYS:
		var kd: int = Items.kademe(k)
		counts[kd - 1] += 1
		var rec: Array = Items.recipe(k)
		if kd == 1:
			assert(rec.is_empty(), "%s: parçanın tarifi olmamalı" % k)
		elif rec.is_empty():
			assert(Items.cost(k) > 0, "%s: tarifsiz eşyanın (2026-10-10) düz fiyatı olmalı" % k)
		else:
			var sum: int = 0
			for c in rec:
				assert(Items.DEFS.has(c), "%s: bilinmeyen bileşen %s" % [k, c])
				assert(Items.kademe(c) < kd, "%s: bileşen %s alt kademe olmalı" % [k, c])
				sum += Items.cost(c)
			assert(sum == Items.cost(k), "%s: fiyat (%d) bileşenlerin toplamı (%d) olmalı (belge)" % [k, Items.cost(k), sum])
		assert(ResourceLoader.exists(Items.icon_path(k)), "%s: ikon yok" % k)
		for stat in Items.get_def(k).get("stats", {}):
			assert(stat in player, "%s: player.gd'de '%s' statı yok" % [k, stat])
	assert(counts == [11, 15, 24], "kademe sayıları: %s (2026-10-18: Ruhların Maskesi epikten efsaneviye geçti)" % str(counts))
	_cleanup()


# ------------------------------------------------------------------ tarif / indirim / slot
func test_owned_components_discount_and_are_consumed() -> void:
	_reset()
	var player: Node = _make_player()
	var hp0: float = player.max_health
	var ap0: float = player.damage_bonus
	assert(player.acquire_item("kanli_yakut", {}, 330), "parça alınabilmeli")
	assert(is_equal_approx(player.max_health - hp0, 50.0) and is_equal_approx(player.damage_bonus - ap0, 5.0), "Kanlı Yakut statları")
	var plan: Dictionary = Items.plan_purchase("kemik_kolye", GameManager.owned_items)
	assert(int(plan["cost"]) == 270, "Kemik Kolye 600 - Kanlı Yakut 330 = 270, bulunan %d" % int(plan["cost"]))
	assert((plan["consume"] as Array).size() == 1, "yakut tüketilmeli")
	assert(player.acquire_item("kemik_kolye", plan, int(plan["cost"])), "epik alınabilmeli")
	assert(GameManager.owned_items.size() == 1 and str(GameManager.owned_items[0]["key"]) == "kemik_kolye", "parça yerine epik kalmalı")
	assert(is_equal_approx(player.max_health - hp0, 80.0), "epiğin canı (80) - parçanın statı geri alınmalı, fark: %s" % (player.max_health - hp0))
	assert(is_equal_approx(player.damage_bonus - ap0, 5.0), "Kemik Kolye +5 saldırı gücü")
	_cleanup()


func test_recursive_components_for_legendary() -> void:
	_reset()
	var player: Node = _make_player()
	## Anka = Yenilenme Özütü x2 + Yaşam Kristali; Yenilenme Özütü = Yaşam x2 + Tılsım. 2 yaşam kristali alt parçadan düşmeli.
	player.acquire_item("yasam_kristali", {}, 0)
	player.acquire_item("yasam_kristali", {}, 0)
	var plan: Dictionary = Items.plan_purchase("anka_kusunun_kalbi", GameManager.owned_items)
	assert(int(plan["cost"]) == 1850 - 540, "1850 - 2x270 = 1310, bulunan %d" % int(plan["cost"]))
	assert((plan["consume"] as Array).size() == 2, "iki kristal de tüketilmeli")
	_cleanup()


## 2026-10-19 (maç analizi): aynı 1. kademe parçanın her sahip olunan kopyası fiyatı +%10 artırır, en çok x2; tarifli alım etkilenmez.
func test_repeated_part_price_rises() -> void:
	var owned: Array = []
	assert(int(Items.plan_purchase("tornavida", owned)["cost"]) == 320, "ilk kopya taban fiyat")
	for i in range(3):
		owned.append({"key": "tornavida"})
	assert(int(Items.plan_purchase("tornavida", owned)["cost"]) == 416, "3 kopya: 320 x 1,3 = 416")
	for i in range(12):
		owned.append({"key": "tornavida"})
	assert(int(Items.plan_purchase("tornavida", owned)["cost"]) == 640, "15 kopya: tavan x2 = 640")
	assert(int(Items.plan_purchase("bile_tasi", owned)["cost"]) == 350, "başka parça etkilenmez")
	assert(Items.repeat_mult("kemik_kolye", owned) == 1.0 and Items.part_copies("kemik_kolye", owned) == 0, "epik/efsanevide çarpan yok")
	## Tarifte eksik parça, başka parçanın kopyalarından etkilenmez: 4 Yaşam Kristali var, Kemik Kolye = Kanlı Yakut + Yaşam Kristali.
	var owned2: Array = []
	for i in range(4):
		owned2.append({"key": "yasam_kristali"})
	var plan: Dictionary = Items.plan_purchase("kemik_kolye", owned2)
	assert(int(plan["cost"]) == 330 and (plan["consume"] as Array).size() == 1, "tarifte yakut taban fiyat, kristal tüketilir: %s" % str(plan))


## 2026-10-17 (kullanıcı: "bazı efsanevi eşyaların alt parçaları yok, özelliklerine göre ata"): artık HİÇBİR efsanevi eşya tarifsiz değil;
## yeni tarifler de sahip olunan parçaları tüketip fiyattan düşer (fiyat = bileşen toplamı kuralı test_defs_is_consistent'te).
func test_every_legendary_has_a_recipe_and_new_recipes_discount() -> void:
	_reset()
	for k in Items.KEYS:
		if Items.kademe(k) == Items.KADEME_EFSANEVI:
			assert(not (Items.recipe(k) as Array).is_empty(), "%s: efsanevi eşyanın alt parçaları (tarifi) olmalı" % k)
	## Kıyamet Bıçağı = Savaşçı Bileyi + Savaşçının Kılıcı + Zırh Söken Hançer + Bile Taşı: sahip olunan epik + parça tüketilir.
	var player: Node = _make_player()
	player.acquire_item("savasci_bileyi", {}, 0)
	player.acquire_item("bile_tasi", {}, 0)
	var plan: Dictionary = Items.plan_purchase("kiyamet_bicagi", GameManager.owned_items)
	assert(int(plan["cost"]) == Items.cost("kiyamet_bicagi") - Items.cost("savasci_bileyi") - Items.cost("bile_tasi"), "Kıyamet Bıçağı: bileyi + bile taşı fiyattan düşmeli, bulunan %d" % int(plan["cost"]))
	assert((plan["consume"] as Array).size() == 2, "bileyi ve bile taşı tüketilmeli")
	## Tanrının Eli'nin (anka_muhru) dirilişi tarifle bozulmaz: parçalar tüketilip eşya alınınca pasif hâlâ çalışır (kendi testi aşağıda).
	_cleanup()


func test_slot_limits_and_unique_legendary() -> void:
	_reset()
	var player: Node = _make_player()
	player.max_item_slots = 1
	assert(player.acquire_item("bile_tasi", {}, 0), "1 parça slotu")
	assert(not player.acquire_item("kol_saati", {}, 0), "parça slotu (seviye başına 1) dolu")
	## Epik parçayı tüketirse yer açılır: Suikastçı = Bile + Kol Saati (kol saati sahip değil -> fiyatı ödenir)
	var plan: Dictionary = Items.plan_purchase("suikastci_kamasi", GameManager.owned_items)
	assert(player.acquire_item("suikastci_kamasi", plan, int(plan["cost"])), "epik ayrı havuz")
	assert(Items.count_kademe(GameManager.owned_items, 1) == 0, "bile taşı tüketildi")
	assert(player.acquire_item("son_sans", {}, 0), "efsanevi alınır")
	assert(Items.purchase_block_reason("son_sans", GameManager.owned_items, 1) != "", "aynı efsanevi ikinci kez alınamaz")
	_reset()
	for k in ["son_sans", "kabuk_delen", "kan_aglayan", "anka_kusunun_kalbi", "zaman_kiran"]:
		GameManager.owned_items.append({"key": k})
	assert(Items.purchase_block_reason("azrailin_gozu", GameManager.owned_items, 1) != "", "en fazla 5 efsanevi")
	_cleanup()


## 2026-10-14 (kullanıcı: "her epik itemden sadece 1 tane alınabilsin"): epikler tekil; parçalar serbest; efsanevi tarifi aynı epikten 2 isterse 1'i sahip olunandan tüketilir.
func test_epics_are_unique_but_parts_and_legendary_recipes_still_work() -> void:
	_reset()
	var player: Node = _make_player()
	player.max_item_slots = 4
	assert(player.acquire_item("bile_tasi", {}, 0) and player.acquire_item("bile_tasi", {}, 0), "parçadan istenildiği kadar (slot sınırına kadar)")
	assert(player.acquire_item("savasci_bileyi", {}, 0), "ilk epik alınır")
	assert(Items.purchase_block_reason("savasci_bileyi", GameManager.owned_items, 4) == "Zaten sende var", "aynı epik ikinci kez alınamaz")
	assert(not player.acquire_item("savasci_bileyi", {}, 0), "acquire_item de ikinciyi reddeder")
	assert(Items.purchase_block_reason("kemik_kolye", GameManager.owned_items, 4) != "Zaten sende var", "başka epik alınabilir")
	## Efsanevi tarifi aynı epikten 2 ister (Anka: 2 Yenilenme Özütü + Yaşam Kristali); 1 tanesi elde: tüketilir, ikincisi tarifle gelir.
	_reset()
	player = _make_player()
	player.acquire_item("yenilenme_ozutu", {}, 0)
	var plan: Dictionary = Items.plan_purchase("anka_kusunun_kalbi", GameManager.owned_items)
	assert((plan["consume"] as Array).size() == 1, "sahip olunan epik tarifte tüketilir")
	assert(Items.purchase_block_reason("anka_kusunun_kalbi", GameManager.owned_items, 4, plan) == "", "efsanevi yine alınabilir")
	assert(player.acquire_item("anka_kusunun_kalbi", plan, int(plan["cost"])), "efsanevi alınır")
	assert(not Items.owns(GameManager.owned_items, "yenilenme_ozutu"), "epik tüketildi")
	assert(Items.purchase_block_reason("yenilenme_ozutu", GameManager.owned_items, 4) == "", "tüketilen epik tekrar alınabilir")
	_cleanup()


func test_elite_chest_and_merchant_skip_owned_epics() -> void:
	_reset()
	var ChestMenu: GDScript = preload("res://scripts/chest_menu.gd")
	var epics: Array = ChestMenu.item_pool(true, 1)
	assert(not epics.is_empty())
	var owned: String = str(epics[0])
	GameManager.owned_items.append({"key": owned})
	assert(not ChestMenu.item_pool(true, 1).has(owned), "elit sandık sahip olunan epiği vermez")
	for k in epics:
		if not Items.owns(GameManager.owned_items, str(k)):
			GameManager.owned_items.append({"key": str(k)})
	assert(not ChestMenu.item_pool(true, 1).is_empty(), "hepsine sahipse sandık boş açılmaz (kart satılabilir)")
	_reset()
	_cleanup()


func test_sell_refunds_half_of_full_price() -> void:
	_reset()
	var player: Node = _make_player()
	player.acquire_item("savascinin_kilici", {}, 0)
	var g0: int = GameManager.gold
	var refund: int = player.sell_owned_item(0)
	assert(refund == 350 and GameManager.gold - g0 == 350, "700 x %%50 = 350, bulunan %d" % refund)
	assert(GameManager.owned_items.is_empty(), "satılan eşya envanterden çıkmalı")
	_cleanup()


# ------------------------------------------------------------------ pasifler
func test_zaman_kiran_survives_and_cools_down() -> void:
	_reset()
	var player: Node = _make_player()
	player.acquire_item("zaman_kiran", {}, 0)
	player.health = 20.0
	player.item_shield_hp = 0.0
	player._last_damage_taken_at_msec = -999999
	player.take_damage(500.0)
	assert(not player.is_dead and player.health >= 1.0, "Zaman Kıran ölümcül isabetten sağ çıkarmalı, can: %s" % player.health)
	assert(player._item_invuln_timer > 0.0 and player._item_zaman_cd > 100.0, "1 sn ölümsüzlük + 120 sn bekleme")
	var hp: float = player.health
	player._last_damage_taken_at_msec = -999999
	player.take_damage(5.0)
	assert(is_equal_approx(player.health, hp), "ölümsüzken hasar almamalı")
	_cleanup()


## Anka Mührü: ölümcül darbede tam can + kalkanla dirilir, 1 sn dokunulmaz, 180 sn bekleme; bekleme sürerken normal ölür.
func test_anka_muhru_revives_once() -> void:
	_reset()
	var player: Node = _make_player()
	player.acquire_item("anka_muhru", {}, 0)
	player.health = 20.0
	player.item_shield_hp = 0.0
	player._last_damage_taken_at_msec = -999999
	player.take_damage(5000.0)
	assert(not player.is_dead and not player.is_downed, "Anka Mührü ölümcül isabette dirilmeli")
	assert(is_equal_approx(player.health, player.max_health), "tam canla dirilmeli: %s / %s" % [player.health, player.max_health])
	assert(player._item_invuln_timer > 0.0 and player._item_anka_revive_cd > 100.0, "1 sn dokunulmaz + 180 sn bekleme")
	_cleanup()


## Şifa Feneri: %25 İyileştirme ve Mana Kalkanı Gücü SADECE pasif (stat satırı yok), sahipken etkin.
func test_sifa_feneri_heal_power_is_passive_only() -> void:
	_reset()
	var player: Node = _make_player()
	var base: float = player.get_heal_shield_power()
	assert(not (Items.DEFS["sifa_feneri"]["stats"] as Dictionary).has("heal_shield_power"), "Şifa Feneri stat satırında iyileştirme gücü olmamalı")
	player.acquire_item("sifa_feneri", {}, 0)
	assert(is_equal_approx(player.get_heal_shield_power() - base, 0.25), "pasif +0.25 vermeli: %s" % (player.get_heal_shield_power() - base))
	_cleanup()


func test_olum_esigi_and_kirilmaz_irade_shield() -> void:
	_reset()
	var player: Node = _make_player()
	player.acquire_item("olum_esigi", {}, 0)
	player.acquire_item("kirilmaz_irade", {}, 0)
	player.item_shield_max = 200.0
	player.item_shield_hp = 0.0
	player.health = player.max_health * 0.31
	player._last_damage_taken_at_msec = -999999
	player.take_damage(player.max_health * 0.05)
	assert(player.item_shield_hp >= 40.0, "Ölüm Eşiği %%20 maks kalkan (40) + Kırılmaz İrade 2, bulunan %s" % player.item_shield_hp)
	assert(player._item_olum_cd > 100.0, "Ölüm Eşiği 120 sn bekleme")
	_cleanup()


func test_flow_speed_stacks_and_son_sans_ap() -> void:
	_reset()
	var player: Node = _make_player()
	player.acquire_item("ruhlarin_akisi", {}, 0)
	var base_speed: float = player.get_effective_move_speed()
	for i in 5:
		player._item_on_xp_orb()
	## 2026-10-18: orb başına %1 (ITEM_FLOW_PER_ORB). 5 orb = %5 hız (eşyanın kendi +%5 hareket hızı base_speed'e dahil, çarpana toplamsal biner: 1,10 / 1,05).
	var flow_ratio: float = player.get_effective_move_speed() / base_speed
	assert(flow_ratio > 1.04 and flow_ratio < 1.055, "5 orb ~%%5 hız: oran %f" % flow_ratio)
	assert(is_equal_approx(player.ITEM_FLOW_PER_ORB, 0.01), "orb başına %1")
	player._item_flow_orbs.clear()
	var ap0: float = player.damage_bonus
	var luck0: float = player.luck
	player.acquire_item("son_sans", {}, 0)
	assert(is_equal_approx(player.damage_bonus - ap0, 25.0 + floorf(luck0 + 10.0)), "Son Şans: 25 + (şans) saldırı gücü, fark %s" % (player.damage_bonus - ap0))
	_cleanup()


func test_heal_power_boosts_own_heals_only() -> void:
	_reset()
	var player: Node = _make_player()
	player.acquire_item("lutuf_madalyonu", {}, 0)
	player.health = 10.0
	player.heal(100.0)
	assert(is_equal_approx(player.health, 118.0) or player.health >= player.max_health, "%%8 güç: 100 -> 108, can %s" % player.health)
	player.health = 10.0
	player.heal(100.0, false)
	assert(is_equal_approx(player.health, 110.0) or player.health >= player.max_health, "arkadaştan gelen can tekrar büyümez")
	_cleanup()


func test_chest_gold_share_formula() -> void:
	assert(ChestDropScript.chest_gold_share(100, 1) == 100, "tek oyuncu tamamı")
	assert(ChestDropScript.chest_gold_share(100, 2) == 90, "2 oyuncu %%90")
	assert(ChestDropScript.chest_gold_share(100, 4) == 70, "4 oyuncu %%70")
	assert(ChestDropScript.CHEST_GOLD_MIN == 90 and ChestDropScript.CHEST_GOLD_MAX == 150, "90-150 altın")


## 2026-10-18 (kullanıcı): Ruhların Maskesi (orb başına hız) epikten EFSANEVİYE geçti: orb başına %0,5 hız, +%20 EXP, +%5 hareket hızı.
func test_soul_mask_is_legendary_and_dependents_keep_their_price() -> void:
	_reset()
	assert(Items.kademe("ruhlarin_akisi") == Items.KADEME_EFSANEVI, "Ruhların Maskesi efsanevi olmalı")
	var st: Dictionary = Items.get_def("ruhlarin_akisi")["stats"]
	assert(is_equal_approx(float(st["exp_gain_percent"]), 0.20) and is_equal_approx(float(st["item_speed_percent"]), 0.05), "temel statlar: +%20 EXP, +%5 hız: %s" % str(st))
	assert(Items.cost("ruhlarin_akisi") == 1790, "fiyat = bileşen toplamı (1790): %d" % Items.cost("ruhlarin_akisi"))
	var passive_text: String = str(Items.get_def("ruhlarin_akisi")["passive"])
	assert(passive_text.contains("%1 hareket hızı") and passive_text.contains("yenilemez"), "pasif metni orb başına %1 ve 'yenilemez' demeli: %s" % passive_text)
	## Eskiden maskeyi bileşen kullanan 3 efsanevinin tarifi açık parçalara çevrildi ve fiyatları aynı (2020 / 2130 / 2250).
	for pair in [["ninjanin_el_kitabi", 2020], ["son_sans", 2130], ["bilgenin_pusulasi", 2250]]:
		var key: String = pair[0]
		assert(not (Items.recipe(key) as Array).has("ruhlarin_akisi"), "%s: efsanevi bileşen (maske) kalmamalı" % key)
		assert(Items.cost(key) == int(pair[1]), "%s fiyatı değişmemeli: %d" % [key, Items.cost(key)])
	assert(not (Items.builds_into("ruhlarin_akisi") as Array).has("son_sans"), "maske artık Son Şans'ın bileşeni değil")
	## Tarif indirimi: sahip olunan Rüzgar Eldiveni + Tecrübe Kitabı fiyattan düşer.
	var player: Node = _make_player()
	player.acquire_item("ruzgar_eldiveni", {}, 0)
	player.acquire_item("tecrube_kitabi", {}, 0)
	var plan: Dictionary = Items.plan_purchase("ruhlarin_akisi", GameManager.owned_items)
	assert(int(plan["cost"]) == 1790 - 650 - 290 and (plan["consume"] as Array).size() == 2, "eldiven + kitap tüketilip düşülmeli: %d" % int(plan["cost"]))
	_cleanup()


## 2026-10-18 (kullanıcı: "ilk orbun verdiği hız yenilenmesin, %1 kalabilir"): Ruhların Maskesi'nde her orbun bonusu KENDİ 4 sn'sinde söner; yeni orb eskisini yenilemez.
func test_soul_mask_orb_speed_decays_per_orb_and_never_refreshes() -> void:
	_reset()
	var player: Node = _make_player()
	player.acquire_item("ruhlarin_akisi", {}, 0)
	assert(is_equal_approx(player._item_flow_bonus(), 0.0), "orb yokken bonus 0")
	player._item_on_xp_orb() ## A: %1, 4 sn
	assert(is_equal_approx(player._item_flow_bonus(), 0.01), "ilk orb 0,01 bonus: %f" % player._item_flow_bonus())
	player._item_flow_tick(2.0) ## A'nın 2 sn'si kaldı -> %0,5
	assert(is_equal_approx(player._item_flow_bonus(), 0.005), "2 sn sonra yarısı: %f" % player._item_flow_bonus())
	player._item_on_xp_orb() ## B: A YENİLENMEZ; A %0,5 + B %1
	assert(is_equal_approx(player._item_flow_bonus(), 0.015), "ikinci orb ilkini yenilememeli (0,5 + 1,0): %f" % player._item_flow_bonus())
	player._item_flow_tick(2.0) ## A söndü (süresi doldu), B'nin 2 sn'si kaldı
	assert(is_equal_approx(player._item_flow_bonus(), 0.005), "A kendi süresinde bitmeli, B yarıda: %f" % player._item_flow_bonus())
	player._item_flow_tick(2.0)
	assert(is_equal_approx(player._item_flow_bonus(), 0.0) and player._item_flow_orbs.is_empty(), "hepsi bitince bonus 0 ve liste boş")
	## Aynı karede gelen orblar (birleşen küre toplaması) tek satırda birleşir ve toplam doğru kalır.
	for i in 32:
		player._item_on_xp_orb()
	assert(player._item_flow_orbs.size() == 1, "aynı karedeki 32 orb tek satır: %d" % player._item_flow_orbs.size())
	assert(is_equal_approx(player._item_flow_bonus(), 0.32), "32 orb = 0,32 bonus: %f" % player._item_flow_bonus())
	## Eşya yokken orb bonus vermez.
	_cleanup()
	_reset()
	var bare: Node = _make_player()
	bare._item_on_xp_orb()
	assert(bare._item_flow_orbs.is_empty(), "maske yokken orb yığını oluşmaz")
	_cleanup()
