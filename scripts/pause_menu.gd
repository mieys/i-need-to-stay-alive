extends CanvasLayer

const KeybindMenuScript := preload("res://scripts/keybind_menu.gd")

@onready var settings_panel: Panel = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/VolumeSlider
@onready var volume_value: Label = $SettingsPanel/VolumeValue
@onready var fullscreen_check: CheckButton = $SettingsPanel/FullscreenCheck
@onready var resolution_option: OptionButton = $SettingsPanel/ResolutionOption
@onready var keybind_button: Button = $SettingsPanel/KeybindButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UISound.connect_all_buttons(self)
	UISound.apply_wood_buttons(self) ## bkz. ui_sound.gd - tüm butonları ahşap stile çevirir
	$Panel/VBox/ResumeButton.pressed.connect(_on_resume)
	$Panel/VBox/RestartButton.pressed.connect(_on_restart)
	$Panel/VBox/MenuButton.pressed.connect(_on_menu)
	$Panel/VBox/SettingsButton.pressed.connect(_on_settings_pressed)
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
	## Çok oyunculuda "Yeniden Başlat" güvenli değil (sadece kendi ekranını
	## resetler, diğer peer'leri koptuğunu bilmeden askıda bırakır) - bkz.
	## _on_menu/_on_restart üstündeki notlar, bu yüzden o modda gizleniyor.
	if NetworkManager.is_multiplayer_active:
		$Panel/VBox/RestartButton.visible = false


## #28 DÜZELTME: main.gd _toggle_pause() artık multiplayer'da get_tree().
## paused KULLANMIYOR (bkz. o dosyadaki not) - bu menü DOĞRUDAN (ESC'ye değil,
## kendi butonuna) kapandığında da aynı şekilde SADECE bu istemcinin kendi
## karakterinin hareket kilidini açması gerekiyor, yoksa "Devam Et"e basan
## oyuncu menü kapandıktan sonra da hareketsiz kalırdı.
func _unlock_local_input() -> void:
	get_tree().paused = false
	if NetworkManager.is_multiplayer_active:
		var local_player: Node = get_tree().get_first_node_in_group("player")
		if local_player and local_player.has_method("set_menu_input_locked"):
			local_player.call("set_menu_input_locked", false)


func _on_resume() -> void:
	_unlock_local_input()
	queue_free()


func _on_restart() -> void:
	if NetworkManager.is_multiplayer_active:
		return
	_unlock_local_input()
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## Kullanıcı bildirimi: "host oyunu kapattığında veya ana menüye döndüğünde
## diğer oyuncuların bağlantısı kesilmiyor oyuna devam edebiliyorlar" - eskiden
## burada sahne DOĞRUDAN değiştiriliyordu, NetworkManager bağlantısı hiç
## kapatılmıyordu (multiplayer_peer sahne değişse bile SceneTree seviyesinde
## açık kalmaya devam eder). Artık host ise close_room() ile TÜM peer'lere
## "oda kapandı" bildirilip bağlantı düzgünce kesiliyor, client ise sadece
## kendi bağlantısını kesiyor.
func _on_menu() -> void:
	_unlock_local_input()
	if NetworkManager.is_multiplayer_active:
		if NetworkManager.is_host:
			NetworkManager.close_room()
		else:
			NetworkManager.disconnect_from_room(false)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_settings_pressed() -> void:
	settings_panel.visible = true
	volume_slider.grab_focus()


func _on_settings_closed() -> void:
	settings_panel.visible = false
	$Panel/VBox/SettingsButton.grab_focus()


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


## Kullanıcı isteği: "tuş ataması için ayarlarda bir menü hazırla, ayarlar
## paneli ufak olduğu için ona sığmaz" - mevcut 560x460 SettingsPanel'in
## ÜSTÜNE değil, onu gizleyip kendi büyük penceresini açan ayrı bir popup
## (bkz. keybind_menu.gd).
func _on_keybind_pressed() -> void:
	settings_panel.visible = false
	var menu := KeybindMenuScript.new()
	add_child(menu)
	menu.closed.connect(func() -> void:
		if is_instance_valid(settings_panel):
			settings_panel.visible = true
	)
