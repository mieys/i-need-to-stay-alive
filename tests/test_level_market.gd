extends Node

## Madde 388: level atlama pazarı (level_market.gd + level_market_view.gd + level_up_screen.gd). Havuz her türü kapsar ve yalnız
## geçerli seçenek çeker, fiyat/satın alma demirci + satıcı kurallarıyla aynı, iki ayrı karıştırma, kart seçimi ekranı kapatmaz
## (DEVAM / süre dolumu kapatır).

const Market := preload("res://scripts/level_market.gd")
const Logic := preload("res://scripts/weapon_shop_logic.gd")
const MetaProgressTestScript := preload("res://scripts/meta_progress.gd")


class FakePlayer extends Node2D:
	var level: int = 12
	var luck: float = 0.0
	var max_health: float = 300.0
	var is_chat_typing: bool = false
	var bought_weapons: Array = []
	var cards: Array = []

	func get_upgrade_count(_id: String) -> int:
		return 0

	func get_max_owned_weapons() -> int:
		return 3

	func get_max_item_slots() -> int:
		return 9

	func buy_weapon_copy(key: String, _level: int) -> bool:
		bought_weapons.append(key)
		return true

	func apply_enchant_choice(card: Dictionary) -> void:
		cards.append(card)
		ShieldEnchantDefs.apply(card)

	func acquire_item(key: String, plan: Dictionary = {}, _paid: int = 0) -> bool:
		for idx in (plan.get("consume", []) as Array).duplicate():
			GameManager.owned_items.remove_at(int(idx))
		GameManager.owned_items.append({"key": key})
		return true


var _saved: Dictionary = {}


func _save_state() -> void:
	_saved = {"gold": GameManager.gold, "weapons": GameManager.owned_weapons.duplicate(true), "enchant": GameManager.shield_enchant,
		"ups": GameManager.shield_enchant_ups.duplicate(true), "shards": GameManager.weapon_shards,
		"items": GameManager.owned_items.duplicate(true), "free": GameManager.free_rerolls_per_card}
	GameManager.gold = 1480
	GameManager.weapon_shards = 17
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("uzunkilic", 1, 0)]
	EnchantDefs.ensure_trait(GameManager.owned_weapons[0])
	GameManager.shield_enchant = ""
	GameManager.shield_enchant_ups = []
	GameManager.owned_items = [{"key": "kanli_yakut"}]
	GameManager.free_rerolls_per_card = 0
	MetaProgressTestScript.unlock_all_override = true


func _restore_state() -> void:
	MetaProgressTestScript.unlock_all_override = false
	GameManager.gold = int(_saved["gold"])
	GameManager.weapon_shards = int(_saved["shards"])
	GameManager.owned_weapons = _saved["weapons"]
	GameManager.shield_enchant = str(_saved["enchant"])
	GameManager.shield_enchant_ups = _saved["ups"]
	GameManager.owned_items = _saved["items"]
	GameManager.free_rerolls_per_card = int(_saved["free"])


## 6 seçenek, çekilişte tekrar yok, havuz her türü kapsar; kalkan türü yalnız Standart'ta, kalkan geliştirmesi yalnız tür alınınca.
func test_offers_cover_every_kind_and_follow_the_shop_rules() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	var seen: Dictionary = {}
	for n in 200:
		var offers: Array = Market.roll_offers(p)
		assert(offers.size() == Market.OFFER_COUNT, "pazar 6 seçenek: %d" % offers.size())
		var ids: Array = offers.map(func(e: Dictionary) -> String: return Market.offer_id(e))
		for id in ids:
			assert(ids.count(id) == 1, "aynı çekilişte tekrar: %s" % id)
		var up_slots: Array = offers.filter(func(e: Dictionary) -> bool: return e["type"] == "wupgrade").map(func(e: Dictionary) -> int: return int(e["slot"]))
		for s in up_slots:
			assert(up_slots.count(s) == 1, "aynı silahın iki geliştirmesi aynı pazarda: %s" % [up_slots])
		for e: Dictionary in offers:
			seen[e["type"] if e["type"] != "item" else "item%d" % Items.kademe(str(e["key"]))] = true
			assert(e["type"] != "upgrade", "tür alınmadan kalkan geliştirmesi çıkmaz")
			if e["type"] == "weapon":
				assert(not GameManager.owns_weapon(str(e["key"])), "sahip olunan silah satılmaz")
			if e["type"] == "item" and Items.kademe(str(e["key"])) >= Items.KADEME_EPIK:
				assert(not Items.owns(GameManager.owned_items, str(e["key"])), "tekil eşya ikinci kez çıkmaz")
			var d: Dictionary = Market.describe(e, p)
			assert(str(d["name"]) != "" and str(d["tag"]) != "" and d["tex"] is Texture2D, "her seçeneğin adı/türü/simgesi olmalı: %s" % e)
	for k: String in ["weapon", "wupgrade", "shield", "item1", "item2", "item3"]:
		assert(seen.has(k), "200 çekilişte %s hiç çıkmadı: %s" % [k, seen.keys()])
	GameManager.shield_enchant = "shield_kale"
	GameManager.shield_enchant_ups = [0, 0]
	var up_seen: bool = false
	for n in 100:
		for e: Dictionary in Market.roll_offers(p):
			assert(e["type"] != "shield", "tür seçildikten sonra başka tür satılmaz")
			up_seen = up_seen or e["type"] == "upgrade"
	assert(up_seen, "tür alınınca kalkan geliştirmesi havuza girer")
	p.free()
	_restore_state()


## Fiyat/parçacık/engel demirci + satıcı kuralıyla aynı, satın alma onların yolundan geçer, alınan seçenek ikinci kez alınmaz.
func test_buying_uses_the_smithy_and_merchant_rules() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	var w: Dictionary = {"type": "weapon", "key": "mizrak"}
	assert(Market.price(w) == Logic.weapon_price(1) and Market.shards(w) == 10, "silah fiyatı demircininki")
	var gold: int = GameManager.gold
	assert(Market.buy(p, w) and bool(w["sold"]), "silah alınır")
	assert(GameManager.gold == gold - Logic.weapon_price(1) and GameManager.weapon_shards == 7 and p.bought_weapons == ["mizrak"], "altın + 10 parçacık düşer")
	assert(not Market.buy(p, w) and Market.block_reason(p, w) == "Alındı", "alınan seçenek ikinci kez alınmaz")
	var kolye: Dictionary = {"type": "item", "key": "kemik_kolye"}
	var plan: Dictionary = Items.plan_purchase("kemik_kolye", GameManager.owned_items)
	assert(Market.price(kolye) == GameManager.apply_shop_discount(int(plan["cost"])) and Market.price(kolye) < Items.cost("kemik_kolye"),
		"tarif indirimi (Kanlı Yakut sende): %d" % Market.price(kolye))
	assert(Market.full_price(kolye) == GameManager.apply_shop_discount(Items.cost("kemik_kolye")), "üstü çizili tam fiyat")
	gold = GameManager.gold
	var cost: int = Market.price(kolye)
	assert(Market.buy(p, kolye) and GameManager.gold == gold - cost, "eşya satıcının yoluyla alınır")
	assert(Items.owns(GameManager.owned_items, "kemik_kolye") and not Items.owns(GameManager.owned_items, "kanli_yakut"), "tarif parçası tüketilir")
	var kale: Dictionary = {"type": "shield", "key": "shield_kale"}
	var savas: Dictionary = {"type": "shield", "key": "shield_savas"}
	assert(Market.buy(p, kale) and GameManager.shield_enchant == "shield_kale", "mana kalkanı türü alınır")
	assert(Market.block_reason(p, savas) != "" and not Market.buy(p, savas), "ikinci tür alınamaz (demirci kuralı)")
	var up: Dictionary = {"type": "upgrade", "index": 0}
	assert(Market.price(up) == Logic.upgrade_price(0) and Market.shards(up) == Logic.SHARD_COST_UPGRADE)
	GameManager.gold = 50
	assert(Market.block_reason(p, up) == "%d altın eksik" % (Logic.upgrade_price(0) - 50) and not Market.buy(p, up), "altın yetmezse alınmaz")
	p.free()
	_restore_state()


## Karıştırma yeterli seçenek varken önceki 6'yı geri getirmez; bedel satıcınınki (kendi sayacıyla artar).
func test_reroll_brings_new_offers_and_costs_like_the_merchant() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	for n in 30:
		var first: Array = Market.roll_offers(p)
		var ids: Array = first.map(func(e: Dictionary) -> String: return Market.offer_id(e))
		for e: Dictionary in Market.roll_offers(p, ids):
			assert(not ids.has(Market.offer_id(e)), "karıştırma aynı seçeneği getirdi: %s" % Market.offer_id(e))
	assert(Market.reroll_cost(0) == preload("res://scripts/merchant_shop_screen.gd").reroll_cost(0) and Market.reroll_cost(1) > Market.reroll_cost(0))
	p.free()
	_restore_state()


## Kart yüzünde değer + bedel hapı (32 px) her kart x her kademede karta sığar (kullanıcı 2026-10-28: bedel "çok ufak" -> büyüdü).
func test_card_cost_pill_fits_every_card() -> void:
	_save_state()
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	var screen: CanvasLayer = (load("res://scenes/level_up_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	var view: Control = screen.get("_market_view")
	var card: Button = screen.cards[0]
	var Special := preload("res://scripts/level_special_cards.gd")
	var all: Array = (load("res://scripts/level_up_screen.gd") as GDScript).get_script_constant_map()["UPGRADES"].duplicate()
	for id: String in Special.ORDER:
		all.append(Special.as_card(id))
	var widest: float = 0.0
	for u: Dictionary in all:
		for tier in range(1, 5):
			view.fill_card(card, screen.call("_market_card_data", u, tier, 3))
			var face: Control = card.get_node("MarketFace")
			var pill: Control = face.find_child("Cost", true, false) as Control
			assert(pill != null, "%s k%d: bedel hapı olmalı" % [u["id"], tier])
			var row: Control = pill.get_parent() as Control
			var w: float = row.get_combined_minimum_size().x
			widest = maxf(widest, w)
			assert(w <= view.CARD_TEXT_W, "%s k%d: değer + bedel sığmıyor %.0f > %.0f" % [u["id"], tier, w, view.CARD_TEXT_W])
	print("en geniş değer+bedel satırı: %.0f / %.0f" % [widest, view.CARD_TEXT_W])
	screen.free()
	p.free()
	_restore_state()


## Ekran (masaüstü): kart seçimi kapatmaz, seçim DEVAM ile gider; pazar alımı + iki ayrı karıştırma; süre dolunca otomatik.
func test_screen_keeps_open_after_pick_and_continues_on_demand() -> void:
	_save_state()
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	var screen: CanvasLayer = (load("res://scenes/level_up_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	var view: Control = screen.get("_market_view")
	assert(view != null and screen.get_node_or_null("LevelMarket") == view, "masaüstünde pazar kurulur")
	assert((view.get("offers") as Array).size() == 6, "6 seçenek")
	assert(view.get("go_button").disabled, "kart seçilmeden DEVAM kapalı")
	var got: Array = []
	screen.upgrade_chosen.connect(func(id: String, tier: int) -> void: got.append([id, tier]))
	## pazar karıştırma: kendi sayacı, kart karıştırmasını etkilemez
	var gold: int = GameManager.gold
	var rc: int = Market.reroll_cost(0)
	view.call("_on_shop_reroll")
	assert(GameManager.gold == gold - rc and int(view.get("shop_rerolls")) == 1 and int(screen.get("_rerolls_this_screen")) == 0, "pazar karıştırması")
	## pazardan alım (alınabilen ilk seçenek)
	var offers: Array = view.get("offers")
	for i in offers.size():
		if Market.block_reason(p, offers[i]) == "":
			gold = GameManager.gold
			var cost: int = Market.price(offers[i])
			assert(view.call("buy", i) and GameManager.gold == gold - cost and bool(offers[i]["sold"]), "pazardan alım")
			break
	(screen.cards[1] as Button).pressed.emit()
	assert(bool(screen.get("_has_chosen")) and got.is_empty(), "kart seçimi ekranı kapatmaz, seçim henüz gitmez")
	assert(screen.reroll_button.disabled and not view.get("go_button").disabled, "kart karıştırma kapanır, DEVAM açılır")
	(screen.cards[0] as Button).pressed.emit()
	view.get("go_button").pressed.emit()
	view.get("go_button").pressed.emit()
	assert(got.size() == 1 and str(got[0][0]) == str(screen._card_ids[1]) and int(got[0][1]) == int(screen._card_tiers[1]),
		"DEVAM seçilen kartı bir kez gönderir: %s" % [got])
	screen.free()
	## süre dolumu: seçilmemişse kart otomatik seçilir ve ekran hemen kapanır
	var screen2: CanvasLayer = (load("res://scenes/level_up_screen.tscn") as PackedScene).instantiate()
	add_child(screen2)
	var got2: Array = []
	screen2.upgrade_chosen.connect(func(id: String, _t: int) -> void: got2.append(id))
	screen2.call("_on_level_up_timer_tick", 0.0)
	assert(got2.size() == 1 and screen2._card_ids.has(got2[0]), "süre dolunca otomatik seçim + kapanış: %s" % [got2])
	screen2.free()
	p.free()
	_restore_state()
