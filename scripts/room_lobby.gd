extends Control

## ODA LOBİSİ (2026-10-11 lobi sistemi, onaylanan prototipin 3. adımı): sadece toplanma - karakter seçimi YOK. Solda oda
## adı + oyuncular (yüz, isim, [HOST]) + sınıra kadar boş yerler, host'ta her oyuncunun yanında "At"; sağda oda bilgisi +
## sohbet. Host "KARAKTER SEÇİMİNE GEÇ" deyince herkes karakter seçimine (lobby_menu.gd) geçer (NetworkManager.set_lobby_phase).
## Oda oyundaysa (oyundan düşüp geri gelen) "OYUNA GERİ KATIL". Bağlantı koparsa / atılırsa oda listesine dönülür.

const LobbyUI := preload("res://scripts/menu_lobby_ui.gd")
const ChatScript: GDScript = preload("res://scripts/menu_lobby_chat.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")

var _mobile: bool = false
var _sz: Dictionary = {}
var _title: Label = null
var _count_label: Label = null
var _players: VBoxContainer = null
var _info_label: Label = null
var _status_label: Label = null
var _primary_btn: Button = null
var _leave_btn: Button = null
var _hint_label: Label = null
var _leaving: bool = false
const BODY_MAX := Vector2(1440, 800)


func _ready() -> void:
	theme = MenuKit.theme()
	MenuKit.add_background(self)
	_mobile = MobileUIScript.enabled
	_sz = LobbyUI.sizes(_mobile)
	if LobbyUI.leave_if_disconnected(self):
		_leaving = true
		return
	if NetworkManager.lobby_phase == NetworkManager.PHASE_SELECT:
		get_tree().change_scene_to_file.call_deferred("res://scenes/lobby_menu.tscn")
		return
	_build()
	NetworkManager.lobby_updated.connect(_refresh)
	NetworkManager.lobby_phase_changed.connect(_on_phase_changed)
	NetworkManager.connection_status_changed.connect(func(t: String) -> void:
		if _status_label: _status_label.text = t)
	_refresh()
	UISound.connect_all_buttons(self)


func _process(_delta: float) -> void:
	if not _leaving and LobbyUI.leave_if_disconnected(self):
		_leaving = true


func _build() -> void:
	var rect: Rect2 = LobbyUI.safe_rect(self, _mobile)
	var fs: int = int(_sz["fs_body"])
	var ctl_h: float = maxf(52.0, float(_sz["ctl_h"]))
	var top_h: float = clampf(roundf(rect.size.y * 0.11), 96.0, 150.0) if _mobile else 96.0

	var back := MenuKit.make_button("< Odadan çık", "tan", fs, top_h - 24.0 if _mobile else 56.0)
	back.pressed.connect(_on_leave_pressed)
	add_child(back)
	MenuKit.place(back, rect.position + Vector2(16, 12 if _mobile else 24), Vector2(300.0 if _mobile else 220.0, top_h - 24.0 if _mobile else 56.0))
	var banner := MenuKit.make_banner("Oda Lobisi", 48 if _mobile else MenuKit.FS_TITLE)
	add_child(banner)
	var bs: Vector2 = banner.get_combined_minimum_size()
	MenuKit.place(banner, Vector2(rect.position.x + roundf((rect.size.x - bs.x) * 0.5), rect.position.y + (6.0 if _mobile else 18.0)), bs)

	var body := Rect2(rect.position + Vector2(16, top_h + 12.0), rect.size - Vector2(32, top_h + 28.0))
	## Masaüstünde pencereler ekranı kaplamaz (2026-10-11 "arayüzün kendisi çok büyük"): en çok BODY_MAX, ortada.
	if not _mobile:
		var bsz: Vector2 = Vector2(minf(BODY_MAX.x, body.size.x), minf(BODY_MAX.y, body.size.y))
		body = Rect2(body.position + Vector2(roundf((body.size.x - bsz.x) * 0.5), roundf((body.size.y - bsz.y) * 0.35)), bsz)
	var left_w: float = roundf(body.size.x * 0.52)
	var gap: float = 16.0

	## Sol: oyuncular + düğmeler
	var left := MenuKit.make_panel("panel_tight")
	add_child(left)
	MenuKit.place(left, body.position, Vector2(left_w, body.size.y))
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 12 if _mobile else 10)
	left.add_child(lv)
	var head := HBoxContainer.new()
	lv.add_child(head)
	_title = MenuKit.make_label(NetworkManager.room_name, 48 if _mobile else MenuKit.FS_TITLE, MenuKit.C_ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_title)
	_count_label = MenuKit.make_label("", fs, MenuKit.C_TEXT_DIM)
	head.add_child(_count_label)
	lv.add_child(MenuKit.make_section_header("Oyuncular", fs))
	var list_box := MenuKit.make_panel("inset")
	list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(list_box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_box.add_child(scroll)
	_players = VBoxContainer.new()
	_players.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_players.add_theme_constant_override("separation", 8)
	scroll.add_child(_players)
	_hint_label = MenuKit.make_label("", int(_sz["fs_label"]), MenuKit.C_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_child(_hint_label)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	lv.add_child(btns)
	_leave_btn = MenuKit.make_button("ODADAN ÇIK", "rose", fs, ctl_h)
	_leave_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leave_btn.pressed.connect(_on_leave_pressed)
	btns.add_child(_leave_btn)
	_primary_btn = MenuKit.make_button("KARAKTER SEÇİMİNE GEÇ", "sage", fs, ctl_h)
	_primary_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_primary_btn.size_flags_stretch_ratio = 2.0
	_primary_btn.pressed.connect(_on_primary_pressed)
	btns.add_child(_primary_btn)

	## Sağ: oda bilgisi + sohbet
	var right := MenuKit.make_panel("panel_tight")
	add_child(right)
	MenuKit.place(right, body.position + Vector2(left_w + gap, 0), Vector2(body.size.x - left_w - gap, body.size.y))
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	right.add_child(rv)
	rv.add_child(MenuKit.make_section_header("Oda", fs))
	var info_box := MenuKit.make_panel("inset")
	rv.add_child(info_box)
	var info_v := VBoxContainer.new()
	info_box.add_child(info_v)
	_info_label = MenuKit.make_label("", int(_sz["fs_label"]), MenuKit.C_TEXT)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_v.add_child(_info_label)
	_status_label = MenuKit.make_label(NetworkManager.last_status_message, int(_sz["fs_label"]), MenuKit.C_TEXT_DIM)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_v.add_child(_status_label)
	var chat: VBoxContainer = ChatScript.new()
	chat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(chat)
	var chat_sz: Dictionary = _sz.duplicate()
	chat_sz["chat_fs"] = int(_sz["fs_label"])
	chat_sz["chat_input_fs"] = int(_sz["fs_input"])
	chat_sz["chat_input_h"] = float(_sz["input_h"])
	chat.setup(chat_sz, _mobile, 200.0, true)


func _refresh() -> void:
	if _players == null or not NetworkManager.is_multiplayer_active:
		return
	var k: int = int(_sz["k"])
	var lp: Dictionary = NetworkManager.lobby_players
	_title.text = NetworkManager.room_name
	_count_label.text = "%d / %d" % [lp.size(), NetworkManager.room_max_players]
	for c in _players.get_children():
		_players.remove_child(c)
		c.queue_free()
	var ids: Array = lp.keys()
	ids.sort()
	var me: int = multiplayer.get_unique_id()
	for pid in ids:
		var extra: Control = null
		if NetworkManager.is_host and int(pid) != me:
			var kick := MenuKit.make_button("At", "rose", int(_sz["fs_small"]), float(_sz["ctl_h"]) * 0.8)
			kick.tooltip_text = "Oyuncuyu odadan çıkar (bu oda kapanana kadar geri giremez)"
			kick.pressed.connect(NetworkManager.kick_player.bind(int(pid)))
			extra = kick
		var info: Dictionary = (lp[pid] as Dictionary).duplicate()
		if int(pid) == me:
			info["name"] = "%s (sen)" % info.get("name", "Oyuncu")
		_players.add_child(LobbyUI.make_player_row(info, {"fs_body": int(_sz["fs_body"]), "fs_small": int(_sz["fs_small"]), "k": k,
			"ready_badge": false, "extra": extra}))
	for i in range(lp.size(), NetworkManager.room_max_players):
		_players.add_child(LobbyUI.make_empty_row(int(_sz["fs_body"]), k))
	UISound.connect_all_buttons(_players)

	var kind: String = "İnternet (Epic)" if NetworkManager.is_online_session else "Aynı ağ (LAN) - %s" % NetworkManager.room_code
	_info_label.text = "Bağlantı: %s\nŞifre: %s\nEn fazla oyuncu: %d" % [kind, "var" if not NetworkManager.room_password.is_empty() else "yok",
		NetworkManager.room_max_players]

	if NetworkManager.is_host:
		_leave_btn.text = "ODAYI KAPAT"
		_primary_btn.visible = true
		_primary_btn.text = "KARAKTER SEÇİMİNE GEÇ"
		_primary_btn.disabled = false
		_hint_label.text = "Herkes gelince karakter seçimine geç. Oyuncuyu çıkarmak için yanındaki \"At\"."
	elif NetworkManager.is_join_blocked_by_game():
		_leave_btn.text = "ODADAN ÇIK"
		_primary_btn.visible = false
		_hint_label.text = "Bu oyun başlamış - sadece oyundan düşen oyuncular geri katılabilir."
	elif NetworkManager.is_room_game_in_progress():
		_leave_btn.text = "ODADAN ÇIK"
		_primary_btn.visible = true
		var my_ready: bool = bool(lp.get(me, {}).get("is_ready", false))
		_primary_btn.text = "OYUNA KATILIYOR..." if my_ready else "OYUNA GERİ KATIL"
		_primary_btn.disabled = my_ready
		_hint_label.text = "Oda oyunda: kaldığın yerden devam edebilirsin."
	else:
		_leave_btn.text = "ODADAN ÇIK"
		_primary_btn.visible = false
		_hint_label.text = "Host karakter seçimine geçince ekran kendiliğinden değişir."


func _on_primary_pressed() -> void:
	if NetworkManager.is_host:
		NetworkManager.set_lobby_phase(NetworkManager.PHASE_SELECT)
	elif NetworkManager.is_room_game_in_progress():
		NetworkManager.set_local_ready(true)


func _on_phase_changed(phase: String) -> void:
	if phase == NetworkManager.PHASE_SELECT and is_inside_tree():
		get_tree().change_scene_to_file.call_deferred("res://scenes/lobby_menu.tscn")


func _on_leave_pressed() -> void:
	_leaving = true
	if NetworkManager.is_host:
		NetworkManager.close_room()
	else:
		NetworkManager.disconnect_from_room(false)
	NetworkManager.last_status_message = ""
	get_tree().change_scene_to_file("res://scenes/room_browser.tscn")
