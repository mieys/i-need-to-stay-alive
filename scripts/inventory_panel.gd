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
const ITEM_TINTS := {
	"vitamin": Color(1.0, 0.55, 0.6, 1),
	"eldiven": Color(0.75, 0.75, 0.8, 1),
	"deri_cizme": Color(0.65, 0.45, 0.3, 1),
	"sigara": Color(0.55, 0.5, 0.45, 1),
	"steroid": Color(1.2, 0.5, 0.45, 1),
	"sansli_zar": Color(0.55, 1.2, 0.6, 1),
	"hasat_cantasi": Color(0.85, 0.7, 0.35, 1),
	"kalkan_yuzugu": Color(0.5, 0.75, 1.3, 1),
	"keskin_uclar": Color(0.8, 0.8, 0.85, 1),
	"kitelama_seti": Color(0.6, 0.9, 0.75, 1),
	"kaos_kitabi": Color(0.85, 0.55, 1.2, 1),
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
const SLOT_SIZE := 80.0
const SLOT_INSET := 8.0


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
var mods_grid: GridContainer = null
var items_grid_box: GridContainer = null

var _last_weapons_signature: String = ""
var _last_equip_signature: String = ""
var _last_mods_signature: String = ""

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


func _request_sell_confirmation(item_label: String, refund: int, action: Callable) -> void:
	var dialog: ConfirmationDialog = _ensure_sell_confirm_dialog()
	dialog.dialog_text = "%s eşyasını satmak istediğine emin misin?\n\n+%d Altın kazanacaksın." % [item_label, refund]
	_pending_sell_action = action
	dialog.popup_centered()


func _on_sell_confirmed() -> void:
	if _pending_sell_action.is_valid():
		_pending_sell_action.call()
	_pending_sell_action = Callable()

const EQUIP_NAMES: Dictionary = {
	"shield_standart": "Standart Kalkan",
	"shield_enerji": "Enerji Kalkanı",
	"shield_kale": "Kale Kalkanı",
	"shield_savas": "Savaş Kalkanı",
	"spray": "İtici Sprey"
}

## Kullanıcı isteği: "karakterin sadece 1 kalkan yuvası + 2 işlevsellik
## yuvası olmalı" - kalkan zaten SHIELD_TYPE_KEYS ile (dükkanda ve burada
## _owned_shield_type()) tek yuvaya sınırlı. İşlevsellik (dükkandaki eski
## "Diğer", artık "İşlevsellik" sekmesi - bkz. shop_panel.gd) tarafında şu an
## SADECE "İtici Sprey" var ama yuva sayısı ileride eklenecek başka
## işlevsellik eşyalarına yer açacak şekilde 2'ye çıkarıldı (bkz.
## MAX_UTILITY_SLOTS/_refresh_equipments).
const UTILITY_KEYS: Array = ["spray"]
const MAX_UTILITY_SLOTS: int = 2

const MOD_NAMES: Dictionary = {
	"resilience": "Meditasyon",
	"thorny": "Yansıtma",
	"turtle": "Kırılmaz İrade",
	"aggressive": "Cinnet",
	"lightning": "Çeviklik",
	"piercing": "Teknik Savaş",
	"tank": "Savunma"
}
const MODE_KEYS: Array = ["resilience", "thorny", "turtle", "aggressive", "lightning", "piercing", "tank"]
const MOD_ICON_TEXTURES: Dictionary = {
	"resilience": preload("res://assets/ui/battle_modes/resilience.png"),
	"thorny": preload("res://assets/ui/battle_modes/thorny.png"),
	"turtle": preload("res://assets/ui/battle_modes/turtle.png"),
	"aggressive": preload("res://assets/ui/battle_modes/aggressive.png"),
	"lightning": preload("res://assets/ui/battle_modes/lightning.png"),
	"piercing": preload("res://assets/ui/battle_modes/piercing.png"),
	"tank": preload("res://assets/ui/battle_modes/tank.png"),
}

var _ready_done := false

func _ready() -> void:
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

	# 3. Savaş Modları - kullanıcı isteği (2026-09-22): "Envanterde savaş modları gözüküyor onları kaldır" - bölüm artık kurulmuyor
	# (mods_grid null kalır, bkz. _refresh_mods'taki koruma). Modların kendisi (dükkan satın alımı/aktif mod) etkilenmez.

	# 4. Pasif Eşyalar
	var title_items: Label = Label.new()
	title_items.text = "PASİF EŞYALAR (Satmak için tıklayın)"
	UIKit.style_label(title_items, UIKit.FS_BODY, UIKit.C_ACCENT, 3)
	main_layout.add_child(title_items)
	
	items_grid_box = GridContainer.new()
	items_grid_box.columns = 6
	items_grid_box.add_theme_constant_override("h_separation", 8)
	items_grid_box.add_theme_constant_override("v_separation", 8)
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
	_refresh_mods()
	_refresh_items_grid()


func _refresh_weapons() -> void:
	if not main_layout or not is_instance_valid(main_layout):
		return
		
	var sig: String = ""
	for entry: Dictionary in GameManager.owned_weapons:
		sig += entry.get("key", "") + ":" + str(entry.get("level", 1)) + ","
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
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		_decorate_slot(btn)
		
		if i < GameManager.owned_weapons.size():
			var entry: Dictionary = GameManager.owned_weapons[i]
			var key: String = entry.get("key", "")
			var level: int = entry.get("level", 1)
			var spent: int = int(entry.get("spent", 0))
			var refund: int = int(round(spent * 0.7))
			
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.tooltip_text = "%s Lv%d\n\nSatmak için tıklayın (+%d Altın)" % [WEAPON_NAMES.get(key, key), level, refund]
			btn.pressed.connect(_on_sell_weapon_equip.bind(i))
			
			var icon_tex: Texture2D = WEAPON_ICON_TEXTURES.get(key)
			if icon_tex:
				var icon_tr: TextureRect = TextureRect.new()
				icon_tr.texture = icon_tex
				icon_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_tr.custom_minimum_size = Vector2(64, 64)
				icon_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon_tr.anchor_left = 0.5
				icon_tr.anchor_right = 0.5
				icon_tr.anchor_top = 0.5
				icon_tr.anchor_bottom = 0.5
				icon_tr.offset_left = -32
				icon_tr.offset_right = 32
				icon_tr.offset_top = -32
				icon_tr.offset_bottom = 32
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
		return
	var entry: Dictionary = GameManager.owned_weapons[index]
	var key: String = entry.get("key", "")
	var refund: int = int(round(int(entry.get("spent", 0)) * 0.7))
	_request_sell_confirmation(WEAPON_NAMES.get(key, key), refund, _do_sell_weapon_equip.bind(index))


func _do_sell_weapon_equip(index: int) -> void:
	if index < 0 or index >= GameManager.owned_weapons.size():
		return
	if GameManager.owned_weapons.size() <= 1:
		return

	var entry: Dictionary = GameManager.owned_weapons[index]
	var refund: int = int(round(int(entry.get("spent", 0)) * 0.7))

	if player and is_instance_valid(player) and player.has_method("remove_owned_weapon"):
		player.remove_owned_weapon(index)

	GameManager.owned_weapons.remove_at(index)
	GameManager.gold += refund
	_last_weapons_signature = ""
	_refresh()


func _owned_shield_type() -> String:
	for key: String in ["shield_standart", "shield_enerji", "shield_kale", "shield_savas"]:
		if int(GameManager.get(key + "_level")) > 0:
			return key
	return ""


func _get_upgrade_cost(item: String, next_level: int) -> int:
	match item:
		"shield_standart", "shield_enerji", "shield_kale", "shield_savas":
			return 3 * next_level * next_level
		"spray":
			return 15 * next_level * next_level
	return next_level


func _get_shield_modulate(key: String) -> Color:
	match key:
		"shield_enerji": return Color(0.6, 0.95, 1.4, 1)
		"shield_kale": return Color(1.3, 0.6, 0.7, 1)
		"shield_savas": return Color(1.2, 0.9, 0.4, 1)
		_: return Color(1, 1, 1, 1)


func _refresh_equipments() -> void:
	if not main_layout or not is_instance_valid(main_layout):
		return
		
	var shield_key: String = _owned_shield_type()
	var shield_lvl: int = int(GameManager.get(shield_key + "_level")) if shield_key != "" else 0
	var sig: String = shield_key + ":" + str(shield_lvl)
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
	shield_btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_decorate_slot(shield_btn)
	
	if shield_key != "":
		var level: int = int(GameManager.get(shield_key + "_level"))
		var total_spent: int = 0
		for l: int in range(1, level + 1):
			total_spent += _get_upgrade_cost(shield_key, l)
		var refund: int = int(round(total_spent * 0.7))
		
		shield_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		shield_btn.tooltip_text = "%s Lv%d\n\nSatmak için tıklayın (+%d Altın)" % [EQUIP_NAMES.get(shield_key, shield_key), level, refund]
		shield_btn.pressed.connect(_on_sell_shield_equip)
		
		var icon: Control = Control.new()
		icon.set_script(load("res://scripts/shop_item_icon.gd"))
		icon.item_type = "shield"
		icon.shield_type = shield_key ## yeni tür ikonları (assets/ui/shields) kendi renginde - eski tint modülasyonu kaldırıldı
		icon.custom_minimum_size = Vector2(64, 64)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.anchor_left = 0.5
		icon.anchor_right = 0.5
		icon.anchor_top = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_left = -32
		icon.offset_right = 32
		icon.offset_top = -32
		icon.offset_bottom = 32
		shield_btn.add_child(icon)
		
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
		shield_btn.add_child(lvl_lbl)
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
		util_btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
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
			icon.custom_minimum_size = Vector2(64, 64)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.anchor_left = 0.5
			icon.anchor_right = 0.5
			icon.anchor_top = 0.5
			icon.anchor_bottom = 0.5
			icon.offset_left = -32
			icon.offset_right = 32
			icon.offset_top = -32
			icon.offset_bottom = 32
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


func _on_sell_shield_equip() -> void:
	var owned: String = _owned_shield_type()
	if owned == "":
		return
	var level: int = int(GameManager.get(owned + "_level"))
	var total_spent: int = 0
	for l: int in range(1, level + 1):
		total_spent += _get_upgrade_cost(owned, l)
	var refund: int = int(round(total_spent * 0.7))
	_request_sell_confirmation(EQUIP_NAMES.get(owned, owned), refund, _do_sell_shield_equip)


func _do_sell_shield_equip() -> void:
	var owned: String = _owned_shield_type()
	if owned == "":
		return
	var level: int = int(GameManager.get(owned + "_level"))
	var total_spent: int = 0
	for l: int in range(1, level + 1):
		total_spent += _get_upgrade_cost(owned, l)
	var refund: int = int(round(total_spent * 0.7))

	GameManager.set(owned + "_level", 0)
	GameManager.gold += refund

	if player and is_instance_valid(player) and player.has_method("refresh_shield_stats"):
		player.refresh_shield_stats()

	_last_equip_signature = ""
	_refresh()


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
	_request_sell_confirmation(EQUIP_NAMES.get(key, key), refund, _do_sell_utility_equip.bind(key))


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


func _refresh_mods() -> void:
	if not main_layout or not is_instance_valid(main_layout) or mods_grid == null:
		return
		
	var sig: String = ""
	for mode: String in MODE_KEYS:
		sig += mode + ":" + str(int(GameManager.get("shield_mod_" + mode + "_level"))) + ","
	if sig == _last_mods_signature:
		return
	_last_mods_signature = sig
		
	for child: Node in mods_grid.get_children():
		child.queue_free()
		
	var slot_tex: Texture2D = load("res://assets/ui/shop_redesign/item_slot.png") as Texture2D
	var style_box: StyleBoxTexture = StyleBoxTexture.new()
	style_box.texture = slot_tex
	style_box.texture_margin_left = 5.0
	style_box.texture_margin_top = 5.0
	style_box.texture_margin_right = 5.0
	style_box.texture_margin_bottom = 5.0
	
	for mode: String in MODE_KEYS:
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		_decorate_slot(btn)
		
		btn.set_script(preload("res://scripts/inventory_mod_drag_source.gd"))
		btn.setup(mode, MOD_ICON_TEXTURES[mode] as Texture2D)
		
		var level: int = int(GameManager.get("shield_mod_" + mode + "_level"))
		if level > 0:
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.tooltip_text = "%s Lv%d\n\nSürükleyip alttaki kısayol slotlarına (1-4) yerleştirin." % [MOD_NAMES.get(mode, mode), level]
			
			var icon_tr: TextureRect = TextureRect.new()
			icon_tr.texture = MOD_ICON_TEXTURES[mode] as Texture2D
			icon_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_tr.custom_minimum_size = Vector2(64, 64)
			icon_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_tr.anchor_left = 0.5
			icon_tr.anchor_right = 0.5
			icon_tr.anchor_top = 0.5
			icon_tr.anchor_bottom = 0.5
			icon_tr.offset_left = -32
			icon_tr.offset_right = 32
			icon_tr.offset_top = -32
			icon_tr.offset_bottom = 32
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
			btn.tooltip_text = "%s (Kilitli - Dükkandan satın alın)" % MOD_NAMES.get(mode, mode)
			var icon_tr: TextureRect = TextureRect.new()
			icon_tr.texture = MOD_ICON_TEXTURES[mode] as Texture2D
			icon_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_tr.custom_minimum_size = Vector2(64, 64)
			icon_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_tr.modulate = Color(1.0, 1.0, 1.0, 0.25)
			icon_tr.anchor_left = 0.5
			icon_tr.anchor_right = 0.5
			icon_tr.anchor_top = 0.5
			icon_tr.anchor_bottom = 0.5
			icon_tr.offset_left = -32
			icon_tr.offset_right = 32
			icon_tr.offset_top = -32
			icon_tr.offset_bottom = 32
			btn.add_child(icon_tr)
			
		mods_grid.add_child(btn)


func _refresh_items_grid() -> void:
	var sig: String = ""
	for entry: Dictionary in GameManager.owned_items:
		sig += str(entry.get("key", "")) + ","
	if sig == _last_items_signature:
		return
	_last_items_signature = sig

	for child: Node in items_grid_box.get_children():
		child.queue_free()

	var slot_tex: Texture2D = load("res://assets/ui/shop_redesign/item_slot.png") as Texture2D
	var style_box: StyleBoxTexture = StyleBoxTexture.new()
	style_box.texture = slot_tex
	style_box.texture_margin_left = 5.0
	style_box.texture_margin_top = 5.0
	style_box.texture_margin_right = 5.0
	style_box.texture_margin_bottom = 5.0

	var style_hover: StyleBoxTexture = StyleBoxTexture.new()
	style_hover.texture = slot_tex
	style_hover.texture_margin_left = 5.0
	style_hover.texture_margin_top = 5.0
	style_hover.texture_margin_right = 5.0
	style_hover.texture_margin_bottom = 5.0
	style_hover.modulate_color = Color(1.22, 1.22, 1.22, 1)

	var style_pressed: StyleBoxTexture = StyleBoxTexture.new()
	style_pressed.texture = slot_tex
	style_pressed.texture_margin_left = 5.0
	style_pressed.texture_margin_top = 5.0
	style_pressed.texture_margin_right = 5.0
	style_pressed.texture_margin_bottom = 5.0
	style_pressed.modulate_color = Color(0.8, 0.8, 0.8, 1)

	for i: int in range(GameManager.owned_items.size()):
		var entry: Dictionary = GameManager.owned_items[i]
		var key: String = entry.get("key", "")
		var def: Dictionary = Items.get_def(key)
		var refund: int = int(round(int(entry.get("spent", 0)) * 0.7))

		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		_decorate_slot(btn)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.tooltip_text = "%s\n%s\n\nSatmak için tıkla (+%d altın)" % [def.get("name", key), def.get("desc", ""), refund]
		btn.pressed.connect(_on_sell_item.bind(i))

		var icon: Control = Control.new()
		icon.set_script(load("res://scripts/shop_item_icon.gd"))
		icon.item_type = "trinket"
		if "item_key" in icon:
			icon.item_key = key
		icon.modulate = Color(1, 1, 1, 1)
		icon.custom_minimum_size = Vector2(64, 64)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.anchor_left = 0.5
		icon.anchor_right = 0.5
		icon.anchor_top = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_left = -32
		icon.offset_right = 32
		icon.offset_top = -32
		icon.offset_bottom = 32
		btn.add_child(icon)

		items_grid_box.add_child(btn)


func _on_sell_item(index: int) -> void:
	if index < 0 or index >= GameManager.owned_items.size():
		return
	var entry: Dictionary = GameManager.owned_items[index]
	var key: String = entry.get("key", "")
	var def: Dictionary = Items.get_def(key)
	var refund: int = int(round(int(entry.get("spent", 0)) * 0.7))
	_request_sell_confirmation(def.get("name", key), refund, _do_sell_item.bind(index))


func _do_sell_item(index: int) -> void:
	if index < 0 or index >= GameManager.owned_items.size():
		return
	var entry: Dictionary = GameManager.owned_items[index]
	var refund: int = int(round(int(entry.get("spent", 0)) * 0.7))

	if player and is_instance_valid(player) and player.has_method("remove_owned_item"):
		player.remove_owned_item(index)

	GameManager.owned_items.remove_at(index)
	GameManager.gold += refund

	_last_items_signature = ""
	_refresh()
