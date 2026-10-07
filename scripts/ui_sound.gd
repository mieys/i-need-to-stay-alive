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
## Kullanıcı isteği (2026-09-25): "arayüzler için ayarlara opaklık ayarı getir". Oyun içi KALICI arayüz parçaları
## (can/kalkan kümesi, yetenek çubuğu, XP çubuğu, minimap, altın, grup paneli, sohbet, görev penceresi...) bu opaklıkla
## çizilir - kendilerini UI_OPACITY_GROUP'a register_ui_opacity() ile kaydederler (bkz. hud.gd, main.gd). Açılır/modal
## pencereler (dükkan, envanter, level kartları, duraklatma) kaydedilmez: onlar her zaman tam opak (okunabilir) kalır.
## show_fps ile AYNI "display" ConfigFile bölümü. %25'in altına inmez (arayüz tamamen kaybolmasın).
const UI_OPACITY_GROUP := &"ui_opacity"
const UI_OPACITY_MIN_PERCENT := 25.0
var ui_opacity_percent: float = 100.0
## EKRAN SARSINTISI (kullanıcı isteği 2026-10-05: "ayarlara kapatma özelliği de ekle"): 0 = kapalı, 100 = tam güç. Hareket hassasiyeti
## olanlar için erişilebilirlik ayarı. camera_shake.gd her olayda ve her karede okur. Aynı "display" ConfigFile bölümü.
var camera_shake_percent: float = 100.0

## GRAFİK AYARLARI - kullanıcı isteği (2026-10-03): "bunu mobil için optimize etmenin en iyi yolu oyuna grafik ayarı
## eklemek" -> "Düşük / Orta / Yüksek" hazır seviye + altında tek tek seçenekler (biri elle değişince seviye "Özel" olur);
## "bu ayar pc sürümünde de olsun". Varsayılan her yerde Yüksek (kullanıcı seçimi). Kazançlar Galaxy S22'de ölçüldü (bkz.
## perf_probe.gd): güneş/bulut kare -1.8 ms, zemin ayrıntısı GPU -0.9 ms. Sis seçenek DEĞİL (oyun mekaniği, düşman gizler).
## Uygulayanlar graphics_changed sinyalini dinler / değeri her kare okur: sun_clouds.gd (güneş/bulut), ground_texel_pass.gd
## (zemin ayrıntısı), world_render_scale.gd (çözünürlük ölçeği). FPS sınırı seviyelere DAHİL DEĞİL (ayrı ayar): PC'de
## varsayılan sınırsız (eskisi gibi), telefonda 60 (mobile_ui.gd'nin eski sabiti). Ekran: graphics_settings_menu.gd.
## Aynı "display" ConfigFile bölümü.
signal graphics_changed
enum GfxPreset { LOW, MEDIUM, HIGH, CUSTOM }
const GFX_PRESET_NAMES: Array[String] = ["Düşük", "Orta", "Yüksek", "Özel"]
## Seviye -> [güneş/bulut, zemin ayrıntısı, çözünürlük ölçeği]
const GFX_PRESET_VALUES := {
	GfxPreset.LOW: [false, false, 0.75],
	GfxPreset.MEDIUM: [false, true, 1.0],
	GfxPreset.HIGH: [true, true, 1.0],
}
const RENDER_SCALES: Array[float] = [1.0, 0.75, 0.5]
const FPS_LIMITS: Array[int] = [30, 60, 120, 0] ## 0 = sınırsız
var gfx_preset: int = GfxPreset.HIGH
var gfx_sun_clouds: bool = true
var gfx_ground_detail: bool = true
var gfx_render_scale: float = 1.0
var fps_limit: int = 0


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


## bkz. camera_shake_percent notu. 0 = kapalı.
func set_camera_shake_percent(percent: float) -> void:
	camera_shake_percent = clampf(percent, 0.0, 100.0)
	_save_display_settings()


## bkz. ui_opacity_percent notu.
func set_ui_opacity_percent(percent: float) -> void:
	ui_opacity_percent = clampf(percent, UI_OPACITY_MIN_PERCENT, 100.0)
	_save_display_settings()
	if is_inside_tree():
		for n: Node in get_tree().get_nodes_in_group(UI_OPACITY_GROUP):
			_apply_ui_opacity(n)


## Kalıcı bir arayüz parçasını opaklık ayarına bağlar (hemen uygular; ayar değişince de güncellenir).
func register_ui_opacity(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.add_to_group(UI_OPACITY_GROUP)
	_apply_ui_opacity(node)


func _apply_ui_opacity(node: Node) -> void:
	var ci := node as CanvasItem
	if ci == null:
		return
	var c: Color = ci.modulate
	c.a = ui_opacity_percent / 100.0
	ci.modulate = c


## bkz. GRAFİK AYARLARI notu.
func set_gfx_preset(preset: int) -> void:
	if not GFX_PRESET_VALUES.has(preset):
		return
	var v: Array = GFX_PRESET_VALUES[preset]
	gfx_sun_clouds = bool(v[0])
	gfx_ground_detail = bool(v[1])
	gfx_render_scale = float(v[2])
	gfx_preset = preset
	_save_display_settings()
	graphics_changed.emit()


## Tek bir seçenek elle değişti -> değerler bir hazır seviyeyle birebir eşleşiyorsa o seviye, yoksa "Özel".
func set_gfx_option(key: String, value: Variant) -> void:
	match key:
		"sun_clouds": gfx_sun_clouds = bool(value)
		"ground_detail": gfx_ground_detail = bool(value)
		"render_scale": gfx_render_scale = _nearest_render_scale(float(value))
		_: return
	gfx_preset = _matching_preset()
	_save_display_settings()
	graphics_changed.emit()


func set_fps_limit(limit: int) -> void:
	fps_limit = limit if FPS_LIMITS.has(limit) else _default_fps_limit()
	_apply_fps_limit()
	_save_display_settings()


func _matching_preset() -> int:
	for p: int in GFX_PRESET_VALUES:
		var v: Array = GFX_PRESET_VALUES[p]
		if bool(v[0]) == gfx_sun_clouds and bool(v[1]) == gfx_ground_detail and is_equal_approx(float(v[2]), gfx_render_scale):
			return p
	return GfxPreset.CUSTOM


func _nearest_render_scale(v: float) -> float:
	var best: float = RENDER_SCALES[0]
	for r: float in RENDER_SCALES:
		if absf(r - v) < absf(best - v):
			best = r
	return best


## Telefonda 60 (sınırsız çizim ısınıp yavaşlatıyor - bkz. mobile_ui.gd), PC'de sınırsız (eskisi gibi).
func _default_fps_limit() -> int:
	return 60 if (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")) else 0


func _apply_fps_limit() -> void:
	Engine.max_fps = fps_limit


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
	config.set_value("display", "ui_opacity_percent", ui_opacity_percent)
	config.set_value("display", "camera_shake_percent", camera_shake_percent)
	config.set_value("display", "gfx_sun_clouds", gfx_sun_clouds)
	config.set_value("display", "gfx_ground_detail", gfx_ground_detail)
	config.set_value("display", "gfx_render_scale", gfx_render_scale)
	config.set_value("display", "fps_limit", fps_limit)
	config.save(DISPLAY_SETTINGS_PATH)


func _load_display_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(DISPLAY_SETTINGS_PATH) == OK:
		is_fullscreen = bool(config.get_value("display", "is_fullscreen", true))
		resolution_index = clamp(int(config.get_value("display", "resolution_index", DEFAULT_RESOLUTION_INDEX)), 0, RESOLUTIONS.size() - 1)
		show_fps = bool(config.get_value("display", "show_fps", false))
		ui_opacity_percent = clampf(float(config.get_value("display", "ui_opacity_percent", 100.0)), UI_OPACITY_MIN_PERCENT, 100.0)
		camera_shake_percent = clampf(float(config.get_value("display", "camera_shake_percent", 100.0)), 0.0, 100.0)
		gfx_sun_clouds = bool(config.get_value("display", "gfx_sun_clouds", true))
		gfx_ground_detail = bool(config.get_value("display", "gfx_ground_detail", true))
		gfx_render_scale = _nearest_render_scale(float(config.get_value("display", "gfx_render_scale", 1.0)))
		fps_limit = int(config.get_value("display", "fps_limit", _default_fps_limit()))
	else:
		fps_limit = _default_fps_limit()
	if not FPS_LIMITS.has(fps_limit):
		fps_limit = _default_fps_limit()
	gfx_preset = _matching_preset()
	_apply_fps_limit()
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_apply_resolution()
