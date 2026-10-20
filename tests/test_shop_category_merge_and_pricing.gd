extends Node

## Kullanıcı isteği doğrulaması:
## 9)  "Eşyalar" -> "Ekstralar"
## 10) "Diğer" -> "İşlevsellik"; Savunma (kalkan) sekmesi tamamen silinip
##     İşlevsellik'e taşındı.
## 11) Karakterin en fazla 1 kalkan yuvası + 2 işlevsellik yuvası olmalı. (2026-09-29'dan beri kalkan dükkanda satılmıyor.)
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
	## 2026-09-29 kalkan sadeleştirmesi (kullanıcı kararı): kalkan seçme/alma/satma YOK - herkes Standart Lv1 kalkanla başlar,
	## dükkandaki kalkan satırları tamamen silindi (eskiden OtherPage'e taşınmışlardı; 2026-10-03 test güncellemesi).
	assert(panel.find_children("*ShieldRow", "", true, false).is_empty(), "Dükkanda kalkan satırı kalmamalı")
	assert(not ("defense" in panel.pages), "'defense' anahtarı hala pages sözlüğünde")
	assert(not ("defense" in panel.page_headers), "'defense' anahtarı hala page_headers sözlüğünde")
	assert(not ("shield_standart" in panel.selectable_rows), "Kalkan artık dükkanda satılmamalı (selectable_rows)")
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


## DÜZELTME (kullanıcı bildirimi: "dükkanda envanterimizde sahip olduğumuz silahları bir daha
## alamıyoruz ... ateş asası varsa ve boş silah slotum olmasına rağmen dükkandaki ateş asasını
## alamıyorum") - "aynı silah birden fazla alınmaz" isteği yanlış anlaşılmıştı: asıl kural seyyar
## satıcıda kart başına ziyaret başına 1 kez alma hakkı (bkz. test_merchant_one_purchase_per_visit).
## Bu kalıcı dükkanda sahip olunan silah TEKRAR alınabilmeli, sadece slot sınırı geçerli.
func test_owned_weapon_cannot_be_bought_twice_but_others_can() -> void:
	var panel: Control = ShopPanelScene.instantiate()
	add_child(panel)
	panel._ready()
	GameManager.owned_weapons = [{"key": "dagger", "level": 1, "spent": 0}]
	GameManager.gold = 100000
	assert(panel._count_owned("dagger") == 1, "dagger zaten sahip olunmali")
	var gold_before: int = GameManager.gold
	panel._on_buy_copy("dagger")
	assert(GameManager.owned_weapons.size() == 1 and GameManager.gold == gold_before, "2026-10-14: her silahtan 1 tane - ikinci kopya alinamaz, altin harcanmaz")
	panel._on_buy_copy("tabanca")
	assert(GameManager.owned_weapons.size() == 2 and GameManager.gold < gold_before, "baska bir silah alinabilir")
	GameManager.owned_weapons = []
	panel.queue_free()


## Slot doluysa (5/5) yine de alınamaz - sahiplik değil SLOT sınırı.
func test_weapon_purchase_is_still_blocked_only_by_the_slot_cap() -> void:
	var panel: Control = ShopPanelScene.instantiate()
	add_child(panel)
	panel._ready()
	GameManager.owned_weapons = []
	for i in range(ShopPanelScript.MAX_OWNED_WEAPONS):
		GameManager.owned_weapons.append({"key": "dagger", "level": 1, "spent": 0})
	GameManager.gold = 100000
	assert(panel._display_cost_text("dagger") == "DOLU", "Slotlar doluyken etiket 'DOLU' olmali")
	panel._on_buy_copy("dagger")
	assert(GameManager.owned_weapons.size() == ShopPanelScript.MAX_OWNED_WEAPONS, "Slot siniri asilmamali")
	GameManager.owned_weapons = []
	panel.queue_free()


func test_max_owned_weapons_caps_at_three() -> void:
	assert(ShopPanelScript.MAX_OWNED_WEAPONS == 3,
		"En fazla 3 silah (2026-10-12 deneme: 5 -> 3) limiti olmali")


func test_inventory_utility_slots_capped_at_two() -> void:
	assert(InventoryPanelScript.MAX_UTILITY_SLOTS == 2,
		"Islevsellik yuva sayisi 2 olmali, bulunan: %s" % InventoryPanelScript.MAX_UTILITY_SLOTS)
	assert(InventoryPanelScript.UTILITY_KEYS.size() >= 1,
		"En az bir islevsellik anahtari (spray) tanimli olmali")


## 2026-10-20 (madde 341): masaüstü "Kahraman Çantası"nda İşlevsellik yuvaları yok (Sprey hiçbir dükkanda satılmıyor) - donanım
## = Mana Kalkanı + evcil hayvan yuvası (her biri düğme + 2 yazı). Telefon (eski yuva düzeni) hâlâ 1 kalkan + 2 işlevsellik.
func test_inventory_panel_creates_two_utility_buttons() -> void:
	var panel: Control = InventoryPanelScene.instantiate()
	add_child(panel)
	panel._ready() ## bkz. yukarıdaki "Force ready" notu - equip_grid/main_layout _ready() içinde oluşuyor.
	panel._refresh_equipments()
	assert(panel.equip_grid != null, "equip_grid olusmamis")
	var slots: Array = panel.equip_grid.get_children().filter(func(c: Node) -> bool: return c is Button)
	assert(slots.size() == 2, "donanım 2 yuva (kalkan + evcil) olmalı, bulunan: %s" % slots.size())
	panel.queue_free()
