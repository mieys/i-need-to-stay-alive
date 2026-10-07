extends CanvasLayer

## SİLAH SATICISI (demirci) ekranı - kullanıcı isteği (2026-10-07): "silah satıcısı ekranı için yeni bir arayüz tasarlaman gerekiyor.
## içinde tüm silahlar görünebilir ve alınabilir sınırlar dahilinde" + silahlar ve kalkanlar (kalkan geliştirmeleri dahil) burada
## satılır. Kurallar/fiyatlar weapon_shop_logic.gd'de (TEK kaynak); bu dosya sadece GÖSTERİR ve çağırır. Örs etkileşimi ve iç
## mekan: weapon_shop.gd.
##
## DÜZEN (1920x1080 tabanı, merchant_shop_screen.gd ile aynı UIKit/bej-ahşap dili): solda seçili ürünün ayrıntısı, ortada iki
## sekme (SİLAHLAR / KALKANLAR), sağda envanter (5 silah yuvası + kalkan özeti). 15 silahın HEPSİ tek bakışta: iki sütun x 8 satır
## yatay "plaka" (ikon | ad + tür | fiyat | AL) - dikey kart ızgarası 15 silahı ekrana sığdırmıyordu. Kalkanlar sekmesi: üstte 3 tür
## (tek seferlik, kalıcı), altında seçilen türün geliştirmeleri. Plakaya tıkla = ayrıntı, AL = satın al; kumandada D-pad bir plakaya
## gelince seçilir, A satın alır (merchant_shop_screen.gd ile aynı desen).
##
## BİLİNÇLİ OLARAK get_tree().paused YOK (seyyar satıcıyla aynı: kişisel/asenkron bir alışveriş, iç mekan zaten güvenli).

signal closed

const Logic := preload("res://scripts/weapon_shop_logic.gd")
const WeaponCatalogScript := preload("res://scripts/weapon_catalog.gd")
const EventSfx := preload("res://scripts/event_sfx.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const ReadingUiWatcher := preload("res://scripts/reading_ui_watcher.gd")

const WINDOW_SCALE := 1.0
const PHONE_K := 1.5
const ROW_MIN_WIDTH := 456.0
const ROW_ICON := 64.0
## bkz. merchant_shop_screen.gd DESC_SCROLLBAR_RESERVE (donma + çökme düzeltmesi): açıklama kutusunun en az genişliği çubuk
## görünsün/görünmesin sabit kalsın - yoksa genişlik <-> yükseklik yerleşim döngüsü kurulabilir.
const DESC_SCROLLBAR_RESERVE := 28.0
const FS_SMALL := 24

enum Tab { WEAPONS, SHIELDS, ENCHANTS }

var _player: Node = null
var _tab: int = Tab.WEAPONS
var _selected: Dictionary = {} ## {"type": "weapon"|"shield"|"upgrade"|"wupgrade", "key": String, "index": int, "slot": int, "final": bool}
var _trait_slot: int = 0 ## EFSUNLAR sekmesinde seçili silah kopyası (owned_weapons dizini)
var _rows: Array = [] ## [{entry, panel, price, sub, buy}]
var _phone: bool = false
var _stats_timer: float = 0.0
var _last_sig: int = 0

var _gold_label: Label = null
var _shard_label: Label = null ## üst çubuktaki silah parçacığı sayacı
var _details_shard: Label
const SHARD_ICON_PATH := "res://assets/pickups/weapon_shard/shard_icon.png"
const SHARD_COLOR := Color(0.62, 0.78, 1.0)
var _tab_buttons: Array = []
var _status_label: Label = null
var _center_holder: VBoxContainer = null
var _phone_scroll: ScrollContainer = null
var _details_name: Label
var _details_kind: Label
var _details_icon_holder: Control
var _details_icon_frame: TextureRect
var _details_icon_inset: Control
var _details_desc: Label
var _details_price: Label
var _details_block: Label
var _inventory_body: VBoxContainer = null


## Seyyar satıcıdaki gibi: ekran açıkken karakter okuma (read) pozuna geçer - bkz. ReadingUiWatcher.
func _enter_tree() -> void:
	add_to_group(ReadingUiWatcher.GROUP)


func setup(player: Node) -> void:
	_player = player
	EventSfx.play(get_tree(), &"shop_open")
	layer = 80
	_build_ui()
	## bkz. merchant_shop_screen.gd setup: oyunu duraklatmayan ekranlarda ESC aynı basışla duraklatma menüsünü de açmasın.
	GameManager.register_blocking_panel(self)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	## bkz. merchant_shop_screen.gd _process: başka bir modal (level atlama/sandık) oyunu duraklatınca ekran gizlenir.
	var paused_by_other: bool = get_tree().paused
	if visible == paused_by_other:
		visible = not paused_by_other
	if paused_by_other:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_on_close_pressed()
		return
	_stats_timer -= delta
	if _stats_timer <= 0.0:
		_stats_timer = 0.25
		## Altın/envanter başka yoldan da değişebilir (sandık payı, görev ödülü, dışarıdan gelen eşya...) - sadece durum
		## değiştiyse yenile (envanter paneli her seferinde yeniden kurulduğu için ucuz imza kontrolü).
		if _state_sig() != _last_sig:
			_refresh_all()


# ------------------------------------------------------------------ iskelet

func _phone_rect() -> Rect2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var safe: Rect2 = MobileUIScript.safe_margins(get_viewport())
	return Rect2(safe.position / PHONE_K, (view - safe.position - safe.size) / PHONE_K)


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
		center.theme = UIKit.theme()
		add_child(center)
		center.add_child(window)
		_apply_window_scale(window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	window.add_child(vbox)
	vbox.add_child(_build_title_bar())
	vbox.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	vbox.add_child(body)
	var details_panel: Control = _build_details_panel()
	body.add_child(details_panel)
	var middle: Control = _build_middle()
	var inventory_panel: Control = _build_inventory_panel()
	if _phone:
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_phone_scroll = ScrollContainer.new()
		_phone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_phone_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_phone_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_phone_scroll.follow_focus = true
		middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_phone_scroll.add_child(middle)
		body.add_child(_phone_scroll)
		details_panel.custom_minimum_size.x = 240.0
		inventory_panel.custom_minimum_size.x = 250.0
		_details_desc.custom_minimum_size.x = 0.0
	else:
		body.add_child(middle)
	body.add_child(inventory_panel)

	UISound.connect_all_buttons(self)
	_show_tab(Tab.WEAPONS)


## bkz. merchant_shop_screen.gd _apply_window_scale: Container çocuğun ölçeğini her yerleşimde sıfırladığı için ölçek ve
## konum yerleşim BİTTİKTEN sonra (sort_children) verilir; pencere ekrana sığmıyorsa küçülür.
func _apply_window_scale(window: Control) -> void:
	var fit_scale := func() -> void:
		if not is_instance_valid(window):
			return
		window.pivot_offset = window.size * 0.5
		var view: Vector2 = window.get_viewport_rect().size
		var fit: float = minf(view.x * 0.97 / maxf(1.0, window.size.x), view.y * 0.97 / maxf(1.0, window.size.y))
		window.scale = Vector2.ONE * minf(WINDOW_SCALE, fit)
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


func _build_title_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	var plaque := PanelContainer.new()
	plaque.add_theme_stylebox_override("panel", UIKit.panel_style("plaque"))
	var title := Label.new()
	title.text = "DEMİRCİ"
	UIKit.style_label(title, UIKit.FS_TITLE, UIKit.C_TEXT, 4)
	plaque.add_child(title)
	bar.add_child(plaque)

	var sub := Label.new()
	sub.text = "Silahlar ve kalkanlar"
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.style_label(sub, UIKit.FS_BODY, UIKit.C_TEXT_DIM, 2)
	if not _phone:
		bar.add_child(sub)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var gold_box := PanelContainer.new()
	gold_box.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))
	_gold_label = Label.new()
	UIKit.style_label(_gold_label, UIKit.FS_BODY, UIKit.C_GOLD, 3)
	_gold_label.custom_minimum_size = Vector2(150.0 if _phone else 220.0, 0)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_box.add_child(_gold_label)
	bar.add_child(gold_box)

	## Silah parçacığı sayacı (silah almak parçacık ister, bkz. weapon_shop_logic.gd): altın kutusunun yanında ikon + sayı.
	var shard_box := PanelContainer.new()
	shard_box.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))
	var shard_h := HBoxContainer.new()
	shard_h.add_theme_constant_override("separation", 6)
	shard_box.add_child(shard_h)
	shard_h.add_child(_shard_icon(44.0))
	_shard_label = Label.new()
	UIKit.style_label(_shard_label, UIKit.FS_BODY, SHARD_COLOR, 3)
	_shard_label.custom_minimum_size = Vector2(56.0 if _phone else 72.0, 0)
	_shard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shard_h.add_child(_shard_label)
	bar.add_child(shard_box)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(64, 64)
	UIKit.style_button(close_btn, "red", true, UIKit.FS_BODY)
	close_btn.pressed.connect(_on_close_pressed)
	bar.add_child(close_btn)
	return bar


## Silah parçacığı simgesi (22 px sanat; size 22'nin tam katı olmalı ki bulanıklaşmasın).
func _shard_icon(size_px: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(SHARD_ICON_PATH) as Texture2D
	icon.custom_minimum_size = Vector2(size_px, size_px)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


# ------------------------------------------------------------------ orta: sekmeler + plakalar

func _build_middle() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	col.add_child(tabs)
	for i in range(3):
		var b := Button.new()
		b.text = ["SİLAHLAR", "KALKANLAR", "EFSUNLAR"][i]
		b.custom_minimum_size = Vector2(220, 56)
		b.pressed.connect(_show_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	_status_label = Label.new()
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.clip_text = true
	UIKit.style_label(_status_label, UIKit.FS_BODY, UIKit.C_TEXT_DIM, 2)
	tabs.add_child(_status_label)
	_center_holder = VBoxContainer.new()
	_center_holder.add_theme_constant_override("separation", 8)
	col.add_child(_center_holder)
	## İki sekmede de aynı genişlik (silah sekmesi iki sütun) - sekme değişince pencere boyu/ortası oynamasın.
	if not _phone:
		col.custom_minimum_size.x = ROW_MIN_WIDTH * 2.0 + 12.0
	return col


func _show_tab(tab: int) -> void:
	_tab = tab
	for i in range(_tab_buttons.size()):
		UIKit.style_button(_tab_buttons[i], "green" if i == tab else "wood", false, UIKit.FS_BODY)
	for c in _center_holder.get_children():
		_center_holder.remove_child(c)
		c.queue_free()
	_rows.clear()
	if tab == Tab.WEAPONS:
		_build_weapon_rows()
	elif tab == Tab.SHIELDS:
		_build_shield_rows()
	else:
		_build_trait_rows()
	UISound.connect_all_buttons(self)
	## Kumanda: sekme açılınca ilk odak ilk plakada (gamepad_ui.gd FIRST_FOCUS_GROUP).
	for r in _rows:
		(r["panel"] as Node).remove_from_group(&"gamepad_first_focus")
	if not _rows.is_empty():
		(_rows[0]["panel"] as Node).add_to_group(&"gamepad_first_focus")
		_select(_rows[0]["entry"])
	_refresh_all()


func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	UIKit.style_label(l, UIKit.FS_BODY, UIKit.C_ACCENT, 2)
	return l


func _build_weapon_rows() -> void:
	var grid := GridContainer.new()
	grid.columns = 1 if _phone else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	## İki sütunda sütun-sütun sıra: sol sütun ilk 8, sağ sütun kalan 7 (GridContainer satır satır doldurur -> sırayı kendimiz kurarız).
	var keys: Array = Logic.weapon_keys()
	var per_col: int = int(ceil(float(keys.size()) / float(grid.columns)))
	var ordered: Array = []
	for r in range(per_col):
		for c in range(grid.columns):
			var idx: int = c * per_col + r
			if idx < keys.size():
				ordered.append(keys[idx])
	for key in ordered:
		var entry := {"type": "weapon", "key": str(key)}
		var row: Dictionary = _build_row(entry)
		(row["panel"] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(row["panel"])
		_rows.append(row)
	_center_holder.add_child(grid)


func _build_shield_rows() -> void:
	_center_holder.add_child(_section_title("KALKAN TÜRLERİ"))
	for key in Logic.shield_keys():
		var row: Dictionary = _build_row({"type": "shield", "key": str(key)})
		(row["panel"] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_center_holder.add_child(row["panel"])
		_rows.append(row)
	_center_holder.add_child(_section_title("GELİŞTİRMELER"))
	var lines: Array = Logic.upgrade_lines()
	if lines.is_empty():
		var hint := Label.new()
		hint.text = "Geliştirmeler, bir kalkan türü aldıktan sonra burada satılır."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(ROW_MIN_WIDTH, 0)
		UIKit.style_label(hint, UIKit.FS_BODY, UIKit.C_TEXT_DIM, 2)
		_center_holder.add_child(hint)
		return
	for i in range(lines.size()):
		var row2: Dictionary = _build_row({"type": "upgrade", "key": GameManager.shield_enchant, "index": i})
		(row2["panel"] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_center_holder.add_child(row2["panel"])
		_rows.append(row2)


## EFSUNLAR sekmesi (kalıcı silah özellikleri): üstte sahip olunan silah kopyaları (seçici), altında seçilenin özelliği ve
## 4 geliştirme + final plakaları. Kopyalar bağımsız: aynı silahtan iki tane varsa her birinin geliştirmesi ayrı.
func _build_trait_rows() -> void:
	var count: int = GameManager.owned_weapons.size()
	if count == 0:
		var none := Label.new()
		none.text = "Önce bir silah al: her silah kendi efsunuyla gelir, geliştirmeleri burada satılır."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(ROW_MIN_WIDTH, 0)
		UIKit.style_label(none, UIKit.FS_BODY, UIKit.C_TEXT_DIM, 2)
		_center_holder.add_child(none)
		return
	_trait_slot = clampi(_trait_slot, 0, count - 1)
	_center_holder.add_child(_section_title("SİLAHLARIN"))
	var picker := HFlowContainer.new()
	picker.add_theme_constant_override("h_separation", 8)
	picker.add_theme_constant_override("v_separation", 8)
	for i in range(count):
		var key: String = str((GameManager.owned_weapons[i] as Dictionary).get("key", ""))
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(76, 76)
		holder.mouse_filter = Control.MOUSE_FILTER_STOP
		holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var inset: Control = _build_icon_slot(holder, 8.0)
		_add_icon(inset, {"type": "weapon", "key": key})
		if i != _trait_slot:
			holder.modulate = Color(1, 1, 1, 0.55)
		holder.gui_input.connect(_on_trait_slot_input.bind(i))
		holder.tooltip_text = str(WeaponCatalogScript.NAMES.get(key, key))
		picker.add_child(holder)
	_center_holder.add_child(picker)
	var wkey: String = str((GameManager.owned_weapons[_trait_slot] as Dictionary).get("key", ""))
	var def: Dictionary = EnchantDefs.get_def(Logic.slot_trait_id(_trait_slot))
	var head := Label.new()
	head.text = "%s: %s" % [str(WeaponCatalogScript.NAMES.get(wkey, wkey)), str(def.get("name", "-"))]
	UIKit.style_label(head, UIKit.FS_BODY, UIKit.C_ACCENT, 2)
	_center_holder.add_child(head)
	var blurb := Label.new()
	blurb.text = str(def.get("desc", ""))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(ROW_MIN_WIDTH, 0)
	UIKit.style_label(blurb, UIKit.FS_BODY, UIKit.C_TEXT_DIM, 2)
	_center_holder.add_child(blurb)
	_center_holder.add_child(_section_title("GELİŞTİRMELER"))
	for r in Logic.slot_upgrade_rows(_trait_slot):
		var entry := {"type": "wupgrade", "key": wkey, "slot": _trait_slot, "index": int(r["index"]), "final": bool(r["final"])}
		var row: Dictionary = _build_row(entry)
		(row["panel"] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_center_holder.add_child(row["panel"])
		_rows.append(row)


func _on_trait_slot_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and slot != _trait_slot:
		_trait_slot = slot
		_selected = {}
		_show_tab(Tab.ENCHANTS)


## Yatay plaka: [ikon] [ad + alt yazı] [fiyat] [AL]. Satır yüksekliği için içerik payı kitin kart payından (14) küçük (8).
func _build_row(entry: Dictionary) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ROW_MIN_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_theme_stylebox_override("panel", _row_style("card"))
	panel.gui_input.connect(_on_row_gui_input.bind(entry))
	## Kumanda (bkz. merchant_shop_screen.gd _build_card): PanelContainer Button değil, odak halkasını elle çiz; D-pad bir plakaya
	## gelince seçilir, A (ui_accept) satın alır.
	panel.focus_mode = Control.FOCUS_ALL
	GamepadFocusHelper.add_focus_ring(panel)
	panel.focus_entered.connect(_select.bind(entry))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)

	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(ROW_ICON, ROW_ICON)
	icon_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset: Control = _build_icon_slot(icon_holder, 6.0)
	_add_icon(inset, entry)
	h.add_child(icon_holder)

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Label.new()
	name_label.text = _entry_name(entry)
	name_label.clip_text = true
	UIKit.style_label(name_label, UIKit.FS_BODY, UIKit.C_TEXT, 3)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(name_label)
	var sub_label := Label.new()
	sub_label.clip_text = true
	UIKit.style_label(sub_label, FS_SMALL, UIKit.C_TEXT_DIM, 0)
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(sub_label)
	h.add_child(texts)

	## Fiyat sütunu: üstte altın, altında (varsa) parçacık maliyeti (ikon + sayı).
	var price_col := VBoxContainer.new()
	price_col.add_theme_constant_override("separation", 0)
	price_col.custom_minimum_size = Vector2(118, 0)
	price_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var price_label := Label.new()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.style_label(price_label, UIKit.FS_BODY, UIKit.C_GOLD, 3)
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_col.add_child(price_label)
	var shard_row := HBoxContainer.new()
	shard_row.alignment = BoxContainer.ALIGNMENT_END
	shard_row.add_theme_constant_override("separation", 4)
	shard_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shard_row.add_child(_shard_icon(22.0))
	var shard_cost_label := Label.new()
	UIKit.style_label(shard_cost_label, FS_SMALL, SHARD_COLOR, 2)
	shard_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shard_row.add_child(shard_cost_label)
	price_col.add_child(shard_row)
	h.add_child(price_col)

	var buy_btn := Button.new()
	buy_btn.text = "AL"
	buy_btn.custom_minimum_size = Vector2(72, 50)
	buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIKit.style_button(buy_btn, "green", false, UIKit.FS_BODY)
	buy_btn.pressed.connect(_on_buy_pressed.bind(entry))
	buy_btn.focus_mode = Control.FOCUS_NONE
	h.add_child(buy_btn)
	return {"entry": entry, "panel": panel, "price": price_label, "sub": sub_label, "buy": buy_btn, "shard_row": shard_row, "shard_cost": shard_cost_label}


var _row_style_cache: Dictionary = {}


func _row_style(kind: String) -> StyleBox:
	if _row_style_cache.has(kind):
		return _row_style_cache[kind]
	var sb: StyleBox = UIKit.panel_style(kind).duplicate() as StyleBox
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 8.0)
	_row_style_cache[kind] = sb
	return sb


## bkz. merchant_shop_screen.gd _build_icon_slot: kare tier çerçevesi + inset ikon alanı (çerçeve holder'ın ilk çocuğu).
func _build_icon_slot(holder: Control, inset: float) -> Control:
	var frame := TextureRect.new()
	frame.name = "SlotFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE ## yoksa en az boyut dokunun piksel boyutu olur (merchant'ta yaşanan hata)
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture = TierSystem.MINI_FRAME_TEXTURES[0]
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


func _add_icon(holder: Control, entry: Dictionary) -> void:
	var tex_rect := TextureRect.new()
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.texture = _entry_icon(entry)
	holder.add_child(tex_rect)


func _entry_icon(entry: Dictionary) -> Texture2D:
	var key: String = str(entry.get("key", ""))
	match str(entry.get("type", "")):
		"weapon":
			var path: String = str(WeaponCatalogScript.ICONS.get(key, ""))
			return load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
		"wupgrade":
			var p3: String = str(WeaponCatalogScript.ICONS.get(key, ""))
			return load(p3) as Texture2D if p3 != "" and ResourceLoader.exists(p3) else null
		"shield", "upgrade":
			var p2: String = str(ShieldEnchantDefs.ICONS.get(key, ""))
			return load(p2) as Texture2D if p2 != "" and ResourceLoader.exists(p2) else null
	return null


func _entry_name(entry: Dictionary) -> String:
	var key: String = str(entry.get("key", ""))
	match str(entry.get("type", "")):
		"weapon":
			return str(WeaponCatalogScript.NAMES.get(key, key.capitalize()))
		"shield":
			return ShieldEnchantDefs.type_name(key)
		"upgrade":
			return "Geliştirme %d" % (int(entry.get("index", 0)) + 1)
		"wupgrade":
			var rows: Array = Logic.slot_upgrade_rows(int(entry.get("slot", 0)))
			var i: int = int(entry.get("index", 0))
			return str((rows[i] as Dictionary)["name"]) if i >= 0 and i < rows.size() else "?"
	return key


# ------------------------------------------------------------------ durum / fiyat / satın alma

func _entry_price(entry: Dictionary) -> int:
	match str(entry.get("type", "")):
		"weapon":
			return Logic.weapon_price(GameManager.owned_weapons.size())
		"shield":
			return Logic.shield_price()
		"upgrade":
			return Logic.upgrade_price(int(entry.get("index", 0)))
		"wupgrade":
			return Logic.wupgrade_price(int(entry.get("slot", 0)), int(entry.get("index", 0)))
	return 0


## "" = alınabilir (altın hariç).
func _entry_block(entry: Dictionary) -> String:
	var key: String = str(entry.get("key", ""))
	match str(entry.get("type", "")):
		"weapon":
			return Logic.weapon_block_reason(_player, key)
		"shield":
			return Logic.shield_block_reason(key)
		"upgrade":
			return Logic.upgrade_block_reason(int(entry.get("index", 0)))
		"wupgrade":
			return Logic.wupgrade_block_reason(int(entry.get("slot", 0)), int(entry.get("index", 0)))
	return "?"


func _entry_shard_cost(entry: Dictionary) -> int:
	if str(entry.get("type", "")) == "wupgrade":
		return Logic.entry_shard_cost("wfinal" if bool(entry.get("final", false)) else "wupgrade")
	return Logic.entry_shard_cost(str(entry.get("type", "")))


func _entry_can_buy(entry: Dictionary) -> bool:
	return _entry_block(entry) == "" and GameManager.gold >= _entry_price(entry)


func _on_buy_pressed(entry: Dictionary) -> void:
	if not _entry_can_buy(entry):
		return
	var key: String = str(entry.get("key", ""))
	var ok: bool = false
	match str(entry.get("type", "")):
		"weapon":
			ok = Logic.buy_weapon(_player, key)
		"shield":
			ok = Logic.buy_shield(_player, key)
		"upgrade":
			ok = Logic.buy_upgrade(_player, int(entry.get("index", 0)))
		"wupgrade":
			ok = Logic.buy_wupgrade(_player, int(entry.get("slot", 0)), int(entry.get("index", 0)))
	if not ok:
		return
	_flash_bought(entry)
	if str(entry.get("type", "")) == "shield":
		_show_tab(Tab.SHIELDS) ## tür alınınca geliştirme satırları belirir, diğer türler kilitlenir
		for r in _rows:
			if str(r["entry"].get("type", "")) == "upgrade":
				_select(r["entry"]) ## seçimi ilk geliştirmeye al: sıradaki adım
				break
	else:
		_refresh_all()


## Satın alınan plakanın kısa parlaması (alındığının görsel onayı). Tween plakaya özel: art arda alımlarda öncekinin tween'i
## öldürülünce plaka parlak kalmasın diye her plakanın kendi tween'i, öldürülünce renk beyaza döndürülür.
func _flash_bought(entry: Dictionary) -> void:
	for r in _rows:
		if r["entry"] == entry and is_instance_valid(r["panel"]):
			var p: Control = r["panel"]
			if p.has_meta("flash_tween"):
				var old: Variant = p.get_meta("flash_tween")
				if old is Tween and (old as Tween).is_valid():
					(old as Tween).kill()
			p.modulate = Color(1.6, 1.45, 0.9)
			var tw: Tween = p.create_tween()
			tw.tween_property(p, "modulate", Color.WHITE, 0.35)
			p.set_meta("flash_tween", tw)


func _on_row_gui_input(event: InputEvent, entry: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select(entry)
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		_select(entry)
		_on_buy_pressed(entry)


func _select(entry: Dictionary) -> void:
	_selected = entry
	_refresh_all()


## Tüm plakaların fiyat/alt yazı/düğme durumunu, ayrıntı + envanter panelini ve altını yeniler.
func _refresh_all() -> void:
	if _gold_label:
		_gold_label.text = "%d Altın" % GameManager.gold
	if _shard_label:
		_shard_label.text = "%d" % GameManager.weapon_shards
	for r in _rows:
		_refresh_row(r)
	_refresh_status()
	_refresh_details()
	_refresh_inventory()
	_last_sig = _state_sig()


## Ekranın gösterdiği her şeyin ucuz özeti (değişmediyse _refresh_all atlanır).
func _state_sig() -> int:
	return hash([GameManager.gold, GameManager.weapon_shards, str(GameManager.owned_weapons), GameManager.shield_enchant,
			str(GameManager.shield_enchant_ups), str(_selected), _tab, _trait_slot])


func _refresh_row(r: Dictionary) -> void:
	var entry: Dictionary = r["entry"]
	var key: String = str(entry.get("key", ""))
	var block: String = _entry_block(entry)
	var price: Label = r["price"]
	var sub: Label = r["sub"]
	var buy: Button = r["buy"]
	var kind: String = str(entry.get("type", ""))
	var locked: bool = false
	var price_text: String = "%d" % _entry_price(entry)
	var price_color: Color = UIKit.C_GOLD
	match kind:
		"weapon":
			var melee: bool = WeaponCatalogScript.MELEE_KEYS.has(key)
			var owned: int = Logic.owned_count(key)
			sub.text = ("Yakın dövüş" if melee else "Menzilli") + (" · Sende x%d" % owned if owned > 0 else "")
		"shield":
			sub.text = Logic.shield_summary(key)
			if GameManager.shield_enchant == key:
				price_text = "SENDE"
				price_color = UIKit.C_GOOD
			elif GameManager.shield_enchant != "":
				price_text = "KİLİTLİ"
				price_color = UIKit.C_TEXT_DIM
				locked = true
		"upgrade":
			var idx: int = int(entry.get("index", 0))
			var limit: int = Logic.upgrade_limit(idx)
			sub.text = "%s  (%d/%s)" % [Logic.upgrade_effect_text(idx).replace("\n", ", "), Logic.upgrade_count(idx), "∞" if limit <= 0 else str(limit)]
			if limit > 0 and Logic.upgrade_count(idx) >= limit:
				price_text = "TAMAM"
				price_color = UIKit.C_GOOD
				locked = true
		"wupgrade":
			var w_slot: int = int(entry.get("slot", 0))
			var w_idx: int = int(entry.get("index", 0))
			var w_rows: Array = Logic.slot_upgrade_rows(w_slot)
			sub.text = str((w_rows[w_idx] as Dictionary)["text"]) if w_idx >= 0 and w_idx < w_rows.size() else ""
			if Logic.wupgrade_taken(w_slot, w_idx):
				price_text = "ALINDI"
				price_color = UIKit.C_GOOD
				locked = true
	price.text = price_text
	price.add_theme_color_override("font_color", price_color)
	## Parçacık maliyeti: sadece fiyatı olan (alınabilir) satırlarda; yetmiyorsa kırmızı.
	var shard_cost: int = _entry_shard_cost(entry)
	var shard_row: Control = r["shard_row"]
	shard_row.visible = shard_cost > 0 and not locked and price_text != "SENDE" and price_text != "TAMAM" and price_text != "ALINDI"
	var shard_cost_label: Label = r["shard_cost"]
	shard_cost_label.text = "%d" % shard_cost
	shard_cost_label.add_theme_color_override("font_color", SHARD_COLOR if GameManager.weapon_shards >= shard_cost else UIKit.C_BAD)
	buy.disabled = not _entry_can_buy(entry)
	var is_selected: bool = _selected == entry
	var style: String = "card_selected" if is_selected else ("card_sold" if locked else "card")
	(r["panel"] as PanelContainer).add_theme_stylebox_override("panel", _row_style(style))


func _refresh_status() -> void:
	if _status_label == null:
		return
	if _tab == Tab.WEAPONS:
		_status_label.text = "Silah yuvası %d/%d" % [GameManager.owned_weapons.size(), Logic.max_weapons(_player)]
	elif _tab == Tab.ENCHANTS:
		_status_label.text = "Silah yuvası %d/%d" % [GameManager.owned_weapons.size(), Logic.max_weapons(_player)]
	elif GameManager.shield_enchant == "":
		_status_label.text = "Kalkan: Standart"
	else:
		_status_label.text = "Kalkan: %s" % ShieldEnchantDefs.type_name(GameManager.shield_enchant)


# ------------------------------------------------------------------ sol: ayrıntı

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
	_details_icon_holder.custom_minimum_size = Vector2(160, 160)
	_details_icon_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_details_icon_inset = _build_icon_slot(_details_icon_holder, 12.0)
	_details_icon_frame = _details_icon_holder.get_node("SlotFrame") as TextureRect
	vbox.add_child(_details_icon_holder)

	_details_name = Label.new()
	_details_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.style_label(_details_name, UIKit.FS_TITLE, UIKit.C_ACCENT, 3)
	vbox.add_child(_details_name)

	_details_kind = Label.new()
	_details_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(_details_kind, UIKit.FS_BODY, UIKit.C_TEXT_DIM, 2)
	vbox.add_child(_details_kind)

	var desc_scroll := ScrollContainer.new()
	desc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_scroll.custom_minimum_size = Vector2(320.0 + DESC_SCROLLBAR_RESERVE, 150)
	desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if _phone:
		desc_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		desc_scroll.custom_minimum_size = Vector2.ZERO
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

	_details_shard = Label.new()
	_details_shard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(_details_shard, UIKit.FS_BODY, SHARD_COLOR, 3)
	vbox.add_child(_details_shard)

	_details_block = Label.new()
	_details_block.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details_block.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.style_label(_details_block, UIKit.FS_BODY, UIKit.C_BAD, 0)
	vbox.add_child(_details_block)
	return panel


## bkz. merchant_shop_screen.gd _attach_side_panel_content: telefonda yan panel içeriği kendi kaydırma kutusunda (pencere boyu
## içerikten türemesin).
func _attach_side_panel_content(panel: PanelContainer, margin: MarginContainer) -> void:
	if not _phone:
		panel.add_child(margin)
		return
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(sc)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(margin)


func _refresh_details() -> void:
	if _details_name == null:
		return
	if _selected.is_empty():
		_details_name.text = ""
		_details_kind.text = ""
		_details_desc.text = ""
		_details_price.text = ""
		_details_shard.text = ""
		_details_block.text = ""
		return
	var key: String = str(_selected.get("key", ""))
	var kind: String = str(_selected.get("type", ""))
	_details_name.text = _entry_name(_selected)
	match kind:
		"weapon":
			_details_kind.text = "Silah · " + ("Yakın dövüş" if WeaponCatalogScript.MELEE_KEYS.has(key) else "Menzilli")
			_details_desc.text = str(WeaponCatalogScript.DESCRIPTIONS.get(key, "")).replace(" · ", "\n")
		"shield":
			var d: Dictionary = ShieldEnchantDefs.TYPES.get(key, {})
			_details_kind.text = "Kalkan türü"
			_details_desc.text = "%s\n\n%s\nBir tür seçildi mi değiştirilemez; diğer türler kilitlenir." % [str(d.get("desc", "")), _shield_stat_lines(key)]
		"upgrade":
			_details_kind.text = "%s geliştirmesi" % ShieldEnchantDefs.type_name(key)
			var idx: int = int(_selected.get("index", 0))
			var limit: int = Logic.upgrade_limit(idx)
			_details_desc.text = "%s\n\nAlınan: %d / %s" % [Logic.upgrade_effect_text(idx), Logic.upgrade_count(idx), "sınırsız" if limit <= 0 else str(limit)]
		"wupgrade":
			var d_slot: int = int(_selected.get("slot", 0))
			var d_idx: int = int(_selected.get("index", 0))
			var d_rows: Array = Logic.slot_upgrade_rows(d_slot)
			var d_def: Dictionary = EnchantDefs.get_def(Logic.slot_trait_id(d_slot))
			_details_kind.text = "%s · %s" % [str(WeaponCatalogScript.NAMES.get(key, key)), "Final" if bool(_selected.get("final", false)) else "Geliştirme"]
			var d_text: String = str((d_rows[d_idx] as Dictionary)["text"]) if d_idx >= 0 and d_idx < d_rows.size() else ""
			_details_desc.text = "%s\n\nEfsun: %s\n%s" % [d_text, str(d_def.get("name", "")), str((d_def.get("base", {}) as Dictionary).get("text", ""))]
	_details_icon_frame.texture = TierSystem.MINI_FRAME_TEXTURES[0]
	for c in _details_icon_inset.get_children():
		c.queue_free()
	_add_icon(_details_icon_inset, _selected)
	var block: String = _entry_block(_selected)
	_details_price.text = "%d Altın" % _entry_price(_selected)
	var shard_cost: int = _entry_shard_cost(_selected)
	_details_shard.visible = shard_cost > 0
	_details_shard.text = "+ %d Silah Parçacığı  (Sende: %d)" % [shard_cost, GameManager.weapon_shards]
	_details_shard.add_theme_color_override("font_color", SHARD_COLOR if GameManager.weapon_shards >= shard_cost else UIKit.C_BAD)
	if block == "" and GameManager.gold < _entry_price(_selected):
		block = "Yetersiz altın"
	_details_block.text = block


## "Kalkan: 160\nHasar soğurma: %60\nYenilenme: 4/sn\nBekleme: yok" (ShieldEnchantDefs.stats() ile aynı alanlar, o türün tabanı).
func _shield_stat_lines(key: String) -> String:
	var d: Dictionary = ShieldEnchantDefs.TYPES.get(key, {})
	if d.is_empty():
		return ""
	var delay_text: String = "yok (savaşta da dolar)" if bool(d.get("always_regen", false)) else "%s sn" % Logic._num(float(d["delay"]))
	return "Kalkan: %d\nHasar soğurma: %%%d\nYenilenme: %s/sn\nBekleme: %s" % [
		int(round(float(d["power"]))), int(round(float(d["absorption"]) * 100.0)), Logic._num(float(d["regen"])), delay_text]


# ------------------------------------------------------------------ sağ: envanter

func _build_inventory_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_attach_side_panel_content(panel, margin)
	_inventory_body = VBoxContainer.new()
	_inventory_body.add_theme_constant_override("separation", 8)
	margin.add_child(_inventory_body)
	return panel


func _refresh_inventory() -> void:
	if _inventory_body == null:
		return
	for c in _inventory_body.get_children():
		_inventory_body.remove_child(c)
		c.queue_free()
	var title := Label.new()
	title.text = "ENVANTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(title, UIKit.FS_TITLE, UIKit.C_ACCENT, 3)
	_inventory_body.add_child(title)
	_inventory_body.add_child(HSeparator.new())
	var max_w: int = Logic.max_weapons(_player)
	_inventory_body.add_child(_section_title("SİLAHLAR %d/%d" % [GameManager.owned_weapons.size(), max_w]))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_inventory_body.add_child(grid)
	for i in range(max_w):
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(76, 76)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inset: Control = _build_icon_slot(holder, 8.0)
		var lvl := Label.new()
		lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIKit.style_label(lvl, FS_SMALL, UIKit.C_TEXT_DIM, 0)
		if i < GameManager.owned_weapons.size():
			var e: Dictionary = GameManager.owned_weapons[i]
			_add_icon(inset, {"type": "weapon", "key": str(e.get("key", ""))})
			lvl.text = "Sv. %d" % int(e.get("level", 1))
		else:
			holder.modulate = Color(1, 1, 1, 0.45)
			lvl.text = "boş"
		cell.add_child(holder)
		cell.add_child(lvl)
		grid.add_child(cell)
	_inventory_body.add_child(_section_title("KALKAN"))
	var stats: Dictionary = ShieldEnchantDefs.stats()
	if stats.is_empty():
		var none := Label.new()
		none.text = "Yok"
		UIKit.style_label(none, UIKit.FS_BODY, UIKit.C_TEXT_DIM, 2)
		_inventory_body.add_child(none)
		return
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var s_holder := Control.new()
	s_holder.custom_minimum_size = Vector2(64, 64)
	var s_inset: Control = _build_icon_slot(s_holder, 6.0)
	_add_icon(s_inset, {"type": "shield", "key": str(stats["key"])})
	head.add_child(s_holder)
	var s_name := Label.new()
	s_name.text = str(stats["name"])
	s_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIKit.style_label(s_name, UIKit.FS_BODY, UIKit.C_TEXT, 3)
	head.add_child(s_name)
	_inventory_body.add_child(head)
	var delay_text: String = "yok" if bool(stats["always_regen"]) else "%s sn" % Logic._num(float(stats["delay"]))
	for pair in [["Kalkan", str(int(round(float(stats["power"]))))],
			["Soğurma", "%%%d" % int(round(float(stats["absorption"]) * 100.0))],
			["Yenilenme", "%s/sn" % Logic._num(float(stats["regen"]))], ["Bekleme", delay_text]]:
		var hb := HBoxContainer.new()
		var l := Label.new()
		l.text = pair[0]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIKit.style_label(l, UIKit.FS_BODY, UIKit.C_TEXT_DIM, 2)
		hb.add_child(l)
		var v := Label.new()
		v.text = pair[1]
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		UIKit.style_label(v, UIKit.FS_BODY, Color(UIKit.INK["shield"]), 2)
		hb.add_child(v)
		_inventory_body.add_child(hb)


func _on_close_pressed() -> void:
	GameManager.unregister_blocking_panel(self)
	closed.emit()
	queue_free()
