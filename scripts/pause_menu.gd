extends CanvasLayer
const Loc := preload("res://scripts/localization.gd") ## dil desteği: Loc.t / Loc.pct (madde 446)

## DURAKLATMA (ESC) MENÜSÜ - "B - Ateş Işığı" (2026-10-17, madde 234; prototip madde 229, kullanıcı "B" seçti).
## Ana menünün D dili (madde 192): kutu yok, oyun dünyası hafif kararır + sol yumuşak gölge, büyük altın başlık + koşu satırı
## (kademe / süre / takım seviyesi) + kiriş süsü, öğeler ikon + başlık + alt yazı. "Ayarlar" aynı katmanda ortak
## settings_screen.gd'yi açar (sol sütun kategorilere döner) - eski bej pencere + ayrı Grafik / Tuş Atamaları pencereleri kalktı.
## Sahne (pause_menu.tscn) sadece kök + betik; arayüz kodla kurulur. Yeniden başlatma / ana menü / çok oyunculu davranışı aynı.

const FM := preload("res://scripts/fire_menu_kit.gd")
const DK := preload("res://scripts/menu_dark_kit.gd")
const UiAnim := preload("res://scripts/ui_anim.gd")
const SettingsScreenScript := preload("res://scripts/settings_screen.gd")
const TierDisplayScript := preload("res://scripts/tier_display.gd")
const LobbyUI := preload("res://scripts/menu_lobby_ui.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const PK := preload("res://scripts/phone_menu_kit.gd")
const OverheadBarScript := preload("res://scripts/overhead_bar.gd")

## TELEFON (2026-10-19; kullanıcı seçimi prototip S "A düzeni + B renkleri", tools/proto_20261018/mobil_proto.gd A_duraklat):
## solda büyük başlık + iri öğeler (piksel simge + 64 px yazı, seçili = altın zemin + sol şerit), sağda KOŞU (süre / kademe /
## seviye / öldürme / altın) + TAKIM (portre + PC'nin karakter üstü can/kalkan çubuğu) levhası. Sohbet öğesi YOK (kullanıcı
## 2026-10-18). Ayarlar aynı katmanda telefon ayarlarını açar (settings_screen.gd). MenuFitter bu ekranı artık büyütmez.
const PH_ITEM_W := 900.0
const PH_ITEM_H := 148.0
const PH_ITEMS_TOP := 280.0
const PH_PANEL_W := 864.0


## Sağ levhadaki takım listesi: sen + müttefikler; portre (baş bölgesi 3x) + ad + can (bölmeli) / kalkan çubuğu (PC 3x).
class PhTeam extends Control:
	const ROW := 108.0
	const FACE := 96.0
	const BAR_K := 3.0
	const HP_COL := Color(0.30, 0.82, 0.24) ## overhead_bar.gd ile aynı
	const HP_BG := Color(0.12, 0.04, 0.04)
	const SH_COL := Color(0.35, 0.72, 1.0)
	const SH_BG := Color(0.04, 0.08, 0.14)
	var _faces: Dictionary = {}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		if is_visible_in_tree() and Engine.get_process_frames() % 10 == 0:
			queue_redraw()

	func members() -> Array:
		var out: Array = []
		var me: Node = get_tree().get_first_node_in_group("player")
		if me:
			out.append([me, "Sen", GameManager.selected_char_id])
		for a: Node in get_tree().get_nodes_in_group("remote_players"):
			if is_instance_valid(a) and int(a.get("peer_id")) > 0:
				out.append([a, str(a.get("player_name")), int(a.get("char_id"))])
		return out

	func _face(cid: int) -> Texture2D:
		if not _faces.has(cid):
			var path: String = str(Characters.get_def(cid).get("portrait", ""))
			_faces[cid] = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
		return _faces[cid]

	func _draw() -> void:
		var f: Font = DK.font()
		var y: float = 0.0
		var bx: float = 388.0
		var bw: float = floorf((size.x - bx) / BAR_K)
		for m: Array in members():
			if y + FACE > size.y + 1.0:
				break
			var n: Node = m[0]
			var down: bool = n.get("is_dead") == true or n.get("is_downed") == true
			var r := Rect2(0, y, FACE, FACE)
			draw_rect(r, DK.C_BAD if down else DK.C_LINE_HI)
			draw_rect(r.grow(-3.0), DK.C_INSET)
			var tex: Texture2D = _face(int(m[2]))
			if tex:
				draw_texture_rect_region(tex, Rect2(r.position + Vector2(12, 12), Vector2(72, 72)), Rect2(12, 3, 24, 24),
						Color(0.45, 0.45, 0.5) if down else Color.WHITE)
			draw_string(f, Vector2(FACE + 20.0, y + 46.0), str(m[1]), HORIZONTAL_ALIGNMENT_LEFT, bx - FACE - 32.0, 48,
					DK.C_DIM if down else DK.C_TEXT)
			var mhp: float = maxf(1.0, float(n.get("max_health")))
			var hp: float = 0.0 if down else clampf(float(n.get("health")) / mhp, 0.0, 1.0)
			draw_set_transform(Vector2(bx, y + 30.0), 0.0, Vector2.ONE * BAR_K)
			var hr := Rect2(0, 0, bw, 8)
			OverheadBarScript.draw_pixel_bar(self, hr, hp, HP_COL, HP_BG)
			for off: float in OverheadBarScript._segment_line_offsets(hr.size.x, OverheadBarScript._segment_line_count(mhp)):
				draw_rect(Rect2(off, 0, 1.0, 8.0), Color(0, 0, 0, 0.7))
			var msh: float = float(n.get("item_shield_max")) if n.get("item_shield_max") != null else 0.0
			if msh > 0.0:
				var sh: float = 0.0 if down else clampf(float(n.get("item_shield_hp")) / msh, 0.0, 1.0)
				OverheadBarScript.draw_pixel_bar(self, Rect2(0, 10, bw, 6), sh, SH_COL, SH_BG)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			y += ROW

var _root: Control = null
var _main_view: Control = null
var _items: Array[Button] = []
var _resume_btn: Button = null
var _settings_btn: Button = null
var _restart_btn: Button = null
var _menu_btn: Button = null
var _surrender_btn: Button = null ## TESLİM OL (madde 540): tek oyunculuda iki basışla biter, çok oyunculuda oylama başlatır / evet oyu verir
var _surrender_confirm: bool = false ## ilk basış alındı, ikinci basış teslim eder
var _surrender_refresh_t: float = 0.0
var _settings: Control = null
## Telefon TESLİM OL simgesi: beyaz bayrak (direk + bez).
const G_FLAG := ["##......", "######..", "########", "########", "######..", "#.......", "#.......", "#.......", "#......."]


func _ready() -> void:
	add_to_group(&"gamepad_modal") ## kumandayla menü gezinmesi: açılınca ilk düğmeye odak (bkz. gamepad_ui.gd)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 91 ## modal ekranlar 90+: HUD + sohbet (40) üstünde, yeniden başlatma onayı (98) altında; ölüm/zafer ekranı varken main.gd katmanı 97'ye çıkarır (_raise_pause_menu_over_end_screens)
	var mp: bool = NetworkManager.is_multiplayer_active
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP ## oyun dünyasına tıklama geçmesin
	_root.theme = DK.theme()
	add_child(_root)
	FM.use_phone_palette(MobileUIScript.enabled)
	if MobileUIScript.enabled:
		_build_phone(mp)
	else:
		_build_desktop(mp)
	UISound.connect_all_buttons(self)

	_resume_btn.pressed.connect(_on_resume)
	_restart_btn.pressed.connect(_on_restart)
	_menu_btn.pressed.connect(_on_menu)
	_settings_btn.pressed.connect(_on_settings_pressed)
	_surrender_btn.pressed.connect(_on_surrender)
	_surrender_btn.focus_exited.connect(func() -> void: ## onay yalnız art arda iki basışta
		if _surrender_confirm:
			_surrender_confirm = false
			_refresh_surrender_item())
	_surrender_btn.visible = not GameManager.is_game_over ## oyun bittiyse teslim anlamsız (madde 536: ESC bitiş ekranında da açılır)
	NetworkManager.surrender_vote_changed.connect(_refresh_surrender_item)
	NetworkManager.surrender_vote_ended.connect(func(_p: bool, _y: int, _t: int) -> void: _refresh_surrender_item())
	_refresh_surrender_item()
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
				_set_item_texts(_restart_btn, "YENİDEN BAŞLA", _restart_sub())
				_set_item_selected(_restart_btn, _restart_btn.has_focus())
		)
	UiAnim.cascade(_items[0].get_parent(), 0.04)
	_resume_btn.grab_focus.call_deferred()


func _build_desktop(mp: bool) -> void:
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
	_surrender_btn = FM.item("TESLİM OL", _surrender_texts()[1], FM.tex_icon(load("res://assets/items/urkek_yurek.png")), true)
	_surrender_btn.name = "SurrenderButton"
	for b: Button in [_resume_btn, _settings_btn, _restart_btn, _surrender_btn, _menu_btn]:
		v.add_child(b)
		_items.append(b)
	_main_view.add_child(v)
	v.position = FM.COL_POS
	v.custom_minimum_size.x = FM.COL_W
	var hint := FM.hint([["ESC", "devam et"], ["W/S", "seç"], ["Enter", tr("onayla")]])
	_main_view.add_child(hint)
	hint.position = Vector2(64, 1000)


## ------------------------------------------------------------------ telefon
func _build_phone(mp: bool) -> void:
	_main_view = Control.new()
	_main_view.name = "MainView"
	_main_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_main_view)
	_main_view.add_child(PK.dim(0.5))
	var shade := FM.StepShade.new()
	shade.name = "PhoneShade"
	shade.col = Color(PK.DIMBG, 0.92)
	shade.x0 = 600.0
	shade.step_w = 70.0
	shade.steps = 10
	_main_view.add_child(shade)
	var title := PK.lbl("MENÜ" if mp else "DURAKLATILDI", PK.FS_HERO, DK.C_ACCENT)
	title.name = "Title"
	title.position = Vector2(PK.SIDE, 40)
	title.size = Vector2(1100, 112)
	_main_view.add_child(title)
	if mp:
		var sub := PK.lbl("Oyun sürüyor - karakterin bekliyor", PK.FS_SMALL, DK.C_BAD)
		sub.name = "MpNote"
		sub.position = Vector2(PK.SIDE, 152)
		sub.size = Vector2(1100, 56)
		_main_view.add_child(sub)
	var v := DK.v(8) ## 5 öğe (TESLİM OL, madde 540) 1080'e sığsın: 280 + 5 x 148 + 4 x 8 = 1052
	v.name = "MenuPanel"
	v.position = Vector2(PK.SIDE, PH_ITEMS_TOP)
	_resume_btn = _ph_item("DEVAM ET", PK.G_PLAY, false)
	_resume_btn.name = "ResumeButton"
	_settings_btn = _ph_item("AYARLAR", PK.G_GEAR, false)
	_settings_btn.name = "SettingsButton"
	_restart_btn = _ph_item("YENİDEN BAŞLA", PK.G_REROLL, false)
	_restart_btn.name = "RestartButton"
	_menu_btn = _ph_item("ANA MENÜ", PK.G_HOME, true)
	_menu_btn.name = "MenuButton"
	_surrender_btn = _ph_item("TESLİM OL", G_FLAG, true)
	_surrender_btn.name = "SurrenderButton"
	for b: Button in [_resume_btn, _settings_btn, _restart_btn, _surrender_btn, _menu_btn]:
		v.add_child(b)
		_items.append(b)
	_main_view.add_child(v)
	_main_view.add_child(_ph_run_panel())
	PK.fit(_main_view)


## Öğe: görünmez düğme + seçili zemini (altın %16 + 8 px sol şerit) + 72 px piksel simge + 64 px yazı.
func _ph_item(title: String, pat: Array, danger: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(PH_ITEM_W, PH_ITEM_H)
	b.flat = true
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var sel := Panel.new()
	sel.name = "Sel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(DK.C_ACCENT, 0.16)
	sb.border_width_left = 8
	sb.border_color = DK.C_ACCENT
	sel.add_theme_stylebox_override("panel", sb)
	sel.set_anchors_preset(Control.PRESET_FULL_RECT)
	sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel.visible = false
	b.add_child(sel)
	var g := PK.glyph(pat, DK.C_TEXT, 8)
	g.position = (Vector2(96.0, PH_ITEM_H * 0.5) - g.custom_minimum_size * 0.5).floor()
	g.size = g.custom_minimum_size
	b.add_child(g)
	var l := PK.lbl(title, PK.FS_TITLE, DK.C_BAD if danger else DK.C_TEXT)
	l.position = Vector2(184, 0)
	l.size = Vector2(PH_ITEM_W - 200.0, PH_ITEM_H)
	b.add_child(l)
	b.set_meta("ph_item", {"sel": sel, "glyph": g, "label": l, "danger": danger})
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.focus_entered.connect(func() -> void: _set_item_selected(b, true))
	b.focus_exited.connect(func() -> void: _set_item_selected(b, false))
	return b


## Sağ levha: KOŞU özeti + TAKIM listesi.
func _ph_run_panel() -> PanelContainer:
	var p := PK.panel(0.92, 32.0)
	p.name = "RunPanel"
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.offset_left = -(PK.SIDE + PH_PANEL_W)
	p.offset_right = -PK.SIDE
	p.offset_top = 64.0
	p.offset_bottom = 64.0 + 952.0
	var v := DK.v(0)
	v.add_child(PK.lbl("KOŞU", PK.FS_BODY, DK.C_DIM))
	var t: int = int(GameManager.run_elapsed())
	var rows: Array = [["Süre", "%d:%02d" % [t / 60, t % 60]],
			["Kademe", TierDisplayScript.to_roman(maxi(GameManager.run_max_tier, 1))],
			["Seviye", str(GameManager.team_level)], ["Öldürme", _thousands(GameManager.run_kills)],
			["Altın", _thousands(int(GameManager.gold))]]
	for r: Array in rows:
		var h := DK.h(0)
		h.custom_minimum_size.y = 72
		h.add_child(PK.lbl(str(r[0]), PK.FS_BODY, DK.C_DIM))
		var val := PK.lbl(str(r[1]), PK.FS_BODY, DK.C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		val.name = "Stat" + str(r[0])
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(val)
		v.add_child(h)
	v.add_child(DK.sp(0, 20))
	v.add_child(PK.lbl("TAKIM", PK.FS_BODY, DK.C_DIM))
	v.add_child(DK.sp(0, 8))
	var team := PhTeam.new()
	team.name = "Team"
	team.custom_minimum_size = Vector2(0, 432)
	v.add_child(team)
	p.add_child(v)
	return p


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _set_item_selected(b: Button, on: bool) -> void:
	if b.has_meta("ph_item"):
		var it: Dictionary = b.get_meta("ph_item")
		(it["sel"] as Control).visible = on
		var c: Color = DK.C_ACCENT if on else (DK.C_DIM if b.disabled else (DK.C_BAD if bool(it["danger"]) else DK.C_TEXT))
		(it["glyph"] as PK.PGlyph).set_color(c)
		(it["label"] as Label).add_theme_color_override("font_color", c)
		return
	FM.set_selected(b, on)


func _set_item_texts(b: Button, title: String, sub: String) -> void:
	if b.has_meta("ph_item"):
		((b.get_meta("ph_item") as Dictionary)["label"] as Label).text = title
		return
	FM.set_texts(b, title, sub)


func _restart_sub() -> String:
	return "Herkesin onayıyla baştan" if NetworkManager.is_multiplayer_active else "Aynı karakterle baştan"


## TESLİM OL öğesi -> [başlık, alt yazı, basılabilir mi] (madde 540; durum NetworkManager teslim bloğunda).
func _surrender_texts() -> Array:
	if _surrender_confirm:
		return ["EMİN MİSİN?", "Tekrar bas: koşu burada biter", true]
	if not NetworkManager.is_multiplayer_active:
		return ["TESLİM OL", "Koşu burada biter", true]
	if NetworkManager.surrender_vote_active:
		if NetworkManager.my_surrender_vote() < 0:
			return ["EVET OYU VER", "Teslim oylaması sürüyor", true]
		return ["TESLİM OL", "Oy verdin, sonuç bekleniyor", false]
	var why: String = NetworkManager.surrender_block_reason()
	if why != "":
		return ["TESLİM OL", why, false]
	return ["TESLİM OL", "Herkes evet derse koşu biter", true]


func _refresh_surrender_item() -> void:
	if not is_instance_valid(_surrender_btn) or not _surrender_btn.visible:
		return
	var t: Array = _surrender_texts()
	var key: String = "%s|%s|%s" % t
	if key == str(_surrender_btn.get_meta("surrender_key", "")):
		return ## 0,5 sn'lik yoklamada değişiklik yoksa dokunma (seçili kayma animasyonu yeniden başlamasın)
	_surrender_btn.set_meta("surrender_key", key)
	var can: bool = bool(t[2])
	_surrender_btn.disabled = not can
	if not can and _surrender_btn.has_focus():
		_resume_btn.grab_focus()
	_set_item_texts(_surrender_btn, str(t[0]), str(t[1]))
	_set_item_selected(_surrender_btn, _surrender_btn.has_focus())


## Tek oyunculu (ya da odada yalnız kalınmış): ilk basış onay ister, ikincisi koşuyu bitirir (main.gd _on_surrender_passed menüyü kapatır).
## Çok oyunculu: oylama başlatır (başlatan "evet" sayılır) ya da sürmekte olana evet oyu verir; menü kapanır ki panel görünsün.
func _on_surrender() -> void:
	if GameManager.is_game_over or _surrender_btn.disabled:
		return
	var solo: bool = not NetworkManager.is_multiplayer_active or NetworkManager.lobby_players.size() <= 1
	if solo and not _surrender_confirm:
		_surrender_confirm = true
		_refresh_surrender_item()
		return
	_surrender_confirm = false
	NetworkManager.request_surrender_vote()
	if is_instance_valid(self) and not is_queued_for_deletion() and NetworkManager.is_multiplayer_active and not GameManager.is_game_over:
		_on_resume()


## "KADEME IV  ◆  12:34  ◆  SEVİYE 18" (GameManager.run_max_tier / run_elapsed / team_level)
func _run_line() -> HBoxContainer:
	var h := DK.h(14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: int = int(GameManager.run_elapsed())
	var parts: Array[String] = ["KADEME " + TierDisplayScript.to_roman(maxi(GameManager.run_max_tier, 1)),
			"%d:%02d" % [t / 60, t % 60], Loc.t("SEVİYE %d") % GameManager.team_level]
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
func _process(delta: float) -> void:
	## Teslim bekleme süresi (çok oyunculu) saniye saniye yazılsın.
	_surrender_refresh_t -= delta
	if _surrender_refresh_t <= 0.0:
		_surrender_refresh_t = 0.5
		_refresh_surrender_item()
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
		_set_item_texts(_restart_btn, "ONAY BEKLENİYOR", "Diğer oyuncuların cevabı bekleniyor")
		_set_item_selected(_restart_btn, false)
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
