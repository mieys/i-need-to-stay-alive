extends Node

## Kullanıcı bildirimi: "dükkanda envanterimizde sahip olduğumuz silahları bir daha alamıyoruz ... ateş
## asası varsa ve boş silah slotum olmasına rağmen dükkandaki ateş asasını alamıyorum. Dükkan her
## yenilendiğinde içinde rasgele değişen eşyalardan herkesin 1 kez alma hakkı olmalıydı."
## (Önceki istek: "tüccarın her gelişi başına her itemden sadece 1 tane alabilmeliydik, rerolla tekrar o
## itemden gelirse bu alamama sınırına dahil değildir.")
##
## Kural: seyyar satıcının HER kartı (eşya / silah / kalkan) ziyaret başına kişi başı 1 kez alınır ("SATILDI");
## sahip olunan bir silahın kartı yine alınabilir (slot boşsa); reroll / yeni ziyaret hakkı yeniler.

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

	func buy_item(key: String, _power: float = 1.0) -> bool:
		bought_items.append(key)
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


func _weapon_card(key: String = "fire_staff") -> Dictionary:
	return {"type": "weapon", "key": key}


## Kullanıcının tam senaryosu: ateş asası zaten var, boş slot var -> dükkandaki ateş asası alınabilmeli.
func test_owned_weapon_card_can_still_be_bought() -> void:
	_reset_state()
	GameManager.owned_weapons = [{"key": "fire_staff", "level": 1, "spent": 0}]
	var merchant := FakeMerchant.new()
	var player := FakePlayer.new()
	add_child(merchant)
	add_child(player)
	var stock: Array = [_weapon_card("fire_staff")]
	var screen: CanvasLayer = _make_screen(stock, merchant, player)
	assert(screen._entry_can_buy(stock[0], 0), "Sahip olunan ateş asasının dükkan kartı alınabilmeli")

	var gold_before: int = GameManager.gold
	screen._on_buy_pressed(0)
	assert(GameManager.owned_weapons.size() == 2, "İkinci ateş asası kopyası envantere eklenmeli, bulunan: %d" % GameManager.owned_weapons.size())
	assert(player.bought_weapons == ["fire_staff"], "Gerçek silah node'u da oluşturulmalı")
	assert(GameManager.gold < gold_before, "Altın harcanmalı")
	_cleanup([merchant, player])


## Aynı kart ziyaret başına 1 kez: ikinci basış hiçbir şey yapmamalı, buton "SATILDI".
func test_each_card_type_is_sold_once_per_visit() -> void:
	_reset_state()
	var merchant := FakeMerchant.new()
	var player := FakePlayer.new()
	add_child(merchant)
	add_child(player)
	var stock: Array = [
		_weapon_card("fire_staff"),
		{"type": "item", "key": Items.KEYS[0], "tier": 1},
		{"type": "shield", "key": "shield_standart"},
	]
	var screen: CanvasLayer = _make_screen(stock, merchant, player)
	for i in range(stock.size()):
		assert(screen._entry_can_buy(stock[i], i), "Kart %d ilk seferde alınabilmeli (%s)" % [i, str(stock[i])])

	## Her kartı iki kez almayı dene (kartların sırası maliyete göre yeniden dizilmiş olabilir).
	var shield_level_before: int = int(GameManager.get("shield_standart_level"))
	for _round in range(2):
		for i in range(screen._stock.size()):
			screen._on_buy_pressed(i)

	assert(player.bought_weapons.size() == 1, "Silah kartı sadece 1 kez alınmalı, bulunan: %d" % player.bought_weapons.size())
	assert(player.bought_items.size() == 1, "Eşya kartı sadece 1 kez alınmalı, bulunan: %d" % player.bought_items.size())
	assert(int(GameManager.get("shield_standart_level")) == shield_level_before + 1,
		"Kalkan kartı sadece 1 seviye vermeli, önce %d sonra %s" % [shield_level_before, str(GameManager.get("shield_standart_level"))])
	for i in range(screen._stock.size()):
		assert(not screen._entry_can_buy(screen._stock[i], i), "Satılan kart tekrar alınamamalı: %s" % str(screen._stock[i]))
		assert(screen._buy_buttons[i].text == "SATILDI", "Satılan kartın butonu 'SATILDI' olmalı, bulunan: %s" % screen._buy_buttons[i].text)
	GameManager.set("shield_standart_level", shield_level_before)
	_cleanup([merchant, player])


## Ekranı kapatıp AYNI ziyaret içinde tekrar açmak hakkı geri VERMEMELİ ("kapatıp tekrar açınca aynı şeyi
## tekrar alabiliyoruz" bildirimi) - ve silah fiyatı değişip kartlar yeniden sıralansa bile "satıldı"
## doğru karta bağlı kalmalı (eskiden stok index'ine bağlıydı).
func test_sold_state_survives_reopening_and_resorting() -> void:
	_reset_state()
	var merchant := FakeMerchant.new()
	var player := FakePlayer.new()
	add_child(merchant)
	add_child(player)
	var cheap_item: Dictionary = {"type": "item", "key": Items.KEYS[0], "tier": 1}
	var weapon: Dictionary = _weapon_card("fire_staff")
	var stock: Array = [cheap_item, weapon]
	var screen: CanvasLayer = _make_screen(stock, merchant, player)
	var weapon_index: int = screen._stock.find(weapon)
	screen._on_buy_pressed(weapon_index)
	assert(weapon.get("sold", false) == true, "Satın alınan silah kartı 'sold' işaretlenmeli")
	screen._on_close_pressed() ## queue_free + closed
	_screens.clear()

	## Sahip olunan silah sayısı arttı -> silah fiyatı değişti -> yeniden sıralama farklı çıkabilir.
	GameManager.owned_weapons.append({"key": "dagger", "level": 1, "spent": 0})
	GameManager.owned_weapons.append({"key": "yay", "level": 1, "spent": 0})
	var reopened: CanvasLayer = _make_screen(stock, merchant, player) ## AYNI stok nesnesi (ziyaret boyunca kalıcı)
	for i in range(reopened._stock.size()):
		var entry: Dictionary = reopened._stock[i]
		var should_be_sold: bool = entry == weapon
		assert(reopened._buy_buttons[i].text == ("SATILDI" if should_be_sold else "AL"),
			"Yeniden açılışta %s kartının etiketi yanlış: %s" % [str(entry), reopened._buy_buttons[i].text])
		assert(reopened._entry_can_buy(entry, i) != should_be_sold, "Yeniden açılışta satılan kart alınamamalı, diğeri alınabilmeli")
	_cleanup([merchant, player])


## Reroll taze bir stok getirir: aynı eşya tekrar çıksa bile yeni bir alma hakkı (kullanıcı isteği).
func test_reroll_renews_the_purchase_right() -> void:
	_reset_state()
	var merchant := FakeMerchant.new()
	var player := FakePlayer.new()
	add_child(merchant)
	add_child(player)
	var first: Dictionary = _weapon_card("fire_staff")
	var screen: CanvasLayer = _make_screen([first], merchant, player)
	screen._on_buy_pressed(0)
	assert(not screen._entry_can_buy(first, 0), "Reroldan önce kart satılmış olmalı")

	merchant.next_stock = [_weapon_card("fire_staff")] ## AYNI silah yeniden geldi (yeni kart nesnesi)
	screen._on_reroll_pressed()
	assert(screen._stock.size() == 1 and screen._entry_can_buy(screen._stock[0], 0),
		"Reroldan sonra aynı silah tekrar alınabilmeli")
	screen._on_buy_pressed(0)
	assert(player.bought_weapons.size() == 2, "Reroldan sonraki kart da 1 kez alınabilmeli, bulunan: %d" % player.bought_weapons.size())
	_cleanup([merchant, player])


## Slot doluysa sahiplik değil SLOT sınırı engeller.
func test_weapon_card_is_blocked_only_by_the_slot_cap() -> void:
	_reset_state()
	for i in range(5):
		GameManager.owned_weapons.append({"key": "dagger", "level": 1, "spent": 0})
	var merchant := FakeMerchant.new()
	var player := FakePlayer.new()
	add_child(merchant)
	add_child(player)
	var stock: Array = [_weapon_card("fire_staff")]
	var screen: CanvasLayer = _make_screen(stock, merchant, player)
	assert(not screen._entry_can_buy(stock[0], 0), "5/5 slotta yeni silah kartı alınamamalı")
	GameManager.owned_weapons.remove_at(4)
	assert(screen._entry_can_buy(stock[0], 0), "Bir slot boşalınca kart alınabilmeli")
	_cleanup([merchant, player])
