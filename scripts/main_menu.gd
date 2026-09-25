extends Control

## Ana menü. Kullanıcı isteği (2026-09-24): "ana menü, singleplayer ve multiplayer karakter menülerindeki tüm kartları ve
## arayüz arkaplanlarını ... sıfırdan tasarla ... hafif cozy ... bej/açık kahverengi tonlarında" - ekran bej menü kitiyle
## (MenuKit, assets/ui/menu, tools/gen_menu_kit.py) KODLA kurulur: iplerle asılı ahşap başlık tabelası, parşömen panelde
## büyük butonlar, aynı dilde ayarlar penceresi (kaydırıcı/açma-kapama/açılır liste de kit dokularıyla).
## Davranış (sahne geçişleri, ses/tam ekran/çözünürlük/FPS ayarları, tuş atamaları, debug modu) eskisiyle AYNI.

const KeybindMenuScript := preload("res://scripts/keybind_menu.gd")

const TITLE := "I NEED TO STAY ALIVE"
const SCREEN := Vector2(1920, 1080)
const SIGN_TOP := 96.0
const SIGN_H := 186.0 ## tabela dokusunun kendi boyu (62 sanat px x 3) - bkz. tools/gen_menu_kit.py sign()
const MENU_W := 540.0
const MENU_FONT := 64 ## ana menü butonları: m5x7 4x (eskisi gibi büyük, uzaktan okunur)

var settings_panel: Control
var volume_slider: HSlider
var volume_value: Label
var fullscreen_check: CheckButton
var resolution_option: OptionButton
var fps_check: CheckButton
var keybind_button: Button

var _start_btn: Button
var _multiplayer_btn: Button
var _settings_btn: Button
var _exit_btn: Button


func _ready() -> void:
	DisplayServer.window_set_title("I Need to Stay Alive")
	theme = MenuKit.theme()
	MenuKit.add_background(self)
	_build_title_sign()
	_build_menu()
	_create_debug_mode_button()
	_build_settings()
	UISound.connect_all_buttons(self)
	_start_btn.grab_focus()


## Başlık: iki örgü iple yukarıdan asılı, 3 tahtalı ahşap tabela; yazı krem, koyu kahve konturlu (tabela boyası).
func _build_title_sign() -> void:
	var f: Font = MenuKit.font()
	var text_w: float = f.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuKit.FS_HUGE).x
	var sign_w: float = ceilf((text_w + 2.0 * 96.0) / 6.0) * 6.0
	var x: float = roundf((SCREEN.x - sign_w) / 6.0) * 3.0

	for rx: float in [x + sign_w * 0.2, x + sign_w * 0.8]:
		var rope := TextureRect.new()
		rope.texture = MenuKit.tex("rope.png")
		rope.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rope.stretch_mode = TextureRect.STRETCH_TILE
		rope.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rope)
		MenuKit.place(rope, Vector2(roundf(rx / 3.0) * 3.0 - 6.0, 0.0), Vector2(12, SIGN_TOP + 15.0))

	var sb := StyleBoxTexture.new()
	sb.texture = MenuKit.tex("sign.png")
	sb.texture_margin_left = 42
	sb.texture_margin_right = 42
	sb.texture_margin_top = 93
	sb.texture_margin_bottom = 93
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	## İçerik payları açıkça verilmezse StyleBoxTexture doku paylarını (93+93) minimum boy sayar ve tabela büyürdü.
	sb.content_margin_left = 90
	sb.content_margin_right = 90
	sb.content_margin_top = 0
	sb.content_margin_bottom = 6
	var sign_panel := PanelContainer.new()
	sign_panel.name = "TitleSign"
	sign_panel.add_theme_stylebox_override("panel", sb)
	sign_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sign_panel)

	var title := MenuKit.make_label(TITLE, MenuKit.FS_HUGE, MenuKit.C_CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "Title"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", MenuKit.C_OUTLINE)
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_shadow_color", Color(0.29, 0.17, 0.10, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_outline_size", 18)
	sign_panel.add_child(title)
	## Ağaca eklendikten SONRA (menü teması geçerliyken) konum/boyut - bkz. character_select.gd _place notu.
	MenuKit.place(sign_panel, Vector2(x, SIGN_TOP), Vector2(sign_w, SIGN_H))


func _build_menu() -> void:
	var panel := MenuKit.make_panel("panel")
	panel.name = "MenuPanel"
	panel.custom_minimum_size = Vector2(MENU_W, 0)
	add_child(panel)
	MenuKit.place(panel, Vector2(roundf((SCREEN.x - MENU_W) / 6.0) * 3.0, 348.0), Vector2(MENU_W, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	_start_btn = MenuKit.make_button("TEK OYUNCULU", "sage", MENU_FONT, 84)
	_multiplayer_btn = MenuKit.make_button("ÇOK OYUNCULU", "tan", MENU_FONT, 84)
	_settings_btn = MenuKit.make_button("AYARLAR", "tan", MENU_FONT, 84)
	_exit_btn = MenuKit.make_button("ÇIKIŞ", "rose", MENU_FONT, 84)
	for b: Button in [_start_btn, _multiplayer_btn, _settings_btn, _exit_btn]:
		v.add_child(b)
	_start_btn.pressed.connect(_on_start_pressed)
	_multiplayer_btn.pressed.connect(_on_multiplayer_pressed)
	_settings_btn.pressed.connect(_on_settings_pressed)
	_exit_btn.pressed.connect(_on_exit_pressed)


## Kullanıcı isteği (2026-09-24): "bu modun otomatik olarak açıldığı bir debugmode haritası
## seçeneği" - ana ekrandaki büyük TEK OYUNCULU/ÇOK OYUNCULU yığınıyla YARIŞMASIN diye küçük,
## sol-alt köşede ayrı bir buton (bkz. scripts/debug_menu.gd/hud.gd/GameManager.
## debug_mode_unlocked notu). Normal "Tek Oyunculu" akışının BİREBİR aynısı, tek fark
## debug_mode_unlocked'ı sahne değişmeden ÖNCE true yapması - hud.gd _setup_debug_mode() bunu
## okuyup DEBUG butonunu baştan görünür kurar, chate "baykusseverim" yazmaya gerek kalmaz.
func _create_debug_mode_button() -> void:
	var btn := MenuKit.make_button("Debug Modu", "tan", MenuKit.FS_SMALL, 42)
	btn.custom_minimum_size = Vector2(168, 42)
	btn.pressed.connect(_on_debug_mode_pressed)
	add_child(btn)
	MenuKit.place(btn, Vector2(24, SCREEN.y - 66), btn.custom_minimum_size)


## Ayarlar penceresi: menünün üstünde, arkası sıcak kahve tonla karartılmış, ortalanmış parşömen panel.
func _build_settings() -> void:
	settings_panel = Control.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_panel.visible = false
	add_child(settings_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.20, 0.11, 0.05, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.add_child(center)

	var box := MenuKit.make_panel("panel")
	box.custom_minimum_size = Vector2(720, 0)
	center.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	box.add_child(v)
	v.add_child(MenuKit.make_section_header("Ayarlar", MenuKit.FS_TITLE))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 18)
	v.add_child(grid)

	grid.add_child(_row_label("Oyun Sesi"))
	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	vol_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.custom_minimum_size = Vector2(300, 42)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol_row.add_child(volume_slider)
	volume_value = MenuKit.make_label("100%", MenuKit.FS_BODY, MenuKit.C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	volume_value.custom_minimum_size = Vector2(84, 0)
	volume_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vol_row.add_child(volume_value)
	grid.add_child(vol_row)

	grid.add_child(_row_label("Tam Ekran"))
	fullscreen_check = CheckButton.new()
	fullscreen_check.size_flags_horizontal = Control.SIZE_SHRINK_END
	grid.add_child(fullscreen_check)

	grid.add_child(_row_label("Çözünürlük"))
	resolution_option = OptionButton.new()
	resolution_option.custom_minimum_size = Vector2(300, 48)
	resolution_option.size_flags_horizontal = Control.SIZE_SHRINK_END
	grid.add_child(resolution_option)

	grid.add_child(_row_label("FPS Göstergesi"))
	fps_check = CheckButton.new()
	fps_check.size_flags_horizontal = Control.SIZE_SHRINK_END
	grid.add_child(fps_check)

	## Kullanıcı isteği (2026-09-25): "arayüzler için ayarlara opaklık ayarı getir" - ses satırıyla aynı düzen (bkz.
	## UISound.ui_opacity_percent; pause_menu.gd'de AYNI satır).
	grid.add_child(_row_label("Arayüz Opaklığı"))
	var op_row := HBoxContainer.new()
	op_row.add_theme_constant_override("separation", 12)
	op_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var op_slider := HSlider.new()
	op_slider.min_value = UISound.UI_OPACITY_MIN_PERCENT
	op_slider.max_value = 100
	op_slider.step = 5
	op_slider.custom_minimum_size = Vector2(300, 42)
	op_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	op_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	op_row.add_child(op_slider)
	var op_value: Label = MenuKit.make_label("100%", MenuKit.FS_BODY, MenuKit.C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	op_value.custom_minimum_size = Vector2(84, 0)
	op_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	op_row.add_child(op_value)
	grid.add_child(op_row)
	op_slider.value = UISound.ui_opacity_percent
	op_value.text = "%d%%" % int(op_slider.value)
	op_slider.value_changed.connect(func(value: float) -> void:
		UISound.set_ui_opacity_percent(value)
		op_value.text = "%d%%" % int(value))

	keybind_button = MenuKit.make_button("Tuş Atamaları", "tan", MenuKit.FS_BODY, 52)
	v.add_child(keybind_button)
	var close_btn := MenuKit.make_button("KAPAT", "sage", MenuKit.FS_BODY, 52)
	v.add_child(close_btn)

	close_btn.pressed.connect(_on_settings_closed)
	keybind_button.pressed.connect(_on_keybind_pressed)
	volume_slider.value = UISound.master_volume_percent
	volume_slider.value_changed.connect(_on_volume_changed)
	_update_volume_label(volume_slider.value)
	## Kullanıcı isteği: "ayarlara çözünürlük ve tam ekran özelliği ekle,
	## değiştirilebilsin" - bkz. ui_sound.gd (UISound autoload'ında
	## set_fullscreen/set_resolution, aynı ConfigFile deseni volume ile).
	for label in UISound.get_resolution_labels():
		resolution_option.add_item(label)
	resolution_option.selected = UISound.resolution_index
	fullscreen_check.button_pressed = UISound.is_fullscreen
	resolution_option.disabled = UISound.is_fullscreen
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	resolution_option.item_selected.connect(_on_resolution_selected)
	## Kullanıcı isteği: "fps göstergesi ekle ayarlardan açılıp kapatılabilsin" -
	## fullscreen_check ile BİREBİR AYNI desen (UISound'daki show_fps'e bağlı,
	## bkz. pause_menu.gd'deki AYNI kopya).
	fps_check.button_pressed = UISound.show_fps
	fps_check.toggled.connect(_on_fps_toggled)


func _row_label(text: String) -> Label:
	var l := MenuKit.make_label(text, MenuKit.FS_BODY, MenuKit.C_TEXT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return l


func _unhandled_input(event: InputEvent) -> void:
	if settings_panel and settings_panel.visible and event.is_action_pressed("ui_cancel"):
		_on_settings_closed()
		get_viewport().set_input_as_handled()


func _on_debug_mode_pressed() -> void:
	NetworkManager.disconnect_from_room()
	GameManager.reset()
	GameManager.debug_mode_unlocked = true
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")


func _on_start_pressed() -> void:
	NetworkManager.disconnect_from_room()
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")


func _on_multiplayer_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby_menu.tscn")


## Kullanıcı isteği: "oyunun başlangıç ekranına çıkış düğmesi ekle".
func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_settings_pressed() -> void:
	settings_panel.visible = true
	volume_slider.grab_focus()


func _on_settings_closed() -> void:
	settings_panel.visible = false
	_settings_btn.grab_focus()


func _on_volume_changed(value: float) -> void:
	UISound.set_master_volume_percent(value)
	_update_volume_label(value)


func _update_volume_label(value: float) -> void:
	volume_value.text = "%d%%" % int(round(value))


func _on_fullscreen_toggled(enabled: bool) -> void:
	UISound.set_fullscreen(enabled)
	resolution_option.disabled = enabled


func _on_resolution_selected(index: int) -> void:
	UISound.set_resolution(index)


func _on_fps_toggled(enabled: bool) -> void:
	UISound.set_show_fps(enabled)


## bkz. pause_menu.gd _on_keybind_pressed - AYNI desen (tek kaynak
## keybind_menu.gd/game_manager.gd, burada ikinci bir kopya YOK).
func _on_keybind_pressed() -> void:
	settings_panel.visible = false
	var menu := KeybindMenuScript.new()
	add_child(menu)
	menu.closed.connect(func() -> void:
		if is_instance_valid(settings_panel):
			settings_panel.visible = true
	)
