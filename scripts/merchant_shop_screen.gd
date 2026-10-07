extends CanvasLayer

## 2026-10-07: silahlar (ve kalkanlar) artık BURADA satılmıyor - demirci dükkanına taşındı (scripts/weapon_shop.gd +
## weapon_shop_screen.gd; kullanıcı: "seyyar satıcıda silah satılmayacak bundan böyle"). Aşağıdaki eski notlardaki silah/kalkan
## kartı anlatımları tarihsel; satıcı yalnızca 8 eşya gösterir. ENVANTER penceresi sahip olunan silahları göstermeye devam eder.
##
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
const EventSfx := preload("res://scripts/event_sfx.gd")

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
var _grid: GridContainer = null ## eşya kartları (4 sütun) - 2026-10-07: silahlar artık burada satılmıyor (demirci dükkanı, weapon_shop.gd)
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
## Tarif satırı (eşya önizlemesi): bileşen ikonları - sahip olunanlar parlak, olmayanlar soluk (bkz. _refresh_recipe).
var _details_recipe_box: VBoxContainer
var _details_recipe_row: HFlowContainer
var _details_recipe_note: Label
var _details_block: Label
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
	EventSfx.play(get_tree(), &"shop_open")
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
	if _phone:
		_fit_phone_columns() ## kaydırma kutusu son genişliğine yerleşimden sonra gelir - ucuz, her kare
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
## Kullanıcı isteği (2026-09-25): "seyyar satıcı arayüzünü %25 küçültmeni istiyorum herşey kocaman ve tüm ekranı kaplıyor
## nerdeyse" - pencerenin tamamı (yazılar, kartlar, butonlar birlikte) merkezinden x0.75 ölçeklenir; CenterContainer onu
## ölçeksiz boyutuna göre ortaladığı için pivot pencerenin ortasında tutulur. Fare/tıklama dönüşümü Godot'ta ölçekle doğru çalışır.
## Kullanıcı bildirimi (2026-10-02): "seyyar satıcıdaki yazılar zor okunuyor, çözünürlüklerinde gariplik var" - m5x7 piksel
## fontu yalnızca 16'nın katı boyutlarda (16/32/48) net; x0.75 ölçek 32'lik yazıyı 24'e (1.5 px/font pikseli) çekip
## düzensiz kalınlıklar yapıyordu (ikonlar da 2.75x oluyordu). Ölçek 1.0'a döndü; pencere kart düzeni sıkılaştırılarak
## ekrana sığdırıldı (kademe etiketi yerine çerçeve rengi, ikonlar tam sayı katı). Aşağıdaki sığdırma artık sadece
## yedek (1080'den küçük bir görüntü alanı olursa).
const WINDOW_SCALE := 1.0

## TELEFON: TAM EKRAN (kullanıcı isteği 2026-10-04: "dükkan ekranı v.b bir pencere değil direk ekranı komple kaplayan bir
## arayüz olsun ... her alanın değerlendirilmesini istiyorum" + "tüm telefonlarla uyumlu"). Eskiden pencere MenuFitter ile
## ekrana sığdırılıyordu (içerik 1080'den uzun -> KÜÇÜLÜYORDU, yazılar ufacıktı). Artık katman PHONE_K kat büyütülür (piksel
## yazı 32 -> 48, keskin), pencere güvenli alanın TAMAMINI kaplar (CenterContainer yok), kart ızgarası kaydırılır ve sütun
## sayısı kalan genişlikten hesaplanır (16:9'dan 21:9'a). Masaüstü değişmedi.
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const PHONE_K := 1.5
var _phone: bool = false
var _phone_scroll: ScrollContainer = null


## Telefonda pencerenin kaplayacağı alan (katman koordinatı = ekran / PHONE_K).
func _phone_rect() -> Rect2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var safe: Rect2 = MobileUIScript.safe_margins(get_viewport())
	return Rect2(safe.position / PHONE_K, (view - safe.position - safe.size) / PHONE_K)


## Kart sütunları kaydırma kutusunun genişliğine göre (kart 228 + aralık 14).
func _fit_phone_columns() -> void:
	if not is_instance_valid(_phone_scroll):
		return
	var avail: float = _phone_scroll.size.x - 20.0
	var cols: int = maxi(1, int(floor((avail + 14.0) / (228.0 + 14.0))))
	if _grid:
		if _grid.columns != cols:
			_grid.columns = cols
		## Kartlar sütunu doldursun (sütun sayısına bölünemeyen genişlik kartlara dağılır, sağda boşluk kalmaz).
		for c in _grid.get_children():
			(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL

## DÜZELTME (2026-10-02): Godot'ta Container.fit_child_in_rect çocuğun ölçeğini HER yerleşimde 1'e sıfırlar - pencere
## CenterContainer'ın çocuğu olduğu için 2026-09-25'teki x0.75 hiç uygulanmıyordu (ölçüm: scale (1, 1)). Ölçek artık
## yerleşim BİTTİKTEN sonra (sort_children sinyali) verilir; yeni eşya bölümüyle uzayan pencere ekrana sığmıyorsa ayrıca
## küçülür (en fazla WINDOW_SCALE).
## Kullanıcı bildirimi (2026-10-02): "seyyar satıcı paneli ekranın ortasında durmuyor" - ölçeksiz pencere (1214 px) ekrandan
## (1080) uzun olunca CenterContainer kendini aşağı doğru büyütüp pencereyi y=0'a koyuyordu; ölçeklenmiş pencerenin merkezi
## ekran merkezinin ~67 px altına düşüyordu. Pivot merkezde olduğu için görünen merkez = position + size/2 -> ekran merkezine
## sabitlenir.
func _apply_window_scale(window: Control) -> void:
	var fit_scale := func() -> void:
		if not is_instance_valid(window):
			return
		window.pivot_offset = window.size * 0.5
		var view: Vector2 = window.get_viewport_rect().size
		var fit: float = minf(view.x * 0.97 / maxf(1.0, window.size.x), view.y * 0.97 / maxf(1.0, window.size.y))
		window.scale = Vector2.ONE * minf(WINDOW_SCALE, fit)
		## position (ham, ölçeksiz) kullanılır - 4.7'de global_position pivot/ölçek kaymasını içeriyor (ölçülerek görüldü).
		var parent_ci := window.get_parent() as CanvasItem
		var center_local: Vector2 = view * 0.5
		if parent_ci:
			center_local = parent_ci.get_global_transform().affine_inverse() * center_local
		window.position = (center_local - window.size * 0.5).round()
	var parent: Node = window.get_parent()
	if parent is Container:
		(parent as Container).sort_children.connect(fit_scale)
	else:
		window.resized.connect(fit_scale)
	fit_scale.call()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.07, 0.03, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_phone = MobileUIScript.enabled
	var window := PanelContainer.new()
	window.add_theme_stylebox_override("panel", UIKit.panel_style("window"))
	if _phone:
		scale = Vector2.ONE * PHONE_K
		window.theme = UIKit.theme()
		add_child(window)
		var r: Rect2 = _phone_rect()
		window.position = r.position
		window.size = r.size
		window.custom_minimum_size = r.size
	else:
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## 2026-09-24: oyun içi bej kit teması (koyu yazı, ten butonlar) - CanvasLayer temayı aktarmadığı için buradan.
		center.theme = UIKit.theme()
		add_child(center)
		center.add_child(window)
		_apply_window_scale(window)

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
	if _phone:
		## 16:9 telefonda (1280 birim) masaüstü başlık genişlikleri pencereyi sağdan taşırıyordu.
		_gold_label.custom_minimum_size.x = 150.0
		inv_btn.custom_minimum_size.x = 190.0
		_reroll_btn.custom_minimum_size.x = 0.0
	vbox.add_child(title_bar)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	vbox.add_child(body)

	var details_panel: Control = _build_details_panel()
	body.add_child(details_panel)
	var grid_node: Control = _build_grid()
	if _phone:
		## Telefon: ızgara kalan genişliği ve yüksekliği doldurur, sığmayan kartlar parmakla kaydırılır.
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_phone_scroll = ScrollContainer.new()
		_phone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_phone_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_phone_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_phone_scroll.follow_focus = true
		grid_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_phone_scroll.add_child(grid_node)
		body.add_child(_phone_scroll)
		_phone_scroll.resized.connect(_fit_phone_columns)
	else:
		body.add_child(grid_node)
	var stats_panel: Control = _build_stats_panel()
	body.add_child(stats_panel)
	if _phone:
		## 16:9 telefonda (1920 / PHONE_K = 1280 birim) masaüstü genişlikleri (360 + 2 kart + 380) sığmıyordu.
		details_panel.custom_minimum_size.x = 260.0
		stats_panel.custom_minimum_size.x = 290.0
		## Açıklama yazıları 320 en az genişlikle detay panelini genişletiyordu (ızgara 16:9'da tek sütuna düşüyordu).
		_details_desc.custom_minimum_size.x = 0.0
		_details_recipe_note.custom_minimum_size.x = 0.0

	## bkz. chest_menu.gd'nin AYNI notu - sadece tık sesi, görsel stil zaten yukarıda UIKit ile elle uygulandı.
	UISound.connect_all_buttons(self)

	_refresh_all_buy_states()
	_refresh_reroll_button()
	_refresh_stats()
	if not _stock.is_empty():
		_select_index(0)


## Detay açıklama kutusunun dikey çubuk için ayrılan payı (px) - ölçüm: Godot kit teması çubuğu 18 px; pay çubuktan büyük olmalı (bkz. _build_details_panel).
const DESC_SCROLLBAR_RESERVE := 28.0


## Yan panellerin (detay / stat) içeriğini panele ekler. TELEFON (2026-10-06, kullanıcı bildirimi "marketteki kaydırma sorunu hâlâ
## düzelmemiş"): panel içeriği kendi kaydırma kutusuna konur. Eskiden içerik doğrudan PanelContainer'daydı ve en az yüksekliği (uzun adlı /
## tarifli eşyada detay paneli 868 birim, mevcut alan 564) pencereyi EKRANDAN UZUN yapıyordu: ortadaki kart ızgarasının kaydırma kutusu
## aniden uzayıp kaydırma sınırı (826 -> 522) düşüyor, liste sıçrıyor, pencerenin altı (AL düğmeleri) ekran dışında kalıyordu; kart seçilince
## (kaydırmaya başlarken parmak karta basar) pencere boyu eşyaya göre sürekli değişiyordu. Kaydırma kutusunun en az yüksekliği 0 olduğundan
## pencere artık HER ZAMAN `_phone_rect()` boyunda kalır, uzun içerik panelin içinde kayar.
func _attach_side_panel_content(panel: PanelContainer, margin: MarginContainer) -> void:
	if not _phone:
		panel.add_child(margin)
		return
	var sc := ScrollContainer.new()
	sc.name = "SidePanelScroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(sc)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(margin)


## Sol: seçili eşyanın büyük ikonu, adı, kademesi, açıklaması ve fiyatı.
func _build_details_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	panel.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_attach_side_panel_content(panel, margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_details_icon_holder = Control.new()
	_details_icon_holder.custom_minimum_size = Vector2(192, 192)
	_details_icon_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	## bkz. _build_card ile AYNI kare ikon-slotu deseni (_build_icon_slot) - çerçeve tier'a göre _refresh_details()'te güncellenir.
	## İkon alanı 144 px = 3x (32 px eşya) / 3x (48 px kalkan) => piksel-net.
	_details_icon_inset = _build_icon_slot(_details_icon_holder, 1, 32.0) ## 128 px = 4x (32 px eşya ikonu) -> piksel-net
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
	## DONMA + ÇÖKME DÜZELTMESİ (kullanıcı bildirimi 2026-10-06: "markette donma devam ediyor ve bu sefer donduktan sonra kapandı"): dikey çubuk
	## yalnızca gerekince göründüğü için bu kutunun EN AZ GENİŞLİĞİ çubuk görününce 320 -> 338'e (içerik + çubuk) sıçrıyordu; detay paneli o genişliğe
	## göre ölçüldüğü için panel genişliği, dolayısıyla eşya adının (ör. "Savaşçının Kılıcı") satır sayısı 1 <-> 2 oluyor, bu detay sütununun
	## en az yüksekliğini 26 px oynatıp açıklamaya kalan yüksekliği (260 <-> 286) ve çubuğun gerekip gerekmediğini yeniden değiştiriyordu: metin
	## tam sınırdaysa DÖNGÜ HİÇ DURMUYORDU. Godot yerleşim güncellemelerini ertelenmiş çağrı kuyruğuyla işlediği için kuyruk bir karede dolana kadar
	## (32 MB, ölçüm: ~1,4 milyon çağrı) oyun donuyor, sonra çöküyordu ("bazen": yalnızca bazı eşya adı/açıklaması uzunluklarında, ölçüm: 10 denemenin 3'ü).
	## Çubuk payı baştan ayrılır: en az genişlik çubuk görünsün ya da görünmesin AYNI kalır.
	desc_scroll.custom_minimum_size = Vector2(320.0 + DESC_SCROLLBAR_RESERVE, 150)
	desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if _phone:
		## Telefonda tüm panel zaten kayıyor (bkz. _attach_side_panel_content): iç içe iki kaydırma kutusu parmağı şaşırtır.
		desc_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		desc_scroll.custom_minimum_size = Vector2.ZERO
	vbox.add_child(desc_scroll)
	_details_desc = Label.new()
	_details_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.style_label(_details_desc, UIKit.FS_BODY, UIKit.C_TEXT_DIM)
	_details_desc.custom_minimum_size = Vector2(320, 0)
	_details_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_scroll.add_child(_details_desc)

	## Tarif (2026-10-02): bileşenler + sahip olunan parçaların fiyattan düşülmesi (bkz. Items.plan_purchase).
	_details_recipe_box = VBoxContainer.new()
	_details_recipe_box.add_theme_constant_override("separation", 6)
	var rt := Label.new()
	rt.text = "TARİF"
	UIKit.style_label(rt, UIKit.FS_BODY, UIKit.C_ACCENT, 2)
	_details_recipe_box.add_child(rt)
	_details_recipe_row = HFlowContainer.new()
	_details_recipe_row.add_theme_constant_override("h_separation", 6)
	_details_recipe_row.add_theme_constant_override("v_separation", 6)
	_details_recipe_box.add_child(_details_recipe_row)
	_details_recipe_note = Label.new()
	_details_recipe_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_recipe_note.custom_minimum_size = Vector2(320, 0)
	UIKit.style_label(_details_recipe_note, UIKit.FS_BODY, UIKit.C_TEXT_DIM, 0)
	_details_recipe_box.add_child(_details_recipe_note)
	vbox.add_child(_details_recipe_box)

	_details_price = Label.new()
	_details_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(_details_price, UIKit.FS_TITLE, UIKit.C_GOLD, 3)
	vbox.add_child(_details_price)

	_details_block = Label.new()
	_details_block.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details_block.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.style_label(_details_block, UIKit.FS_BODY, UIKit.C_BAD, 0)
	vbox.add_child(_details_block)

	return panel


func _build_grid() -> Control:
	## 2026-10-02: silah ve eşya ayrı bölümlerdi; 2026-10-07: silahlar demirci dükkanına taşındı (weapon_shop.gd), burada sadece
	## EŞYALAR (4x2) kaldı.
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var ibox := VBoxContainer.new()
	ibox.add_theme_constant_override("separation", 8)
	ibox.add_child(_section_title("EŞYALAR"))
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	ibox.add_child(_grid)
	row.add_child(ibox)
	_populate_grid()
	return row

func _populate_grid() -> void:
	for old_card in _card_panels:
		if is_instance_valid(old_card):
			old_card.remove_from_group(&"gamepad_first_focus") ## karıştırmada silinen kart ilk odak adayı kalmasın
	_card_panels.clear()
	_buy_buttons.clear()
	_price_labels.clear()
	for i in range(_stock.size()):
		_grid.add_child(_build_card(i))
	## Kumanda: dükkan açılınca ilk odak üstteki bir düğme değil ilk kart olsun (gamepad_ui.gd FIRST_FOCUS_GROUP).
	if not _card_panels.is_empty():
		(_card_panels[0] as Node).add_to_group(&"gamepad_first_focus")

## _on_reroll_pressed tarafından çağrılır - TAMAMEN yeni bir stokla kartları
## sıfırdan kurar (bkz. _build_ui()'nin ilk kuruluşuyla AYNI _populate_grid).
func _rebuild_grid() -> void:
	if _grid:
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
	## 2026-10-02: 3 sıra kart (1 silah + 2 eşya) x1.0 ölçekte ekrana sığsın diye yükseklik içeriğe göre (eskiden 336).
	card.custom_minimum_size = Vector2(228, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("panel", UIKit.panel_style("card"))
	card.gui_input.connect(_on_card_gui_input.bind(index))
	## DÜZELTME (kullanıcı isteği: "gamepad desteği ekle") - bu PanelContainer bir Button OLMADIĞI için motor "focus" stilini
	## kendiliğinden çizmiyor, GamepadFocusHelper kendi kenarlığını ekliyor (bkz. o dosyadaki not).
	card.focus_mode = Control.FOCUS_ALL
	GamepadFocusHelper.add_focus_ring(card)
	## KUMANDA SATIN ALMA DÜZELTMESİ (kullanıcı bildirimi 2026-10-04: "joystick kullanırken seyyar satıcıdan satın alma
	## butonlarına basamıyorum"): kart odaklanabilir olduğu için içindeki AL butonu D-pad'in odak aramasına HİÇ girmiyordu
	## (ölçüldü: 4 kartın 4 AL butonu da ulaşılamaz) ve karta A basmak sadece "seç" yapıyordu - kumandayla satın almanın yolu
	## yoktu. Artık D-pad bir karta gelince o kart seçilir (ayrıntılar solda görünür), A (ui_accept) odaktaki kartı SATIN ALIR
	## (bkz. _on_card_gui_input). Fare akışı aynen: tık seçer, AL satın alır.
	card.focus_entered.connect(_select_index.bind(index))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	## 2026-10-02: kartın üstündeki kademe yazısı (Parça/Epik/Efsanevi, Silah) kaldırıldı - kademe ikon çerçevesinin renginden
	## (kahve/mavi/mor) okunuyor, adı soldaki ayrıntı panelinde; pencere x1.0'da ekrana sığsın diye.
	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(112, 112)
	icon_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_inset: Control = _build_icon_slot(icon_holder, _entry_slot_tier(entry), 8.0) ## 96 px = 3x (32 px ikon)
	_add_icon(icon_inset, entry)
	vbox.add_child(icon_holder)

	var name_label := Label.new()
	name_label.text = _entry_name(entry)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0, 52)
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIKit.style_label(name_label, UIKit.FS_BODY, UIKit.C_TEXT, 3)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	## 2026-10-02: fiyat + AL aynı satırda (pencere x1.0'da ekrana sığsın diye bir satır kazanıldı).
	var buy_row := HBoxContainer.new()
	buy_row.add_theme_constant_override("separation", 6)
	buy_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(buy_row)
	var price_label := Label.new()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.style_label(price_label, UIKit.FS_BODY, UIKit.C_GOLD, 3)
	price_label.text = "%d Altın" % _entry_cost(entry)
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy_row.add_child(price_label)

	## Kullanıcı isteği: "eşyaların altında minik satın al butonları olsun" - artık okunaklı boyutta (yeşil onay plakası).
	var buy_btn := Button.new()
	buy_btn.text = "AL"
	buy_btn.custom_minimum_size = Vector2(72, 50)
	UIKit.style_button(buy_btn, "green", false, UIKit.FS_BODY)
	buy_btn.pressed.connect(_on_buy_pressed.bind(index))
	buy_btn.focus_mode = Control.FOCUS_NONE ## kumanda/klavye odağı kartta (A = satın al); fare tıklaması etkilenmez
	buy_row.add_child(buy_btn)

	_card_panels.append(card)
	_buy_buttons.append(buy_btn)
	_price_labels.append(price_label)
	return card


## Kartın küçük "tür" etiketi (kademesi olmayan kartlar için; 2026-10-07'den beri satıcıda sadece eşya var).
func _entry_kind_text(_entry: Dictionary) -> String:
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
	## Eşya kademesi = çerçeve rengi (1 kahve, 2 mavi parıltılı, 3 mor parıltılı - kullanıcı: "oyunda hali hazırda mevcut").
	return Items.kademe(str(entry.get("key", ""))) if entry.get("type") == "item" else 1

func _entry_name(entry: Dictionary) -> String:
	var key: String = entry.get("key", "")
	match entry.get("type"):
		"item":
			return Items.item_name(key)
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
			## 2026-10-02: kullanıcının 32x32 eşya ikonları (assets/items/<anahtar>.png, bkz. items.gd).
			tex_rect.texture = Items.icon(key)
			tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_index(index)
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		## Kumanda/klavye: odaktaki kartı satın al (satılmış/yetersiz altınlı kartta _on_buy_pressed sessizce çıkar).
		_select_index(index)
		_on_buy_pressed(index)


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


func _refresh_details() -> void:
	if _selected_index < 0 or _selected_index >= _stock.size():
		return
	var entry: Dictionary = _stock[_selected_index]
	var key: String = str(entry.get("key", ""))
	_details_name.text = _entry_name(entry)
	_details_recipe_box.visible = false
	_details_block.text = ""
	if entry.get("type") == "item":
		var kd: int = Items.kademe(key)
		_details_tier.text = Items.KADEME_NAMES[kd - 1]
		_details_tier.add_theme_color_override("font_color", TierSystem.COLORS[kd - 1])
		var desc: String = Items.describe(key)
		var ups: Array = Items.builds_into(key)
		if not ups.is_empty():
			var names: Array = []
			for u in ups:
				names.append(Items.item_name(u))
			desc += "\n\nYükseltmeleri: " + ", ".join(names)
		_details_desc.text = desc
		_refresh_recipe(key)
		if not _entry_sold(entry):
			var reason: String = Items.purchase_block_reason(key, GameManager.owned_items, _part_slots())
			_details_block.text = reason
	_details_icon_frame.texture = TierSystem.MINI_FRAME_TEXTURES[_entry_slot_tier(entry) - 1]
	for c in _details_icon_inset.get_children():
		c.queue_free()
	_add_icon(_details_icon_inset, entry)
	_details_price.text = "%d Altın" % _entry_cost(entry)


## Tarif satırı: her bileşen küçük kademe çerçeveli ikon; sahip olunan (bu satın almada tüketilecek) bileşenler parlak.
## Alt satırda tam fiyat ve indirim dökümü.
func _refresh_recipe(key: String) -> void:
	for c in _details_recipe_row.get_children():
		c.queue_free()
	var rec: Array = Items.recipe(key)
	if rec.is_empty():
		return
	_details_recipe_box.visible = true
	var plan: Dictionary = Items.plan_purchase(key, GameManager.owned_items)
	var owned_keys: Array = []
	for idx in plan.get("consume", []):
		owned_keys.append(str((GameManager.owned_items[int(idx)] as Dictionary).get("key", "")))
	var pool: Array = owned_keys.duplicate()
	for comp in rec:
		var have: bool = pool.has(str(comp))
		if have:
			pool.erase(str(comp))
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(80, 80)
		holder.mouse_filter = Control.MOUSE_FILTER_PASS
		holder.tooltip_text = "%s (%d altın)%s" % [Items.item_name(str(comp)), Items.cost(str(comp)), "  - sende var" if have else ""]
		var inset: Control = _build_icon_slot(holder, Items.kademe(str(comp)), 8.0) ## 64 px = 2x ikon
		_add_icon_by(inset, "item", str(comp))
		holder.modulate = Color(1, 1, 1, 1) if have else Color(1, 1, 1, 0.38)
		_details_recipe_row.add_child(holder)
	var full: int = int(plan.get("full", Items.cost(key)))
	var pay: int = int(plan.get("cost", full))
	if pay < full:
		_details_recipe_note.text = "Sendeki parçalar: -%d" % (full - pay)
	else:
		_details_recipe_note.text = "Parça sendeyse fiyattan düşer"

## ---------------------------------------------------------------- sağ: kendine özgü stat penceresi
func _build_stats_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	panel.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_attach_side_panel_content(panel, margin)
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
	{"id": "heal_power", "label": "İyileştirme", "color": Color(UIKit.INK["health"])},
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
	t["heal_power"] = ("+%%%d" % int(round(float(p.heal_shield_power) * 100.0))) if "heal_shield_power" in p else "-"
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
	if _phone:
		## Katman PHONE_K büyütülmüş - tam ekran çapası ekranın PHONE_K katına taşardı; alanı elle ver.
		var pr: Rect2 = _phone_rect()
		_inventory_overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_inventory_overlay.offset_left = pr.position.x
		_inventory_overlay.offset_top = pr.position.y
		_inventory_overlay.offset_right = pr.end.x
		_inventory_overlay.offset_bottom = pr.end.y

	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.07, 0.03, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_overlay.add_child(dim)

	var window := PanelContainer.new()
	window.add_theme_stylebox_override("panel", UIKit.panel_style("window"))
	if _phone:
		## Telefon: envanter de tam alanı kaplar (ortalanmış/ölçeklenmiş pencere değil - bkz. PHONE_K notu).
		_inventory_overlay.add_child(window)
		window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inventory_overlay.add_child(center)
		center.add_child(window)
		_apply_window_scale(window)
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
	if _phone:
		_inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
		shield_box.add_child(_inventory_cell("shield", owned_shield, 1, ShieldEnchantDefs.type_name(owned_shield), " "))
	else:
		shield_box.add_child(_inventory_cell("", "", 1, "Yok", " "))
	srow.add_child(shield_box)
	_inventory_body.add_child(srow)

	## Eşyalar (2026-10-02): kademe başına ayrı bölüm ve slot sınırı - parça seviye başına 1, epik 10, efsanevi 5.
	var owned_i: Array = GameManager.owned_items
	for kd in [Items.KADEME_EFSANEVI, Items.KADEME_EPIK, Items.KADEME_PARCA]:
		var limit: int = Items.slot_limit(kd, _part_slots())
		var keys: Array = []
		for e in owned_i:
			var ik: String = str((e as Dictionary).get("key", ""))
			if Items.kademe(ik) == kd:
				keys.append(ik)
		var title: Label = _section_title("%s EŞYALAR  %d/%d" % [Items.KADEME_NAMES[kd - 1].to_upper(), keys.size(), limit])
		title.add_theme_color_override("font_color", TierSystem.COLORS[kd - 1])
		_inventory_body.add_child(title)
		var irow := HFlowContainer.new()
		irow.add_theme_constant_override("h_separation", 12)
		irow.add_theme_constant_override("v_separation", 12)
		## Boş yuvalar en fazla bir sıra (parça slotu seviyeyle büyür; uzun boş liste göstermeye gerek yok).
		var shown: int = mini(limit, maxi(keys.size(), int(ceil(float(maxi(keys.size(), 1)) / 5.0)) * 5))
		shown = maxi(shown, keys.size())
		for i in range(shown):
			if i < keys.size():
				var cell: Control = _inventory_cell("item", keys[i], kd, Items.item_name(keys[i]), Items.KADEME_NAMES[kd - 1], TierSystem.COLORS[kd - 1])
				cell.tooltip_text = "%s\n%s" % [Items.item_name(keys[i]), Items.describe(keys[i])]
				irow.add_child(cell)
			else:
				irow.add_child(_inventory_cell("", "", kd, "Boş", " "))
		_inventory_body.add_child(irow)
	_fit_inventory_scroll()


## bkz. _inventory_scroll üstündeki not. İçeriğin gerçek (minimum) boyutu hesaplanıp kaydırma alanı ona göre
## boyutlandırılır: genişlik = içerik (+ dikey kaydırma çubuğu payı), yükseklik = min(içerik, ekrana sığan).
func _fit_inventory_scroll() -> void:
	if _phone:
		return ## telefonda kaydırma kutusu pencerenin kalanını doldurur (SIZE_EXPAND_FILL)
	if not (_inventory_scroll and is_instance_valid(_inventory_scroll) and _inventory_body and is_instance_valid(_inventory_body)):
		return
	var content: Vector2 = _inventory_body.get_combined_minimum_size()
	var vp_h: float = get_viewport().get_visible_rect().size.y / (PHONE_K if _phone else 1.0)
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
	## Kullanıcı isteği (2026-10-02): "zaman ölçeklenmesini kaldır" - fiyatlar sabit (eşya: belgedeki fiyat, sahip olunan
	## parçalar düşülür; silah: shop_panel'in kademeli taban fiyatı).
	match entry.get("type"):
		"item":
			return int(Items.plan_purchase(key, GameManager.owned_items).get("cost", Items.cost(key)))
	return 0

## bkz. _entry_cost üstündeki DÜZELTME notu - kullanıcı isteği: "fiyatı
## ucuzdan pahalıya göre sıralanmalı".
func _sort_stock_by_cost() -> void:
	_stock.sort_custom(func(a, b): return _entry_cost(a) < _entry_cost(b))


func _owned_shield_type() -> String:
	return ShieldEnchantDefs.owned_type()


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
			return Items.purchase_block_reason(key, GameManager.owned_items, _part_slots()) == ""
	return false


## Parça slotu sayısı (seviye başına 1) - oyuncu yoksa (test) 1.
func _part_slots() -> int:
	if _player and _player.has_method("get_max_item_slots"):
		return int(_player.get_max_item_slots())
	return 1

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
			## Tarifli satın alma: sahip olunan bileşenler tüketilir (player.acquire_item kaydı da yazar).
			var plan: Dictionary = Items.plan_purchase(key, GameManager.owned_items)
			if _player and _player.has_method("acquire_item") and _player.acquire_item(key, plan, cost):
				GameManager.gold -= cost
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
		_buy_buttons[i].text = "AL"
		_price_labels[i].text = "SATILDI" if sold else "%d Altın" % _entry_cost(entry)
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
