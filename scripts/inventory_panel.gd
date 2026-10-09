extends Control

## Yeni "Envanter" paneli: sahip olunan silahları küçük ikonlarla (üst sıra,
## en fazla 5 - bkz. GameManager.owned_weapons/player.gd MAX_OWNED_WEAPONS)
## ve altın/tecrübe miktarını gösterir. HUD'daki tek bir "ENVANTER" butonu
## bu paneli VE stats_panel.tscn'i (istatistikler) birlikte açıp kapatıyor
## (bkz. hud.gd _on_envanter_toggle) - referans görselde ikisi yan yana
## gösterildiği için.

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
}
const WEAPON_NAMES := {
	"dagger": "Bıçak", "fire_staff": "Ateş Asası", "lightning_staff": "Yıldırım Asası", "tabanca": "Tabanca",
	"tuftuf": "Tüftüf", "tufek": "Tüfek", "arcane": "Arcane Asası", "yay": "Yay",
	"crossbow": "Arbalet", "boomerang": "Bumerang", "buz_asasi": "Buz Asası", "fisek": "Fişek",
	"pence": "Pençe", "topuz": "Topuz", "uzunkilic": "Uzunkılıç",
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


## Kısa, tek seferlik bir ease-out büyüme+belirme - zıplama/elastik yok,
## göz yormasın diye hızlı (bkz. OPEN_ANIM_DURATION).
func _play_open_animation() -> void:
	if _open_tween and _open_tween.is_valid():
		_open_tween.kill()
	modulate.a = 0.0
	scale = Vector2(OPEN_ANIM_START_SCALE, OPEN_ANIM_START_SCALE)
	_open_tween = create_tween()
	_open_tween.set_parallel(true)
	_open_tween.set_ease(Tween.EASE_OUT)
	_open_tween.set_trans(Tween.TRANS_CUBIC)
	_open_tween.tween_property(self, "modulate:a", 1.0, OPEN_ANIM_DURATION)
	_open_tween.tween_property(self, "scale", Vector2.ONE, OPEN_ANIM_DURATION)


var main_layout: VBoxContainer = null
var weapons_grid: HBoxContainer = null
var equip_grid: HBoxContainer = null
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
## kullanıcı "Evet" dediğinde çalışıyor.
var _sell_confirm_dialog: ConfirmationDialog = null
var _pending_sell_action: Callable = Callable()


func _ensure_sell_confirm_dialog() -> ConfirmationDialog:
	if _sell_confirm_dialog and is_instance_valid(_sell_confirm_dialog):
		return _sell_confirm_dialog
	_sell_confirm_dialog = ConfirmationDialog.new()
	_sell_confirm_dialog.title = "Satışı Onayla"
	_sell_confirm_dialog.ok_button_text = "Sat"
	_sell_confirm_dialog.cancel_button_text = "Vazgeç"
	_sell_confirm_dialog.confirmed.connect(_on_sell_confirmed)
	add_child(_sell_confirm_dialog)
	return _sell_confirm_dialog


func _request_sell_confirmation(item_label: String, refund: int, action: Callable, desc: String = "", shard_refund: int = 0) -> void:
	if _mobile:
		## Telefon: onay penceresi yerine alttaki bilgi şeridi (ad + açıklama + büyük SAT) - dokunmak önce bilgiyi gösterir.
		if shard_refund > 0:
			desc += "\n+%d Silah Parçacığı geri alırsın." % shard_refund
		_show_detail(item_label, desc, refund, action)
		return
	var dialog: ConfirmationDialog = _ensure_sell_confirm_dialog()
	dialog.dialog_text = "%s eşyasını satmak istediğine emin misin?\n\n+%d Altın kazanacaksın." % [item_label, refund]
	if shard_refund > 0:
		dialog.dialog_text += "\n+%d Silah Parçacığı geri alacaksın." % shard_refund
	_pending_sell_action = action
	dialog.popup_centered()


func _on_sell_confirmed() -> void:
	if _pending_sell_action.is_valid():
		_pending_sell_action.call()
	_pending_sell_action = Callable()

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
	gold_label.text = str(GameManager.gold)
	if player and is_instance_valid(player):
		xp_label.text = str(int(player.xp))
	else:
		xp_label.text = "0"
	_refresh_weapons()
	_refresh_equipments()
	_refresh_items_grid()


func _refresh_weapons() -> void:
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
	
	for i: int in range(5):
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

	if player and is_instance_valid(player) and player.has_method("remove_owned_weapon"):
		player.remove_owned_weapon(index)

	GameManager.owned_weapons.remove_at(index)
	GameManager.gold += refund
	GameManager.add_weapon_shards(shard_refund)
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
		shield_btn.tooltip_text = "Kalkan Yuvası (Boş)"
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
		UIKit.style_label(head, 40 if _mobile else 24, TierSystem.COLORS[kd - 1], 0)
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
	var key: String = str((GameManager.owned_items[index] as Dictionary).get("key", ""))
	_request_sell_confirmation(Items.item_name(key), Items.sell_refund(key), _do_sell_item.bind(index),
			Items.KADEME_NAMES[Items.kademe(key) - 1] + "  ·  " + Items.describe(key))


## Satış iadesi eşyanın TAM fiyatının %70'i (tarifle ucuza alınmış olsa da - parçaları tek tek satmakla aynı değer).
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
	var row: Array = [[frame.get_node("GoldIcon"), 0.0], [gold_label, 52.0], [frame.get_node("XPIcon"), 240.0], [xp_label, 292.0]]
	for r in row:
		var c: Control = r[0] as Control
		var is_icon: bool = not (c is Label)
		c.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		c.offset_left = -600.0 + float(r[1])
		c.offset_right = c.offset_left + (44.0 if is_icon else 180.0)
		c.offset_top = 48.0 if is_icon else 34.0
		c.offset_bottom = 92.0 if is_icon else 106.0
	## Yuva alanı.
	var scroll: ScrollContainer = main_layout.get_parent() as ScrollContainer
	if scroll:
		scroll.offset_top = 136.0
		scroll.offset_bottom = -292.0
	for c in main_layout.get_children():
		if c is Label:
			var l := c as Label
			l.text = l.text.replace("(Satmak için tıklayın)", "").strip_edges()
			l.add_theme_font_size_override("font_size", 40)
	weapons_grid.add_theme_constant_override("separation", 12)
	equip_grid.add_theme_constant_override("separation", 12)
	## Bilgi şeridi.
	var strip := Panel.new()
	strip.name = "MobileDetail"
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_left = 28.0
	strip.offset_right = -28.0
	strip.offset_top = -276.0
	strip.offset_bottom = -28.0
	strip.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))
	frame.add_child(strip)
	_detail_name = Label.new()
	UIKit.style_label(_detail_name, 48, UIKit.C_TEXT, 0)
	_detail_name.position = Vector2(28.0, 16.0)
	_detail_name.size = Vector2(rect.size.x - 460.0, 60.0)
	_detail_name.clip_text = true
	strip.add_child(_detail_name)
	_detail_desc = Label.new()
	UIKit.style_label(_detail_desc, 40, UIKit.C_TEXT_DIM, 0)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.position = Vector2(28.0, 84.0)
	_detail_desc.size = Vector2(rect.size.x - 460.0, 140.0)
	_detail_desc.clip_text = true
	strip.add_child(_detail_desc)
	_detail_sell = Button.new()
	UIKit.style_button(_detail_sell, "red", false, 40)
	_detail_sell.position = Vector2(rect.size.x - 56.0 - 360.0, 56.0)
	_detail_sell.size = Vector2(340.0, 136.0)
	_detail_sell.pressed.connect(_on_detail_sell)
	strip.add_child(_detail_sell)
	UISound.connect_all_buttons(strip)
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
	_detail_name.add_theme_color_override("font_color", UIKit.C_TEXT)
	_detail_desc.text = desc
	_detail_action = action
	_detail_sell.visible = action.is_valid()
	_detail_sell.text = "SAT  +%d" % refund


func _clear_detail() -> void:
	if _detail_name == null:
		return
	_detail_name.text = "Bir eşyaya dokun"
	_detail_name.add_theme_color_override("font_color", UIKit.C_TEXT_DIM)
	_detail_desc.text = "Ne işe yaradığı ve satış fiyatı burada görünür."
	_detail_action = Callable()
	_detail_sell.visible = false


func _on_detail_sell() -> void:
	if _detail_action.is_valid():
		_detail_action.call()
	_clear_detail()