extends Node

## Tüm arayüz (UI) tıklama sesi: menülerdeki HERHANGİ bir Button'a (BaseButton
## türevi - Button, CheckButton, TextureButton...) basıldığında çalar.
## "spam gibi hissettirmesin" isteğiyle HER tıklamada hafif farklı bir perde
## kullanılır (bkz. play_click). Sahneler arası (dükkan, seviye atlama, duraklat
## menüsü, ana menü, karakter seçimi, HUD'daki kalkan modu butonları, F9 debug
## paneli...) TEK, paylaşılan bir AudioStreamPlayer ile çalışır - autoload
## olduğu için her panelin kendi ses node'unu oluşturmasına gerek kalmaz.
##
## Kullanım: her panelin/menünün _ready()'sinde tek satır yeter:
##   UISound.connect_all_buttons(self)
## Bu, o kök node'un altındaki (kendisi dahil) TÜM Button'ları bulup pressed
## sinyalini play_click()'e bağlar - yeni bir buton eklenirse otomatik dahil
## olur, ayrı ayrı bağlamaya gerek kalmaz. Zaten bağlıysa tekrar bağlamaz
## (sahne yeniden açılıp _ready() tekrar çalıştığında çift ses çalmasın diye).

const CLICK_SOUND := preload("res://assets/audio/ui_click.wav")
const SETTINGS_PATH := "user://audio_settings.cfg"
const MASTER_BUS_NAME := "Master"

var _player: AudioStreamPlayer
var master_volume_percent: float = 100.0

## Kullanıcı isteği: "oyunumun ayarlarına çözünürlük ve tam ekran özelliği
## ekle. çözünürlük ve tam ekran değiştirilebilsin. exclusive olmasın tam
## ekran hali." - ses ayarlarıyla AYNI ConfigFile deseni, ayrı bir dosyada
## (bkz. DISPLAY_SETTINGS_PATH). Bu autoload zaten tüm menülerden erişilebilir
## olduğu için ("UISound.xxx") görüntü ayarlarını da burada tutmak, ayrı bir
## autoload eklemekten daha az risk taşıyor.
const DISPLAY_SETTINGS_PATH := "user://display_settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const DEFAULT_RESOLUTION_INDEX := 2 ## 1920x1080 - project.godot'un varsayılanıyla eşleşir

var is_fullscreen: bool = true
var resolution_index: int = DEFAULT_RESOLUTION_INDEX
## Kullanıcı isteği: "oyuna fps göstergesi ekle ayarlardan açılıp
## kapatılabilsin" - is_fullscreen/resolution_index ile AYNI "display" bölümü/
## ConfigFile'ı paylaşıyor, ayrı bir dosya/autoload YOK.
var show_fps: bool = false


func _ready() -> void:
	_load_audio_settings()
	_load_display_settings()
	## Duraklatma menüsü açıkken de (get_tree().paused = true) tıklama sesi
	## duyulsun diye - pause_menu.gd kendi butonlarını PROCESS_MODE_ALWAYS
	## yapıyor, bu da aynı sebeple AudioStreamPlayer'a uygulanmalı, yoksa
	## sahne duraklatılınca ses "duraklatılmış" sayılıp çalmaz.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.stream = CLICK_SOUND
	_player.volume_db = -6.0
	add_child(_player)


func play_click() -> void:
	if not _player:
		return
	_player.pitch_scale = randf_range(0.9, 1.1)
	_player.play()


func set_master_volume_percent(percent: float) -> void:
	master_volume_percent = clamp(percent, 0.0, 100.0)
	var bus_index: int = AudioServer.get_bus_index(MASTER_BUS_NAME)
	if bus_index < 0:
		return
	var linear_volume: float = master_volume_percent / 100.0
	var volume_db: float = -80.0 if linear_volume <= 0.0 else linear_to_db(linear_volume)
	AudioServer.set_bus_volume_db(bus_index, volume_db)
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "master_volume_percent", master_volume_percent)
	config.save(SETTINGS_PATH)


func _load_audio_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume_percent = float(config.get_value("audio", "master_volume_percent", 100.0))
	set_master_volume_percent(master_volume_percent)


func connect_all_buttons(root: Node) -> void:
	_connect_recursive(root)


func _connect_recursive(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(play_click):
		node.pressed.connect(play_click)
	for child in node.get_children():
		_connect_recursive(child)


## Kullanıcı isteği: "oyundaki bütün butonları bununla değiştirmeni
## istiyorum. tıklanabilen bütün butonlar bununla değişecek" (ahşap plaka
## görseli) - connect_all_buttons() ile BİREBİR AYNI "kök node'un altındaki
## HER Button'ı bul" deseni, tek fark sese bağlamak yerine ShopPanel'in
## paylaşılan ahşap stilini uyguluyor (bkz. shop_panel.gd
## _apply_wood_button_style/_make_wood_button_style - doku/margin/ton
## sabitlerinin TEK kaynağı orada, burada İKİNCİ bir kopyası YOK). Her
## panelin/menünün _ready()'sinde connect_all_buttons(self)'in HEMEN
## yanına eklenmesi yeterli - yeni bir buton eklenirse otomatik dahil olur.
func apply_wood_buttons(root: Node) -> void:
	_apply_wood_recursive(root)


## Envanter/dükkan gibi panellerde bazı Button'lar gerçek "metin etiketli"
## aksiyon butonu DEĞİL, üstünde bir eşya/silah ikonu gösteren KARE bir slot
## çerçevesi (bkz. inventory_panel.gd silah/kalkan/yardımcı eşya/satış
## slotları, hepsi 62x62 kare) - ahşap plaka görseli (94x34, enine dikdörtgen)
## böyle kare bir slota basılırsa ikonun arkasında anlamsız/bozuk görünürdü.
## Bu yüzden SABİT KARE/DİKEY oranlı custom_minimum_size'ı olan butonlar
## (slot/kart tarzı ikon konteynerları) bilerek atlanıyor - gerçek metin
## butonları genelde ya boyutu container'a bırakır (0,0) ya da enine
## dikdörtgen bir custom_minimum_size kullanır, ikisi de bu filtreden geçer.
func _looks_like_icon_slot(btn: Button) -> bool:
	var sz: Vector2 = btn.custom_minimum_size
	return sz.x > 0.0 and sz.y > 0.0 and sz.y > sz.x * 0.6


func _apply_wood_recursive(node: Node) -> void:
	if node is Button and not _looks_like_icon_slot(node):
		ShopPanel._apply_wood_button_style(node)
	for child in node.get_children():
		_apply_wood_recursive(child)


## bkz. sınıf üstü DISPLAY_SETTINGS notu. "exclusive olmasın" isteği:
## WINDOW_MODE_EXCLUSIVE_FULLSCREEN (bazı sistemlerde alt-tab/pencere
## değiştirmede sorun çıkarabilen "gerçek" özel tam ekran) DEĞİL,
## WINDOW_MODE_FULLSCREEN (kenarlıksız, pencere yöneticisiyle uyumlu)
## kullanılıyor - project.godot'un mevcut window/size/mode=3 varsayılanıyla
## da AYNI mod.
func set_fullscreen(enabled: bool) -> void:
	is_fullscreen = enabled
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_apply_resolution()
	_save_display_settings()


func set_resolution(index: int) -> void:
	resolution_index = clamp(index, 0, RESOLUTIONS.size() - 1)
	if not is_fullscreen:
		_apply_resolution()
	_save_display_settings()


func set_show_fps(enabled: bool) -> void:
	show_fps = enabled
	_save_display_settings()


func get_resolution_labels() -> Array[String]:
	var labels: Array[String] = []
	for r in RESOLUTIONS:
		labels.append("%dx%d" % [r.x, r.y])
	return labels


func _apply_resolution() -> void:
	var size: Vector2i = RESOLUTIONS[resolution_index]
	DisplayServer.window_set_size(size)
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	DisplayServer.window_set_position((screen_size - size) / 2)


func _save_display_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("display", "is_fullscreen", is_fullscreen)
	config.set_value("display", "resolution_index", resolution_index)
	config.set_value("display", "show_fps", show_fps)
	config.save(DISPLAY_SETTINGS_PATH)


func _load_display_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(DISPLAY_SETTINGS_PATH) == OK:
		is_fullscreen = bool(config.get_value("display", "is_fullscreen", true))
		resolution_index = clamp(int(config.get_value("display", "resolution_index", DEFAULT_RESOLUTION_INDEX)), 0, RESOLUTIONS.size() - 1)
		show_fps = bool(config.get_value("display", "show_fps", false))
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_apply_resolution()
