extends Control

## Çok oyunculu ODA LİSTESİ (kullanıcı isteği 2026-10-11: "insanlar oda kurup odalarına şifre koyup oyuncu sayısı v.b limitleri
## koyup birbirlerinin odalarına girebilmeli"; onaylanan prototip: oda listesi + "Oda kur" penceresi + şifre sorusu).
## Akış: burası -> karakter seçimi (lobby_menu.gd; 2026-10-16 oda lobisi room_lobby.gd aradan çıktı, sadece eski sürümlü host için duruyor). Ekran tamamen KODLA kurulur (.tscn sadece kök).
## Liste: aynı ağdaki (LAN beacon v2) + internet (Epic) odaları TEK listede; satır = oda adı, host, oyuncu x/sınır, tür, şifre,
## durum. Kilitli odaya tıklayınca satırın altında şifre sorulur; dolu oda tıklanmaz; "oyunda" oda tıklanır (sadece o oyundan
## düşenler geri girebilir - host kalanları reddeder). Altta elle "IP ile katıl" yedeği. Şifre/sınır kontrolü HOST'ta yapılır
## (bkz. network_manager.gd ODA AYARLARI bloğu), buradaki kilit sadece arayüz bilgisi.
## MASAÜSTÜ (2026-10-16, kullanıcı: "oda kurma ekranını çok oyunculu moda uygun hale getir" + "arka plan ana menüdekiyle aynı olsun"):
## karakter seçimiyle (lobby_select_desktop.gd "SEÇİM D") AYNI ızgara + koyu kit (menu_dark_kit.gd) + "Ocak Başı" arka planı
## (menu_hearth_bg.gd): sol sütun mod kutusu (ANA MENÜ, durum) + adın + HEP AÇIK "ODA KUR" formu (eski açılır pencere), sağ oda listesi,
## alt sağ IP ile katıl. TELEFON: eski bej yerleşim (_build_mobile + _build_dialog açılır pencere), arka plan aynı sahne.

const UiAnim := preload("res://scripts/ui_anim.gd")
const LobbyUI := preload("res://scripts/menu_lobby_ui.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const DK := preload("res://tools/proto_20261017/out/panel_renk/kod/kit_a.gd")
const HearthBg := preload("res://tools/proto_20261017/out/panel_renk/kod/hb_a.gd")
## Masaüstü ızgarası (lobby_select_desktop.gd LEFT / MID+RIGHT / START_Y ile aynı sütunlar).
const D_LEFT := Rect2(32, 24, 440, 1024)
const D_LIST := Rect2(488, 24, 1400, 908)
const D_IP := Rect2(488, 948, 1400, 100)
const D_ROW_H := 68.0
const D_INPUT_H := 52.0
const ONLINE_REFRESH_SEC := 8.0
const LAN_PORT := 7777
const PLAYER_CHOICES := [2, 3, 4, 5, 6, 7, 8]
const DEFAULT_MAX_PLAYERS := 4
const PASSWORD_MAX_LEN := 32
const PANEL_MAX := Vector2(1200, 800)
const DIALOG_W := 600.0

var _mobile: bool = false
var _sz: Dictionary = {}
var _status_label: Label = null
var _name_input: LineEdit = null
var _list: VBoxContainer = null
var _ip_input: LineEdit = null
var _refresh_btn: Button = null
var _create_btn: Button = null

var _online_rooms: Array = []
var _online_searched: bool = false
var _online_timer: Timer = null
## Şifre sorusu açık olan satır (oda anahtarı) + o satırın hata mesajı.
var _pw_key: String = ""
var _pw_error: String = ""
var _pw_input: LineEdit = null
## Şu an katılmaya çalışılan oda (ret gelirse şifre sorusu ona açılır).
var _pending: Dictionary = {}
## IP ile katılınca şifre istendiyse listede satırı olmadığı için geçici satır (şifre sorusu altında açılır).
var _ip_room: Dictionary = {}
## Çift tıklamayı önler. Epic adımları (await) saniyeler sürebilir - LAN'da bağlantı düşünce, internette en geç BUSY_MIN_MS sonra
## yeniden açılır (tekrar basmak eski denemeyi zaten iptal eder, bkz. NetworkManager._online_attempt).
var _busy: bool = false
var _busy_since_msec: int = 0
const BUSY_MIN_MS := 1500

## "Oda kur" penceresi.
var _dialog: Control = null
var _room_name_input: LineEdit = null
var _room_pw_input: LineEdit = null
var _max_buttons: Dictionary = {} ## int -> Button
var _max_players: int = DEFAULT_MAX_PLAYERS
var _online_choice_btn: Button = null
var _lan_choice_btn: Button = null
var _use_online: bool = false
var _dialog_error: Label = null
## Masaüstü: oda sayısı (liste başlığı) + bağlantı seçiminin açıklaması.
var _count_label: Label = null
var _conn_hint: Label = null


func _ready() -> void:
	_mobile = MobileUIScript.enabled
	theme = MenuKit.theme() if _mobile else DK.theme()
	HearthBg.add_to(self, 0.0 if _mobile else HearthBg.DIM_DESKTOP)
	_sz = LobbyUI.sizes(_mobile)
	if NetworkManager.is_multiplayer_active:
		_go_to_room.call_deferred()
		return
	if _mobile:
		_build_mobile()
		_build_dialog()
	else:
		_build_desktop()
	NetworkManager.room_entered.connect(_on_room_entered)
	NetworkManager.room_join_rejected.connect(_on_join_rejected)
	NetworkManager.connection_status_changed.connect(_on_status)
	NetworkManager.server_disconnected.connect(_on_join_failed)
	NetworkManager.lan_games_updated.connect(_rebuild_list)
	NetworkManager.start_lan_discovery_listen()
	if not NetworkManager.last_status_message.is_empty():
		_status_label.text = NetworkManager.last_status_message
		NetworkManager.last_status_message = ""
	if NetworkManager.is_online_available():
		_online_timer = Timer.new()
		_online_timer.wait_time = ONLINE_REFRESH_SEC
		_online_timer.timeout.connect(_refresh_online)
		add_child(_online_timer)
		_online_timer.start()
		_refresh_online.call_deferred()
	_rebuild_list()
	UISound.connect_all_buttons(self)


func _exit_tree() -> void:
	NetworkManager.stop_lan_discovery_listen()


func _process(_delta: float) -> void:
	## Bağlanma denemesi bittiyse (başarısız / reddedildi / koptu) düğmeler yeniden açılsın.
	if _busy and not NetworkManager.is_multiplayer_active and Time.get_ticks_msec() - _busy_since_msec > BUSY_MIN_MS:
		_set_busy(false)


func _unhandled_input(event: InputEvent) -> void:
	if _mobile or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if not _pw_key.is_empty(): ## açık şifre sorusu önce kapanır
		_pw_key = ""
		_pw_error = ""
		_rebuild_list()
	else:
		_on_back_pressed()


# ---------------------------------------------------------------------------------------------------- masaüstü yerleşimi (SEÇİM D)
func _build_desktop() -> void:
	var col := DK.v(16)
	col.add_child(_d_mode_box())
	col.add_child(_d_name_card())
	var form := _d_create_box()
	form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(form)
	_d_put(col, D_LEFT)
	_d_put(_d_list_box(), D_LIST)
	_d_put(_d_ip_box(), D_IP)
	_room_name_input.text = "%s odası" % _player_name()
	_set_max_players(DEFAULT_MAX_PLAYERS)
	_set_connection(NetworkManager.is_online_available())


func _d_put(c: Control, r: Rect2) -> void:
	add_child(c)
	MenuKit.place(c, r.position, r.size)


func _d_input(text: String, placeholder: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.custom_minimum_size = Vector2(0, D_INPUT_H)
	e.add_theme_font_size_override("font_size", DK.FS_BODY)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return e


## Seçimdeki oda kutusunun yerinde: başlık + ANA MENÜ + bilgi çipleri + durum metni.
func _d_mode_box() -> PanelContainer:
	var box := DK.box(DK.C_PANEL, DK.C_LINE, 14)
	var v := DK.v(8)
	var head := DK.h(10)
	var title := DK.lbl("ÇOK OYUNCULU", DK.FS_TITLE, DK.C_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back := DK.btn("ANA MENÜ", "ghost", DK.FS_LABEL, 44, 0)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.tooltip_text = "Ana menüye dön (Esc)"
	back.pressed.connect(_on_back_pressed)
	head.add_child(back)
	v.add_child(head)
	var chips := DK.h(8)
	chips.add_child(DK.chip(DK.G_GLOBE, "İnternet + LAN" if NetworkManager.is_online_available() else "Sadece LAN", DK.C_DIM))
	chips.add_child(DK.chip(DK.G_PERSON, "%d-%d kişi" % [NetworkManager.ROOM_MIN_PLAYERS, NetworkManager.MAX_PLAYERS], DK.C_DIM))
	v.add_child(chips)
	_status_label = DK.wrap("Bir odaya katıl ya da kendi odanı kur.", DK.FS_LABEL, DK.C_DIM, D_LEFT.size.x - 28, 3)
	v.add_child(_status_label)
	box.add_child(v)
	return box


## Adın: seçimdeki kendi oyuncu kartının görünümü (renk şeridi + yüz), ad yerinde düzenlenir.
func _d_name_card() -> PanelContainer:
	var card := DK.box(DK.C_PANEL3, DK.C_ACCENT, 10)
	var hb := DK.h(12)
	var stripe := ColorRect.new()
	stripe.color = DK.player_color(0)
	stripe.custom_minimum_size = Vector2(6, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(stripe)
	var fb := DK.box(DK.C_INSET, DK.C_LINE, 2, 2, 3)
	fb.add_child(DK.icon(LobbyUI.face_texture(str(Characters.get_def(NetworkManager.local_char_id).get("portrait", ""))), 72))
	hb.add_child(fb)
	var v := DK.v(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(DK.lbl("ADIN", DK.FS_LABEL, DK.C_ACCENT))
	_name_input = _d_input(NetworkManager.local_player_name, "Adını gir", 20)
	_name_input.text_submitted.connect(func(_t: String) -> void: _commit_name())
	_name_input.focus_exited.connect(_commit_name)
	v.add_child(_name_input)
	hb.add_child(v)
	card.add_child(hb)
	return card


## Eski "Oda kur" penceresinin alanları, hep açık.
func _d_create_box() -> PanelContainer:
	var box := DK.box(DK.C_PANEL, DK.C_LINE, 16)
	var v := DK.v(10)
	v.add_child(DK.title_bar("ODA KUR"))
	v.add_child(DK.lbl("Oda adı", DK.FS_LABEL, DK.C_DIM))
	_room_name_input = _d_input("", "Odanın adı", 32)
	_room_name_input.text_submitted.connect(func(_t: String) -> void: _on_create_pressed())
	v.add_child(_room_name_input)
	v.add_child(DK.lbl("Şifre  (boşsa herkes girebilir)", DK.FS_LABEL, DK.C_DIM))
	_room_pw_input = _d_input("", "Şifresiz", PASSWORD_MAX_LEN)
	_room_pw_input.secret = true
	_room_pw_input.text_submitted.connect(func(_t: String) -> void: _on_create_pressed())
	v.add_child(_room_pw_input)
	v.add_child(DK.lbl("En fazla oyuncu", DK.FS_LABEL, DK.C_DIM))
	var max_row := DK.h(6)
	for n in PLAYER_CHOICES:
		var b := DK.btn(str(n), "tile", DK.FS_BODY, D_INPUT_H, 0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_max_players.bind(int(n)))
		max_row.add_child(b)
		_max_buttons[int(n)] = b
	v.add_child(max_row)
	v.add_child(DK.lbl("Bağlantı", DK.FS_LABEL, DK.C_DIM))
	var conn := DK.h(6)
	_online_choice_btn = DK.btn("İnternet", "tile", DK.FS_BODY, D_INPUT_H, 0)
	_online_choice_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_online_choice_btn.pressed.connect(_set_connection.bind(true))
	conn.add_child(_online_choice_btn)
	_lan_choice_btn = DK.btn("Aynı ağ (LAN)", "tile", DK.FS_BODY, D_INPUT_H, 0)
	_lan_choice_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lan_choice_btn.pressed.connect(_set_connection.bind(false))
	conn.add_child(_lan_choice_btn)
	if not NetworkManager.is_online_available():
		_online_choice_btn.disabled = true
		_online_choice_btn.tooltip_text = "Epic ayarları eksik (eos_credentials.cfg) - şimdilik sadece LAN."
	v.add_child(conn)
	_conn_hint = DK.wrap("", DK.FS_LABEL, DK.C_DIM, D_LEFT.size.x - 32, 2)
	v.add_child(_conn_hint)
	v.add_child(DK.sp(0, 0, false, true))
	_dialog_error = DK.wrap("", DK.FS_LABEL, DK.C_BAD, D_LEFT.size.x - 32, 2)
	v.add_child(_dialog_error)
	_create_btn = DK.btn("ODAYI KUR", "primary", DK.FS_TITLE, 72, 0)
	_create_btn.pressed.connect(_on_create_pressed)
	v.add_child(_create_btn)
	box.add_child(v)
	return box


## Sağ: oda listesi (seçimdeki orta + sağ sütunun yerinde).
func _d_list_box() -> PanelContainer:
	var box := DK.box(DK.C_PANEL, DK.C_LINE, 16)
	var v := DK.v(10)
	var right := DK.h(14)
	_count_label = DK.lbl("", DK.FS_LABEL, DK.C_DIM)
	right.add_child(_count_label)
	_refresh_btn = DK.btn("YENİLE", "ghost", DK.FS_LABEL, 40, 0)
	_refresh_btn.pressed.connect(_on_refresh_pressed)
	right.add_child(_refresh_btn)
	v.add_child(DK.title_bar("AÇIK ODALAR", right))
	var head := MarginContainer.new()
	head.add_theme_constant_override("margin_left", 16)
	head.add_theme_constant_override("margin_right", 16)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hc := DK.h(16)
	var titles: Array = ["ODA", "HOST", "OYUNCU", "TÜR", "ŞİFRE", "DURUM"]
	for i in titles.size():
		var l := DK.lbl(titles[i], DK.FS_LABEL, DK.C_DIM)
		_d_col_size(l, i)
		hc.add_child(l)
	head.add_child(hc)
	v.add_child(head)
	v.add_child(DK.hline())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list = DK.v(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_list)
	v.add_child(scroll)
	box.add_child(v)
	return box


## Sütunlar: oda adı esner; host, oyuncu, tür, şifre, durum sabit.
const D_COLS := [-1.0, 240.0, 120.0, 170.0, 150.0, 120.0]


func _d_col_size(c: Control, i: int) -> void:
	if float(D_COLS[i]) < 0.0:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.custom_minimum_size.x = 80
	else:
		c.custom_minimum_size.x = float(D_COLS[i])
	if c is Label:
		(c as Label).clip_text = true
		(c as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


## Glif + yazı hücresi (sabit genişlikte).
func _d_cell(i: int, pat: Array, t: String, col: Color) -> HBoxContainer:
	var hb := DK.h(8)
	hb.add_child(DK.glyph(pat, col, 3))
	var l := DK.lbl(t, DK.FS_LABEL, col)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	_d_col_size(hb, i)
	return hb


func _d_room_row(r: Dictionary) -> Button:
	var in_game: bool = bool(r["in_game"])
	var full: bool = int(r["players"]) >= int(r["max_players"]) and not in_game
	var open: bool = str(r["key"]) == _pw_key
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, D_ROW_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = full or _busy
	DK.style_button(b, "tile_on" if open else ("tile_locked" if b.disabled else "tile"), 4, 6.0)
	b.pressed.connect(_on_room_pressed.bind(r))
	var muted: bool = full or in_game
	var cols := DK.h(16)
	var nm := DK.lbl(str(r["room_name"]), DK.FS_BODY, DK.C_ACCENT if open else (DK.C_DIM if muted else DK.C_TEXT))
	_d_col_size(nm, 0)
	cols.add_child(nm)
	cols.add_child(_d_cell(1, DK.G_CROWN, str(r["host_name"]), DK.C_DIM))
	cols.add_child(_d_cell(2, DK.G_PERSON, "%d/%d" % [int(r["players"]), int(r["max_players"])], DK.C_BAD if full else DK.C_TEXT))
	cols.add_child(_d_cell(3, DK.G_GLOBE, "İnternet" if r["kind"] == "online" else "LAN", DK.C_DIM))
	var locked: bool = bool(r["locked"])
	cols.add_child(_d_cell(4, DK.G_LOCK if locked else DK.G_OPEN, "Şifreli" if locked else "Açık", DK.C_PRICE if locked else DK.C_DIM))
	var status: String = "Oyunda" if in_game else ("Dolu" if full else "Lobide")
	var st := DK.lbl(status, DK.FS_LABEL, DK.C_PRICE if in_game else (DK.C_BAD if full else DK.C_GOOD))
	_d_col_size(st, 5)
	cols.add_child(st)
	DK.btn_row(b, cols, false)
	b.tooltip_text = "%s - host: %s" % [r["room_name"], r["host_name"]]
	if in_game:
		b.tooltip_text += " (oyunda: sadece bu oyundan düşenler geri girebilir)"
	return b


func _d_password_row(r: Dictionary) -> PanelContainer:
	var box := DK.box(DK.C_INSET, DK.C_ACCENT_DK, 12)
	var v := DK.v(6)
	var row := DK.h(12)
	row.add_child(DK.glyph(DK.G_LOCK, DK.C_PRICE, 3))
	row.add_child(DK.lbl("Şifre:", DK.FS_LABEL, DK.C_TEXT))
	_pw_input = _d_input("", "Oda şifresi", PASSWORD_MAX_LEN)
	_pw_input.secret = true
	_pw_input.text_submitted.connect(func(_t: String) -> void: _submit_password(r))
	_pw_input.text_changed.connect(func(_t: String) -> void: _pw_error = "")
	row.add_child(_pw_input)
	var join := DK.btn("KATIL", "primary", DK.FS_BODY, D_INPUT_H, 150)
	join.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	join.pressed.connect(_submit_password.bind(r))
	row.add_child(join)
	var cancel := DK.btn("VAZGEÇ", "ghost", DK.FS_BODY, D_INPUT_H, 150)
	cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(func() -> void:
		_pw_key = ""
		_pw_error = ""
		_rebuild_list())
	row.add_child(cancel)
	v.add_child(row)
	if not _pw_error.is_empty():
		v.add_child(DK.lbl(_pw_error, DK.FS_LABEL, DK.C_BAD))
	box.add_child(v)
	_focus_password.call_deferred(_pw_input)
	return box


func _d_empty(msg: String, searching: bool) -> Control:
	var v := DK.v(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(DK.sp(0, 180))
	var g := DK.glyph(DK.G_GLOBE if searching else DK.G_PERSON, DK.C_LINE_HI, 6)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(g)
	v.add_child(DK.lbl(msg, DK.FS_BODY, DK.C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	if not searching:
		v.add_child(DK.lbl("Soldaki ODA KUR ile kendi odanı kur - kurunca doğrudan karakter seçimine geçersin.", DK.FS_LABEL, DK.C_DIM,
			HORIZONTAL_ALIGNMENT_CENTER))
	return v


func _d_ip_box() -> PanelContainer:
	var box := DK.box(DK.C_PANEL, DK.C_LINE, 14)
	var row := DK.h(12)
	row.add_child(DK.glyph(DK.G_GLOBE, DK.C_DIM, 3))
	row.add_child(DK.lbl("Listede yok mu? IP ile katıl:", DK.FS_LABEL, DK.C_DIM))
	_ip_input = _d_input("", "192.168.1.50:7777", 64)
	_ip_input.text_submitted.connect(func(_t: String) -> void: _on_ip_join_pressed())
	row.add_child(_ip_input)
	var b := DK.btn("KATIL", "ghost", DK.FS_BODY, D_INPUT_H, 160)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_on_ip_join_pressed)
	row.add_child(b)
	box.add_child(row)
	return box


## Seçim düğmesi (en fazla oyuncu / bağlantı): telefonda bej sage/tan, masaüstünde koyu kit karosu.
func _style_choice(b: Button, on: bool) -> void:
	if _mobile:
		MenuKit.style_button(b, "sage" if on else "tan")
	else:
		DK.style_button(b, "tile_on" if on else ("tile_locked" if b.disabled else "tile"), 4, 6.0)


# ---------------------------------------------------------------------------------------------------- telefon yerleşimi
func _build_mobile() -> void:
	var rect: Rect2 = LobbyUI.safe_rect(self, _mobile)
	var fs: int = int(_sz["fs_body"])
	var ctl_h: float = float(_sz["ctl_h"])
	var top_h: float = clampf(roundf(rect.size.y * 0.11), 96.0, 150.0) if _mobile else 96.0

	var back := MenuKit.make_button("< Geri", "tan", fs, top_h - 24.0 if _mobile else 56.0)
	back.pressed.connect(_on_back_pressed)
	add_child(back)
	MenuKit.place(back, rect.position + Vector2(16, 12 if _mobile else 24), Vector2(240.0 if _mobile else 200.0, top_h - 24.0 if _mobile else 56.0))
	var banner := MenuKit.make_banner("Çok Oyunculu", 48 if _mobile else MenuKit.FS_TITLE)
	add_child(banner)
	var bs: Vector2 = banner.get_combined_minimum_size()
	MenuKit.place(banner, Vector2(rect.position.x + roundf((rect.size.x - bs.x) * 0.5), rect.position.y + (6.0 if _mobile else 18.0)), bs)

	## Masaüstünde pencere ekranı kaplamaz (2026-10-11 "arayüzün kendisi çok büyük"): 1200 x en çok 800, ortada.
	var panel_w: float = rect.size.x - 32.0 if _mobile else minf(PANEL_MAX.x, rect.size.x - 32.0)
	var panel_h: float = rect.size.y - top_h - 28.0 if _mobile else minf(PANEL_MAX.y, rect.size.y - top_h - 28.0)
	var panel := MenuKit.make_panel("panel_tight")
	add_child(panel)
	var free_y: float = rect.size.y - top_h - 12.0 - panel_h
	MenuKit.place(panel, Vector2(rect.position.x + roundf((rect.size.x - panel_w) * 0.5), rect.position.y + top_h + 12.0 + (0.0 if _mobile else roundf(free_y * 0.35))),
		Vector2(panel_w, panel_h))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14 if _mobile else 10)
	panel.add_child(v)

	## Oyuncu adı + Yenile + ODA KUR
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var name_lbl := MenuKit.make_label("Adın:", _fs_label(), MenuKit.C_TEXT_DIM)
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name_lbl)
	_name_input = LineEdit.new()
	_name_input.text = NetworkManager.local_player_name
	_name_input.placeholder_text = "Adını gir"
	_name_input.max_length = 20
	_name_input.custom_minimum_size = Vector2(380.0 if _mobile else 320.0, _input_h())
	_name_input.add_theme_font_size_override("font_size", _fs_input())
	_name_input.text_submitted.connect(func(_t: String) -> void: _commit_name())
	_name_input.focus_exited.connect(_commit_name)
	top.add_child(_name_input)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_refresh_btn = MenuKit.make_button("Yenile", "tan", fs, ctl_h)
	_refresh_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_refresh_btn.pressed.connect(_on_refresh_pressed)
	top.add_child(_refresh_btn)
	_create_btn = MenuKit.make_button("ODA KUR", "sage", fs, ctl_h)
	_create_btn.custom_minimum_size.x = 260.0 if _mobile else 200.0
	_create_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_create_btn.pressed.connect(_open_dialog)
	top.add_child(_create_btn)

	var status_box := MenuKit.make_panel("inset")
	v.add_child(status_box)
	_status_label = MenuKit.make_label("Bir odaya katıl ya da kendi odanı kur.", _fs_label(), MenuKit.C_TEXT_DIM)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_box.add_child(_status_label)

	## Başlık satırı oda satırlarıyla hizalı: liste kutusunun iç payı + düğme içi pay kadar içeriden.
	var head_margin := MarginContainer.new()
	head_margin.add_theme_constant_override("margin_left", 26)
	head_margin.add_theme_constant_override("margin_right", 26)
	v.add_child(head_margin)
	head_margin.add_child(_make_columns(["Oda adı", "Host", "Oyuncu", "Tür", "Şifre", "Durum"], MenuKit.C_ACCENT, _fs_label()))
	var list_box := MenuKit.make_panel("inset")
	list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(list_box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	## Yedek: IP ile katıl (keşif güvenlik duvarına takılırsa).
	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 10)
	v.add_child(ip_row)
	var ip_lbl := MenuKit.make_label("Listede yok mu? IP ile katıl:", _fs_label(), MenuKit.C_TEXT_DIM)
	ip_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ip_row.add_child(ip_lbl)
	_ip_input = LineEdit.new()
	_ip_input.placeholder_text = "192.168.1.50:7777"
	_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_input.custom_minimum_size = Vector2(0, _input_h())
	_ip_input.add_theme_font_size_override("font_size", _fs_input())
	_ip_input.text_submitted.connect(func(_t: String) -> void: _on_ip_join_pressed())
	ip_row.add_child(_ip_input)
	var ip_btn := MenuKit.make_button("Katıl", "tan", fs, ctl_h)
	ip_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ip_btn.pressed.connect(_on_ip_join_pressed)
	ip_row.add_child(ip_btn)


## Sütun genişlikleri (telefonda 1,6x): oda adı (esner), host, oyuncu, tür, şifre, durum.
func _col_widths() -> Array:
	var m: float = 1.6 if _mobile else 1.0
	return [-1.0, 200.0 * m, 130.0 * m, 160.0 * m, 100.0 * m, 140.0 * m]


func _make_columns(texts: Array, color: Color, fs: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var widths: Array = _col_widths()
	for i in texts.size():
		var l := MenuKit.make_label(str(texts[i]), fs, color)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if float(widths[i]) < 0.0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.custom_minimum_size.x = float(widths[i])
		h.add_child(l)
	return h


func _fs_label() -> int:
	return int(_sz["fs_label"])


func _fs_input() -> int:
	return int(_sz["fs_input"])


func _input_h() -> float:
	return float(_sz["input_h"])


# ---------------------------------------------------------------------------------------------------- liste
func _rooms() -> Array:
	var out: Array = []
	for g in NetworkManager.get_discovered_lan_games():
		out.append({"key": "lan:%s:%d" % [g["ip"], g["port"]], "kind": "lan", "ip": g["ip"], "port": int(g["port"]),
			"room_name": str(g.get("room_name", g["name"])), "host_name": str(g["name"]), "players": int(g.get("players", 1)),
			"max_players": int(g.get("max_players", NetworkManager.MAX_PLAYERS)), "locked": bool(g.get("locked", false)),
			"in_game": bool(g.get("in_game", false))})
	for r in _online_rooms:
		out.append({"key": "eos:%s" % r["host_id"], "kind": "online", "host_id": str(r["host_id"]),
			"room_name": str(r.get("room_name", r["host_name"])), "host_name": str(r["host_name"]), "players": int(r["players"]),
			"max_players": int(r["max_players"]), "locked": bool(r.get("locked", false)), "in_game": bool(r["in_game"])})
	if not _ip_room.is_empty():
		out.append(_ip_room)
	out.sort_custom(func(a, b): return [a["in_game"], str(a["room_name"])] < [b["in_game"], str(b["room_name"])])
	return out


func _rebuild_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_pw_input = null
	var rooms: Array = _rooms()
	if _count_label:
		_count_label.text = ("%d oda" % rooms.size()) if not rooms.is_empty() else ""
	if rooms.is_empty():
		var searching: bool = NetworkManager.is_online_available() and not _online_searched
		if not _mobile:
			_list.add_child(_d_empty("Odalar aranıyor..." if searching else "Henüz açık oda yok.", searching))
			return
		var msg: String = "Odalar aranıyor..." if searching else "Henüz açık oda yok - \"ODA KUR\" ile sen kurabilirsin."
		var empty := MenuKit.make_label(msg, _fs_label(), MenuKit.C_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_child(empty)
		return
	for r in rooms:
		_list.add_child(_make_room_row(r) if _mobile else _d_room_row(r))
		if str(r["key"]) == _pw_key:
			_list.add_child(_make_password_row(r) if _mobile else _d_password_row(r))
	UISound.connect_all_buttons(_list)


func _make_room_row(r: Dictionary) -> Control:
	var full: bool = int(r["players"]) >= int(r["max_players"]) and not bool(r["in_game"])
	var btn := MenuKit.make_button("", "tan", int(_sz["fs_body"]), float(_sz["ctl_h"]))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.disabled = full or _busy
	btn.pressed.connect(_on_room_pressed.bind(r))
	var status: String = "Oyunda" if bool(r["in_game"]) else ("Dolu" if full else "Lobide")
	var color: Color = MenuKit.C_TEXT_DIM if (full or bool(r["in_game"])) else MenuKit.C_TEXT
	var cols := _make_columns([str(r["room_name"]), str(r["host_name"]),
		"%d / %d" % [int(r["players"]), int(r["max_players"])], "İnternet" if r["kind"] == "online" else "LAN",
		"Var" if bool(r["locked"]) else "-", status], color, _fs_label())
	btn.add_child(cols)
	cols.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cols.offset_left = 12
	cols.offset_right = -12
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	btn.tooltip_text = "%s - host: %s" % [r["room_name"], r["host_name"]]
	if bool(r["in_game"]):
		btn.tooltip_text += " (oyunda: sadece bu oyundan düşenler geri girebilir)"
	return btn


func _make_password_row(r: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var fs: int = int(_sz["fs_body"])
	var pw_lbl := MenuKit.make_label("Şifre:", _fs_label(), MenuKit.C_TEXT)
	pw_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pw_lbl)
	_pw_input = LineEdit.new()
	_pw_input.secret = true
	_pw_input.max_length = PASSWORD_MAX_LEN
	_pw_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pw_input.custom_minimum_size = Vector2(0, _input_h())
	_pw_input.add_theme_font_size_override("font_size", _fs_input())
	_pw_input.text_submitted.connect(func(_t: String) -> void: _submit_password(r))
	_pw_input.text_changed.connect(func(_t: String) -> void: _pw_error = "")
	row.add_child(_pw_input)
	var join := MenuKit.make_button("Katıl", "sage", fs, float(_sz["ctl_h"]))
	join.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	join.pressed.connect(_submit_password.bind(r))
	row.add_child(join)
	var cancel := MenuKit.make_button("Vazgeç", "tan", fs, float(_sz["ctl_h"]))
	cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(func() -> void:
		_pw_key = ""
		_pw_error = ""
		_rebuild_list())
	row.add_child(cancel)
	if not _pw_error.is_empty():
		box.add_child(MenuKit.make_label(_pw_error, _fs_label(), MenuKit.C_BAD))
	_focus_password.call_deferred(_pw_input)
	return box


func _focus_password(input: LineEdit) -> void:
	if is_instance_valid(input) and input.is_inside_tree():
		input.grab_focus()


func _on_room_pressed(r: Dictionary) -> void:
	if _busy:
		return
	if bool(r["locked"]):
		_pw_key = str(r["key"])
		_pw_error = ""
		_rebuild_list()
		return
	_join(r, "")


func _submit_password(r: Dictionary) -> void:
	var pw: String = _pw_input.text if _pw_input != null else ""
	if pw.is_empty():
		_pw_error = "Şifreyi gir."
		_rebuild_list()
		return
	_join(r, pw)


func _join(r: Dictionary, password: String) -> void:
	_commit_name()
	_pending = r
	_set_busy(true)
	NetworkManager.join_password = password
	_status_label.text = "\"%s\" odasına bağlanılıyor..." % r["room_name"]
	if r["kind"] == "online":
		NetworkManager.join_online(str(r["host_id"]), str(r["host_name"]), _player_name(), NetworkManager.local_char_id)
	else:
		NetworkManager.join_lan(str(r["ip"]), int(r["port"]), _player_name(), NetworkManager.local_char_id)


func _on_ip_join_pressed() -> void:
	if _busy:
		return
	var parts: PackedStringArray = _ip_input.text.strip_edges().split(":")
	var ip: String = parts[0].strip_edges() if parts.size() > 0 else ""
	if ip.is_empty():
		_status_label.text = "IP adresini yaz (ör. 192.168.1.50:7777)."
		return
	var port: int = int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else LAN_PORT
	## Şifreli odaysa host "şifreli" diye reddeder ve şifre sorusu bu girdi için açılır.
	_join({"key": "ip:%s:%d" % [ip, port], "kind": "lan", "ip": ip, "port": port, "room_name": "%s:%d" % [ip, port],
		"host_name": ip, "players": 0, "max_players": NetworkManager.MAX_PLAYERS, "locked": false, "in_game": false}, "")


func _on_join_rejected(code: int, message: String) -> void:
	_status_label.text = message
	if (code == NetworkManager.REJECT_PASSWORD_NEEDED or code == NetworkManager.REJECT_PASSWORD_WRONG) and not _pending.is_empty():
		if str(_pending["key"]).begins_with("ip:"):
			_ip_room = _pending.duplicate()
			_ip_room["locked"] = true
		_pw_key = str(_pending["key"])
		_pw_error = message if code == NetworkManager.REJECT_PASSWORD_WRONG else ""
	_rebuild_list()


func _on_join_failed() -> void:
	_set_busy(false)


func _on_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _set_busy(value: bool) -> void:
	_busy = value
	_busy_since_msec = Time.get_ticks_msec()
	if _create_btn:
		_create_btn.disabled = value
		if not _mobile:
			DK.style_button(_create_btn, "off" if value else "primary")
	if _refresh_btn:
		_refresh_btn.disabled = value
		if not _mobile:
			DK.style_button(_refresh_btn, "off" if value else "ghost")
	_rebuild_list()


func _on_refresh_pressed() -> void:
	_rebuild_list()
	_refresh_online()


func _refresh_online() -> void:
	if NetworkManager.is_multiplayer_active or not NetworkManager.is_online_available():
		return
	var rooms: Array = await EosOnline.search_lobbies_async(_player_name())
	if not is_inside_tree() or NetworkManager.is_multiplayer_active:
		return
	_online_searched = true
	_online_rooms = rooms
	if not _busy and (_pw_input == null or not _pw_input.has_focus()):
		_rebuild_list()


func _player_name() -> String:
	var n: String = _name_input.text.strip_edges() if _name_input else ""
	return "Oyuncu" if n.is_empty() else n


func _commit_name() -> void:
	if _name_input == null:
		return
	var n: String = _name_input.text.strip_edges()
	if not n.is_empty() and n != NetworkManager.local_player_name:
		## Masaüstünde form hep açık: oda adı hâlâ "<eski ad> odası" ise yeni adla güncellenir (elle yazılmışsa dokunulmaz).
		var was_default: bool = not _mobile and _room_name_input != null and _room_name_input.text == "%s odası" % NetworkManager.local_player_name
		NetworkManager.update_local_player_name(n)
		if was_default:
			_room_name_input.text = "%s odası" % NetworkManager.local_player_name


func _on_room_entered() -> void:
	_go_to_room.call_deferred()


func _go_to_room() -> void:
	if not is_inside_tree():
		return
	var scene: String = "res://scenes/lobby_menu.tscn" if NetworkManager.lobby_phase == NetworkManager.PHASE_SELECT else "res://scenes/room_lobby.tscn"
	get_tree().change_scene_to_file(scene)


func _on_back_pressed() -> void:
	if NetworkManager.is_multiplayer_active or NetworkManager.is_online_session:
		NetworkManager.disconnect_from_room(false)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ---------------------------------------------------------------------------------------------------- "Oda kur" penceresi (telefon; masaüstünde form solda hep açık)
func _build_dialog() -> void:
	_dialog = Control.new()
	_dialog.visible = false
	add_child(_dialog)
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.02, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var fs: int = int(_sz["fs_body"])
	var ctl_h: float = float(_sz["ctl_h"])
	var w: float = 1100.0 if _mobile else DIALOG_W
	var panel := MenuKit.make_panel("panel")
	_dialog.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(MenuKit.make_section_header("Oda kur", MenuKit.FS_TITLE if not _mobile else 48))

	v.add_child(MenuKit.make_label("Oda adı", _fs_label(), MenuKit.C_TEXT_DIM))
	_room_name_input = LineEdit.new()
	_room_name_input.max_length = 32
	_room_name_input.custom_minimum_size = Vector2(0, _input_h())
	_room_name_input.add_theme_font_size_override("font_size", _fs_input())
	v.add_child(_room_name_input)

	v.add_child(MenuKit.make_label("Şifre (boşsa herkes girebilir)", _fs_label(), MenuKit.C_TEXT_DIM))
	_room_pw_input = LineEdit.new()
	_room_pw_input.secret = true
	_room_pw_input.max_length = PASSWORD_MAX_LEN
	_room_pw_input.custom_minimum_size = Vector2(0, _input_h())
	_room_pw_input.add_theme_font_size_override("font_size", _fs_input())
	v.add_child(_room_pw_input)

	v.add_child(MenuKit.make_label("En fazla oyuncu", _fs_label(), MenuKit.C_TEXT_DIM))
	var max_row := HBoxContainer.new()
	max_row.add_theme_constant_override("separation", 6)
	v.add_child(max_row)
	for n in PLAYER_CHOICES:
		var b := MenuKit.make_button(str(n), "tan", fs, ctl_h)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_max_players.bind(int(n)))
		max_row.add_child(b)
		_max_buttons[int(n)] = b

	v.add_child(MenuKit.make_label("Bağlantı", _fs_label(), MenuKit.C_TEXT_DIM))
	var conn_row := HBoxContainer.new()
	conn_row.add_theme_constant_override("separation", 6)
	v.add_child(conn_row)
	_online_choice_btn = MenuKit.make_button("İnternet", "tan", fs, ctl_h)
	_online_choice_btn.tooltip_text = "PC + Android, port açmaya gerek yok"
	_online_choice_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_online_choice_btn.pressed.connect(_set_connection.bind(true))
	conn_row.add_child(_online_choice_btn)
	_lan_choice_btn = MenuKit.make_button("Aynı ağ (LAN)", "tan", fs, ctl_h)
	_lan_choice_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lan_choice_btn.pressed.connect(_set_connection.bind(false))
	conn_row.add_child(_lan_choice_btn)
	if not NetworkManager.is_online_available():
		_online_choice_btn.disabled = true
		_online_choice_btn.tooltip_text = "Epic ayarları eksik (eos_credentials.cfg) - şimdilik sadece LAN."

	_dialog_error = MenuKit.make_label("", _fs_label(), MenuKit.C_BAD)
	_dialog_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_error.custom_minimum_size.x = w - 64.0
	v.add_child(_dialog_error)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	v.add_child(btn_row)
	var cancel := MenuKit.make_button("Vazgeç", "rose", fs, ctl_h)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void: _dialog.visible = false)
	btn_row.add_child(cancel)
	var create := MenuKit.make_button("Kur", "sage", fs, ctl_h)
	create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create.pressed.connect(_on_create_pressed)
	btn_row.add_child(create)

	var view: Vector2 = get_viewport().get_visible_rect().size
	var ps: Vector2 = Vector2(w, panel.get_combined_minimum_size().y)
	MenuKit.place(panel, ((view - ps) * 0.5).floor(), ps)
	_set_max_players(DEFAULT_MAX_PLAYERS)
	_set_connection(NetworkManager.is_online_available())


func _set_max_players(n: int) -> void:
	_max_players = n
	for k in _max_buttons:
		_style_choice(_max_buttons[k], int(k) == n)


func _set_connection(online: bool) -> void:
	_use_online = online and NetworkManager.is_online_available()
	_style_choice(_online_choice_btn, _use_online)
	_style_choice(_lan_choice_btn, not _use_online)
	if _conn_hint:
		if not NetworkManager.is_online_available():
			_conn_hint.text = "Epic ayarları eksik - şimdilik sadece aynı ağdakiler katılabilir."
		elif _use_online:
			_conn_hint.text = "PC + Android, port açmaya gerek yok."
		else:
			_conn_hint.text = "Aynı Wi-Fi / kablolu ağdakiler oda listesinde görür."


func _open_dialog() -> void:
	if _busy:
		return
	_commit_name()
	_room_name_input.text = "%s odası" % _player_name()
	_room_pw_input.text = ""
	_dialog_error.text = ""
	_dialog.visible = true
	UiAnim.window_in(_dialog)
	if not _mobile:
		_room_name_input.grab_focus.call_deferred()


func _on_create_pressed() -> void:
	var rname: String = _room_name_input.text.strip_edges()
	if rname.is_empty():
		_dialog_error.text = "Oda adı gir."
		return
	_commit_name()
	_dialog_error.text = ""
	NetworkManager.configure_room(rname, _room_pw_input.text, _max_players)
	if _dialog:
		_dialog.visible = false
	_set_busy(true)
	if _use_online:
		_status_label.text = "İnternet odası kuruluyor..."
		NetworkManager.host_online(_player_name(), NetworkManager.local_char_id)
	else:
		if not NetworkManager.host_lan(LAN_PORT, _player_name(), NetworkManager.local_char_id):
			_set_busy(false)
