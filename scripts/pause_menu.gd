extends CanvasLayer

## DURAKLATMA (ESC) MENÜSÜ - "B - Ateş Işığı" (2026-10-17, madde 234; prototip madde 229, kullanıcı "B" seçti).
## Ana menünün D dili (madde 192): kutu yok, oyun dünyası hafif kararır + sol basamaklı gölge, büyük altın başlık + koşu satırı
## (kademe / süre / takım seviyesi) + kiriş süsü, öğeler mum + ikon + başlık + alt yazı. "Ayarlar" aynı katmanda ortak
## settings_screen.gd'yi açar (sol sütun kategorilere döner) - eski bej pencere + ayrı Grafik / Tuş Atamaları pencereleri kalktı.
## Sahne (pause_menu.tscn) sadece kök + betik; arayüz kodla kurulur. Yeniden başlatma / ana menü / çok oyunculu davranışı aynı.

const FM := preload("res://scripts/fire_menu_kit.gd")
const DK := preload("res://scripts/menu_dark_kit.gd")
const UiAnim := preload("res://scripts/ui_anim.gd")
const SettingsScreenScript := preload("res://scripts/settings_screen.gd")
const TierDisplayScript := preload("res://scripts/tier_display.gd")
const LobbyUI := preload("res://scripts/menu_lobby_ui.gd")

var _root: Control = null
var _main_view: Control = null
var _items: Array[Button] = []
var _resume_btn: Button = null
var _settings_btn: Button = null
var _restart_btn: Button = null
var _menu_btn: Button = null
var _settings: Control = null


func _ready() -> void:
	add_to_group(&"gamepad_modal") ## kumandayla menü gezinmesi: açılınca ilk düğmeye odak (bkz. gamepad_ui.gd)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 91 ## modal ekranlar 90+: HUD + sohbet (40) üstünde, yeniden başlatma onayı / ölüm ekranı (95) altında
	var mp: bool = NetworkManager.is_multiplayer_active
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP ## oyun dünyasına tıklama geçmesin
	_root.theme = DK.theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.10, 0.06, 0.03, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_root.add_child(FM.left_shade())

	_main_view = Control.new()
	_main_view.name = "MainView"
	_main_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_main_view)
	## Çok oyunculuda oyun durmaz (main.gd _toggle_pause: sadece yerel karakter kilitlenir) - başlık bunu söylesin.
	var sub := DK.v(0)
	sub.add_child(_run_line())
	if mp:
		sub.add_child(FM.lbl("Oyun sürüyor - karakterin bekliyor", DK.FS_LABEL, FM.C_RED))
	var logo := FM.title_block("MENÜ" if mp else "DURAKLATILDI", sub)
	_main_view.add_child(logo)
	logo.position = FM.TITLE_POS

	var v := DK.v(0)
	v.name = "MenuPanel"
	var portrait: Texture2D = LobbyUI.face_texture(str(Characters.get_def(GameManager.selected_char_id).get("portrait", "")))
	_resume_btn = FM.item("DEVAM ET", "Kaldığın yerden sürdür",
			FM.tex_icon(portrait) if portrait else null)
	_resume_btn.name = "ResumeButton"
	_settings_btn = FM.item("AYARLAR", "Ses, ekran, grafik, tuşlar", FM.tex_icon(load("res://assets/items/tornavida.png")))
	_settings_btn.name = "SettingsButton"
	_restart_btn = FM.item("YENİDEN BAŞLA", _restart_sub(), FM.tex_icon(load("res://assets/items/zaman_kiran.png")))
	_restart_btn.name = "RestartButton"
	var menu_sub := "Koşu burada biter"
	if mp:
		menu_sub = "Oda kapanır, herkes çıkar" if NetworkManager.is_host else "Odadan ayrılırsın"
	_menu_btn = FM.item("ANA MENÜ", menu_sub, FM.tex_icon(load("res://assets/items/ruzgar_yuruyen_cizmeleri.png")), true)
	_menu_btn.name = "MenuButton"
	for b: Button in [_resume_btn, _settings_btn, _restart_btn, _menu_btn]:
		v.add_child(b)
		_items.append(b)
	_main_view.add_child(v)
	v.position = FM.COL_POS
	v.custom_minimum_size.x = FM.COL_W
	var hint := FM.hint([["ESC", "devam et"], ["W/S", "seç"], ["Enter", "onayla"]])
	_main_view.add_child(hint)
	hint.position = Vector2(64, 1000)
	UISound.connect_all_buttons(self)

	_resume_btn.pressed.connect(_on_resume)
	_restart_btn.pressed.connect(_on_restart)
	_menu_btn.pressed.connect(_on_menu)
	_settings_btn.pressed.connect(_on_settings_pressed)
	## Çok oyunculuda yeniden başlatmayı SADECE host görür ve basması bir onay oylaması başlatır (bkz. _on_restart,
	## NetworkManager.request_restart_vote); client'lar sadece gelen onay isteğine cevap verir (main.gd _on_restart_request_received).
	if mp and not NetworkManager.is_host:
		_restart_btn.visible = false
	if mp and NetworkManager.is_host:
		## Oylama reddedilirse/zaman aşımına uğrarsa (asıl toast/unpause işi main.gd _on_restart_vote_result) menü hâlâ açıksa
		## "onay bekleniyor" donuk hâlinde kalmasın.
		NetworkManager.restart_vote_result.connect(func(_approved: bool, _rejecter: String):
			if is_instance_valid(self) and is_instance_valid(_restart_btn):
				_restart_btn.disabled = false
				FM.set_texts(_restart_btn, "YENİDEN BAŞLA", _restart_sub())
				FM.set_selected(_restart_btn, _restart_btn.has_focus())
		)
	UiAnim.cascade(v, 0.04)
	_resume_btn.grab_focus.call_deferred()


func _restart_sub() -> String:
	return "Herkesin onayıyla baştan" if NetworkManager.is_multiplayer_active else "Aynı karakterle baştan"


## "KADEME IV  ◆  12:34  ◆  SEVİYE 18" (GameManager.run_max_tier / run_elapsed / team_level)
func _run_line() -> HBoxContainer:
	var h := DK.h(14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: int = int(GameManager.run_elapsed())
	var parts: Array[String] = ["KADEME " + TierDisplayScript.to_roman(maxi(GameManager.run_max_tier, 1)),
			"%d:%02d" % [t / 60, t % 60], "SEVİYE %d" % GameManager.team_level]
	for i in parts.size():
		if i > 0:
			h.add_child(DK.glyph(FM.G_DIAMOND, FM.C_GOLD_DIM, 2))
		h.add_child(FM.lbl(parts[i], DK.FS_BODY, FM.C_TAG))
	return h


## #28 DÜZELTME: main.gd _toggle_pause() multiplayer'da get_tree().paused KULLANMIYOR - bu menü DOĞRUDAN (ESC'ye değil,
## kendi düğmesine) kapandığında da aynı şekilde SADECE bu istemcinin kendi karakterinin hareket kilidini açması gerekiyor,
## yoksa "Devam Et"e basan oyuncu menü kapandıktan sonra da hareketsiz kalırdı.
func _unlock_local_input() -> void:
	get_tree().paused = false
	if NetworkManager.is_multiplayer_active:
		var local_player: Node = get_tree().get_first_node_in_group("player")
		if local_player and local_player.has_method("set_menu_input_locked"):
			local_player.call("set_menu_input_locked", false)


func _on_resume() -> void:
	_unlock_local_input()
	queue_free()


## Tek oyunculuda menü açılınca get_tree().paused=true olur ve main.gd'nin _process'i durur - ikinci ESC'yi bu menü (ALWAYS)
## yakalar. Çok oyunculuda ağaç durmaz, ESC'yi main.gd'nin "pause_game" denetimi işler (burada no-op). Ayarlar açıkken ESC
## ayarlar ekranınındır (settings_screen.gd kapanırken mark_ui_cancel_consumed - aynı basış menüyü de kapatmasın).
func _process(_delta: float) -> void:
	if not get_tree().paused:
		return
	## Host "yeniden başlatma onayı" beklerken de (çok oyunculuda BİLEREK) paused=true - oylama sonucu main.gd'de yönetilir.
	if NetworkManager.is_multiplayer_active and NetworkManager.restart_vote_pending:
		return
	if is_instance_valid(_settings) or GameManager.was_ui_cancel_consumed():
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_on_resume()


## Öğeler arasında W/S (oklar/D-pad zaten Godot odak gezinmesiyle çalışır).
func _input(event: InputEvent) -> void:
	if is_instance_valid(_settings) or not _main_view.visible:
		return
	var d := 0
	if InputMap.has_action("move_up") and event.is_action_pressed("move_up", true) and not event is InputEventJoypadMotion:
		d = -1
	elif InputMap.has_action("move_down") and event.is_action_pressed("move_down", true) and not event is InputEventJoypadMotion:
		d = 1
	if d == 0:
		return
	var vis: Array[Button] = []
	for b in _items:
		if b.visible and not b.disabled:
			vis.append(b)
	if vis.is_empty():
		return
	var cur: int = -1
	for i in vis.size():
		if vis[i].has_focus():
			cur = i
	vis[clampi(cur + d, 0, vis.size() - 1) if cur >= 0 else 0].grab_focus()
	get_viewport().set_input_as_handled()


## Çok oyunculuda (SADECE host görür) doğrudan resetlemek yerine onay oylaması başlatılır (network_manager.gd "YENİDEN BAŞLATMA
## ONAYI"); gerçek yeniden başlatma herkes onaylarsa main.gd _on_restart_vote_result -> _rpc_start_game ile olur.
func _on_restart() -> void:
	if NetworkManager.is_multiplayer_active:
		if not NetworkManager.is_host or NetworkManager.restart_vote_pending:
			return
		NetworkManager.request_restart_vote()
		## Diğer oyuncular cevap verene kadar oyunu duraklat (client'larda da aynı, bkz. main.gd _on_restart_request_received).
		get_tree().paused = true
		_restart_btn.disabled = true
		FM.set_texts(_restart_btn, "ONAY BEKLENİYOR", "Diğer oyuncuların cevabı bekleniyor")
		FM.set_selected(_restart_btn, false)
		_resume_btn.grab_focus()
		return
	_unlock_local_input()
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## Host ise close_room() ile TÜM peer'lere "oda kapandı" bildirilip bağlantı düzgünce kesilir, client sadece kendi bağlantısını
## keser (eskiden sahne doğrudan değişiyor, diğer oyuncular oyunda kalıyordu).
func _on_menu() -> void:
	_unlock_local_input()
	await NetworkManager.flush_balance_before_leave() ## koşu kaydı bağlantı kesilmeden host'a ulaşsın
	if NetworkManager.is_multiplayer_active:
		if NetworkManager.is_host:
			NetworkManager.close_room()
		else:
			NetworkManager.disconnect_from_room(false)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_settings_pressed() -> void:
	if is_instance_valid(_settings):
		return
	_main_view.visible = false
	_settings = SettingsScreenScript.new("Duraklatma menüsüne dön", 0.8)
	_settings.closed.connect(_on_settings_closed)
	_root.add_child(_settings)


func _on_settings_closed() -> void:
	_settings = null
	_main_view.visible = true
	_settings_btn.grab_focus.call_deferred()


## Testler / araçlar için: açık ayarlar ekranı (yoksa null).
func get_settings_screen() -> Control:
	return _settings if is_instance_valid(_settings) else null
