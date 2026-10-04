extends PanelContainer

## Başlangıç silahı seçici (kullanıcı isteği 2026-10-03: "bundan sonra başlangıç silahı karakter seçim ekranından seçilsin
## oradan isteyen oyuncu istediği silahı seçebilsin başlangıç için ... karakter seçim arayüzünü güncellemen gerekiyor hem
## pcde hem androidde"). Tek oyunculu karakter seçimi (character_select.gd) ve çok oyunculu lobi (lobby_menu.gd) ORTAK
## bileşeni - ruhani yetenek seçicinin (spiritual_picker.gd) yanında, aynı menü kitiyle.
## Kompakt satır: seçili silahın ikonu (ahşap yuva) + adı + türü + "Değiştir" + kısa açıklama. Satıra / ikona / düğmeye
## basınca 15 silahın ızgarası açılır (_open_grid, ayrı CanvasLayer - hangi ekranda olursa olsun en üstte); birine basmak
## seçer ve kapatır. Seçim GameManager.selected_start_weapon'a yazılır (ruhani yetenek gibi yerel tercih, ağdan gitmez);
## oyun başlayınca main.gd _start_initial_loadout_selection verir. Veriler scripts/weapon_catalog.gd'de.
## mobile = true: telefon boyları (ikon 144, yazılar 40/48, ızgara hücresi 260 px).

signal picked(key: String)

const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")
const SELECT_RING_COLOR := Color(1.0, 0.78, 0.22)

var mobile: bool = false
## Izgara (açılan pencere) telefonda her zaman büyük - lobide satır masaüstü boyunda kalsa bile (bkz. lobby_menu.gd).
var _big_grid: bool = false
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
var _icon: TextureRect = null
var _name_label: Label = null
var _cat_label: Label = null
var _desc_label: Label = null
var _popup: CanvasLayer = null


func setup(is_mobile: bool = false) -> void:
	mobile = is_mobile
	_big_grid = is_mobile or MobileUIScript.enabled
	_build()
	select(WeaponCatalog.selected(), false)


func _fs(desktop: int, phone: int) -> int:
	return phone if mobile else desktop


func _gs(desktop: int, phone: int) -> int:
	return phone if _big_grid else desktop


func _build() -> void:
	add_theme_stylebox_override("panel", MenuKit.style("panel_tight"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(MenuKit.make_section_header("Başlangıç Silahı", _fs(MenuKit.FS_BODY, 40)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var icon_size: float = 144.0 if mobile else 96.0
	var frame := MenuKit.make_panel("slot_selected")
	frame.custom_minimum_size = Vector2(icon_size, icon_size)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)
	var icon_btn := TextureButton.new()
	icon_btn.ignore_texture_size = true
	icon_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	icon_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon_btn.tooltip_text = "Başlangıç silahını değiştir"
	icon_btn.pressed.connect(_open_grid)
	frame.add_child(icon_btn)
	_icon = TextureRect.new() ## görünen ikon (TextureButton'ın dokusu değişince boyut hesabı oynamasın diye ayrı)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	_name_label = MenuKit.make_label("", _fs(MenuKit.FS_BODY, 48), MenuKit.C_TEXT)
	_name_label.clip_text = true
	col.add_child(_name_label)
	_cat_label = MenuKit.make_label("", _fs(MenuKit.FS_SMALL, 32), MenuKit.C_TEXT_DIM)
	col.add_child(_cat_label)
	var change := MenuKit.make_button("Değiştir", "tan", _fs(MenuKit.FS_SMALL, 40), 112.0 if mobile else 48.0)
	change.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	change.custom_minimum_size.x = 260.0 if mobile else 170.0
	change.pressed.connect(_open_grid)
	col.add_child(change)

	_desc_label = MenuKit.make_label("", _fs(MenuKit.FS_SMALL, 32), MenuKit.C_TEXT_DIM)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_desc_label.clip_text = true
	_desc_label.custom_minimum_size = Vector2(0, 112.0 if mobile else 56.0)
	v.add_child(_desc_label)


func select(key: String, emit: bool = true) -> void:
	if not WeaponCatalog.is_valid(key):
		key = WeaponCatalog.DEFAULT_KEY
	GameManager.selected_start_weapon = key
	if _icon:
		_icon.texture = WeaponCatalog.icon(key)
	if _name_label:
		_name_label.text = WeaponCatalog.display_name(key)
	if _cat_label:
		_cat_label.text = WeaponCatalog.category_label(key)
		_cat_label.add_theme_color_override("font_color", WeaponCatalog.category_color(key))
	if _desc_label:
		## "HASAR: 13 + %100 saldırı gücü · Ateş hızı ..." - kart metninin "HASAR:" başlığı kompakt satırda gereksiz.
		_desc_label.text = str(WeaponCatalog.DESCRIPTIONS.get(key, "")).replace("HASAR: ", "Hasar ")
	if emit:
		picked.emit(key)


## ---------------------------------------------------------------- 15 silahın ızgarası
func _open_grid() -> void:
	if is_instance_valid(_popup):
		return
	_popup = CanvasLayer.new()
	_popup.layer = 60
	_popup.add_to_group(&"gamepad_modal") ## kumandayla gezinme (bkz. gamepad_ui.gd)
	_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	var host: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	host.add_child(_popup)
	var root := Control.new()
	root.theme = MenuKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.06, 0.03, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_close_grid())
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := MenuKit.make_panel("panel")
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	var title := MenuKit.make_label("Başlangıç Silahını Seç", _gs(MenuKit.FS_TITLE, 64), MenuKit.C_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	var close := MenuKit.make_button("X", "rose", _gs(MenuKit.FS_BODY, 48), 112.0 if _big_grid else 56.0)
	close.custom_minimum_size.x = 112.0 if _big_grid else 56.0
	close.pressed.connect(_close_grid)
	head.add_child(close)

	var grid := GridContainer.new()
	grid.columns = 5
	var sep: int = 16 if _big_grid else 12
	grid.add_theme_constant_override("h_separation", sep)
	grid.add_theme_constant_override("v_separation", sep)
	v.add_child(grid)
	var cell := Vector2(280, 250) if _big_grid else Vector2(200, 176)
	var icon_px: float = 144.0 if _big_grid else 96.0
	var current: String = WeaponCatalog.selected()
	for key: String in WeaponCatalog.KEYS:
		var b := Button.new()
		b.custom_minimum_size = cell
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "%s (%s)\n%s" % [WeaponCatalog.display_name(key), WeaponCatalog.category_label(key),
				str(WeaponCatalog.DESCRIPTIONS.get(key, ""))]
		var style: StyleBox = MenuKit.style("slot_selected" if key == current else "slot_normal")
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, MenuKit.style("slot_hover") if st == "hover" and key != current else style)
		b.pressed.connect(func() -> void:
			select(key)
			_close_grid())
		var ic := TextureRect.new()
		ic.texture = WeaponCatalog.icon(key)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		MenuKit.place(ic, Vector2((cell.x - icon_px) * 0.5, 12.0), Vector2(icon_px, icon_px))
		var nm := MenuKit.make_label(WeaponCatalog.display_name(key), _gs(MenuKit.FS_SMALL, 40), MenuKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		nm.clip_text = true
		b.add_child(nm)
		## MenuKit.place (ofset) - ağaca girmeden verilen size, varsayılan temanın büyük yazısıyla şişip hücreden taşıyordu.
		MenuKit.place(nm, Vector2(4.0, icon_px + 14.0), Vector2(cell.x - 8.0, _gs(30, 48)))
		MenuKit.fit_label_font(nm, nm.text, _gs(MenuKit.FS_SMALL, 40), cell.x - 16.0)
		var cat := MenuKit.make_label(WeaponCatalog.category_label(key), _gs(MenuKit.FS_SMALL, 32), WeaponCatalog.category_color(key), HORIZONTAL_ALIGNMENT_CENTER)
		b.add_child(cat)
		MenuKit.place(cat, Vector2(4.0, icon_px + _gs(44, 62)), Vector2(cell.x - 8.0, _gs(30, 40)))
		grid.add_child(b)
		if key == current:
			b.grab_focus.call_deferred()
	UISound.connect_all_buttons(root)


func _close_grid() -> void:
	if is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


func _exit_tree() -> void:
	_close_grid()


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_popup) and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_grid()
