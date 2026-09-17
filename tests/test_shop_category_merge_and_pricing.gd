extends Node

## Kullanıcı isteği doğrulaması:
## 9)  "Eşyalar" -> "Ekstralar"
## 10) "Diğer" -> "İşlevsellik"; Savunma (kalkan) sekmesi tamamen silinip
##     İşlevsellik'e taşındı.
## 11) Karakterin en fazla 1 kalkan yuvası + 2 işlevsellik yuvası olmalı.
## 12) DÜZELTME (SONRAKİ kullanıcı isteği: "Multiplayerda ilk seçtiğimiz
##     silahtan sonra alacağımız 2. silah ucuz olacak 3. 4 .5 silahı 80 gold
##     civarında başlat") - eski #12 ("fazladan kopya fiyatı artırmamalı")
##     kasıtlı olarak TERS ÇEVRİLDİ: artık toplam sahip olunan silah
##     sayısına göre kademeli fiyatlanıyor (bkz. aşağıdaki test).

const ShopPanelScene: PackedScene = preload("res://scenes/shop_panel.tscn")
const InventoryPanelScene: PackedScene = preload("res://scenes/inventory_panel.tscn")
const ShopPanelScript = preload("res://scripts/shop_panel.gd")
const InventoryPanelScript = preload("res://scripts/inventory_panel.gd")


func test_shop_panel_instantiates_without_defense_tab() -> void:
	var panel: Control = ShopPanelScene.instantiate()
	add_child(panel)
	panel._ready() ## bkz. test_chest_system.gd'deki aynı "Force ready" notu - bu
	## test ortamında yeni eklenen node'lar için NOTIFICATION_READY otomatik
	## tetiklenmiyor (get_tree() null döndüğü için), @onready değişkenlerin
	## (selectable_rows dahil) dolması için _ready() elle çağrılmalı.
	## Defense sekmesi/sayfası tamamen kaldırılmış olmalı.
	assert(panel.get_node_or_null("Frame/Margin/VBox/Body/TabBar/DefenseTab") == null,
		"DefenseTab hala sahnede - silinmemiş")
	assert(panel.get_node_or_null("Frame/Margin/VBox/Body/Scroll/PagesVBox/DefensePage") == null,
		"DefensePage hala sahnede - silinmemiş")
	## Kalkan satırları artık OtherPage (İşlevsellik) altında olmalı.
	assert(panel.get_node_or_null("Frame/Margin/VBox/Body/Scroll/PagesVBox/OtherPage/StandartShieldRow") != null,
		"StandartShieldRow OtherPage altına taşınmamış")
	assert(panel.get_node_or_null("Frame/Margin/VBox/Body/Scroll/PagesVBox/OtherPage/SavasShieldRow") != null,
		"SavasShieldRow OtherPage altına taşınmamış")
	assert(not ("defense" in panel.pages), "'defense' anahtarı hala pages sözlüğünde")
	assert(not ("defense" in panel.page_headers), "'defense' anahtarı hala page_headers sözlüğünde")
	assert("shield_standart" in panel.selectable_rows, "shield_standart artık selectable_rows'ta olmalı")
	panel.queue_free()


func test_tab_tooltips_renamed() -> void:
	var panel: Control = ShopPanelScene.instantiate()
	add_child(panel)
	var other_tab: Button = panel.get_node("Frame/Margin/VBox/Body/TabBar/OtherTab")
	var items_tab: Button = panel.get_node("Frame/Margin/VBox/Body/TabBar/ItemsTab")
	assert(other_tab.tooltip_text == "İşlevsellik", "OtherTab tooltip'i 'İşlevsellik' olmalı, bulunan: %s" % other_tab.tooltip_text)
	assert(items_tab.tooltip_text == "Ekstralar", "ItemsTab tooltip'i 'Ekstralar' olmalı, bulunan: %s" % items_tab.tooltip_text)
	panel.queue_free()


func test_page_headers_renamed() -> void:
	var panel: Control = ShopPanelScene.instantiate()
	add_child(panel)
	var other_header: Label = panel.get_node("Frame/Margin/VBox/Body/Scroll/PagesVBox/OtherHeader")
	var items_header: Label = panel.get_node("Frame/Margin/VBox/Body/Scroll/PagesVBox/ItemsHeader")
	assert(other_header.text == "İŞLEVSELLİK", "OtherHeader metni 'İŞLEVSELLİK' olmalı, bulunan: %s" % other_header.text)
	assert(items_header.text == "EKSTRALAR", "ItemsHeader metni 'EKSTRALAR' olmalı, bulunan: %s" % items_header.text)
	panel.queue_free()


## DÜZELTME (kullanıcı isteği: "Multiplayerda ilk seçtiğimiz silahtan sonra
## alacağımız 2. silah ucuz olacak 3. 4 .5 silahı 80 gold civarında
## başlat") - artık silah TÜRÜNDEN bağımsız, sahip olunan TOPLAM silah
## sayısına (next_total_count) göre kademeli: 2. silah ucuz, 3.+ ~80 altın.
func test_copy_cost_scales_with_total_owned_count() -> void:
	var panel: Control = ShopPanelScene.instantiate()
	add_child(panel)
	var second_weapon: int = panel._copy_cost("dagger", 2)
	var third_weapon: int = panel._copy_cost("tabanca", 3)
	var fifth_weapon: int = panel._copy_cost("yay", 5)
	assert(second_weapon == ShopPanelScript.SECOND_WEAPON_COST,
		"2. silah ucuz tarifeyi odemeli, bulunan: %s beklenen: %s" % [second_weapon, ShopPanelScript.SECOND_WEAPON_COST])
	assert(third_weapon == ShopPanelScript.LATER_WEAPON_COST and fifth_weapon == ShopPanelScript.LATER_WEAPON_COST,
		"3./5. silah ~80 tarifesini odemeli, bulunan: 3.=%s 5.=%s beklenen: %s" % [third_weapon, fifth_weapon, ShopPanelScript.LATER_WEAPON_COST])
	assert(second_weapon < third_weapon, "2. silah 3./4./5.'den ucuz olmali")
	panel.queue_free()


## DÜZELTME (kullanıcı isteği: "shopta ki shop page den aynı silah birden
## fazla alınmaz") - zaten sahip olunan bir silah türü bir daha
## satın alınamamalı, dükkan bunu hem fiyat etiketinde ("SAHİPSİN") hem de
## gerçek satın alma fonksiyonunda (_on_buy_copy) engellemeli.
func test_owned_weapon_cannot_be_bought_again() -> void:
	var panel: Control = ShopPanelScene.instantiate()
	add_child(panel)
	panel._ready()
	GameManager.owned_weapons = [{"key": "dagger", "level": 1, "spent": 0}]
	assert(panel._count_owned("dagger") == 1, "dagger zaten sahip olunmali")
	assert(panel._display_cost_text("dagger") == "SAHİPSİN",
		"Sahip olunan silahin fiyat etiketi 'SAHIPSIN' olmali, bulunan: %s" % panel._display_cost_text("dagger"))
	var gold_before: int = GameManager.gold
	var count_before: int = GameManager.owned_weapons.size()
	panel._on_buy_copy("dagger")
	assert(GameManager.owned_weapons.size() == count_before,
		"Zaten sahip olunan silah tekrar satin alinmamali")
	assert(GameManager.gold == gold_before,
		"Engellenen satin almada altin harcanmamali")
	panel.queue_free()


func test_max_owned_weapons_still_caps_at_five() -> void:
	assert(ShopPanelScript.MAX_OWNED_WEAPONS == 5,
		"En fazla 5 silah kopyasi limiti degismemis olmali")


func test_inventory_utility_slots_capped_at_two() -> void:
	assert(InventoryPanelScript.MAX_UTILITY_SLOTS == 2,
		"Islevsellik yuva sayisi 2 olmali, bulunan: %s" % InventoryPanelScript.MAX_UTILITY_SLOTS)
	assert(InventoryPanelScript.UTILITY_KEYS.size() >= 1,
		"En az bir islevsellik anahtari (spray) tanimli olmali")


func test_inventory_panel_creates_two_utility_buttons() -> void:
	var panel: Control = InventoryPanelScene.instantiate()
	add_child(panel)
	panel._ready() ## bkz. yukarıdaki "Force ready" notu - equip_grid/main_layout _ready() içinde oluşuyor.
	panel._refresh_equipments()
	assert(panel.equip_grid != null, "equip_grid olusmamis")
	## 1 kalkan + 2 islevsellik = 3 buton
	assert(panel.equip_grid.get_child_count() == 3,
		"equip_grid 3 slot (1 kalkan + 2 islevsellik) icermeli, bulunan: %s" % panel.equip_grid.get_child_count())
	panel.queue_free()
