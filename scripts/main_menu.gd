extends Control

const KeybindMenuScript := preload("res://scripts/keybind_menu.gd")

@onready var settings_panel: Panel = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/VolumeSlider
@onready var volume_value: Label = $SettingsPanel/VolumeValue
@onready var fullscreen_check: CheckButton = $SettingsPanel/FullscreenCheck
@onready var resolution_option: OptionButton = $SettingsPanel/ResolutionOption
@onready var keybind_button: Button = $SettingsPanel/KeybindButton


func _ready() -> void:
	DisplayServer.window_set_title("I Need to Stay Alive")
	UISound.connect_all_buttons(self)
	UISound.apply_wood_buttons(self) ## bkz. ui_sound.gd - tüm butonları ahşap stile çevirir
	## Kullanıcı geri bildirimi (2026-09-22): menü butonları zor okunuyordu - büyük yazıya kalın koyu kontur (okunaklılık).
	for menu_btn: Button in [$VBoxContainer/StartButton, $VBoxContainer/MultiplayerButton, $VBoxContainer/SettingsButton, $VBoxContainer/ExitButton]:
		menu_btn.add_theme_constant_override("outline_size", 8)
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/MultiplayerButton.pressed.connect(_on_multiplayer_pressed)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$VBoxContainer/ExitButton.pressed.connect(_on_exit_pressed)
	$SettingsPanel/CloseButton.pressed.connect(_on_settings_closed)
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
	settings_panel.visible = false
	## Kullanıcı isteği (2026-09-21): ayarlar paneli UIKit ahşap pencere çerçevesinde (konum/boyut aynı).
	settings_panel.add_theme_stylebox_override("panel", UIKit.panel_style("window"))
	$VBoxContainer/StartButton.grab_focus()


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
	$VBoxContainer/SettingsButton.grab_focus()


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
