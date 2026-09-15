extends CanvasLayer

## Kullanıcı isteği: "ayarlara tuş ataması özelliği ekle, isteyen istediği
## tuşu istediği şeyle değiştirebilsin. tuş ataması için ayarlarda bir menü
## hazırla, ayarlar paneli ufak olduğu için ona sığmaz çünkü" - mevcut
## 560x460 SettingsPanel'e sığmayacağı için AYRI, kendi büyük penceresi olan
## bir popup. weapon_select_screen.gd/mini_shop_screen.gd ile AYNI "tamamen
## kod ile kurulan runtime ekran" deseni - ayrı bir .tscn yok.
##
## Kaynak/kalıcılık: TÜM action listesi ve gerçek kaydetme/uygulama mantığı
## game_manager.gd'de tek yerde (bkz. REBINDABLE_ACTIONS/set_keybind_
## override/get_keybind_keycode) - burada ikinci bir kopya YOK, bu ekran
## sadece o API'yi çağıran bir arayüz.

signal closed

const PAL_ACCENT := Color(0.83, 0.56, 0.30, 1.0)
const PAL_BG := Color(0.18, 0.13, 0.08, 0.97)

var _listening_action: String = ""
var _row_buttons: Dictionary = {} ## action_name -> Button (tuş adını gösteren buton)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.02, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(640, 640)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAL_BG
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.border_color = PAL_ACCENT
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_right = 14
	sb.corner_radius_bottom_left = 14
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	outer.add_theme_stylebox_override("panel", sb)
	center.add_child(outer)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	outer.add_child(main_vbox)

	var title := Label.new()
	title.text = "TUŞ ATAMALARI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", PAL_ACCENT)
	main_vbox.add_child(title)

	var hint := Label.new()
	hint.text = "Değiştirmek istediğin tuşa tıkla, ardından yeni tuşa bas (İptal için ESC)."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	main_vbox.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var rows_vbox := VBoxContainer.new()
	rows_vbox.add_theme_constant_override("separation", 8)
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows_vbox)

	for entry in GameManager.REBINDABLE_ACTIONS:
		rows_vbox.add_child(_build_row(entry["action"], entry["label"]))

	var close_btn := Button.new()
	close_btn.text = "KAPAT"
	close_btn.custom_minimum_size = Vector2(0, 46)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(_on_close_pressed)
	main_vbox.add_child(close_btn)

	var ui_sound = get_node_or_null("/root/UISound")
	if ui_sound and ui_sound.has_method("connect_all_buttons"):
		ui_sound.connect_all_buttons(self)
	## DÜZELTME (kullanıcı isteği: "Button resmini oyunumdaki tüm butonlarla
	## değiştir") - bu panel sese bağlanıyordu ama yeni ahşap buton stilini
	## HİÇ almıyordu (bkz. ui_sound.gd apply_wood_buttons/shop_panel.gd
	## _apply_wood_button_style - tek kaynak orada, ikinci bir kopya yok).
	if ui_sound and ui_sound.has_method("apply_wood_buttons"):
		ui_sound.apply_wood_buttons(self)


func _build_row(action_name: String, label_text: String) -> PanelContainer:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.26, 0.19, 0.12, 1.0)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.45, 0.35, 0.22)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left = 8
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 20)
	hbox.add_child(name_lbl)

	var key_btn := Button.new()
	key_btn.custom_minimum_size = Vector2(170, 40)
	key_btn.add_theme_font_size_override("font_size", 18)
	key_btn.text = OS.get_keycode_string(GameManager.get_keybind_keycode(action_name))
	key_btn.pressed.connect(_on_key_button_pressed.bind(action_name, key_btn))
	hbox.add_child(key_btn)
	_row_buttons[action_name] = key_btn

	return row


func _on_key_button_pressed(action_name: String, btn: Button) -> void:
	if _listening_action != "" and _listening_action != action_name:
		var prev_btn: Button = _row_buttons.get(_listening_action)
		if prev_btn:
			prev_btn.text = OS.get_keycode_string(GameManager.get_keybind_keycode(_listening_action))
	_listening_action = action_name
	btn.text = "Bir tuşa bas..."


## Dinleme modundayken bir sonraki tuş basımını yakalar - _unhandled_input
## değil _input kullanılıyor çünkü bu panel açıkken get_tree().paused = true
## (bkz. pause_menu.gd) ve process_mode zaten PROCESS_MODE_ALWAYS.
func _input(event: InputEvent) -> void:
	if _listening_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var btn: Button = _row_buttons.get(_listening_action)
		if event.keycode == KEY_ESCAPE:
			if btn:
				btn.text = OS.get_keycode_string(GameManager.get_keybind_keycode(_listening_action))
			_listening_action = ""
			get_viewport().set_input_as_handled()
			return
		var new_keycode: int = event.physical_keycode
		GameManager.set_keybind_override(_listening_action, new_keycode)
		if btn:
			btn.text = OS.get_keycode_string(new_keycode)
		_listening_action = ""
		get_viewport().set_input_as_handled()


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
