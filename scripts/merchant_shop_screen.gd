extends CanvasLayer

## Kullanıcı isteği: "Seyyar satıcı dükkandan rasgele 6 item gösterecek.
## Ekstralar, silahlar, kalkanlar dahil. Tier sistemi olanlar rasgele
## tierlarda dükkanda çıkabilir. Oyuncular istediği eşyayı seçip alabilir.
## Bunun için dükkan arayüzüne benzer bir arayüz tasarla ve eşyaların
## altında minik satın al butonları olsun. Eşyaya tıklayınca da solda
## eşyanın özellikleri görünsün."
##
## chest_menu.gd'nin "CanvasLayer + Dim backdrop + prosedürel kart" deseniyle
## aynı teknikle (hiç .tscn yok, weapon_select_screen.gd gibi tamamen kodla
## inşa ediliyor) kuruluyor - ama chest_menu.gd'nin aksine (1 kart, seç-ve-
## kapan) burası GERÇEK bir dükkan: 6 kart AYNI ANDA gösterilir, her kartın
## KENDİ mini "AL" butonu var (kullanıcı isteği), istenildiği kadar satın
## alınabilir, "AL" tekrar tekrar kullanılabilir (chest_menu.gd'deki gibi
## bir kere seçip kapanmıyor).
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
## TEK istisna: oyuncu kendi reroll hakkını kullanırsa (bkz. _on_reroll_
## pressed) stok o anda YENİDEN çekilir - hak sayısı TravelingMerchant'ta
## (bkz. _merchant) ziyaretler arası kalıcı/kişisel olarak tutulur.

signal closed

const PAL_CONTENT_BG := Color(0.239, 0.2, 0.149, 1.0)
const PAL_CONTENT_BORDER := Color(0.168, 0.137, 0.101, 1.0)
const PAL_ACCENT := Color(0.83, 0.56, 0.30, 1.0)
const PAL_WINDOW_BG := Color(0.47, 0.39, 0.23, 1.0)
const PAL_WINDOW_BORDER := Color(0.25, 0.15, 0.08, 1.0)

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
const WEAPON_COST_BASE := {
	"dagger": 60, "fire_staff": 80, "lightning_staff": 120, "tabanca": 100, "tuftuf": 90, "tufek": 100, "arcane": 110, "yay": 100,
	"crossbow": 100, "boomerang": 110, "buz_asasi": 95, "fisek": 120, "pence": 90, "topuz": 105, "uzunkilic": 100,
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

## Kullanıcı isteği: "seyyar satıcıda çıkan itemlerin her biri sadece 1 kez
## satın alınabilir" - SADECE "item" tipi (pasif eşya) kartlar için: silah
## kopyası (birden fazla kopya = level yükseltme malzemesi) ve kalkan
## seviyesi (her AL bir seviye daha yükseltir) tekrar tekrar satın alınabilir
## OLMAK ÜZERE tasarlandı, o ikisine dokunulmadı. Stok index'ine göre tutulur
## (aynı eşya/tier iki farklı karttaysa ikisi ayrı sayılır).
## DÜZELTME (kullanıcı bildirimi: "dükkanı kapatıp tekrar açınca aynı şeyi
## tekrar alabiliyoruz") - bu dizi ARTIK burada YAŞAMIYOR, bkz. traveling_
## merchant.gd sold_item_indices (bu ekran her açılışta sıfırdan kurulup
## kapanışta queue_free() olduğu için burada tutmak ziyaret boyunca kalıcı
## olamıyordu) - _merchant üzerinden okunup yazılıyor.

var _details_name: Label
var _details_tier: Label
var _details_icon_holder: Control
var _details_icon_frame: TextureRect
var _details_icon_inset: Control
var _details_desc: Label
var _details_price: Label


func setup(player: Node, stock: Array, merchant: Node = null) -> void:
	_player = player
	_stock = stock
	## Kullanıcı isteği: "Dükkandaki eşyaların fiyatı oyunun süresine göre
	## ucuzdan pahalıya göre sıralanmalı" - bkz. _sort_stock_by_cost/
	## _entry_cost.
	_sort_stock_by_cost()
	_merchant = merchant
	_build_ui()
	## DÜZELTME (kullanıcı isteği: "gamepad desteği ekle") - bkz. shop_panel.gd
	## _ready()'deki AYNI kök neden notu: bu ekran BİLİNÇLİ OLARAK get_tree().
	## paused kullanmıyor, bu yüzden main.gd'nin genel ui_cancel/pause-toggle
	## kontrolü bu ekran açıkken de çalışıp pause menüsünü ÜSTÜNE açardı.
	GameManager.register_blocking_panel(self)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_on_close_pressed()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var window := PanelContainer.new()
	var window_style := StyleBoxFlat.new()
	window_style.bg_color = PAL_WINDOW_BG
	window_style.border_color = PAL_WINDOW_BORDER
	window_style.set_border_width_all(4)
	window_style.set_corner_radius_all(14)
	window_style.shadow_color = Color(0, 0, 0, 0.4)
	window_style.shadow_size = 6
	window.add_theme_stylebox_override("panel", window_style)
	center.add_child(window)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	window.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title_bar := HBoxContainer.new()
	var title_label := Label.new()
	title_label.text = "SEYYAR SATICI"
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.85, 1.0))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_label)
	## Kullanıcı isteği: "Seyyar satıcıdaki eşyaları rerollama butonu ekle" -
	## hak sayısı TravelingMerchant'ta tutuluyor (bkz. _merchant üstündeki
	## yorum), burada sadece gösterilip _on_reroll_pressed ile tetikleniyor.
	_reroll_btn = Button.new()
	_reroll_btn.custom_minimum_size = Vector2(200, 36)
	_reroll_btn.add_theme_font_size_override("font_size", 16)
	ShopScript._apply_wood_button_style(_reroll_btn)
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	title_bar.add_child(_reroll_btn)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(36, 36)
	ShopScript._apply_mini_wood_button_style(close_btn)
	close_btn.pressed.connect(_on_close_pressed)
	title_bar.add_child(close_btn)
	vbox.add_child(title_bar)
	vbox.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	vbox.add_child(body)

	body.add_child(_build_details_panel())
	body.add_child(VSeparator.new())
	body.add_child(_build_grid())

	## bkz. chest_menu.gd'nin AYNI notu - sadece tık sesi, görsel stil zaten
	## yukarıda ShopScript._apply_*_button_style ile elle uygulandı.
	UISound.connect_all_buttons(self)

	_refresh_all_buy_states()
	_refresh_reroll_button()
	if not _stock.is_empty():
		_select_index(0)


func _build_details_panel() -> Control:
	var panel := PanelContainer.new()
	## DÜZELTME (kullanıcı bildirimi: "seyyar satıcının paneli çok yüksek üstte
	## gereksiz boşluklar var") - kök neden: bu panel sabit 440px yükseklik
	## istiyordu ama içeriği (ikon 120 + isim/tier/fiyat etiketleri) bunun
	## çok altında bir yer kaplıyor; aradaki farkı aşağıdaki desc_scroll
	## (eskiden SIZE_EXPAND_FILL) dolduruyordu - kısa açıklama metinlerinde
	## bu, içeriğin üstte kümelenip altında büyük boş bir alan bırakması
	## demekti. Yükseklik içeriğe daha yakın bir değere düşürüldü, desc_scroll
	## da artık panel doldurmuyor (bkz. aşağısı).
	panel.custom_minimum_size = Vector2(280, 340)
	var style := StyleBoxFlat.new()
	style.bg_color = PAL_CONTENT_BG
	style.border_color = PAL_CONTENT_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_details_icon_holder = Control.new()
	_details_icon_holder.custom_minimum_size = Vector2(120, 120)
	_details_icon_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	## bkz. _build_card ile AYNI kare ikon-slotu deseni (_build_icon_slot) -
	## çerçeve tier'a göre _refresh_details()'te güncellenir (bkz. o fonksiyon),
	## bu yüzden referansı burada saklıyoruz.
	_details_icon_inset = _build_icon_slot(_details_icon_holder, 1, 18.0)
	_details_icon_frame = _details_icon_holder.get_node("SlotFrame") as TextureRect
	vbox.add_child(_details_icon_holder)

	_details_name = Label.new()
	_details_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	_details_name.add_theme_font_size_override("font_size", 26)
	_details_name.add_theme_color_override("font_color", PAL_ACCENT)
	vbox.add_child(_details_name)

	_details_tier = Label.new()
	_details_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details_tier.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_details_tier)

	var desc_scroll := ScrollContainer.new()
	## bkz. yukarıdaki panel.custom_minimum_size notu - artık paneli dolduran
	## SIZE_EXPAND_FILL DEĞİL, birkaç satır açıklamaya rahatça yetecek sabit
	## bir yükseklik (uzun açıklamalarda hâlâ kendi kaydırma çubuğuyla scroll
	## edilebilir).
	desc_scroll.custom_minimum_size = Vector2(0, 110)
	vbox.add_child(desc_scroll)
	_details_desc = Label.new()
	_details_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_details_desc.add_theme_font_size_override("font_size", 18)
	_details_desc.add_theme_color_override("font_color", Color(0.85, 0.79, 0.7, 1.0))
	_details_desc.custom_minimum_size = Vector2(250, 0)
	desc_scroll.add_child(_details_desc)

	_details_price = Label.new()
	_details_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details_price.add_theme_font_size_override("font_size", 22)
	_details_price.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	vbox.add_child(_details_price)

	return panel


func _build_grid() -> Control:
	_grid = GridContainer.new()
	_grid.columns = 3
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


## Kullanıcı isteği (SONRADAN VAZGEÇİLDİ - bkz. "uzun kartları buna
## eklemeyelim vazgeçtim kötü duruyor, sadece ikonları saran 1/1 kart kalsın"):
## level atlama kartı tarzı büyük dikey "Frame" dokusu (TierSystem.
## FRAME_TEXTURES) BURADA (seyyar satıcı mini kartlarında) KULLANILMIYOR -
## SADECE ikonun arkasındaki küçük kare slot (bkz. _build_icon_slot,
## TierSystem.MINI_FRAME_TEXTURES) tier'ı gösteriyor. level_up_screen.gd ve
## chest_menu.gd'deki büyük Frame kullanımına DOKUNULMADI, sadece burası.
func _build_card(index: int) -> PanelContainer:
	var entry: Dictionary = _stock[index]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(150, 220)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.32, 0.2, 0.11, 1.0)
	style.border_color = PAL_CONTENT_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 2
	style.shadow_offset = Vector2(2, 3)
	card.add_theme_stylebox_override("panel", style)
	card.gui_input.connect(_on_card_gui_input.bind(index))
	## DÜZELTME (kullanıcı isteği: "gamepad desteği ekle") - bu PanelContainer
	## bir Button OLMADIĞI için motor "focus" stilini kendiliğinden çizmiyor,
	## GamepadFocusHelper kendi kenarlığını ekliyor (bkz. o dosyadaki not).
	card.focus_mode = Control.FOCUS_ALL
	GamepadFocusHelper.add_focus_ring(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var tier_label := Label.new()
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.add_theme_font_size_override("font_size", 14)
	if entry.get("type") == "item":
		var tier: int = int(entry.get("tier", 1))
		tier_label.text = TierSystem.NAMES[tier - 1]
		tier_label.add_theme_color_override("font_color", TierSystem.COLORS[tier - 1])
	else:
		tier_label.text = " "
	vbox.add_child(tier_label)

	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(84, 84)
	icon_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_inset: Control = _build_icon_slot(icon_holder, _entry_slot_tier(entry), 12.0)
	_add_icon(icon_inset, entry)
	vbox.add_child(icon_holder)

	var name_label := Label.new()
	name_label.text = _entry_name(entry)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78, 1.0))
	vbox.add_child(name_label)

	var price_label := Label.new()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 15)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	price_label.text = "%d Altın" % _entry_cost(entry)
	vbox.add_child(price_label)

	## Kullanıcı isteği: "eşyaların altında minik satın al butonları olsun"
	## sonra "AL butonunu ufalt dışarı taşmışlar hep" - eskiden genişliği 0
	## (= VBoxContainer'ı yatayda TAMAMEN doldur) idi, ahşap stilin kendi
	## texture_margin'leriyle (bkz. shop_panel.gd BUTTON_WOOD_MARGIN_H) kart
	## kenarına çok yakın/taşmış görünüyordu. Artık sabit, kartın içine rahat
	## sığan küçük bir genişlikte ve ortalanmış.
	var buy_btn := Button.new()
	buy_btn.text = "AL"
	buy_btn.custom_minimum_size = Vector2(76, 26)
	buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy_btn.add_theme_font_size_override("font_size", 14)
	ShopScript._apply_wood_button_style(buy_btn)
	buy_btn.pressed.connect(_on_buy_pressed.bind(index))
	vbox.add_child(buy_btn)

	_card_panels.append(card)
	_buy_buttons.append(buy_btn)
	_price_labels.append(price_label)
	return card


## Kullanıcı isteği: "seyyar satıcı arayüzündeki kare kare gibi olan
## slotlar yerine bunları kullanacaksın, tier'ı olmayan şeyler tier 1 mini
## kartını kullansın" - TierSystem.MINI_FRAME_TEXTURES ikonun ARKASINA kare
## bir çerçeve olarak eklenir; asıl ikon bu çerçevenin kalın kenarlığıyla
## ÇAKIŞMASIN diye INSET (her kenardan `inset` px içeri) bir alt Control'e
## çizilir - o Control _add_icon()'a verilir, döner (çağıran taraf ikonu
## oraya ekler). Çerçeve her zaman holder'ın İLK çocuğu (index 0) olur.
func _build_icon_slot(holder: Control, tier: int, inset: float) -> Control:
	var frame := TextureRect.new()
	frame.name = "SlotFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## KRİTİK: bkz. _build_card'daki AYNI notun (dosya bu tekrarlanan hatayı
	## yaşadı) - expand_mode olmadan minimum boyut dokunun gerçek piksel
	## boyutu (583x583) olur ve kart alanını devasa bir kareyle kaplar.
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


## bkz. chest_menu.gd _build_card / shop_panel.gd shop_item_icon.gd üstündeki
## AYNI 3 yollu ikon deseni (eşya: PNG dosya yolu, silah: WEAPON_ICON_
## TEXTURES, kalkan: shop_item_icon.gd'nin prosedürel "shield" çizimi -
## kalkanların ayrı bir PNG ikon tablosu yok).
func _add_icon(holder: Control, entry: Dictionary) -> void:
	var key: String = entry.get("key", "")
	match entry.get("type"):
		"item":
			var icon_path: String = "res://assets/generated/item_" + key + "_frame_0.png"
			var tex_rect := TextureRect.new()
			tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			if ResourceLoader.exists(icon_path):
				tex_rect.texture = load(icon_path) as Texture2D
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			holder.add_child(tex_rect)
		"weapon":
			var wpath: String = WEAPON_ICON_TEXTURES.get(key, "")
			var wtex_rect := TextureRect.new()
			wtex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			if not wpath.is_empty() and ResourceLoader.exists(wpath):
				wtex_rect.texture = load(wpath) as Texture2D
			wtex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			wtex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			holder.add_child(wtex_rect)
		"shield":
			var shield_icon := Control.new()
			shield_icon.set_script(load("res://scripts/shop_item_icon.gd"))
			shield_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			shield_icon.set("item_type", "shield")
			holder.add_child(shield_icon)


func _on_card_gui_input(event: InputEvent, index: int) -> void:
	## DÜZELTME (kullanıcı isteği: "gamepad desteği ekle") - ui_accept (A/
	## Enter/Boşluk) artık kart odaktayken sol tık ile AYNI seçim eylemini
	## tetikliyor.
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or event.is_action_pressed("ui_accept"):
		_select_index(index)


func _select_index(index: int) -> void:
	_selected_index = index
	for i in range(_card_panels.size()):
		var panel: PanelContainer = _card_panels[i]
		var is_selected: bool = i == index
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			var w: int = 6 if is_selected else 3
			style.border_width_left = w
			style.border_width_top = w
			style.border_width_right = w
			style.border_width_bottom = w
	_refresh_details()


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
		_details_tier.text = ""
		_details_desc.text = "Yeni bir silah - kalıcı olarak edinilir."
	else:
		var key: String = entry.get("key", "")
		_details_tier.text = ""
		var lvl: int = int(GameManager.get(key + "_level"))
		var max_lvl: int = int(ShopScript.MAX_LEVELS.get(key, 20))
		_details_desc.text = "Kalkan seviyesi: %d/%d\nSatın alınca bir seviye yükselir." % [lvl, max_lvl]
	_details_icon_frame.texture = TierSystem.MINI_FRAME_TEXTURES[_entry_slot_tier(entry) - 1]
	for c in _details_icon_inset.get_children():
		c.queue_free()
	_add_icon(_details_icon_inset, entry)
	_details_price.text = "%d Altın" % _entry_cost(entry)


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

func _scale_merchant_price(base_shape: float) -> int:
	var scale: float = MERCHANT_PRICE_EARLY_SCALE + float(_merchant_price_tier() - 1) * MERCHANT_PRICE_PER_TIER_GROWTH
	return max(MERCHANT_PRICE_MIN, int(round(base_shape * scale)))

func _entry_cost(entry: Dictionary) -> int:
	var key: String = entry.get("key", "")
	match entry.get("type"):
		"item":
			var base_cost: int = int(Items.get_def(key).get("cost_base", 50))
			var power_mult: float = Items.ITEM_TIER_POWER[int(entry.get("tier", 1)) - 1]
			return _scale_merchant_price(base_cost * power_mult)
		"weapon":
			return _scale_merchant_price(float(WEAPON_COST_BASE.get(key, 100)))
		"shield":
			var next_level: int = int(GameManager.get(key + "_level")) + 1
			return _scale_merchant_price(float(ShopScript._upgrade_cost(key, next_level)))
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


## bkz. _sold_item_indices üstündeki DÜZELTME notu - kalıcı depo artık
## _merchant (TravelingMerchant) üzerinde, _merchant geçersizse (olağanüstü
## bir durum, normalde setup() ile hep geçerli bir referans gelir) hiçbir
## şey satılmamış gibi güvenli bir varsayılana düşer.
func _sold_indices() -> Array:
	return _merchant.sold_item_indices if _merchant and is_instance_valid(_merchant) else []


func _entry_can_buy(entry: Dictionary, index: int) -> bool:
	if entry.get("type") == "item" and _sold_indices().has(index):
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
				_sold_indices().append(index)
		"weapon":
			## bkz. shop_panel.gd _on_buy_copy / chest_menu.gd _on_al_pressed
			## AYNI sıra: önce deftere ekle, sonra gerçek silah node'unu spawn et.
			GameManager.gold -= cost
			GameManager.owned_weapons.append({"key": key, "level": 1, "spent": cost})
			if _player and _player.has_method("buy_weapon_copy"):
				_player.buy_weapon_copy(key, 1)
		"shield":
			var next_level: int = int(GameManager.get(key + "_level")) + 1
			GameManager.gold -= cost
			GameManager.set(key + "_level", next_level)
			if _player and _player.has_method("refresh_shield_stats"):
				_player.refresh_shield_stats()
	_refresh_all_buy_states()
	if _selected_index == index:
		_refresh_details()


func _refresh_all_buy_states() -> void:
	for i in range(_stock.size()):
		var entry: Dictionary = _stock[i]
		var sold: bool = entry.get("type") == "item" and _sold_indices().has(i)
		_buy_buttons[i].disabled = not _entry_can_buy(entry, i)
		_buy_buttons[i].text = "SATILDI" if sold else "AL"
		_price_labels[i].text = "%d Altın" % _entry_cost(entry)


func _refresh_reroll_button() -> void:
	if not _reroll_btn:
		return
	if not _merchant or not is_instance_valid(_merchant):
		_reroll_btn.visible = false
		return
	var charges: int = int(_merchant.get_reroll_charges())
	_reroll_btn.text = "YENİDEN ÇEVİR (%d)" % charges
	_reroll_btn.disabled = charges <= 0


## Kullanıcı isteği: "Seyyar satıcıdaki eşyaları rerollama butonu ekle" - 1
## hak harcayıp TravelingMerchant'tan tamamen taze bir stok ister, tüm
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
	if not _stock.is_empty():
		_select_index(0)


func _on_close_pressed() -> void:
	GameManager.unregister_blocking_panel(self)
	closed.emit()
	queue_free()
