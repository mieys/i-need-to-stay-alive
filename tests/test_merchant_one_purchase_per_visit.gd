extends Node

## Kullanıcı bildirimi: "dükkanda envanterimizde sahip olduğumuz silahları bir daha alamıyoruz ... ateş
## asası varsa ve boş silah slotum olmasına rağmen dükkandaki ateş asasını alamıyorum. Dükkan her
## yenilendiğinde içinde rasgele değişen eşyalardan herkesin 1 kez alma hakkı olmalıydı."
## (Önceki istek: "tüccarın her gelişi başına her itemden sadece 1 tane alabilmeliydik, rerolla tekrar o
## itemden gelirse bu alamama sınırına dahil değildir.")
##
## Kural: seyyar satıcının HER kartı ziyaret başına kişi başı 1 kez alınır ("SATILDI"); sahip olunan bir eşyanın kartı yine
## alınabilir (slot boşsa); reroll / yeni ziyaret hakkı yeniler. 2026-10-07: silahlar demirci dükkanına taşındı (weapon_shop.gd) -
## bu testler eskiden silah kartıyla sınanıyordu, artık aynı kurallar eşya kartlarıyla sınanır (silah testi: test_weapon_shop.gd).

const MerchantScreenScript: GDScript = preload("res://scripts/merchant_shop_screen.gd")


## Ekranın çağırdığı dükkan arayüzü: altınlı karıştırma + taze stok (bkz. traveling_merchant.gd).
class FakeMerchant extends Node:
	var next_stock: Array = []

	func get_reroll_cost() -> int:
		return 0

	func try_reroll_stock() -> Variant:
		return next_stock


## Ekranın çağırdığı oyuncu arayüzü.
class FakePlayer extends Node:
	var bought_weapons: Array = []
	var bought_items: Array = []
	var shield_refreshes: int = 0

	func get_max_item_slots() -> int:
		return 3

	func get_max_owned_weapons() -> int:
		return 5

	## 2026-10-02: satıcı artık tarifli acquire_item çağırır (kaydı oyuncu yazar).
	func acquire_item(key: String, _plan: Dictionary = {}, paid: int = 0) -> bool:
		bought_items.append(key)
		GameManager.owned_items.append({"key": key, "spent": paid})
		return true

	func buy_weapon_copy(key: String, _level: int) -> bool:
		bought_weapons.append(key)
		return true

	func refresh_shield_stats() -> void:
		shield_refreshes += 1


var _screens: Array = []


func _reset_state() -> void:
	GameManager.gold = 100000
	GameManager.owned_weapons = []
	GameManager.owned_items = []


func _make_screen(stock: Array, merchant: Node, player: Node) -> CanvasLayer:
	var screen: CanvasLayer = MerchantScreenScript.new()
	add_child(screen)
	screen.setup(player, stock, merchant)
	_screens.append(screen)
	return screen


func _cleanup(extra: Array = []) -> void:
	for node in _screens + extra:
		if is_instance_valid(node):
			node.queue_free()
	_screens.clear()
	_reset_state()


const OTHER_ITEM_KEY := "isik_parcacigi" ## ikinci gerçek parça
const EPIC_ITEM_KEY := "kemik_kolye" ## gerçek epik (ayrı slot havuzu)


func _item_card(key: String = TEST_ITEM_KEY) -> Dictionary:
	return {"type": "item", "key": key, "tier": 1}


## Kullanıcının tam senaryosu (silahtan eşyaya uyarlandı): aynı eşyadan zaten var, boş slot var -> dükkandaki kart alınabilmeli.
func test_owned_item_card_can_still_be_bought() -> void:
	_reset_state()
	GameManager.owned_items = [{"key": TEST_ITEM_KEY, "spent": 0}]
	var merchant := FakeMerchant.new()
	var player := FakePlayer.new()
	add_child(merchant)
	add_child(player)
	var stock: Array = [_item_card(TEST_ITEM_KEY)]
	var screen: CanvasLayer = _make_screen(stock, merchant, player)
	assert(screen._entry_can_buy(stock[0], 0), "Sahip olunan eşyanın dükkan kartı alınabilmeli")

	var gold_before: int = GameManager.gold
	screen._on_buy_pressed(0)
	assert(GameManager.owned_items.size() == 2, "İkinci kopya envantere eklenmeli, bulunan: %d" % GameManager.owned_items.size())
	assert(player.bought_items == [TEST_ITEM_KEY], "Eşya oyuncuya verilmeli")
	assert(GameManager.gold < gold_before, "Altın harcanmalı")
	_cleanup([merchant, player])


## 2026-10-07: seyyar satıcının stoğunda silah YOK (silahlar demirci dükkanında) - 8 eşya.
func test_generated_stock_has_no_weapons() -> void:
	var merchant_node: Node = (load("res://scripts/traveling_merchant.gd") as GDScript).new()
	for i in range(20):
		var stock: Array = merchant_node.call("_generate_stock")
		assert(stock.size() == 8, "stok 8 eşya olmalı, bulunan: %d" % stock.size())
		for e: Dictionary in stock:
			assert(str(e.get("type")) == "item", "satıcı sadece eşya satmalı: %s" % str(e))
	merchant_node.free()


## Aynı kart ziyaret başına 1 kez: ikinci basış hiçbir şey yapmamalı, buton "SATILDI".
## Eşya kartı akışı gerçek bir parça kartıyla sınanır.
const TEST_ITEM_KEY := "kutsal_tilsim" ## 2026-10-02: gerçek bir parça (bilinmeyen anahtar satın alınamaz)


func test_each_card_type_is_sold_once_per_visit() -> void:
	_reset_state()
	var merchant := FakeMerchant.new()
	var player := FakePlayer.new()
	add_child(merchant)
	add_child(player)
	var stock: Array = [
		_item_card(OTHER_ITEM_KEY),
		_item_card(TEST_ITEM_KEY),
	]
	var screen: CanvasLayer = _make_screen(stock, merchant, player)
	for i in range(stock.size()):
		assert(screen._entry_can_buy(stock[i], i), "Kart %d ilk seferde alınabilmeli (%s)" % [i, str(stock[i])])

	## Her kartı iki kez almayı dene (kartların sırası maliyete göre yeniden dizilmiş olabilir).
	for _round in range(2):
		for i in range(screen._stock.size()):
			screen._on_buy_pressed(i)

	assert(player.bought_items.size() == 2, "Her eşya kartı sadece 1 kez alınmalı (2 kart = 2 alım), bulunan: %d" % player.bought_items.size())
	for i in range(screen._stock.size()):
		assert(not screen._entry_can_buy(screen._stock[i], i), "Satılan kart tekrar alınamamalı: %s" % str(screen._stock[i]))
		## 2026-10-02: "SATILDI" artık fiyatın yerinde (fiyat + AL aynı satırda), buton pasif.
		assert(screen._price_labels[i].text == "SATILDI", "Satılan kartın fiyat yazısı 'SATILDI' olmalı, bulunan: %s" % screen._price_labels[i].text)
		assert(screen._buy_buttons[i].disabled, "Satılan kartın AL butonu pasif olmalı")
	_cleanup([merchant, player])


## Ekranı kapatıp AYNI ziyaret içinde tekrar açmak hakkı geri VERMEMELİ ("kapatıp tekrar açınca aynı şeyi
## tekrar alabiliyoruz" bildirimi) - ve fiyat değişip kartlar yeniden sıralansa bile "satıldı"
## doğru karta bağlı kalmalı (eskiden stok index'ine bağlıydı; eşya fiyatı sahip olunan parçalara göre düşer).
func test_sold_state_survives_reopening_and_resorting() -> void:
	_reset_state()
	var merchant := FakeMerchant.new()
	var player := FakePlayer.new()
	add_child(merchant)
	add_child(player)
	var cheap_item: Dictionary = _item_card(TEST_ITEM_KEY)
	var epic: Dictionary = _item_card(EPIC_ITEM_KEY)
	var stock: Array = [cheap_item, epic]
	var screen: CanvasLayer = _make_screen(stock, merchant, player)
	var epic_index: int = screen._stock.find(epic)
	screen._on_buy_pressed(epic_index)
	assert(epic.get("sold", false) == true, "Satın alınan kart 'sold' işaretlenmeli")
	screen._on_close_pressed() ## queue_free + closed
	_screens.clear()

	## Sahip olunan eşya değişti -> ucuz kartın fiyatı/sıralama farklı çıkabilir.
	GameManager.owned_items.append({"key": "kanli_yakut", "spent": 0})
	GameManager.owned_items.append({"key": "yasam_kristali", "spent": 0})
	var reopened: CanvasLayer = _make_screen(stock, merchant, player) ## AYNI stok nesnesi (ziyaret boyunca kalıcı)
	for i in range(reopened._stock.size()):
		var entry: Dictionary = reopened._stock[i]
		var should_be_sold: bool = entry == epic
		assert((reopened._price_labels[i].text == "SATILDI") == should_be_sold,
			"Yeniden açılışta %s kartının etiketi yanlış: %s" % [str(entry), reopened._price_labels[i].text])
		assert(reopened._entry_can_buy(entry, i) != should_be_sold, "Yeniden açılışta satılan kart alınamamalı, diğeri alınabilmeli")
	_cleanup([merchant, player])


## Reroll taze bir stok getirir: aynı eşya tekrar çıksa bile yeni bir alma hakkı (kullanıcı isteği).
func test_reroll_renews_the_purchase_right() -> void:
	_reset_state()
	var merchant := FakeMerchant.new()
	var player := FakePlayer.new()
	add_child(merchant)
	add_child(player)
	var first: Dictionary = _item_card(TEST_ITEM_KEY)
	var screen: CanvasLayer = _make_screen([first], merchant, player)
	screen._on_buy_pressed(0)
	assert(not screen._entry_can_buy(first, 0), "Reroldan önce kart satılmış olmalı")

	merchant.next_stock = [_item_card(TEST_ITEM_KEY)] ## AYNI eşya yeniden geldi (yeni kart nesnesi)
	screen._on_reroll_pressed()
	assert(screen._stock.size() == 1 and screen._entry_can_buy(screen._stock[0], 0),
		"Reroldan sonra aynı eşya tekrar alınabilmeli")
	screen._on_buy_pressed(0)
	assert(player.bought_items.size() == 2, "Reroldan sonraki kart da 1 kez alınabilmeli, bulunan: %d" % player.bought_items.size())
	_cleanup([merchant, player])


## Slot doluysa sahiplik değil SLOT sınırı engeller (parça slotu: FakePlayer 3).
func test_item_card_is_blocked_only_by_the_slot_cap() -> void:
	_reset_state()
	for i in range(3):
		GameManager.owned_items.append({"key": OTHER_ITEM_KEY, "spent": 0})
	var merchant := FakeMerchant.new()
	var player := FakePlayer.new()
	add_child(merchant)
	add_child(player)
	var stock: Array = [_item_card(TEST_ITEM_KEY)]
	var screen: CanvasLayer = _make_screen(stock, merchant, player)
	assert(not screen._entry_can_buy(stock[0], 0), "3/3 parça slotunda yeni parça kartı alınamamalı")
	GameManager.owned_items.remove_at(2)
	assert(screen._entry_can_buy(stock[0], 0), "Bir slot boşalınca kart alınabilmeli")
	_cleanup([merchant, player])
