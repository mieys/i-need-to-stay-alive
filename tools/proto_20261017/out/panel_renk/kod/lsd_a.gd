extends Control

## ÇOK OYUNCULU KARAKTER SEÇİMİ - masaüstü, "SEÇİM D" (2026-10-16, kullanıcının seçtiği prototip: tools/proto_20261016/menu_proto.gd
## _design_sec_d). Oda kurulunca DOĞRUDAN bu ekran açılır, oyuncular seçim sürerken bağlanır (oda lobisi aşaması kalktı, bkz.
## network_manager.gd "ODA AYARLARI" notu). Koyu kit: menu_dark_kit.gd. lobby_menu.gd sahneyi kurar, durum/ağ olaylarını buraya iletir.
##   sol  : oda kutusu (ad, Şifreli/Açık, İnternet/LAN, n/en çok, ODADAN ÇIK) + oyuncu kartları (renk şeridi, yüz, HOST/SEN,
##          karakter adı, silah/ruhani(+kendi evcilin) ikonları, HAZIR/SEÇİYOR, host'ta X = at) + host'ta "bağlanıyor" kartları + sohbet
##   orta : 5 sütun karakter ızgarası (kilitliler sönük + fiyat, kimin seçtiği köşede baş harfle) + seçilenin statları + Q/E/R/Pasif
##   sağ  : vitrin (canlı bekleme animasyonu) + yüklemen + SİLAH / EVCİL / RUHANİ sekmeleri (seçenekler DOĞRUDAN ızgarada) + açıklama
##   alt sağ: host OYUNU BAŞLAT (herkes hazır olunca) / istemci HAZIRIM; altında "x/y hazır · n bağlanıyor".
## TEK OYUNCULU kip (`solo`, 2026-10-16 - kullanıcı: "tek oyunculu modun tasarımını çok oyunculu moda uygun hale getir"; character_select.gd
## kurar): ağ yok; sol = mod kutusu (ANA MENÜ, Ruh Kıymığı) + kendi kartın + EN İYİ KOŞULARIN (sohbetin yerinde), orta/sağ AYNI,
## alt sağ OYUNU BAŞLAT (kilitli karakterde kapalı). leave_pressed = ana menüye dön.

signal character_picked(char_id: int)
signal start_pressed
signal ready_pressed
signal leave_pressed

const DK := preload("res://tools/proto_20261017/out/panel_renk/kod/kit_a.gd")
const WC := preload("res://scripts/weapon_catalog.gd")
const PC := preload("res://scripts/pet_catalog.gd")
const SS := preload("res://scripts/spiritual_skills.gd")
const MP := preload("res://scripts/meta_progress.gd")
const LU := preload("res://scripts/menu_lobby_ui.gd")
const SI := preload("res://scripts/stat_icon.gd")
const PreviewScript := preload("res://scripts/menu_character_preview.gd")
const RR := preload("res://scripts/run_records.gd")
const RunSummaryUI := preload("res://scripts/run_summary_ui.gd")

const LEFT := Rect2(32, 24, 440, 1024)
const MID := Rect2(488, 24, 760, 1024)
const RIGHT := Rect2(1264, 24, 624, 908)
const START_Y := 948.0
const CARD := Vector2(134, 150)
const TILE := Vector2(108, 124)
const SHORT := {4: "Büyücü", 5: "Assasin", 7: "Şovalye", 13: "Vampir", 14: "Hadime"}
const CHAT_KEEP := 50

## Tek oyunculu kip (build'den ÖNCE atanır).
var solo: bool = false
var _sel_char: int = 1
var _viewing_locked: bool = false
var _tab: String = "weapon"
var _detail_key: String = "" ## sekmede incelenen (kilitliyse seçilmeden açıklaması gösterilir)
var _cards: Dictionary = {} ## char_id -> {"btn": Button, "marks": HBoxContainer, "name": Label}
var _room_name: Label = null
var _chips: HBoxContainer = null
var _leave_btn: Button = null
var _status: Label = null
var _players: VBoxContainer = null
var _chat_log: VBoxContainer = null
var _chat_scroll: ScrollContainer = null
var _chat_input: LineEdit = null
var _open_count: Label = null
var _char_name: Label = null
var _stats: GridContainer = null
var _skills: VBoxContainer = null
var _preview: Control = null
var _load_name: Label = null
var _load_icons: HBoxContainer = null
var _tab_btns: Dictionary = {}
var _tab_grid: GridContainer = null
var _detail_name: Label = null
var _detail_cat: Label = null
var _detail_desc: Label = null
var _start_btn: Button = null
var _start_info: Label = null
var _lock: ColorRect = null
var _pending_shown: int = -1
var _pending_bars: Array = []
var _time: float = 0.0


func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = DK.theme()
	_validate_loadout()
	if solo:
		_build_left_solo()
	else:
		_build_left()
	_build_mid()
	_build_right()
	_build_start()
	set_process(not solo)
	if solo:
		return
	_build_lock()
	NetworkManager.chat_message_received.connect(_on_chat_message)


func _exit_tree() -> void:
	if NetworkManager.chat_message_received.is_connected(_on_chat_message):
		NetworkManager.chat_message_received.disconnect(_on_chat_message)


func _process(delta: float) -> void:
	_time += delta
	var pending: int = NetworkManager.pending_join_count()
	if pending != _pending_shown and _players != null:
		_refresh_players()
		_refresh_start()
	for b in _pending_bars:
		if is_instance_valid(b):
			b.set("frac", fmod(_time, 1.6) / 1.6)
			(b as Control).queue_redraw()


func _put(c: Control, r: Rect2) -> Control:
	add_child(c)
	MenuKit.place(c, r.position, r.size)
	return c


## Kilitli / geçersiz seçimleri varsayılana çek (eski seçicilerin setup'taki select(..., false) davranışı).
func _validate_loadout() -> void:
	var changed := false
	var w: String = WC.selected()
	if not WC.is_valid(w) or not MP.is_unlocked(MP.WEAPON, w):
		w = WC.DEFAULT_KEY
	if w != GameManager.selected_start_weapon:
		GameManager.selected_start_weapon = w
		changed = true
	var p: String = PC.selected()
	if not PC.is_valid(p) or not MP.is_unlocked(MP.PET, p):
		p = PC.DEFAULT_KEY
	GameManager.selected_pet = p
	var s: String = GameManager.selected_spiritual
	if not SS.is_valid(s) or not MP.is_unlocked(MP.SPIRIT, s):
		s = SS.DEFAULT_ID
	if s != GameManager.selected_spiritual:
		GameManager.selected_spiritual = s
		changed = true
	if changed:
		NetworkManager.update_local_loadout()


## ------------------------------------------------------------------ sol: oda + oyuncular + sohbet
func _build_left() -> void:
	var room := DK.box(DK.C_PANEL, DK.C_LINE, 14)
	var rv := DK.v(8)
	var head := DK.h(10)
	_room_name = DK.lbl(NetworkManager.room_name, DK.FS_TITLE, DK.C_ACCENT)
	_room_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_name.clip_text = true
	_room_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_room_name)
	_leave_btn = DK.btn("ODAYI KAPAT" if NetworkManager.is_host else "ODADAN ÇIK", "danger", DK.FS_LABEL, 44, 0)
	_leave_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_leave_btn.pressed.connect(func() -> void: leave_pressed.emit())
	head.add_child(_leave_btn)
	rv.add_child(head)
	_chips = DK.h(8)
	rv.add_child(_chips)
	_status = DK.wrap("Karakterini, silahını, evcilini ve ruhani yeteneğini seç.", DK.FS_LABEL, DK.C_DIM, LEFT.size.x - 28, 2)
	rv.add_child(_status)
	room.add_child(rv)
	_put(room, Rect2(LEFT.position, Vector2(LEFT.size.x, 0)))

	var list := ScrollContainer.new()
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_players = DK.v(10)
	_players.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(_players)
	_put(list, Rect2(LEFT.position.x, 184, LEFT.size.x, 520))

	var chat := DK.box(DK.C_PANEL, DK.C_LINE, 14)
	var cv := DK.v(8)
	cv.add_child(DK.lbl("SOHBET", DK.FS_LABEL, DK.C_ACCENT))
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log = DK.v(4)
	_chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_scroll.add_child(_chat_log)
	cv.add_child(_chat_scroll)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Mesaj yaz... (Enter)"
	_chat_input.max_length = 200
	_chat_input.text_submitted.connect(func(_t: String) -> void: _send_chat())
	cv.add_child(_chat_input)
	chat.add_child(cv)
	_put(chat, Rect2(LEFT.position.x, 716, LEFT.size.x, 332))
	for e in NetworkManager.lobby_chat_log:
		_add_chat_line(str(e["name"]), str(e["text"]))
	_scroll_chat_end.call_deferred()


## Tek oyunculu sol sütun: oda kutusunun yerinde mod kutusu, oyuncu listesinde sadece kendi kartın, sohbetin yerinde en iyi koşular.
func _build_left_solo() -> void:
	var room := DK.box(DK.C_PANEL, DK.C_LINE, 14)
	var rv := DK.v(8)
	var head := DK.h(10)
	_room_name = DK.lbl("TEK OYUNCULU", DK.FS_TITLE, DK.C_ACCENT)
	_room_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_room_name)
	_leave_btn = DK.btn("ANA MENÜ", "ghost", DK.FS_LABEL, 44, 0)
	_leave_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_leave_btn.tooltip_text = "Ana menüye dön (Esc)"
	_leave_btn.pressed.connect(func() -> void: leave_pressed.emit())
	head.add_child(_leave_btn)
	rv.add_child(head)
	_chips = DK.h(8)
	_chips.add_child(DK.chip(DK.G_PERSON, "Tek oyuncu", DK.C_DIM))
	var shard := DK.box(DK.C_INSET, DK.C_LINE, 6, 2, 4)
	var sst: StyleBoxFlat = shard.get_theme_stylebox("panel")
	sst.content_margin_left = 12
	sst.content_margin_right = 14
	var sh := DK.h(8)
	sh.add_child(DK.ShardIcon.new(20))
	sh.add_child(DK.lbl(str(MP.shards()), DK.FS_LABEL, DK.C_PRICE))
	shard.add_child(sh)
	shard.tooltip_text = "Ruh Kıymığı - kilitli karakter/silah/evcil/ruhani Ruh Mağazası'nda açılır"
	shard.mouse_filter = Control.MOUSE_FILTER_PASS
	_chips.add_child(shard)
	rv.add_child(_chips)
	_status = DK.wrap("Karakterini, silahını, evcilini ve ruhani yeteneğini seç.", DK.FS_LABEL, DK.C_DIM, LEFT.size.x - 28, 2)
	rv.add_child(_status)
	room.add_child(rv)
	_put(room, Rect2(LEFT.position, Vector2(LEFT.size.x, 0)))

	_players = DK.v(10)
	_put(_players, Rect2(LEFT.position.x, 184, LEFT.size.x, 0))
	_refresh_players()
	_put(_records_box(), Rect2(LEFT.position.x, 716, LEFT.size.x, 332))


## Tek oyunculu kartın verisi (çok oyunculuda lobby_players'tan gelir).
func _local_info() -> Dictionary:
	return {"name": NetworkManager.local_player_name, "char_id": _sel_char, "weapon": GameManager.selected_start_weapon,
		"spirit": GameManager.selected_spiritual, "is_host": false, "is_ready": false}


## En iyi koşular (run_records.gd; tam liste ana menüdeki REKORLAR ekranında).
func _records_box() -> PanelContainer:
	var data: Dictionary = RR.load_all()
	var runs: int = int(data.get("runs", 0))
	var box := DK.box(DK.C_PANEL, DK.C_LINE, 14)
	var v := DK.v(10)
	v.add_child(DK.title_bar("EN İYİ KOŞULARIN", DK.lbl("%d koşu" % runs if runs > 0 else "", DK.FS_LABEL, DK.C_DIM)))
	if runs <= 0:
		v.add_child(DK.wrap("Henüz koşu yok. İlk koşunu başlat - en yüksek kademen, en uzun süren ve en çok öldürmen burada görünür.",
			DK.FS_LABEL, DK.C_DIM, LEFT.size.x - 28))
		box.add_child(v)
		return box
	var tiles := DK.h(10)
	for t: Array in [["EN YÜKSEK KADEME", "Kademe %d" % int(data.get("best_tier", 0))],
			["EN UZUN SÜRE", _time_or_dash(float(data.get("best_time", 0.0)))]]:
		var tile := DK.box(DK.C_INSET, DK.C_LINE, 10, 2, 4)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tv := DK.v(0)
		tv.add_child(DK.lbl(t[0], DK.FS_SMALL, DK.C_DIM))
		tv.add_child(DK.lbl(t[1], DK.FS_TITLE, DK.C_ACCENT))
		tile.add_child(tv)
		tiles.add_child(tile)
	v.add_child(tiles)
	for row: Array in [["Tek koşuda en çok öldürme", _num_or_dash(int(data.get("best_kills", 0)))],
			["Zafer", str(int(data.get("victories", 0)))],
			["En hızlı zafer", _time_or_dash(float(data.get("best_victory_time", 0.0)))],
			["Toplam öldürme", str(int(data.get("total_kills", 0)))]]:
		var hb := DK.h(8)
		var l := DK.lbl(row[0], DK.FS_LABEL, DK.C_DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		hb.add_child(DK.lbl(row[1], DK.FS_LABEL))
		v.add_child(hb)
	box.add_child(v)
	return box


static func _time_or_dash(seconds: float) -> String:
	return RunSummaryUI.format_time(seconds) if seconds > 0.0 else "-"


static func _num_or_dash(n: int) -> String:
	return str(n) if n > 0 else "-"


func _player_ids() -> Array:
	var ids: Array = NetworkManager.lobby_players.keys()
	ids.sort()
	return ids


func _my_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0


func _refresh_room() -> void:
	_room_name.text = NetworkManager.room_name
	for c in _chips.get_children():
		_chips.remove_child(c)
		c.queue_free()
	var locked: bool = not NetworkManager.room_password.is_empty()
	_chips.add_child(DK.chip(DK.G_LOCK if locked else DK.G_OPEN, "Şifreli" if locked else "Açık", DK.C_DIM))
	if NetworkManager.is_online_session:
		_chips.add_child(DK.chip(DK.G_GLOBE, "İnternet", DK.C_DIM))
	else:
		_chips.add_child(DK.chip(DK.G_GLOBE, ("LAN %s" % NetworkManager.room_code) if NetworkManager.room_code != "" else "LAN", DK.C_DIM))
	_chips.add_child(DK.chip(DK.G_PERSON, "%d/%d" % [NetworkManager.lobby_players.size(), NetworkManager.room_max_players], DK.C_TEXT))


func _refresh_players() -> void:
	for c in _players.get_children():
		_players.remove_child(c)
		c.queue_free()
	_pending_bars.clear()
	if solo:
		_players.add_child(_player_card(0, 0))
		return
	var ids: Array = _player_ids()
	for i in ids.size():
		_players.add_child(_player_card(int(ids[i]), i))
	var pending: int = NetworkManager.pending_join_count()
	_pending_shown = pending
	for k in pending:
		_players.add_child(_pending_card())
	UISound.connect_all_buttons(_players)


func _player_card(pid: int, index: int) -> PanelContainer:
	var info: Dictionary = _local_info() if solo else NetworkManager.lobby_players.get(pid, {})
	var me: bool = solo or pid == _my_id()
	var col: Color = DK.player_color(index)
	var card := DK.box(DK.C_PANEL3 if me else DK.C_PANEL, DK.C_ACCENT if me else DK.C_LINE, 10)
	var hb := DK.h(12)
	var stripe := ColorRect.new()
	stripe.color = col
	stripe.custom_minimum_size = Vector2(6, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(stripe)
	var cid: int = int(info.get("char_id", 1))
	var fb := DK.box(DK.C_INSET, DK.C_LINE, 2, 2, 3)
	fb.add_child(DK.icon(LU.face_texture(str(Characters.get_def(cid).get("portrait", ""))), 72))
	hb.add_child(fb)
	var v := DK.v(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var top := DK.h(8)
	var nm := DK.lbl(str(info.get("name", "Oyuncu")), DK.FS_BODY)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.custom_minimum_size.x = 40
	top.add_child(nm)
	if bool(info.get("is_host", false)):
		var cr := DK.glyph(DK.G_CROWN, DK.C_ACCENT, 3)
		cr.tooltip_text = "Host"
		cr.mouse_filter = Control.MOUSE_FILTER_PASS
		top.add_child(cr)
	if me:
		top.add_child(_me_tag())
	if not solo:
		top.add_child(_state_badge(bool(info.get("is_ready", false))))
	v.add_child(top)
	var bot := DK.h(6)
	var cn := DK.lbl(str(Characters.get_def(cid).get("name", "")), DK.FS_LABEL, col)
	cn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cn.clip_text = true
	cn.custom_minimum_size.x = 40
	bot.add_child(cn)
	var wkey: String = str(info.get("weapon", ""))
	if WC.is_valid(wkey):
		bot.add_child(DK.slot(WC.icon(wkey), 48, "Silah: " + WC.display_name(wkey)))
	if me:
		bot.add_child(DK.slot(PC.icon(PC.selected()), 48, "Evcil: " + PC.display_name(PC.selected())))
	var sid: String = str(info.get("spirit", ""))
	if SS.is_valid(sid):
		bot.add_child(DK.slot(load(str(SS.get_def(sid).get("icon", ""))) as Texture2D, 48, "Ruhani: " + SS.skill_name(sid)))
	if NetworkManager.is_host and not me:
		var kick := DK.btn("", "danger", DK.FS_LABEL, 40, 40)
		kick.tooltip_text = "Odadan at (bu oda kapanana kadar geri giremez)"
		var cc := CenterContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(DK.glyph(DK.G_X, DK.C_BAD, 3))
		kick.add_child(cc)
		kick.pressed.connect(NetworkManager.kick_player.bind(pid))
		bot.add_child(kick)
	v.add_child(bot)
	hb.add_child(v)
	card.add_child(hb)
	return card


func _pending_card() -> PanelContainer:
	var card := DK.box(DK.C_INSET, DK.C_LINE, 10)
	var hb := DK.h(12)
	var stripe := ColorRect.new()
	stripe.color = DK.C_LINE_HI
	stripe.custom_minimum_size = Vector2(6, 0)
	hb.add_child(stripe)
	var fb := DK.box(DK.C_PANEL2, DK.C_LINE, 2, 2, 3)
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(72, 72)
	cc.add_child(DK.glyph(DK.G_QMARK, DK.C_LINE_HI, 5))
	fb.add_child(cc)
	hb.add_child(fb)
	var v := DK.v(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var top := DK.h(8)
	top.add_child(DK.lbl("Oyuncu bağlanıyor", DK.FS_BODY, DK.C_DIM))
	top.add_child(DK.sp(0, 0, true))
	top.add_child(DK.glyph(DK.G_DOTS, DK.C_DIM, 3))
	v.add_child(top)
	var bar := DK.Bar.new(0.0, DK.C_LINE_HI, DK.C_PANEL2, 6)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pending_bars.append(bar)
	v.add_child(bar)
	hb.add_child(v)
	card.add_child(hb)
	return card


func _me_tag() -> PanelContainer:
	var p := DK.box(DK.C_ACCENT, Color(0, 0, 0, 0), 2, 0, 3)
	var st: StyleBoxFlat = p.get_theme_stylebox("panel")
	st.content_margin_left = 8
	st.content_margin_right = 8
	var l := DK.lbl("SEN", DK.FS_LABEL, DK.C_ACCENT_TEXT)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	p.add_child(l)
	return p


func _state_badge(is_ready: bool) -> HBoxContainer:
	var hb := DK.h(6)
	if is_ready:
		hb.add_child(DK.glyph(DK.G_CHECK, DK.C_GOOD, 3))
		hb.add_child(DK.lbl("HAZIR", DK.FS_LABEL, DK.C_GOOD))
	else:
		hb.add_child(DK.lbl("SEÇİYOR", DK.FS_LABEL, DK.C_PRICE))
	return hb


## ------------------------------------------------------------------ sohbet (menu_lobby_chat.gd ile aynı RPC ve geçmiş)
func _send_chat() -> void:
	var text: String = _chat_input.text.strip_edges()
	_chat_input.text = ""
	if text.is_empty() or not NetworkManager.is_multiplayer_active or not multiplayer.has_multiplayer_peer():
		return
	NetworkManager.broadcast_chat_message.rpc(multiplayer.get_unique_id(), NetworkManager.local_player_name, text)
	_chat_input.grab_focus.call_deferred()


func _on_chat_message(_peer_id: int, player_name: String, text: String) -> void:
	_add_chat_line(player_name, text)
	_scroll_chat_end()


func _name_color(player_name: String) -> Color:
	var ids: Array = _player_ids()
	for i in ids.size():
		if str(NetworkManager.lobby_players[ids[i]].get("name", "")) == player_name:
			return DK.player_color(i)
	return DK.C_ACCENT


func _add_chat_line(player_name: String, text: String) -> void:
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_override("normal_font", DK.font())
	line.add_theme_font_size_override("normal_font_size", DK.FS_LABEL)
	line.add_theme_color_override("default_color", DK.C_TEXT)
	line.text = "[color=#%s]%s:[/color] %s" % [_name_color(player_name).to_html(false), player_name.xml_escape(), text.xml_escape()]
	_chat_log.add_child(line)
	while _chat_log.get_child_count() > CHAT_KEEP:
		var old: Node = _chat_log.get_child(0)
		_chat_log.remove_child(old)
		old.queue_free()


func _scroll_chat_end() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(_chat_scroll):
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)


## ------------------------------------------------------------------ orta: karakter ızgarası + ayrıntı
func _build_mid() -> void:
	var mid := DK.box(DK.C_PANEL, DK.C_LINE, 16)
	var mv := DK.v(12)
	_open_count = DK.lbl("", DK.FS_LABEL, DK.C_DIM)
	mv.add_child(DK.title_bar("KARAKTERİNİ SEÇ", _open_count))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var ids: Array = Characters.DEFS.keys()
	ids.sort()
	var open_n: int = 0
	for id in ids:
		grid.add_child(_char_card(int(id)))
		if MP.is_unlocked(MP.CHAR, int(id)):
			open_n += 1
	_open_count.text = "%d/%d açık" % [open_n, ids.size()]
	mv.add_child(grid)
	mv.add_child(DK.hline())
	var nh := DK.h(12)
	_char_name = DK.lbl("", DK.FS_TITLE, DK.C_ACCENT)
	nh.add_child(_char_name)
	nh.add_child(DK.sp(0, 0, true))
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 22)
	_stats.add_theme_constant_override("v_separation", 6)
	nh.add_child(_stats)
	mv.add_child(nh)
	_skills = DK.v(10)
	mv.add_child(_skills)
	mid.add_child(mv)
	_put(mid, MID)


func _char_card(id: int) -> Button:
	var def: Dictionary = Characters.get_def(id)
	var lk: bool = not MP.is_unlocked(MP.CHAR, id)
	var b := Button.new()
	b.custom_minimum_size = CARD
	b.tooltip_text = str(def.get("name", "")) + ("\n" + MP.lock_text(MP.CHAR, id) if lk else "")
	b.pressed.connect(func() -> void: character_picked.emit(id))
	var v := DK.v(2)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(DK.icon(LU.face_texture(str(def.get("portrait", ""))), 96, lk))
	var nl: Label = null
	if lk:
		var ph := DK.h(6)
		ph.alignment = BoxContainer.ALIGNMENT_CENTER
		ph.add_child(DK.ShardIcon.new(18, true))
		ph.add_child(DK.lbl(str(MP.cost(MP.CHAR, id)), DK.FS_LABEL, DK.C_BAD))
		v.add_child(ph)
	else:
		var t: String = str(SHORT.get(id, def.get("name", "")))
		var fs: int = DK.FS_LABEL if DK.font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, DK.FS_LABEL).x <= CARD.x - 12 else DK.FS_SMALL
		nl = DK.lbl(t, fs, DK.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(nl)
	b.add_child(v)
	if lk:
		var lg := DK.glyph(DK.G_LOCK, DK.C_DIM, 3)
		lg.position = Vector2(CARD.x - 30, 8)
		b.add_child(lg)
	var marks := DK.h(4)
	marks.position = Vector2(6, 6)
	b.add_child(marks)
	_cards[id] = {"btn": b, "marks": marks, "name": nl, "locked": lk}
	_style_card(id)
	return b


func _style_card(id: int) -> void:
	var c: Dictionary = _cards[id]
	var sel: bool = id == _sel_char
	DK.style_button(c["btn"], "tile_on" if sel else ("tile_locked" if c["locked"] else "tile"), 4, 6.0)
	if c["name"] != null:
		(c["name"] as Label).add_theme_color_override("font_color", DK.C_ACCENT if sel else DK.C_TEXT)


## Kimin hangi karakteri seçtiği: kartın sol üstünde oyuncu renginde baş harf.
func _refresh_marks() -> void:
	for id in _cards:
		var marks: HBoxContainer = _cards[id]["marks"]
		for c in marks.get_children():
			marks.remove_child(c)
			c.queue_free()
	var ids: Array = _player_ids()
	for i in ids.size():
		var info: Dictionary = NetworkManager.lobby_players[ids[i]]
		var cid: int = int(info.get("char_id", 1))
		if not _cards.has(cid):
			continue
		var col: Color = DK.player_color(i)
		var p := DK.box(col, col.darkened(0.5), 0, 2, 3)
		p.custom_minimum_size = Vector2(26, 26)
		var l := DK.lbl(str(info.get("name", "?")).substr(0, 1).to_upper(), DK.FS_LABEL, Color("#16120c"), HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		p.add_child(l)
		p.tooltip_text = str(info.get("name", ""))
		(_cards[cid]["marks"] as HBoxContainer).add_child(p)


func show_character(id: int, locked: bool) -> void:
	var prev: int = _sel_char
	_sel_char = id
	_viewing_locked = locked
	if _cards.has(prev):
		_style_card(prev)
	if _cards.has(id):
		_style_card(id)
	var def: Dictionary = Characters.get_def(id)
	_char_name.text = str(def.get("name", ""))
	_fill_stats(id)
	_fill_skills(id)
	if _preview:
		_preview.call("setup", def, 3, 172.0)
	_refresh_loadout_header()
	_refresh_start()
	if solo:
		_refresh_players() ## kendi kartındaki yüz + karakter adı


## Kumanda/klavye: odak seçili karakter kartında başlar.
func focus_character(id: int) -> void:
	if _cards.has(id):
		(_cards[id]["btn"] as Button).grab_focus()


func _stat_tex(key: String) -> Texture2D:
	var f: String = str(SI.ICON_PATHS.get(key, ""))
	if f != "" and ResourceLoader.exists(SI.ICON_DIR + f):
		return load(SI.ICON_DIR + f) as Texture2D
	return null


func _fill_stats(id: int) -> void:
	for c in _stats.get_children():
		_stats.remove_child(c)
		c.queue_free()
	var bs: Dictionary = Characters.get_base_stats(id)
	var atk: int = int(bs.get("atk", 0))
	for row: Array in [["max_health", "Can", str(int(bs.get("hp", 100)))], ["speed", "Hız", str(int(bs.get("speed", 252)))],
			["damage", "Güç", str(int(bs.get("ap", 10)))], ["fire_rate", "Saldırı Hızı", ("%+d%%" % atk) if atk != 0 else "0"]]:
		var hb := DK.h(8)
		hb.add_child(DK.icon(_stat_tex(row[0]), 32))
		hb.add_child(DK.lbl(row[1], DK.FS_LABEL, DK.C_DIM))
		hb.add_child(DK.lbl(row[2], DK.FS_LABEL))
		_stats.add_child(hb)


## Yetenek açıklamasının ilk cümlesi ("ULTİ:" gibi büyük harfli önek atılır); tamamı satırın ipucunda.
static func first_sentence(t: String, n: int = 150) -> String:
	var s: String = t.strip_edges()
	var colon: int = s.find(":")
	if colon > 0 and colon < 22 and s.substr(0, colon).to_upper() == s.substr(0, colon):
		s = s.substr(colon + 1).strip_edges()
	var dot: int = s.find(". ")
	if dot > 0:
		s = s.substr(0, dot + 1)
	if s.length() > n:
		s = s.substr(0, n - 3).strip_edges() + "..."
	return s


func _fill_skills(id: int) -> void:
	for c in _skills.get_children():
		_skills.remove_child(c)
		c.queue_free()
	var d: Dictionary = Characters.get_def(id)
	for slot: Array in [["skill", "skill"], ["skill2", "skill2"], ["skill3", "skill3"], ["passive", ""]]:
		var key: String = slot[0]
		var nm: String = "Pasif" if key == "passive" else str(d.get(key + "_name", ""))
		var desc: String = str(d.get("passive" if key == "passive" else key + "_desc", ""))
		if nm == "" and desc == "":
			continue
		var badge: String = "P" if key == "passive" else GameManager.get_action_key_label(str(slot[1]))
		var lvl: int = 0 if key == "passive" else Characters.skill_unlock_level(id, key)
		_skills.add_child(_skill_row(_tex(str(d.get(key + "_icon", ""))), badge, nm, desc, lvl))


func _tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _skill_row(tex: Texture2D, key: String, nm: String, desc: String, unlock_lvl: int) -> HBoxContainer:
	var hb := DK.h(14)
	hb.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.tooltip_text = "%s%s\n%s" % [nm, ("  (%d. seviyede açılır)" % unlock_lvl) if unlock_lvl > 1 else "", desc]
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(56, 56)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sl := DK.slot(tex, 48)
	sl.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(sl)
	var kb := DK.box(DK.C_INSET, DK.C_LINE_HI, 0, 2, 3)
	kb.custom_minimum_size = Vector2(24, 24)
	kb.position = Vector2(36, 36)
	kb.add_child(DK.lbl(key.left(1), DK.FS_SMALL, DK.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	holder.add_child(kb)
	hb.add_child(holder)
	var v := DK.v(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(DK.lbl(nm, DK.FS_BODY))
	if desc != "":
		v.add_child(DK.wrap(first_sentence(desc), DK.FS_LABEL, DK.C_DIM, MID.size.x - 32 - 56 - 14, 1))
	hb.add_child(v)
	return hb


## ------------------------------------------------------------------ sağ: vitrin + sekmeli yükleme
func _build_right() -> void:
	var right := DK.box(DK.C_PANEL, DK.C_LINE, 16)
	var xv := DK.v(12)
	var hv := DK.h(16)
	var sc := DK.box(DK.C_INSET, DK.C_LINE, 0)
	sc.custom_minimum_size = Vector2(200, 200)
	sc.add_child(DK.Spot.new(DK.C_SPOT, 0.86))
	_preview = PreviewScript.new()
	_preview.custom_minimum_size = Vector2(200, 200)
	sc.add_child(_preview)
	_preview.set("playing", true)
	hv.add_child(sc)
	var hb := DK.v(6)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(DK.lbl("YÜKLEMEN", DK.FS_LABEL, DK.C_ACCENT))
	_load_name = DK.lbl("", DK.FS_TITLE)
	_load_name.clip_text = true
	hb.add_child(_load_name)
	_load_icons = DK.h(6)
	hb.add_child(_load_icons)
	hv.add_child(hb)
	xv.add_child(hv)
	var tabs := DK.h(8)
	for t: Array in [["weapon", "SİLAH"], ["pet", "EVCİL"], ["spirit", "RUHANİ"]]:
		var tb := DK.btn(t[1], "ghost", DK.FS_BODY, 52, 0)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = t[0]
		tb.pressed.connect(func() -> void: _set_tab(key))
		_tab_btns[key] = tb
		tabs.add_child(tb)
	xv.add_child(tabs)
	_tab_grid = GridContainer.new()
	_tab_grid.columns = 5
	_tab_grid.add_theme_constant_override("h_separation", 10)
	_tab_grid.add_theme_constant_override("v_separation", 10)
	xv.add_child(_tab_grid)
	xv.add_child(DK.sp(0, 0, false, true))
	var wd := DK.box(DK.C_INSET, DK.C_LINE, 14)
	var wdv := DK.v(4)
	var wh := DK.h(10)
	_detail_name = DK.lbl("", DK.FS_BODY, DK.C_ACCENT)
	wh.add_child(_detail_name)
	_detail_cat = DK.lbl("", DK.FS_LABEL, DK.C_DIM)
	wh.add_child(_detail_cat)
	wdv.add_child(wh)
	_detail_desc = DK.wrap("", DK.FS_LABEL, DK.C_DIM, RIGHT.size.x - 32 - 28, 4)
	_detail_desc.custom_minimum_size.y = 4 * 26
	wdv.add_child(_detail_desc)
	wd.add_child(wdv)
	xv.add_child(wd)
	right.add_child(xv)
	_put(right, RIGHT)
	_set_tab("weapon")


func _current(kind: String) -> String:
	match kind:
		"weapon":
			return GameManager.selected_start_weapon
		"pet":
			return PC.selected()
	return GameManager.selected_spiritual


func _set_tab(kind: String) -> void:
	_tab = kind
	_detail_key = _current(kind)
	for k in _tab_btns:
		DK.style_button(_tab_btns[k], "primary" if k == kind else "ghost")
	_fill_tab()


func _options(kind: String) -> Array:
	match kind:
		"weapon":
			return WC.KEYS
		"pet":
			return PC.KEYS
	return SS.ORDER


func _meta_kind(kind: String) -> String:
	return {"weapon": MP.WEAPON, "pet": MP.PET, "spirit": MP.SPIRIT}[kind]


func _opt_icon(kind: String, key: String) -> Texture2D:
	match kind:
		"weapon":
			return WC.icon(key)
		"pet":
			return PC.icon(key)
	return _tex(str(SS.get_def(key).get("icon", "")))


func _opt_name(kind: String, key: String) -> String:
	match kind:
		"weapon":
			return WC.display_name(key)
		"pet":
			return PC.display_name(key)
	return SS.skill_name(key)


func _fill_tab() -> void:
	for c in _tab_grid.get_children():
		_tab_grid.remove_child(c)
		c.queue_free()
	var cur: String = _current(_tab)
	for key: String in _options(_tab):
		var lk: bool = not MP.is_unlocked(_meta_kind(_tab), key)
		var on: bool = key == cur
		var b := Button.new()
		b.custom_minimum_size = TILE
		DK.style_button(b, "tile_on" if on else ("tile_locked" if lk else "tile"), 4, 4.0)
		b.tooltip_text = _opt_name(_tab, key) + ("\n" + MP.lock_text(_meta_kind(_tab), key) if lk else "")
		var v := DK.v(2)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		## DK.icon tam katlı ölçekler: 64 kutuda 48 px sanat 1x kalıyordu (silahlar küçük görünürdü) -> silah 96 (2x).
		v.add_child(DK.icon(_opt_icon(_tab, key), 96 if _tab == "weapon" else 64, lk))
		v.add_child(DK.lbl(_opt_name(_tab, key), DK.FS_SMALL, DK.C_ACCENT if on else (DK.C_DIM if lk else DK.C_TEXT), HORIZONTAL_ALIGNMENT_CENTER))
		b.add_child(v)
		if lk:
			var lg := DK.glyph(DK.G_LOCK, DK.C_DIM, 2)
			lg.position = Vector2(TILE.x - 22, 8)
			b.add_child(lg)
		b.pressed.connect(_on_option_pressed.bind(key))
		_tab_grid.add_child(b)
	_fill_detail()
	UISound.connect_all_buttons(_tab_grid)


func _on_option_pressed(key: String) -> void:
	_detail_key = key
	if MP.is_unlocked(_meta_kind(_tab), key):
		match _tab:
			"weapon":
				GameManager.selected_start_weapon = key
				NetworkManager.update_local_loadout()
			"pet":
				GameManager.selected_pet = key
			_:
				GameManager.selected_spiritual = key
				NetworkManager.update_local_loadout()
		## Kendi kartındaki ikonlar: evcil ağdan gitmez; tek oyunculuda lobby_updated yok.
		if solo or _tab == "pet":
			_refresh_players()
	_fill_tab()
	_refresh_loadout_header()


func _fill_detail() -> void:
	var key: String = _detail_key
	var lk: bool = not MP.is_unlocked(_meta_kind(_tab), key)
	_detail_name.text = _opt_name(_tab, key)
	match _tab:
		"weapon":
			_detail_cat.text = WC.category_label(key)
			_detail_cat.add_theme_color_override("font_color", WC.category_color(key))
			_detail_desc.text = WC.trait_text(key)
		"pet":
			_detail_cat.text = "Evcil hayvan"
			_detail_cat.add_theme_color_override("font_color", DK.C_DIM)
			_detail_desc.text = PC.description(key)
		_:
			var def: Dictionary = SS.get_def(key)
			_detail_cat.text = "Aktif (%s)" % GameManager.get_action_key_label("skill4") if bool(def.get("active", false)) else "Pasif"
			_detail_cat.add_theme_color_override("font_color", DK.C_DIM)
			_detail_desc.text = str(def.get("desc", ""))
	if lk:
		_detail_desc.text = MP.lock_text(_meta_kind(_tab), key) + "\n" + _detail_desc.text


func _refresh_loadout_header() -> void:
	if _load_name == null:
		return
	_load_name.text = str(Characters.get_def(_sel_char).get("name", ""))
	for c in _load_icons.get_children():
		_load_icons.remove_child(c)
		c.queue_free()
	for kind: String in ["weapon", "pet", "spirit"]:
		var key: String = _current(kind)
		_load_icons.add_child(DK.slot(_opt_icon(kind, key), 48, _opt_name(kind, key)))


## ------------------------------------------------------------------ başlat / hazır + kilit
func _build_start() -> void:
	var v := DK.v(6)
	_start_btn = DK.btn("OYUNU BAŞLAT", "off", DK.FS_TITLE, 80, RIGHT.size.x)
	_start_btn.pressed.connect(func() -> void:
		if solo or NetworkManager.is_host:
			start_pressed.emit()
		else:
			ready_pressed.emit())
	v.add_child(_start_btn)
	_start_info = DK.lbl("", DK.FS_LABEL, DK.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_start_info)
	_put(v, Rect2(RIGHT.position.x, START_Y, RIGHT.size.x, 0))


func _build_lock() -> void:
	_lock = ColorRect.new()
	_lock.color = Color(0.07, 0.04, 0.02, 0.45)
	_lock.mouse_filter = Control.MOUSE_FILTER_STOP
	_lock.visible = false
	_put(_lock, Rect2(MID.position, Vector2(RIGHT.end.x - MID.position.x, RIGHT.size.y)))
	var l := DK.lbl("Hazırsın - değiştirmek için HAZIR DEĞİLİM'e bas.", DK.FS_BODY, DK.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_lock.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_bottom = -24


func _local_ready() -> bool:
	return bool(NetworkManager.lobby_players.get(_my_id(), {}).get("is_ready", false))


func _refresh_start() -> void:
	if _start_btn == null:
		return
	if solo:
		_start_btn.text = "KİLİTLİ KARAKTER" if _viewing_locked else "OYUNU BAŞLAT"
		_start_btn.disabled = _viewing_locked
		DK.style_button(_start_btn, "off" if _viewing_locked else "primary")
		_start_info.text = MP.lock_text(MP.CHAR, _sel_char) if _viewing_locked else "Tek oyunculu  ·  Esc: ana menü"
		return
	var lp: Dictionary = NetworkManager.lobby_players
	var ready_n: int = 0
	for info: Dictionary in lp.values():
		if info.get("is_ready", false):
			ready_n += 1
	var pending: int = NetworkManager.pending_join_count()
	var info_text: String = "%d/%d hazır" % [ready_n, lp.size()]
	if pending > 0:
		info_text += "  ·  %d oyuncu bağlanıyor" % pending
	var kind: String = "primary"
	if NetworkManager.is_host:
		_start_btn.text = "OYUNU BAŞLAT"
		var can: bool = NetworkManager.all_players_ready() and not _viewing_locked
		_start_btn.disabled = not can
		kind = "primary" if can else "off"
		if _viewing_locked:
			info_text = "Kilitli karakterle başlatılamaz  ·  " + info_text
		elif not NetworkManager.all_players_ready():
			info_text += "  ·  herkes hazır olunca başlatabilirsin"
	else:
		var local_ready: bool = _local_ready()
		if NetworkManager.is_join_blocked_by_game():
			_start_btn.text = "OYUN BAŞLAMIŞ"
			_start_btn.disabled = true
			kind = "off"
		elif NetworkManager.is_room_game_in_progress():
			_start_btn.disabled = false
			_start_btn.text = "OYUNA KATILIYOR..." if local_ready else "OYUNA KATIL"
		else:
			_start_btn.disabled = false
			_start_btn.text = "HAZIR DEĞİLİM" if local_ready else "HAZIRIM"
			kind = "ghost" if local_ready else "primary"
			if _viewing_locked and not local_ready:
				_start_btn.disabled = true
				_start_btn.text = "KİLİTLİ KARAKTER"
				kind = "off"
		info_text += "  ·  host herkes hazır olunca başlatır"
	DK.style_button(_start_btn, kind)
	_start_info.text = info_text
	if _lock:
		_lock.visible = _local_ready() and not NetworkManager.is_host


func set_status(text: String) -> void:
	if _status:
		_status.text = text


## lobby_updated: oda bilgisi, oyuncular, kart işaretleri, başlat düğmesi.
func refresh() -> void:
	if not NetworkManager.is_multiplayer_active:
		return
	_refresh_room()
	_refresh_players()
	_refresh_marks()
	_refresh_start()
