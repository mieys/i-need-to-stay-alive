extends CanvasLayer

const KeybindMenuScript := preload("res://scripts/keybind_menu.gd")

@onready var settings_panel: Panel = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/VolumeSlider
@onready var volume_value: Label = $SettingsPanel/VolumeValue
@onready var fullscreen_check: CheckButton = $SettingsPanel/FullscreenCheck
@onready var resolution_option: OptionButton = $SettingsPanel/ResolutionOption
@onready var fps_check: CheckButton = $SettingsPanel/FpsCheck
@onready var keybind_button: Button = $SettingsPanel/KeybindButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UISound.connect_all_buttons(self)
	UISound.apply_wood_buttons(self) ## bkz. ui_sound.gd - tüm butonları ahşap stile çevirir
	## Kullanıcı isteği (2026-09-21): duraklatma/ayar panelleri UIKit ahşap pencere çerçevesinde (konum/boyut aynı).
	$Panel.add_theme_stylebox_override("panel", UIKit.panel_style("window"))
	$SettingsPanel.add_theme_stylebox_override("panel", UIKit.panel_style("window"))
	## Kullanıcı isteği (2026-09-24): oyun içi arayüzler menülerle aynı bej/ahşap kite geçti - panellerin kendi teması
	## (koyu yazı, kit kaydırıcı/açma-kapama/açılır liste), sıcak karartma, başlıklar kiremit vurgu renginde 48 px.
	var game_theme: Theme = UIKit.theme()
	$Panel.theme = game_theme
	$SettingsPanel.theme = game_theme
	$Dim.color = Color(0.12, 0.07, 0.03, 0.55)
	for title: Label in [$Panel/VBox/Title, $SettingsPanel/Title]:
		UIKit.style_label(title, UIKit.FS_TITLE, UIKit.C_ACCENT, 0)
	## DÜZELTME: "DURAKLATILDI" başlığı hiç görünmüyordu - sahnede clip_text + autowrap birlikte açıktı, bu ikilide Label minimum
	## yüksekliğini 1 px bildiriyor, VBox ona 1 px verip hiçbir satır çizilmiyordu (çalışma anında ölçüldü: rect yüksekliği 1,
	## visible_lines 0). Tek satırlık kısa başlık - kaydırma/kırpmaya gerek yok.
	var pause_title: Label = $Panel/VBox/Title
	pause_title.clip_text = false
	pause_title.autowrap_mode = TextServer.AUTOWRAP_OFF
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
	## Kullanıcı isteği: "fps göstergesi ekle ayarlardan açılıp kapatılabilsin" -
	## fullscreen_check ile BİREBİR AYNI desen (UISound'daki show_fps'e bağlı).
	fps_check.button_pressed = UISound.show_fps
	fps_check.toggled.connect(_on_fps_toggled)
	settings_panel.visible = false
	## DÜZELTME (kullanıcı isteği: "Multiplayerda host oyunu yeniden
	## başlatabilsin eskiden yeniden başlatmayı seçerek fakat önce diğer
	## oyunculara onayı sorulsun") - eskiden çok oyunculuda bu buton
	## TAMAMEN gizliydi (sadece kendi ekranını resetleyip diğer peer'leri
	## askıda bırakırdı). Artık SADECE host görebiliyor (client'larda hâlâ
	## gizli - onlar isteği başlatamaz, sadece gelen onay isteğine cevap
	## verir, bkz. main.gd _on_restart_request_received) ve host'un basması
	## gerçek bir yeniden başlatma YERİNE bir onay oylaması başlatıyor (bkz.
	## _on_restart, NetworkManager.request_restart_vote).
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		$Panel/VBox/RestartButton.visible = false
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		## Oylama reddedilirse/zaman aşımına uğrarsa (bkz. main.gd
		## _on_restart_vote_result - asıl toast/unpause işini o yapar) bu menü
		## hâlâ açıksa butonu "Onay bekleniyor..." donuk halinde bırakmamak
		## için normale döndürür.
		NetworkManager.restart_vote_result.connect(func(_approved: bool, _rejecter: String):
			if is_instance_valid(self):
				$Panel/VBox/RestartButton.disabled = false
				$Panel/VBox/RestartButton.text = "Yeniden Başla"
		)


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


## DÜZELTME (kullanıcı isteği: "gamepad desteği ekle" - kök neden analizi
## sırasında bulunan mevcut hata): tekli oyuncuda menü açılınca get_tree().
## paused=true olur, ve bunu tetikleyen main.gd'nin KENDİ _process()'i
## (varsayılan PROCESS_MODE_PAUSABLE) tam o anda duraklar - yani main.gd
## İKİNCİ bir ESC/gamepad-B basışını GÖREMEZ, menü bugüne kadar SADECE
## "Devam Et" butonuyla kapanabiliyordu. Bu panel zaten PROCESS_MODE_ALWAYS
## olduğu için (bkz. _ready()) kendi kontrolünü ekliyoruz.
##
## Çift tetiklenme YOK: bu kontrol SADECE get_tree().paused iken çalışıyor -
## bu sadece tekli oyuncuda true olabiliyor (_on_restart()'ın çok oyunculu
## dalı HARİÇ, bkz. aşağıdaki restart_vote_pending koruması), ve tam o anda
## main.gd'nin kendi _process'i zaten donmuş durumda - ikisi asla aynı
## karede aktif olamaz. Çok oyunculuda (normal durumda) bu her zaman no-op
## (ağaç hiç duraklamıyor), mevcut multiplayer-güvenli davranış korunuyor.
func _process(_delta: float) -> void:
	if not get_tree().paused:
		return
	## İSTİSNA: host bir "yeniden başlatma onayı" bekliyorken de (çok
	## oyunculuda BİLEREK) get_tree().paused=true olur (bkz. _on_restart()
	## aşağıda) - bu bekleme durumu ui_cancel ile ERKEN kapatılmamalı, oylama
	## sonucu main.gd _on_restart_vote_result üzerinden merkezi olarak
	## yönetiliyor (reddedilirse/zaman aşımında ORADA açılıyor).
	if NetworkManager.is_multiplayer_active and NetworkManager.restart_vote_pending:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_on_resume()


## DÜZELTME (kullanıcı isteği: "Multiplayerda host oyunu yeniden başlatabilsin
## fakat önce diğer oyunculara onayı sorulsun") - multiplayer'da (SADECE
## host bu butonu görebiliyor, bkz. _ready) artık doğrudan resetlemek yerine
## bir onay oylaması başlatılıyor (bkz. network_manager.gd "YENİDEN BAŞLATMA
## ONAYI" bloğu) - gerçek yeniden başlatma SADECE herkes onaylarsa, sonucu
## main.gd _on_restart_vote_result üzerinden işleyip _rpc_start_game()
## çağırınca gerçekleşir.
func _on_restart() -> void:
	if NetworkManager.is_multiplayer_active:
		if not NetworkManager.is_host or NetworkManager.restart_vote_pending:
			return
		NetworkManager.request_restart_vote()
		## Diğer oyuncular cevap verene kadar oyunu duraklat (bkz. main.gd
		## _on_restart_request_received - client'larda AYNI şekilde duraklıyor,
		## _on_restart_vote_result reddedilirse/zaman aşımında herkes için
		## açıyor) - host da dahil, kimse oylama bitmeden ilerlemesin.
		get_tree().paused = true
		$Panel/VBox/RestartButton.disabled = true
		$Panel/VBox/RestartButton.text = "Onay bekleniyor..."
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


func _on_fps_toggled(enabled: bool) -> void:
	UISound.set_show_fps(enabled)


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
