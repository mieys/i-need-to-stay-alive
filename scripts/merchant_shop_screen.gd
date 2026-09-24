extends CanvasLayer

## Kullanıcı isteği: "Seyyar satıcı dükkandan rasgele 8 item gösterecek.
## Ekstralar, silahlar, kalkanlar dahil. Tier sistemi olanlar rasgele
## tierlarda dükkanda çıkabilir. Oyuncular istediği eşyayı seçip alabilir.
## Bunun için dükkan arayüzüne benzer bir arayüz tasarla ve eşyaların
## altında minik satın al butonları olsun. Eşyaya tıklayınca da solda
## eşyanın özellikleri görünsün."
##
## chest_menu.gd'nin "CanvasLayer + Dim backdrop + prosedürel kart" deseniyle
## aynı teknikle (hiç .tscn yok, weapon_select_screen.gd gibi tamamen kodla
## inşa ediliyor) kuruluyor - ama chest_menu.gd'nin aksine (1 kart, seç-ve-
## kapan) burası GERÇEK bir dükkan: 8 kart AYNI ANDA gösterilir, her kartın
## KENDİ mini "AL" butonu var (kullanıcı isteği), kapanmadan birden fazla
## kart alınabilir (chest_menu.gd'deki gibi bir kere seçip kapanmıyor).
## Kullanıcı isteği: "tüccarın her gelişi başına her itemden sadece 1 tane
## alabilmeliydik (rerolla tekrar o itemden gelirse bu alamama sınırına dahil
## değildir)" - HER kart (eşya, silah, kalkan) ziyaret başına kişi başı SADECE
## 1 kez alınabilir, sonra "SATILDI" olur (bkz. entry["sold"]). Sahip olunan bir
## silahın dükkandaki kartı da alınabilir (yeni bağımsız kopya, boş slot varsa).
##
## BİLİNÇLİ OLARAK get_tree().paused = true YOK (chest_menu.gd/level_up_
## screen.gd'nin AKSİNE): sandık/level kartı TÜM takımın senkronize karar
## verdiği anlar, ama seyyar satıcıya gitmek KİŞİSEL/ASENKRON bir eylem - bir
## oyuncu dükkana bakarken diğerleri dışarıda savaşmaya devam edebilmeli
## (bkz. shop_panel.gd'nin de AYNI şekilde oyunu duraklatmaması).
##
## Stok (traveling_merchant.gd _generate_stock() tarafından satıcı
## BELİRİRKEN, HER OYUNCU için AYRI AYRI rastgele seçilir, TÜM ziyaret
## boyunca sabit kalır - ekranı kapatıp tekrar açmak yeniden ÇEKMEZ) -
## setup()'a dışarıdan verilir, bu ekran SADECE gösterir/sattırır.
## Kullanıcı isteği: "Seyyar satıcıdaki eşyaları rerollama butonu ekle" -
## TEK istisna: oyuncu altınla karıştırırsa (bkz. _on_reroll_pressed/reroll_cost)
## stok o anda YENİDEN çekilir - ziyaret başına karıştırma sayacı TravelingMerchant'ta
## (bkz. _merchant) kişisel olarak tutulur.

signal closed

## bkz. chest_menu.gd/weapon_select_screen.gd üstündeki AYNI not - shop_
## panel.gd'nin static yardımcı fonksiyonlarına (_apply_wood_button_style/
## _apply_mini_wood_button_style/MAX_LEVELS/_upgrade_cost) script referansı
## üzerinden erişiliyor, instance gerekmiyor.
const ShopScript := preload("res://scripts/shop_panel.gd")

## "Deliberate copy" - shop_panel.gd/chest_menu.gd/weapon_select_screen.gd
## ile AYNI desen (bu dosyalar hiçbiri class_name üzerinden bu tabloları
## paylaşmıyor).
const WEAPON_NAMES := {
	"dagger": "Bıçak", "fire_staff": "Ateş Asası", "lightning_staff": "Yıldırım Asası", "tabanca": "Tabanca",
	"tuftuf": "Tüftüf", "tufek": "Tüfek", "arcane": "Arcane Asası", "yay": "Yay",
	"crossbow": "Arbalet", "boomerang": "Bumerang", "buz_asasi": "Buz Asası", "fisek": "Fişek",
	"pence": "Pençe", "topuz": "Topuz", "uzunkilic": "Uzunkılıç",
}
const WEAPON_ICON_TEXTURES := {
	"dagger": "res://assets/weapons/base_knife/icon_v2.png",
	"fire_staff": "res://assets/weapons/fire/firestaff_icon_v3.png",
	"lightning_staff": "res://assets/weapons/lightning/icon_v3.png",
	"tabanca": "res://assets/weapons/tabanca/icon_v2.png",
	"tuftuf": "res://assets/weapons/tuftuf/icon_v2.png",
	"tufek": "res://assets/weapons/tufek/icon.png",
	"arcane": "res://assets/weapons/arcane/icon_v3.png",
	"yay": "res://assets/weapons/yay/draw1.png",
	"crossbow": "res://assets/weapons/crossbow/icon.png",
	"boomerang": "res://assets/weapons/boomerang/icon.png",
	"buz_asasi": "res://assets/weapons/buz_asasi/icon_v3.png",
	"fisek": "res://assets/weapons/fisek/icon.png",
	"pence": "res://assets/weapons/pence/icon.png",
	"topuz": "res://assets/weapons/topuz/icon.png",
	"uzunkilic": "res://assets/weapons/uzunkilic/icon.png",
}
const SHIELD_NAMES := {
	"shield_standart": "Standart Kalkan", "shield_enerji": "Enerji Kalkanı",
	"shield_kale": "Kale Kalkanı", "shield_savas": "Savaş Kalkanı",
}
const SHIELD_TYPE_KEYS := ["shield_standart", "shield_enerji", "shield_kale", "shield_savas"]
const MAX_OWNED_WEAPONS := 5

var _player: Node = null
var _stock: Array = []
var _selected_index: int = -1
var _card_panels: Array = []
var _buy_buttons: Array = []
var _price_labels: Array = []
## bkz. dosya başı "reroll" notu - TravelingMerchant referansı, reroll hakkı/
## hakkın harcanması ORADA (ziyaretler arası kalıcı, kişisel) tutuluyor, bu
## ekran sadece butonu gösterip çağırıyor.
var _merchant: Node = null
var _grid: GridContainer = null
var _reroll_btn: Button = null

## "Satıldı" kaydı KARTIN KENDİSİNDE tutulur (entry["sold"], bkz. _entry_sold):
## entry Dictionary'leri TravelingMerchant._current_stock içinde yaşar ve bu ekran
## AYNI Array/Dictionary nesnelerini paylaşır - ekranı kapatıp AYNI ziyaret içinde
## tekrar açmak kaydı sıfırlamaz (bkz. kullanıcı bildirimi: "dükkanı kapatıp tekrar
## açınca aynı şeyi tekrar alabiliyoruz"), reroll ya da yeni ziyaret taze
## Dictionary'ler üretir, yani hak kendiliğinden yenilenir.
## DÜZELTME (kullanıcı bildirimi: "envanterimizde sahip olduğumuz silahları bir
## daha alamıyoruz ... her yenilendiğinde herkesin 1 kez alma hakkı olmalıydı"):
## eskiden kural SADECE "item" kartlarına uygulanıyordu, silah kartı için bunun
## yerine "zaten sahipsen alamazsın" engeli konmuştu (yanlış yorum) - artık her
## kart tipi aynı "ziyaret başına 1 kez" kuralına tabi, sahiplik engeli yok.
## Eskiden kayıt stok INDEX'ine göre TravelingMerchant.sold_item_indices'teydi;
## _sort_stock_by_cost() her açılışta diziyi YERİNDE yeniden sıraladığı ve silah
## fiyatı sahip olunan silah sayısına bağlı olduğu için (bkz. _entry_cost) index
## kayıtları başka bir karta kayabiliyordu.

var _details_name: Label
var _details_tier: Label
var _details_icon_holder: Control
var _details_icon_frame: TextureRect
var _details_icon_inset: Control
var _details_desc: Label
var _details_price: Label
## Sağdaki stat penceresi / altın göstergesi / envanter penceresi (bkz. _build_stats_panel, _open_inventory).
var _gold_label: Label = null
var _stat_value_labels: Dictionary = {}
var _stats_timer: float = 0.0
var _inventory_overlay: Control = null
var _inventory_body: VBoxContainer = null
## Kullanıcı bildirimi (2026-09-24, ekran görüntüsüyle): "dükkanda envantere tıklayınca çok eşyamız varsa eşya gösterme
## arayüzü aşağı kayıyor ve aşağıdaki eşyalar görünmüyor" - pencere içerik kadar uzuyor ve ekranın altından taşıyordu.
## İçerik artık bu kaydırma alanında; yüksekliği içerik ile ekranın izin verdiği azami değerin küçüğü (bkz.
## _fit_inventory_scroll) - az eşyada pencere eskisi gibi içerik kadar, çok eşyada ekrana sığıp kaydırılır.
var _inventory_scroll: ScrollContainer = null
const INVENTORY_SCREEN_MARGIN := 80.0 ## pencerenin ekranın üst+alt kenarından toplam boşluğu
const INVENTORY_HEADER_ALLOWANCE := 150.0 ## başlık çubuğu + ayraç + pencere çerçeve payları


const ReadingUiWatcher := preload("res://scripts/reading_ui_watcher.gd")
## Seyyar satıcı dükkanı açıkken karakter okuma (read) pozuna geçer - bkz. ReadingUiWatcher.
func _enter_tree() -> void:
	add_to_group(ReadingUiWatcher.GROUP)


func setup(player: Node, stock: Array, merchant: Node = null) -> void:
	_player = player
	_stock = stock
	## Kullanıcı isteği: "Dükkandaki eşyaların fiyatı oyunun süresine göre
	## ucuzdan pahalıya göre sıralanmalı" - bkz. _sort_stock_by_cost/
	## _entry_cost.
	_sort_stock_by_cost()
	_merchant = merchant
	## Pencere büyüdüğü için HUD'un üstündeki geçici yazıların (satıcı sayacı, "eve gir" ipucu, bildirimler) üstüne binmesini önle.
	layer = 80
	_build_ui()
	## DÜZELTME (kullanıcı isteği: "gamepad desteği ekle") - bkz. shop_panel.gd
	## _ready()'deki AYNI kök neden notu: bu ekran BİLİNÇLİ OLARAK get_tree().
	## paused kullanmıyor, bu yüzden main.gd'nin genel ui_cancel/pause-toggle
	## kontrolü bu ekran açıkken de çalışıp pause menüsünü ÜSTÜNE açardı.
	GameManager.register_blocking_panel(self)
	## bkz. _process başındaki "oyun duraklarken gizlen" düzeltmesi - duraklamada da çalışsın ki kendini gizleyip
	## geri açabilsin.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	## BUG DÜZELTMESİ (kullanıcı bildirimi 2026-09-24: "seyyar satıcı arayüzü açıkken level atladığımızda yetenek ve
	## sandık seçilmiyor ve hiçbir butona basamadan takılı kalıyoruz") - bu ekran 80. CanvasLayer'da ve tam ekran
	## karartması (dim, MOUSE_FILTER_STOP) TÜM tıklamaları yutuyor; seviye atlama (level_up_screen.tscn layer 1),
	## sandık (chest_menu) ve mola dükkanı ise ALTINDAKİ katmanlarda açılıp get_tree().paused = true yapıyor. Duraklama
	## bu ekranın kendi _process'ini de durdurduğu için ESC ile kapatmak da mümkün değildi -> tam kilit. Artık oyun
	## duraklatıldığı sürece (bu ekran oyunu hiç duraklatmaz, yani duraklama HER ZAMAN başka bir modal demek) ekran
	## gizlenir (gizli CanvasLayer girdi almaz), duraklama bitince kaldığı yerden aynen geri gelir.
	var paused_by_other: bool = get_tree().paused
	if visible == paused_by_other:
		visible = not paused_by_other
	if paused_by_other:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		## Envanter penceresi açıksa ESC önce onu kapatır, dükkanı değil.
		if _inventory_overlay and is_instance_valid(_inventory_overlay):
			_close_inventory()
		else:
			_on_close_pressed()
		return
	## Sağdaki stat penceresi + altın göstergesi: satın alma/hasar/level gibi değişimleri yakalamak için hafif yoklama.
	_stats_timer -= delta
	if _stats_timer <= 0.0:
		_stats_timer = 0.25
		_refresh_stats()
		_refresh_reroll_button() ## altın dükkan açıkken de değişebilir (paylaşılan altın vb.)


## Kullanıcı isteği (2026-09-21): "seyyar satıcı arayüzünde itemler ve yazılar çok ufak kalıyor. Bu arayüzü daha kullanıcı dostu ve
## sağında kendine özgü stat penceresi olacak şekilde yeniden tasarla, ayrıca dükkanda olduğumuz eşyaları gösterebilecek bir buton ve
## buna özgü pencere ekle" - tüm arayüz UIKit (assets/ui/kit) ile yeniden kuruldu: 2x piksel ölçeği, m5x7 için 32/48/64 yazı boyutları
## (eskiden 14-18 = okunaksız/uneven), büyük kartlar (icon 96 px), sağda stat penceresi, üstte ENVANTER butonu (bkz. _open_inventory).
func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.07, 0.03, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## 2026-09-24: oyun içi bej kit teması (koyu yazı, ten butonlar) - CanvasLayer temayı aktarmadığı için buradan.
	center.theme = UIKit.theme()
	add_child(center)

	var window := PanelContainer.new()
	window.add_theme_stylebox_override("panel", UIKit.panel_style("window"))
	center.add_child(window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	window.add_child(vbox)

	## ---- Başlık çubuğu: başlık tahtası | altın | ENVANTER | YENİDEN ÇEVİR | X ----
	var title_bar := HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 14)
	var title_plaque := PanelContainer.new()
	title_plaque.add_theme_stylebox_override("panel", UIKit.panel_style("plaque"))
	var title_label := Label.new()
	title_label.text = "SEYYAR SATICI"
	UIKit.style_label(title_label, UIKit.FS_TITLE, UIKit.C_TEXT, 4)
	title_plaque.add_child(title_label)
	title_bar.add_child(title_plaque)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(spacer)

	var gold_box := PanelContainer.new()
	gold_box.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))
	_gold_label = Label.new()
	UIKit.style_label(_gold_label, UIKit.FS_BODY, UIKit.C_GOLD, 3)
	_gold_label.custom_minimum_size = Vector2(220, 0)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_box.add_child(_gold_label)
	title_bar.add_child(gold_box)

	## Kullanıcı isteği: "dükkanda olduğumuz eşyaları gösterebilecek bir buton ve buna özgü pencere" - bkz. _open_inventory.
	var inv_btn := Button.new()
	inv_btn.text = "ENVANTER"
	inv_btn.custom_minimum_size = Vector2(230, 64)
	UIKit.style_button(inv_btn, "wood", false, UIKit.FS_BODY)
	inv_btn.pressed.connect(_open_inventory)
	title_bar.add_child(inv_btn)

	## Kullanıcı isteği: "Seyyar satıcıdaki eşyaları rerollama butonu ekle" - artık altınla (bkz. reroll_cost); ziyaret
	## başına karıştırma sayacı TravelingMerchant'ta, burada sadece gösterilip _on_reroll_pressed ile tetikleniyor.
	_reroll_btn = Button.new()
	_reroll_btn.custom_minimum_size = Vector2(340, 64)
	UIKit.style_button(_reroll_btn, "wood", false, UIKit.FS_BODY)
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	title_bar.add_child(_reroll_btn)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(64, 64)
	UIKit.style_button(close_btn, "red", true, UIKit.FS_BODY)
	close_btn.pressed.connect(_on_close_pressed)
	title_bar.add_child(close_btn)
	vbox.add_child(title_bar)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	vbox.add_child(body)

	body.add_child(_build_details_panel())
	body.add_child(_build_grid())
	body.add_child(_build_stats_panel())

	## bkz. chest_menu.gd'nin AYNI notu - sadece tık sesi, görsel stil zaten yukarıda UIKit ile elle uygulandı.
	UISound.connect_all_buttons(self)

	_refresh_all_buy_states()
	_refresh_reroll_button()
	_refresh_stats()
	if not _stock.is_empty():
		_select_index(0)


## Sol: seçili eşyanın büyük ikonu, adı, kademesi, açıklaması ve fiyatı.
func _build_details_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	panel.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_details_icon_holder = Control.new()
	_details_icon_holder.custom_minimum_size = Vector2(192, 192)
	_details_icon_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	## bkz. _build_card ile AYNI kare ikon-slotu deseni (_build_icon_slot) - çerçeve tier'a göre _refresh_details()'te güncellenir.
	## İkon alanı 144 px = 3x (32 px eşya) / 3x (48 px kalkan) => piksel-net.
	_details_icon_inset = _build_icon_slot(_details_icon_holder, 1, 24.0)
	_details_icon_frame = _details_icon_holder.get_node("SlotFrame") as TextureRect
	vbox.add_child(_details_icon_holder)

	_details_name = Label.new()
	_details_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.style_label(_details_name, UIKit.FS_TITLE, UIKit.C_ACCENT, 3)
	vbox.add_child(_details_name)

	_details_tier = Label.new()
	_details_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(_details_tier, UIKit.FS_BODY, UIKit.C_TEXT, 2)
	vbox.add_child(_details_tier)

	var desc_scroll := ScrollContainer.new()
	desc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_scroll.custom_minimum_size = Vector2(0, 150)
	desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(desc_scroll)
	_details_desc = Label.new()
	_details_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.style_label(_details_desc, UIKit.FS_BODY, UIKit.C_TEXT_DIM)
	_details_desc.custom_minimum_size = Vector2(320, 0)
	_details_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_scroll.add_child(_details_desc)

	_details_price = Label.new()
	_details_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(_details_price, UIKit.FS_TITLE, UIKit.C_GOLD, 3)
	vbox.add_child(_details_price)

	return panel


func _build_grid() -> Control:
	_grid = GridContainer.new()
	## 8 kart (bkz. TravelingMerchant.STOCK_SIZE) 4 sütun x 2 satır.
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	_populate_grid()
	return _grid


func _populate_grid() -> void:
	_card_panels.clear()
	_buy_buttons.clear()
	_price_labels.clear()
	for i in range(_stock.size()):
		_grid.add_child(_build_card(i))


## _on_reroll_pressed tarafından çağrılır - TAMAMEN yeni bir stokla kartları
## sıfırdan kurar (bkz. _build_ui()'nin ilk kuruluşuyla AYNI _populate_grid).
func _rebuild_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_populate_grid()
	## Yeni oluşan butonlara da tık sesi bağlanmalı - connect_all_buttons zaten
	## bağlı olanları atlıyor (bkz. ui_sound.gd), tekrar çağırmak zararsız.
	UISound.connect_all_buttons(self)


## Kart: kademe etiketi, ikon (tier çerçeveli kare slot), ad, fiyat, AL butonu. Kullanıcı isteği (SONRADAN VAZGEÇİLDİ - "uzun kartları
## buna eklemeyelim, sadece ikonları saran 1/1 kart kalsın"): level-kartı tarzı büyük dikey Frame BURADA kullanılmaz, sadece ikon slotu
## (TierSystem.MINI_FRAME_TEXTURES) tier'ı gösterir.
func _build_card(index: int) -> PanelContainer:
	var entry: Dictionary = _stock[index]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(228, 350)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("panel", UIKit.panel_style("card"))
	card.gui_input.connect(_on_card_gui_input.bind(index))
	## DÜZELTME (kullanıcı isteği: "gamepad desteği ekle") - bu PanelContainer bir Button OLMADIĞI için motor "focus" stilini
	## kendiliğinden çizmiyor, GamepadFocusHelper kendi kenarlığını ekliyor (bkz. o dosyadaki not).
	card.focus_mode = Control.FOCUS_ALL
	GamepadFocusHelper.add_focus_ring(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var tier_label := Label.new()
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(tier_label, UIKit.FS_BODY, UIKit.C_TEXT, 3)
	if entry.get("type") == "item":
		var tier: int = int(entry.get("tier", 1))
		tier_label.text = TierSystem.NAMES[tier - 1]
		tier_label.add_theme_color_override("font_color", TierSystem.COLORS[tier - 1])
	else:
		tier_label.text = _entry_kind_text(entry)
		tier_label.add_theme_color_override("font_color", UIKit.C_TEXT_DIM)
	tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tier_label)

	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(120, 120)
	icon_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_inset: Control = _build_icon_slot(icon_holder, _entry_slot_tier(entry), 12.0)
	_add_icon(icon_inset, entry)
	vbox.add_child(icon_holder)

	var name_label := Label.new()
	name_label.text = _entry_name(entry)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0, 70)
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIKit.style_label(name_label, UIKit.FS_BODY, UIKit.C_TEXT, 3)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var price_label := Label.new()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(price_label, UIKit.FS_BODY, UIKit.C_GOLD, 3)
	price_label.text = "%d Altın" % _entry_cost(entry)
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(price_label)

	## Kullanıcı isteği: "eşyaların altında minik satın al butonları olsun" - artık okunaklı boyutta (yeşil onay plakası).
	var buy_btn := Button.new()
	buy_btn.text = "AL"
	buy_btn.custom_minimum_size = Vector2(150, 56)
	buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIKit.style_button(buy_btn, "green", false, UIKit.FS_BODY)
	buy_btn.pressed.connect(_on_buy_pressed.bind(index))
	vbox.add_child(buy_btn)

	_card_panels.append(card)
	_buy_buttons.append(buy_btn)
	_price_labels.append(price_label)
	return card


## Kartın küçük "tür" etiketi (kademesi olmayan silah/kalkan kartları için).
func _entry_kind_text(entry: Dictionary) -> String:
	match entry.get("type"):
		"weapon":
			return "Silah"
		"shield":
			return "Kalkan"
	return " "


## Kullanıcı isteği: "seyyar satıcı arayüzündeki kare kare gibi olan slotlar yerine bunları kullanacaksın, tier'ı olmayan şeyler tier 1
## mini kartını kullansın" - TierSystem.MINI_FRAME_TEXTURES ikonun ARKASINA kare bir çerçeve olarak eklenir; asıl ikon bu çerçevenin
## kalın kenarlığıyla ÇAKIŞMASIN diye INSET (her kenardan `inset` px içeri) bir alt Control'e çizilir - o Control _add_icon()'a verilir.
## Çerçeve her zaman holder'ın İLK çocuğu (index 0) olur.
func _build_icon_slot(holder: Control, tier: int, inset: float) -> Control:
	var frame := TextureRect.new()
	frame.name = "SlotFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## KRİTİK: bkz. _build_card'daki AYNI notun (dosya bu tekrarlanan hatayı yaşadı) - expand_mode olmadan minimum boyut dokunun gerçek
	## piksel boyutu (583x583) olur ve kart alanını devasa bir kareyle kaplar.
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture = TierSystem.MINI_FRAME_TEXTURES[tier - 1]
	holder.add_child(frame)

	var inner := Control.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = inset
	inner.offset_top = inset
	inner.offset_right = -inset
	inner.offset_bottom = -inset
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(inner)
	return inner


func _entry_slot_tier(entry: Dictionary) -> int:
	return int(entry.get("tier", 1)) if entry.get("type") == "item" else 1


func _entry_name(entry: Dictionary) -> String:
	var key: String = entry.get("key", "")
	match entry.get("type"):
		"item":
			return Items.get_def(key).get("name", key.capitalize())
		"weapon":
			return WEAPON_NAMES.get(key, key.capitalize())
		"shield":
			return SHIELD_NAMES.get(key, key.capitalize())
	return key.capitalize()


## bkz. chest_menu.gd _build_card / shop_panel.gd shop_item_icon.gd üstündeki AYNI 3 yollu ikon deseni (eşya: PNG dosya yolu, silah:
## WEAPON_ICON_TEXTURES, kalkan: assets/ui/shields/type_*.png - tools/gen_shield_icons.py ile üretilen 48x48 piksel ikonlar).
func _add_icon(holder: Control, entry: Dictionary) -> void:
	_add_icon_by(holder, str(entry.get("type", "")), str(entry.get("key", "")))


func _add_icon_by(holder: Control, type: String, key: String) -> void:
	var tex_rect := TextureRect.new()
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	match type:
		"item":
			var icon_path: String = "res://assets/generated/item_" + key + "_frame_0.png"
			if ResourceLoader.exists(icon_path):
				tex_rect.texture = load(icon_path) as Texture2D
			else:
				## Bazı eşyaların hazır PNG'si yok (bkz. shop_item_icon.gd) - prosedürel çizime düş.
				var proc := Control.new()
				proc.set_script(load("res://scripts/shop_item_icon.gd"))
				proc.set_anchors_preset(Control.PRESET_FULL_RECT)
				proc.mouse_filter = Control.MOUSE_FILTER_IGNORE
				proc.set("item_type", "trinket")
				holder.add_child(proc)
				return
		"weapon":
			var wpath: String = WEAPON_ICON_TEXTURES.get(key, "")
			if not wpath.is_empty() and ResourceLoader.exists(wpath):
				tex_rect.texture = load(wpath) as Texture2D
		"shield":
			tex_rect.texture = _shield_icon_texture(key)
	holder.add_child(tex_rect)


## Kalkan TÜRÜ ikonu (shield_standart -> type_standart.png ...). Bulunamazsa standart.
static func _shield_icon_texture(key: String) -> Texture2D:
	var short: String = key.replace("shield_", "")
	var path: String = "res://assets/ui/shields/type_%s.png" % short
	if not ResourceLoader.exists(path):
		path = "res://assets/ui/shields/type_standart.png"
	return load(path) as Texture2D


func _on_card_gui_input(event: InputEvent, index: int) -> void:
	## DÜZELTME (kullanıcı isteği: "gamepad desteği ekle") - ui_accept (A/Enter/Boşluk) artık kart odaktayken sol tık ile AYNI
	## seçim eylemini tetikliyor.
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or event.is_action_pressed("ui_accept"):
		_select_index(index)


func _select_index(index: int) -> void:
	_selected_index = index
	_refresh_card_styles()
	_refresh_details()


## Kart çerçevesi: normal / seçili (altın) / satıldı (soluk).
func _refresh_card_styles() -> void:
	for i in range(_card_panels.size()):
		var panel: PanelContainer = _card_panels[i]
		var sold: bool = i < _stock.size() and _entry_sold(_stock[i])
		var kind: String = "card_selected" if i == _selected_index else ("card_sold" if sold else "card")
		panel.add_theme_stylebox_override("panel", UIKit.panel_style(kind))


## Kalkan türünün çalışma biçimi (player.gd SHIELD_TYPES ile uyumlu) - açıklama metni.
const SHIELD_DESC := {
	"shield_standart": "Dengeli kalkan.\nHasarın %65'ini emer.\nHasar aldıktan 8 sn sonra yenilenmeye başlar.",
	"shield_enerji": "Düşük kapasite ama çok hızlı yenilenir.\nHasarın %55'ini emer.\nHasar aldıktan 4.5 sn sonra yenilenmeye başlar.",
	"shield_kale": "En yüksek kapasite ve emilim.\nHasarın %75'ini emer.\nYenilenmesi yavaştır (9 sn bekleme).",
	"shield_savas": "Savaş sırasında da durmadan yenilenir.\nHasarın %60'ını emer.\nBekleme süresi yoktur.",
}


func _refresh_details() -> void:
	if _selected_index < 0 or _selected_index >= _stock.size():
		return
	var entry: Dictionary = _stock[_selected_index]
	_details_name.text = _entry_name(entry)
	if entry.get("type") == "item":
		var tier: int = int(entry.get("tier", 1))
		_details_tier.text = TierSystem.NAMES[tier - 1]
		_details_tier.add_theme_color_override("font_color", TierSystem.COLORS[tier - 1])
		_details_desc.text = Items.get_def(entry.get("key", "")).get("desc", "")
	elif entry.get("type") == "weapon":
		_details_tier.text = "Silah"
		_details_tier.add_theme_color_override("font_color", UIKit.C_TEXT_DIM)
		_details_desc.text = "Yeni bir silah - kalıcı olarak edinilir."
	else:
		var key: String = entry.get("key", "")
		_details_tier.text = "Kalkan"
		_details_tier.add_theme_color_override("font_color", UIKit.C_TEXT_DIM)
		var lvl: int = int(GameManager.get(key + "_level"))
		var max_lvl: int = int(ShopScript.MAX_LEVELS.get(key, 20))
		_details_desc.text = "%s\n\nKalkan seviyesi: %d/%d\nSatın alınca bir seviye yükselir." % [SHIELD_DESC.get(key, ""), lvl, max_lvl]
	_details_icon_frame.texture = TierSystem.MINI_FRAME_TEXTURES[_entry_slot_tier(entry) - 1]
	for c in _details_icon_inset.get_children():
		c.queue_free()
	_add_icon(_details_icon_inset, entry)
	_details_price.text = "%d Altın" % _entry_cost(entry)


## ---------------------------------------------------------------- sağ: kendine özgü stat penceresi
func _build_stats_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	panel.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "DURUMUN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(title, UIKit.FS_TITLE, UIKit.C_ACCENT, 3)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	_stat_value_labels.clear()
	for row in STAT_ROWS:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		var name_lbl := Label.new()
		name_lbl.text = row["label"]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIKit.style_label(name_lbl, UIKit.FS_BODY, UIKit.C_TEXT_DIM, 2)
		hb.add_child(name_lbl)
		var val_lbl := Label.new()
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		UIKit.style_label(val_lbl, UIKit.FS_BODY, row["color"], 2)
		hb.add_child(val_lbl)
		vbox.add_child(hb)
		_stat_value_labels[row["id"]] = val_lbl
	return panel


## Stat satırları (id -> _refresh_stats). Renkler: can/kalkan/hasar/şans/tecrübe kendi tonlarında, diğerleri koyu kahve -
## 2026-09-24: bej parşömen üstünde okunan mürekkep tonları (TEK kaynak UIKit.INK).
const STAT_ROWS := [
	{"id": "health", "label": "Can", "color": Color(UIKit.INK["damage"])},
	{"id": "shield", "label": "Kalkan", "color": Color(UIKit.INK["shield"])},
	{"id": "damage", "label": "Hasar", "color": Color(UIKit.INK["range"])},
	{"id": "fire_rate", "label": "Saldırı Hızı", "color": UIKit.C_TEXT},
	{"id": "crit", "label": "Kritik", "color": UIKit.C_TEXT},
	{"id": "speed", "label": "Hız", "color": UIKit.C_TEXT},
	{"id": "range", "label": "Menzil", "color": UIKit.C_TEXT},
	{"id": "pickup", "label": "Toplama", "color": UIKit.C_TEXT},
	{"id": "absorb", "label": "Soğurma", "color": UIKit.C_TEXT},
	{"id": "dodge", "label": "Sıvışma", "color": UIKit.C_TEXT},
	{"id": "luck", "label": "Şans", "color": UIKit.C_GOOD},
	{"id": "xp", "label": "Tecrübe", "color": Color(UIKit.INK["exp"])},
]


func _refresh_stats() -> void:
	if _gold_label:
		_gold_label.text = "%d Altın" % GameManager.gold
	if _stat_value_labels.is_empty():
		return
	var p: Node = _player
	## Test/sahte oyuncu (bkz. tests/test_merchant_one_purchase_per_visit.gd FakePlayer) stat alanlarına sahip değil - satırlar "-" kalır.
	if not p or not is_instance_valid(p) or not p.has_method("get_primary_weapon"):
		for id in _stat_value_labels:
			(_stat_value_labels[id] as Label).text = "-"
		return
	var w = p.get_primary_weapon()
	var t: Dictionary = {}
	t["health"] = "%d/%d" % [int(p.health), int(p.max_health)]
	t["shield"] = "%d/%d" % [int(p.item_shield_hp), int(p.item_shield_max)]
	t["damage"] = str(int(w.damage)) if w else "-"
	## bkz. player.gd get_attack_speed_bonus_percent (stat ekranıyla AYNI değer).
	t["fire_rate"] = ("+%%%d" % int(round(p.get_attack_speed_bonus_percent()))) if p.has_method("get_attack_speed_bonus_percent") else "-"
	t["crit"] = ("%%%d (x%.2f)" % [int(w.crit_chance * 100.0), w.crit_damage]) if w else "-"
	t["speed"] = str(int(p.speed))
	t["range"] = "+%%%d" % int(round(p.weapon_range_bonus * 100.0))
	t["pickup"] = "+%%%d" % int(round(p.pickup_range_percent * 100.0))
	t["absorb"] = "%%%d" % int(round(p.shield_protection * 100.0))
	t["dodge"] = "%%%d" % int(round(p.dodge_chance * 100.0))
	t["luck"] = ("%d" % int(round(p.luck))) if is_equal_approx(p.luck, round(p.luck)) else ("%.1f" % p.luck)
	t["xp"] = "+%%%d" % int(round(p.exp_gain_percent * 100.0))
	for id in _stat_value_labels:
		(_stat_value_labels[id] as Label).text = str(t.get(id, "-"))


## ---------------------------------------------------------------- ENVANTER penceresi
## Kullanıcı isteği: "seyyar satıcı dükkanında olduğumuz eşyaları gösterebilecek bir buton ve buna özgü pencere" - sahip olunan
## silahlar / kalkan / eşyalar tek pencerede; satın alımla anlık güncellenmesi için _refresh_inventory() de çağrılır.
func _open_inventory() -> void:
	if _inventory_overlay and is_instance_valid(_inventory_overlay):
		_close_inventory()
		return
	_inventory_overlay = Control.new()
	_inventory_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inventory_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_overlay.theme = UIKit.theme()
	add_child(_inventory_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.07, 0.03, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory_overlay.add_child(center)

	var window := PanelContainer.new()
	window.add_theme_stylebox_override("panel", UIKit.panel_style("window"))
	center.add_child(window)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	window.add_child(vbox)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	var plaque := PanelContainer.new()
	plaque.add_theme_stylebox_override("panel", UIKit.panel_style("plaque"))
	var t := Label.new()
	t.text = "ENVANTERİN"
	UIKit.style_label(t, UIKit.FS_TITLE, UIKit.C_TEXT, 4)
	plaque.add_child(t)
	bar.add_child(plaque)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	var x := Button.new()
	x.text = "X"
	x.custom_minimum_size = Vector2(64, 64)
	UIKit.style_button(x, "red", true, UIKit.FS_BODY)
	x.pressed.connect(_close_inventory)
	bar.add_child(x)
	vbox.add_child(bar)
	vbox.add_child(HSeparator.new())

	_inventory_scroll = ScrollContainer.new()
	_inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inventory_scroll.follow_focus = true ## gamepad ile odak aşağı inince kaydırsın
	vbox.add_child(_inventory_scroll)
	_inventory_body = VBoxContainer.new()
	_inventory_body.add_theme_constant_override("separation", 12)
	_inventory_scroll.add_child(_inventory_body)
	_refresh_inventory()
	UISound.connect_all_buttons(_inventory_overlay)


func _close_inventory() -> void:
	if _inventory_overlay and is_instance_valid(_inventory_overlay):
		_inventory_overlay.queue_free()
	_inventory_overlay = null
	_inventory_body = null
	_inventory_scroll = null


func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	UIKit.style_label(l, UIKit.FS_BODY, UIKit.C_ACCENT, 3)
	return l


## Envanter kutucuğu: kare slot + ikon + ad + alt yazı. Boş slot için icon yok, soluk çukur.
func _inventory_cell(type: String, key: String, tier: int, title: String, sub: String, sub_color: Color = UIKit.C_TEXT_DIM) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(176, 0)
	cell.add_theme_stylebox_override("panel", UIKit.panel_style("card" if key != "" else "card_sold"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	cell.add_child(v)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(120, 120)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var inset: Control = _build_icon_slot(holder, clampi(tier, 1, 4), 12.0)
	if key != "":
		_add_icon_by(inset, type, key)
	v.add_child(holder)
	var n := Label.new()
	n.text = title
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(0, 40)
	UIKit.style_label(n, UIKit.FS_BODY, UIKit.C_TEXT if key != "" else UIKit.C_TEXT_DIM, 2)
	v.add_child(n)
	var s := Label.new()
	s.text = sub
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(s, UIKit.FS_BODY, sub_color, 2)
	v.add_child(s)
	return cell


func _refresh_inventory() -> void:
	if not _inventory_body or not is_instance_valid(_inventory_body):
		return
	for c in _inventory_body.get_children():
		c.queue_free()

	## Silahlar
	var max_w: int = MAX_OWNED_WEAPONS
	if _player and _player.has_method("get_max_owned_weapons"):
		max_w = _player.get_max_owned_weapons()
	var owned_w: Array = GameManager.owned_weapons
	_inventory_body.add_child(_section_title("SİLAHLAR  %d/%d" % [owned_w.size(), max_w]))
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 12)
	for i in range(max_w):
		if i < owned_w.size():
			var wk: String = str(owned_w[i].get("key", ""))
			wrow.add_child(_inventory_cell("weapon", wk, 1, WEAPON_NAMES.get(wk, wk.capitalize()), "Sv. %d" % int(owned_w[i].get("level", 1))))
		else:
			wrow.add_child(_inventory_cell("", "", 1, "Boş", " "))
	_inventory_body.add_child(wrow)

	## Kalkan (savaş modları kullanıcı isteğiyle envanterden kaldırıldı)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 12)
	var owned_shield: String = _owned_shield_type()
	var shield_box := VBoxContainer.new()
	shield_box.add_theme_constant_override("separation", 6)
	shield_box.add_child(_section_title("KALKAN"))
	if owned_shield != "":
		var lvl: int = int(GameManager.get(owned_shield + "_level"))
		var mx: int = int(ShopScript.MAX_LEVELS.get(owned_shield, 20))
		shield_box.add_child(_inventory_cell("shield", owned_shield, 1, SHIELD_NAMES.get(owned_shield, ""), "Sv. %d/%d" % [lvl, mx]))
	else:
		shield_box.add_child(_inventory_cell("", "", 1, "Yok", " "))
	srow.add_child(shield_box)
	_inventory_body.add_child(srow)

	## Eşyalar
	var max_i: int = 1
	if _player and _player.has_method("get_max_item_slots"):
		max_i = _player.get_max_item_slots()
	var owned_i: Array = GameManager.owned_items
	_inventory_body.add_child(_section_title("EŞYALAR  %d/%d" % [owned_i.size(), max_i]))
	var irow := HFlowContainer.new()
	irow.add_theme_constant_override("h_separation", 12)
	irow.add_theme_constant_override("v_separation", 12)
	for i in range(maxi(max_i, owned_i.size())):
		if i < owned_i.size():
			var ik: String = str(owned_i[i].get("key", ""))
			var tier: int = int(owned_i[i].get("tier", 1))
			irow.add_child(_inventory_cell("item", ik, tier, Items.get_def(ik).get("name", ik.capitalize()), TierSystem.NAMES[tier - 1], TierSystem.COLORS[tier - 1]))
		else:
			irow.add_child(_inventory_cell("", "", 1, "Boş", " "))
	_inventory_body.add_child(irow)
	_fit_inventory_scroll()


## bkz. _inventory_scroll üstündeki not. İçeriğin gerçek (minimum) boyutu hesaplanıp kaydırma alanı ona göre
## boyutlandırılır: genişlik = içerik (+ dikey kaydırma çubuğu payı), yükseklik = min(içerik, ekrana sığan).
func _fit_inventory_scroll() -> void:
	if not (_inventory_scroll and is_instance_valid(_inventory_scroll) and _inventory_body and is_instance_valid(_inventory_body)):
		return
	var content: Vector2 = _inventory_body.get_combined_minimum_size()
	var vp_h: float = get_viewport().get_visible_rect().size.y
	var max_h: float = maxf(200.0, vp_h - INVENTORY_SCREEN_MARGIN - INVENTORY_HEADER_ALLOWANCE)
	var needs_scroll: bool = content.y > max_h
	var bar_w: float = _inventory_scroll.get_v_scroll_bar().get_combined_minimum_size().x + 8.0 if needs_scroll else 0.0
	_inventory_scroll.custom_minimum_size = Vector2(content.x + bar_w, minf(content.y, max_h))


## Kullanıcı bu bir DÜKKAN olduğu için fiyatın tier'a göre değişip
## değişmeyeceğini belirtmedi - sandığın AKSİNE burası ücretsiz değil, bu
## yüzden üst tier eşyalar (bkz. Items.ITEM_TIER_POWER, %100/%150/%200/%250
## güç) taban fiyatın AYNI oranında daha PAHALI satılıyor ki bir Efsanevi
## eşya bir Sıradan eşyayla aynı fiyata "bedavadan" güçlü olmasın.
## DÜZELTME (kullanıcı isteği: "Oyunun ekonomisi kazanca göre şekillenmeli.
## En düşük 20 altından başlamalı eşya fiyatları kazanç arttıkça artacak
## fiyatlar.") - eski taban fiyatlar (WEAPON_COST_BASE/Items cost_base)
## SABİTTİ, oyunun neresinde olursanız olun aynı kalıyordu. Artık bu
## tabanlar SADECE eşyalar arası GÖRECELİ "şekli" korumak için kullanılıyor
## (Yıldırım Asası hep Bıçak'tan pahalı kalsın diye) - gerçek Altın miktarı
## enemy_spawner.gd _current_tier() ile AYNI game_time/tier_duration
## mantığıyla o anki Kademeye göre ölçekleniyor: erken oyunda taban fiyatın
## sadece bir kısmı istenir (küçük eşyalar 20 altın tabanına sıkışır),
## Kademe ilerledikçe (oyuncular daha çok kazandıkça) fiyat da katlanarak
## artar.
const MERCHANT_PRICE_TIER_DURATION := 100.0 ## enemy_spawner.gd tier_duration ile AYNI değer
const MERCHANT_PRICE_MIN := 20
const MERCHANT_PRICE_EARLY_SCALE := 0.25 ## Kademe 1'de taban fiyatın ~%25'i istenir
const MERCHANT_PRICE_PER_TIER_GROWTH := 0.12 ## Kademe başına +%12

func _merchant_price_tier() -> int:
	var t: float = GameManager.game_time
	return clampi(1 + int(t / MERCHANT_PRICE_TIER_DURATION), 1, 15)

## Kullanıcı isteği (2026-09-24): "seyyar satıcı marketindeki rerollama hakkı tıpkı level atlama kartlarındaki gibi
## altınla olacak ve fiyatı da onun gibi artacak". Karıştırma fiyatının TEK kaynağı - level_up_screen.gd _reroll_cost da
## bunu çağırır (iki ekranın formülü birbirinden sapmasın):
##   taban = REROLL_BASE_COST x satıcı fiyat ölçeği (yukarıdaki Kademe/zaman eğrisi, Kademe 1'e göre oranlanmış -
##           Kademe 1'de 3, Kademe 5'te ~9, Kademe 15'te ~23 altın)
##   fiyat = taban x (1 + o ekranda/ziyarette yapılan karıştırma sayısı) -> 3, 6, 9, 12 ...
## Level atlama ekranında sayaç ekran başına, seyyar satıcıda ziyaret başına (traveling_merchant.gd) sıfırlanır.
const REROLL_BASE_COST := 3.0


static func reroll_cost(rerolls_done: int) -> int:
	var tier: int = clampi(1 + int(GameManager.game_time / MERCHANT_PRICE_TIER_DURATION), 1, 15)
	var price_scale: float = (MERCHANT_PRICE_EARLY_SCALE + float(tier - 1) * MERCHANT_PRICE_PER_TIER_GROWTH) / MERCHANT_PRICE_EARLY_SCALE
	var base: int = maxi(1, int(round(REROLL_BASE_COST * price_scale)))
	return base * (1 + maxi(0, rerolls_done))


func _scale_merchant_price(base_shape: float) -> int:
	var scale: float = MERCHANT_PRICE_EARLY_SCALE + float(_merchant_price_tier() - 1) * MERCHANT_PRICE_PER_TIER_GROWTH
	return max(MERCHANT_PRICE_MIN, int(round(base_shape * scale)))

## Kullanıcı isteği (2026-09-21): Ruhani Yetenek "Para" pasifi (bkz. GameManager.apply_shop_discount) - indirim tek
## seferde, en sonda uygulanır; iç hesaplar ShopScript'in *_raw (indirimsiz) fonksiyonlarını kullanır (çift indirim olmasın).
func _entry_cost(entry: Dictionary) -> int:
	return GameManager.apply_shop_discount(_entry_cost_raw(entry))


func _entry_cost_raw(entry: Dictionary) -> int:
	var key: String = entry.get("key", "")
	match entry.get("type"):
		"item":
			var base_cost: int = int(Items.get_def(key).get("cost_base", 50))
			var power_mult: float = Items.ITEM_TIER_POWER[int(entry.get("tier", 1)) - 1]
			return _scale_merchant_price(base_cost * power_mult)
		"weapon":
			## DÜZELTME (kullanıcı isteği: "Multiplayerda ilk seçtiğimiz
			## silahtan sonra alacağımız 2. silah ucuz olacak 3. 4 .5 silahı
			## 80 gold civarında başlat") - artık silah TÜRÜNDEN değil
			## (WEAPON_COST_BASE artık kullanılmıyor), shop_panel.gd'deki
			## AYNI kademeli taban fiyatı (bkz. ShopScript._copy_cost) sahip
			## olunan TOPLAM silah sayısına göre kullanıyor - üstüne bu
			## dükkana özgü Kademe/zaman ölçeklemesi (_scale_merchant_price)
			## hâlâ AYNI şekilde uygulanıyor.
			var next_total: int = GameManager.owned_weapons.size() + 1
			return _scale_merchant_price(float(ShopScript._copy_cost_raw(key, next_total)))
		"shield":
			var next_level: int = int(GameManager.get(key + "_level")) + 1
			return _scale_merchant_price(float(ShopScript._upgrade_cost_raw(key, next_level)))
	return 0


## bkz. _entry_cost üstündeki DÜZELTME notu - kullanıcı isteği: "fiyatı
## ucuzdan pahalıya göre sıralanmalı".
func _sort_stock_by_cost() -> void:
	_stock.sort_custom(func(a, b): return _entry_cost(a) < _entry_cost(b))


func _owned_shield_type() -> String:
	for key in SHIELD_TYPE_KEYS:
		if int(GameManager.get(key + "_level")) > 0:
			return key
	return ""


## bkz. yukarıdaki "Satıldı kaydı" notu.
func _entry_sold(entry: Dictionary) -> bool:
	return bool(entry.get("sold", false))


func _entry_can_buy(entry: Dictionary, _index: int) -> bool:
	if _entry_sold(entry):
		return false
	var key: String = entry.get("key", "")
	var cost: int = _entry_cost(entry)
	if GameManager.gold < cost:
		return false
	match entry.get("type"):
		"item":
			var max_slots: int = 1
			if _player and _player.has_method("get_max_item_slots"):
				max_slots = _player.get_max_item_slots()
			return GameManager.owned_items.size() < max_slots
		"weapon":
			## Sahip olunan bir silah türü de alınabilir ("ateş asam var, boş slotum var
			## ama dükkandaki ateş asasını alamıyorum" bildirimi) - kural "kart başına
			## ziyaret başına 1 kez" (bkz. _entry_sold), sahiplik engeli DEĞİL.
			var max_w: int = MAX_OWNED_WEAPONS
			if _player and _player.has_method("get_max_owned_weapons"):
				max_w = _player.get_max_owned_weapons()
			return GameManager.owned_weapons.size() < max_w
		"shield":
			var cur_level: int = int(GameManager.get(key + "_level"))
			if cur_level >= int(ShopScript.MAX_LEVELS.get(key, 20)):
				return false
			var owned: String = _owned_shield_type()
			return owned == "" or owned == key
	return false


func _on_buy_pressed(index: int) -> void:
	if index < 0 or index >= _stock.size():
		return
	var entry: Dictionary = _stock[index]
	if not _entry_can_buy(entry, index):
		return
	var key: String = entry.get("key", "")
	var cost: int = _entry_cost(entry)
	match entry.get("type"):
		"item":
			var power_mult: float = Items.ITEM_TIER_POWER[int(entry.get("tier", 1)) - 1]
			if _player and _player.has_method("buy_item") and _player.buy_item(key, power_mult):
				GameManager.gold -= cost
				GameManager.owned_items.append({"key": key, "spent": cost, "power": power_mult, "tier": int(entry.get("tier", 1))})
				entry["sold"] = true
		"weapon":
			## bkz. shop_panel.gd _on_buy_copy / chest_menu.gd _on_al_pressed
			## AYNI sıra: önce deftere ekle, sonra gerçek silah node'unu spawn et.
			GameManager.gold -= cost
			GameManager.owned_weapons.append({"key": key, "level": 1, "spent": cost})
			if _player and _player.has_method("buy_weapon_copy"):
				_player.buy_weapon_copy(key, 1)
			entry["sold"] = true
		"shield":
			var next_level: int = int(GameManager.get(key + "_level")) + 1
			GameManager.gold -= cost
			GameManager.set(key + "_level", next_level)
			if _player and _player.has_method("refresh_shield_stats"):
				_player.refresh_shield_stats()
			entry["sold"] = true
	_refresh_all_buy_states()
	_refresh_reroll_button()
	if _selected_index == index:
		_refresh_details()


func _refresh_all_buy_states() -> void:
	for i in range(_stock.size()):
		var entry: Dictionary = _stock[i]
		var sold: bool = _entry_sold(entry)
		_buy_buttons[i].disabled = not _entry_can_buy(entry, i)
		_buy_buttons[i].text = "SATILDI" if sold else "AL"
		_price_labels[i].text = "%d Altın" % _entry_cost(entry)
	_refresh_card_styles()
	_refresh_stats()
	_refresh_inventory()


func _refresh_reroll_button() -> void:
	if not _reroll_btn:
		return
	if not _merchant or not is_instance_valid(_merchant):
		_reroll_btn.visible = false
		return
	var cost: int = int(_merchant.get_reroll_cost())
	var text: String = "YENİDEN ÇEVİR (%d altın)" % cost
	if _reroll_btn.text != text:
		_reroll_btn.text = text
	_reroll_btn.disabled = GameManager.gold < cost


## Kullanıcı isteği: "Seyyar satıcıdaki eşyaları rerollama butonu ekle" - altın
## ödeyip (bkz. reroll_cost) TravelingMerchant'tan tamamen taze bir stok ister, tüm
## kartları (ve "SATILDI" durumlarını - artık FARKLI eşyalar olduğu için
## eski durum anlamsız) sıfırdan kurar.
func _on_reroll_pressed() -> void:
	if not _merchant or not is_instance_valid(_merchant):
		return
	var new_stock: Variant = _merchant.try_reroll_stock()
	if new_stock == null:
		return
	_stock = new_stock
	_sort_stock_by_cost()
	## bkz. traveling_merchant.gd try_reroll_stock() - "satıldı" kaydı ARTIK
	## orada, reroll çağrısının kendisi zaten sıfırlıyor.
	_selected_index = -1
	_rebuild_grid()
	_refresh_all_buy_states()
	_refresh_reroll_button()
	_refresh_stats()
	if not _stock.is_empty():
		_select_index(0)


func _on_close_pressed() -> void:
	GameManager.unregister_blocking_panel(self)
	closed.emit()
	queue_free()
