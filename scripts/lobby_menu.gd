extends Control

## Çok oyunculu KARAKTER SEÇİMİ. 2026-10-16 (kullanıcı: "oda kurulduktan sonra direk karakter seçim ekranına geçilsin ve o esnada
## oyuncular bağlansın"): oda kurulunca/katılınca DOĞRUDAN burası açılır (oda lobisi aşaması yok). MASAÜSTÜ yerleşimi artık
## lobby_select_desktop.gd ("SEÇİM D", koyu kit menu_dark_kit.gd) - bu dosya onu kurar, ağ olaylarını iletir. Aşağıdaki eski
## yerleşim notu sadece TELEFON yerleşimi (_build_mobile) için geçerli.
## (eski) 2026-10-11 lobi sistemi (kullanıcı onaylı prototip A): bağlantı /
## oda kurma / katılma artık oda listesinde (room_browser.gd), toplanma oda lobisinde (room_lobby.gd); burası sadece seçim:
##   sol  : oda adı + "x / y hazır" + odadaki oyuncular (yüz portresi + seçtiği silah/ruhani ikon + HAZIR/SEÇİYOR rozeti) +
##          sohbet + HAZIRIM / OYUNU BAŞLAT (host) / LOBİYE DÖN (host) / ODADAN ÇIK
##   orta : kurdele başlık + karakter kartları (YÜZ portreli, bkz. menu_character_card.gd face) + yetenek bilgi paneli +
##          başlangıç silahı satırı ("Değiştir" -> 15 silahın açılır ızgarası, menu_weapon_picker.gd)
##   sağ  : seçili karakterin vitrini (tam boy, idle animasyonlu) + Ruhani Yetenek seçici
## Hazır olan oyuncunun seçimleri kilitlenir (orta + sağ üstünde yarı saydam kilit; HAZIR DEĞİLİM ile açılır).
## Host "LOBİYE DÖN" derse herkes oda lobisine döner (NetworkManager.set_lobby_phase). Yeniden başlatma oylaması onaylanınca
## herkes buraya döner (network_manager.gd _return_to_lobby_for_restart, restart_returned_to_lobby bayrağı).
## Telefon: kendi tam ekran yerleşimi (_build_mobile).

const SpiritualPickerScript: GDScript = preload("res://scripts/spiritual_picker.gd")
const RosterScript: GDScript = preload("res://scripts/menu_character_roster.gd")
const DetailsScript: GDScript = preload("res://scripts/menu_character_details.gd")
const ShowcaseScript: GDScript = preload("res://scripts/menu_character_showcase.gd")
const WeaponPickerScript: GDScript = preload("res://scripts/menu_weapon_picker.gd")
const PetPickerScript: GDScript = preload("res://scripts/menu_pet_picker.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const LobbyUI := preload("res://scripts/menu_lobby_ui.gd")
const ChatScript: GDScript = preload("res://scripts/menu_lobby_chat.gd")
const CharSelectScript: GDScript = preload("res://scripts/character_select.gd")
const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")
const DesktopScript: GDScript = preload("res://scripts/lobby_select_desktop.gd")
const HearthBg := preload("res://scripts/menu_hearth_bg.gd")

## Telefon kart ızgarası: yan yana 3 (kullanıcı isteği 2026-10-03 "karakterler 3 sıralı olsun").
const M_COLUMNS := 3
const M_TOPBAR_FRAC := 0.11
const M_LEFT_FRAC := 0.32
const M_RIGHT_FRAC := 0.26

var status_label: Label
var back_btn: Button
var room_info_label: Label
var player_list_container: VBoxContainer
var start_game_btn: Button
var ready_btn: Button
var close_room_btn: Button
var _desk: Control = null ## masaüstü SEÇİM D ekranı (telefonda null)

var roster: GridContainer
var details: PanelContainer
var showcase: PanelContainer

var selected_char_id: int = 1
var _viewing_locked: bool = false ## şu an kilitli bir karaktere bakılıyor (hazır/başlat kapalı)

var _mobile: bool = false
var _sz: Dictionary = {}
var _fs_body: int = MenuKit.FS_BODY
var _fs_small: int = MenuKit.FS_SMALL
var _ctl_h: float = 48.0
var _portrait_k: int = 1
## Hazırken seçim kilidi (orta + sağ alanın üstünde).
var _lock: Control = null
var _leaving: bool = false


func _ready() -> void:
	theme = MenuKit.theme()
	_mobile = MobileUIScript.enabled
	## Arka plan ana menüyle aynı "Ocak Başı" sahnesi (2026-10-16); masaüstünde koyu kite uysun diye kısılır.
	HearthBg.add_to(self, 0.0 if _mobile else HearthBg.DIM_DESKTOP)
	_sz = LobbyUI.sizes(_mobile)
	_fs_body = int(_sz["fs_body"])
	_fs_small = int(_sz["fs_small"])
	_ctl_h = float(_sz["ctl_h"])
	_portrait_k = int(_sz["k"])
	if LobbyUI.leave_if_disconnected(self):
		_leaving = true
		return
	## 2026-10-19 (madde 279): telefonda da SEÇİM D ekranı (lobby_select_desktop.gd) kurulur - o kendi telefon yerleşimini seçer
	## (_build_phone, prototip S = B). Aşağıdaki eski bej telefon kurucusu (_build_mobile) artık çağrılmıyor.
	_build_desktop()

	NetworkManager.lobby_updated.connect(_update_lobby_ui)
	NetworkManager.lobby_phase_changed.connect(_on_phase_changed)
	NetworkManager.connection_status_changed.connect(_on_status_changed)

	selected_char_id = NetworkManager.local_char_id if Characters.DEFS.has(NetworkManager.local_char_id) \
			and MetaProgressScript.is_unlocked(MetaProgressScript.CHAR, NetworkManager.local_char_id) else 1
	_on_character_pressed(selected_char_id)
	_update_lobby_ui()
	## Yeniden başlatma onaylandıysa (bkz. network_manager.gd _return_to_lobby_for_restart) herkes
	## buraya döner: karakter seçimi yeniden yapılır, hazır olunur, host oyunu başlatır.
	if NetworkManager.restart_returned_to_lobby:
		NetworkManager.restart_returned_to_lobby = false
		_set_status("Yeniden başlatma onaylandı: karakterini yeniden seç ve hazır ol, host oyunu başlatsın.")

	UISound.connect_all_buttons(self)


func _process(_delta: float) -> void:
	if not _leaving and LobbyUI.leave_if_disconnected(self):
		_leaving = true


func _place(c: Control, pos: Vector2, sz: Vector2) -> void:
	MenuKit.place(c, pos, sz)


func _build_desktop() -> void:
	## Ekran lobby_select_desktop.gd'de kurulur (arka plan _ready'de, menu_hearth_bg.gd).
	_desk = DesktopScript.new()
	add_child(_desk)
	_desk.call("build")
	_desk.connect("character_picked", _on_character_pressed)
	_desk.connect("start_pressed", _on_start_game_pressed)
	_desk.connect("ready_pressed", _on_ready_pressed)
	_desk.connect("leave_pressed", _on_close_room_pressed)


## ------------------------------------------------------------------ telefon
## TAM EKRAN + her telefona uyumlu (character_select.gd _build_mobile ile AYNI dil): üst şerit (Geri + başlık) + kenardan
## kenara üç panel, oransal genişlik: sol oda paneli (kaydırılabilir - oyuncular/sohbet), orta karakter kartları (3 sütun),
## sağ ruhani yetenek + başlangıç silahı. Güvenli kenar payına uyar.
func _build_mobile() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var safe: Rect2 = MobileUIScript.safe_margins(get_viewport())
	var x0: float = safe.position.x
	var x1: float = view.x - safe.size.x
	var y0: float = safe.position.y
	var y1: float = view.y - safe.size.y
	var w: float = x1 - x0
	var topbar_h: float = clampf(roundf(view.y * M_TOPBAR_FRAC), 96.0, 150.0)

	var bar := MenuKit.make_panel("panel_tight")
	add_child(bar)
	_place(bar, Vector2(x0, y0), Vector2(w, topbar_h))
	back_btn = MenuKit.make_button("< Kapat" if NetworkManager.is_host else "< Çık", "tan", 40, topbar_h - 24.0)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)
	_place(back_btn, Vector2(x0 + 12.0, y0 + 12.0), Vector2(240.0, topbar_h - 24.0))
	var title := MenuKit.make_label("Karakterini Seç", 48, MenuKit.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	_place(title, Vector2(x0, y0), Vector2(w, topbar_h))

	var body_y: float = y0 + topbar_h
	var body_h: float = y1 - body_y
	var left_w: float = roundf(w * M_LEFT_FRAC)
	var right_w: float = roundf(w * M_RIGHT_FRAC)
	var center_w: float = w - left_w - right_w

	var panel: PanelContainer = _build_lobby_panel()
	_place(panel, Vector2(x0, body_y), Vector2(left_w, body_h))

	var center := MenuKit.make_panel("panel_tight")
	add_child(center)
	_place(center, Vector2(x0 + left_w, body_y), Vector2(center_w, body_h))
	var avail: float = center_w - 2.0 * 28.0 - 16.0
	var k: float = CharSelectScript.mobile_card_k(avail, M_COLUMNS, 8.0)
	var card: Vector2 = (MenuKit.CARD_SIZE * k).floor()
	var sep: int = int(floorf((avail - M_COLUMNS * card.x) / (M_COLUMNS - 1)))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(scroll)
	roster = RosterScript.new()
	roster.build(M_COLUMNS, k, true)
	roster.add_theme_constant_override("h_separation", sep)
	roster.add_theme_constant_override("v_separation", 8)
	roster.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	roster.character_picked.connect(_on_character_pressed)
	scroll.add_child(roster)

	var weapon_h: float = roundf(body_h * 0.32)
	var pet_h: float = roundf(body_h * 0.34)
	var spirit_picker: PanelContainer = SpiritualPickerScript.new()
	add_child(spirit_picker)
	spirit_picker.setup(3)
	spirit_picker.picked.connect(func(_id: String) -> void: NetworkManager.update_local_loadout())
	_place(spirit_picker, Vector2(x1 - right_w, body_y), Vector2(right_w, body_h - weapon_h - pet_h))
	var pet_picker: PanelContainer = PetPickerScript.new()
	add_child(pet_picker)
	pet_picker.setup(true)
	_place(pet_picker, Vector2(x1 - right_w, body_y + body_h - weapon_h - pet_h), Vector2(right_w, pet_h))
	var weapon_picker: PanelContainer = WeaponPickerScript.new()
	add_child(weapon_picker)
	weapon_picker.setup(true)
	weapon_picker.picked.connect(func(_key: String) -> void: NetworkManager.update_local_loadout())
	_place(weapon_picker, Vector2(x1 - right_w, body_y + body_h - weapon_h), Vector2(right_w, weapon_h))
	_build_lock(Rect2(x0 + left_w, body_y, x1 - x0 - left_w, body_h))


## ------------------------------------------------------------------ sol: oda paneli
## Masaüstü + telefon ortak (boyutlar _fs_body/_fs_small/_ctl_h). Yerleştirmeyi çağıran yapar.
func _build_lobby_panel() -> PanelContainer:
	var panel := MenuKit.make_panel("panel_tight")
	panel.name = "LeftPanel"
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14 if _mobile else 10)
	if _mobile:
		## Telefonda büyük satırlar panele sığmaz - parmakla kaydırılır.
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		panel.add_child(scroll)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(v)
	else:
		panel.add_child(v)

	room_info_label = MenuKit.make_label(NetworkManager.room_name, _fs_body, MenuKit.C_ACCENT)
	room_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(room_info_label)
	var status_box := MenuKit.make_panel("inset")
	v.add_child(status_box)
	status_label = MenuKit.make_label("Karakterini, silahını ve ruhani yeteneğini seç, sonra HAZIRIM'a bas.", _fs_small, MenuKit.C_TEXT_DIM)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_box.add_child(status_label)

	v.add_child(MenuKit.make_section_header("Oyuncular", _fs_body))
	var players_box := MenuKit.make_panel("inset")
	players_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## En az 3 oyuncu satırı görünsün (telefonda kaydırma kabında EXPAND_FILL büyümez).
	players_box.custom_minimum_size = Vector2(0, 340.0 if _mobile else 260.0)
	v.add_child(players_box)
	var player_scroll := ScrollContainer.new()
	player_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	players_box.add_child(player_scroll)
	player_list_container = VBoxContainer.new()
	player_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_list_container.add_theme_constant_override("separation", 6)
	player_scroll.add_child(player_list_container)

	var chat: VBoxContainer = ChatScript.new()
	v.add_child(chat)
	chat.setup(_sz, _mobile, 300.0 if _mobile else 150.0)

	var btn_h: float = maxf(52.0, _ctl_h)
	ready_btn = MenuKit.make_button("HAZIRIM", "sage", _fs_body, btn_h)
	v.add_child(ready_btn)
	start_game_btn = MenuKit.make_button("OYUNU BAŞLAT", "sage", _fs_body, btn_h)
	v.add_child(start_game_btn)
	close_room_btn = MenuKit.make_button("ODAYI KAPAT" if NetworkManager.is_host else "ODADAN ÇIK", "rose", _fs_body, btn_h)
	v.add_child(close_room_btn)
	start_game_btn.pressed.connect(_on_start_game_pressed)
	ready_btn.pressed.connect(_on_ready_pressed)
	close_room_btn.pressed.connect(_on_close_room_pressed)
	return panel


## Hazırken seçim kilidi: orta + sağ alanın üstünde fareyi yutan yarı saydam katman.
func _build_lock(r: Rect2) -> void:
	_lock = ColorRect.new()
	(_lock as ColorRect).color = Color(0.1, 0.06, 0.03, 0.35)
	_lock.mouse_filter = Control.MOUSE_FILTER_STOP
	_lock.visible = false
	add_child(_lock)
	_place(_lock, r.position, r.size)
	var lbl := MenuKit.make_label("Hazırsın - değiştirmek için HAZIR DEĞİLİM'e bas.", _fs_body, MenuKit.C_CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock.add_child(lbl)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.offset_bottom = -24


func _on_character_pressed(char_id: int) -> void:
	selected_char_id = char_id
	## Kilitli karakter (Ruh Mağazası, bkz. meta_progress.gd) incelenebilir ama SEÇİLMEZ: ağa gönderilmez, hazır/başlat düğmeleri kapanır.
	_viewing_locked = not MetaProgressScript.is_unlocked(MetaProgressScript.CHAR, char_id)
	if roster:
		roster.select(char_id)
	if details:
		details.show_character(char_id)
	if showcase:
		showcase.show_character(char_id)
	if _desk:
		_desk.call("show_character", char_id, _viewing_locked)
	if not _viewing_locked:
		NetworkManager.update_local_character(char_id)
	_update_lobby_ui()


func _local_ready() -> bool:
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	return bool(NetworkManager.lobby_players.get(my_id, {}).get("is_ready", false))


func _on_start_game_pressed() -> void:
	NetworkManager.start_multiplayer_game()


func _on_ready_pressed() -> void:
	NetworkManager.set_local_ready(not _local_ready())


func _on_close_room_pressed() -> void:
	_leaving = true
	if NetworkManager.is_host:
		NetworkManager.close_room()
	else:
		NetworkManager.disconnect_from_room(false)
	NetworkManager.last_status_message = ""
	get_tree().change_scene_to_file("res://scenes/room_browser.tscn")


func _on_back_pressed() -> void:
	_on_close_room_pressed() ## oda lobisi yok (2026-10-16): geri = odayı kapat / odadan çık


## Eski sürümlü bir host oda lobisine dönerse (PHASE_ROOM) eski ekrana geçilir; bu sürüm bu aşamaya hiç geçmez.
func _on_phase_changed(phase: String) -> void:
	if phase == NetworkManager.PHASE_ROOM and is_inside_tree():
		get_tree().change_scene_to_file.call_deferred("res://scenes/room_lobby.tscn")


func _on_status_changed(status_text: String) -> void:
	_set_status(status_text)


func _set_status(text: String) -> void:
	if _desk:
		_desk.call("set_status", text)
	elif status_label:
		status_label.text = text


func _update_lobby_ui() -> void:
	if _desk:
		_desk.call("refresh")
		return
	if player_list_container == null or not NetworkManager.is_multiplayer_active:
		return
	var lp: Dictionary = NetworkManager.lobby_players
	var ready_count: int = 0
	for info: Dictionary in lp.values():
		if info.get("is_ready", false):
			ready_count += 1
	room_info_label.text = "%s   (%d / %d hazır)" % [NetworkManager.room_name, ready_count, lp.size()]
	var host: bool = NetworkManager.is_host
	start_game_btn.visible = host
	start_game_btn.disabled = not NetworkManager.all_players_ready() or _viewing_locked
	ready_btn.visible = not host
	var local_ready: bool = _local_ready()
	## Oda zaten oyundaysa (geç katılım) hazır olmak oyuna girmek demek - düğme bunu söylesin.
	if NetworkManager.is_join_blocked_by_game():
		ready_btn.text = "OYUN BAŞLAMIŞ"
		ready_btn.disabled = true
	elif NetworkManager.is_room_game_in_progress():
		ready_btn.disabled = false
		ready_btn.text = "OYUNA KATILIYOR..." if local_ready else "OYUNA KATIL"
	else:
		ready_btn.disabled = false
		ready_btn.text = "HAZIR DEĞİLİM" if local_ready else "HAZIRIM"
		if _viewing_locked and not local_ready:
			ready_btn.disabled = true
			ready_btn.text = "KİLİTLİ KARAKTER"
	if _lock:
		_lock.visible = local_ready and not host

	for child in player_list_container.get_children():
		player_list_container.remove_child(child)
		child.queue_free()
	var ids: Array = lp.keys()
	ids.sort()
	for pid in ids:
		player_list_container.add_child(LobbyUI.make_player_row(lp[pid], {"fs_body": _fs_body, "fs_small": _fs_small, "k": _portrait_k}))
