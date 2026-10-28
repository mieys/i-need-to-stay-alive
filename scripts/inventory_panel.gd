extends Control

## ENVANTER. İki ayrı görünüş, satış kuralları ortak (_do_sell_item / _do_sell_weapon_equip):
##  - MASAÜSTÜ "KAHRAMAN ÇANTASI" (madde 341, 2026-10-20; kullanıcı madde 336 prototiplerinden B'yi seçti): tek ekran - solda gruplu
##    özellikler, ortada ışık havuzunda karakter + çevresinde 3 silah yuvası (Zanaatkâr sanatı + efsun kontürü) + Mana Kalkanı / evcil,
##    sağda HEYBE (kademe satırları) + seçili şeyin kartı (statlar, pasif, tarif, SATARSAN, SAT). Satış = seç -> SAT (onay penceresi yok).
##    Özellikler paneli (stats_panel) masaüstünde artık ayrıca açılmaz (hud.gd _on_envanter_toggle). Kod: dosyanın sonundaki "_ch_" bölümü.
##  - TELEFON (MobileUI.enabled): eski yuva düzeni + Gece Sıvası (madde 276), hud.gd apply_mobile_layout'u çağırır; özellikler paneli
##    rayın ÖZELLİK sekmesinde. Bu yol eski kurulumu (_build_legacy) kullanır.

const WEAPON_ICON_TEXTURES := {
	"dagger": preload("res://assets/weapons/base_knife/icon_v2.png"),
	"fire_staff": preload("res://assets/weapons/fire/firestaff_icon_v2.png"),
	"lightning_staff": preload("res://assets/weapons/lightning/icon_v2.png"),
	"tabanca": preload("res://assets/weapons/tabanca/icon_v2.png"),
	"tuftuf": preload("res://assets/weapons/tuftuf/icon_v2.png"),
	"tufek": preload("res://assets/weapons/tufek/icon.png"),
	"arcane": preload("res://assets/weapons/arcane/icon_v2.png"),
	"yay": preload("res://assets/weapons/yay/draw1.png"),
	"crossbow": preload("res://assets/weapons/crossbow/icon.png"),
	"boomerang": preload("res://assets/weapons/boomerang/icon.png"),
	"buz_asasi": preload("res://assets/weapons/buz_asasi/icon.png"),
	"fisek": preload("res://assets/weapons/fisek/icon.png"),
	"pence": preload("res://assets/weapons/pence/icon.png"),
	"topuz": preload("res://assets/weapons/topuz/icon.png"),
	"uzunkilic": preload("res://assets/weapons/uzunkilic/icon.png"),
	"gokkusagi": preload("res://assets/weapons/zanaat/gokkusagi_L1.png"),
	"mizrak": preload("res://assets/weapons/zanaat/mizrak_L1.png"),
	"kalkan": preload("res://assets/weapons/zanaat/kalkan_L1.png"),
	"yinyang": preload("res://assets/weapons/zanaat/yinyang_L1.png"),
}
const WEAPON_NAMES := {
	"dagger": "Bıçak", "fire_staff": "Ateş Asası", "lightning_staff": "Yıldırım Asası", "tabanca": "Tabanca",
	"tuftuf": "Tüftüf", "tufek": "Tüfek", "arcane": "Arcane Asası", "yay": "Yay",
	"crossbow": "Arbalet", "boomerang": "Bumerang", "buz_asasi": "Buz Asası", "fisek": "Fişek",
	"pence": "Pençe", "topuz": "Topuz", "uzunkilic": "Uzunkılıç", "gokkusagi": "Gökkuşağı Asası", "mizrak": "Mızrak", "kalkan": "Kalkan", "yinyang": "Yin Yang Kitabı",
}

## Eşyalar (bkz. scripts/items.gd) - dükkandaki ItemsPage satırlarıyla BİREBİR
## AYNI tonlar (bkz. shop_panel.tscn) kullanıcı iki yerde de aynı eşyayı hemen
## tanısın diye.
## 2026-10-02: eski ekstralar silindi (bkz. items.gd) - yeni ekstraların tonları buraya (anahtar -> Color).
const ITEM_TINTS := {
}

## HUD, bu paneli istatistik paneliyle EŞLEŞTİRİP birlikte açıp kapatıyor
## (bkz. hud.gd _on_envanter_toggle/_on_envanter_closed) - paneldeki X'e
## basınca sadece kendini değil, eşleştiği istatistik panelini de kapatması
## gerektiği için bu sinyali yayınlıyoruz.
signal closed

@onready var close_button: Button = $Frame/CloseButton
@onready var gold_label: Label = $Frame/GoldLabel
@onready var xp_label: Label = $Frame/XPLabel
@onready var weapon_slots: Array = [
	$Frame/WeaponSlot1,
	$Frame/WeaponSlot2,
	$Frame/WeaponSlot3,
	$Frame/WeaponSlot4,
	$Frame/WeaponSlot5,
]
@onready var items_grid: GridContainer = $Frame/ItemsScroll/ItemsGrid

## Kullanıcı isteği (2026-09-22): "Envanter arayüzünü seyyar satıcı gibi pixel tarzda, diğer arayüzlerle uyumlu yap" - yuvalar artık
## seyyar satıcıdaki gibi TierSystem.MINI_FRAME_TEXTURES çerçeveli 96 px kareler (ikon alanı 64 px = eşya ikonları 2x), pencere/başlık/altın
## alanı UIKit (assets/ui/kit) ile. Satış/sürükleme mantığı DEĞİŞMEDİ.
const GoldRewardFx := preload("res://scripts/gold_reward_fx.gd")
const SLOT_SIZE := 80.0
const SLOT_INSET := 8.0
## Telefon (kullanıcı bildirimi 2026-10-03: "envanter paneli çok kötü mobile uyumlu değil"): hud.gd paneli küçültüp
## sığdırmak yerine apply_mobile_layout'u çağırır - pencere ekranın yarısından büyük, yuvalar 136 px (eşya ikonu 32 px'in
## 3 katı), yazılar 40/48. Telefonda ipucu (tooltip) görünmediği için yuvaya dokunmak satış onayı açmaz: alttaki bilgi
## şeridinde ad + açıklama + büyük SAT düğmesi belirir (iki adım = yanlışlıkla satış yok). Masaüstünde hiçbir şey değişmez.
var _mobile: bool = false
var _slot: float = SLOT_SIZE
var _icon_px: float = 64.0
var _inset_px: float = SLOT_INSET
var _detail_name: Label = null
var _detail_desc: Label = null
var _detail_sell: Button = null
var _detail_action: Callable = Callable()


## Yuva düğmesi: kendi stili boş (çerçeveyi biz çiziyoruz), çerçeve dokusu çocuk TextureRect; fare üstüne gelince çerçeve parlar.
func _decorate_slot(btn: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, empty)
	var frame := TextureRect.new()
	frame.name = "SlotFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	## 2026-09-25: tier mini kartları tamamen tier rengine geçti; envanter yuvası kademesiz olduğu için eski sade hücreyi kullanır.
	frame.texture = UIKit.game_tex("slot_cell.png")
	if _mobile: ## telefon (madde 276): bej hücre yerine Gece Sıvası kuyusu (dolu eşyada kademe çerçevesi yine üstte)
		frame.texture = null
		for st2 in ["normal", "hover", "pressed", "disabled"]:
			btn.add_theme_stylebox_override(st2, _ph_sb(Color(PH_INSET, 0.92), PH_LINE, 2, 10))
	btn.add_child(frame)
	btn.mouse_entered.connect(func() -> void:
		if is_instance_valid(frame):
			frame.self_modulate = Color(1.25, 1.18, 1.05, frame.self_modulate.a))
	btn.mouse_exited.connect(func() -> void:
		if is_instance_valid(frame):
			frame.self_modulate = Color(1, 1, 1, frame.self_modulate.a))
	UISound.connect_all_buttons(btn)


func _dim_slot(btn: Button) -> void:
	var frame: Node = btn.get_node_or_null("SlotFrame")
	if frame:
		(frame as TextureRect).self_modulate = Color(1, 1, 1, 0.55)


var player: Node = null

## GameManager.owned_items'ın son bilinen "imzası" (anahtarların sıralı
## listesi) - ItemsGrid her _process() karesinde DEĞİL, SADECE bu değiştiğinde
## (satın alma/satış) yeniden kuruluyor (bkz. _refresh_items_grid) - her
## karede N tane Button/Icon node'unu baştan yaratmak gereksiz maliyet olurdu.
var _last_items_signature: String = ""
## Eşya yuvalarının ikonları (eşya dizini -> TextureRect): satışta ikon parçalanıp altına döner (bkz. _do_sell_item).
var _item_slot_icons: Dictionary = {}

## Açılış animasyonu (bkz. _play_open_animation) - kullanıcı isteği:
## "envanter penceresi de animasyonla açılsın, ease ease olmalı ve yorucu
## olmamalı." hud.gd bu paneli sadece "visible = true" yaparak açıyor,
## davranışı değiştirmeden animasyonu eklemek için NOTIFICATION_VISIBILITY_
## CHANGED dinleniyor - hud.gd'ye hiç dokunmaya gerek kalmıyor.
const OPEN_ANIM_DURATION := 0.2
const OPEN_ANIM_START_SCALE := 0.9
var _open_tween: Tween = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_play_open_animation()
		_clear_detail()
		if _chest != null:
			_ch_on_open()


## Kısa, tek seferlik bir ease-out büyüme+belirme - zıplama/elastik yok,
## göz yormasın diye hızlı (bkz. OPEN_ANIM_DURATION).
func _play_open_animation() -> void:
	if _open_tween and _open_tween.is_valid():
		_open_tween.kill()
	modulate.a = 0.0
	pivot_offset = size * 0.5
	scale = Vector2(OPEN_ANIM_START_SCALE, OPEN_ANIM_START_SCALE)
	_open_tween = create_tween()
	_open_tween.set_parallel(true)
	_open_tween.set_ease(Tween.EASE_OUT)
	_open_tween.set_trans(Tween.TRANS_CUBIC)
	_open_tween.tween_property(self, "modulate:a", 1.0, OPEN_ANIM_DURATION)
	_open_tween.tween_property(self, "scale", Vector2.ONE, OPEN_ANIM_DURATION)


var main_layout: VBoxContainer = null
## Masaüstünde (Kahraman Çantası): weapons_grid = sahnedeki silah yuvaları, equip_grid = kalkan + evcil yuvaları, items_grid_box = HEYBE.
var weapons_grid: Control = null
var equip_grid: Control = null
var items_grid_box: VBoxContainer = null ## 2026-10-02: kademe bölümleri (bkz. _refresh_items_grid)

var _last_weapons_signature: String = ""
var _last_equip_signature: String = ""

## #37 DÜZELTME (kullanıcı bildirimi: "Envanterden bir şey satınca parasını
## vermiyor, ayrıca tıklayınca direkt satılmamalı - dükkandan zaten
## satılabiliyor"): silah/kalkan/işlevsellik/eşya yuvalarına tıklamak eskiden
## HİÇBİR onay istemeden AN'INDA satıyordu - kazayla tıklanan (özellikle
## "spent": 0 olan BAŞLANGIÇ silahı gibi) bir eşya sessizce kayboluyor, kullanıcı
## bunu "para vermiyor" (0 altın iade - aslında doğru davranış, çünkü bedava
## verilmişti) sanıp karıştırıyordu. Artık HER satış tek bir paylaşılan
## ConfirmationDialog üzerinden onay istiyor, gerçek satış mantığı SADECE
## kullanıcı "Evet" dediğinde çalışıyor. 2026-10-20 (madde 341): onay penceresi kalktı - masaüstünde tıklamak SEÇER, satış kartın SAT
## düğmesiyle (iki adım); telefonda alttaki bilgi şeridi + SAT (madde 276).
func _request_sell_confirmation(item_label: String, refund: int, action: Callable, desc: String = "", shard_refund: int = 0) -> void:
	## Telefon: alttaki bilgi şeridi (ad + açıklama + büyük SAT) - dokunmak önce bilgiyi gösterir.
	if shard_refund > 0:
		desc += "\n+%d Silah Parçacığı geri alırsın." % shard_refund
	_show_detail(item_label, desc, refund, action)

## Kalkan adları shield_enchant_defs.gd'den (ShieldEnchantDefs.type_name) gelir.
const EQUIP_NAMES: Dictionary = {
	"spray": "İtici Sprey"
}

## Kullanıcı isteği: "karakterin sadece 1 kalkan yuvası + 2 işlevsellik
## yuvası olmalı" - kalkan tek yuva (herkesin Standart Kalkanı, bkz.
## _owned_shield_type()). İşlevsellik (dükkandaki eski
## "Diğer", artık "İşlevsellik" sekmesi - bkz. shop_panel.gd) tarafında şu an
## SADECE "İtici Sprey" var ama yuva sayısı ileride eklenecek başka
## işlevsellik eşyalarına yer açacak şekilde 2'ye çıkarıldı (bkz.
## MAX_UTILITY_SLOTS/_refresh_equipments).
const UTILITY_KEYS: Array = ["spray"]
const MAX_UTILITY_SLOTS: int = 2

var _ready_done := false

func _ready() -> void:
	add_to_group(&"gamepad_modal") ## kumandayla menü gezinmesi: açılınca ilk düğmeye odak (bkz. gamepad_ui.gd)
	if _ready_done:
		return
	_ready_done = true
	if not MobileUIScript.enabled:
		if is_inside_tree() and get_tree() != null:
			player = get_tree().get_first_node_in_group("player")
		_build_chest()
		_refresh()
		return
	_build_legacy()


## Eski (telefon) kurulumu: bej sahne düğümleri + kaydırmalı yuva düzeni; apply_mobile_layout bunu Gece Sıvası'na çevirir.
func _build_legacy() -> void:
	if main_layout != null:
		return
	UISound.connect_all_buttons(self)
	UISound.apply_wood_buttons(self) ## bkz. ui_sound.gd - tüm butonları ahşap stile çevirir
	## DÜZELTME (bkz. hud.gd ShieldModeSlot ile AYNI kök neden) - CloseButton
	## (40x40, kare) custom_minimum_size yerine offset ile boyutlandırıldığı
	## için ui_sound.gd'nin _looks_like_icon_slot kontrolünü atlayıp yukarıdaki
	## taramadan GENİŞ Button.png stiliyle çıkıyordu - kare olduğu için KARE
	## mini button.png stiliyle EZİLİYOR.
	_apply_kit_layout()
	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if is_inside_tree() and get_tree() != null:
		player = get_tree().get_first_node_in_group("player")
	pivot_offset = size * 0.5
	
	# Hide old static nodes
	var old_weapons_title: Label = $Frame.get_node_or_null("WeaponsTitle") as Label
	if old_weapons_title: old_weapons_title.visible = false
	var old_items_title: Label = $Frame.get_node_or_null("ItemsTitle") as Label
	if old_items_title: old_items_title.visible = false
	var old_items_scroll: ScrollContainer = $Frame.get_node_or_null("ItemsScroll") as ScrollContainer
	if old_items_scroll: old_items_scroll.visible = false
	
	for i in range(1, 6):
		var bg_node: NinePatchRect = $Frame.get_node_or_null("WeaponSlot" + str(i) + "BG") as NinePatchRect
		if bg_node: bg_node.visible = false
		var slot_node: TextureRect = $Frame.get_node_or_null("WeaponSlot" + str(i)) as TextureRect
		if slot_node: slot_node.visible = false

	# Build MMORPG layout
	var main_scroll: ScrollContainer = ScrollContainer.new()
	main_scroll.custom_minimum_size = Vector2(640, 420)
	main_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_scroll.offset_left = 30
	main_scroll.offset_top = 96
	main_scroll.offset_right = -30
	main_scroll.offset_bottom = -104
	$Frame.add_child(main_scroll)
	
	main_layout = VBoxContainer.new()
	main_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_layout.add_theme_constant_override("separation", 14)
	main_scroll.add_child(main_layout)

	# 1. Silahlar
	var title_weapons: Label = Label.new()
	title_weapons.text = "SİLAHLAR (Satmak için tıklayın)"
	UIKit.style_label(title_weapons, UIKit.FS_BODY, UIKit.C_ACCENT, 3)
	main_layout.add_child(title_weapons)
	
	weapons_grid = HBoxContainer.new()
	weapons_grid.add_theme_constant_override("separation", 10)
	main_layout.add_child(weapons_grid)

	# 2. Ekipmanlar (Shield & Utility/İşlevsellik)
	var title_equip: Label = Label.new()
	title_equip.text = "EKİPMANLAR (Satmak için tıklayın)"
	UIKit.style_label(title_equip, UIKit.FS_BODY, UIKit.C_ACCENT, 3)
	main_layout.add_child(title_equip)
	
	equip_grid = HBoxContainer.new()
	equip_grid.add_theme_constant_override("separation", 10)
	main_layout.add_child(equip_grid)

	# 4. Eşyalar (2026-10-02 yeni eşya sistemi): Efsanevi / Epik / Parça bölümleri, kendi slot sınırlarıyla.
	var title_items: Label = Label.new()
	title_items.text = "EŞYALAR (Satmak için tıklayın)"
	UIKit.style_label(title_items, UIKit.FS_BODY, UIKit.C_ACCENT, 3)
	main_layout.add_child(title_items)

	items_grid_box = VBoxContainer.new()
	items_grid_box.add_theme_constant_override("separation", 6)
	main_layout.add_child(items_grid_box)

	_refresh()


## Kullanıcı isteği (2026-09-22): pencere çerçevesi/başlık tahtası/kapat/alt bilgi UIKit ile (bkz. seyyar satıcı ekranı, merchant_shop_screen.gd).
func _apply_kit_layout() -> void:
	## 2026-09-24: oyun içi bej kit teması (menülerle aynı dil, bir ton koyu) - etiketler varsayılan olarak koyu kahve.
	theme = UIKit.theme()
	$Frame.add_theme_stylebox_override("panel", UIKit.panel_style("window_tight"))
	## Sahnede krem verilmiş bölüm başlıkları (SİLAHLAR / EŞYALAR) bej zeminde okunmuyordu -> kiremit başlık rengi.
	for sec_name in ["WeaponsTitle", "ItemsTitle"]:
		var sec: Label = $Frame.get_node_or_null(sec_name) as Label
		if sec:
			sec.add_theme_color_override("font_color", UIKit.C_ACCENT)
			sec.add_theme_constant_override("outline_size", 0)
	var header: Panel = $Frame.get_node_or_null("HeaderBar") as Panel
	if header:
		header.add_theme_stylebox_override("panel", UIKit.panel_style("plaque"))
		header.offset_left = 26.0
		header.offset_right = -26.0
		header.offset_top = 22.0
		header.offset_bottom = 78.0
		var title: Label = header.get_node_or_null("Title") as Label
		if title:
			UIKit.style_label(title, UIKit.FS_TITLE, UIKit.C_TEXT, 4)
			title.offset_left = 24.0
	close_button.icon = null
	close_button.text = "X"
	close_button.offset_left = -86.0
	close_button.offset_top = 26.0
	close_button.offset_right = -32.0
	close_button.offset_bottom = 74.0
	UIKit.style_button(close_button, "red", true, UIKit.FS_BODY)
	## Altın / tecrübe alt bilgisi: koyu çukur zemin + büyük pixel yazı
	var footer_bg := Panel.new()
	footer_bg.name = "FooterBG"
	footer_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer_bg.offset_left = 28.0
	footer_bg.offset_right = -28.0
	footer_bg.offset_top = -92.0
	footer_bg.offset_bottom = -28.0
	footer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_bg.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))
	$Frame.add_child(footer_bg)
	$Frame.move_child(footer_bg, gold_label.get_parent().get_children().find($Frame.get_node("GoldIcon")))
	var gi: Control = $Frame.get_node("GoldIcon") as Control
	var xi: Control = $Frame.get_node("XPIcon") as Control
	for c: Control in [gi, xi]:
		c.offset_top = -80.0
		c.offset_bottom = -40.0
	gi.offset_left = 48.0
	gi.offset_right = 88.0
	gold_label.offset_left = 98.0
	gold_label.offset_right = 300.0
	xi.offset_left = 340.0
	xi.offset_right = 380.0
	xp_label.offset_left = 390.0
	xp_label.offset_right = 600.0
	for l: Label in [gold_label, xp_label]:
		l.offset_top = -86.0
		l.offset_bottom = -34.0
		l.add_theme_font_size_override("font_size", UIKit.FS_TITLE)
		l.add_theme_constant_override("outline_size", 0)
	gold_label.add_theme_color_override("font_color", UIKit.C_GOLD)
	xp_label.add_theme_color_override("font_color", Color(UIKit.INK["shield"]))

func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _process(_delta: float) -> void:
	if not visible:
		return
	_refresh()


func _refresh() -> void:
	if _chest != null:
		_ch_refresh()
		return
	gold_label.text = str(GameManager.gold)
	if player and is_instance_valid(player):
		xp_label.text = str(int(player.xp))
	else:
		xp_label.text = "0"
	_refresh_weapons()
	_refresh_equipments()
	_refresh_items_grid()


func _refresh_weapons() -> void:
	if _chest != null:
		_ch_build_weapons()
		return
	if not main_layout or not is_instance_valid(main_layout):
		return
		
	var sig: String = ""
	for entry: Dictionary in GameManager.owned_weapons:
		sig += entry.get("key", "") + ":" + str(entry.get("level", 1)) + ":" + str(entry.get("shards_spent", 0)) + "," ## parçacık defteri: ipucundaki iade/efsun sayısı güncel kalsın
	if sig == _last_weapons_signature:
		return
	_last_weapons_signature = sig
		
	for child: Node in weapons_grid.get_children():
		child.queue_free()
		
	var slot_tex: Texture2D = load("res://assets/ui/shop_redesign/item_slot.png") as Texture2D
	var style_box: StyleBoxTexture = StyleBoxTexture.new()
	style_box.texture = slot_tex
	style_box.texture_margin_left = 5.0
	style_box.texture_margin_top = 5.0
	style_box.texture_margin_right = 5.0
	style_box.texture_margin_bottom = 5.0
	
	var weapon_slot_count: int = int(player.get_max_owned_weapons()) if is_instance_valid(player) and player.has_method("get_max_owned_weapons") else 3
	for i: int in range(weapon_slot_count):
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(_slot, _slot)
		_decorate_slot(btn)
		
		if i < GameManager.owned_weapons.size():
			var entry: Dictionary = GameManager.owned_weapons[i]
			var key: String = entry.get("key", "")
			var level: int = entry.get("level", 1)
			var refund: int = EnchantDefs.sell_refund_gold(entry)
			var shard_refund: int = EnchantDefs.sell_refund_shards(entry)

			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			## Kalıcı silah özelliği (EnchantDefs.TRAITS): adı + alınan geliştirme sayısı (geliştirmeler demirci dükkanında).
			var trait_line: String = ""
			var trait_rec: Dictionary = entry.get("enchant", {})
			var trait_def: Dictionary = EnchantDefs.get_def(str(trait_rec.get("id", "")))
			if not trait_def.is_empty():
				var done: int = (EnchantDefs.upgrades_taken(trait_rec) as Array).size() + (1 if EnchantDefs.is_complete(trait_rec) else 0)
				trait_line = "\nEfsun: %s (%d/%d)" % [str(trait_def["name"]), done, (trait_def["upgrades"] as Array).size() + 1]
			btn.tooltip_text = "%s Lv%d%s\n\nSatmak için tıklayın (+%d Altın%s)" % [WEAPON_NAMES.get(key, key), level, trait_line, refund,
					(", +%d Silah Parçacığı" % shard_refund) if shard_refund > 0 else ""]
			btn.pressed.connect(_on_sell_weapon_equip.bind(i))
			
			var icon_tex: Texture2D = WEAPON_ICON_TEXTURES.get(key)
			if icon_tex:
				var icon_tr: TextureRect = TextureRect.new()
				icon_tr.texture = icon_tex
				icon_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_tr.custom_minimum_size = Vector2(_icon_px, _icon_px)
				icon_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon_tr.anchor_left = 0.5
				icon_tr.anchor_right = 0.5
				icon_tr.anchor_top = 0.5
				icon_tr.anchor_bottom = 0.5
				icon_tr.offset_left = -_icon_px * 0.5
				icon_tr.offset_right = _icon_px * 0.5
				icon_tr.offset_top = -_icon_px * 0.5
				icon_tr.offset_bottom = _icon_px * 0.5
				btn.add_child(icon_tr)
				
				var lvl_lbl: Label = Label.new()
				lvl_lbl.text = "Sv%d" % level
				lvl_lbl.add_theme_font_size_override("font_size", UIKit.FS_BODY)
				lvl_lbl.add_theme_color_override("font_color", UIKit.C_CREAM)
				lvl_lbl.add_theme_color_override("font_outline_color", UIKit.C_OUTLINE)
				lvl_lbl.add_theme_constant_override("outline_size", 4)
				lvl_lbl.anchor_left = 1.0
				lvl_lbl.anchor_top = 1.0
				lvl_lbl.anchor_right = 1.0
				lvl_lbl.anchor_bottom = 1.0
				lvl_lbl.offset_left = -70
				lvl_lbl.offset_top = -38
				lvl_lbl.offset_right = -10
				lvl_lbl.offset_bottom = -8
				lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				btn.add_child(lvl_lbl)
		else:
			btn.tooltip_text = "Silah Yuvası (Boş)"
			_dim_slot(btn)
			
		weapons_grid.add_child(btn)


func _on_sell_weapon_equip(index: int) -> void:
	if index < 0 or index >= GameManager.owned_weapons.size():
		return
	if _chest != null: ## masaüstü: tıklama seçer, satış kartın SAT düğmesiyle
		_ch_select("weapon", index)
		return
	if GameManager.owned_weapons.size() <= 1:
		if _mobile: ## telefonda bilgi yine görünür, son silah satılamaz (SAT yok)
			var only: Dictionary = GameManager.owned_weapons[index]
			_show_detail(WEAPON_NAMES.get(str(only.get("key", "")), "Silah"), "Silah  ·  Seviye %d\nSon silah satılamaz." % int(only.get("level", 1)), 0, Callable())
		return
	var entry: Dictionary = GameManager.owned_weapons[index]
	var key: String = entry.get("key", "")
	var refund: int = EnchantDefs.sell_refund_gold(entry)
	_request_sell_confirmation(WEAPON_NAMES.get(key, key), refund, _do_sell_weapon_equip.bind(index),
			"Silah  ·  Seviye %d" % int(entry.get("level", 1)) + ("\nSon silah satılamaz." if GameManager.owned_weapons.size() <= 1 else ""),
			EnchantDefs.sell_refund_shards(entry))


func _do_sell_weapon_equip(index: int) -> void:
	if index < 0 or index >= GameManager.owned_weapons.size():
		return
	if GameManager.owned_weapons.size() <= 1:
		return

	var entry: Dictionary = GameManager.owned_weapons[index]
	var refund: int = EnchantDefs.sell_refund_gold(entry)
	var shard_refund: int = EnchantDefs.sell_refund_shards(entry)
	## Masaüstü: eşya satışı gibi silah ikonu da parçalanıp altına döner (yuva ikonu = kaynak).
	var shatter: Array = _ch_icon_rect(_ch_weapon_icons.get(index) as TextureRect)

	if player and is_instance_valid(player) and player.has_method("remove_owned_weapon"):
		player.remove_owned_weapon(index)

	GameManager.owned_weapons.remove_at(index)
	GameManager.gold += refund
	GameManager.add_weapon_shards(shard_refund)
	if not shatter.is_empty() and refund > 0:
		GoldRewardFx.show_shatter(get_tree(), refund, shatter[0], shatter[1], shatter[2])
	_last_weapons_signature = ""
	_refresh()


func _owned_shield_type() -> String:
	return ShieldEnchantDefs.owned_type()


func _get_upgrade_cost(item: String, next_level: int) -> int:
	match item:
		"spray":
			return 15 * next_level * next_level
	return next_level


func _refresh_equipments() -> void:
	if _chest != null:
		_ch_build_equip()
		return
	if not main_layout or not is_instance_valid(main_layout):
		return
		
	var shield_key: String = _owned_shield_type()
	var sig: String = shield_key + ":" + str(GameManager.shield_enchant_ups)
	for utility_key: String in UTILITY_KEYS:
		sig += "," + utility_key + ":" + str(int(GameManager.get(utility_key + "_level")))
	if sig == _last_equip_signature:
		return
	_last_equip_signature = sig
		
	for child: Node in equip_grid.get_children():
		child.queue_free()
		
	var slot_tex: Texture2D = load("res://assets/ui/shop_redesign/item_slot.png") as Texture2D
	var style_box: StyleBoxTexture = StyleBoxTexture.new()
	style_box.texture = slot_tex
	style_box.texture_margin_left = 5.0
	style_box.texture_margin_top = 5.0
	style_box.texture_margin_right = 5.0
	style_box.texture_margin_bottom = 5.0
	
	# 1. Shield slot
	var shield_btn: Button = Button.new()
	shield_btn.custom_minimum_size = Vector2(_slot, _slot)
	_decorate_slot(shield_btn)
	
	## 2026-09-29: kalkan satılamaz (herkes Standart Kalkanla başlıyor, dükkanda kalkan yok; tür/geliştirme sadece kalkan
	## efsunlarıyla - bkz. shield_enchant_defs.gd) - yuva sadece
	## sahip olunan kalkanı gösterir, tıklanınca satış YOK (yoksa oyuncu o oyun boyunca kalkansız kalırdı).
	if shield_key != "":
		var shield_sum: String = ShieldEnchantDefs.summary()
		shield_btn.tooltip_text = shield_sum if shield_sum != "" else ShieldEnchantDefs.type_name(shield_key)
		if _mobile: ## telefonda ipucu yok - dokununca bilgi şeridinde (satılamaz, SAT yok)
			shield_btn.pressed.connect(_show_detail.bind(ShieldEnchantDefs.type_name(shield_key), shield_sum, 0, Callable()))
		var icon: Control = Control.new()
		icon.set_script(load("res://scripts/shop_item_icon.gd"))
		icon.item_type = "shield"
		icon.shield_type = shield_key ## yeni tür ikonları (assets/ui/shields) kendi renginde - eski tint modülasyonu kaldırıldı
		icon.custom_minimum_size = Vector2(_icon_px, _icon_px)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.anchor_left = 0.5
		icon.anchor_right = 0.5
		icon.anchor_top = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_left = -_icon_px * 0.5
		icon.offset_right = _icon_px * 0.5
		icon.offset_top = -_icon_px * 0.5
		icon.offset_bottom = _icon_px * 0.5
		shield_btn.add_child(icon)
	else:
		shield_btn.tooltip_text = "Mana Kalkanı Yuvası (Boş)"
		_dim_slot(shield_btn)
		
	equip_grid.add_child(shield_btn)
	
	# 2. İşlevsellik yuvaları (kullanıcı isteği: "1 kalkan + 2 işlevsellik
	## yuvası") - sahip olunan UTILITY_KEYS türleri (şu an sadece spray)
	## sırayla dolduruluyor, kalan yuvalar boş placeholder olarak kalıyor.
	var owned_utility_keys: Array = []
	for utility_key: String in UTILITY_KEYS:
		if int(GameManager.get(utility_key + "_level")) > 0:
			owned_utility_keys.append(utility_key)

	for slot_index: int in range(MAX_UTILITY_SLOTS):
		var util_btn: Button = Button.new()
		util_btn.custom_minimum_size = Vector2(_slot, _slot)
		_decorate_slot(util_btn)

		if slot_index < owned_utility_keys.size():
			var utility_key: String = owned_utility_keys[slot_index]
			var utility_level: int = int(GameManager.get(utility_key + "_level"))
			var total_spent: int = 0
			for l: int in range(1, utility_level + 1):
				total_spent += _get_upgrade_cost(utility_key, l)
			var refund: int = int(round(total_spent * 0.7))

			util_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			util_btn.tooltip_text = "%s Lv%d\n\nSatmak için tıklayın (+%d Altın)" % [EQUIP_NAMES.get(utility_key, utility_key), utility_level, refund]
			util_btn.pressed.connect(_on_sell_utility_equip.bind(utility_key))

			var icon: Control = Control.new()
			icon.set_script(load("res://scripts/shop_item_icon.gd"))
			icon.item_type = utility_key
			icon.custom_minimum_size = Vector2(_icon_px, _icon_px)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.anchor_left = 0.5
			icon.anchor_right = 0.5
			icon.anchor_top = 0.5
			icon.anchor_bottom = 0.5
			icon.offset_left = -_icon_px * 0.5
			icon.offset_right = _icon_px * 0.5
			icon.offset_top = -_icon_px * 0.5
			icon.offset_bottom = _icon_px * 0.5
			util_btn.add_child(icon)

			var lvl_lbl: Label = Label.new()
			lvl_lbl.text = "Sv%d" % utility_level
			lvl_lbl.add_theme_font_size_override("font_size", UIKit.FS_BODY)
			lvl_lbl.add_theme_color_override("font_color", UIKit.C_CREAM)
			lvl_lbl.add_theme_color_override("font_outline_color", UIKit.C_OUTLINE)
			lvl_lbl.add_theme_constant_override("outline_size", 4)
			lvl_lbl.anchor_left = 1.0
			lvl_lbl.anchor_top = 1.0
			lvl_lbl.anchor_right = 1.0
			lvl_lbl.anchor_bottom = 1.0
			lvl_lbl.offset_left = -70
			lvl_lbl.offset_top = -38
			lvl_lbl.offset_right = -10
			lvl_lbl.offset_bottom = -8
			lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			util_btn.add_child(lvl_lbl)
		else:
			util_btn.tooltip_text = "İşlevsellik Yuvası (Boş)"
			_dim_slot(util_btn)

		equip_grid.add_child(util_btn)


## "key" hangi İşlevsellik yuvasına basıldığını belirtir (bkz.
## UTILITY_KEYS/MAX_UTILITY_SLOTS) - artık tek bir sabit "spray" değil,
## genel bir anahtar parametresi (ileride eklenecek başka işlevsellik
## eşyaları için de aynı fonksiyon kullanılabilsin diye).
func _on_sell_utility_equip(key: String) -> void:
	var level: int = int(GameManager.get(key + "_level"))
	if level <= 0:
		return
	var total_spent: int = 0
	for l: int in range(1, level + 1):
		total_spent += _get_upgrade_cost(key, l)
	var refund: int = int(round(total_spent * 0.7))
	_request_sell_confirmation(EQUIP_NAMES.get(key, key), refund, _do_sell_utility_equip.bind(key), "İşlevsellik  ·  Seviye %d" % level)


func _do_sell_utility_equip(key: String) -> void:
	var level: int = int(GameManager.get(key + "_level"))
	if level <= 0:
		return
	var total_spent: int = 0
	for l: int in range(1, level + 1):
		total_spent += _get_upgrade_cost(key, l)
	var refund: int = int(round(total_spent * 0.7))

	GameManager.set(key + "_level", 0)
	GameManager.gold += refund

	_last_equip_signature = ""
	_refresh()


func _refresh_items_grid() -> void:
	if _chest != null:
		_ch_build_bag()
		return
	var sig: String = str(player.get_max_item_slots() if player and is_instance_valid(player) and player.has_method("get_max_item_slots") else 1) + "|"
	for entry: Dictionary in GameManager.owned_items:
		sig += str(entry.get("key", "")) + ","
	if sig == _last_items_signature:
		return
	_last_items_signature = sig
	_item_slot_icons.clear()

	for child: Node in items_grid_box.get_children():
		child.queue_free()

	var part_slots: int = 1
	if player and is_instance_valid(player) and player.has_method("get_max_item_slots"):
		part_slots = player.get_max_item_slots()
	for kd in [Items.KADEME_EFSANEVI, Items.KADEME_EPIK, Items.KADEME_PARCA]:
		var limit: int = Items.slot_limit(kd, part_slots)
		var indices: Array = []
		for i: int in range(GameManager.owned_items.size()):
			if Items.kademe(str((GameManager.owned_items[i] as Dictionary).get("key", ""))) == kd:
				indices.append(i)
		var head := Label.new()
		head.text = "%s  %d/%d" % [Items.KADEME_NAMES[kd - 1].to_upper(), indices.size(), limit]
		UIKit.style_label(head, 40 if _mobile else 24, PH_TIER[kd - 1] if _mobile else TierSystem.COLORS[kd - 1], 0)
		items_grid_box.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 7 if _mobile else 6
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		items_grid_box.add_child(grid)
		## Boş yuvalar: sınır küçükse (efsanevi 5) hepsi, büyükse bir sıra.
		var cols: int = grid.columns
		var shown: int = mini(limit, maxi(indices.size(), cols * int(ceil(float(maxi(indices.size(), 1)) / float(cols)))))
		for n in range(maxi(shown, indices.size())):
			var btn: Button = Button.new()
			btn.custom_minimum_size = Vector2(_slot, _slot)
			_decorate_slot(btn)
			var frame: TextureRect = btn.get_node("SlotFrame") as TextureRect
			if n >= indices.size():
				btn.disabled = true
				_dim_slot(btn)
				grid.add_child(btn)
				continue
			var i: int = indices[n]
			var key: String = str((GameManager.owned_items[i] as Dictionary).get("key", ""))
			frame.texture = TierSystem.MINI_FRAME_TEXTURES[kd - 1]
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.tooltip_text = "%s
%s

Satmak için tıkla (+%d altın)" % [Items.item_name(key), Items.describe(key), Items.sell_refund(key)]
			btn.pressed.connect(_on_sell_item.bind(i))
			var icon := TextureRect.new()
			icon.texture = Items.icon(key)
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = _inset_px
			icon.offset_top = _inset_px
			icon.offset_right = -_inset_px
			icon.offset_bottom = -_inset_px
			btn.add_child(icon)
			_item_slot_icons[i] = icon
			grid.add_child(btn)


func _on_sell_item(index: int) -> void:
	if index < 0 or index >= GameManager.owned_items.size():
		return
	if _chest != null:
		_ch_select("item", index)
		return
	var key: String = str((GameManager.owned_items[index] as Dictionary).get("key", ""))
	_request_sell_confirmation(Items.item_name(key), Items.sell_refund(key), _do_sell_item.bind(index),
			Items.KADEME_NAMES[Items.kademe(key) - 1] + "  ·  " + Items.describe(key))


## Satış iadesi eşyanın TAM fiyatının %50'si (tarifle ucuza alınmış olsa da - parçaları tek tek satmakla aynı değer).
## Kullanıcı isteği (2026-10-08): "item satınca itemin parçalanıp altına dönüşme animasyonu" - yuvanın ikonu parçalanır, parçalar altın
## paraya dönüp altın paneline uçar (gold_reward_fx.gd show_shatter; altın burada/oyuncuda eklenir, animasyon çift eklemez).
func _do_sell_item(index: int) -> void:
	if index < 0 or index >= GameManager.owned_items.size():
		return
	var key: String = str((GameManager.owned_items[index] as Dictionary).get("key", ""))
	var shatter_tex: Texture2D = Items.icon(key)
	var shatter_from: Vector2 = Vector2.ZERO
	var shatter_size: Vector2 = Vector2.ZERO
	var slot_icon: TextureRect = _item_slot_icons.get(index) as TextureRect
	if shatter_tex != null and is_instance_valid(slot_icon) and slot_icon.is_inside_tree():
		var xf: Transform2D = slot_icon.get_global_transform_with_canvas()
		var top_left: Vector2 = xf * Vector2.ZERO
		var bottom_right: Vector2 = xf * slot_icon.size
		shatter_from = (top_left + bottom_right) * 0.5
		shatter_size = (bottom_right - top_left).abs()
	var refund: int = Items.sell_refund(key)
	if player and is_instance_valid(player) and player.has_method("sell_owned_item"):
		refund = player.sell_owned_item(index)
	else:
		GameManager.owned_items.remove_at(index)
		GameManager.gold += refund
	if shatter_size != Vector2.ZERO and refund > 0:
		GoldRewardFx.show_shatter(get_tree(), refund, shatter_from, shatter_tex, shatter_size)
	_last_items_signature = ""
	_refresh()


## ---------------------------------------------------------------- TELEFON YERLEŞİMİ (bkz. dosya başındaki _mobile notu)
## rect: tuval px (hud.gd verir). Başlık levhası + altın/tecrübe üstte, X sağ üstte, yuvalar kaydırmalı alanda, altta bilgi şeridi.
func apply_mobile_layout(rect: Rect2) -> void:
	if _chest != null: ## masaüstü görünüşü kurulmuşken telefon yerleşimi istendi: eski (telefon) kuruluma dön
		_chest.queue_free()
		_chest = null
		($Frame as Control).visible = true
		_build_legacy()
	_mobile = true
	_slot = 136.0
	_icon_px = 96.0
	_inset_px = 20.0
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = rect.position
	size = rect.size
	pivot_offset = size * 0.5
	var frame: Control = $Frame as Control
	var header: Panel = frame.get_node_or_null("HeaderBar") as Panel
	if header:
		header.offset_top = 22.0
		header.offset_bottom = 118.0
		header.offset_right = -152.0
		var title: Label = header.get_node_or_null("Title") as Label
		if title:
			title.add_theme_font_size_override("font_size", 48)
	close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left = -136.0
	close_button.offset_right = -28.0
	close_button.offset_top = 22.0
	close_button.offset_bottom = 118.0
	close_button.add_theme_font_size_override("font_size", 48)
	## Altın / tecrübe: alt bilgi yerine başlık levhasının sağ yarısında.
	var footer: Control = frame.get_node_or_null("FooterBG") as Control
	if footer:
		footer.visible = false
	## Sağ kenara yaslı (28 px iç pay - ayrıntı sütunuyla aynı hizada; eskiden başlığın ortasında yüzüyordu).
	var row: Array = [[frame.get_node("GoldIcon"), 0.0], [gold_label, 52.0], [frame.get_node("XPIcon"), 260.0], [xp_label, 312.0]]
	for r in row:
		var c: Control = r[0] as Control
		var is_icon: bool = not (c is Label)
		c.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		c.offset_left = -520.0 + float(r[1])
		c.offset_right = c.offset_left + (44.0 if is_icon else 180.0)
		c.offset_top = 48.0 if is_icon else 34.0
		c.offset_bottom = 92.0 if is_icon else 106.0
	## Yuva alanı solda kendi genişliğinde (5 yuva), kalan genişlik sağdaki ayrıntı sütununa (prototip B "Yan Ray + Detay"; kullanıcı
	## 2026-10-19: yuvalar sola yığılıp sağ taraf boş kalıyordu, ayrıntı ekran boyu alt şeritteydi).
	var slots_w: float = 5.0 * _slot + 4.0 * 12.0 + 2.0 * 28.0 + 24.0
	var detail_w: float = maxf(560.0, rect.size.x - slots_w - 28.0 * 3.0)
	var col_h: float = rect.size.y - 136.0 - 28.0
	var scroll: ScrollContainer = main_layout.get_parent() as ScrollContainer
	if scroll:
		scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		scroll.offset_left = 28.0
		scroll.offset_right = -(detail_w + 56.0)
		scroll.offset_top = 136.0
		scroll.offset_bottom = -28.0
	for c in main_layout.get_children():
		if c is Label:
			var l := c as Label
			l.text = l.text.replace("(Satmak için tıklayın)", "").strip_edges()
			l.add_theme_font_size_override("font_size", 40)
	weapons_grid.add_theme_constant_override("separation", 12)
	equip_grid.add_theme_constant_override("separation", 12)
	## Bilgi şeridi (bir kez kurulur; ekran yeniden yerleşince sadece boyutlanır - madde 276: eskiden her çağrıda yenisi eklenip
	## stil eskisine gidiyordu).
	var strip: Panel = frame.get_node_or_null("MobileDetail") as Panel
	var fresh: bool = strip == null
	if fresh:
		strip = Panel.new()
		strip.name = "MobileDetail"
		strip.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))
		frame.add_child(strip)
		_detail_name = Label.new()
		UIKit.style_label(_detail_name, 48, UIKit.C_TEXT, 0)
		_detail_name.clip_text = true
		strip.add_child(_detail_name)
		_detail_desc = Label.new()
		UIKit.style_label(_detail_desc, 40, UIKit.C_TEXT_DIM, 0)
		_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_desc.clip_text = true
		strip.add_child(_detail_desc)
		_detail_sell = Button.new()
		UIKit.style_button(_detail_sell, "red", false, 40)
		_detail_sell.pressed.connect(_on_detail_sell)
		strip.add_child(_detail_sell)
		UISound.connect_all_buttons(strip)
	strip.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	strip.offset_left = -(detail_w + 28.0)
	strip.offset_right = -28.0
	strip.offset_top = 136.0
	strip.offset_bottom = -28.0
	_detail_name.position = Vector2(32.0, 28.0)
	_detail_name.size = Vector2(detail_w - 64.0, 60.0)
	_detail_desc.position = Vector2(32.0, 104.0)
	_detail_desc.size = Vector2(detail_w - 64.0, maxf(80.0, col_h - 104.0 - 136.0 - 64.0))
	_detail_sell.position = Vector2(32.0, col_h - 136.0 - 32.0)
	_detail_sell.size = Vector2(detail_w - 64.0, 136.0)
	_apply_night_style()
	_clear_detail()
	## Yuvalar yeni boyutla yeniden kurulsun.
	_last_weapons_signature = "-"
	_last_equip_signature = "-"
	_last_items_signature = "-"
	_refresh()


func _show_detail(item_label: String, desc: String, refund: int, action: Callable) -> void:
	if _detail_name == null:
		return
	_detail_name.text = item_label
	_detail_name.add_theme_color_override("font_color", PH_TEXT if _mobile else UIKit.C_TEXT)
	_detail_desc.text = desc
	_detail_action = action
	_detail_sell.visible = action.is_valid()
	_detail_sell.text = "SAT  +%d" % refund


func _clear_detail() -> void:
	if _detail_name == null:
		return
	_detail_name.text = "Bir eşyaya dokun"
	_detail_name.add_theme_color_override("font_color", PH_DIM if _mobile else UIKit.C_TEXT_DIM)
	_detail_desc.text = "Ne işe yaradığı ve satış fiyatı burada görünür."
	_detail_action = Callable()
	_detail_sell.visible = false


func _on_detail_sell() -> void:
	if _detail_action.is_valid():
		_detail_action.call()
	_clear_detail()


## ---------------------------------------------------------------- TELEFON: Gece Sıvası (madde 276; kullanıcı onayı 2026-10-18,
## madde 253 "B"): bej kit telefonda mavi-mor sıva paneline döner (çerçeve, başlık, boş yuvalar, kademe başlıkları, ayrıntı şeridi,
## SAT). Kapatma telefonda hud.gd'nin yan rayındaki geri düğmesi (X gizli). Masaüstü aynı.
const PH_PANEL := Color("#1a1a2c")
const PH_INSET := Color("#12121f")
const PH_LINE := Color("#3b3a5a")
const PH_LINE_HI := Color("#5f5c86")
const PH_TEXT := Color("#efe6d6")
const PH_DIM := Color("#a7a2c0")
const PH_ACCENT := Color("#f4c56e")
const PH_TIER := [Color("#c39a64"), Color("#6f9df2"), Color("#b98af2")]


static func _ph_sb(fill: Color, border: Color, bw: int, rad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(rad)
	sb.corner_detail = 6
	return sb


func _apply_night_style() -> void:
	var frame: Control = get_node_or_null("Frame") as Control
	if frame == null:
		return
	frame.add_theme_stylebox_override("panel", _ph_sb(Color(PH_PANEL, 0.97), PH_LINE_HI, 3, 10))
	var header: Panel = frame.get_node_or_null("HeaderBar") as Panel
	if header:
		header.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var title: Label = header.get_node_or_null("Title") as Label
		if title:
			title.text = "ÇANTA"
			UIKit.style_label(title, 48, PH_ACCENT, 0)
	close_button.visible = false
	if main_layout:
		for c in main_layout.get_children():
			if c is Label:
				(c as Label).add_theme_color_override("font_color", PH_DIM)
	var strip: Panel = frame.get_node_or_null("MobileDetail") as Panel
	if strip:
		strip.add_theme_stylebox_override("panel", _ph_sb(Color(PH_INSET, 0.92), PH_LINE, 2, 12))
	if _detail_desc:
		_detail_desc.add_theme_color_override("font_color", PH_DIM)
	if _detail_sell:
		var red := Color("#6a2a24")
		_detail_sell.add_theme_stylebox_override("normal", _ph_sb(red, Color("#9a4a3e"), 3, 12))
		_detail_sell.add_theme_stylebox_override("hover", _ph_sb(red.lightened(0.08), Color("#9a4a3e"), 3, 12))
		_detail_sell.add_theme_stylebox_override("pressed", _ph_sb(red.darkened(0.12), Color("#9a4a3e"), 3, 12))
		_detail_sell.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for fc: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			_detail_sell.add_theme_color_override(fc, PH_TEXT)



## ================================================================ MASAÜSTÜ: "KAHRAMAN ÇANTASI" (madde 341)
## Prototip: tools/proto_20261020/envanter_proto.gd _build_b (madde 336). Görünüş ShopDarkKit PAL_WOOD (demirci "Örs Vitrini") + HUD Kısık Ahşap
## kenarı; simgeler: silah = Zanaatkâr kademe sanatı + efsun kontürü (WeaponTierArt + DarkKit.wicon), stat = stat_mini_lol (HUD mini paneli),
## eşya = kademe renkli yuva (satıcıdaki tile). Pencere dükkanlar gibi grup panelinin solundaki güvenli alanda ortalanır, sığmazsa küçülür.
## Oyunu durdurmaz; arkadaki karartmaya tıklamak kapatır. Kurallar (satış iadesi, son silah, kalkan satılmaz) bu dosyanın üst kısmıyla aynı.
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const DarkKit := preload("res://scripts/shop_dark_kit.gd")
const HudTheme := preload("res://scripts/hud_theme.gd")
const HudStatPanel := preload("res://scripts/hud_stat_panel.gd")
const StatsPanelScript := preload("res://scripts/stats_panel.gd")
const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const WeaponCatalogScript := preload("res://scripts/weapon_catalog.gd")
const PetCatalog := preload("res://scripts/pet_catalog.gd")
const ModalSafeArea := preload("res://scripts/modal_safe_area.gd")

const CH_SIZE := Vector2(1600, 1000)
const CH_LEFT_W := 360.0
const CH_STAGE := Vector2(520, 860)
const CH_TILE := 72.0 ## 32 px eşya ikonu 2x (yuva kenarıyla >= 72 olmalı, yoksa 1x kalır)
const CH_COLS := 7
const CH_BAG_H := 332.0 ## 3 kademe satırı; fazlası kayar
const CH_WSLOT := 112.0
const CH_WSLOT_SMALL := 88.0 ## 4+ silah (Talon Ayna Formu): küçük yuva, ad yazısı yok
const CH_EQ_SLOT := 96.0
const CH_REFRESH_MS := 250
## Silah yayı: karakterin çevresinde 210° -> 330° (üst yarı), merkez/yarıçaplar sahne px.
const CH_ARC_CENTER := Vector2(260, 408)
const CH_ARC_RADIUS := Vector2(208, 312)
const CH_CHEST := Vector2(260, 370) ## bağ çizgilerinin hedefi (karakterin göğsü)
const CH_XP := Color("#c9a2f0")
const CH_XP_TEXT := Color("#d0a8f6")
const CH_HEART := Color("#e8735e")
const CH_GROUPS := [
	["SALDIRI", ["damage", "fire_rate", "crit_chance", "crit_damage", "shield_pen_percent", "range"]],
	["SAVUNMA", ["shield_protection", "shield_amount", "shield_regen", "health_regen", "lifesteal", "dodge"]],
	["DESTEK", ["cooldown_reduction", "heal_power", "speed", "luck"]],
]
## Eşya stat anahtarı -> stat_mini_lol simgesi ("heart" / "xp" = kendi glifi/dokusu).
const CH_STAT_ICON := {
	"damage_bonus": "damage", "item_flat_hit_damage": "damage", "item_damage_mult_bonus": "damage", "item_ap_percent": "damage",
	"item_fire_rate_percent": "fire_rate", "crit_chance_bonus": "crit_chance", "item_crit_damage_bonus": "crit_damage",
	"cooldown_reduction_percent": "cooldown_reduction", "lifesteal_percent": "lifesteal", "item_extra_lifesteal": "lifesteal",
	"dodge_chance": "dodge", "item_speed_percent": "speed", "shield_pen_percent": "shield_pen_percent",
	"item_pickup_range_percent": "range", "shield_protection_bonus": "shield_protection", "item_shield_power_flat": "shield_amount",
	"item_shield_regen_flat": "shield_regen", "item_shield_regen_percent": "shield_regen", "item_shield_delay_reduction": "shield_regen",
	"item_health_regen": "health_regen", "item_vitamin_regen_bonus": "health_regen", "heal_shield_power": "heal_power", "luck": "luck",
	"max_health": "heart", "exp_gain_percent": "xp",
}
const CH_G_HEART := [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
const CH_XP_GEM := "res://assets/ui/newui/icon_xp_gem.png"

var _k = null ## DarkKit örneği (PAL_WOOD)
var _chest: Control = null ## tam ekran kök: karartma + pencere
var _ch_win: Control = null
var _ch_gold: Label = null
var _ch_shard: Label = null
var _ch_stat_vals: Dictionary = {} ## stat id -> değer Label'ı
var _ch_tips: Dictionary = {}
var _ch_stage: Control = null
var _ch_lines = null ## DarkKit.Lines - silah yuvası -> göğüs bağları
var _ch_sprite: AnimatedSprite2D = null
var _ch_name: Label = null
var _ch_level: Label = null
var _ch_xp_bar = null ## DarkKit.Bar
var _ch_xp_text: Label = null
var _ch_bag_count: Label = null
var _ch_detail: PanelContainer = null
var _ch_detail_box: VBoxContainer = null
var _ch_sell_btn: Button = null
var _ch_sell_note: String = "" ## seçili şeyin iade metni (testler okur)
var _ch_sel: Dictionary = {} ## {"kind": "item" | "weapon" | "shield" | "pet", "index": int}
var _ch_rings: Array = [] ## [tür, dizin, seçim halkası]
var _ch_weapon_icons: Dictionary = {} ## silah dizini -> ikon TextureRect (satışta parçalanma kaynağı)
var _ch_last_stats_ms: int = -100000
var _ch_reserved: float = -1.0


func _build_chest() -> void:
	for c in get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_k = DarkKit.new(DarkKit.PAL_WOOD)
	_chest = Control.new()
	_chest.name = "HeroChest"
	_chest.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chest)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.02, 0.04, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_ch_on_dim_input)
	_chest.add_child(dim)
	## ahşap kenar (HUD Kısık Ahşap) + iç panel (demirci ahşabı)
	var rim: PanelContainer = _k.box(HudTheme.RIM, HudTheme.OUTLINE, 8, 4, 6)
	rim.name = "Window"
	rim.mouse_filter = Control.MOUSE_FILTER_STOP ## pencereye tıklama arkadaki karartmaya (kapat) düşmesin
	rim.custom_minimum_size = CH_SIZE
	_chest.add_child(rim)
	_ch_win = rim
	var win: PanelContainer = _k.box(_k.c("panel"), HudTheme.RIM_LO, 18, 3, 4)
	win.theme = _k.theme()
	rim.add_child(win)
	var col: VBoxContainer = _k.v(12)
	win.add_child(col)
	col.add_child(_ch_header())
	var body: HBoxContainer = _k.h(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	body.add_child(_ch_stats_column())
	body.add_child(_ch_build_stage())
	var right: VBoxContainer = _k.v(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	right.add_child(_ch_bag_box())
	_ch_detail = _k.box(_k.c("panel2"), _k.c("line_hi"), 16, 3, 6)
	_ch_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ch_detail.mouse_filter = Control.MOUSE_FILTER_PASS
	_ch_detail_box = _k.v(10)
	_ch_detail.add_child(_ch_detail_box)
	right.add_child(_ch_detail)
	UISound.connect_all_buttons(_chest)


func _ch_header() -> HBoxContainer:
	var head: HBoxContainer = _k.h(16)
	var plaque: PanelContainer = _k.box(HudTheme.INSET, HudTheme.RIM_HI, 10, 3, 4)
	var pr: HBoxContainer = _k.h(12)
	pr.add_child(_k.sp(6))
	pr.add_child(_k.glyph(DarkKit.G_BAG, HudTheme.ACCENT, 4))
	pr.add_child(_k.lbl("KAHRAMAN ÇANTASI", 40, HudTheme.ACCENT))
	pr.add_child(_k.sp(6))
	plaque.add_child(pr)
	head.add_child(plaque)
	head.add_child(_k.sp(0, 0, true))
	var g: HBoxContainer = _k.amt(GameManager.gold, 32, _k.c("price"))
	_ch_gold = g.get_meta("label") as Label
	head.add_child(g)
	head.add_child(_k.sp(10))
	var s: HBoxContainer = _k.amt(GameManager.weapon_shards, 32, DarkKit.SHARD_TEXT, "shard")
	_ch_shard = s.get_meta("label") as Label
	head.add_child(s)
	head.add_child(_k.sp(10))
	var x: Button = _k.btn("", "ghost", 32, 56, 56)
	x.name = "CloseX"
	x.tooltip_text = "Kapat (ESC)"
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(_k.glyph(DarkKit.G_X, _k.c("text"), 4))
	x.add_child(cc)
	x.pressed.connect(_on_close_pressed)
	head.add_child(x)
	return head


func _ch_on_dim_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_on_close_pressed()


## Pencere grup panelinin solundaki güvenli alanda ortalanır (dükkanlarla aynı kural, madde 36), sığmazsa küçülür.
func _ch_fit() -> void:
	if _ch_win == null or not is_inside_tree():
		return
	var view: Vector2 = get_viewport_rect().size
	_ch_reserved = ModalSafeArea.reserved_right(get_tree(), view)
	var safe: Rect2 = ModalSafeArea.rect(get_tree(), view)
	var sz: Vector2 = _ch_win.get_combined_minimum_size().max(CH_SIZE)
	var fit: float = minf(1.0, minf(safe.size.x * 0.97 / sz.x, safe.size.y * 0.97 / sz.y))
	_ch_win.scale = Vector2.ONE * fit
	_ch_win.position = (safe.get_center() - sz * fit * 0.5).round()


func _ch_on_open() -> void:
	## Grup paneli (aynı katman) pencerenin ÜSTÜNDE kalsın: envanter açıkken de arkadaşa altın gönderilebilsin (hud.gd PartyPanelLayer notu).
	var layer: Node = get_parent()
	if layer is CanvasLayer and get_index() != 0:
		layer.move_child.call_deferred(self, 0)
	_ch_sync_sprite()
	_ch_fit()
	## Her açılış ilk eşyadan başlar (panel oyun başında, çanta boşken kurulur; eski seçim evcilde kalıyordu).
	_ch_sel = _ch_default_sel()
	_ch_last_stats_ms = -100000
	_ch_refresh()
	_ch_update_rings()
	_ch_build_detail()


func _ch_refresh() -> void:
	var a: bool = _ch_build_weapons()
	var b: bool = _ch_build_equip()
	var c: bool = _ch_build_bag()
	if a or b or c:
		if not _ch_sel_valid():
			_ch_sel = _ch_default_sel()
		_ch_update_rings()
		_ch_build_detail()
	if _ch_gold:
		_ch_gold.text = str(GameManager.gold)
		_ch_shard.text = str(GameManager.weapon_shards)
	var now: int = Time.get_ticks_msec()
	if now - _ch_last_stats_ms < CH_REFRESH_MS:
		return
	_ch_last_stats_ms = now
	_ch_refresh_stats()
	if is_inside_tree() and visible and not is_equal_approx(_ch_reserved, ModalSafeArea.reserved_right(get_tree(), get_viewport_rect().size)):
		_ch_fit()


func _ch_clear(n: Node) -> void:
	if n == null:
		return
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _ch_has_player() -> bool:
	return player != null and is_instance_valid(player)


## ---------------------------------------------------------------- sol: gruplu özellikler
func _ch_stats_column() -> Control:
	_ch_build_tips()
	var box: PanelContainer = _k.box(_k.c("inset"), _k.c("line"), 14)
	box.custom_minimum_size.x = CH_LEFT_W
	var v: VBoxContainer = _k.v(4)
	box.add_child(v)
	for g: Array in CH_GROUPS:
		var gh: HBoxContainer = _k.h(10)
		gh.add_child(_k.lbl(str(g[0]), 24, _k.c("accent")))
		var ln: ColorRect = _k.hline(_k.c("line"), 3)
		ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ln.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		gh.add_child(ln)
		v.add_child(gh)
		var i: int = 0
		for id: String in g[1]:
			v.add_child(_ch_stat_row(id, i % 2 == 0))
			i += 1
		v.add_child(_k.sp(0, 8))
	return box


func _ch_stat_row(id: String, stripe: bool) -> Control:
	var p: PanelContainer = _k.box(Color(_k.c("panel3"), 0.45) if stripe else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 2)
	var sb: StyleBoxFlat = p.get_theme_stylebox("panel") as StyleBoxFlat
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	p.mouse_filter = Control.MOUSE_FILTER_STOP ## ipucu (stat açıklaması)
	p.tooltip_text = str(_ch_tips.get(id, ""))
	var r: HBoxContainer = _k.h(10)
	r.custom_minimum_size.y = 30
	r.add_child(_k.icon(DarkKit.tex(HudStatPanel.ICON_DIR + id + ".png"), 24))
	r.add_child(_k.expand(_k.lbl(_ch_stat_name(id), 24, _k.c("text"))))
	var val: Label = _k.lbl("-", 24, _k.c("price"), HORIZONTAL_ALIGNMENT_RIGHT)
	_ch_stat_vals[id] = val
	r.add_child(val)
	p.add_child(r)
	return p


func _ch_stat_name(id: String) -> String:
	for s: Array in HudStatPanel.STATS:
		if s[0] == id:
			return str(s[1])
	return id


## İpuçları HUD mini stat paneliyle aynı kaynaktan (hud_stat_panel.gd _build_tips).
func _ch_build_tips() -> void:
	var extra: Dictionary = {}
	for row in StatsPanelScript.EXTRA_ROWS:
		extra[row[0]] = StatsPanelScript.row_tip(row)
	for s: Array in HudStatPanel.STATS:
		var tip: String = str(s[2])
		if tip.begins_with("@"):
			var key: String = tip.substr(1)
			tip = str(StatsPanelScript.STAT_TIPS.get(key, extra.get(key, s[1])))
		_ch_tips[s[0]] = tip


func _ch_refresh_stats() -> void:
	if not _ch_has_player():
		return
	var vals: Dictionary = HudStatPanel.values_for(player)
	for id in _ch_stat_vals:
		var l: Label = _ch_stat_vals[id]
		var t: String = str(vals.get(id, "-"))
		if l.text != t:
			l.text = t
	if "level" in player and _ch_level:
		_ch_level.text = " Sv %d " % int(player.get("level"))
		var need: float = maxf(1.0, float(player.get("xp_to_next_level")))
		var have: float = float(player.get("xp"))
		_ch_xp_bar.set_frac(have / need)
		_ch_xp_text.text = "%d / %d XP" % [int(have), int(need)]


## ---------------------------------------------------------------- orta: sahne (karakter + silah yayı + kalkan/evcil)
func _ch_build_stage() -> Control:
	_ch_stage = Control.new()
	_ch_stage.name = "Stage"
	_ch_stage.custom_minimum_size = CH_STAGE
	_ch_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spot = DarkKit.Spot.new(_k.c("spot"), 0.72)
	spot.position = Vector2(0, 40)
	spot.size = Vector2(CH_STAGE.x, 640)
	_ch_stage.add_child(spot)
	_ch_lines = DarkKit.Lines.new()
	_ch_lines.size = CH_STAGE
	_ch_stage.add_child(_ch_lines)
	_ch_sprite = AnimatedSprite2D.new()
	_ch_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ch_stage.add_child(_ch_sprite)
	weapons_grid = Control.new()
	weapons_grid.name = "WeaponSlots"
	weapons_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapons_grid.size = CH_STAGE
	_ch_stage.add_child(weapons_grid)
	equip_grid = Control.new()
	equip_grid.name = "EquipSlots"
	equip_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equip_grid.size = CH_STAGE
	_ch_stage.add_child(equip_grid)
	## ad + seviye + XP
	var nv: VBoxContainer = _k.v(4)
	var nr: HBoxContainer = _k.h(12)
	nr.alignment = BoxContainer.ALIGNMENT_CENTER
	_ch_name = _k.lbl(str(Characters.get_def(GameManager.selected_char_id).get("name", "")), 40, _k.c("text"))
	nr.add_child(_ch_name)
	var lvp: PanelContainer = _k.box(HudTheme.INSET, HudTheme.ACCENT, 2, 2, 3)
	_ch_level = _k.lbl(" Sv 1 ", 24, HudTheme.ACCENT)
	lvp.add_child(_ch_level)
	nr.add_child(lvp)
	nv.add_child(nr)
	_ch_xp_bar = DarkKit.Bar.new(0.0, CH_XP, _k.c("inset"), 16, 360)
	nv.add_child(_k.center(_ch_xp_bar))
	_ch_xp_text = _k.lbl("", 24, CH_XP_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	nv.add_child(_ch_xp_text)
	nv.position = Vector2(40, 750)
	nv.size = Vector2(440, 100)
	_ch_stage.add_child(nv)
	_ch_sync_sprite()
	return _ch_stage


## Oyuncunun GERÇEK kareleri (form/görünüm değişse de doğru), yoksa karakter tanımı; idle_down döngüde.
func _ch_sync_sprite() -> void:
	if _ch_sprite == null:
		return
	var fr: SpriteFrames = null
	if _ch_has_player() and "anim" in player and player.get("anim") is AnimatedSprite2D:
		fr = (player.get("anim") as AnimatedSprite2D).sprite_frames
	if fr == null:
		var p: String = str(Characters.get_def(GameManager.selected_char_id).get("frames", ""))
		fr = load(p) as SpriteFrames if p != "" and ResourceLoader.exists(p) else null
	if fr == null or fr.get_animation_names().is_empty():
		_ch_sprite.visible = false
		return
	var anim: String = "idle_down" if fr.has_animation("idle_down") else String(fr.get_animation_names()[0])
	if _ch_sprite.sprite_frames != fr:
		_ch_sprite.sprite_frames = fr
	var tex: Texture2D = fr.get_frame_texture(anim, 0)
	var h: float = tex.get_size().y if tex else 48.0
	var sc: float = maxf(1.0, floorf(300.0 / h))
	_ch_sprite.scale = Vector2.ONE * sc
	_ch_sprite.position = Vector2(CH_STAGE.x * 0.5, roundf(440.0 - 0.12 * h * sc))
	_ch_sprite.visible = true
	if _ch_sprite.animation != StringName(anim) or not _ch_sprite.is_playing():
		_ch_sprite.play(anim)


func _ch_weapon_tier(entry: Dictionary) -> int:
	var ench: Dictionary = entry.get("enchant", {})
	if ench.is_empty():
		return 1
	if bool(ench.get("final", false)):
		return 5
	return mini(4, 1 + (ench.get("ups", []) as Array).size())


func _ch_roman(entry: Dictionary) -> String:
	var plus: int = EnchantDefs.plus_count(entry.get("enchant", {}))
	return DarkKit.ROMAN[_ch_weapon_tier(entry) - 1] + ((" +%d" % plus) if plus > 0 else "")


func _ch_tier_col(t: int) -> Color:
	return DarkKit.ENCH_COL[t] if t >= 2 else _k.c("dim")


func _ch_weapon_tex(key: String, tier: int) -> Texture2D:
	var t: Texture2D = WeaponTierArt.texture(key, tier)
	return t if t != null else WEAPON_ICON_TEXTURES.get(key)


func _ch_weapon_name(key: String) -> String:
	return str(WEAPON_NAMES.get(key, WeaponCatalogScript.display_name(key)))


func _ch_pips(entry: Dictionary, w: float, h: float = 10.0) -> Control:
	var ench: Dictionary = entry.get("enchant", {})
	var n: int = (ench.get("ups", []) as Array).size() + (1 if bool(ench.get("final", false)) else 0)
	var cols: Array = [DarkKit.ENCH_COL[2], DarkKit.ENCH_COL[3], DarkKit.ENCH_COL[4], DarkKit.ENCH_COL[4], DarkKit.ENCH_COL[5]]
	return DarkKit.TierPips.new(cols, n, _k.c("inset"), w, h)


## Yuva düğmesi: görünmez Button + içerik (çocuk) + seçim halkası. Halka _ch_rings'e kaydedilir.
func _ch_slot_button(kind: String, index: int, s: float, content: Control, tip: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(s, s)
	b.size = b.custom_minimum_size
	for st: String in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_theme_stylebox_override("focus", _k.sb(Color(0, 0, 0, 0), _k.c("accent").lightened(0.3), 3, 6))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = tip
	var ring: Control = content.get_node_or_null("SelRing") as Control
	if ring == null:
		ring = Panel.new()
		ring.name = "SelRing"
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		(ring as Panel).add_theme_stylebox_override("panel", _k.sb(Color(0, 0, 0, 0), _k.c("accent"), 3, 8))
		ring.position = Vector2(-6, -6)
		ring.size = Vector2(s + 12, s + 12)
		b.add_child(ring)
	ring.visible = false
	b.add_child(content)
	_ch_rings.append([kind, index, ring])
	b.pressed.connect(_ch_select.bind(kind, index))
	return b


func _ch_forget_rings(kind: String) -> void:
	_ch_rings = _ch_rings.filter(func(r: Array) -> bool: return r[0] != kind and is_instance_valid(r[2]))


func _ch_weapon_spot(i: int, n: int) -> Vector2:
	var t: float = 0.5 if n <= 1 else float(i) / float(n - 1)
	var ang: float = deg_to_rad(lerpf(210.0, 330.0, t))
	return CH_ARC_CENTER + Vector2(cos(ang) * CH_ARC_RADIUS.x, sin(ang) * CH_ARC_RADIUS.y)


func _ch_build_weapons() -> bool:
	if weapons_grid == null:
		return false
	var maxw: int = int(player.get_max_owned_weapons()) if _ch_has_player() and player.has_method("get_max_owned_weapons") else 3
	var sig: String = str(maxw) + "|"
	for entry: Dictionary in GameManager.owned_weapons:
		var ench: Dictionary = entry.get("enchant", {})
		sig += "%s:%d:%d:%d:%s:%d," % [str(entry.get("key", "")), int(entry.get("level", 1)), int(entry.get("shards_spent", 0)),
				(ench.get("ups", []) as Array).size(), str(ench.get("final", false)), int(ench.get("plus", 0))]
	if sig == _last_weapons_signature:
		return false
	_last_weapons_signature = sig
	_ch_clear(weapons_grid)
	_ch_forget_rings("weapon")
	_ch_weapon_icons.clear()
	_ch_lines.segs.clear()
	var n: int = maxi(maxw, GameManager.owned_weapons.size())
	var s: float = CH_WSLOT if n <= 3 else CH_WSLOT_SMALL
	for i in n:
		var c: Vector2 = _ch_weapon_spot(i, n)
		var pos: Vector2 = (c - Vector2(s, s) * 0.5).round()
		_ch_lines.segs.append([PackedVector2Array([c, c.lerp(CH_CHEST, 0.42)]), Color(_k.c("line_hi"), 0.7), 3.0])
		if i >= GameManager.owned_weapons.size():
			var e: Panel = _k.empty_slot(s)
			e.position = pos
			e.size = Vector2(s, s)
			e.tooltip_text = "Boş silah yuvası (demirciden silah alınır)"
			e.mouse_filter = Control.MOUSE_FILTER_STOP
			weapons_grid.add_child(e)
			continue
		var entry: Dictionary = GameManager.owned_weapons[i]
		var key: String = str(entry.get("key", ""))
		var tier: int = _ch_weapon_tier(entry)
		var tc: Color = _ch_tier_col(tier)
		var bg: PanelContainer = _k.box(_k.c("inset"), tc.darkened(0.15), 0, 3, 6)
		bg.custom_minimum_size = Vector2(s, s)
		bg.size = bg.custom_minimum_size
		var ic: Control = _k.wicon(_ch_weapon_tex(key, tier), s - 8.0, tier)
		bg.add_child(_k.center(ic))
		_ch_weapon_icons[i] = ic.get_child(ic.get_child_count() - 1) as TextureRect
		var btn: Button = _ch_slot_button("weapon", i, s, bg, _ch_weapon_name(key))
		btn.position = pos
		weapons_grid.add_child(btn)
		var badge: PanelContainer = _k.box(HudTheme.OUTLINE, tc, 2, 2, 3)
		badge.add_child(_k.lbl(" " + _ch_roman(entry) + " ", 24, tc))
		badge.position = pos + Vector2(s - 36, -14)
		weapons_grid.add_child(badge)
		if n <= 3:
			for k2 in 2:
				var t: String = _ch_weapon_name(key) if k2 == 0 else _ch_trait_name(entry)
				var l: Label = _k.lbl(t, 24, _k.c("text") if k2 == 0 else _k.c("dim"), HORIZONTAL_ALIGNMENT_CENTER)
				_ch_put_label(weapons_grid, l, Vector2(c.x - 90, pos.y + s + 4 + 24 * k2), Vector2(180, 26))
	_ch_lines.queue_redraw()
	UISound.connect_all_buttons(weapons_grid)
	return true


## Serbest yerleşen yazı: boyut AĞACA EKLENDİKTEN sonra verilir - ağaç dışında Label'ın en küçük boyutu yedek yazı tipiyle ölçülüp
## kutuyu büyütüyordu (180x26 -> 237x70; yazılar kayıp üst üste biniyordu, bkz. ShopDarkKit.est_w notu).
func _ch_put_label(parent: Control, l: Label, pos: Vector2, sz: Vector2) -> void:
	parent.add_child(l)
	l.size = sz
	l.position = pos


func _ch_trait_name(entry: Dictionary) -> String:
	var d: Dictionary = EnchantDefs.get_def(str((entry.get("enchant", {}) as Dictionary).get("id", "")))
	return str(d.get("name", ""))


func _ch_build_equip() -> bool:
	if equip_grid == null:
		return false
	var shield_key: String = _owned_shield_type()
	var pet: String = PetCatalog.selected()
	var sig: String = "%s:%s:%s" % [shield_key, str(GameManager.shield_enchant_ups), pet]
	if sig == _last_equip_signature:
		return false
	_last_equip_signature = sig
	_ch_clear(equip_grid)
	_ch_forget_rings("shield")
	_ch_forget_rings("pet")
	var specs: Array = [
		["shield", DarkKit.tex(str(ShieldEnchantDefs.ICONS.get(shield_key, ""))) if shield_key != "" else null,
			"MANA KALKANI", ShieldEnchantDefs.type_name(shield_key) if shield_key != "" else "Yok", Vector2(70, 580)],
		["pet", PetCatalog.icon(pet), "EVCİL", PetCatalog.display_name(pet), Vector2(354, 580)],
	]
	for sp: Array in specs:
		var pos: Vector2 = sp[4]
		var bg: PanelContainer = _k.box(_k.c("inset"), HudTheme.RIM_HI, 0, 3, 6)
		bg.custom_minimum_size = Vector2(CH_EQ_SLOT, CH_EQ_SLOT)
		bg.size = bg.custom_minimum_size
		if sp[1] != null:
			bg.add_child(_k.icon(sp[1], 72))
		var btn: Button = _ch_slot_button(str(sp[0]), 0, CH_EQ_SLOT, bg, str(sp[3]))
		btn.position = pos
		equip_grid.add_child(btn)
		for k2 in 2:
			var l: Label = _k.lbl(str(sp[2]) if k2 == 0 else str(sp[3]), 24, _k.c("accent") if k2 == 0 else _k.c("text"), HORIZONTAL_ALIGNMENT_CENTER)
			l.clip_text = true
			_ch_put_label(equip_grid, l, Vector2(pos.x + CH_EQ_SLOT * 0.5 - 130, pos.y + CH_EQ_SLOT + 4 + 24 * k2), Vector2(260, 26))
	UISound.connect_all_buttons(equip_grid)
	return true


## ---------------------------------------------------------------- sağ: heybe (kademe satırları)
func _ch_bag_box() -> Control:
	var box: PanelContainer = _k.box(_k.c("inset"), _k.c("line"), 14)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var v: VBoxContainer = _k.v(10)
	box.add_child(v)
	var hr: HBoxContainer = _k.h(12)
	hr.add_child(_k.glyph(DarkKit.G_BAG, _k.c("accent"), 3))
	hr.add_child(_k.lbl("HEYBE", 32, _k.c("accent")))
	hr.add_child(_k.sp(0, 0, true))
	_ch_bag_count = _k.lbl("", 24, _k.c("dim"))
	hr.add_child(_ch_bag_count)
	v.add_child(hr)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = CH_BAG_H
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(scroll)
	items_grid_box = _k.v(10)
	items_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(items_grid_box)
	return box


func _ch_build_bag() -> bool:
	if items_grid_box == null:
		return false
	var part_slots: int = int(player.get_max_item_slots()) if _ch_has_player() and player.has_method("get_max_item_slots") else 1
	var sig: String = str(part_slots) + "|"
	for entry: Dictionary in GameManager.owned_items:
		sig += str(entry.get("key", "")) + ","
	if sig == _last_items_signature:
		return false
	_last_items_signature = sig
	_ch_clear(items_grid_box)
	_ch_forget_rings("item")
	_item_slot_icons.clear()
	var total: int = 0
	for kd in [Items.KADEME_EFSANEVI, Items.KADEME_EPIK, Items.KADEME_PARCA]:
		total += Items.slot_limit(kd, part_slots)
	_ch_bag_count.text = "%d / %d yuva" % [GameManager.owned_items.size(), total]
	for kd in [Items.KADEME_EFSANEVI, Items.KADEME_EPIK, Items.KADEME_PARCA]:
		var lim: int = Items.slot_limit(kd, part_slots)
		var idx: Array = []
		for i: int in GameManager.owned_items.size():
			if Items.kademe(str((GameManager.owned_items[i] as Dictionary).get("key", ""))) == kd:
				idx.append(i)
		var tv: VBoxContainer = _k.v(6)
		var head: HBoxContainer = _k.h(8)
		head.add_child(_k.lbl(DarkKit.TIER_NAME[kd - 1], 24, DarkKit.TIER_COL[kd - 1]))
		head.add_child(_k.lbl("%d/%d" % [idx.size(), lim], 24, _k.c("dim")))
		tv.add_child(head)
		var grid := GridContainer.new()
		grid.columns = CH_COLS
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		## En az bir sıra; sınır küçükse (efsanevi 5) hepsi, büyükse sahip olunanları kapsayan sıralar.
		var shown: int = mini(lim, maxi(CH_COLS, CH_COLS * int(ceil(float(idx.size()) / float(CH_COLS)))))
		for n in maxi(shown, idx.size()):
			if n >= idx.size():
				grid.add_child(_k.empty_slot(CH_TILE))
				continue
			var i: int = idx[n]
			var key: String = str((GameManager.owned_items[i] as Dictionary).get("key", ""))
			var tile: Control = _k.tile(Items.icon(key), CH_TILE, DarkKit.TIER_COL[kd - 1])
			for ch in tile.get_children():
				if ch is TextureRect:
					_item_slot_icons[i] = ch
			grid.add_child(_ch_slot_button("item", i, CH_TILE, tile, Items.item_name(key)))
		tv.add_child(grid)
		items_grid_box.add_child(tv)
	UISound.connect_all_buttons(items_grid_box)
	return true


## ---------------------------------------------------------------- seçim + kart
func _ch_default_sel() -> Dictionary:
	if not GameManager.owned_items.is_empty():
		return {"kind": "item", "index": 0}
	if not GameManager.owned_weapons.is_empty():
		return {"kind": "weapon", "index": 0}
	return {"kind": "shield", "index": 0} if _owned_shield_type() != "" else {"kind": "pet", "index": 0}


func _ch_sel_valid() -> bool:
	var i: int = int(_ch_sel.get("index", -1))
	match str(_ch_sel.get("kind", "")):
		"item":
			return i >= 0 and i < GameManager.owned_items.size()
		"weapon":
			return i >= 0 and i < GameManager.owned_weapons.size()
		"shield":
			return _owned_shield_type() != ""
		"pet":
			return true
	return false


func _ch_select(kind: String, index: int) -> void:
	_ch_sel = {"kind": kind, "index": index}
	_ch_update_rings()
	_ch_build_detail()


func _ch_update_rings() -> void:
	for r: Array in _ch_rings:
		if is_instance_valid(r[2]):
			(r[2] as Control).visible = r[0] == _ch_sel.get("kind", "") and int(r[1]) == int(_ch_sel.get("index", -1))


func _ch_build_detail() -> void:
	if _ch_detail_box == null:
		return
	_ch_clear(_ch_detail_box)
	_ch_sell_btn = null
	_ch_sell_note = ""
	if not _ch_sel_valid():
		return
	var i: int = int(_ch_sel["index"])
	match str(_ch_sel["kind"]):
		"item":
			_ch_detail_item(str((GameManager.owned_items[i] as Dictionary).get("key", "")))
		"weapon":
			_ch_detail_weapon(i)
		"shield":
			_ch_detail_shield()
		"pet":
			_ch_detail_pet()
	UISound.connect_all_buttons(_ch_detail_box)


## Kartın iskeleti: üst satır (ikon + ad + alt satır + sağ ek), kayan gövde, alt satır (not + SAT). Gövde VBox'ını döndürür.
func _ch_card(icon: Control, title: String, sub: Control, border: Color, right: Control, note: String, sell_text: String, can_sell: bool) -> VBoxContainer:
	(_ch_detail.get_theme_stylebox("panel") as StyleBoxFlat).border_color = border
	var top: HBoxContainer = _k.h(14)
	top.add_child(icon)
	var tv: VBoxContainer = _k.v(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_child(_k.clip(title, 32, _k.c("text"), 280))
	tv.add_child(sub)
	top.add_child(tv)
	if right:
		top.add_child(right)
	_ch_detail_box.add_child(top)
	_ch_detail_box.add_child(_k.hline())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body: VBoxContainer = _k.v(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	_ch_detail_box.add_child(scroll)
	var bottom: HBoxContainer = _k.h(12)
	bottom.add_child(_k.expand(_k.wrap(note, 24, _k.c("dim"), 300)))
	if sell_text != "":
		var r: HBoxContainer = _k.h(10)
		r.add_child(_k.lbl(sell_text, 32, _k.c("accent_text") if can_sell else _k.c("dim")))
		if can_sell:
			r.add_child(_k.coin(32))
			r.add_child(_k.lbl("+%d" % _ch_sel_refund(), 32, _k.c("accent_text")))
		_ch_sell_btn = _k.row_btn(r, "primary", 60, 240)
		_ch_sell_btn.name = "SellButton"
		_ch_sell_btn.disabled = not can_sell
		_ch_sell_btn.size_flags_vertical = Control.SIZE_SHRINK_END
		_ch_sell_btn.pressed.connect(_ch_sell)
		bottom.add_child(_ch_sell_btn)
	_ch_detail_box.add_child(bottom)
	return body


func _ch_sel_refund() -> int:
	var i: int = int(_ch_sel.get("index", -1))
	match str(_ch_sel.get("kind", "")):
		"item":
			return Items.sell_refund(str((GameManager.owned_items[i] as Dictionary).get("key", "")))
		"weapon":
			return EnchantDefs.sell_refund_gold(GameManager.owned_weapons[i])
	return 0


func _ch_icon_box(c: Control, s: float, border: Color) -> PanelContainer:
	var p: PanelContainer = _k.box(_k.c("inset"), border, 0, 3, 4)
	p.custom_minimum_size = Vector2(s, s)
	p.add_child(_k.center(c))
	return p


## Eşyanın stat satırları ([simge anahtarı, metin]) - Items.describe ile aynı sıra/biçim.
func _ch_item_lines(key: String) -> Array:
	var stats: Dictionary = Items.get_def(key).get("stats", {})
	var keys: Array = []
	for s in stats:
		if Items.STAT_LABELS.has(s):
			keys.append(str(s))
	var out: Array = []
	if keys.is_empty():
		return out
	var lines: PackedStringArray = Items.describe(key).split("\n\n")[0].split("\n")
	for n in mini(keys.size(), lines.size()):
		out.append([str(CH_STAT_ICON.get(keys[n], "damage")), lines[n]])
	return out


func _ch_line(icon_id: String, text: String, col: Color) -> HBoxContainer:
	var r: HBoxContainer = _k.h(10)
	if icon_id == "heart":
		r.add_child(_k.center(_k.glyph(CH_G_HEART, CH_HEART, 3)))
	elif icon_id == "xp":
		r.add_child(_k.icon(DarkKit.tex(CH_XP_GEM), 24))
	else:
		r.add_child(_k.icon(DarkKit.tex(HudStatPanel.ICON_DIR + icon_id + ".png"), 24))
	r.add_child(_k.expand(_k.wrap(text, 24, col, 520)))
	return r


func _ch_mini_tiles(title: String, keys: Array) -> VBoxContainer:
	var v: VBoxContainer = _k.v(4)
	v.add_child(_k.lbl(title, 24, _k.c("dim")))
	var r: HBoxContainer = _k.h(6)
	for k in keys.slice(0, 5):
		var tile: Control = _k.tile(Items.icon(str(k)), 48, DarkKit.TIER_COL[Items.kademe(str(k)) - 1])
		tile.tooltip_text = Items.item_name(str(k))
		tile.mouse_filter = Control.MOUSE_FILTER_STOP
		r.add_child(tile)
	v.add_child(r)
	return v


func _ch_detail_item(key: String) -> void:
	var kd: int = Items.kademe(key)
	var tc: Color = DarkKit.TIER_COL[kd - 1]
	var sub: HBoxContainer = _k.h(14)
	sub.add_child(_k.lbl(DarkKit.TIER_NAME[kd - 1], 24, tc))
	sub.add_child(_k.amt(Items.cost(key), 24, _k.c("dim")))
	var rec: Array = Items.recipe(key)
	var refund: int = Items.sell_refund(key)
	_ch_sell_note = "+%d altın geri alırsın." % refund
	var body: VBoxContainer = _ch_card(_k.tile(Items.icon(key), 80, tc), Items.item_name(key), sub, tc.darkened(0.2),
			_ch_mini_tiles("TARİF", rec) if not rec.is_empty() else null,
			"Satış fiyatı tam fiyatın yarısı. " + _ch_sell_note, "SAT", true)
	var lines: Array = _ch_item_lines(key)
	for ln: Array in lines:
		body.add_child(_ch_line(str(ln[0]), str(ln[1]), _k.c("good")))
	var pas: String = str(Items.get_def(key).get("passive", ""))
	if pas != "":
		var pb: PanelContainer = _k.box(_k.c("inset"), _k.c("line"), 12, 2, 4)
		var pv: VBoxContainer = _k.v(4)
		pv.add_child(_k.lbl("PASİF", 24, tc))
		pv.add_child(_k.wrap(pas, 24, _k.c("text"), 540))
		pb.add_child(pv)
		body.add_child(pb)
	var up: Array = Items.builds_into(key)
	if not up.is_empty():
		body.add_child(_ch_mini_tiles("ŞUNA DÖNÜŞÜR", up))
	if not lines.is_empty() or pas != "":
		body.add_child(_k.lbl("SATARSAN", 24, _k.c("dim")))
		for ln: Array in lines:
			body.add_child(_ch_line(str(ln[0]), str(ln[1]).replace("+", "-"), _k.c("bad")))
		if pas != "":
			body.add_child(_k.wrap("Pasifi de gider.", 24, _k.c("bad"), 540))


func _ch_detail_weapon(i: int) -> void:
	var entry: Dictionary = GameManager.owned_weapons[i]
	var key: String = str(entry.get("key", ""))
	var tier: int = _ch_weapon_tier(entry)
	var tc: Color = _ch_tier_col(tier)
	var sub: HBoxContainer = _k.h(14)
	sub.add_child(_k.lbl("KADEME " + _ch_roman(entry), 24, tc))
	sub.add_child(_k.lbl(WeaponCatalogScript.category_label(key), 24, _k.c("dim")))
	var pv: VBoxContainer = _k.v(6)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	var ench: Dictionary = entry.get("enchant", {})
	var done: int = (ench.get("ups", []) as Array).size() + (1 if bool(ench.get("final", false)) else 0)
	pv.add_child(_k.lbl("USTALIK %d/5" % done, 24, _k.c("dim")))
	pv.add_child(_ch_pips(entry, 150, 10))
	var last: bool = GameManager.owned_weapons.size() <= 1
	var refund: int = EnchantDefs.sell_refund_gold(entry)
	var shards: int = EnchantDefs.sell_refund_shards(entry)
	_ch_sell_note = ("+%d altın ve +%d Silah Parçacığı geri alırsın." % [refund, shards]) if shards > 0 else ("+%d altın geri alırsın." % refund)
	var note: String = "Son silah satılamaz." if last else _ch_sell_note + " Geliştirmeler silahla gider."
	var body: VBoxContainer = _ch_card(_ch_icon_box(_k.wicon(_ch_weapon_tex(key, tier), 72, tier), 80, tc), _ch_weapon_name(key), sub,
			tc.darkened(0.15), pv, note, "SON SİLAH" if last else "SAT", not last)
	var tname: String = _ch_trait_name(entry)
	if tname != "":
		body.add_child(_k.lbl("ÖZELLİK: " + tname, 24, _k.c("accent")))
		body.add_child(_k.wrap(str(EnchantDefs.get_def(str(ench.get("id", ""))).get("desc", "")), 24, _k.c("text"), 540))
	var d: String = str(WeaponCatalogScript.DESCRIPTIONS.get(key, ""))
	if d != "":
		body.add_child(_k.wrap(d, 24, _k.c("dim"), 540))
	body.add_child(_k.wrap("Kademesini ve geliştirmelerini demirciden alırsın.", 24, _k.c("dim"), 540))


func _ch_detail_shield() -> void:
	var key: String = _owned_shield_type()
	var st: Dictionary = ShieldEnchantDefs.stats()
	var sub: HBoxContainer = _k.h(14)
	sub.add_child(_k.lbl("MANA KALKANI", 24, _k.c("accent")))
	var body: VBoxContainer = _ch_card(_ch_icon_box(_k.icon(DarkKit.tex(str(ShieldEnchantDefs.ICONS.get(key, ""))), 72), 80, HudTheme.RIM_HI),
			ShieldEnchantDefs.type_name(key), sub, HudTheme.RIM_HI, null,
			"Mana kalkanı satılmaz; türünü ve geliştirmelerini demirciden alırsın.", "", false)
	if not st.is_empty():
		body.add_child(_ch_line("shield_amount", "%d Güç" % int(st["power"]), _k.c("text")))
		body.add_child(_ch_line("shield_protection", "%%%d Soğurma" % int(round(float(st["absorption"]) * 100.0)), _k.c("text")))
		body.add_child(_ch_line("shield_regen", "%s / sn Yenilenme" % HudStatPanel._num(float(st["regen"])), _k.c("text")))
		var delay: float = float(st["delay"])
		body.add_child(_ch_line("cooldown_reduction", ("Hasardan sonra %s sn bekler" % HudStatPanel._num(delay)) if delay > 0.0 else "Hasar alınca beklemez",
				_k.c("text")))
	var desc: String = str((ShieldEnchantDefs.TYPES.get(key, {}) as Dictionary).get("desc", ""))
	if desc != "":
		body.add_child(_k.wrap(desc, 24, _k.c("dim"), 540))


func _ch_detail_pet() -> void:
	var pet: String = PetCatalog.selected()
	var sub: HBoxContainer = _k.h(14)
	sub.add_child(_k.lbl("EVCİL HAYVAN", 24, _k.c("accent")))
	var body: VBoxContainer = _ch_card(_ch_icon_box(_k.icon(PetCatalog.icon(pet), 72), 80, HudTheme.RIM_HI), PetCatalog.display_name(pet), sub,
			HudTheme.RIM_HI, null, "Evcil hayvan oyun başında seçilir.", "", false)
	body.add_child(_k.wrap(PetCatalog.description(pet), 24, _k.c("text"), 540))


func _ch_sell() -> void:
	var kind: String = str(_ch_sel.get("kind", ""))
	var i: int = int(_ch_sel.get("index", -1))
	_ch_sel = {} ## satıştan sonra yeniden kurulumda varsayılan seçime düşer
	match kind:
		"item":
			_do_sell_item(i)
		"weapon":
			_do_sell_weapon_equip(i)
	if not _ch_sel_valid():
		_ch_sel = _ch_default_sel()
		_ch_update_rings()
		_ch_build_detail()


## Satışta parçalanma kaynağı: [merkez (tuval), doku, boyut]; ikon yoksa [].
func _ch_icon_rect(tr: TextureRect) -> Array:
	if tr == null or not is_instance_valid(tr) or not tr.is_inside_tree() or tr.texture == null:
		return []
	var xf: Transform2D = tr.get_global_transform_with_canvas()
	var a: Vector2 = xf * Vector2.ZERO
	var b: Vector2 = xf * tr.size
	return [(a + b) * 0.5, tr.texture, (b - a).abs()]
