extends Control

## AYARLAR ekranı - "B - Ateş Işığı" (2026-10-17, madde 234; prototip tools/proto_20261017/esc_ayar_proto.gd, madde 229).
## Duraklatma (ESC) menüsü VE ana menü aynı ekranı açar (eskiden iki ayrı kopya panel + ayrı Grafik / Tuş Atamaları pencereleri
## vardı). Kutu yok: solda büyük başlık + kategori sütunu (GENEL / GRAFİK / TUŞLAR / GERİ, seçilide yanan mum), sağda panelsiz
## satırlar (altın bölüm başlığı + ince ayraç), çoklu seçimler konsol tarzı "< değer >" döngüsü. Sağ kenarda arka plan görünür.
## Değerler ve kaydetme TEK yerde: UISound (her set_* anında dosyaya yazar); bu ekran sadece o API'yi çağırır.
## Gezinme: W/S (ok/D-pad) satır, A/D değiştir, Enter/A etkinleştir, Q/E (LB/RB, Tab) bölüm, ESC/B geri. Fare: satır üstü =
## seçili, döngüde sol yarı = önceki / sağ yarı = sonraki, kaydırıcı tıkla-sürükle.

signal closed

const FM := preload("res://scripts/fire_menu_kit.gd")
const DK := preload("res://scripts/menu_dark_kit.gd")
const UiAnim := preload("res://scripts/ui_anim.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const PK := preload("res://scripts/phone_menu_kit.gd")

const COL_X := 660.0
const COL_Y := 150.0
const COL_W := 840.0
const ROW_H := 64.0
const SLIDER_W := 300.0
const VALUE_W := 90.0
const CHOICE_W := SLIDER_W + VALUE_W

enum Cat { GENEL, GRAFIK, TUSLAR, DOKUNMATIK, SES }

## TELEFON (2026-10-19; kullanıcı seçimi prototip S "A düzeni + B renkleri", tools/proto_20261018/mobil_proto.gd A_ayarlar):
## üstte kare geri düğmesi + başlık, ortada tek levhada satırlar (ince çizgiyle ayrılır, seçili = altın zemin + sol şerit), altta
## sekmeler GENEL / GRAFİK / DOKUNMATİK / SES. TUŞLAR telefonda yok; GENEL'den ses ve pencere satırları çıkar (SES sekmesi /
## telefonda pencere yok). Kaydırıcı + "< değer >" seçicisi aynı sınıflar, k = 2 (prototip ölçüsü).
const PH_ROW_H := 120.0
const PH_FS := 48
const PH_AREA_TOP := 160.0
const PH_RESET_W := 420.0
const PH_TABS := [[Cat.GENEL, "GENEL", 300.0], [Cat.GRAFIK, "GRAFİK", 300.0], [Cat.DOKUNMATIK, "DOKUNMATİK", 460.0], [Cat.SES, "SES", 260.0]]

const G_PICTURE := ["#########", "#....##.#", "#....##.#", "#..#....#", "#.###.#.#", "#########"]
const G_KEY := [".#######.", "#.......#", "#.#.#.#.#", "#.......#", "#.#####.#", "#.......#", ".#######."]
const G_BACK := ["...#...", "..#....", "#######", "..#....", "...#..."]
const G_ARROW_L := ["...##", "..###", ".####", "#####", ".####", "..###", "...##"]
const G_ARROW_R := ["##...", "###..", "####.", "#####", "####.", "###..", "##..."]
const G_LOCK := ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]

const GFX_HINT := "Oyun kasıyorsa kaliteyi düşür. Dünya çözünürlüğü sadece oyun dünyasını etkiler, arayüz her zaman net kalır."

const JOY_BUTTON_LABELS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "Sol Çubuk", JOY_BUTTON_RIGHT_STICK: "Sağ Çubuk",
	JOY_BUTTON_BACK: "Back/Select", JOY_BUTTON_START: "Start",
	JOY_BUTTON_DPAD_UP: "D-Pad Yukarı", JOY_BUTTON_DPAD_DOWN: "D-Pad Aşağı",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Sol", JOY_BUTTON_DPAD_RIGHT: "D-Pad Sağ",
}
const JOY_AXIS_LABELS := {
	JOY_AXIS_LEFT_X: "Sol Çubuk Yatay", JOY_AXIS_LEFT_Y: "Sol Çubuk Dikey",
	JOY_AXIS_RIGHT_X: "Sağ Çubuk Yatay", JOY_AXIS_RIGHT_Y: "Sağ Çubuk Dikey",
	JOY_AXIS_TRIGGER_LEFT: "Sol Tetik", JOY_AXIS_TRIGGER_RIGHT: "Sağ Tetik",
}


## Piksel kaydırıcı (Range: value / min_value / max_value / step + value_changed). Tıkla-sürükle değer verir.
class FireSlider extends Range:
	var focused: bool = false
	var k: float = 1.0 ## telefonda 2 (prototip ölçüsü)
	var _drag: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(SLIDER_W, 32)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		value_changed.connect(func(_v: float) -> void: queue_redraw())

	func _frac() -> float:
		return 0.0 if max_value <= min_value else clampf((value - min_value) / (max_value - min_value), 0.0, 1.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_drag = event.pressed
			if event.pressed:
				_set_from_x(event.position.x)
			accept_event()
		elif event is InputEventMouseMotion and _drag:
			_set_from_x(event.position.x)
			accept_event()

	func _set_from_x(x: float) -> void:
		var f: float = clampf((x - 3.0 * k) / maxf(size.x - 6.0 * k, 1.0), 0.0, 1.0)
		value = min_value + f * (max_value - min_value) ## Range step'e yuvarlar

	func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
		if w > 0.0 and h > 0.0:
			draw_rect(Rect2(roundf(x), roundf(y), roundf(w), roundf(h)), c)

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var ty: float = roundf(h * 0.5 - 7.0 * k)
		_r(0, ty, w, 14 * k, FM.C_LINE)
		_r(3 * k, ty + 3 * k, w - 6 * k, 8 * k, FM.C_DARK)
		var fx: float = roundf(3.0 * k + (w - 6.0 * k) * _frac())
		_r(3 * k, ty + 3 * k, fx - 3.0 * k, 8 * k, FM.C_GOLD)
		_r(3 * k, ty + 3 * k, fx - 3.0 * k, 3 * k, FM.C_GOLD.lightened(0.3))
		for i in range(1, 4):
			var tx: float = roundf(3.0 * k + (w - 6.0 * k) * float(i) / 4.0)
			if tx > fx + 12.0 * k:
				_r(tx - 1.0 * k, ty + 3.0 * k, 3 * k, 8 * k, FM.C_LINE)
		var kw := 18.0 * k
		var kx: float = clampf(fx - kw * 0.5, 0.0, w - kw)
		if focused and k <= 1.0: ## telefonda seçili satırın zemini yeter (halka satırın dışına taşardı)
			for rc: Rect2 in [Rect2(kx - 2, -3, kw + 4, 3), Rect2(kx - 2, h, kw + 4, 3), Rect2(kx - 5, 0, 3, h), Rect2(kx + kw + 2, 0, 3, h)]:
				_r(rc.position.x, rc.position.y, rc.size.x, rc.size.y, FM.C_GOLD)
		_r(kx, 2 * k, kw, h - 4 * k, FM.C_KNOB_DK)
		_r(kx + 3 * k, 5 * k, kw - 6 * k, h - 10 * k, FM.C_CREAM)
		_r(kx + 3 * k, 5 * k, kw - 6 * k, 3 * k, FM.C_CREAM.lightened(0.35))


## "< değer >" döngüsü (aç/kapa dahil tüm çoklu seçimler). Fare: sol yarı önceki, sağ yarı sonraki. locked: kilit simgesi, değişmez.
class Carousel extends Control:
	signal changed(index: int)
	var options: Array = []
	var index: int = 0
	var override_text: String = "" ## ör. grafik "Özel" - adım atılınca normale döner
	var locked: bool = false
	var focused: bool = false
	var well: bool = false ## telefon: koyu kuyu içinde, iri ok + 48 px yazı (dokunma alanı belli olsun)

	func _init() -> void:
		custom_minimum_size = Vector2(CHOICE_W, 44)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func set_state(i: int, override: String = "", lock: bool = false) -> void:
		index = i
		override_text = override
		locked = lock
		mouse_default_cursor_shape = Control.CURSOR_ARROW if lock else Control.CURSOR_POINTING_HAND
		queue_redraw()

	func step(d: int) -> bool:
		if locked or options.is_empty():
			return false
		index = wrapi(index + d, 0, options.size())
		override_text = ""
		queue_redraw()
		changed.emit(index)
		return true

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if step(-1 if event.position.x < size.x * 0.5 else 1):
				UISound.play_click()
			accept_event()

	func _pat(rows_: Array, pos: Vector2, s: float, c: Color) -> void:
		for j in rows_.size():
			var row: String = rows_[j]
			for i in row.length():
				if row[i] == "#":
					draw_rect(Rect2(pos.x + i * s, pos.y + j * s, s, s), c)

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var gp: float = 6.0 if well else 2.0
		var cy: float = roundf(h * 0.5 - 3.5 * gp)
		if well:
			draw_rect(Rect2(Vector2.ZERO, size), FM.C_LINE)
			draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(FM.C_DARK, 0.92))
		var ax: float = roundf(44.0 - 2.5 * gp) if well else 4.0
		var ac: Color = FM.C_SUB if locked else FM.C_GOLD
		if locked:
			_pat(G_LOCK, Vector2(ax, cy), gp, ac)
		else:
			_pat(G_ARROW_L, Vector2(ax, cy), gp, ac)
			_pat(G_ARROW_R, Vector2(w - ax - 5.0 * gp, cy), gp, ac)
		var t: String = override_text
		if t == "" and index >= 0 and index < options.size():
			t = str(options[index])
		var tc: Color = FM.C_SUB if locked else (FM.C_GOLD if focused else FM.C_CREAM)
		var f: Font = DK.font()
		var fs: int = PH_FS if well else DK.FS_BODY
		var mx: float = 88.0 if well else 22.0
		var by: float = roundf((h - (f.get_ascent(fs) + f.get_descent(fs))) * 0.5 + f.get_ascent(fs))
		draw_string(f, Vector2(mx, by), t, HORIZONTAL_ALIGNMENT_CENTER, w - 2.0 * mx, fs, tc)


## Tuş satırının iki hücresi (klavye / kumanda). Tıklanan hücre dinlemeye geçer.
class KeyCells extends Control:
	signal cell_pressed(cell: int)
	const CELL_W := 190.0
	const GAP := 12.0
	var texts: Array = ["", ""]
	var sel: int = 0
	var listening: int = -1
	var focused: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(CELL_W * 2.0 + GAP, 44)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var c: int = 0 if event.position.x < CELL_W + GAP * 0.5 else 1
			cell_pressed.emit(c)
			accept_event()

	func _draw() -> void:
		var f: Font = DK.font()
		var fs: int = DK.FS_LABEL
		for c in 2:
			var x: float = c * (CELL_W + GAP)
			var on: bool = focused and sel == c
			var lis: bool = listening == c
			var bd: Color = FM.C_GOLD if (on or lis) else Color("#6a5440")
			var fill: Color = Color(FM.C_GOLD, 0.16) if lis else Color(0.08, 0.05, 0.03, 0.85)
			draw_rect(Rect2(x, 0, CELL_W, size.y), bd)
			draw_rect(Rect2(x + 2, 2, CELL_W - 4, size.y - 4), fill)
			var t: String = ("Bir tuşa bas..." if c == 0 else "Kumandaya bas...") if lis else str(texts[c])
			var tc: Color = FM.C_GOLD if (on or lis) else (FM.C_CREAM if c == 0 else FM.C_TAG)
			var by: float = roundf((size.y - (f.get_ascent(fs) + f.get_descent(fs))) * 0.5 + f.get_ascent(fs))
			draw_string(f, Vector2(x + 6, by), t, HORIZONTAL_ALIGNMENT_CENTER, CELL_W - 12, fs, tc)


var back_sub: String = "Geri dön"
var band_alpha: float = 0.8

var _cat: int = Cat.GENEL
var _cat_btns: Array[Button] = []
## Görünen kategoriler (sekme / Q-E sırası); _cat_btns aynı sırada.
var _cats: Array = [Cat.GENEL, Cat.GRAFIK, Cat.TUSLAR]
var _phone: bool = false
var _col: VBoxContainer = null
var _hint_holder: Control = null
var _rows: Array[Dictionary] = []
var _focus: int = 0
var _listen_action: String = ""
var _listen_cell: int = -1
var _listen_row: Dictionary = {}


func _init(sub_for_back: String = "Geri dön", shade_alpha: float = 0.8) -> void:
	back_sub = sub_for_back
	band_alpha = shade_alpha


func _ready() -> void:
	name = "SettingsScreen"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) ## ağaçtayken set_anchors_preset eski (0) boyutu korurdu
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = DK.theme()
	_phone = MobileUIScript.enabled
	FM.use_phone_palette(_phone)
	if _phone:
		_build_phone_shell()
		_set_category(Cat.GENEL, false)
		return
	var band := FM.StepShade.new()
	band.col = Color(0.05, 0.035, 0.025, band_alpha)
	add_child(band)
	var logo := FM.title_block("AYARLAR", FM.lbl("Değişiklikler anında kaydedilir", DK.FS_BODY, FM.C_TAG))
	add_child(logo)
	logo.position = FM.TITLE_POS
	var v := DK.v(0)
	v.name = "CategoryPanel"
	var specs: Array = [
		["GENEL", "Ses, ekran, arayüz", FM.tex_icon(load("res://assets/items/tornavida.png"))],
		["GRAFİK", "Kalite, gölge, zemin, FPS", DK.glyph(G_PICTURE, FM.C_CREAM, 5)],
		["TUŞLAR", "Klavye ve kumanda", DK.glyph(G_KEY, FM.C_CREAM, 5)],
	]
	for i in specs.size():
		var sp: Array = specs[i]
		var b := FM.item(sp[0], sp[1], sp[2], false, false)
		b.focus_mode = Control.FOCUS_NONE
		var ci: int = i
		b.pressed.connect(func() -> void: _set_category(ci, true))
		b.mouse_entered.connect(func() -> void: FM.set_selected(b, true))
		b.mouse_exited.connect(func() -> void: FM.set_selected(b, ci == _cat))
		v.add_child(b)
		_cat_btns.append(b)
	v.add_child(DK.sp(0, 24))
	var back := FM.item("GERİ", back_sub, DK.glyph(G_BACK, FM.C_SUB, 5), false, false)
	back.name = "BackButton"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(close)
	back.mouse_entered.connect(func() -> void: FM.set_selected(back, true))
	back.mouse_exited.connect(func() -> void: FM.set_selected(back, false))
	v.add_child(back)
	add_child(v)
	v.position = FM.COL_POS
	v.custom_minimum_size.x = FM.COL_W
	_col = DK.v(0)
	_col.name = "Rows"
	_col.custom_minimum_size.x = COL_W
	add_child(_col)
	_col.position = Vector2(COL_X, COL_Y)
	_hint_holder = Control.new()
	_hint_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_holder)
	_hint_holder.position = Vector2(64, 952) ## sol altta iki satır: sağ alt oyuncu panelinin (HUD) üstüne binmesin
	_set_category(Cat.GENEL, false)
	UiAnim.cascade(v, 0.04)


## ------------------------------------------------------------------ kategoriler
func _set_category(c: int, with_sound: bool) -> void:
	_cancel_listen()
	_cat = c if _cats.has(c) else int(_cats[0])
	for i in _cat_btns.size():
		if _phone:
			PK.set_kind(_cat_btns[i], "selected" if _cats[i] == _cat else "secondary")
		else:
			FM.set_selected(_cat_btns[i], _cats[i] == _cat)
	for ch in _col.get_children():
		_col.remove_child(ch)
		ch.queue_free()
	_rows.clear()
	match _cat:
		Cat.GENEL:
			_build_genel()
		Cat.GRAFIK:
			_build_grafik()
		Cat.TUSLAR:
			_build_tuslar()
		Cat.DOKUNMATIK:
			_build_dokunmatik()
		Cat.SES:
			_build_ses()
	_focus = 0
	_update_focus()
	if _hint_holder:
		for ch in _hint_holder.get_children():
			ch.queue_free()
		var hv := DK.v(10)
		hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _cat == Cat.TUSLAR:
			hv.add_child(FM.hint([["W/S", "seç"], ["A/D", "klavye / kumanda"], ["Enter", "ata"]]))
		else:
			hv.add_child(FM.hint([["W/S", "seç"], ["A/D", "değiştir"]]))
		hv.add_child(FM.hint([["Q/E", "bölüm"], ["ESC", "geri"]]))
		_hint_holder.add_child(hv)
	UiAnim.cascade(_col, 0.025)
	if with_sound:
		UISound.play_click()


func _cycle_category(d: int) -> void:
	var i: int = maxi(_cats.find(_cat), 0)
	_set_category(int(_cats[wrapi(i + d, 0, _cats.size())]), true)


## Telefon kabuğu: karartma + üst/alt sönümleme, geri + başlık, satır levhası (kaydırılabilir), alt sekmeler. Konumlar çapalı -
## tuval genişliği telefona göre değişir.
func _build_phone_shell() -> void:
	_cats = [Cat.GENEL, Cat.GRAFIK, Cat.DOKUNMATIK, Cat.SES]
	add_child(PK.dim(0.72))
	add_child(PK.fade(SIDE_TOP, 200.0, 0.75))
	add_child(PK.fade(SIDE_BOTTOM, 230.0, 0.85))
	PK.header(self, "AYARLAR", "", close)
	var area := PK.panel(0.9, 0.0)
	area.name = "RowsPanel"
	area.mouse_filter = Control.MOUSE_FILTER_PASS
	area.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.offset_left = PK.SIDE
	area.offset_right = -PK.SIDE
	area.offset_top = PH_AREA_TOP
	area.offset_bottom = -(PK.BOTTOM + PK.BTN_H + 16.0)
	var sc := ScrollContainer.new()
	sc.name = "Scroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	area.add_child(sc)
	_col = DK.v(0)
	_col.name = "Rows"
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_col)
	add_child(area)
	## Alt sıra levhanın iki kenarına hizalı: sekmeler soldan VARSAYILAN'a kadar (prototip genişlik oranlarıyla) yayılır, VARSAYILAN
	## sağ kenarda - ortada boşluk kalıp sıra sola yığılmasın.
	var tabs := DK.h(20)
	tabs.name = "CategoryTabs"
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tabs.offset_left = PK.SIDE
	tabs.offset_right = -(PK.SIDE + PH_RESET_W + 24.0)
	tabs.offset_top = -(PK.BOTTOM + PK.BTN_H)
	tabs.offset_bottom = -PK.BOTTOM
	for t: Array in PH_TABS:
		var bt := PK.button(str(t[1]), "secondary", PK.FS_BODY, [], float(t[2]))
		bt.name = "Tab" + str(t[1])
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.size_flags_stretch_ratio = float(t[2])
		var cat: int = int(t[0])
		bt.pressed.connect(func() -> void:
			if cat != _cat:
				_set_category(cat, true))
		tabs.add_child(bt)
		_cat_btns.append(bt)
	add_child(tabs)
	var reset := PK.button("VARSAYILAN", "ghost", PK.FS_BODY, [], PH_RESET_W)
	reset.name = "ResetButton"
	reset.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	reset.offset_left = -(PK.SIDE + PH_RESET_W)
	reset.offset_right = -PK.SIDE
	reset.offset_top = -(PK.BOTTOM + PK.BTN_H)
	reset.offset_bottom = -PK.BOTTOM
	reset.pressed.connect(_reset_category)
	add_child(reset)
	PK.fit(self)


## Telefon VARSAYILAN: açık sekmenin ayarlarını ilk kurulum değerlerine döndürür (UISound değişkenlerinin başlangıç değerleri).
func _reset_category() -> void:
	match _cat:
		Cat.GENEL:
			UISound.set_camera_shake_percent(100.0)
			UISound.set_ui_anim_enabled(true)
			UISound.set_show_fps(false)
			UISound.set_auto_pick_cards(false)
		Cat.GRAFIK:
			UISound.set_gfx_preset(UISound.GfxPreset.HIGH)
			UISound.set_fps_limit(UISound._default_fps_limit())
		Cat.DOKUNMATIK:
			UISound.set_touch_joystick_fixed(false)
			UISound.set_touch_button_scale_percent(100.0)
			UISound.set_ui_opacity_percent(100.0)
			UISound.set_touch_vibration(true)
		Cat.SES:
			UISound.set_master_volume_percent(100.0)
			UISound.set_music_volume_percent(100.0)
	_sync_all()
	UISound.play_click()


func _section(title: String) -> void:
	if _phone: ## telefonda tek levha, bölüm başlığı yok (sekmeler ayırır)
		return
	var h := DK.h(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.custom_minimum_size.y = 48
	h.add_child(DK.glyph(FM.G_DIAMOND, FM.C_GOLD, 3))
	var t := DK.lbl(title, DK.FS_BODY, FM.C_GOLD)
	t.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.03, 1))
	t.add_theme_constant_override("outline_size", 6)
	h.add_child(t)
	var ln := ColorRect.new()
	ln.color = Color(FM.C_GOLD_DIM, 0.28)
	ln.custom_minimum_size = Vector2(0, 2)
	ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ln.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ln)
	if _col.get_child_count() > 0:
		_col.add_child(DK.sp(0, 18))
	_col.add_child(h)


## Satır: yazı solda, denetim sağda; seçiliyken altın zemin + sol altın şerit. r: {id, label, ctrl, step(dir), activate(joy), sync}
func _add_row(r: Dictionary, extra: Control = null) -> void:
	var pc := PanelContainer.new()
	pc.name = "Row_" + str(r["id"])
	pc.custom_minimum_size.y = PH_ROW_H if _phone else ROW_H
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := DK.h(24 if _phone else 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lab := DK.lbl(r["label"], PH_FS if _phone else DK.FS_BODY, FM.C_CREAM)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _phone: ## prototip: yazı satırın ~%48'i, denetim kalanı
		lab.size_flags_stretch_ratio = 0.92
		(r["ctrl"] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lab)
	if extra:
		h.add_child(extra)
	h.add_child(r["ctrl"])
	pc.add_child(h)
	var wrap := DK.v(0)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(pc)
	var ln := ColorRect.new()
	ln.color = Color(FM.C_GOLD_DIM, 0.16)
	ln.custom_minimum_size = Vector2(0, 2)
	ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _phone:
		var lm := MarginContainer.new()
		lm.add_theme_constant_override("margin_left", 28)
		lm.add_theme_constant_override("margin_right", 28)
		lm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lm.add_child(ln)
		wrap.add_child(lm)
	else:
		wrap.add_child(ln)
	_col.add_child(wrap)
	r["panel"] = pc
	r["lab"] = lab
	r["i"] = _rows.size()
	_rows.append(r)
	(r["sync"] as Callable).call()


## stp: klavye/kumanda adımı; snap: kaydırıcının yuvarlama adımı (fare) - ses eskiden 1'lik adımla kaydediliyordu, yuvarlanmasın.
func _slider_row(id: String, label: String, lo: float, hi: float, stp: float, getter: Callable, setter: Callable, fmt: Callable,
		snap: float = -1.0) -> void:
	var box := DK.h(20 if _phone else 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := FireSlider.new()
	s.name = id.capitalize().replace(" ", "") + "Slider"
	s.min_value = lo
	s.max_value = hi
	s.step = snap if snap > 0.0 else stp
	box.add_child(s)
	var vl := DK.lbl("", PH_FS if _phone else DK.FS_BODY, FM.C_CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	vl.name = id.capitalize().replace(" ", "") + "Value"
	vl.custom_minimum_size.x = VALUE_W - 14.0
	box.add_child(vl)
	if _phone: ## prototip: değer solda, kaydırıcı kalan genişlikte
		s.k = 2.0
		s.custom_minimum_size = Vector2(240, 64)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vl.custom_minimum_size.x = 150.0
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.move_child(vl, 0)
	var r := {"id": id, "label": label, "ctrl": box, "slider": s, "value_label": vl}
	r["sync"] = func() -> void:
		s.set_value_no_signal(float(getter.call()))
		s.queue_redraw()
		vl.text = fmt.call(s.value)
	r["step"] = func(d: int) -> bool:
		var before: float = s.value
		s.value = s.value + d * stp
		return not is_equal_approx(before, s.value)
	r["activate"] = func(_joy: bool) -> void: pass
	s.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		vl.text = fmt.call(v)
		_focus_row(r))
	_add_row(r)


## options: gösterilecek yazılar; getter -> mevcut dizin; setter(dizin). lock_fn -> kilitli mi; override_fn -> yerine yazı ("" = yok).
func _choice_row(id: String, label: String, options: Array, getter: Callable, setter: Callable,
		lock_fn: Callable = Callable(), override_fn: Callable = Callable(), lock_hint: String = "") -> void:
	var c := Carousel.new()
	c.name = id.capitalize().replace(" ", "") + "Choice"
	c.options = options
	if _phone:
		c.well = true
		c.custom_minimum_size = Vector2(300, 88)
	var hint_lbl: Label = null
	if lock_hint != "":
		hint_lbl = DK.lbl(lock_hint, DK.FS_LABEL, FM.C_SUB)
	var r := {"id": id, "label": label, "ctrl": c, "choice": c}
	r["sync"] = func() -> void:
		var lk: bool = lock_fn.is_valid() and bool(lock_fn.call())
		c.set_state(int(getter.call()), str(override_fn.call()) if override_fn.is_valid() else "", lk)
		if hint_lbl:
			hint_lbl.visible = lk
	r["step"] = func(d: int) -> bool: return c.step(d)
	r["activate"] = func(_joy: bool) -> void:
		if c.step(1):
			UISound.play_click()
	c.changed.connect(func(i: int) -> void:
		setter.call(i)
		_sync_all()
		_focus_row(r))
	_add_row(r, hint_lbl)


func _toggle_row(id: String, label: String, getter: Callable, setter: Callable) -> void:
	_choice_row(id, label, ["Kapalı", "Açık"], func() -> int: return 1 if bool(getter.call()) else 0,
			func(i: int) -> void: setter.call(i == 1))


func _pct(v: float) -> String:
	return "%%%d" % roundi(v)


func _build_genel() -> void:
	if _phone: ## telefonda pencere/çözünürlük yok, ses kendi sekmesinde, opaklık DOKUNMATİK'te
		_slider_row("shake", "Ekran Sarsıntısı", 0.0, 100.0, 10.0, func() -> float: return UISound.camera_shake_percent,
				func(v: float) -> void: UISound.set_camera_shake_percent(v),
				func(v: float) -> String: return "Kapalı" if roundi(v) == 0 else _pct(v))
		_toggle_row("ui_anim", "Arayüz Animasyonları", func() -> bool: return UISound.ui_anim_enabled,
				func(on: bool) -> void: UISound.set_ui_anim_enabled(on))
		_toggle_row("fps", "FPS Göstergesi", func() -> bool: return UISound.show_fps, func(on: bool) -> void: UISound.set_show_fps(on))
		_toggle_row("auto_pick", "Otomatik Kart Seçimi", func() -> bool: return UISound.auto_pick_cards,
				func(on: bool) -> void: UISound.set_auto_pick_cards(on))
		return
	_section("SES")
	_slider_row("volume", "Oyun Sesi", 0.0, 100.0, 5.0, func() -> float: return UISound.master_volume_percent,
			func(v: float) -> void: UISound.set_master_volume_percent(v), _pct, 1.0)
	_slider_row("music", "Müzik Sesi", 0.0, 100.0, 5.0, func() -> float: return UISound.music_volume_percent,
			func(v: float) -> void: UISound.set_music_volume_percent(v), _pct, 1.0)
	_section("EKRAN")
	_toggle_row("fullscreen", "Tam Ekran", func() -> bool: return UISound.is_fullscreen,
			func(on: bool) -> void: UISound.set_fullscreen(on))
	_choice_row("resolution", "Çözünürlük", Array(UISound.get_resolution_labels()), func() -> int: return UISound.resolution_index,
			func(i: int) -> void: UISound.set_resolution(i), func() -> bool: return UISound.is_fullscreen, Callable(), "tam ekranda kilitli")
	_toggle_row("fps", "FPS Göstergesi", func() -> bool: return UISound.show_fps, func(on: bool) -> void: UISound.set_show_fps(on))
	_section("ARAYÜZ")
	_slider_row("ui_opacity", "Arayüz Opaklığı", UISound.UI_OPACITY_MIN_PERCENT, 100.0, 5.0,
			func() -> float: return UISound.ui_opacity_percent, func(v: float) -> void: UISound.set_ui_opacity_percent(v), _pct)
	_slider_row("shake", "Ekran Sarsıntısı", 0.0, 100.0, 10.0, func() -> float: return UISound.camera_shake_percent,
			func(v: float) -> void: UISound.set_camera_shake_percent(v),
			func(v: float) -> String: return "Kapalı" if roundi(v) == 0 else _pct(v))
	_toggle_row("ui_anim", "Arayüz Animasyonları", func() -> bool: return UISound.ui_anim_enabled,
			func(on: bool) -> void: UISound.set_ui_anim_enabled(on))
	## Level atlama / sandık kartını kendiliğinden seçer (afk oyuncu arkadaşlarını bekletmesin; auto_pick.gd).
	_section("OYUN")
	_toggle_row("auto_pick", "Otomatik Kart Seçimi", func() -> bool: return UISound.auto_pick_cards,
			func(on: bool) -> void: UISound.set_auto_pick_cards(on))


func _build_grafik() -> void:
	_section("GRAFİK")
	var names: Array = []
	for i in 3:
		names.append(UISound.GFX_PRESET_NAMES[i])
	_choice_row("preset", "Kalite", names, func() -> int: return mini(UISound.gfx_preset, 2),
			func(i: int) -> void: UISound.set_gfx_preset(i), Callable(),
			func() -> String: return UISound.GFX_PRESET_NAMES[UISound.GfxPreset.CUSTOM] if UISound.gfx_preset == UISound.GfxPreset.CUSTOM else "")
	_toggle_row("sun", "Güneş Işığı / Bulut Gölgesi", func() -> bool: return UISound.gfx_sun_clouds,
			func(on: bool) -> void: UISound.set_gfx_option("sun_clouds", on))
	_toggle_row("ground", "Zemin Ayrıntısı", func() -> bool: return UISound.gfx_ground_detail,
			func(on: bool) -> void: UISound.set_gfx_option("ground_detail", on))
	_toggle_row("wind_fx", "Rüzgar Efekti", func() -> bool: return UISound.gfx_wind_fx,
			func(on: bool) -> void: UISound.set_gfx_option("wind_fx", on))
	var scales: Array = []
	for s: float in UISound.RENDER_SCALES:
		scales.append(_pct(s * 100.0))
	var scale_now := func() -> int:
		for i in UISound.RENDER_SCALES.size():
			if is_equal_approx(UISound.RENDER_SCALES[i], UISound.gfx_render_scale):
				return i
		return 0
	_choice_row("render_scale", "Dünya Çözünürlüğü", scales, scale_now,
			func(i: int) -> void: UISound.set_gfx_option("render_scale", UISound.RENDER_SCALES[i]))
	var fps_names: Array = []
	for f: int in UISound.FPS_LIMITS:
		fps_names.append(str(f) if f > 0 else "Sınırsız")
	_choice_row("fps_limit", "FPS Sınırı", fps_names, func() -> int: return maxi(UISound.FPS_LIMITS.find(UISound.fps_limit), 0),
			func(i: int) -> void: UISound.set_fps_limit(UISound.FPS_LIMITS[i]))
	_col.add_child(DK.sp(0, 18))
	var hint := DK.wrap(GFX_HINT, 32 if _phone else DK.FS_LABEL, FM.C_TAG, 1600.0 if _phone else COL_W - 40.0)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 32 if _phone else 20)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(hint)
	_col.add_child(m)


## Telefon: dokunmatik kontroller (UISound touch_* ayarları; joystick touch_controls.gd, düğme boyutu hud.gd) + arayüz opaklığı.
func _build_dokunmatik() -> void:
	_choice_row("joystick", "Joystick", ["Yüzen", "Sabit"], func() -> int: return 1 if UISound.touch_joystick_fixed else 0,
			func(i: int) -> void: UISound.set_touch_joystick_fixed(i == 1))
	_slider_row("button_size", "Düğme Boyutu", UISound.TOUCH_BUTTON_SCALE_MIN, UISound.TOUCH_BUTTON_SCALE_MAX, 10.0,
			func() -> float: return UISound.touch_button_scale_percent,
			func(v: float) -> void: UISound.set_touch_button_scale_percent(v), _pct, 5.0)
	_slider_row("ui_opacity", "Arayüz Opaklığı", UISound.UI_OPACITY_MIN_PERCENT, 100.0, 5.0,
			func() -> float: return UISound.ui_opacity_percent, func(v: float) -> void: UISound.set_ui_opacity_percent(v), _pct)
	_toggle_row("vibration", "Titreşim", func() -> bool: return UISound.touch_vibration,
			func(on: bool) -> void: UISound.set_touch_vibration(on))


func _build_ses() -> void:
	_slider_row("volume", "Oyun Sesi", 0.0, 100.0, 5.0, func() -> float: return UISound.master_volume_percent,
			func(v: float) -> void: UISound.set_master_volume_percent(v), _pct, 1.0)
	_slider_row("music", "Müzik Sesi", 0.0, 100.0, 5.0, func() -> float: return UISound.music_volume_percent,
			func(v: float) -> void: UISound.set_music_volume_percent(v), _pct, 1.0)


func _build_tuslar() -> void:
	_section("TUŞLAR")
	var head := DK.h(12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(DK.sp(0, 0, true))
	for t: String in ["KLAVYE", "KUMANDA"]:
		var l := DK.lbl(t, DK.FS_LABEL, FM.C_TAG, HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size.x = KeyCells.CELL_W
		head.add_child(l)
	head.add_child(DK.sp(18))
	_col.add_child(head)
	for entry: Dictionary in GameManager.REBINDABLE_ACTIONS:
		var action: String = entry["action"]
		var kc := KeyCells.new()
		var r := {"id": "key_" + action, "label": entry["label"], "ctrl": kc, "action": action}
		r["sync"] = func() -> void:
			kc.texts = [OS.get_keycode_string(GameManager.get_keybind_keycode(action)),
					joypad_label(GameManager.get_keybind_joypad_descriptor(action))]
			kc.queue_redraw()
		r["step"] = func(d: int) -> bool:
			var before: int = kc.sel
			kc.sel = clampi(kc.sel + d, 0, 1)
			kc.queue_redraw()
			return before != kc.sel
		r["activate"] = func(joy: bool) -> void: _start_listen(r, 1 if joy else kc.sel)
		kc.cell_pressed.connect(func(cell: int) -> void:
			_focus_row(r)
			kc.sel = cell
			_start_listen(r, cell))
		_add_row(r)
		(r["panel"] as PanelContainer).custom_minimum_size.y = 56.0


static func joypad_label(d: Dictionary) -> String:
	if d.is_empty():
		return "Atanmamış"
	if int(d.get("kind", -1)) == GameManager.JoypadKind.BUTTON:
		return JOY_BUTTON_LABELS.get(int(d.get("button", -1)), "Buton %d" % int(d.get("button", -1)))
	var axis_name: String = JOY_AXIS_LABELS.get(int(d.get("axis", -1)), "Eksen %d" % int(d.get("axis", -1)))
	return "%s %s" % [axis_name, "+" if float(d.get("sign", 1.0)) > 0.0 else "-"]


## ------------------------------------------------------------------ seçili satır
func _sync_all() -> void:
	for r: Dictionary in _rows:
		(r["sync"] as Callable).call()


func _focus_row(r: Dictionary) -> void:
	var i: int = int(r.get("i", -1))
	if i >= 0 and i != _focus:
		_focus = i
		_update_focus()


func _update_focus() -> void:
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var on: bool = i == _focus
		var s := StyleBoxFlat.new()
		s.bg_color = Color(FM.C_GOLD, 0.09) if on else Color(0, 0, 0, 0)
		if on:
			s.border_width_left = 6
			s.border_color = FM.C_GOLD
		s.content_margin_left = 32 if _phone else 18
		s.content_margin_right = 24 if _phone else 18
		s.content_margin_top = 4
		s.content_margin_bottom = 4
		(r["panel"] as PanelContainer).add_theme_stylebox_override("panel", s)
		var lab: Label = r["lab"]
		lab.add_theme_color_override("font_color", FM.C_GOLD if on else FM.C_CREAM)
		var ctrl: Control = r["ctrl"]
		if r.has("slider"):
			(r["slider"] as FireSlider).focused = on
			(r["slider"] as FireSlider).queue_redraw()
			(r["value_label"] as Label).add_theme_color_override("font_color", FM.C_GOLD if on else FM.C_CREAM)
		elif ctrl is Carousel:
			(ctrl as Carousel).focused = on
			ctrl.queue_redraw()
		elif ctrl is KeyCells:
			(ctrl as KeyCells).focused = on
			ctrl.queue_redraw()


func _move_focus(d: int) -> void:
	if _rows.is_empty():
		return
	var n: int = clampi(_focus + d, 0, _rows.size() - 1)
	if n != _focus:
		_focus = n
		_update_focus()


## ------------------------------------------------------------------ tuş atama dinleme (eski keybind_menu.gd mantığı)
func _start_listen(r: Dictionary, cell: int) -> void:
	_cancel_listen()
	_listen_action = r["action"]
	_listen_cell = cell
	_listen_row = r
	(r["ctrl"] as KeyCells).listening = cell
	(r["ctrl"] as KeyCells).queue_redraw()
	UISound.play_click()


func _cancel_listen() -> void:
	if _listen_row.has("ctrl"):
		var kc: KeyCells = _listen_row["ctrl"]
		if is_instance_valid(kc):
			kc.listening = -1
			kc.queue_redraw()
	_listen_action = ""
	_listen_cell = -1
	_listen_row = {}


func _finish_listen() -> void:
	var r: Dictionary = _listen_row
	_cancel_listen()
	if r.has("sync"):
		(r["sync"] as Callable).call()
	UISound.play_click()


func _handle_listen(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel_listen()
		return true
	if _listen_cell == 0:
		if event is InputEventKey and event.pressed and not event.echo:
			GameManager.set_keybind_override(_listen_action, event.physical_keycode)
			_finish_listen()
			return true
	else:
		var d: Dictionary = {}
		if event is InputEventJoypadButton and event.pressed:
			d = {"kind": GameManager.JoypadKind.BUTTON, "button": event.button_index}
		elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
			d = {"kind": GameManager.JoypadKind.AXIS, "axis": event.axis, "sign": signf(event.axis_value)}
		if not d.is_empty():
			GameManager.set_keybind_joypad_override(_listen_action, d)
			_finish_listen()
			return true
	return event is InputEventKey or event is InputEventJoypadButton ## dinlerken başka hiçbir şey tetiklenmesin


## ------------------------------------------------------------------ girdi
## Çubuk (eksen) olayları sürekli akar: eylem başına bir kez, eşiği geçince (mandal) - yoksa çubuk tutulunca satırlar uçardı.
var _axis_latch: Dictionary = {}


func _act(event: InputEvent, names: Array) -> bool:
	for n: String in names:
		if not InputMap.has_action(n) or not event.is_action(n):
			continue
		if event is InputEventJoypadMotion:
			var p: bool = event.is_action_pressed(n)
			var was: bool = bool(_axis_latch.get(n, false))
			_axis_latch[n] = p
			if p and not was:
				return true
			continue
		if event.is_action_pressed(n, true):
			return true
	return false


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _listen_action != "":
		if _handle_listen(event):
			GameManager.mark_ui_cancel_consumed()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		for i in _rows.size():
			var pc: Control = _rows[i]["panel"]
			if Rect2(Vector2.ZERO, pc.size).has_point(pc.get_local_mouse_position()): ## telefonda katman ölçekli - yerel konum
				if i != _focus:
					_focus = i
					_update_focus()
				break
		return
	var handled := true
	if _act(event, ["ui_cancel", "pause_game"]) and not event.is_echo():
		close()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q \
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER:
		_cycle_category(-1)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_E, KEY_TAB] \
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
		_cycle_category(1)
	elif _act(event, ["ui_up", "move_up"]):
		_move_focus(-1)
	elif _act(event, ["ui_down", "move_down"]):
		_move_focus(1)
	elif _act(event, ["ui_left", "move_left"]):
		_step_focused(-1)
	elif _act(event, ["ui_right", "move_right"]):
		_step_focused(1)
	elif _act(event, ["ui_accept"]) and not event.is_echo():
		if _focus < _rows.size():
			(_rows[_focus]["activate"] as Callable).call(event is InputEventJoypadButton)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _step_focused(d: int) -> void:
	if _focus >= _rows.size():
		return
	if bool((_rows[_focus]["step"] as Callable).call(d)):
		UISound.play_click()


## Grup paneli (HUD, katman 96) ayarlar açıkken görünmez - kullanıcı (2026-10-19): "grup penceresi üstte görünmemeli ayarlar
## açıkken" (bkz. party_panel.gd set_suppressed).
func _enter_tree() -> void:
	get_tree().call_group(&"party_panel", &"set_suppressed", "settings", true)


func _exit_tree() -> void:
	get_tree().call_group(&"party_panel", &"set_suppressed", "settings", false)


## Ekranı kapatır: ESC/B ya da GERİ. Aynı basışla duraklatma menüsü de kapanmasın (main.gd / pause_menu.gd ui_cancel denetimi).
func close() -> void:
	_cancel_listen()
	GameManager.mark_ui_cancel_consumed()
	UISound.play_click()
	closed.emit()
	queue_free()
