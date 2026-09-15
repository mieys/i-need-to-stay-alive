extends Control

const BASE_STATS := "Can:100  Hız:240  Hasar:10  AteşHızı:1.0/sn"

@onready var status_label: Label = $TopBar/StatusLabel
@onready var back_btn: Button = $TopBar/BackBtn
@onready var player_name_input: LineEdit = $LeftPanel/Margin/VBox/NameHBox/PlayerNameInput
@onready var create_btn: Button = $LeftPanel/Margin/VBox/CreateBtn
@onready var join_btn: Button = $LeftPanel/Margin/VBox/JoinHBox/JoinBtn
@onready var room_code_input: LineEdit = $LeftPanel/Margin/VBox/JoinHBox/RoomCodeInput
@onready var room_info_label: Label = $LeftPanel/Margin/VBox/RoomInfoLabel
@onready var public_ip_label: Label = $LeftPanel/Margin/VBox/PublicIpLabel
@onready var player_list_container: VBoxContainer = $LeftPanel/Margin/VBox/PlayerScroll/PlayerListVBox
@onready var start_game_btn: Button = $LeftPanel/Margin/VBox/StartGameBtn
@onready var ready_btn: Button = $LeftPanel/Margin/VBox/ReadyBtn
@onready var close_room_btn: Button = $LeftPanel/Margin/VBox/CloseRoomBtn

@onready var grid: GridContainer = $RightArea/VBox/Grid
## Kullanıcı isteği: "her açıklama ikonun yanında görünmeli açıklamalar
## ikonlardan bağımsız konumdalar" - character_select.gd'deki ile birebir
## aynı satır tabanlı yerleşim (bkz. lobby_menu.tscn UltiRow/TemelRow/
## PassiveRow).
@onready var name_label: Label = $RightArea/InfoPanel/InfoMargin/InfoVBoxOuter/NameLabel
@onready var stats_label: Label = $RightArea/InfoPanel/InfoMargin/InfoVBoxOuter/StatsLabel
@onready var ulti_row: HBoxContainer = $RightArea/InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/UltiRow
@onready var skill_icon_1 = $RightArea/InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/UltiRow/SkillIcon1
@onready var ulti_desc_label: Label = $RightArea/InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/UltiRow/UltiDescLabel
@onready var temel_row: HBoxContainer = $RightArea/InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/TemelRow
@onready var skill_icon_2 = $RightArea/InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/TemelRow/SkillIcon2
@onready var temel_desc_label: Label = $RightArea/InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/TemelRow/TemelDescLabel
## Kullanıcı isteği: "karakterlerin pasiflerinin ikonu da görünmeli" -
## hud.gd _setup_ability_icons() ile aynı mantık (bkz. character_select.gd).
@onready var passive_row: HBoxContainer = $RightArea/InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/PassiveRow
@onready var passive_icon = $RightArea/InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/PassiveRow/PassiveIcon
@onready var passive_desc_label: Label = $RightArea/InfoPanel/InfoMargin/InfoVBoxOuter/TextScroll/RowsVBox/PassiveRow/PassiveDescLabel

var selected_char_id: int = 1
var cards: Dictionary = {}
var _select_frame_style_off: StyleBoxFlat
var _select_frame_style_on: StyleBoxFlat

var _lan_host_btn: Button = null
var _lan_join_btn: Button = null
var _lan_ip_input: LineEdit = null
var _lan_separator: HSeparator = null
var _lan_title: Label = null
var _mode_select_panel: PanelContainer = null
var current_mode: String = ""


func _ready() -> void:
	create_btn.pressed.connect(_on_create_room_pressed)
	join_btn.pressed.connect(_on_join_room_pressed)
	start_game_btn.pressed.connect(_on_start_game_pressed)
	ready_btn.pressed.connect(_on_ready_pressed)
	close_room_btn.pressed.connect(_on_close_room_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	
	NetworkManager.lobby_updated.connect(_update_lobby_ui)
	NetworkManager.connection_status_changed.connect(_on_status_changed)

	## DÜZELTME (kullanıcı bildirimi: "insanlar lobiye girdikten sonra ismini
	## değiştiremiyor") - bu alan eskiden sadece odaya girmeden ÖNCEki
	## "başlangıç ismi"ni okuyordu, odadayken düzenlemenin hiçbir etkisi
	## yoktu. Artık Enter'a basınca YA DA alandan çıkınca (zaten odadaysa)
	## yeni isim herkese yayınlanıyor (bkz. NetworkManager.update_local_
	## player_name).
	player_name_input.text_submitted.connect(_on_player_name_submitted)
	player_name_input.focus_exited.connect(func(): _on_player_name_submitted(player_name_input.text))

	# Dynamically add LAN controls to the UI
	var vbox: VBoxContainer = $LeftPanel/Margin/VBox as VBoxContainer
	var join_hbox_node = $LeftPanel/Margin/VBox/JoinHBox
	var insert_idx: int = join_hbox_node.get_index() + 1
	
	_lan_separator = HSeparator.new()
	vbox.add_child(_lan_separator)
	vbox.move_child(_lan_separator, insert_idx)
	
	_lan_title = Label.new()
	_lan_title.text = "LAN (Yerel Ağ) Bağlantısı"
	_lan_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lan_title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_lan_title)
	vbox.move_child(_lan_title, insert_idx + 1)
	
	# Row 1: LineEdit for IP:Port
	_lan_ip_input = LineEdit.new()
	_lan_ip_input.placeholder_text = "IP:Port (örn. 192.168.1.50:7777)"
	_lan_ip_input.text = "127.0.0.1:7777"
	_lan_ip_input.custom_minimum_size = Vector2(0, 44)
	vbox.add_child(_lan_ip_input)
	vbox.move_child(_lan_ip_input, insert_idx + 2)
	
	# Row 2: HBox for buttons
	var lan_hbox := HBoxContainer.new()
	lan_hbox.name = "LanHBox"
	lan_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(lan_hbox)
	vbox.move_child(lan_hbox, insert_idx + 3)
	
	_lan_host_btn = Button.new()
	_lan_host_btn.text = "LAN Kur"
	_lan_host_btn.custom_minimum_size = Vector2(0, 44)
	_lan_host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lan_hbox.add_child(_lan_host_btn)
	
	_lan_join_btn = Button.new()
	_lan_join_btn.text = "LAN Katıl"
	_lan_join_btn.custom_minimum_size = Vector2(0, 44)
	_lan_join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lan_hbox.add_child(_lan_join_btn)
	
	# Row 3: Small helper text explaining where to get IP
	var lan_info_lbl := Label.new()
	lan_info_lbl.name = "LanInfoLbl"
	lan_info_lbl.text = "NOT: LAN kurmak/katılmak için bilgisayarınızın yerel IP adresini (CMD -> ipconfig komutundan görebileceğiniz IPv4 adresini) kullanın."
	lan_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lan_info_lbl.add_theme_font_size_override("font_size", 14)
	lan_info_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	vbox.add_child(lan_info_lbl)
	vbox.move_child(lan_info_lbl, insert_idx + 4)
	
	_lan_host_btn.pressed.connect(func():
		var parts: Array = _lan_ip_input.text.split(":")
		var port: int = 7777
		if parts.size() > 1:
			port = int(parts[1])
		var pname: String = player_name_input.text.strip_edges()
		if pname.is_empty():
			pname = "Kurucu (LAN)"
		NetworkManager.host_lan(port, pname, selected_char_id)
	)
	
	_lan_join_btn.pressed.connect(func():
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
	)
	
	# Initial UI State: Hide panels, show Mode Selection!
	$LeftPanel.visible = false
	$RightArea.visible = false
	_create_mode_select_ui()
	
	_populate_character_grid()
	_update_lobby_ui()
	_on_character_pressed(1)
	
	UISound.connect_all_buttons(self)
	UISound.apply_wood_buttons(self) ## bkz. ui_sound.gd - tüm butonları ahşap stile çevirir


func _create_mode_select_ui() -> void:
	if _mode_select_panel:
		_mode_select_panel.queue_free()
		
	_mode_select_panel = PanelContainer.new()
	_mode_select_panel.custom_minimum_size = Vector2(600, 480)
	_mode_select_panel.set_anchors_preset(Control.PRESET_CENTER)
	_mode_select_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mode_select_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mode_select_panel.offset_left = -300
	_mode_select_panel.offset_right = 300
	_mode_select_panel.offset_top = -240
	_mode_select_panel.offset_bottom = 240
	add_child(_mode_select_panel)
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	panel_style.border_width_left = 4
	panel_style.border_width_top = 4
	panel_style.border_width_right = 4
	panel_style.border_width_bottom = 4
	panel_style.border_color = Color(0.4, 0.35, 0.25, 1.0)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.corner_radius_bottom_left = 16
	## Kullanıcı isteği: gölge tüm oyun pencerelerinde tutarlı olsun (pixel
	## stili: keskin, sağ-alta kayan hafif gölge).
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 2
	panel_style.shadow_offset = Vector2(3, 4)
	_mode_select_panel.add_theme_stylebox_override("panel", panel_style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	_mode_select_panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	var title := Label.new()
	title.text = "ÇOK OYUNCULU MODU SEÇ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	## Kullanıcı isteği: "çok oyunculu modu seçim ekranındaki fontları %50
	## büyüt" - bu panelin tüm font_size'ları (başlık/buton/açıklama) x1.5.
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	vbox.add_child(title)

	# Ziva Cloud Button
	var ziva_btn := Button.new()
	ziva_btn.text = "ZIVA CLOUD (Bulut Lobi)"
	ziva_btn.custom_minimum_size = Vector2(0, 70)
	ziva_btn.add_theme_font_size_override("font_size", 36)
	vbox.add_child(ziva_btn)

	var ziva_desc := Label.new()
	ziva_desc.text = "Oda koduyla internet üzerinden port yönlendirmesiz hızlı bağlantı."
	ziva_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ziva_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	ziva_desc.add_theme_font_size_override("font_size", 24)
	ziva_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(ziva_desc)

	# LAN Button
	var lan_btn := Button.new()
	lan_btn.text = "LAN (Yerel Ağ Bağlantısı)"
	lan_btn.custom_minimum_size = Vector2(0, 70)
	lan_btn.add_theme_font_size_override("font_size", 36)
	vbox.add_child(lan_btn)

	var lan_desc := Label.new()
	lan_desc.text = "Aynı ev/ofis ağındaki bilgisayarlar için IP adresiyle doğrudan bağlantı."
	lan_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lan_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	lan_desc.add_theme_font_size_override("font_size", 24)
	lan_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(lan_desc)
	
	ziva_btn.pressed.connect(func():
		_enter_lobby_mode("ziva")
	)
	
	lan_btn.pressed.connect(func():
		_enter_lobby_mode("lan")
	)
	
	if is_inside_tree():
		UISound.connect_all_buttons(self)
		UISound.apply_wood_buttons(self) ## bkz. ui_sound.gd - tüm butonları ahşap stile çevirir


func _enter_lobby_mode(mode: String) -> void:
	current_mode = mode
	if _mode_select_panel:
		_mode_select_panel.visible = false
	
	$LeftPanel.visible = true
	$RightArea.visible = true
	
	# Set visibility of host/join controls based on mode
	create_btn.visible = (mode == "ziva")
	$LeftPanel/Margin/VBox/OrLabel.visible = (mode == "ziva")
	join_btn.get_parent().visible = (mode == "ziva") # JoinHBox
	
	if _lan_title: _lan_title.visible = (mode == "lan")
	if _lan_ip_input: _lan_ip_input.visible = (mode == "lan")
	if _lan_separator: _lan_separator.visible = (mode == "lan")
	
	var vbox: VBoxContainer = $LeftPanel/Margin/VBox as VBoxContainer
	var lan_hbox = vbox.get_node_or_null("LanHBox")
	if lan_hbox: lan_hbox.visible = (mode == "lan")
	var lan_info_lbl = vbox.get_node_or_null("LanInfoLbl")
	if lan_info_lbl: lan_info_lbl.visible = (mode == "lan")
	
	# Update Title
	$TopBar/Title.text = "ZIVA BULUT LOBİSİ" if mode == "ziva" else "YEREL AĞ (LAN) LOBİSİ"
	_update_lobby_ui()


## Kullanıcı isteği: "çok oyunculu karakter seçim ekranındaki karakter
## kartlarını tek oyunculudaki gibi yap" - aşağıdaki üç stil fonksiyonu ve
## _populate_character_grid/_fit_label_font, character_select.gd'deki
## _build_portrait_card_style / _build_name_card_style / _build_select_
## frame_style / _ready-içi kart kurulumu / _fit_label_font ile birebir
## aynı (portre+isim iki parçalı kaynaşık kart, seçim karartma yerine
## yeşil çerçeveyle gösteriliyor - bkz. o dosyadaki notlar).
static func _build_portrait_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.32, 0.2, 0.11, 1)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 0
	style.border_color = Color(0.16, 0.09, 0.04, 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 0
	style.corner_radius_bottom_left = 0
	return style


static func _build_name_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.52, 0.34, 0.15, 1)
	style.border_width_left = 3
	style.border_width_top = 0
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.16, 0.09, 0.04, 1)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style


static func _build_select_frame_style(highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	var w: int = 5 if highlighted else 0
	style.border_width_left = w
	style.border_width_top = w
	style.border_width_right = w
	style.border_width_bottom = w
	style.border_color = Color(0.22, 0.62, 0.2, 1.0)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.content_margin_left = 6
	style.content_margin_top = 6
	style.content_margin_right = 6
	style.content_margin_bottom = 6
	return style


func _populate_character_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	cards.clear()

	var portrait_style := _build_portrait_card_style()
	var name_style := _build_name_card_style()
	_select_frame_style_off = _build_select_frame_style(false)
	_select_frame_style_on = _build_select_frame_style(true)

	for char_id in Characters.DEFS:
		var def: Dictionary = Characters.DEFS[char_id]

		var outer := VBoxContainer.new()
		outer.add_theme_constant_override("separation", 0)
		outer.alignment = BoxContainer.ALIGNMENT_CENTER

		var card_panel := PanelContainer.new()
		card_panel.custom_minimum_size = Vector2(148, 140)
		card_panel.clip_contents = true
		card_panel.add_theme_stylebox_override("panel", portrait_style)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		card_panel.add_child(margin)

		var portrait_center := CenterContainer.new()
		margin.add_child(portrait_center)

		var button := TextureButton.new()
		button.custom_minimum_size = Vector2(122, 122)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if ResourceLoader.exists(def["portrait"]):
			button.texture_normal = load(def["portrait"])
		button.pressed.connect(_on_character_pressed.bind(char_id))
		portrait_center.add_child(button)

		outer.add_child(card_panel)

		var name_card := PanelContainer.new()
		name_card.custom_minimum_size = Vector2(148, 42)
		name_card.clip_contents = true
		name_card.add_theme_stylebox_override("panel", name_style)

		var name_margin := MarginContainer.new()
		name_margin.add_theme_constant_override("margin_left", 4)
		name_margin.add_theme_constant_override("margin_top", 4)
		name_margin.add_theme_constant_override("margin_right", 4)
		name_margin.add_theme_constant_override("margin_bottom", 4)
		name_card.add_child(name_margin)

		var label := Label.new()
		label.text = def["name"]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		name_margin.add_child(label)
		_fit_label_font(label, def["name"], 30, 18, 148 - 8)

		outer.add_child(name_card)

		var select_frame := PanelContainer.new()
		select_frame.add_theme_stylebox_override("panel", _select_frame_style_off)
		select_frame.add_child(outer)

		grid.add_child(select_frame)
		cards[char_id] = select_frame


## bkz. character_select.gd _fit_label_font - birebir aynı.
func _fit_label_font(label: Label, txt: String, start_size: int, min_size: int, max_width: float) -> void:
	var font_size: int = start_size
	var font: Font = label.get_theme_font("font")
	if not font:
		font = ThemeDB.fallback_font
	while font_size > min_size:
		var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		if w <= max_width:
			break
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)


func _on_character_pressed(char_id: int) -> void:
	selected_char_id = char_id
	var def: Dictionary = Characters.get_def(char_id)
	name_label.text = def["name"]
	## bkz. character_select.gd - artık tüm karakterler ortak silahla
	## saldırdığı için "Sınıf: Yakıncı/Menzilli" etiketi kaldırıldı.
	stats_label.text = BASE_STATS

	skill_icon_1.skill_id = def.get("skill", 1)
	skill_icon_1.custom_texture = load(def["skill_icon"]) if def.has("skill_icon") else null
	skill_icon_1.queue_redraw()
	ulti_desc_label.text = "%s (R tuşu): %s" % [def.get("skill_name", "Ulti"), def["skill_desc"]]

	var has_skill2: bool = def.has("skill2")
	temel_row.visible = has_skill2
	if has_skill2:
		skill_icon_2.skill_id = def.get("skill2", 1)
		skill_icon_2.custom_texture = load(def["skill2_icon"]) if def.has("skill2_icon") else null
		skill_icon_2.queue_redraw()
		temel_desc_label.text = "%s (E tuşu): %s" % [def.get("skill2_name", "Temel"), def["skill2_desc"]]

	## Pasif satırı: hud.gd _setup_ability_icons() ile aynı mantık.
	var has_passive: bool = def.has("passive") and not str(def["passive"]).is_empty()
	passive_row.visible = has_passive
	if has_passive:
		## bkz. hud.gd _setup_ability_icons() üstündeki AYNI DÜZELTME notu.
		passive_icon.skill_id = def.get("passive_vector_id", -1)
		var p_tex_path: String = def.get("passive_icon", "")
		passive_icon.custom_texture = load(p_tex_path) if p_tex_path != "" and ResourceLoader.exists(p_tex_path) else null
		passive_icon.queue_redraw()
		passive_desc_label.text = "Pasif: %s" % def["passive"]

	## Kullanıcı isteği: "tek oyunculudaki gibi yap" - character_select.gd'deki
	## gibi karartma (modulate) değil, seçili karta yeşil çerçeve.
	for id in cards:
		var frame: PanelContainer = cards[id]
		frame.add_theme_stylebox_override("panel", _select_frame_style_on if id == char_id else _select_frame_style_off)

	NetworkManager.update_local_character(char_id)


func _on_create_room_pressed() -> void:
	var pname: String = player_name_input.text.strip_edges()
	if pname.is_empty():
		pname = "Oyuncu 1"
	## Ziva relay'inde yeni bir oda kodu üretip o odaya katılır (bkz.
	## NetworkManager create_room / _generate_room_code).
	NetworkManager.create_room(0, pname, selected_char_id)


func _on_join_room_pressed() -> void:
	## Host'un paylaştığı oda kodu giriliyor (relay tabanlı - IP/port DEĞİL).
	var code: String = room_code_input.text.strip_edges()
	var pname: String = player_name_input.text.strip_edges()
	if pname.is_empty():
		pname = "Oyuncu 2"
	if code.is_empty():
		status_label.text = "Lütfen oda kodunu girin!"
		return
	NetworkManager.join_room(code, pname, selected_char_id)


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
		
	if current_mode != "":
		current_mode = ""
		$LeftPanel.visible = false
		$RightArea.visible = false
		if _mode_select_panel:
			_mode_select_panel.visible = true
		$TopBar/Title.text = "ÇOK OYUNCULU LOBİ"
		return
		
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_status_changed(status_text: String) -> void:
	status_label.text = status_text


## Ziva/LAN üzerinden bağlantı bilgisi
func _refresh_public_ip_label() -> void:
	public_ip_label.visible = true
	if NetworkManager.is_lan_mode:
		public_ip_label.text = "LAN bağlantısı kuruldu. IP:Port : %s" % NetworkManager.room_code
	else:
		public_ip_label.text = "Arkadaşların katılması için bu oda kodunu paylaş: %s" % NetworkManager.room_code


func _update_lobby_ui() -> void:
	if not NetworkManager.is_multiplayer_active:
		room_info_label.text = "Oda: Henüz Bağlı Değil"
		start_game_btn.visible = false
		ready_btn.visible = false
		close_room_btn.visible = false
		create_btn.disabled = false
		join_btn.disabled = false
		public_ip_label.visible = false
		if _lan_host_btn: _lan_host_btn.disabled = false
		if _lan_join_btn: _lan_join_btn.disabled = false
		if _lan_ip_input: _lan_ip_input.editable = true
	else:
		room_info_label.text = "Oda Kodu: %s (%s)" % [NetworkManager.room_code, "Host" if NetworkManager.is_host else "Katılımcı"]
		start_game_btn.visible = NetworkManager.is_host
		start_game_btn.disabled = not NetworkManager.all_players_ready()
		ready_btn.visible = not NetworkManager.is_host
		var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
		var local_ready: bool = NetworkManager.lobby_players.get(my_id, {}).get("is_ready", false)
		ready_btn.text = "HAZIR DEĞİLİM" if local_ready else "HAZIRIM"
		close_room_btn.visible = NetworkManager.is_host
		create_btn.disabled = true
		join_btn.disabled = true
		if _lan_host_btn: _lan_host_btn.disabled = true
		if _lan_join_btn: _lan_join_btn.disabled = true
		if _lan_ip_input: _lan_ip_input.editable = false
		_refresh_public_ip_label()
	
	for child in player_list_container.get_children():
		child.queue_free()
	
	for pid in NetworkManager.lobby_players.keys():
		var pinfo: Dictionary = NetworkManager.lobby_players[pid]
		var cdef: Dictionary = Characters.get_def(pinfo.get("char_id", 1))
		var cname: String = cdef.get("name", "Karakter")
		var host_tag: String = " [HOST]" if pinfo.get("is_host", false) else ""
		
		var lbl := Label.new()
		var ready_tag: String = " [HAZIR]" if pinfo.get("is_ready", false) else " [HAZIR DEĞİL]"
		lbl.text = "• %s (%s)%s%s" % [pinfo.get("name", "Oyuncu"), cname, host_tag, ready_tag]
		lbl.add_theme_font_size_override("font_size", 20)
		player_list_container.add_child(lbl)

