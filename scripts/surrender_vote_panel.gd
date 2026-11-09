extends CanvasLayer

## TESLİM OYLAMASI PANELİ (madde 540, 2026-11-09; kullanıcı: "oyuna esc de teslim olma seçeneği ekle oylama ile loldeki gibi").
## Yalnız çok oyunculuda (main.gd kurar). Biri ESC > TESLİM OL'a basınca herkeste açılır: başlık, başlatan + kalan süre, oyuncu başına
## oy kutusu (yeşil evet / kırmızı hayır / koyu bekliyor), süre çubuğu, EVET / HAYIR düğmeleri (masaüstünde F1 / F2). Oy verince
## düğmeler yerine "Evet dedin"; oylama geçmezse 2,5 sn "TESLİM GEÇMEDİ" kalır, geçerse oyun bitti ekranı açılır (panel kapanır).
## Veri NetworkManager'ın teslim bloğundan (surrender_vote_*); oyun durmaz, panel kimseyi engellemez (blocking panel DEĞİL).
## Masaüstünde sol üst konsolun (hud.gd CONSOLE_SIZE 228x126 @ 20,20) altında, telefonda üst ortada.

const HudTheme := preload("res://scripts/hud_theme.gd")
const HudTrayKit := preload("res://scripts/hud_tray_kit.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const Loc := preload("res://scripts/localization.gd")

const PANEL_POS := Vector2(20.0, 158.0) ## konsolun alt kenarı 146 + 12
const PANEL_W := 330.0
const FS := 32 ## m5x7 (stil rehberi 16/32/48)
const PIP := 27.0 ## oy kutusu (9 sanat pikseli)
const PIP_GAP := 6.0
const BAR_H := 12.0
const RESULT_HOLD := 2.5
const PHONE_TOP_FRAC := 0.2 ## telefonda ekran yüksekliğinin bu oranında, ortada

var _panel: PanelContainer = null
var _title: Label = null
var _who: Label = null
var _time: Label = null
var _pips: Pips = null
var _bar: TimeBar = null
var _btn_row: HBoxContainer = null
var _yes: Button = null
var _no: Button = null
var _mine: Label = null
var _result_t: float = 0.0 ## > 0: sonuç gösteriliyor, sıfıra inince kapanır


## Oyuncu başına oy kutusu: dış hat + iç (evet yeşil, hayır kırmızı, bekliyor koyu kuyu).
class Pips extends Control:
	var voters: PackedInt32Array = PackedInt32Array()
	var votes: Dictionary = {}

	func set_data(v: PackedInt32Array, d: Dictionary) -> void:
		voters = v
		votes = d
		custom_minimum_size = Vector2(maxf(0.0, voters.size() * (PIP + PIP_GAP) - PIP_GAP), PIP)
		queue_redraw()

	func _draw() -> void:
		var x: float = 0.0
		for pid in voters:
			var r := Rect2(x, 0.0, PIP, PIP)
			draw_rect(r, HudTheme.OUTLINE)
			var c: Color = HudTheme.DOCK_INSET
			if votes.has(pid):
				c = HudTheme.HP_GREEN if bool(votes[pid]) else HudTheme.HP_RED
			draw_rect(r.grow(-3.0), c)
			if votes.has(pid): ## üst ışık şeridi (kabartma, 1 sanat pikseli)
				draw_rect(Rect2(r.position + Vector2(3.0, 3.0), Vector2(PIP - 6.0, 3.0)), Color(1, 1, 1, 0.22))
			x += PIP + PIP_GAP


## Kalan süre çubuğu: koyu kuyu + altın dolgu (sağdan erir).
class TimeBar extends Control:
	var frac: float = 1.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, HudTheme.OUTLINE)
		draw_rect(r.grow(-3.0), HudTheme.DOCK_INSET)
		var w: float = floorf((size.x - 6.0) * clampf(frac, 0.0, 1.0) / 3.0) * 3.0 ## 3 px ızgara
		if w > 0.0:
			draw_rect(Rect2(3.0, 3.0, w, size.y - 6.0), HudTheme.ACCENT)


func _ready() -> void:
	name = "SurrenderVotePanel"
	layer = 46 ## HUD + sohbet (40) üstünde, modal ekranların (90+) altında
	process_mode = Node.PROCESS_MODE_ALWAYS ## ruh hâli duraklatmasında da (madde 438) oy verilebilsin
	_build()
	_panel.visible = false
	NetworkManager.surrender_vote_changed.connect(_refresh)
	NetworkManager.surrender_vote_ended.connect(_on_ended)
	if NetworkManager.surrender_vote_active: ## geç kurulduysa
		_refresh()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP ## tıklama dünyaya geçmesin
	_panel.add_theme_stylebox_override("panel", HudTrayKit.tray(18.0, 15.0))
	_panel.custom_minimum_size.x = PANEL_W
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)

	_title = _lbl("TESLİM OYLAMASI", HudTheme.ACCENT)
	_title.name = "Title"
	v.add_child(_title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	v.add_child(row)
	_who = _lbl("", HudTheme.DIM)
	_who.name = "Who"
	_who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_who.clip_text = true
	row.add_child(_who)
	_time = _lbl("", HudTheme.PRICE)
	_time.name = "Time"
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_time)

	_pips = Pips.new()
	_pips.name = "Pips"
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_pips)

	_bar = TimeBar.new()
	_bar.name = "TimeBar"
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.custom_minimum_size = Vector2(0.0, BAR_H)
	v.add_child(_bar)

	_btn_row = HBoxContainer.new()
	_btn_row.name = "Buttons"
	_btn_row.add_theme_constant_override("separation", 6)
	v.add_child(_btn_row)
	var phone: bool = MobileUIScript.enabled
	_yes = _button("EVET" if phone else "F1  EVET", HudTheme.GOOD)
	_yes.name = "YesButton"
	_yes.pressed.connect(func() -> void: _vote(true))
	_btn_row.add_child(_yes)
	_no = _button("HAYIR" if phone else "F2  HAYIR", HudTheme.BAD)
	_no.name = "NoButton"
	_no.pressed.connect(func() -> void: _vote(false))
	_btn_row.add_child(_no)

	_mine = _lbl("", HudTheme.TEXT)
	_mine.name = "Mine"
	_mine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_mine)
	UISound.connect_all_buttons(_panel)
	_place()
	get_viewport().size_changed.connect(_place)


func _lbl(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FS)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE ## klavye odağını çalmasın (WASD / boşluk oyuna gitsin)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 45.0
	b.add_theme_font_size_override("font_size", FS)
	HudTrayKit.style_plate_button(b)
	for c: String in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, col)
	return b


## Masaüstü: sol üst konsolun altı. Telefon: üst orta, HUD ölçeğinde.
func _place() -> void:
	if not is_instance_valid(_panel):
		return
	_panel.reset_size()
	if MobileUIScript.enabled:
		var k: float = MobileUIScript.HUD_SCALE
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_panel.scale = Vector2(k, k)
		_panel.position = Vector2(roundf((vp.x - _panel.size.x * k) * 0.5), roundf(vp.y * PHONE_TOP_FRAC))
	else:
		_panel.scale = Vector2.ONE
		_panel.position = PANEL_POS


func _vote(yes: bool) -> void:
	if not NetworkManager.surrender_vote_active or NetworkManager.my_surrender_vote() >= 0:
		return
	NetworkManager.submit_surrender_vote(yes)
	_refresh()


func _input(event: InputEvent) -> void:
	if not _panel.visible or _result_t > 0.0 or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY_F1 or k.keycode == KEY_F1:
		_vote(true)
		get_viewport().set_input_as_handled()
	elif k.physical_keycode == KEY_F2 or k.keycode == KEY_F2:
		_vote(false)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	if _result_t > 0.0:
		_result_t -= delta
		if _result_t <= 0.0:
			_panel.visible = false
		return
	if not NetworkManager.surrender_vote_active or GameManager.is_game_over:
		_panel.visible = false
		return
	var left: float = NetworkManager.surrender_time_left()
	_time.text = Loc.t("%d sn") % ceili(left)
	_bar.frac = left / NetworkManager.SURRENDER_VOTE_TIMEOUT
	_bar.queue_redraw()


func _refresh() -> void:
	if not NetworkManager.surrender_vote_active or GameManager.is_game_over:
		return
	_result_t = 0.0
	_title.text = "TESLİM OYLAMASI"
	_title.add_theme_color_override("font_color", HudTheme.ACCENT)
	var main: Node = get_parent()
	var who_name: String = "?"
	if main and main.has_method("_chat_peer_name"):
		who_name = str(main.call("_chat_peer_name", NetworkManager.surrender_vote_initiator))
	_who.text = Loc.t("%s başlattı") % who_name
	var votes: Dictionary = NetworkManager.surrender_votes.duplicate()
	var me: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var mine: int = NetworkManager.my_surrender_vote()
	if mine >= 0 and not votes.has(me):
		votes[me] = mine == 1 ## kendi oyum host yayınından önce de görünsün
	_pips.set_data(NetworkManager.surrender_voters, votes)
	_btn_row.visible = mine < 0
	_mine.visible = mine >= 0
	if mine >= 0:
		_mine.text = "Evet dedin" if mine == 1 else "Hayır dedin"
		_mine.add_theme_color_override("font_color", HudTheme.GOOD if mine == 1 else HudTheme.BAD)
	_time.visible = true
	_bar.visible = true
	_panel.visible = true
	_place()


func _on_ended(passed: bool, yes_count: int, total: int) -> void:
	if passed or total <= 0 or not _panel.visible:
		_result_t = 0.0
		_panel.visible = false
		return
	_title.text = "TESLİM GEÇMEDİ"
	_title.add_theme_color_override("font_color", HudTheme.BAD)
	_who.text = Loc.t("%d/%d evet") % [yes_count, total]
	_time.visible = false
	_bar.visible = false
	_btn_row.visible = false
	_mine.visible = false
	_result_t = RESULT_HOLD
	_place()
