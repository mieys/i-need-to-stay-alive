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
	assert(Items.KEYS.size() == 50, "11 parça + 16 epik + 23 efsanevi = 50 (2026-10-10: +1 epik, +7 efsanevi tarifsiz), bulunan %d" % Items.KEYS.size())
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
	assert(counts == [11, 16, 23], "kademe sayıları: %s" % str(counts))
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
	assert(player.get_effective_move_speed() > base_speed * 1.04, "5 orb ~%%5 hız")
	player._item_flow_timer = 0.0
	player._item_flow_stacks = 0.0
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
