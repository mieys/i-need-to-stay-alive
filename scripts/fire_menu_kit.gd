extends RefCounted

## "ATEŞ IŞIĞI" menü dili - duraklatma (ESC) menüsü + ayarlar ekranının ortak parçaları (2026-10-17, madde 234; prototip B,
## madde 229). Kaynak dil ana menünün D sol menüsü (madde 192): kutu yok, sol taraf yumuşak kararır (sol_golge.png), büyük
## altın başlık + kiriş süsü, öğeler = mum yuvası + ikon + başlık + alt yazı, seçilide yanan mum + altın yazı.
## Renkler/ölçüler main_menu.gd ile AYNI değerler (orada kendi kopyası var; birini değiştirirsen ötekini de).

const DK := preload("res://scripts/menu_dark_kit.gd")
const UiAnim := preload("res://scripts/ui_anim.gd")

const COL_W := 560.0
const ITEM_H := 92.0
const ITEM_ICON := 48.0
const TITLE_POS := Vector2(48, 72)
const COL_POS := Vector2(40, 320) ## ana menü MenuPanel ile aynı yer

## Renkler static var: telefonda (2026-10-19, kullanıcı seçimi "A düzeni + B renkleri") use_phone_palette() Gece Sıvası'na çevirir;
## kaydırıcı / seçici / ipucu çizimleri hep buradan okur. Masaüstünde Ateş Işığı değerleri.
static var C_GOLD := Color("#f4c56e")
static var C_GOLD_DIM := Color("#e2c08a")
static var C_CREAM := Color("#efe2c6")
static var C_SUB := Color("#b09878")
static var C_TAG := Color("#c8b28e")
static var C_RED := Color("#dc7f60")
static var C_DARK := Color("#140e09") ## kaydırıcı yuvası
static var C_LINE := Color("#3b2a1a")
static var C_KNOB_DK := Color("#1a110a")


## on: telefon (Gece Sıvası, MenuDarkKit renkleri); false: masaüstü Ateş Işığı. Ekranlar kurulurken çağırır (testler aynı süreçte
## iki kipi de açtığı için tek seferlik değil).
static func use_phone_palette(on: bool) -> void:
	C_GOLD = Color("#f4c56e")
	C_GOLD_DIM = Color("#e2c08a")
	C_CREAM = Color("#efe6d6") if on else Color("#efe2c6")
	C_SUB = Color("#a7a2c0") if on else Color("#b09878")
	C_TAG = Color("#a7a2c0") if on else Color("#c8b28e")
	C_RED = Color("#e38c7c") if on else Color("#dc7f60")
	C_DARK = Color("#12121f") if on else Color("#140e09")
	C_LINE = Color("#3b3a5a") if on else Color("#3b2a1a")
	C_KNOB_DK = Color("#0a0a12") if on else Color("#1a110a")

const CANDLES_PATH := "res://harita/Ev içi/Candles.png"
const SHADE_PATH := "res://assets/ui/ana_menu/sol_golge.png"
const TRIM_PATH := "res://assets/ui/ana_menu/kiris_suslu.png"

const G_DIAMOND := ["..#..", ".###.", "#####", ".###.", "..#.."]


## Ana menünün yanan mumu (Candles.png 3. sütun, iki alev karesi).
class Candle extends Control:
	const COL := 3
	var tex: Texture2D = null
	var _t: float = 0.0

	func _init(t: Texture2D) -> void:
		tex = t
		custom_minimum_size = Vector2(64, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		process_mode = Node.PROCESS_MODE_ALWAYS ## duraklatılmış ağaçta da titresin

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if tex == null:
			return
		var row: int = int(_t * 4.0) % 2
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, Vector2(64, 64)), Rect2(Vector2(COL * 32, row * 32), Vector2(32, 32)))


## Karartma bandı: x0'a kadar tam, sonra steps * step_w genişliğinde YUMUŞAK söner (ayar satırlarının okunurluğu). Ad eski:
## 2026-10-20'ye kadar step_w'lik basamaklarla sönüyordu ("pixel pixel" bulundu); şimdi köşe renkli dilimlerle smoothstep geçişi.
class StepShade extends Control:
	const FADE_SLICES := 16
	var col: Color = Color(0.05, 0.035, 0.025, 0.8)
	var x0: float = 1520.0
	var step_w: float = 48.0
	var steps: int = 6

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, x0, size.y), col)
		var fade_w: float = step_w * steps
		for i in FADE_SLICES:
			var xa: float = x0 + fade_w * float(i) / FADE_SLICES
			var xb: float = x0 + fade_w * float(i + 1) / FADE_SLICES
			var ca := Color(col, col.a * _ease(float(i) / FADE_SLICES))
			var cb := Color(col, col.a * _ease(float(i + 1) / FADE_SLICES))
			draw_polygon(PackedVector2Array([Vector2(xa, 0), Vector2(xb, 0), Vector2(xb, size.y), Vector2(xa, size.y)]),
				PackedColorArray([ca, cb, cb, ca]))

	static func _ease(t: float) -> float: ## 0 -> 1 (tam), 1 -> 0
		return 1.0 - smoothstep(0.0, 1.0, t)


static func lbl(t: String, fs: int, c: Color) -> Label:
	var l := DK.lbl(t, fs, c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


static func tex_icon(tex: Texture2D, s: float = ITEM_ICON) -> Control:
	return DK.icon(tex, s)


## Sol yumuşak karartma (ana menü sahnesindeki ile aynı doku, 480x1, DOĞRUSAL gerilir), tam ekran. 2026-10-20'ye kadar doku Bayer
## titreşimli basamaklıydı ve en yakın komşuyla gerildiği için ESC menüsünde soldan 4 px'lik dama deseni görünüyordu.
static func left_shade() -> TextureRect:
	var shade := TextureRect.new()
	shade.texture = load(SHADE_PATH)
	shade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	return shade


## Büyük altın başlık + altında satır (Control) + kiriş süsü. Konum: TITLE_POS.
static func title_block(title: String, sub: Control) -> VBoxContainer:
	var logo := DK.v(4)
	logo.name = "TitleSign"
	var t := DK.lbl(title, 72, C_GOLD)
	t.name = "Title"
	t.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03, 1))
	t.add_theme_constant_override("outline_size", 12)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	t.add_theme_constant_override("shadow_offset_y", 6)
	logo.add_child(t)
	if sub:
		logo.add_child(sub)
	logo.add_child(DK.sp(0, 10))
	var trim := TextureRect.new()
	trim.texture = load(TRIM_PATH)
	trim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	trim.stretch_mode = TextureRect.STRETCH_TILE
	trim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trim.custom_minimum_size = Vector2(480, 48)
	trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.add_child(trim)
	return logo


## Bir menü öğesi: görünmez düğme + mum yuvası, ikon, başlık, alt yazı. follow_focus: fare üstü = odak, odak = seçili görünüm
## (ESC menüsü). false ise seçili görünüm elle verilir (ayarlar kategorileri - klavye satırları gezer, kategori Q/E ile değişir).
static func item(title: String, sub: String, icon: Control, danger: bool = false, follow_focus: bool = true) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(COL_W, ITEM_H)
	b.flat = true
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var row := DK.h(14)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var candle := Candle.new(load(CANDLES_PATH) as Texture2D)
	candle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	candle.visible = false
	var slot := CenterContainer.new()
	slot.custom_minimum_size = Vector2(64, 64)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(candle)
	row.add_child(slot)
	var ib := CenterContainer.new()
	ib.custom_minimum_size = Vector2(ITEM_ICON * 1.6, ITEM_ICON)
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon:
		ib.add_child(icon)
	row.add_child(ib)
	var v := DK.v(-2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := lbl(title, DK.FS_TITLE, C_RED if danger else C_CREAM)
	v.add_child(tl)
	var sl := lbl(sub, DK.FS_LABEL, C_SUB)
	sl.visible = sub != ""
	v.add_child(sl)
	row.add_child(v)
	b.add_child(row)
	b.set_meta("fm_item", {"title": tl, "sub": sl, "candle": candle, "danger": danger, "row": row})
	if follow_focus:
		b.mouse_entered.connect(func() -> void:
			if b.focus_mode != Control.FOCUS_NONE and not b.disabled:
				b.grab_focus())
		b.focus_entered.connect(func() -> void: set_selected(b, true))
		b.focus_exited.connect(func() -> void: set_selected(b, false))
	return b


static func set_selected(b: Button, on: bool) -> void:
	if not b.has_meta("fm_item"):
		return
	var it: Dictionary = b.get_meta("fm_item")
	var tl: Label = it["title"]
	var sl: Label = it["sub"]
	(it["candle"] as Control).visible = on
	UiAnim.slide_x(it["row"] as Control, 12.0 if on else 0.0) ## seçili öğe hafifçe öne (sağa) çıkar, madde 200
	if on:
		tl.add_theme_color_override("font_color", C_GOLD)
		tl.add_theme_color_override("font_outline_color", Color(0.35, 0.16, 0.04, 1))
		tl.add_theme_constant_override("outline_size", 6)
		sl.add_theme_color_override("font_color", C_GOLD_DIM)
	else:
		var dis: bool = b.disabled
		tl.add_theme_color_override("font_color", C_SUB if dis else (C_RED if bool(it["danger"]) else C_CREAM))
		tl.add_theme_constant_override("outline_size", 0)
		sl.add_theme_color_override("font_color", C_SUB)


static func set_texts(b: Button, title: String, sub: String) -> void:
	if not b.has_meta("fm_item"):
		return
	var it: Dictionary = b.get_meta("fm_item")
	(it["title"] as Label).text = title
	(it["sub"] as Label).text = sub
	(it["sub"] as Label).visible = sub != ""


## Alt köşedeki tuş ipuçları: [[tuş, açıklama], ...]
static func hint(pairs: Array) -> HBoxContainer:
	var h := DK.h(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in pairs.size():
		var pr: Array = pairs[i]
		if i > 0:
			h.add_child(DK.sp(18))
		var p := PanelContainer.new()
		var s := DK.sb(Color(0.08, 0.05, 0.03, 0.85), Color("#6a5440"), 2, 4)
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 2
		s.content_margin_bottom = 2
		p.add_theme_stylebox_override("panel", s)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p.add_child(DK.lbl(str(pr[0]), DK.FS_LABEL, C_CREAM, HORIZONTAL_ALIGNMENT_CENTER))
		h.add_child(p)
		h.add_child(DK.lbl(str(pr[1]), DK.FS_LABEL, C_TAG))
	return h
