extends Control

## Çok oyunculu (LAN) lobi. Kullanıcı isteği (2026-09-24): menülerin kartları/arka planları bej/cozy piksel kitle (MenuKit)
## SIFIRDAN yeniden tasarlandı; ekran tamamen KODLA kurulur (.tscn sadece kök).
## Yerleşim (1920x1080, tek oyunculu character_select.gd ile AYNI simetrik üç sütun):
##   sol  : lobi paneli - oyuncu adı, bağlantı (durum, IP:Port, LAN Kur/Katıl, otomatik bulunan oyunlar), oda bilgisi,
##          odadaki oyuncular (mini karakter + hazır rozeti), HAZIRIM / OYUNU BAŞLAT / ODAYI KAPAT
##   orta : kurdele başlık + 6x2 karakter kartı + yetenek bilgi paneli (character_select.gd ile ORTAK bileşenler)
##   sağ  : seçili karakterin küçük vitrini + Ruhani Yetenek seçici
## Ağ davranışı (NetworkManager çağrıları, keşif dinleme, isim güncelleme, yeniden başlatma bayrağı) eskisiyle AYNI.

const SpiritualPickerScript: GDScript = preload("res://scripts/spiritual_picker.gd")
const RosterScript: GDScript = preload("res://scripts/menu_character_roster.gd")
const DetailsScript: GDScript = preload("res://scripts/menu_character_details.gd")
const ShowcaseScript: GDScript = preload("res://scripts/menu_character_showcase.gd")
const PreviewScript: GDScript = preload("res://scripts/menu_character_preview.gd")

## character_select.gd ile AYNI ızgara ölçüleri.
const SCREEN := Vector2(1920, 1080)
const EDGE := 16.0
const GAP := 16.0
const SIDE := 376.0
const TOP := 108.0
const BOTTOM := 16.0

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

var _lan_host_btn: Button = null
var _lan_join_btn: Button = null
var _lan_ip_input: LineEdit = null
## Kullanıcı isteği: "ip adresimi otomatik olarak lan'da görünsün ipmi sürekli
## yazmak istemiyorum" - bkz. network_manager.gd LAN OTOMATİK KEŞİF bloğu; bu liste
## ağdan bulunan host'ları gösterir, tıklanınca IP alanı otomatik doldurulup katılır.
var _lan_found_vbox: VBoxContainer = null
var _lan_found_header: Label = null


func _ready() -> void:
	theme = MenuKit.theme()
	MenuKit.add_background(self)

	## NOT: her node ÖNCE ağaca eklenir, SONRA MenuKit.place ile offset olarak yerleştirilir (bkz. o fonksiyonun notu).
	back_btn = MenuKit.make_button("< Geri Dön", "tan", MenuKit.FS_BODY, 56)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)
	_place(back_btn, Vector2(EDGE, 24), Vector2(200, 56))

	var banner := MenuKit.make_banner("Çok Oyunculu Lobi")
	add_child(banner)
	var bs: Vector2 = banner.get_combined_minimum_size()
	_place(banner, Vector2(roundf((SCREEN.x - bs.x) / 6.0) * 3.0, 18.0), bs)

	_build_lobby_panel()
	_build_center()
	_build_right_column()

	NetworkManager.lobby_updated.connect(_update_lobby_ui)
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


## ------------------------------------------------------------------ sol: lobi paneli
func _build_lobby_panel() -> void:
	var panel := MenuKit.make_panel("panel_tight")
	panel.name = "LeftPanel"
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	v.add_child(MenuKit.make_section_header("Oyuncu"))
	player_name_input = LineEdit.new()
	player_name_input.placeholder_text = "Adınızı girin..."
	player_name_input.custom_minimum_size = Vector2(0, 48)
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

	v.add_child(MenuKit.make_section_header("Bağlantı"))
	var status_box := MenuKit.make_panel("inset")
	v.add_child(status_box)
	status_label = MenuKit.make_label("Sunucu kurun veya bir adrese katılın", MenuKit.FS_BODY, MenuKit.C_TEXT_DIM)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_box.add_child(status_label)

	## Kullanıcı isteği: "multiplayerdan ziva altyapısını kaldır" - tek bağlantı yolu LAN/IP.
	_lan_ip_input = LineEdit.new()
	_lan_ip_input.placeholder_text = "IP:Port (örn. 192.168.1.50:7777)"
	_lan_ip_input.text = "127.0.0.1:7777"
	_lan_ip_input.custom_minimum_size = Vector2(0, 48)
	v.add_child(_lan_ip_input)

	var lan_hbox := HBoxContainer.new()
	lan_hbox.add_theme_constant_override("separation", 8)
	v.add_child(lan_hbox)
	_lan_host_btn = MenuKit.make_button("LAN Kur", "tan", MenuKit.FS_BODY, 48)
	_lan_host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lan_hbox.add_child(_lan_host_btn)
	_lan_join_btn = MenuKit.make_button("LAN Katıl", "tan", MenuKit.FS_BODY, 48)
	_lan_join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lan_hbox.add_child(_lan_join_btn)
	_lan_host_btn.pressed.connect(_on_lan_host_pressed)
	_lan_join_btn.pressed.connect(_on_lan_join_pressed)

	## DÜZELTME (kullanıcı isteği: "ip adresimi otomatik olarak lan'da görünsün") - host olunca IP otomatik algılanıp
	## oda bilgisinde gösteriliyor VE aynı ağdaki host'lar aşağıdaki listede kendiliğinden beliriyor - manuel IP sadece
	## keşif işe yaramazsa (güvenlik duvarı vb.) yedek.
	var lan_info := MenuKit.make_label("Aynı ağdaki oyunlar aşağıda kendiliğinden belirir, tıklayıp katılabilirsin. Görünmezse (güvenlik duvarı vb.) host'un IP:Port'unu yukarıya yaz.", MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM)
	lan_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lan_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(lan_info)

	_lan_found_header = MenuKit.make_label("Bulunan Oyunlar", MenuKit.FS_BODY, MenuKit.C_ACCENT)
	v.add_child(_lan_found_header)
	_lan_found_vbox = VBoxContainer.new()
	_lan_found_vbox.add_theme_constant_override("separation", 4)
	v.add_child(_lan_found_vbox)

	v.add_child(MenuKit.make_section_header("Oda"))
	room_info_label = MenuKit.make_label("Oda: Henüz Bağlı Değil", MenuKit.FS_BODY, MenuKit.C_GOOD)
	room_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(room_info_label)
	public_ip_label = MenuKit.make_label("", MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM)
	public_ip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	public_ip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	public_ip_label.visible = false
	v.add_child(public_ip_label)

	var players_box := MenuKit.make_panel("inset")
	players_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(players_box)
	var player_scroll := ScrollContainer.new()
	player_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	players_box.add_child(player_scroll)
	player_list_container = VBoxContainer.new()
	player_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_list_container.add_theme_constant_override("separation", 6)
	player_scroll.add_child(player_list_container)

	ready_btn = MenuKit.make_button("HAZIRIM", "sage", MenuKit.FS_BODY, 52)
	ready_btn.visible = false
	v.add_child(ready_btn)
	start_game_btn = MenuKit.make_button("OYUNU BAŞLAT (HOST)", "sage", MenuKit.FS_BODY, 52)
	start_game_btn.visible = false
	v.add_child(start_game_btn)
	close_room_btn = MenuKit.make_button("ODAYI KAPAT", "rose", MenuKit.FS_BODY, 52)
	close_room_btn.visible = false
	v.add_child(close_room_btn)
	start_game_btn.pressed.connect(_on_start_game_pressed)
	ready_btn.pressed.connect(_on_ready_pressed)
	close_room_btn.pressed.connect(_on_close_room_pressed)

	_place(panel, Vector2(EDGE, TOP), Vector2(SIDE, SCREEN.y - TOP - BOTTOM))


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
	_place(details, Vector2(center_x, details_y), Vector2(center_w, SCREEN.y - BOTTOM - details_y))


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
	_place(col, Vector2(SCREEN.x - EDGE - SIDE, TOP), Vector2(SIDE, SCREEN.y - TOP - BOTTOM))


func _on_character_pressed(char_id: int) -> void:
	selected_char_id = char_id
	roster.select(char_id)
	details.show_character(char_id)
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
		var empty_lbl := MenuKit.make_label("(henüz bulunamadı - host aynı ağda olmalı)", MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lan_found_vbox.add_child(empty_lbl)
		return
	for g in games:
		var btn := MenuKit.make_button("%s   (%s:%d)" % [g["name"], g["ip"], g["port"]], "tan", MenuKit.FS_SMALL, 40)
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
	else:
		room_info_label.text = "Bağlantı: %s (%s)" % [NetworkManager.room_code, "Host" if NetworkManager.is_host else "Katılımcı"]
		start_game_btn.visible = NetworkManager.is_host
		start_game_btn.disabled = not NetworkManager.all_players_ready()
		ready_btn.visible = not NetworkManager.is_host
		var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
		var local_ready: bool = NetworkManager.lobby_players.get(my_id, {}).get("is_ready", false)
		ready_btn.text = "HAZIR DEĞİLİM" if local_ready else "HAZIRIM"
		close_room_btn.visible = NetworkManager.is_host
		if _lan_host_btn: _lan_host_btn.disabled = true
		if _lan_join_btn: _lan_join_btn.disabled = true
		if _lan_ip_input: _lan_ip_input.editable = false
		## Zaten bağlandık - "Bulunan Oyunlar" listesi artık anlamsız, gizle
		## (dinleme de NetworkManager.host_lan/join_lan içinde zaten durduruldu).
		if _lan_found_header: _lan_found_header.visible = false
		if _lan_found_vbox: _lan_found_vbox.visible = false
		_refresh_public_ip_label()

	for child in player_list_container.get_children():
		child.queue_free()
	if NetworkManager.lobby_players.is_empty():
		var none := MenuKit.make_label("Odada henüz kimse yok", MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM)
		player_list_container.add_child(none)
	for pid in NetworkManager.lobby_players.keys():
		player_list_container.add_child(_make_player_row(NetworkManager.lobby_players[pid]))


## Odadaki bir oyuncu satırı: mini karakter (1x, idle ilk kare) + isim / karakter adı + HAZIR / BEKLİYOR rozeti.
func _make_player_row(pinfo: Dictionary) -> Control:
	var cdef: Dictionary = Characters.get_def(pinfo.get("char_id", 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var slot := MenuKit.make_panel("slot_normal")
	row.add_child(slot)
	var mini: Control = PreviewScript.new()
	mini.custom_minimum_size = Vector2(48, 48)
	slot.add_child(mini)
	mini.setup(cdef, 1, 46.0)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var host_tag: String = "  [HOST]" if pinfo.get("is_host", false) else ""
	var name_lbl := MenuKit.make_label("%s%s" % [pinfo.get("name", "Oyuncu"), host_tag], MenuKit.FS_BODY, MenuKit.C_TEXT)
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_lbl)
	col.add_child(MenuKit.make_label(str(cdef.get("name", "Karakter")), MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM))

	var is_ready: bool = pinfo.get("is_ready", false)
	var badge := MenuKit.make_panel("tag_pasif" if is_ready else "tag_ulti")
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(MenuKit.make_label("HAZIR" if is_ready else "BEKLİYOR", MenuKit.FS_SMALL, MenuKit.C_CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(badge)
	return row
