extends Control

## Çok oyunculu (LAN) lobi. Kullanıcı isteği (2026-09-24): menülerin kartları/arka planları bej/cozy piksel kitle (MenuKit)
## SIFIRDAN yeniden tasarlandı; ekran tamamen KODLA kurulur (.tscn sadece kök).
## Yerleşim (1920x1080, tek oyunculu character_select.gd ile AYNI simetrik üç sütun):
##   sol  : lobi paneli - oyuncu adı, bağlantı (durum, IP:Port, LAN Kur/Katıl, otomatik bulunan oyunlar), oda bilgisi,
##          odadaki oyuncular (mini karakter + hazır rozeti), HAZIRIM / OYUNU BAŞLAT / ODAYI KAPAT
##   orta : kurdele başlık + 6x2 karakter kartı + yetenek bilgi paneli (character_select.gd ile ORTAK bileşenler)
##   sağ  : seçili karakterin küçük vitrini + Ruhani Yetenek seçici
## Ağ davranışı (NetworkManager çağrıları, keşif dinleme, isim güncelleme, yeniden başlatma bayrağı) eskisiyle AYNI.
## 2026-10-03 (kullanıcı isteği: "çok oyunculu arayüzü güncel arayüzle uyumlu değil herşey ufacık" + "lobi içi chat" +
## "karakter portrelerinde karakterlerin yüzü görünsün, silah seçimleri falan da görünsün"):
##  - Telefon: kendi tam ekran yerleşimi (_build_mobile; karakter seçim ekranının telefon diliyle aynı - büyük yazı/dokunma
##    alanları, 4/3 kartlar); masaüstü yerleşimi aynı.
##  - Oyuncu satırı: karakterin yüz portresi (characters.gd "portrait") + seçtiği başlangıç silahı ve ruhani yetenek ikonu
##    (NetworkManager.update_local_loadout ile herkese gider).
##  - Odadayken lobi sohbeti (oyun içi sohbetle AYNI RPC: NetworkManager.broadcast_chat_message).

const SpiritualPickerScript: GDScript = preload("res://scripts/spiritual_picker.gd")
const RosterScript: GDScript = preload("res://scripts/menu_character_roster.gd")
const DetailsScript: GDScript = preload("res://scripts/menu_character_details.gd")
const ShowcaseScript: GDScript = preload("res://scripts/menu_character_showcase.gd")
const WeaponPickerScript: GDScript = preload("res://scripts/menu_weapon_picker.gd")
const PreviewScript: GDScript = preload("res://scripts/menu_character_preview.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")
const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")

## character_select.gd ile AYNI ızgara ölçüleri.
const SCREEN := Vector2(1920, 1080)
const EDGE := 16.0
const GAP := 16.0
const SIDE := 376.0
const TOP := 108.0
const BOTTOM := 16.0
## Telefon kart ızgarası: yan yana 3 (kullanıcı isteği 2026-10-03 "karakterler 3 sıralı olsun").
const M_COLUMNS := 3
const CHAT_MAX_LINES := 50
## Oyuncu satırındaki YÜZ: portreler (characters.gd "portrait") 48x48 TAM BOY çizimler - yüz o boyutta seçilmiyor. Çizili
## alanın üst-ortasından FACE_ART x FACE_ART sanat pikseli (baş + şapka) kesilir, tam sayı katında büyütülür (masaüstü 2x,
## telefon 4x) - piksel sanatı bozulmaz. Kesimler önbellekte.
const FACE_ART := 24
static var _face_cache: Dictionary = {}

var status_label: Label
var back_btn: Button
var player_name_input: LineEdit
var room_info_label: Label
var public_ip_label: Label
var player_list_container: VBoxContainer
var start_game_btn: Button
var ready_btn: Button
var close_room_btn: Button

var roster: GridContainer
var details: PanelContainer
var showcase: PanelContainer

var selected_char_id: int = 1

## Boyutlar: masaüstü MenuKit ölçüleri; telefonda _ready'de büyütülür (yazı 40/32, dokunma alanı 96 px, portre 2x).
var _mobile: bool = false
var _fs_body: int = MenuKit.FS_BODY
var _fs_small: int = MenuKit.FS_SMALL
var _ctl_h: float = 48.0
var _portrait_k: int = 1
## Lobi sohbeti (sadece odadayken görünür).
var _chat_section: VBoxContainer = null
var _chat_scroll: ScrollContainer = null
var _chat_log: VBoxContainer = null
var _chat_input: LineEdit = null
## LAN bölümü (başlık, IP, Kur/Katıl, açıklama) - odaya girince gizlenir (oyuncu listesine/sohbete yer kalsın).
var _lan_section: Array[Control] = []

var _lan_host_btn: Button = null
var _lan_join_btn: Button = null
var _lan_ip_input: LineEdit = null
## Kullanıcı isteği: "ip adresimi otomatik olarak lan'da görünsün ipmi sürekli
## yazmak istemiyorum" - bkz. network_manager.gd LAN OTOMATİK KEŞİF bloğu; bu liste
## ağdan bulunan host'ları gösterir, tıklanınca IP alanı otomatik doldurulup katılır.
var _lan_found_vbox: VBoxContainer = null
var _lan_found_header: Label = null
## İnternet odaları (kullanıcı isteği 2026-10-02: "hem androidden hem pcden crossplay sağlanması radmin olmadan") -
## Epic Online Services; bkz. scripts/net/eos_online.gd + network_manager.gd host_online/join_online.
const ONLINE_REFRESH_SEC := 8.0
var _online_host_btn: Button = null
var _online_refresh_btn: Button = null
var _online_vbox: VBoxContainer = null
var _online_section: Array[Control] = []
var _online_refresh_timer: Timer = null
var _online_searched_once: bool = false


func _ready() -> void:
	theme = MenuKit.theme()
	MenuKit.add_background(self)
	_mobile = MobileUIScript.enabled
	if _mobile:
		_fs_body = 40
		_fs_small = 32
		_ctl_h = 96.0
		_portrait_k = 2
		_build_mobile()
	else:
		_build_desktop()

	NetworkManager.lobby_updated.connect(_update_lobby_ui)
	NetworkManager.chat_message_received.connect(_on_chat_message_received)
	NetworkManager.connection_status_changed.connect(_on_status_changed)
	NetworkManager.lan_games_updated.connect(_refresh_lan_found_list)
	NetworkManager.start_lan_discovery_listen()
	_refresh_lan_found_list()

	_update_lobby_ui()
	_on_character_pressed(1)
	## Yeniden başlatma onaylandıysa (bkz. network_manager.gd _return_to_lobby_for_restart) herkes
	## buraya döner: karakter seçimi yeniden yapılır, hazır olunur, host oyunu başlatır.
	if NetworkManager.restart_returned_to_lobby:
		NetworkManager.restart_returned_to_lobby = false
		status_label.text = "Yeniden başlatma onaylandı: karakterini yeniden seç ve hazır ol, host oyunu başlatsın."

	UISound.connect_all_buttons(self)


func _place(c: Control, pos: Vector2, sz: Vector2) -> void:
	MenuKit.place(c, pos, sz)


func _build_desktop() -> void:
	## NOT: her node ÖNCE ağaca eklenir, SONRA MenuKit.place ile offset olarak yerleştirilir (bkz. o fonksiyonun notu).
	back_btn = MenuKit.make_button("< Geri Dön", "tan", MenuKit.FS_BODY, 56)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)
	_place(back_btn, Vector2(EDGE, 24), Vector2(200, 56))

	var banner := MenuKit.make_banner("Çok Oyunculu Lobi")
	add_child(banner)
	var bs: Vector2 = banner.get_combined_minimum_size()
	_place(banner, Vector2(roundf((SCREEN.x - bs.x) / 6.0) * 3.0, 18.0), bs)

	var panel: PanelContainer = _build_lobby_panel()
	_place(panel, Vector2(EDGE, TOP), Vector2(SIDE, SCREEN.y - TOP - BOTTOM))
	_build_center()
	_build_right_column()


## ------------------------------------------------------------------ telefon
## TAM EKRAN + her telefona uyumlu (kullanıcı isteği 2026-10-04, character_select.gd _build_mobile ile AYNI dil): üst şerit
## (Geri + başlık) + kenardan kenara üç panel, oransal genişlik: sol oda paneli (kaydırılabilir - bağlantı/oyuncular/sohbet),
## orta karakter kartları (3 sütun, ölçek sütunu doldurur), sağ ruhani yetenek + başlangıç silahı. Güvenli kenar payına uyar.
const CharSelectScript: GDScript = preload("res://scripts/character_select.gd")
const M_TOPBAR_FRAC := 0.11
const M_LEFT_FRAC := 0.32
const M_RIGHT_FRAC := 0.26


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
	back_btn = MenuKit.make_button("< Geri", "tan", 40, topbar_h - 24.0)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)
	_place(back_btn, Vector2(x0 + 12.0, y0 + 12.0), Vector2(240.0, topbar_h - 24.0))
	var title := MenuKit.make_label("Çok Oyunculu Lobi", 48, MenuKit.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
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
	roster.build(M_COLUMNS, k)
	roster.add_theme_constant_override("h_separation", sep)
	roster.add_theme_constant_override("v_separation", 8)
	roster.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	roster.character_picked.connect(_on_character_pressed)
	scroll.add_child(roster)

	var weapon_h: float = roundf(body_h * 0.42)
	var spirit_picker: PanelContainer = SpiritualPickerScript.new()
	add_child(spirit_picker)
	spirit_picker.setup(3)
	spirit_picker.picked.connect(func(_id: String) -> void: NetworkManager.update_local_loadout())
	_place(spirit_picker, Vector2(x1 - right_w, body_y), Vector2(right_w, body_h - weapon_h))
	var weapon_picker: PanelContainer = WeaponPickerScript.new()
	add_child(weapon_picker)
	weapon_picker.setup(true)
	weapon_picker.picked.connect(func(_key: String) -> void: NetworkManager.update_local_loadout())
	_place(weapon_picker, Vector2(x1 - right_w, body_y + body_h - weapon_h), Vector2(right_w, weapon_h))


## ------------------------------------------------------------------ sol: lobi paneli
## Sol oda paneli (masaüstü + telefon ortak; boyutlar _fs_body/_fs_small/_ctl_h). Yerleştirmeyi çağıran yapar.
func _build_lobby_panel() -> PanelContainer:
	var panel := MenuKit.make_panel("panel_tight")
	panel.name = "LeftPanel"
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14 if _mobile else 10)
	if _mobile:
		## Telefonda büyük satırlar panele sığmaz (özellikle bağlı değilken) - parmakla kaydırılır.
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		panel.add_child(scroll)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(v)
	else:
		panel.add_child(v)

	v.add_child(MenuKit.make_section_header("Oyuncu", _fs_body))
	player_name_input = LineEdit.new()
	player_name_input.placeholder_text = "Adınızı girin..."
	player_name_input.custom_minimum_size = Vector2(0, _ctl_h)
	player_name_input.add_theme_font_size_override("font_size", _fs_body)
	v.add_child(player_name_input)
	## DÜZELTME (kullanıcı bildirimi: "insanlar lobiye girdikten sonra ismini
	## değiştiremiyor") - Enter'a basınca YA DA alandan çıkınca (zaten odadaysa)
	## yeni isim herkese yayınlanıyor (bkz. NetworkManager.update_local_player_name).
	player_name_input.text_submitted.connect(_on_player_name_submitted)
	player_name_input.focus_exited.connect(func(): _on_player_name_submitted(player_name_input.text))
	## DÜZELTME (kullanıcı isteği: "oyunda isim profili olsun 1 kere ismini
	## yazınca bi daha yazman gerekmesin") - NetworkManager kaydedilmiş ismi zaten
	## local_player_name'e yüklüyor, burada sadece alana yansıtılıyor.
	player_name_input.text = NetworkManager.local_player_name

	v.add_child(MenuKit.make_section_header("Bağlantı", _fs_body))
	var status_box := MenuKit.make_panel("inset")
	v.add_child(status_box)
	status_label = MenuKit.make_label("Sunucu kurun veya bir adrese katılın", _fs_body, MenuKit.C_TEXT_DIM)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_box.add_child(status_label)

	_build_online_section(v)

	## Kullanıcı isteği: "multiplayerdan ziva altyapısını kaldır" - LAN/IP (internet odası yukarıda, Epic).
	var lan_header := MenuKit.make_label("Aynı Ağ (LAN)", _fs_body, MenuKit.C_ACCENT)
	v.add_child(lan_header)
	_lan_ip_input = LineEdit.new()
	_lan_ip_input.placeholder_text = "IP:Port (örn. 192.168.1.50:7777)"
	_lan_ip_input.text = "127.0.0.1:7777"
	_lan_ip_input.custom_minimum_size = Vector2(0, _ctl_h)
	_lan_ip_input.add_theme_font_size_override("font_size", _fs_body)
	v.add_child(_lan_ip_input)

	var lan_hbox := HBoxContainer.new()
	lan_hbox.add_theme_constant_override("separation", 8)
	v.add_child(lan_hbox)
	_lan_host_btn = MenuKit.make_button("LAN Kur", "tan", _fs_body, _ctl_h)
	_lan_host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lan_hbox.add_child(_lan_host_btn)
	_lan_join_btn = MenuKit.make_button("LAN Katıl", "tan", _fs_body, _ctl_h)
	_lan_join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lan_hbox.add_child(_lan_join_btn)
	_lan_host_btn.pressed.connect(_on_lan_host_pressed)
	_lan_join_btn.pressed.connect(_on_lan_join_pressed)
	_lan_section = [lan_header, _lan_ip_input, lan_hbox]

	## DÜZELTME (kullanıcı isteği: "ip adresimi otomatik olarak lan'da görünsün") - host olunca IP otomatik algılanıp
	## oda bilgisinde gösteriliyor VE aynı ağdaki host'lar aşağıdaki listede kendiliğinden beliriyor - manuel IP sadece
	## keşif işe yaramazsa (güvenlik duvarı vb.) yedek.
	var lan_info := MenuKit.make_label("Aynı ağdaki oyunlar aşağıda belirir. Görünmezse host'un IP:Port'unu yaz.", _fs_small, MenuKit.C_TEXT_DIM)
	lan_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lan_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(lan_info)
	_lan_section.append(lan_info)

	_lan_found_header = MenuKit.make_label("Bulunan LAN Oyunları", _fs_small, MenuKit.C_TEXT_DIM)
	v.add_child(_lan_found_header)
	_lan_found_vbox = VBoxContainer.new()
	_lan_found_vbox.add_theme_constant_override("separation", 4)
	v.add_child(_lan_found_vbox)

	v.add_child(MenuKit.make_section_header("Oda", _fs_body))
	room_info_label = MenuKit.make_label("Oda: Henüz Bağlı Değil", _fs_body, MenuKit.C_GOOD)
	room_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(room_info_label)
	public_ip_label = MenuKit.make_label("", _fs_small, MenuKit.C_TEXT_DIM)
	public_ip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	public_ip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	public_ip_label.visible = false
	v.add_child(public_ip_label)

	var players_box := MenuKit.make_panel("inset")
	players_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## En az 3 oyuncu satırı görünsün (masaüstünde panel dolunca sıkışıp kayboluyordu; telefonda kaydırma kabında
	## EXPAND_FILL büyümez).
	players_box.custom_minimum_size = Vector2(0, 340.0 if _mobile else 170.0)
	v.add_child(players_box)
	var player_scroll := ScrollContainer.new()
	player_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	players_box.add_child(player_scroll)
	player_list_container = VBoxContainer.new()
	player_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_list_container.add_theme_constant_override("separation", 6)
	player_scroll.add_child(player_list_container)

	_build_chat_section(v)

	ready_btn = MenuKit.make_button("HAZIRIM", "sage", _fs_body, maxf(52.0, _ctl_h))
	ready_btn.visible = false
	v.add_child(ready_btn)
	start_game_btn = MenuKit.make_button("OYUNU BAŞLAT (HOST)", "sage", _fs_body, maxf(52.0, _ctl_h))
	start_game_btn.visible = false
	v.add_child(start_game_btn)
	close_room_btn = MenuKit.make_button("ODAYI KAPAT", "rose", _fs_body, maxf(52.0, _ctl_h))
	close_room_btn.visible = false
	v.add_child(close_room_btn)
	start_game_btn.pressed.connect(_on_start_game_pressed)
	ready_btn.pressed.connect(_on_ready_pressed)
	close_room_btn.pressed.connect(_on_close_room_pressed)
	return panel


## ------------------------------------------------------------------ lobi sohbeti
## Sadece odadayken görünür (_update_lobby_ui). Oyun içi sohbetle AYNI RPC (NetworkManager.broadcast_chat_message,
## "call_local" - gönderen kendi mesajını da sinyalden alır). Enter ya da "Gönder" ile; telefonda kutuya dokununca
## sistem klavyesi açılır.
func _build_chat_section(v: VBoxContainer) -> void:
	_chat_section = VBoxContainer.new()
	_chat_section.add_theme_constant_override("separation", 6)
	_chat_section.visible = false
	v.add_child(_chat_section)
	_chat_section.add_child(MenuKit.make_section_header("Sohbet", _fs_body))
	var log_box := MenuKit.make_panel("inset")
	_chat_section.add_child(log_box)
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chat_scroll.custom_minimum_size = Vector2(0, 300.0 if _mobile else 150.0)
	log_box.add_child(_chat_scroll)
	_chat_log = VBoxContainer.new()
	_chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_log.add_theme_constant_override("separation", 2)
	_chat_scroll.add_child(_chat_log)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_chat_section.add_child(row)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Mesaj yaz..."
	_chat_input.max_length = 200
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.custom_minimum_size = Vector2(0, _ctl_h)
	_chat_input.add_theme_font_size_override("font_size", _fs_body)
	_chat_input.text_submitted.connect(func(_t: String) -> void: _send_chat())
	row.add_child(_chat_input)
	var send := MenuKit.make_button("Gönder", "tan", _fs_body, _ctl_h)
	send.pressed.connect(_send_chat)
	row.add_child(send)


func _send_chat() -> void:
	var text: String = _chat_input.text.strip_edges()
	_chat_input.text = ""
	if text.is_empty() or not NetworkManager.is_multiplayer_active or not multiplayer.has_multiplayer_peer():
		return
	NetworkManager.broadcast_chat_message.rpc(multiplayer.get_unique_id(), NetworkManager.local_player_name, text)
	if not _mobile:
		_chat_input.grab_focus.call_deferred() ## arka arkaya yazabilsin (telefonda klavye kendiliğinden kapanır)


func _on_chat_message_received(_peer_id: int, player_name: String, text: String) -> void:
	if _chat_log == null:
		return
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("normal_font_size", _fs_small)
	line.add_theme_font_size_override("bold_font_size", _fs_small)
	line.add_theme_color_override("default_color", MenuKit.C_TEXT)
	line.text = "[color=#%s]%s:[/color] %s" % [MenuKit.C_ACCENT.to_html(false), player_name.xml_escape(), text.xml_escape()]
	_chat_log.add_child(line)
	while _chat_log.get_child_count() > CHAT_MAX_LINES:
		var old: Node = _chat_log.get_child(0)
		_chat_log.remove_child(old)
		old.queue_free()
	await get_tree().process_frame
	if is_instance_valid(_chat_scroll):
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)


## İnternet (Epic) bölümü: [İnternetten Kur] [Yenile] + bulunan odalar. Kimlik dosyası yoksa düğmeler kapalı, LAN etkilenmez.
func _build_online_section(v: VBoxContainer) -> void:
	var header := MenuKit.make_label("İnternet (PC + Android)", _fs_body, MenuKit.C_ACCENT)
	v.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_online_host_btn = MenuKit.make_button("İnternetten Kur", "sage", _fs_body, _ctl_h)
	_online_host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_online_host_btn)
	_online_refresh_btn = MenuKit.make_button("Yenile", "tan", _fs_body, _ctl_h)
	row.add_child(_online_refresh_btn)
	_online_host_btn.pressed.connect(_on_online_host_pressed)
	_online_refresh_btn.pressed.connect(_refresh_online_list)
	_online_vbox = VBoxContainer.new()
	_online_vbox.add_theme_constant_override("separation", 4)
	v.add_child(_online_vbox)
	_online_section = [header, row, _online_vbox]
	if not NetworkManager.is_online_available():
		_online_host_btn.disabled = true
		_online_refresh_btn.disabled = true
		_set_online_message("Epic ayarları eksik (eos_credentials.cfg) - şimdilik sadece LAN.")
		return
	_set_online_message("Odalar aranıyor...")
	_online_refresh_timer = Timer.new()
	_online_refresh_timer.wait_time = ONLINE_REFRESH_SEC
	_online_refresh_timer.timeout.connect(_refresh_online_list)
	add_child(_online_refresh_timer)
	_online_refresh_timer.start()
	_refresh_online_list.call_deferred()


func _set_online_message(text: String) -> void:
	for c in _online_vbox.get_children():
		c.queue_free()
	var lbl := MenuKit.make_label(text, _fs_small, MenuKit.C_TEXT_DIM)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_online_vbox.add_child(lbl)


func _player_name_or(fallback: String) -> String:
	var pname: String = player_name_input.text.strip_edges()
	return fallback if pname.is_empty() else pname


func _on_online_host_pressed() -> void:
	NetworkManager.host_online(_player_name_or("Kurucu"), selected_char_id)


## Epic'te bu oyunun açık odalarını arar (bağlı değilken ONLINE_REFRESH_SEC'te bir kendiliğinden, ya da "Yenile").
func _refresh_online_list() -> void:
	if NetworkManager.is_multiplayer_active or not NetworkManager.is_online_available():
		return
	if not _online_searched_once:
		_set_online_message("Odalar aranıyor...")
	var rooms: Array = await EosOnline.search_lobbies_async(_player_name_or("Oyuncu"))
	if not is_inside_tree() or NetworkManager.is_multiplayer_active:
		return
	_online_searched_once = true
	if rooms.is_empty():
		_set_online_message("(açık internet odası yok - sen kurabilirsin)")
		return
	for c in _online_vbox.get_children():
		c.queue_free()
	for r in rooms:
		var label: String = "%s   %d/%d" % [r["host_name"], int(r["players"]), int(r["max_players"])]
		if r["in_game"]:
			label += "  (oyunda)"
		var btn := MenuKit.make_button(label, "tan", _fs_small, maxf(40.0, _ctl_h * 0.85))
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.tooltip_text = label
		btn.disabled = int(r["players"]) >= int(r["max_players"])
		btn.pressed.connect(_on_online_room_pressed.bind(String(r["host_id"]), String(r["host_name"])))
		_online_vbox.add_child(btn)
	UISound.connect_all_buttons(_online_vbox)


func _on_online_room_pressed(host_id: String, host_name: String) -> void:
	NetworkManager.join_online(host_id, host_name, _player_name_or("Katılımcı"), selected_char_id)


## ------------------------------------------------------------------ orta: kartlar + yetenek paneli
func _build_center() -> void:
	var center_x: float = EDGE + SIDE + GAP
	var center_w: float = SCREEN.x - 2.0 * center_x
	roster = RosterScript.new()
	add_child(roster)
	roster.build()
	var grid_size: Vector2 = RosterScript.grid_size(Characters.DEFS.size())
	_place(roster, Vector2(center_x + floorf((center_w - grid_size.x) * 0.5), TOP), grid_size)
	roster.character_picked.connect(_on_character_pressed)

	details = DetailsScript.new()
	add_child(details)
	var details_y: float = TOP + grid_size.y + GAP
	## Başlangıç silahı (kullanıcı isteği 2026-10-03, bkz. menu_weapon_picker.gd) - yetenek panelinin sağında; sağ sütun
	## (vitrin + ruhani yetenek) dolu olduğu için. Seçim yerel tercih (GameManager.selected_start_weapon), ağdan gitmez.
	var details_h: float = SCREEN.y - BOTTOM - details_y
	var picker_w: float = 376.0
	_place(details, Vector2(center_x, details_y), Vector2(center_w - picker_w - GAP, details_h))
	var weapon_picker: PanelContainer = WeaponPickerScript.new()
	add_child(weapon_picker)
	weapon_picker.setup(false)
	weapon_picker.picked.connect(func(_key: String) -> void: NetworkManager.update_local_loadout())
	_place(weapon_picker, Vector2(center_x + center_w - picker_w, details_y), Vector2(picker_w, details_h))


## ------------------------------------------------------------------ sağ: vitrin + ruhani yetenek
func _build_right_column() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	showcase = ShowcaseScript.new()
	col.add_child(showcase)
	showcase.build(false)
	## Ruhani Yetenek seçici (kullanıcı isteği: karakter seçerken herkes 1 ruhani yetenek seçer) - seçim yerel bir
	## oyuncu tercihi (GameManager.selected_spiritual), ağdan gitmesi gerekmez.
	var spirit_picker: PanelContainer = SpiritualPickerScript.new()
	spirit_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spirit_picker)
	spirit_picker.setup(3)
	spirit_picker.picked.connect(func(_id: String) -> void: NetworkManager.update_local_loadout())
	_place(col, Vector2(SCREEN.x - EDGE - SIDE, TOP), Vector2(SIDE, SCREEN.y - TOP - BOTTOM))


func _on_character_pressed(char_id: int) -> void:
	selected_char_id = char_id
	roster.select(char_id)
	if details:
		details.show_character(char_id)
	if showcase:
		showcase.show_character(char_id)
	NetworkManager.update_local_character(char_id)


func _on_lan_host_pressed() -> void:
	var parts: Array = _lan_ip_input.text.split(":")
	var port: int = 7777
	if parts.size() > 1:
		port = int(parts[1])
	var pname: String = player_name_input.text.strip_edges()
	if pname.is_empty():
		pname = "Kurucu (LAN)"
	NetworkManager.host_lan(port, pname, selected_char_id)


func _on_lan_join_pressed() -> void:
	var parts: Array = _lan_ip_input.text.split(":")
	var ip: String = "127.0.0.1"
	var port: int = 7777
	if parts.size() > 0:
		ip = parts[0].strip_edges()
	if parts.size() > 1:
		port = int(parts[1])
	var pname: String = player_name_input.text.strip_edges()
	if pname.is_empty():
		pname = "Katılımcı (LAN)"
	NetworkManager.join_lan(ip, port, pname, selected_char_id)


func _on_start_game_pressed() -> void:
	NetworkManager.start_multiplayer_game()


func _on_ready_pressed() -> void:
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var current_ready: bool = NetworkManager.lobby_players.get(my_id, {}).get("is_ready", false)
	NetworkManager.set_local_ready(not current_ready)


## Kullanıcı isteği: "insanlar lobiye girdikten sonra ismini değiştiremiyor" -
## sadece zaten bir odadayken (NetworkManager.is_multiplayer_active) anlamlı;
## odaya girmeden önceki metin zaten create/join sırasında normal şekilde
## okunuyor, burada tekrar bir şey yapmaya gerek yok.
func _on_player_name_submitted(new_text: String) -> void:
	if not NetworkManager.is_multiplayer_active:
		return
	NetworkManager.update_local_player_name(new_text)


func _on_close_room_pressed() -> void:
	if NetworkManager.is_host:
		NetworkManager.close_room()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_back_pressed() -> void:
	if NetworkManager.is_multiplayer_active:
		NetworkManager.disconnect_from_room()
		_update_lobby_ui()
		return
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_status_changed(status_text: String) -> void:
	status_label.text = status_text


## LAN/IP bağlantı bilgisi
func _refresh_public_ip_label() -> void:
	public_ip_label.visible = true
	## room_code artık host'ta gerçek algılanan IP'yi taşıyor (bkz. network_manager.gd
	## host_lan/get_local_lan_ip) - bu etiket kullanıcının arkadaşına söyleyebileceği
	## IP'yi otomatik gösteriyor, "ipconfig"e gerek kalmıyor.
	public_ip_label.text = "Bağlantı bilgisi (gerekirse paylaş): %s" % NetworkManager.room_code


## NetworkManager.lan_games_updated sinyaliyle çağrılır, ağda bulunan host'ları listeler;
## tıklanınca IP elle yazılmadan doğrudan katılır.
func _refresh_lan_found_list() -> void:
	if _lan_found_vbox == null:
		return
	for c in _lan_found_vbox.get_children():
		c.queue_free()
	var games: Array = NetworkManager.get_discovered_lan_games()
	if games.is_empty():
		var empty_lbl := MenuKit.make_label("(henüz bulunamadı - host aynı ağda olmalı)", _fs_small, MenuKit.C_TEXT_DIM)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lan_found_vbox.add_child(empty_lbl)
		return
	for g in games:
		var btn := MenuKit.make_button("%s   (%s:%d)" % [g["name"], g["ip"], g["port"]], "tan", _fs_small, maxf(40.0, _ctl_h * 0.85))
		## DÜZELTME (kullanıcı bildirimi: "soldaki oda kurma paneli oda bulduğunda kocaman büyüyen bir buton
		## yüzünden dışa taşıyor") - clip_text + expand_fill: buton mevcut genişliği DOLDURUR, metne göre BÜYÜMEZ,
		## sığmayan metin "..." ile kırpılır.
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.tooltip_text = btn.text ## kırpılan tam metin ipucunda kalsın
		btn.pressed.connect(_on_found_game_pressed.bind(String(g["ip"]), int(g["port"])))
		_lan_found_vbox.add_child(btn)
	UISound.connect_all_buttons(_lan_found_vbox)


func _on_found_game_pressed(ip: String, port: int) -> void:
	_lan_ip_input.text = "%s:%d" % [ip, port]
	var pname: String = player_name_input.text.strip_edges()
	if pname.is_empty():
		pname = "Katılımcı (LAN)"
	NetworkManager.join_lan(ip, port, pname, selected_char_id)


func _exit_tree() -> void:
	## Lobiden ayrılınca (ana menüye dönünce) dinlemeyi durdur ki UDP portu boşta
	## kalıp gelecekteki bir oturumu (ya da AYNI PC'deki ikinci test istemcisini)
	## engellemesin - bkz. network_manager.gd LAN OTOMATİK KEŞİF notu.
	if NetworkManager.lan_games_updated.is_connected(_refresh_lan_found_list):
		NetworkManager.lan_games_updated.disconnect(_refresh_lan_found_list)
	NetworkManager.stop_lan_discovery_listen()


func _update_lobby_ui() -> void:
	if not NetworkManager.is_multiplayer_active:
		room_info_label.text = "Oda: Henüz Bağlı Değil"
		start_game_btn.visible = false
		ready_btn.visible = false
		close_room_btn.visible = false
		public_ip_label.visible = false
		if _lan_host_btn: _lan_host_btn.disabled = false
		if _lan_join_btn: _lan_join_btn.disabled = false
		if _lan_ip_input: _lan_ip_input.editable = true
		## Henüz bağlanmadık (ör. host_lan/join_lan başarısız oldu, ya da bağlıyken
		## "geri" ile lobiye dönüldü) - keşif dinlemesi AÇIK olmalı, bkz. _ready().
		NetworkManager.start_lan_discovery_listen()
		if _lan_found_header: _lan_found_header.visible = true
		if _lan_found_vbox: _lan_found_vbox.visible = true
		_refresh_lan_found_list()
		for c in _online_section:
			c.visible = true
		if _chat_section:
			_chat_section.visible = false
		for c in _lan_section:
			c.visible = true
		var online_ok: bool = NetworkManager.is_online_available()
		if _online_host_btn: _online_host_btn.disabled = not online_ok
		if _online_refresh_btn: _online_refresh_btn.disabled = not online_ok
	else:
		room_info_label.text = "Bağlantı: %s (%s)" % [NetworkManager.room_code, "Host" if NetworkManager.is_host else "Katılımcı"]
		start_game_btn.visible = NetworkManager.is_host
		start_game_btn.disabled = not NetworkManager.all_players_ready()
		ready_btn.visible = not NetworkManager.is_host
		var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
		var local_ready: bool = NetworkManager.lobby_players.get(my_id, {}).get("is_ready", false)
		## Oda zaten oyundaysa (2026-10-04 geç katılım) hazır olmak oyuna girmek demek - düğme bunu söylesin.
		if NetworkManager.is_join_blocked_by_game():
			ready_btn.text = "OYUN BAŞLAMIŞ"
			ready_btn.disabled = true
		elif NetworkManager.is_room_game_in_progress():
			ready_btn.disabled = false
			ready_btn.text = "OYUNA KATILIYOR..." if local_ready else "OYUNA KATIL"
		else:
			ready_btn.disabled = false
			ready_btn.text = "HAZIR DEĞİLİM" if local_ready else "HAZIRIM"
		close_room_btn.visible = NetworkManager.is_host
		if _lan_host_btn: _lan_host_btn.disabled = true
		if _lan_join_btn: _lan_join_btn.disabled = true
		if _lan_ip_input: _lan_ip_input.editable = false
		## Zaten bağlandık - "Bulunan Oyunlar" listesi artık anlamsız, gizle
		## (dinleme de NetworkManager.host_lan/join_lan içinde zaten durduruldu).
		if _lan_found_header: _lan_found_header.visible = false
		if _lan_found_vbox: _lan_found_vbox.visible = false
		## Odadayken internet bölümü de gizli (oda bilgisi aşağıdaki "Oda" bölümünde).
		for c in _online_section:
			c.visible = false
		if _chat_section:
			_chat_section.visible = true
		for c in _lan_section:
			c.visible = false
		_refresh_public_ip_label()

	for child in player_list_container.get_children():
		child.queue_free()
	if NetworkManager.lobby_players.is_empty():
		var none := MenuKit.make_label("Odada henüz kimse yok", _fs_small, MenuKit.C_TEXT_DIM)
		player_list_container.add_child(none)
	for pid in NetworkManager.lobby_players.keys():
		player_list_container.add_child(_make_player_row(NetworkManager.lobby_players[pid]))


## Odadaki bir oyuncu satırı (2026-10-03): YÜZ PORTRESİ (characters.gd "portrait", 48x48 sanat - tam sayı ölçek, telefonda 2x)
## + 1. satır isim [HOST] ve HAZIR/BEKLİYOR rozeti, 2. satır karakter adı + seçtiği başlangıç silahı ve ruhani yetenek ikonu
## (lobby_players "weapon"/"spirit" - NetworkManager.update_local_loadout; henüz gelmediyse ikon yok).
func _make_player_row(pinfo: Dictionary) -> Control:
	var cdef: Dictionary = Characters.get_def(pinfo.get("char_id", 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var slot := MenuKit.make_panel("slot_normal")
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slot)
	var face_px: float = float(FACE_ART * 2 * _portrait_k)
	var face_tex: Texture2D = _face_texture(str(cdef.get("portrait", "")))
	if face_tex:
		var face := TextureRect.new()
		face.texture = face_tex
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.custom_minimum_size = Vector2(face_px, face_px)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(face)
	else:
		var mini: Control = PreviewScript.new()
		mini.custom_minimum_size = Vector2(face_px, face_px)
		slot.add_child(mini)
		mini.setup(cdef, _portrait_k, face_px - 2.0)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	var host_tag: String = "  [HOST]" if pinfo.get("is_host", false) else ""
	var name_lbl := MenuKit.make_label("%s%s" % [pinfo.get("name", "Oyuncu"), host_tag], _fs_body, MenuKit.C_TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_lbl)
	var is_ready: bool = pinfo.get("is_ready", false)
	var badge := MenuKit.make_panel("tag_pasif" if is_ready else "tag_ulti")
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(MenuKit.make_label("HAZIR" if is_ready else "BEKLİYOR", _fs_small, MenuKit.C_CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	top.add_child(badge)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	col.add_child(bottom)
	var char_lbl := MenuKit.make_label(str(cdef.get("name", "Karakter")), _fs_small, MenuKit.C_TEXT_DIM)
	char_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_lbl.clip_text = true
	char_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bottom.add_child(char_lbl)
	var icon_px: float = 32.0 * _portrait_k
	var weapon_key: String = str(pinfo.get("weapon", ""))
	if WeaponCatalog.is_valid(weapon_key):
		bottom.add_child(_loadout_icon(WeaponCatalog.icon(weapon_key), icon_px, "Silah: " + WeaponCatalog.display_name(weapon_key)))
	var spirit_id: String = str(pinfo.get("spirit", ""))
	if SpiritualSkillsScript.is_valid(spirit_id):
		var sdef: Dictionary = SpiritualSkillsScript.get_def(spirit_id)
		var sicon: String = str(sdef.get("icon", ""))
		var stex: Texture2D = load(sicon) as Texture2D if sicon != "" and ResourceLoader.exists(sicon) else null
		bottom.add_child(_loadout_icon(stex, icon_px, "Ruhani yetenek: " + str(sdef.get("name", spirit_id))))
	return row


## Portrenin baş kısmı (bkz. FACE_ART notu): çizili alanın yatay ortası, üst kenarından bir piksel yukarısı.
static func _face_texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if _face_cache.has(path):
		return _face_cache[path]
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	var used: Rect2i = img.get_used_rect()
	var size: int = mini(FACE_ART, mini(img.get_width(), img.get_height()))
	var x: int = clampi(used.position.x + used.size.x / 2 - size / 2, 0, img.get_width() - size)
	var y: int = clampi(used.position.y - 1, 0, img.get_height() - size)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(x, y, size, size)
	_face_cache[path] = at
	return at


func _loadout_icon(tex: Texture2D, px: float, tip: String) -> Control:
	var frame := MenuKit.make_panel("slot_normal")
	frame.tooltip_text = tip
	var icon := TextureRect.new()
	icon.texture = tex
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(px, px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	return frame
