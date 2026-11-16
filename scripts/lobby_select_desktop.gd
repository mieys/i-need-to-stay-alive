extends Control
const Loc := preload("res://scripts/localization.gd") ## dil desteği: Loc.t / Loc.pct (madde 446)

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

const HT := preload("res://scripts/hud_theme.gd") ## tek arayüz paleti (stil rehberi, madde 403)
const DK := preload("res://scripts/menu_dark_kit.gd")
const WC := preload("res://scripts/weapon_catalog.gd")
const PC := preload("res://scripts/pet_catalog.gd")
const SS := preload("res://scripts/spiritual_skills.gd")
const MP := preload("res://scripts/meta_progress.gd")
const LU := preload("res://scripts/menu_lobby_ui.gd")
const PortraitFace := preload("res://scripts/portrait_face.gd") ## yüz + karaktere özel bulanık arka plan (madde 464/485)
const PetBadge := preload("res://scripts/pet_badge.gd") ## evcile özel bulanık arka plan (madde 585)
## Oyuncu kartındaki silah / evcil / ruhani yuva yüzü (madde 681): 64 = 32 px silah çizimi 2x; çerçeveyle 72 = portre boyu.
const CARD_SLOT_PX := 64.0
const CornerBrackets := preload("res://scripts/corner_brackets.gd") ## seçili / üstündeki kartın köşebentleri (madde 538)
const SI := preload("res://scripts/stat_icon.gd")
const WeaponStatBars := preload("res://scripts/weapon_stat_bars.gd")
const PreviewScript := preload("res://scripts/menu_character_preview.gd")
const RR := preload("res://scripts/run_records.gd")
const RunSummaryUI := preload("res://scripts/run_summary_ui.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const PK := preload("res://scripts/phone_menu_kit.gd")
const GameModeScript := preload("res://scripts/pvp/game_mode.gd") ## 2v2: oyuncu kartları takım başlıkları altında (madde 608)
const TeamsScript := preload("res://scripts/pvp/teams.gd")
const PvpNetScript := preload("res://scripts/pvp/pvp_net.gd")

const LEFT := Rect2(32, 24, 440, 1024)
const MID := Rect2(488, 24, 760, 1024)
const RIGHT := Rect2(1264, 24, 624, 908)
const ROW_GAP := 24 ## orta panel çubuk / stat satırında iki blok arasındaki en az boşluk (madde 748)
const START_Y := 948.0
const CARD := Vector2(134, 150)
## TILE.y 124 -> 122 + TILE_NAME_GAP -4 -> -6 (madde 759): SEL_PAD 8 ok payı silah sekmesinde sağ paneli 908 -> 910 uzatıyordu; panel boyu
## değişince PixelBox damar kayması (grain_offset, kutu BOYUNA bağlı) değişip sekme değiştirince pencere dokusu "değişiyordu".
const TILE := Vector2(108, 122)
## TEK KUTU (madde 759, 2026-11-16; kullanıcı: "kutu içinde kutu var, karakter ikonunun çerçevesi olsa yeter"): MASAÜSTÜNDE kart / karo
## kutusu yok (düğme flat, yalnız tıklama alanı), kutu = Gömme Tepsi çerçevesi, ad altında. Karakter: yüz 96 + 2x8 = 112; 5 x 112 + 4 x 42
## = 728 = orta panelin iç genişliği (başlık / ayraçla aynı kenar). Yüz x5 (136) + 32'lik adla en dolu karakterde (Matthew) orta panel
## 1047 > 1024 oluyordu -> x4 kaldı. Telefon düzeni eski kart kutusunda (görsel doğrulanmadı, madde 279).
const CARD_GAP := Vector2(42, 16)
const CARD_NAME_GAP := -6 ## etiketin üstündeki satır payı alt köşebende yetiyor -> eksi aralık, yazı köşebendin hemen altında
const CARD_NAME_H := 32.0
const NAME_OVER := 12.0 ## ad etiketi çerçeveden iki yana taşabilir (en uzun ad 32'de < 136)
const TILE_FRAME := 104.0
const TILE_GAP := 15 ## 5 x 104 + 4 x 15 = 580: sekmelerin sol kenarına hizalı, sağda kaydırma çubuğu payı 20 (madde 652)
const TILE_NAME_GAP := -6
const WEAPON_ICON_TARGET := 75.0 ## silah çiziminin uzun kenarı en çok (madde 759, _weapon_icon; 60 -> 75 "azcık daha büyük")
const WEAPON_DENSE_FILL := 0.55 ## opak oranı bunun üstündeki (dolu yuvarlak / kare) silahın hedefi %90
## Yetenek ikonu 48 -> 56 (madde 759). 60 denendi: metin sütunu 658 -> 638 daralıp Lyra'nın iki kısa metni 2 satıra sığmadı ("…");
## 56 + 2x8 çerçeve = 72, ikon-metin aralığı 14 -> SKILL_GAP 8 -> sütun 648.
const SKILL_ICON := 56.0
const SKILL_GAP := 8
const SKILL_BOX := SKILL_ICON + 16.0 ## + 2 x 8 Gömme Tepsi çerçevesi
const SEL_PAD := 8 ## sağ ızgaranın kaydırma kutusunda pay: seçim oku çerçevenin 8 px üstüne, uzun ad sütunun 7 px soluna taşar
const PickArrow := preload("res://scripts/pick_arrow.gd") ## seçili kartın zıplayan oku (madde 759)
const SEL_PAL := [HT.PICK_FRAME_HI, HT.ACCENT, HT.PICK_FRAME_LO] ## seçili çerçeve: açık kenar / ahşap / koyu ahşap altın
const HOV_PAL := [HT.ACCENT_SOFT, HT.PICK_HOVER, HT.RIM] ## üstünde / odakta: açık ahşap
const SHORT := {} ## uzun unvanların kart kısaltması; karakterlere isim verilince boşaldı (madde 623)
const CHAT_KEEP := 50
const ScrollFollowScript := preload("res://scripts/scroll_follow.gd")

## Tek oyunculu kip (build'den ÖNCE atanır).
var solo: bool = false
var _sel_char: int = 1
var _viewing_locked: bool = false
var _tab: String = "weapon"
var _detail_key: String = "" ## sekmede incelenen (kilitliyse seçilmeden açıklaması gösterilir)
var _cards: Dictionary = {} ## char_id -> {"btn": Button, "name": Label, "face": FramedPortrait, "arrow" / "brk", ...}
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
var _char_title: Label = null ## lakap satırı (madde 623); boşsa gizli
var _stats: GridContainer = null
var _skills: VBoxContainer = null
var _preview: Control = null
var _load_name: Label = null
var _load_icons: HBoxContainer = null ## yalnız telefon düzeni (_ph_refresh_loadout)
var _hero_side: VBoxContainer = null ## masaüstü vitrin: önizlemenin sağı, şimdilik BOŞ (kullanıcı dolduracak, madde 748)
var _char_bars: GridContainer = null ## orta panel: karakter Hasar/Savunma/Çeviklik/Destek çubukları (weapon_stat_bars.gd CHAR_ROWS)
var _tab_btns: Dictionary = {}
var _tab_grid: GridContainer = null
var _detail_name: Label = null
var _detail_cat: Label = null
var _detail_desc: Label = null
var _detail_bars: GridContainer = null ## silah stat çubukları (weapon_stat_bars.gd); yalnız SİLAH sekmesinde görünür
var _start_btn: Button = null
## Harita artık OYUNU BAŞLAT'tan sonra dünya haritasında seçilir (world_map_screen.gd, madde 606); buradaki HARİTA kutusu kalktı.
const MapProfilesScript := preload("res://scripts/map_profiles.gd")
var _start_info: Label = null
var _lock: ColorRect = null
var _pending_shown: int = -1
var _pending_bars: Array = []
var _time: float = 0.0
## Ölçüler (telefonda büyür, bkz. _build_phone).
var _card: Vector2 = CARD
var _card_face: float = 96.0
var _tile: Vector2 = TILE
var _fs_lab: int = DK.FS_LABEL
var _fs_small: int = DK.FS_SMALL
var _prev_k: int = 3
var _prev_ground: float = 158.0


func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = DK.theme()
	_validate_loadout()
	_warm_previews()
	if not solo:
		var pvp_net: Node = PvpNetScript.instance()
		if pvp_net != null and not pvp_net.is_connected("teams_changed", _on_teams_changed):
			pvp_net.connect("teams_changed", _on_teams_changed)
	if MobileUIScript.enabled:
		_build_phone()
		return
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


## Karta tıklayınca önizleme takılıyordu: karakterin SpriteFrames'i ilk tıklamada yükleniyor (25-265 ms) ve ilk karenin
## dolu piksel kutusu `get_image()` (GPU geri okuma) ile ölçülüyordu. Yükleme KENDİ iş parçacığında (WorkerThreadPool
## değil - madde 233), ölçüm ana iş parçacığında kare başına bir karakter; sonuç `PreviewScript` önbelleğinde kalır.
func _warm_previews() -> void:
	var defs: Array = []
	var paths: Array = []
	for id in Characters.DEFS.keys():
		var d: Dictionary = Characters.get_def(int(id))
		var p: String = str(d.get("frames", ""))
		if p != "":
			defs.append(d)
			paths.append(p)
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or paths.is_empty():
		return
	var th := Thread.new()
	th.start(func() -> void:
		for p: String in paths:
			ResourceLoader.load(p))
	while th.is_alive():
		await loop.process_frame
	th.wait_to_finish()
	for d: Dictionary in defs:
		if not is_instance_valid(self):
			return
		PreviewScript.warm(d)
		await loop.process_frame


func _exit_tree() -> void:
	if NetworkManager.chat_message_received.is_connected(_on_chat_message):
		NetworkManager.chat_message_received.disconnect(_on_chat_message)
	var pvp_net: Node = PvpNetScript.instance()
	if pvp_net != null and pvp_net.is_connected("teams_changed", _on_teams_changed):
		pvp_net.disconnect("teams_changed", _on_teams_changed)


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
	if p != str(GameManager.selected_pet):
		changed = true
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
	ScrollFollowScript.attach(_chat_scroll)
	cv.add_child(_chat_scroll)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Mesaj yaz... (Enter)"
	_chat_input.max_length = 200
	_chat_input.keep_editing_on_text_submit = true ## Enter sonrası odak kaybolmasın
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
	_chips.add_child(DK.chip(DK.I_PLAYERS, "Tek oyuncu", DK.C_DIM))
	var shard := DK.box(DK.C_INSET, DK.C_LINE, 6, 2, 4)
	var sst = shard.get_theme_stylebox("panel") ## PixelBox (madde 417)
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

	## Oyuncu kartı / EN İYİ KOŞULLAR tek VBox'ta alt alta; kayıt kutusu kalan yüksekliği doldurur (alt kenar 1048).
	## (Aradaki HARİTA kutusu madde 606'da kalktı: harita OYUNU BAŞLAT'tan sonra dünya haritasında seçilir.)
	var stack := DK.v(12)
	stack.name = "SoloStack"
	_put(stack, Rect2(LEFT.position.x, 184, LEFT.size.x, LEFT.end.y - 184.0))
	_players = DK.v(10)
	_players.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(_players)
	_refresh_players()
	var records := _records_box()
	records.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(records)


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
	v.add_child(DK.title_bar("EN İYİ KOŞULARIN", DK.lbl(Loc.t("%d koşu") % runs if runs > 0 else "", DK.FS_LABEL, DK.C_DIM)))
	if runs <= 0:
		v.add_child(DK.wrap("Henüz koşu yok. İlk koşunu başlat - en yüksek kademen, en uzun süren ve en çok öldürmen burada görünür.",
			DK.FS_LABEL, DK.C_DIM, LEFT.size.x - 28))
		box.add_child(v)
		return box
	var tiles := DK.h(10)
	for t: Array in [["EN YÜKSEK KADEME", Loc.t("Kademe %d") % int(data.get("best_tier", 0))],
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
	_chips.add_child(DK.chip(DK.I_LOCKED if locked else DK.I_OPEN, "Şifreli" if locked else "Şifresiz", DK.C_DIM))
	if NetworkManager.is_online_session:
		_chips.add_child(DK.chip(DK.I_ONLINE, "İnternet", DK.C_DIM))
	else:
		_chips.add_child(DK.chip(DK.I_ONLINE, (Loc.t("LAN %s") % NetworkManager.room_code) if NetworkManager.room_code != "" else "LAN", DK.C_DIM))
	_chips.add_child(DK.chip(DK.I_PLAYERS, "%d/%d" % [NetworkManager.lobby_players.size(), NetworkManager.room_max_players], DK.C_TEXT))
	if _team_mode():
		_chips.add_child(DK.chip(DK.G_CROWN, GameModeScript.display_name(GameModeScript.PVP), DK.C_ACCENT))


func _refresh_players() -> void:
	if _players == null: ## telefon tek oyunculu: oyuncu kartı yok
		return
	for c in _players.get_children():
		_players.remove_child(c)
		c.queue_free()
	_pending_bars.clear()
	if solo:
		_players.add_child(_player_card(0, 0))
		return
	var ids: Array = _player_ids()
	if _team_mode():
		## 2v2 (madde 608): iki takım başlığı, altında o takımın oyuncuları; kart rengi (index) kimlik sırasından, takım değişince değişmez.
		for t in TeamsScript.TEAM_COUNT:
			_players.add_child(_team_header(t))
			for i in ids.size():
				if TeamsScript.team_of(int(ids[i])) == t:
					_players.add_child(_player_card(int(ids[i]), i))
	else:
		for i in ids.size():
			_players.add_child(_player_card(int(ids[i]), i))
	var pending: int = NetworkManager.pending_join_count()
	_pending_shown = pending
	for k in pending:
		_players.add_child(_pending_card())
	UISound.connect_all_buttons(_players)


## 2v2 odası mı (oyuncular takım başlıkları altında gruplanır). Tek oyunculuda hiç.
func _team_mode() -> bool:
	return not solo and GameModeScript.is_pvp()


## Takım başlığı: renkli ad + kişi sayısı; sağda bu takımda değilsem GEÇ düğmesi (takım doluysa kapalı), değilsem "TAKIMIN" etiketi.
func _team_header(team: int) -> Control:
	var col: Color = HT.TEAM_COLORS[team]
	var cap: int = TeamsScript.team_capacity(NetworkManager.room_max_players)
	var n: int = 0
	for pid in _player_ids():
		if TeamsScript.team_of(int(pid)) == team:
			n += 1
	var mine: bool = TeamsScript.team_of(_my_id()) == team
	var hb := DK.h(10)
	hb.name = "TeamHeader%d" % team
	var stripe := ColorRect.new()
	stripe.color = col
	stripe.custom_minimum_size = Vector2(6, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(stripe)
	var title := DK.lbl(TeamsScript.TITLES[team], DK.FS_LABEL, col)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.x = 40
	hb.add_child(title)
	var count := DK.lbl("%d/%d" % [n, cap], DK.FS_LABEL, DK.C_DIM)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(count)
	if mine:
		hb.add_child(_team_tag(col))
	else:
		var full: bool = n >= cap
		var b := DK.btn("DOLU" if full else "BU TAKIMA GEÇ", "off" if full else "tile", DK.FS_LABEL, 72.0 if _phone else 44.0, 0)
		b.name = "TeamJoin%d" % team
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = full
		b.tooltip_text = "Takım dolu" if full else "%s takımına geç" % TeamsScript.NAMES[team]
		b.pressed.connect(_on_team_join_pressed.bind(team))
		hb.add_child(b)
	return hb


func _team_tag(col: Color) -> PanelContainer:
	var p := DK.box(col, Color(0, 0, 0, 0), 2, 0, 3)
	var st = p.get_theme_stylebox("panel") ## PixelBox (madde 417)
	st.content_margin_left = 8
	st.content_margin_right = 8
	var l := DK.lbl("TAKIMIN", DK.FS_LABEL, DK.C_ACCENT_TEXT)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _on_team_join_pressed(team: int) -> void:
	var net: Node = PvpNetScript.instance()
	if net != null:
		net.call("request_team", team)


## Host takımları değiştirdi (ya da başkası geçti): kartlar + başlat bilgisi yenilenir.
func _on_teams_changed() -> void:
	if _players == null or not is_inside_tree():
		return
	_refresh_players()
	_refresh_start()


func _player_card(pid: int, index: int) -> PanelContainer:
	var info: Dictionary = _local_info() if solo else NetworkManager.lobby_players.get(pid, {})
	var me: bool = solo or pid == _my_id()
	var col: Color = DK.player_color(index)
	var card := DK.box(DK.C_PANEL3 if me else DK.C_PANEL, DK.C_ACCENT if me else DK.C_LINE, 10)
	var hb := DK.h(12)
	var stripe := ColorRect.new()
	stripe.color = HT.TEAM_COLORS[TeamsScript.team_of(pid)] if _team_mode() else col
	stripe.custom_minimum_size = Vector2(6, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(stripe)
	var cid: int = int(info.get("char_id", 1))
	hb.add_child(PortraitFace.framed_icon(cid, 72, 2.0))
	var v := DK.v(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var top := DK.h(8)
	var nm := DK.lbl(str(info.get("name", "Oyuncu")), DK.FS_BODY)
	nm.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED ## oyuncu adı çevrilmez ("Can" -> "Health" olmasın, 2026-11-15)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.custom_minimum_size.x = 40
	top.add_child(nm)
	if bool(info.get("is_host", false)):
		var cr := DK.room_icon(DK.I_HOST)
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
		bot.add_child(_kind_slot("weapon", wkey, CARD_SLOT_PX, "Silah: " + WC.display_name(wkey)))
	## Evcil: kendi kartında yerel seçim, başkasınınkinde lobby_players["pet"] (eski exe göndermez -> boş).
	var pkey: String = PC.selected() if me else str(info.get("pet", ""))
	if PC.is_valid(pkey):
		bot.add_child(_kind_slot("pet", pkey, CARD_SLOT_PX, "Evcil: " + PC.display_name(pkey)))
	var sid: String = str(info.get("spirit", ""))
	if SS.is_valid(sid):
		bot.add_child(_kind_slot("spirit", sid, CARD_SLOT_PX, "Ruhani: " + SS.skill_name(sid)))
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
	var st = p.get_theme_stylebox("panel") ## PixelBox (madde 417)
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
	ScrollFollowScript.to_end(_chat_scroll) ## asıl iniş vbar.changed'de (satır boyu birkaç karede oturur)


## ------------------------------------------------------------------ orta: karakter ızgarası + ayrıntı
func _build_mid() -> void:
	var mid := DK.box(DK.C_PANEL, DK.C_LINE, 16)
	var mv := DK.v(12)
	_open_count = DK.lbl("", DK.FS_LABEL, DK.C_DIM)
	## AYRINTILI (madde 756): yetenek satırları KISA metin, tam metin bu düğmenin penceresinde. Alt kenarda 2 satırlık kısa metinle
	## sığmıyordu (37 px taşma) -> başlık satırının sağında.
	var th := DK.h(12)
	th.add_child(_open_count)
	th.add_child(_details_button(DK.FS_LABEL, 34.0))
	mv.add_child(DK.title_bar("KARAKTERİNİ SEÇ", th))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", int(CARD_GAP.x)) ## tek kutu (madde 759)
	grid.add_theme_constant_override("v_separation", int(CARD_GAP.y))
	var ids: Array = Characters.DEFS.keys()
	ids.sort()
	var open_n: int = 0
	for id in ids:
		## Yalnız sahip olunan karakterler listelenir; kilitliler Ruh Mağazası'nda görünür.
		if not MP.is_unlocked(MP.CHAR, int(id)):
			continue
		grid.add_child(_char_card(int(id)))
		open_n += 1
	_open_count.text = ""
	mv.add_child(grid)
	mv.add_child(DK.hline())
	## 2026-11-16 (madde 748): satır = [karakter çubukları 2x2] [boşluk] [temel statlar 2x2]. Karakter adı + lakap bu satırdan SAĞ ÜSTE
	## (vitrin önizlemesinin yanı, _build_right) taşındı (kullanıcı: "karakterin adı yazmasın o halde, sağ üstte yazsın"). Çubuk bloğu sola,
	## yeteneklerin ikon kenarına hizalı ve SABİT (karakter değişince kaymaz); temel statlar sağ kenarda. Çubuk bloğu temel stat ızgarasıyla
	## aynı kalıp (2 satır, 32 px ikon): 32 + 9 + 117 (3 sanat px dilim) = 158 hücre, blok 334; en geniş stat ızgarası 337 (Aldric) -> sığar.
	## Uzun özel stat adları kısa (meta_upgrades "short"); başka dilde yine sığmazsa _fit_stats_row "…" ile kırpar.
	var nh := DK.h(0)
	if not _phone:
		_char_bars = WeaponStatBars.new()
		_char_bars.setup(3, 32.0, DK.FS_LABEL, WeaponStatBars.CHAR_ROWS, 3)
		_char_bars.add_theme_constant_override("v_separation", 0) ## hücre (ad + dilim) 36 px: 2 x 36 = 72 ~ stat ızgarası 2 x 32 + 6 = 70
		_char_bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nh.add_child(_char_bars)
	nh.add_child(DK.sp(ROW_GAP, 0, true))
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 22)
	_stats.add_theme_constant_override("v_separation", 6)
	_stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nh.add_child(_stats)
	mv.add_child(nh)
	## Stat satırı ile ilk yetenek arası 12 -> 30 (2026-11-16, kullanıcı: "yetenek satırıyla stat çubukları arasında çok az mesafe var"):
	## mv aralığı 12 + 6 px boşluk + 12. Yetenek satırları kendi arasında 10'da kalır.
	mv.add_child(DK.sp(0, 6))
	## Kısa metin 2 satır (madde 756): satır arası 10 -> 4, yoksa 4 satırı da iki satırlık karakter (Matthew) 13 px taşıyordu.
	_skills = DK.v(4)
	mv.add_child(_skills)
	mid.add_child(mv)
	_put(mid, MID)


func _char_card(id: int) -> Button:
	var def: Dictionary = Characters.get_def(id)
	var lk: bool = not MP.is_unlocked(MP.CHAR, id)
	var b := Button.new()
	b.custom_minimum_size = _card
	b.tooltip_text = str(def.get("name", "")) + ("\n" + MP.lock_text(MP.CHAR, id) if lk else "")
	b.pressed.connect(func() -> void: character_picked.emit(id))
	var single: bool = not _phone ## TEK KUTU yalnız masaüstü (madde 759)
	var v := DK.v(CARD_NAME_GAP if single else 2)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN if single else BoxContainer.ALIGNMENT_CENTER
	## Portre Gömme Tepsi çerçevesinde (madde 535): çerçevesiz kare kartın içinde "kesik" duruyordu.
	var face: CenterContainer = PortraitFace.framed_icon(id, _card_face, 3.0 if _phone else 2.0, lk)
	var fw: float = face.custom_minimum_size.x
	if single:
		_flat_button(b)
		b.custom_minimum_size = Vector2(fw, face.custom_minimum_size.y + CARD_NAME_GAP + CARD_NAME_H)
		v.offset_left = -NAME_OVER
		v.offset_right = NAME_OVER
	v.add_child(face)
	var nl: Label = null
	if lk:
		var ph := DK.h(6)
		ph.alignment = BoxContainer.ALIGNMENT_CENTER
		ph.add_child(DK.ShardIcon.new(18 if _fs_lab <= DK.FS_LABEL else 28, true))
		ph.add_child(DK.lbl(str(MP.cost(MP.CHAR, id)), _fs_lab, DK.C_BAD))
		v.add_child(ph)
	else:
		var t: String = str(SHORT.get(id, def.get("name", "")))
		## Etiket metni ekranda çevrilir -> ölçüm çevrilmiş adla (tr).
		var tw: float = DK.font().get_string_size(tr(t), HORIZONTAL_ALIGNMENT_LEFT, -1, DK.FS_BODY).x
		var fs: int = (DK.FS_BODY if tw <= fw + NAME_OVER * 2.0 else DK.FS_LABEL) if single \
				else (_fs_lab if DK.font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs_lab).x <= _card.x - 12 else _fs_small)
		nl = DK.lbl(t, fs, DK.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(nl)
	b.add_child(v)
	## Seçim vurgusu: telefonda KÖŞEBENT (madde 538: seçili altın, üstünde / odakta PICK_HOVER). Masaüstü tek kutuda (madde 759, kullanıcı
	## 4 prototipten "D ile B'yi birleştir"): seçili = çerçeve ALTIN + üstünde zıplayan altın OK (pick_arrow.gd), üstünde / odakta = çerçeve
	## açık ahşap; ikisi de _refresh_brackets'te.
	var brk: Control = null
	var arrow: Control = null
	if single:
		arrow = PickArrow.new()
		arrow.set("t", 3.0)
		(face.get_child(0) as Control).add_child(arrow)
	else:
		brk = CornerBrackets.new()
		brk.set("t", 4.0 if _phone else 3.0)
		b.add_child(brk)
	b.mouse_entered.connect(_set_card_hover.bind(id, "hov", true))
	b.mouse_exited.connect(_set_card_hover.bind(id, "hov", false))
	b.focus_entered.connect(_set_card_hover.bind(id, "foc", true))
	b.focus_exited.connect(_set_card_hover.bind(id, "foc", false))
	if lk:
		var cw: float = fw if single else _card.x
		var lg := DK.glyph(DK.G_LOCK, DK.C_DIM, 3 if _card.x <= CARD.x else 4)
		lg.position = Vector2(cw - (30 if _card.x <= CARD.x else 40), 8)
		b.add_child(lg)
	## Kartın sol üstündeki oyuncu baş harfi (kim hangi karakteri seçti) kaldırıldı (madde 759, kullanıcı: "kimin aldığını belirten
	## göstergeye gerek yok"); oyuncu kartları zaten herkesin karakterini gösteriyor.
	_cards[id] = {"btn": b, "name": nl, "locked": lk, "face": face.get_child(0), "brk": brk, "arrow": arrow, "hov": false, "foc": false}
	_style_card(id)
	return b


func _style_card(id: int) -> void:
	var c: Dictionary = _cards[id]
	var sel: bool = id == _sel_char
	## Kart kenarı her durumda nötr (madde 538: altın "tile_on" kenarı + altın odak halkası kalktı); seçili yalnız bir ton açık dolgu,
	## üstündeyken dolgu biraz açılır, vurgu köşebentlerde (_refresh_brackets).
	var b: Button = c["btn"]
	var lk: bool = c["locked"]
	if not b.flat: ## tek kutu (madde 759) kartında kutu yok
		var fill: Color = DK.C_INSET if lk else (DK.C_PANEL3 if sel else DK.C_PANEL2)
		DK.style_button_colors(b, fill, DK.C_LINE, DK.C_DIM if lk else DK.C_TEXT, Color(0, 0, 0, 0), 2, 4, 6.0)
		b.add_theme_stylebox_override("hover", DK.sb(fill.lightened(0.06), DK.C_LINE, 2, 4, 6.0))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_refresh_brackets(id)
	if c["name"] != null:
		(c["name"] as Label).add_theme_color_override("font_color", DK.C_ACCENT if sel else DK.C_TEXT)
	var fp: Object = c.get("face")
	if fp != null and fp.has_method("set_accent") and c.get("arrow") == null: ## tek kutuda çerçevenin tamamı boyanır (_refresh_brackets)
		fp.call("set_accent", DK.C_ACCENT if sel else Color(0, 0, 0, 0))


func _set_card_hover(id: int, key: String, on: bool) -> void:
	if not _cards.has(id):
		return
	_cards[id][key] = on
	_refresh_brackets(id)


func _refresh_brackets(id: int) -> void:
	var c: Dictionary = _cards[id]
	var arrow: Object = c.get("arrow")
	if arrow != null and is_instance_valid(arrow): ## tek kutu (madde 759): altın çerçeve + ok / açık ahşap çerçeve
		var sel: bool = id == _sel_char
		var hov: bool = c.get("hov", false) or c.get("foc", false)
		(c["face"] as Object).call("set_palette", SEL_PAL if sel else (HOV_PAL if hov else []))
		arrow.call("set_on", sel)
		return
	var brk: Object = c.get("brk")
	if brk == null or not is_instance_valid(brk):
		return
	var col := Color(0, 0, 0, 0)
	if id == _sel_char:
		col = DK.C_ACCENT
	elif c.get("hov", false) or c.get("foc", false):
		col = HT.PICK_HOVER
	brk.call("set_color", col)


## Tek kutu (madde 759): düğme yalnız tıklama alanı, hiçbir durumda kutu çizmez (flat + boş odak).
static func _flat_button(b: Button) -> void:
	b.flat = true
	for s: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())


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
	if _char_title:
		_char_title.text = str(def.get("title_name", ""))
		_char_title.visible = _char_title.text != ""
	_fill_stats(id)
	if _char_bars != null:
		_char_bars.call("show_values", Characters.stat_bars(id))
	_fill_skills(id)
	if _preview:
		_preview.call("setup", def, _prev_k, _prev_ground)
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
	var rows: Array = [["max_health", "Can", str(int(bs.get("hp", 100)))], ["speed", "Hız", str(int(bs.get("speed", 252)))],
			["damage", "Güç", str(int(bs.get("ap", 10)))]]
	var sig: Dictionary = MenuKit.signature_info(id) ## karaktere özel stat (madde 677) 4. hücre
	if not sig.is_empty():
		## Masaüstünde ad satırı dar (çubuklar ortada, madde 748): kısa ad, tam ad ipucunda. Telefon tam adı kullanır.
		rows.append([str(sig["icon"]), str(sig["name"] if _phone else sig["short"]), str(sig["value"]), str(sig["name"])])
	var sig_lab: Label = null
	for row: Array in rows:
		var hb := DK.h(8)
		hb.add_child(DK.icon(_stat_tex(row[0]), 32 if _fs_lab <= DK.FS_LABEL else 48))
		var nlab := DK.lbl(row[1], _fs_lab, DK.C_DIM)
		if _phone: ## telefon: ad solda, değer sağda (iki sütun eşit genişlikte)
			nlab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(nlab)
		hb.add_child(DK.lbl(row[2], _fs_lab))
		if row.size() > 3:
			hb.mouse_filter = Control.MOUSE_FILTER_PASS
			hb.tooltip_text = "%s %s" % [tr(str(row[3])), row[2]]
			sig_lab = nlab
		_stats.add_child(hb)
	if not _phone and sig_lab != null:
		_fit_stats_row(sig_lab)


## Masaüstü ad satırı (madde 748): ad + boşluk + çubuk bloğu + boşluk + stat ızgarası iç genişliği aşarsa özel stat adı "…" ile kırpılır
## (kısa adı olmayan uzun çeviriler için; tam ad hücrenin ipucunda). Aşmıyorsa dokunulmaz.
func _fit_stats_row(sig_lab: Label) -> void:
	var nh: Control = _stats.get_parent()
	var used: float = 0.0
	for c in nh.get_children():
		used += (c as Control).get_combined_minimum_size().x
	var over: float = used - (MID.size.x - 32.0)
	if over <= 0.0:
		return
	var w: float = sig_lab.get_combined_minimum_size().x
	sig_lab.clip_text = true
	sig_lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sig_lab.custom_minimum_size.x = maxf(40.0, floorf(w - over))


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


## ---------------------------------------------------------------- kısa / ayrıntılı yetenek açıklaması (madde 756)
## Orta paneldeki yetenek satırının açıklama satır sayısı (kısa metin; sığma: tests/test_skill_short_desc.gd).
const SKILL_ROW_LINES := 2
var _details_ov: Control = null


## Kısa açıklama tek satırlık gösterime: tür öneki ("ULTİ:", "TEMEL (Q ile değişir):"), gömülü bekleme notu ve satır sonları atılır.
static func short_line(t: String) -> String:
	var re := RegEx.new()
	## Tür öneki: BÜYÜK HARF kelime (+ parantez) + ":" ; Çincede harf büyüklüğü yok -> Han kelime + PARANTEZ + ":" (madde 759: "基础 (用 Q 切换):"
	## silinmiyor, Lyra satırı 2 satıra sığmıyordu). Parantezsiz Han önek (pasif adı "闪电速度：") korunur.
	re.compile("^\\s*(?:\\p{Lu}+(?:\\s*\\([^)]*\\))?|\\p{Han}+\\s*\\([^)]*\\))\\s*[:：]\\s*")
	var s: String = re.sub(t.strip_edges(), "")
	re.compile("\\s*\\(\\d+(?:[.,]\\d+)?\\s*(?:sn bekleme|s cooldown|s Abklingzeit|s de enfriamiento|s de recharge|s di ricarica|s de recarga|s odnowienia|с перезарядки|秒冷却)\\)")
	s = re.sub(s, "", true)
	return s.replace("\n", " ").strip_edges()


func _details_button(fs: int, hh: float) -> Button:
	var b := DK.btn("AYRINTILI", "ghost", fs, hh)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Yeteneklerin ve ruhani yeteneğin tam açıklaması"
	b.pressed.connect(open_skill_details)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_details_ov) and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_skill_details()


func close_skill_details() -> void:
	if is_instance_valid(_details_ov):
		_details_ov.queue_free()
	_details_ov = null


## Seçili karakterin P/Q/E/R + seçili ruhani yeteneğin UZUN (eski, tam) açıklamaları; dışına tık / KAPAT / Esc kapatır.
func open_skill_details() -> void:
	close_skill_details()
	var d: Dictionary = Characters.get_def(_sel_char)
	var ov := ColorRect.new()
	ov.color = Color(HT.DEEP, 0.6)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_details_ov = ov
	var area: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
	var fs_text: int = _fs_lab
	var psz := Vector2(minf(1120.0, area.x - 48.0), minf(920.0, area.y - 48.0))
	var panel := DK.box(DK.C_PANEL2, DK.C_LINE_HI, 20)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.add_child(panel)
	panel.position = ((area - psz) * 0.5).floor()
	panel.size = psz
	ov.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close_skill_details())
	var v := DK.v(12)
	panel.add_child(v)
	var close := DK.btn("KAPAT", "ghost", fs_text, 44.0)
	close.pressed.connect(close_skill_details)
	v.add_child(DK.title_bar(Loc.t("%s - AYRINTILI AÇIKLAMA") % str(d.get("name", "")), close, DK.FS_BODY))
	v.add_child(DK.hline())
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var list := DK.v(18)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var text_w: float = psz.x - 40.0 - SKILL_BOX - 14.0 - 24.0 ## panel iç payı + ikon çerçevesi + aralık + kaydırma çubuğu
	for slot: Array in [["passive", ""], ["skill", "skill"], ["skill2", "skill2"], ["skill3", "skill3"]]:
		var key: String = slot[0]
		var desc: String = Characters.long_desc(d, key)
		if desc == "":
			continue
		var nm: String = Loc.t("Pasif") if key == "passive" else str(d.get(key + "_name", ""))
		var badge: String = "P" if key == "passive" else GameManager.get_action_key_label(str(slot[1]))
		list.add_child(_details_row(_tex(str(d.get(key + "_icon", ""))), "%s  [%s]" % [nm, badge.left(1)], desc, text_w, fs_text))
	var sp_id: String = GameManager.selected_spiritual
	var sd: Dictionary = SS.get_def(sp_id)
	if not sd.is_empty():
		list.add_child(DK.hline(2.0))
		list.add_child(_details_row(_tex(str(sd.get("icon", ""))), Loc.t("Ruhani: %s") % str(sd.get("name", "")), str(sd.get("desc", "")), text_w, fs_text))
	UISound.connect_all_buttons(panel)


func _details_row(tex: Texture2D, title: String, desc: String, text_w: float, fs: int) -> HBoxContainer:
	var hb := DK.h(14)
	var sl := _skill_frame(tex)
	sl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(sl)
	var col := DK.v(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(DK.lbl(title, DK.FS_BODY, DK.C_ACCENT))
	col.add_child(DK.wrap(desc, fs, DK.C_TEXT, text_w))
	hb.add_child(col)
	return hb


func _fill_skills(id: int) -> void:
	close_skill_details() ## karakter değişince açık ayrıntı penceresi eski karakteri göstermesin
	for c in _skills.get_children():
		_skills.remove_child(c)
		c.queue_free()
	var d: Dictionary = Characters.get_def(id)
	if _phone:
		_ph_fill_skills(id, d)
		return
	for slot: Array in [["skill", "skill"], ["skill2", "skill2"], ["skill3", "skill3"], ["passive", ""]]:
		var key: String = slot[0]
		var nm: String = "Pasif" if key == "passive" else str(d.get(key + "_name", ""))
		var desc: String = Characters.long_desc(d, key)
		if nm == "" and desc == "":
			continue
		var badge: String = "P" if key == "passive" else GameManager.get_action_key_label(str(slot[1]))
		var lvl: int = 0 if key == "passive" else Characters.skill_unlock_level(id, key)
		_skills.add_child(_skill_row(_tex(str(d.get(key + "_icon", ""))), badge, nm, desc, lvl, short_line(Characters.short_desc(d, key))))


func _tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Yetenek ikonu Gömme Tepsi çerçevesinde (madde 759, kullanıcı: "skill göstergelerindeki çerçeveler diğer çerçeveler gibi olsun ...
## azıcık büyüsün skill ikonları da"): eski DK.slot (ince C_LINE kenar, 48 px) yerine portre / karo çerçevesi (t 2), ikon 48 -> 56.
## İkon dokuları 144 px = 48 sanat px x3; 56'da nearest küçültme (sanat pikseli ~1,17 ekran px).
func _skill_frame(tex: Texture2D) -> CenterContainer:
	return PortraitFace.wrap_framed(DK.icon(tex, SKILL_ICON), Vector2(SKILL_ICON, SKILL_ICON), 2.0)


func _skill_row(tex: Texture2D, key: String, nm: String, desc: String, unlock_lvl: int, short: String = "") -> HBoxContainer:
	var hb := DK.h(SKILL_GAP)
	hb.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.tooltip_text = "%s%s\n%s" % [nm, (Loc.t("  (%d. seviyede açılır)") % unlock_lvl) if unlock_lvl > 1 else "", desc]
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(SKILL_BOX, SKILL_BOX)
	## HBox çocuğu varsayılan FILL: 2 satırlık açıklama satırı ikondan uzun -> çerçeve dikey gerilip ikonun
	## üstünde/altında siyah bant kalıyordu (2026-11-16). Kare kalsın, metne göre ortalansın.
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fr := _skill_frame(tex)
	fr.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(fr)
	var kb := DK.box(DK.C_INSET, DK.C_LINE_HI, 0, 2, 3)
	kb.custom_minimum_size = Vector2(24, 24)
	kb.position = Vector2(SKILL_BOX - 20.0, SKILL_BOX - 20.0) ## sağ alt köşeye, çerçeveden 4 px taşar (eskisi gibi)
	kb.add_child(DK.lbl(key.left(1), DK.FS_SMALL, DK.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	holder.add_child(kb)
	hb.add_child(holder)
	var v := DK.v(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(DK.lbl(nm, DK.FS_BODY))
	if desc != "":
		v.add_child(DK.wrap(short if short != "" else first_sentence(desc), DK.FS_LABEL, DK.C_DIM, MID.size.x - 32 - SKILL_BOX - SKILL_GAP, SKILL_ROW_LINES))
	hb.add_child(v)
	return hb


## ------------------------------------------------------------------ sağ: vitrin + sekmeli yükleme
func _build_right() -> void:
	## 2026-10-19: 17 silahla ızgara 4 satır (124 px karo) -> panel OYUNU BAŞLAT'ın altına taşıyordu; boşluklar sıkıştı
	## (dolgu 12, aralık 6, vitrin 184, sekme 44, ızgara 6, açıklama 3 satır). Sığma testi: test_start_weapon_pick.gd.
	var right := DK.box(DK.C_PANEL, DK.C_LINE, 12)
	var xv := DK.v(6)
	var hv := DK.h(16)
	var sc := DK.box(DK.C_INSET, DK.C_LINE, 0)
	sc.custom_minimum_size = Vector2(184, 184)
	_preview = PreviewScript.new()
	_preview.custom_minimum_size = Vector2(184, 184)
	sc.add_child(_preview)
	_preview.set("playing", true)
	hv.add_child(sc)
	## 2026-11-16 (madde 748): önizlemenin sağında ÜSTTE karakter adı + lakap (orta paneldeki ad satırından taşındı, kullanıcı isteği);
	## altı boş - kullanıcı buraya seçilen silah/evcil/ruhani kutucuklarını ya da karakter hikayesini koyacak.
	_hero_side = DK.v(0)
	_hero_side.alignment = BoxContainer.ALIGNMENT_BEGIN
	_hero_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_char_name = DK.lbl("", DK.FS_TITLE, DK.C_ACCENT)
	_char_name.clip_text = true
	_char_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hero_side.add_child(_char_name)
	_char_title = DK.lbl("", DK.FS_LABEL, DK.C_DIM) ## lakap (madde 623)
	_hero_side.add_child(_char_title)
	hv.add_child(_hero_side)
	xv.add_child(hv)
	var tabs := DK.h(8)
	for t: Array in [["weapon", "SİLAH"], ["pet", "EVCİL"], ["spirit", "RUHANİ"]]:
		var tb := DK.btn(t[1], "ghost", DK.FS_BODY, 44, 0)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = t[0]
		tb.pressed.connect(func() -> void: _set_tab(key))
		_tab_btns[key] = tb
		tabs.add_child(tb)
	xv.add_child(tabs)
	_tab_grid = GridContainer.new()
	_tab_grid.columns = 5
	_tab_grid.add_theme_constant_override("h_separation", TILE_GAP) ## tek kutu (madde 759): 10 -> 15, 5 x 104 + 4 x 15 = 580
	_tab_grid.add_theme_constant_override("v_separation", 3) ## 6 -> 3: 4 satırla da panel 8 px taşıyordu (madde 652 ölçümü)
	## 2026-11-13 (madde 652, 21. silah Makineli): 20'den fazla seçenek 5. satırı açıp paneli yine OYUNU BAŞLAT'ın altına taşıyordu ->
	## ızgara en çok 4 satır yüksekliğinde bir kaydırma kutusunda (fazlası tekerlekle kayar; 5 x 108 + aralık 580 < 600, çubuğa yer var).
	var grid_scroll := ScrollContainer.new()
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	## 2026-11-13 (silah stat çubukları, kullanıcı: "silahlara daha az yer kalsa da bu bilgi önemli"): ızgara 4 -> 3 satır, açılan ~127 px
	## ayrıntı kutusundaki çubuklara gitti (fazlası yine kayar).
	## Tek kutuda seçim oku çerçevenin ÜSTÜNE, uzun ad (Rainbow Staff, Submachine Gun) sütunun SOLUNA taşar (madde 759); kaydırma kutusu
	## ilk satır / sütunda onları kesiyordu -> ızgara kutunun içinde SEL_PAD sol / üst payla, kutu da dış MarginContainer'ın eksi sol payıyla
	## aynı kadar sola taşar (panel dolgusu 12 > 8): karolar sekmelerin sol kenarında kalır. Kutu boyu da SEL_PAD uzun.
	grid_scroll.custom_minimum_size = Vector2(0, TILE.y * 3.0 + 3.0 * 2.0 + SEL_PAD)
	_tab_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", SEL_PAD)
	pad.add_theme_constant_override("margin_top", SEL_PAD)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(_tab_grid)
	grid_scroll.add_child(pad)
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", -SEL_PAD)
	outer.add_child(grid_scroll)
	xv.add_child(outer)
	xv.add_child(DK.sp(0, 0, false, true))
	var wd := DK.box(DK.C_INSET, DK.C_LINE, 10)
	var wdv := DK.v(4)
	var wh := DK.h(10)
	_detail_name = DK.lbl("", DK.FS_BODY, DK.C_ACCENT)
	wh.add_child(_detail_name)
	_detail_cat = DK.lbl("", DK.FS_LABEL, DK.C_DIM)
	wh.add_child(_detail_cat)
	wdv.add_child(wh)
	_detail_bars = WeaponStatBars.new()
	_detail_bars.setup(3, 48.0, DK.FS_LABEL)
	wdv.add_child(_detail_bars)
	_detail_desc = DK.wrap("", DK.FS_LABEL, DK.C_DIM, RIGHT.size.x - 24 - 20, 3)
	_detail_desc.custom_minimum_size.y = 3 * 26
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
			return WC.menu_icon(key) ## yatay çizimli tüfekler ızgarada çapraz + büyük (madde 581)
		"pet":
			return PC.icon(key)
	return _tex(str(SS.get_def(key).get("icon", "")))


## Yükleme satırı / oyuncu kartı yuvası (madde 679): portreyle aynı Gömme Tepsi çerçevesi (eski düz WIN_LINE kenar ahşap kartta kayboluyordu).
## Silah damarlı ahşap kuyuda (_weapon_well, madde 759), evcil kendi arka planıyla (madde 585), ruhani kendi çizimli zemininde.
## Toplam boy eskisiyle aynı: px + 2x4 çerçeve.
func _kind_slot(kind: String, key: String, px: float, tip: String) -> Control:
	var face: Control
	if kind == "pet" and PetBadge.has_background(key):
		face = PetBadge.box(key, px)
	elif kind == "weapon":
		face = _weapon_well(key, px)
	else:
		var well := ColorRect.new()
		well.color = DK.C_INSET
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := DK.icon(_opt_icon(kind, key), px)
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		well.add_child(ic)
		face = well
	## Evcil arka planı tam katla kırpılır (PetBadge.fit): kutu px'ten 1-2 px küçük olabilir -> kendi boyuyla çerçevelenir.
	var fs: Vector2 = face.custom_minimum_size if kind == "pet" and face.custom_minimum_size.x > 0.0 else Vector2(px, px)
	var cc := PortraitFace.wrap_framed(face, fs, 1.0)
	if tip != "":
		cc.tooltip_text = tip
		cc.mouse_filter = Control.MOUSE_FILTER_PASS
	return cc


## SİLAH KUYUSU (madde 759; kullanıcı: "silahların arkaplanı çok parlak ve göz yoruyor, önceki halindeki texture'a benzer"): düz açık
## ahşap yerine HT.ITEM_WELL (koyu ahşap RIM_LO) + pencere / karo ile AYNI R2 ahşap damarı, kart gücünde (PixelBox.grain_card_alpha).
## Kuyu GRAIN_MIN'den küçük olduğu için PixelBox kendisi dokulamaz -> damar karosundan side x side bölge (kayma anahtara bağlı, sanat
## pikseline oturur: karolar birbirinin kopyası görünmez). Çizim _weapon_icon ile dengeli boyda, kenara en az 2 px kala.
func _weapon_well(key: String, side: float) -> ColorRect:
	var well := ColorRect.new()
	well.color = HT.ITEM_WELL
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gt: Texture2D = DK.PixelBox.grain_tex
	if gt != null and DK.PixelBox.grain_card_alpha > 0.0:
		var h: int = absi(hash(key))
		var nx: int = maxi(1, int((gt.get_width() - side) / 3.0))
		var ny: int = maxi(1, int((gt.get_height() - side) / 3.0))
		var at := AtlasTexture.new()
		at.atlas = gt
		at.region = Rect2(float((h % nx) * 3), float(((h / 7) % ny) * 3), side, side)
		var gr := TextureRect.new()
		gr.texture = at
		gr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gr.stretch_mode = TextureRect.STRETCH_SCALE
		gr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		gr.set_anchors_preset(Control.PRESET_FULL_RECT)
		gr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gr.modulate = Color(1, 1, 1, DK.PixelBox.grain_card_alpha)
		well.add_child(gr)
	var ic := _weapon_icon(_trimmed(_opt_icon("weapon", key)), side - 4.0)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	well.add_child(ic)
	return well


## DENGELİ SİLAH BOYU (madde 759; kullanıcı: "bazı silahlar çok ufak bazıları çok büyük görünüyor" + "silahlar azcık daha büyük gözüksün"):
## DK.icon kutuya sığan EN BÜYÜK tam katı seçiyordu -> 28 px Yay / Arbalet 3x = 84, 48'lik tuvalde çizilmiş çapraz tüfekler (Tüfek / Pompalı /
## Makineli, kırpık 43-44 px) 1x = 44, çoğu (29-30 px) 2x = 58-60. Şimdi ölçek YARIM KAT adımlı, uzun kenar WEAPON_ICON_TARGET'i geçmeyen en
## büyük (tam kat hedefin %90'ına yetiyorsa o): çoğu 2,5x = 70-75, tüfekler 1,5x = 64-66. Dolu yuvarlak / kare çizim (opak oranı
## WEAPON_DENSE_FILL üstü: Kalkan, Çakram, Yin Yang) aynı boyda daha iri görünür -> hedefi %90 (Kalkan / Çakram 2x = 60, Yin Yang 2,5x = 65).
## Kutuya (box) sığmayan kat yarımşar küçülür (oyuncu kartı yuvası 60).
static func _weapon_icon(tex: Texture2D, box: float) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(box, box)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex == null:
		return cc
	var ts: Vector2 = tex.get_size()
	var md: float = maxf(ts.x, ts.y)
	var target: float = WEAPON_ICON_TARGET * (0.9 if _icon_fill(tex) > WEAPON_DENSE_FILL else 1.0)
	target = minf(target, box)
	var k: float = floorf(target / md)
	if k < 1.0 or k * md < target * 0.9:
		k = maxf(0.5, floorf(target / md * 2.0) / 2.0)
	while k * md > box and k > 0.5:
		k -= 0.5
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.custom_minimum_size = (ts * k).floor()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(tr)
	return cc


## Çizimin (kırpık bölge) opak piksel oranı; dolu yuvarlak / kare silahlar için (_weapon_icon). Önbellekli.
static var _fill_cache: Dictionary = {}

static func _icon_fill(tex: Texture2D) -> float:
	var src: Texture2D = tex
	var reg := Rect2i(Vector2i.ZERO, Vector2i(tex.get_size()))
	if tex is AtlasTexture:
		src = (tex as AtlasTexture).atlas
		reg = Rect2i((tex as AtlasTexture).region)
	if src == null or src.resource_path == "":
		return 0.0
	var ck: String = src.resource_path + str(reg)
	if _fill_cache.has(ck):
		return _fill_cache[ck]
	var f: float = 0.0
	var img: Image = src.get_image()
	if img and reg.size.x > 0 and reg.size.y > 0:
		if img.is_compressed():
			img.decompress()
		var n: int = 0
		for y in range(reg.position.y, reg.end.y):
			for x in range(reg.position.x, reg.end.x):
				if img.get_pixel(x, y).a > 0.5:
					n += 1
		f = float(n) / float(reg.size.x * reg.size.y)
	_fill_cache[ck] = f
	return f


## Dokunun saydam kenarını kırpar (silah çizimleri 32/48 tuvalde 26-30 px; kırpınca tam kat ölçek daha büyük sığar). Önbellekli.
static var _trim_cache: Dictionary = {}

static func _trimmed(tex: Texture2D) -> Texture2D:
	if tex == null or tex.resource_path == "":
		return tex
	if _trim_cache.has(tex.resource_path):
		return _trim_cache[tex.resource_path]
	var out: Texture2D = tex
	var img: Image = tex.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var r: Rect2i = img.get_used_rect()
		if r.size.x > 0 and r.size != img.get_size():
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(r)
			out = at
	_trim_cache[tex.resource_path] = out
	return out


func _opt_name(kind: String, key: String) -> String:
	match kind:
		"weapon":
			return WC.display_name(key)
		"pet":
			return PC.display_name(key)
	return SS.skill_name(key)


## Seçenek karosu / başlık yuvası ipucundaki fayda metni (ayrıntı sütunuyla aynı kaynak).
func _opt_desc(kind: String, key: String) -> String:
	match kind:
		"weapon":
			return WC.trait_text(key)
		"pet":
			return PC.description(key)
	return str(SS.get_def(key).get("desc", ""))


func _opt_tip(kind: String, key: String) -> String:
	var tip: String = _opt_name(kind, key)
	var desc: String = _opt_desc(kind, key)
	if desc != "":
		tip += "\n" + desc
	return tip


func _fill_tab() -> void:
	for c in _tab_grid.get_children():
		_tab_grid.remove_child(c)
		c.queue_free()
	var cur: String = _current(_tab)
	for key: String in _options(_tab):
		var lk: bool = not MP.is_unlocked(_meta_kind(_tab), key)
		if lk:
			continue ## sahip olunmayanlar burada gizli (Ruh Mağazası'nda görünür)
		var on: bool = key == cur
		var b := Button.new()
		b.tooltip_text = _opt_tip(_tab, key) + ("\n" + MP.lock_text(_meta_kind(_tab), key) if lk else "")
		if not _phone:
			_single_tile(b, key, on)
			b.pressed.connect(_on_option_pressed.bind(key))
			_tab_grid.add_child(b)
			continue
		b.custom_minimum_size = _tile
		DK.style_button(b, "tile_on" if on else ("tile_locked" if lk else "tile"), 4, 4.0)
		var v := DK.v(2)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		## DK.icon tam katlı ölçekler: 64 kutuda 48 px sanat 1x kalıyordu (silahlar küçük görünürdü) -> silah 96 (2x).
		var isz: float = (96.0 if _tab == "weapon" else 64.0) * (1.5 if _phone else 1.0)
		if _tab == "pet" and PetBadge.has_background(key):
			## karakter kartı portresiyle aynı çerçeve kalınlığı (madde 535) + arka plan (madde 585): masaüstü 56 iç (2x) + 2x4 kenar = 72
			v.add_child(PetBadge.framed_icon(key, 104.0 if _phone else 72.0, 3.0 if _phone else 2.0, lk))
		elif _tab == "spirit":
			## Ruhani de aynı Gömme Tepsi çerçevesinde (kullanıcı 2026-11-16: "diğerleri gibi çerçevesi olmalı"); toplam boy evcil karosuyla
			## aynı: masaüstü 56 iç + 2x8 kenar = 72, telefon 80 iç + 2x12 = 104 (144 px ikon küçültülür; eski çerçevesiz hali de 64'e küçülüyordu).
			var sp_in: float = 80.0 if _phone else 56.0
			var sp_face := DK.icon(_opt_icon(_tab, key), sp_in, lk)
			sp_face.custom_minimum_size = Vector2(sp_in, sp_in)
			v.add_child(PortraitFace.wrap_framed(sp_face, Vector2(sp_in, sp_in), 3.0 if _phone else 2.0, lk))
		else:
			v.add_child(DK.icon(_opt_icon(_tab, key), isz, lk))
		var on_l := DK.lbl(_opt_name(_tab, key), _fs_small, DK.C_ACCENT if on else (DK.C_DIM if lk else DK.C_TEXT), HORIZONTAL_ALIGNMENT_CENTER)
		on_l.clip_text = true
		on_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(on_l)
		b.add_child(v)
		if lk:
			var lg := DK.glyph(DK.G_LOCK, DK.C_DIM, 2 if not _phone else 3)
			lg.position = Vector2(_tile.x - (22 if not _phone else 32), 8)
			b.add_child(lg)
		b.pressed.connect(_on_option_pressed.bind(key))
		_tab_grid.add_child(b)
	_fill_detail()
	UISound.connect_all_buttons(_tab_grid)


## Masaüstü seçenek karosu TEK KUTU (madde 759): kutu = 104 px Gömme Tepsi çerçevesi (silah açık ahşap kuyuda, _kind_slot gibi; evcil kendi
## arka planıyla; ruhani kendi çiziminde), ad 24 altında. Seçili: çerçeve altın + zıplayan ok (karakter kartıyla aynı), ad altın; üstünde /
## odakta çerçeve açık ahşap.
## Ad sütun adımını (104 + 15) 6 px'e kadar aşabilir (yazı ortalı, komşuyla çakışmaz, kırpılmaz); daha uzunu 16'ya düşer ve "…" ile kırpılır.
func _single_tile(b: Button, key: String, on: bool) -> void:
	_flat_button(b)
	b.custom_minimum_size = Vector2(TILE_FRAME, TILE.y)
	b.set_meta("tile_on", on)
	var v := DK.v(TILE_NAME_GAP)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.offset_left = -float(TILE_GAP / 2)
	v.offset_right = float(TILE_GAP / 2)
	var inner: float = TILE_FRAME - 8.0 * 2.0
	var face: CenterContainer
	if _tab == "pet" and PetBadge.has_background(key):
		face = PetBadge.framed_icon(key, TILE_FRAME, 2.0)
	elif _tab == "weapon":
		face = PortraitFace.wrap_framed(_weapon_well(key, inner), Vector2(inner, inner), 2.0)
	else:
		var sp := DK.icon(_opt_icon(_tab, key), inner)
		sp.custom_minimum_size = Vector2(inner, inner)
		face = PortraitFace.wrap_framed(sp, Vector2(inner, inner), 2.0)
	v.add_child(face)
	var holder: Control = face.get_child(0)
	if on:
		holder.call("set_palette", SEL_PAL)
		var arrow := PickArrow.new()
		arrow.t = 2.0
		holder.add_child(arrow)
		arrow.set_on(true)
	var hov := func(state: bool) -> void:
		if not on:
			holder.call("set_palette", HOV_PAL if state else [])
	b.mouse_entered.connect(hov.bind(true))
	b.mouse_exited.connect(hov.bind(false))
	b.focus_entered.connect(hov.bind(true))
	b.focus_exited.connect(hov.bind(false))
	var nm: String = _opt_name(_tab, key)
	var limit: float = TILE_FRAME + float(TILE_GAP) + 6.0
	var too_long: bool = DK.font().get_string_size(tr(nm), HORIZONTAL_ALIGNMENT_LEFT, -1, DK.FS_LABEL).x > limit ## ekranda çevrilir
	var l := DK.lbl(nm, DK.FS_SMALL if too_long else DK.FS_LABEL, DK.C_ACCENT if on else DK.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.clip_text = too_long
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if too_long else TextServer.OVERRUN_NO_TRIMMING
	v.add_child(l)
	b.add_child(v)


func _on_option_pressed(key: String) -> void:
	_detail_key = key
	if MP.is_unlocked(_meta_kind(_tab), key):
		match _tab:
			"weapon":
				GameManager.selected_start_weapon = key
				NetworkManager.update_local_loadout()
			"pet":
				GameManager.selected_pet = key
				NetworkManager.update_local_loadout()
			_:
				GameManager.selected_spiritual = key
				NetworkManager.update_local_loadout()
		## Kendi kartındaki ikonlar: tek oyunculuda lobby_updated yok.
		if solo:
			_refresh_players()
	_fill_tab()
	_refresh_loadout_header()


func _fill_detail() -> void:
	var key: String = _detail_key
	var lk: bool = not MP.is_unlocked(_meta_kind(_tab), key)
	_detail_name.text = _opt_name(_tab, key)
	if _detail_bars != null:
		_detail_bars.visible = _tab == "weapon"
		if _tab == "weapon":
			_detail_bars.call("show_weapon", key)
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
			_detail_cat.text = Loc.t("Aktif (%s)") % GameManager.get_action_key_label("skill4") if bool(def.get("active", false)) else "Pasif"
			_detail_cat.add_theme_color_override("font_color", DK.C_DIM)
			_detail_desc.text = SS.short_desc(key) ## kısa (madde 756); tam metin karo ipucunda ve AYRINTILI penceresinde
	if lk:
		_detail_desc.text = MP.lock_text(_meta_kind(_tab), key) + "\n" + _detail_desc.text


func _refresh_loadout_header() -> void:
	## Masaüstünde vitrin başlığı şimdilik boş (madde 748); yalnız telefon düzeninin yükleme satırı var.
	if _phone and _load_name != null:
		_ph_refresh_loadout()


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
	## Kilit metni anahtar da isteyince uzar ("Kilitli - 450 Ruh Kıymığı + 3 Bataklık Anahtarı (Ruh Mağazası)", madde 605): sütunu genişletmesin,
	## sığmazsa kısalsın; tam metin fare üstünde ipucu.
	_start_info.clip_text = true
	_start_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_start_info.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(_start_info)
	_put(v, Rect2(RIGHT.position.x, START_Y, RIGHT.size.x, 0))


func _build_lock() -> void:
	_lock = ColorRect.new()
	_lock.color = Color(HT.DEEP, 0.45) ## tek palet (madde 403)
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
		_start_info.text = MP.lock_text(MP.CHAR, _sel_char) if _viewing_locked else ("" if _phone else "Tek oyunculu  ·  Esc: ana menü")
		_start_info.tooltip_text = _start_info.text if _viewing_locked else ""
		return
	var lp: Dictionary = NetworkManager.lobby_players
	var ready_n: int = 0
	for info: Dictionary in lp.values():
		if info.get("is_ready", false):
			ready_n += 1
	var pending: int = NetworkManager.pending_join_count()
	var info_text: String = Loc.t("%d/%d hazır") % [ready_n, lp.size()]
	if pending > 0:
		info_text += Loc.t("  ·  %d oyuncu bağlanıyor") % pending
	var kind: String = "primary"
	var team_block: String = TeamsScript.lobby_start_block() if _team_mode() else "" ## 2v2: iki takımda da oyuncu olmalı (madde 608)
	if NetworkManager.is_host:
		_start_btn.text = "OYUNU BAŞLAT"
		var can: bool = NetworkManager.all_players_ready() and not _viewing_locked and team_block == ""
		_start_btn.disabled = not can
		kind = "primary" if can else "off"
		if _viewing_locked:
			info_text = "Kilitli karakterle başlatılamaz  ·  " + info_text
		elif not NetworkManager.all_players_ready():
			info_text += "  ·  herkes hazır olunca başlatabilirsin"
		elif team_block != "":
			info_text += "  ·  " + team_block
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
		if team_block != "":
			info_text += "  ·  " + team_block
	DK.style_button(_start_btn, kind)
	_start_info.text = info_text.replace("  ·  ", ", ") if _phone else info_text
	if _lock:
		_lock.visible = _local_ready() and not NetworkManager.is_host


func set_status(text: String) -> void:
	if _status:
		_status.text = text


## lobby_updated: oda bilgisi, oyuncular, başlat düğmesi.
func refresh() -> void:
	if not NetworkManager.is_multiplayer_active:
		return
	_refresh_room()
	_refresh_players()
	_refresh_start()


## ------------------------------------------------------------------ telefon
## TELEFON (2026-10-19, madde 279; kullanıcı seçimi prototip S = B "Yan Ray + Detay", mobil_proto.gd B_karakter; kullanıcı: "karakter
## seçimlerinde (hepsi) karakterin yüzü görünsün sağdaki hali boydan olsun sadece"): ray [TAKIM (çok oyunculu)] KAHRAMAN / EVCİL / SİLAH /
## RUHANİ (simgeler o anki seçim); ortada sekmenin ızgarası (YÜZ kartları / seçenek karoları + açıklama) ya da TAKIM (oda, oyuncular,
## sohbet); sağda BOYDAN canlı önizleme + ad + statlar + yetenek simgeleri (dokununca açıklama) + yükleme + BAŞLAT / HAZIRIM. Aynı üyeler
## (_cards, _tab_grid, _detail_*, _stats, _skills, _preview, _start_btn, _players, _chat_* ...) masaüstü mantığıyla dolar; geri = leave_pressed.
var _phone: bool = false
var _ph: Dictionary = {}
var _ph_pages: Dictionary = {} ## "team" / "hero" / "opts" -> sayfa
var _ph_tab_keys: Array = []
var _ph_rail_icons: Dictionary = {} ## "pet"/"weapon"/"spirit" -> TextureRect (raydaki simge)
var _ph_opts_title: Label = null
var _ph_skill_desc: Label = null
var _ph_skill_sel: int = 0


func _build_phone() -> void:
	_phone = true
	_card = Vector2(196, 232)
	_card_face = 144.0
	_tile = Vector2(196, 232)
	_fs_lab = 32
	_fs_small = 32
	_prev_k = 6
	_prev_ground = 312.0
	var root := Control.new()
	root.name = "PhoneSelect"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	PK.fit(root)
	var tabs: Array = []
	if not solo:
		tabs.append(["TAKIM", PK.G_USERS])
		_ph_tab_keys.append("team")
	for k: Array in [["hero", "KAHRAMAN"], ["pet", "EVCİL"], ["weapon", "SİLAH"], ["spirit", "RUHANİ"]]:
		_ph_tab_keys.append(k[0])
		if k[0] == "hero":
			tabs.append([k[1], PK.G_USER])
		else:
			var ic: CenterContainer = DK.icon(_opt_icon(str(k[0]), _current(str(k[0]))), 64)
			if ic.get_child_count() > 0:
				_ph_rail_icons[k[0]] = ic.get_child(0)
			tabs.append([k[1], ic])
	_ph = PK.b_frame(root, tabs, func() -> void: leave_pressed.emit(), 860.0, 0.55)
	var rail_tabs: Array = _ph["tabs"]
	for i in rail_tabs.size():
		var ti: int = i
		(rail_tabs[i] as Button).pressed.connect(func() -> void:
			UISound.play_click()
			_ph_select_tab(ti))
	var mid: Control = _ph["mid"]
	_ph_pages["hero"] = _ph_hero_page()
	_ph_pages["opts"] = _ph_opts_page()
	if not solo:
		_ph_pages["team"] = _ph_team_page()
	for k in _ph_pages:
		var pg: Control = _ph_pages[k]
		mid.add_child(pg)
		pg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ph_build_detail(_ph["det"])
	if not solo:
		_ph_build_lock(root)
		NetworkManager.chat_message_received.connect(_on_chat_message)
		set_process(true)
	else:
		set_process(false)
	_tab = "weapon"
	_detail_key = _current("weapon")
	_ph_select_tab(_ph_tab_keys.find("hero"))


func _ph_select_tab(i: int) -> void:
	PK.set_rail(_ph["tabs"], i)
	var key: String = _ph_tab_keys[i]
	for k in _ph_pages:
		(_ph_pages[k] as Control).visible = false
	match key:
		"team", "hero":
			(_ph_pages[key] as Control).visible = true
		_:
			(_ph_pages["opts"] as Control).visible = true
			_ph_opts_title.text = {"pet": "EVCİL", "weapon": "SİLAH", "spirit": "RUHANİ"}[key]
			_set_tab(key)


## KAHRAMAN: başlık + açık sayısı + 5 sütun yüz kartı (kaydırılır).
func _ph_hero_page() -> Control:
	var v := DK.v(16)
	v.name = "HeroPage"
	_open_count = PK.lbl("", PK.FS_SMALL, DK.C_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	var head := DK.h(16)
	var t := PK.lbl("KAHRAMAN", PK.FS_TITLE, DK.C_ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_open_count)
	v.add_child(head)
	var lst: Array = PK.scroll_list(0)
	v.add_child(lst[0])
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	var ids: Array = Characters.DEFS.keys()
	ids.sort()
	var open_n: int = 0
	for id in ids:
		if not MP.is_unlocked(MP.CHAR, int(id)):
			continue
		grid.add_child(_char_card(int(id)))
		open_n += 1
	_open_count.text = ""
	(lst[1] as VBoxContainer).add_child(grid)
	return v


## EVCİL / SİLAH / RUHANİ: başlık + 5 sütun seçenek karosu (kaydırılır) + seçilen/incelenen seçeneğin açıklaması.
func _ph_opts_page() -> Control:
	var v := DK.v(16)
	v.name = "OptionsPage"
	_ph_opts_title = PK.lbl("", PK.FS_TITLE, DK.C_ACCENT)
	v.add_child(_ph_opts_title)
	var lst: Array = PK.scroll_list(0)
	v.add_child(lst[0])
	_tab_grid = GridContainer.new()
	_tab_grid.columns = 5
	_tab_grid.add_theme_constant_override("h_separation", 16)
	_tab_grid.add_theme_constant_override("v_separation", 16)
	(lst[1] as VBoxContainer).add_child(_tab_grid)
	var wd := PK.inset(0.85, 20.0, DK.C_LINE)
	wd.custom_minimum_size.y = 236
	var wdv := DK.v(6)
	var wh := DK.h(16)
	_detail_name = PK.lbl("", PK.FS_BODY, DK.C_ACCENT)
	wh.add_child(_detail_name)
	_detail_cat = PK.lbl("", PK.FS_SMALL, DK.C_DIM)
	wh.add_child(_detail_cat)
	wdv.add_child(wh)
	_detail_bars = WeaponStatBars.new()
	_detail_bars.setup(3, 48.0, PK.FS_SMALL)
	wdv.add_child(_detail_bars)
	_detail_desc = PK.lbl("", PK.FS_SMALL, DK.C_DIM)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wdv.add_child(_detail_desc)
	wd.add_child(wdv)
	v.add_child(wd)
	return v


## TAKIM (çok oyunculu): oda adı + bilgiler + durum, oyuncu kartları (kaydırılır), sohbet.
func _ph_team_page() -> Control:
	var v := DK.v(14)
	v.name = "TeamPage"
	var head := DK.h(16)
	_room_name = PK.lbl(NetworkManager.room_name, PK.FS_TITLE, DK.C_ACCENT)
	_room_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_name.clip_text = true
	_room_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_room_name)
	_leave_btn = PK.button("ODAYI KAPAT" if NetworkManager.is_host else "ODADAN ÇIK", "danger", PK.FS_SMALL, [], 0.0, 72.0)
	_leave_btn.pressed.connect(func() -> void: leave_pressed.emit())
	head.add_child(_leave_btn)
	v.add_child(head)
	_chips = DK.h(8)
	v.add_child(_chips)
	_status = PK.lbl("Karakterini, silahını, evcilini ve ruhani yeteneğini seç.", PK.FS_SMALL, DK.C_DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	var cols := DK.h(20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var plist := ScrollContainer.new()
	plist.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	plist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plist.size_flags_stretch_ratio = 1.2
	_players = DK.v(10)
	_players.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plist.add_child(_players)
	cols.add_child(plist)
	var chat := PK.inset(0.85, 16.0, DK.C_LINE)
	chat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cv := DK.v(8)
	cv.add_child(PK.lbl("SOHBET", PK.FS_SMALL, DK.C_ACCENT))
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log = DK.v(4)
	_chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_scroll.add_child(_chat_log)
	ScrollFollowScript.attach(_chat_scroll)
	cv.add_child(_chat_scroll)
	_chat_input = PK.line_edit("Mesaj yaz", PK.FS_SMALL, 80.0)
	_chat_input.max_length = 200
	_chat_input.keep_editing_on_text_submit = true ## Enter sonrası odak kaybolmasın
	_chat_input.text_submitted.connect(func(_t: String) -> void: _send_chat())
	cv.add_child(_chat_input)
	chat.add_child(cv)
	cols.add_child(chat)
	v.add_child(cols)
	for e in NetworkManager.lobby_chat_log:
		_add_chat_line(str(e["name"]), str(e["text"]))
	_scroll_chat_end.call_deferred()
	return v


## Sağ sütun: boydan önizleme + ad + statlar + yetenek simgeleri + yükleme + başlat.
func _ph_build_detail(det: VBoxContainer) -> void:
	var sc := PK.inset(0.8, 0.0, DK.C_LINE)
	sc.custom_minimum_size = Vector2(0, 340)
	_preview = PreviewScript.new()
	_preview.custom_minimum_size = Vector2(0, 340)
	sc.add_child(_preview)
	_preview.set("playing", true)
	det.add_child(sc)
	det.add_child(DK.sp(0, 12))
	_char_name = PK.lbl("", PK.FS_TITLE, DK.C_ACCENT)
	det.add_child(_char_name)
	_char_title = PK.lbl("", PK.FS_SMALL, DK.C_DIM) ## lakap (madde 623)
	det.add_child(_char_title)
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 40)
	_stats.add_theme_constant_override("v_separation", 4)
	det.add_child(_stats)
	det.add_child(DK.sp(0, 12))
	_skills = DK.v(8)
	det.add_child(_skills)
	det.add_child(DK.sp(0, 0, false, true))
	var lr := DK.h(12)
	_load_icons = DK.h(8)
	lr.add_child(_load_icons)
	_load_name = PK.lbl("", PK.FS_SMALL, DK.C_DIM)
	_load_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_name.clip_text = true
	_load_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lr.add_child(_load_name)
	det.add_child(lr)
	det.add_child(DK.sp(0, 12))
	_start_info = PK.lbl("", PK.FS_SMALL, DK.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_start_info.clip_text = true
	_start_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	det.add_child(_start_info)
	_start_btn = DK.btn("OYUNU BAŞLAT", "off", PK.FS_TITLE, 144, 0)
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_btn.pressed.connect(func() -> void:
		if solo or NetworkManager.is_host:
			start_pressed.emit()
		else:
			ready_pressed.emit())
	det.add_child(_start_btn)


## Yetenek simgeleri (Pasif, Q, E, R) 96 px + tuş rozeti + AYRINTILI; dokunulan yeteneğin adı + KISA açıklaması altta (madde 756).
func _ph_fill_skills(id: int, d: Dictionary) -> void:
	var row := DK.h(20)
	var slots: Array = []
	for slot: Array in [["passive", ""], ["skill", "skill"], ["skill2", "skill2"], ["skill3", "skill3"]]:
		var key: String = slot[0]
		var nm: String = "Pasif" if key == "passive" else str(d.get(key + "_name", ""))
		var desc: String = short_line(Characters.short_desc(d, key)) ## kısa (madde 756); tam metin AYRINTILI penceresinde
		if nm == "" and desc == "":
			continue
		slots.append([key, nm, desc, "P" if key == "passive" else GameManager.get_action_key_label(str(slot[1])).left(1)])
	_ph_skill_sel = clampi(_ph_skill_sel, 0, maxi(slots.size() - 1, 0))
	for i in slots.size():
		var sl: Array = slots[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(104, 104)
		DK.style_button(b, "tile_on" if i == _ph_skill_sel else "tile", 6, 4.0)
		var holder := CenterContainer.new()
		holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(DK.icon(_tex(str(d.get(str(sl[0]) + "_icon", ""))), 88))
		b.add_child(holder)
		var kb := DK.box(DK.C_INSET, DK.C_ACCENT if str(sl[3]) == "R" else DK.C_LINE_HI, 0, 2, 3)
		kb.custom_minimum_size = Vector2(36, 36)
		kb.position = Vector2(-6, 74)
		kb.add_child(DK.lbl(str(sl[3]), 24, DK.C_ACCENT if str(sl[3]) == "R" else DK.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		b.add_child(kb)
		var bi: int = i
		b.pressed.connect(func() -> void:
			_ph_skill_sel = bi
			_fill_skills(_sel_char))
		row.add_child(b)
	row.add_child(DK.sp(0, 0, true))
	var dbtn := _details_button(24, 104.0)
	dbtn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dbtn.custom_minimum_size.y = 72.0
	row.add_child(dbtn)
	_skills.add_child(row)
	_ph_skill_desc = PK.lbl("", PK.FS_SMALL, DK.C_DIM)
	_ph_skill_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ph_skill_desc.custom_minimum_size = Vector2(0, 72)
	if not slots.is_empty():
		var cur: Array = slots[_ph_skill_sel]
		var lvl: int = 0 if str(cur[0]) == "passive" else Characters.skill_unlock_level(id, str(cur[0]))
		_ph_skill_desc.text = "%s%s: %s" % [cur[1], (Loc.t(" (%d. sv.)") % lvl) if lvl > 1 else "", str(cur[2])]
	_skills.add_child(_ph_skill_desc)


## Yükleme satırı (evcil, silah, ruhani simgeleri + adları) ve raydaki simgeler.
func _ph_refresh_loadout() -> void:
	for c in _load_icons.get_children():
		_load_icons.remove_child(c)
		c.queue_free()
	var names: Array = []
	for kind: String in ["pet", "weapon", "spirit"]:
		var key: String = _current(kind)
		_load_icons.add_child(_kind_slot(kind, key, 56, _opt_name(kind, key)))
		names.append(_opt_name(kind, key))
		var tr: Variant = _ph_rail_icons.get(kind)
		if tr is TextureRect and is_instance_valid(tr):
			(tr as TextureRect).texture = _opt_icon(kind, key)
	_load_name.text = ", ".join(names)


## Hazır olunca (istemci) seçim alanı kilitlenir; HAZIR DEĞİLİM sağ sütunda açık kalır.
func _ph_build_lock(root: Control) -> void:
	_lock = ColorRect.new()
	_lock.color = Color(HT.DEEP, 0.5)
	_lock.mouse_filter = Control.MOUSE_FILTER_STOP
	_lock.visible = false
	_lock.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lock.offset_left = PK.RAIL_W
	_lock.offset_right = -(860.0 + 2.0 * PK.EDGE)
	root.add_child(_lock)
	var l := PK.lbl("Hazırsın - değiştirmek için HAZIR DEĞİLİM'e bas.", PK.FS_BODY, DK.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_lock.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_bottom = -48
