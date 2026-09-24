class_name MenuKit
extends RefCounted

## Menü kiti (ana menü + tek/çok oyunculu karakter seçimi) için TEK giriş noktası.
## Kullanıcı isteği (2026-09-24): "ana menü, singleplayer ve multiplayer karakter menülerindeki tüm kartları ve arayüz
## arkaplanlarını daha güzel olacak şekilde sıfırdan tasarla. pixel tarzda 48x48 pixel sanatı varyantlarında hafif cozy
## aşırı koyu veya açık renkli olmayan ... bej/açık kahverengi tonlarında".
## Dokular tools/gen_menu_kit.py ile üretilir -> assets/ui/menu/*.png. Her sanat pikseli TAM 3 ekran pikseli (T) - kart
## portreleri de 3x çizildiği için çerçeve/karakter konturları aynı ızgarada. Metin: m5x7, 16'nın katı boyutlar (16/32/48/96).
## Oyun-içi arayüz (2026-09-24, "aynı tarz ama biraz daha koyu"): aynı üretici build_game() ile assets/ui/game/'e
## (GAME_DIR) biraz daha koyu bir palet yazar; oyun içi ekranlar bunu UIKit.theme() / UIKit.panel_style() üzerinden
## (build_theme(PAL_GAME)) kullanır. assets/ui/kit artık SADECE HUD parçaları (tools/gen_ui_kit.py).
## Kullanım: menünün kök Control'üne `theme = MenuKit.theme()` - Button/LineEdit/Slider/CheckButton/Option/ScrollBar/
## Tooltip hepsi otomatik bej kit görünümünü alır; paneller/başlıklar/kartlar için aşağıdaki yardımcılar.

const DIR := "res://assets/ui/menu/"
const FONT_PATH := "res://assets/fonts/m5x7.ttf"
const T := 3.0 ## 1 sanat pikseli = 3 ekran pikseli

## Kullanıcı bildirimi (2026-09-24): "karakter seçimlerinde bazı fontlar çok ufak ve zor okunuyor özellikle oda kurma
## kısmındaki bazı yazılar" - 16 (m5x7'nin 2x'i) 1080p'de okunmuyordu (ağ ipucu, "henüz bulunamadı", "Odada henüz kimse
## yok", bulunan oyun butonları, oyuncu satırındaki karakter adı/HAZIR rozeti). 24 = m5x7'nin tam 3x'i: font aynı, pikseller
## hâlâ tam sayı katında (keskin), sadece büyüdü.
const FS_SMALL := 24
const FS_BODY := 32
const FS_TITLE := 48
const FS_HUGE := 96

const C_TEXT := Color("#4a2c1a")
const C_TEXT_DIM := Color("#7a5534")
const C_ACCENT := Color("#9c4f27")   ## kiremit: bölüm başlıkları
const C_LINE := Color("#b3804b")     ## süs çizgileri
const C_GOOD := Color("#4d6a1f")
const C_BAD := Color("#a03d27")
const C_GOLD := Color("#b07a22")
const C_CREAM := Color("#fff3d8")
const C_OUTLINE := Color("#4a2c1a")
const C_WASH := Color(0.99, 0.90, 0.72, 0.16) ## arka plan manzarasının üstüne sıcak, hafif bej örtü

## Kart dokusu: 60x72 sanat px (gövde 58x70 + 1 px seçim parıltısı payı) - bkz. tools/gen_menu_kit.py card().
const CARD_SIZE := Vector2(180, 216)
const CARD_GROUND_Y := 144.0     ## (1 + 46 + 1) * 3: ayakların ALT kenarının ekran y'si (tümseğin orta satırı)
const CARD_PLATE_RECT := Rect2(15, 162, 150, 36) ## isim plakasının iç alanı (doku satır 54..65, sütun 5..54)

## Vitrin sahneleri (tools/gen_menu_kit.py stage()): ground_y = ayak alt kenarı (tümsek satırı + 1) x 3.
const STAGE_BIG := {"file": "stage_big.png", "size": Vector2(336, 420), "ground_y": 381.0, "scale": 6}
const STAGE_SMALL := {"file": "stage_small.png", "size": Vector2(336, 186), "ground_y": 153.0, "scale": 4}

static var _tex_cache: Dictionary = {}
static var _style_cache: Dictionary = {}
static var _theme: Theme = null


## Oyun içi kit (UIKit) aynı çizim/stil kodunu kullanır, sadece doku klasörü ve renkler farklı (bir ton koyu) -
## bkz. tools/gen_menu_kit.py build_game ve PAL_GAME.
const GAME_DIR := "res://assets/ui/game/"


static func tex(file: String, dir: String = DIR) -> Texture2D:
	var key: String = dir + file
	if _tex_cache.has(key):
		return _tex_cache[key]
	var t: Texture2D = load(key) as Texture2D
	_tex_cache[key] = t
	return t


static func font() -> Font:
	return load(FONT_PATH) as Font


## 9-slice doku stili. margins: sanat pikseli cinsinden [sol, üst, sağ, alt] doku payları; content: ekran px [sol, üst, sağ, alt].
static func _tex_style(file: String, margins: Array, content: Array, tile: bool = true, dir: String = DIR) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(file, dir)
	sb.texture_margin_left = margins[0] * T
	sb.texture_margin_top = margins[1] * T
	sb.texture_margin_right = margins[2] * T
	sb.texture_margin_bottom = margins[3] * T
	sb.content_margin_left = content[0]
	sb.content_margin_top = content[1]
	sb.content_margin_right = content[2]
	sb.content_margin_bottom = content[3]
	if tile:
		## Orta/kenar bantları esnetilmeden karo olarak tekrarlanır (parşömen benekleri 12 px periyotlu).
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return sb


## kind: panel (büyük pencere) / panel_tight / panel_small (ipucu, açılır liste) / inset (çukur alan) / inset_focus (odak halkası) /
## banner (kurdele başlık) / slot_normal / slot_hover / slot_selected / keycap / tag_ulti / tag_temel / tag_pasif
## dir: DIR (menü) ya da GAME_DIR (oyun içi) - iki kitte de aynı dosya adları/paylar (tools/gen_menu_kit.py).
static func style(kind: String, dir: String = DIR) -> StyleBox:
	var key: String = dir + "|" + kind
	if _style_cache.has(key):
		return _style_cache[key]
	var sb: StyleBox
	match kind:
		"panel":
			sb = _tex_style("panel.png", [10, 10, 10, 10], [27, 24, 27, 27], true, dir)
		"panel_tight":
			sb = _tex_style("panel.png", [10, 10, 10, 10], [20, 18, 20, 20], true, dir) ## 376 px yan panel - 40 = 336 px (vitrin sahnesi genişliği)
		"panel_small":
			sb = _tex_style("panel.png", [10, 10, 10, 10], [21, 15, 21, 18], true, dir)
		"inset":
			sb = _tex_style("inset.png", [4, 4, 4, 4], [12, 6, 12, 6], true, dir)
		"inset_focus":
			sb = _tex_style("inset_focus.png", [4, 4, 4, 4], [12, 6, 12, 6], true, dir)
		"banner":
			## Başlık kurdelesi her zaman dokunun kendi yüksekliğinde (72 px) çizilir - bkz. banner().
			sb = _tex_style("banner.png", [14, 8, 14, 11], [54, 3, 54, 21], false, dir)
		"slot_normal", "slot_hover", "slot_selected":
			sb = _tex_style(kind + ".png", [4, 4, 4, 4], [6, 6, 6, 6], false, dir)
		"keycap":
			sb = _tex_style("keycap.png", [3, 3, 3, 4], [9, 0, 9, 6], false, dir)
		"tag_ulti", "tag_temel", "tag_pasif":
			sb = _tex_style(kind + ".png", [3, 3, 3, 3], [9, 0, 9, 0], false, dir)
		_:
			sb = StyleBoxEmpty.new()
	_style_cache[key] = sb
	return sb


## variant: tan (varsayılan) / sage (onay: başla/hazır) / rose (tehlikeli: çıkış/odayı kapat) / bark (yalnız oyun kiti: koyu
## ikincil buton, krem yazı). state: normal/hover/pressed/disabled/focus.
static func button_style(variant: String, state: String, dir: String = DIR) -> StyleBox:
	return btn_style(dir, "btn_", variant, state, BTN_MARGINS, BTN_CONTENT, BTN_CONTENT_PRESSED)


## Menü butonu payları (sanat px doku payı / ekran px içerik payı). Oyun kiti daha sıkı yerleşimler için kendi paylarını
## verir (PAL_GAME "btn_*", UIKit.button_style).
const BTN_MARGINS := [8, 6, 8, 6]
const BTN_CONTENT := [24, 6, 24, 12]
const BTN_CONTENT_PRESSED := [24, 9, 24, 9]


## Ortak buton stili üretici: prefix "btn_" (24x16 sanat px) ya da "btn_mini_" (12x12, yalnız oyun kiti). Basılı durumda
## içerik payı ayrı (yüz 1 sanat pikseli aşağı çöker, yazı da onunla iner). focus dokusu yalnız halka (bkz. focus_ring).
static func btn_style(dir: String, prefix: String, variant: String, state: String, margins: Array, content: Array, content_pressed: Array) -> StyleBox:
	var key: String = "btn|%s|%s|%s|%s|%s|%s" % [dir, prefix, variant, state, margins, content]
	if _style_cache.has(key):
		return _style_cache[key]
	var sb: StyleBoxTexture
	if state == "focus":
		sb = _tex_style(prefix + "focus.png", margins, content, true, dir)
	elif state == "pressed":
		sb = _tex_style("%s%s_pressed.png" % [prefix, variant], margins, content_pressed, true, dir)
	else:
		sb = _tex_style("%s%s_%s.png" % [prefix, variant, state], margins, content, true, dir)
	_style_cache[key] = sb
	return sb


const BTN_TEXT := {
	"tan": [Color("#4a2c1a"), Color("#5a3620")],
	"sage": [Color("#2e3b14"), Color("#3a4a1a")],
	"rose": [Color("#4a1d0e"), Color("#5a2614")],
	"bark": [Color("#fff0d6"), Color("#ffffff")],
}

## Paletler: aynı tema kurucusu (build_theme) iki kit için. Oyun paleti bir ton koyu parşömen -> yazılar da bir ton koyu.
const PAL_MENU := {
	"dir": DIR, "text": C_TEXT, "dim": C_TEXT_DIM, "accent": C_ACCENT,
	"track": Color("#d3b686"), "track_edge": Color("#9a7a50"), "disabled_text": Color(0.42, 0.36, 0.30, 0.8),
}
const PAL_GAME := {
	"dir": GAME_DIR, "text": Color("#3a2212"), "dim": Color("#5e3f24"), "accent": Color("#8a3f1e"),
	"track": Color("#b99a6b"), "track_edge": Color("#7f613b"), "disabled_text": Color(0.36, 0.30, 0.24, 0.8),
	## Oyun içi butonlar eski kitin sıkı içerik paylarını korur (34-40 px'lik butonlar büyüyüp yerleşimleri bozmasın).
	"btn_margins": [8, 5, 8, 5], "btn_content": [18, 4, 18, 4], "btn_content_pressed": [18, 6, 18, 2],
}


## Tek bir butona (tema varsayılanı tan) başka bir varyant uygular.
static func style_button(btn: Button, variant: String = "tan", font_size: int = -1) -> void:
	if not is_instance_valid(btn):
		return
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(st, button_style(variant, st))
	var cols: Array = BTN_TEXT.get(variant, BTN_TEXT["tan"])
	btn.add_theme_color_override("font_color", cols[0])
	btn.add_theme_color_override("font_hover_color", cols[1])
	btn.add_theme_color_override("font_pressed_color", cols[0])
	btn.add_theme_color_override("font_focus_color", cols[0])
	btn.add_theme_color_override("font_hover_pressed_color", cols[0])
	if font_size > 0:
		btn.add_theme_font_size_override("font_size", font_size)


static func make_button(text: String, variant: String = "tan", font_size: int = FS_BODY, min_height: float = 48.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_height)
	b.focus_mode = Control.FOCUS_ALL
	if variant != "tan" or font_size != FS_BODY:
		style_button(b, variant, font_size)
	return b


## Mutlak yerleşim: konum/boyutu OFFSET olarak yazar (sol-üst çapa). `size = ...` ataması o anki minimum boyuta kırpılıp
## offset'lere KALICI yazılıyordu - ilk karede otomatik kaydırmalı etiketlerin genişliği henüz 0 olduğu için her kelime ayrı
## satıra düşüp minimum yükseklik geçici olarak binlerce px çıkıyor, panel o boyda kalıyordu (lobi sol paneli 3436 px, alt
## butonlar ekran dışında). Offset'ler kırpılmaz; Godot boyutu her yerleşimde offset'lerden yeniden hesaplar.
static func place(c: Control, pos: Vector2, sz: Vector2) -> void:
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + sz.x
	c.offset_bottom = pos.y + sz.y


static func make_label(text: String, font_size: int = FS_BODY, color: Color = C_TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func make_panel(kind: String = "panel") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(kind))
	return p


## Ekran başlığı: parşömen kurdele, koyu kahve 48 px yazı. Kurdele yazıya göre genişler, yüksekliği sabit (72 px).
static func make_banner(text: String, font_size: int = FS_TITLE) -> PanelContainer:
	var p := make_panel("banner")
	p.custom_minimum_size = Vector2(0, 72)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var l := make_label(text, font_size, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.name = "Text"
	p.add_child(l)
	return p


## Panel içi bölüm başlığı: kiremit renkli yazı + iki yanında süslü (elmas uçlu) 1 texel çizgi.
static func make_section_header(text: String, font_size: int = FS_BODY) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left: Control = MenuDividerScript.new()
	left.flip = false
	var right: Control = MenuDividerScript.new()
	right.flip = true
	var l := make_label(text, font_size, C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	l.name = "Text"
	h.add_child(left)
	h.add_child(l)
	h.add_child(right)
	return h


const MenuDividerScript: GDScript = preload("res://scripts/menu_divider.gd")


## Metni kutuya (max_width) sığana kadar 1'er 1'er küçültür (en az 16). Son çare: bugünkü isimlerin hepsi 32 px'te
## kart plakasına sığıyor (en uzunu "Assasin Çocuk" = 144 px, plaka 156 px) - m5x7 16'nın katı olmayan boyutlarda
## hafif düzensiz çizilir, o yüzden yalnızca gerçekten sığmayan yeni bir isim eklenirse devreye girer.
static func fit_label_font(label: Label, text: String, start_size: int, max_width: float) -> void:
	var f: Font = label.get_theme_font("font")
	if f == null:
		f = font()
	var size_px: int = start_size
	while size_px > FS_SMALL and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > max_width:
		size_px -= 1
	label.add_theme_font_size_override("font_size", size_px)


## Menü teması (kod ile kurulur, .tres yok): tüm standart kontroller bej kit görünümünü alır.
static func theme() -> Theme:
	if _theme == null:
		_theme = build_theme(PAL_MENU)
	return _theme


static var _theme_cache: Dictionary = {}


## Palet (PAL_MENU / PAL_GAME) ile tema kurar: Button/OptionButton/PopupMenu/Tooltip/LineEdit/ScrollBar/HSlider/CheckButton/
## Label/RichTextLabel. Oyun içi paneller UIKit.theme() ile PAL_GAME sürümünü kullanır (bkz. ui_kit.gd).
static func build_theme(pal: Dictionary) -> Theme:
	var dir: String = pal["dir"]
	if _theme_cache.has(dir):
		return _theme_cache[dir]
	var text: Color = pal["text"]
	var dim: Color = pal["dim"]
	var bm: Array = pal.get("btn_margins", BTN_MARGINS)
	var bc: Array = pal.get("btn_content", BTN_CONTENT)
	var bcp: Array = pal.get("btn_content_pressed", BTN_CONTENT_PRESSED)
	var th := Theme.new()
	th.default_font = font()
	th.default_font_size = FS_BODY

	th.set_color("font_color", "Label", text)
	th.set_color("font_outline_color", "Label", C_OUTLINE)
	th.set_constant("outline_size", "Label", 0)
	th.set_constant("line_spacing", "Label", 0)
	th.set_color("default_color", "RichTextLabel", text)
	th.set_color("font_outline_color", "RichTextLabel", C_OUTLINE)

	## Butonlar (tan)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		th.set_stylebox(st, "Button", btn_style(dir, "btn_", "tan", st, bm, bc, bcp))
	th.set_color("font_color", "Button", BTN_TEXT["tan"][0])
	th.set_color("font_hover_color", "Button", BTN_TEXT["tan"][1])
	th.set_color("font_pressed_color", "Button", BTN_TEXT["tan"][0])
	th.set_color("font_focus_color", "Button", BTN_TEXT["tan"][0])
	th.set_color("font_hover_pressed_color", "Button", BTN_TEXT["tan"][0])
	th.set_color("font_disabled_color", "Button", pal["disabled_text"])
	th.set_constant("outline_size", "Button", 0)

	## OptionButton = buton + ok ikonu
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		th.set_stylebox(st, "OptionButton", btn_style(dir, "btn_", "tan", st, bm, bc, bcp))
	th.set_icon("arrow", "OptionButton", tex("arrow_down.png", dir))
	th.set_color("font_color", "OptionButton", text)
	th.set_color("font_hover_color", "OptionButton", text)
	th.set_color("font_pressed_color", "OptionButton", text)
	th.set_color("font_focus_color", "OptionButton", text)
	th.set_color("font_disabled_color", "OptionButton", pal["disabled_text"])
	th.set_constant("arrow_margin", "OptionButton", 18)

	## Açılır liste / ipucu
	th.set_stylebox("panel", "PopupMenu", style("panel_small", dir))
	th.set_stylebox("hover", "PopupMenu", style("inset", dir))
	th.set_color("font_color", "PopupMenu", text)
	th.set_color("font_hover_color", "PopupMenu", text)
	th.set_color("font_disabled_color", "PopupMenu", dim)
	th.set_constant("v_separation", "PopupMenu", 6)
	th.set_stylebox("panel", "TooltipPanel", style("panel_small", dir))
	th.set_color("font_color", "TooltipLabel", text)
	th.set_font_size("font_size", "TooltipLabel", FS_BODY)

	## Metin girişi
	th.set_stylebox("normal", "LineEdit", style("inset", dir))
	th.set_stylebox("read_only", "LineEdit", style("inset", dir))
	th.set_stylebox("focus", "LineEdit", style("inset_focus", dir))
	th.set_color("font_color", "LineEdit", text)
	th.set_color("font_uneditable_color", "LineEdit", dim)
	th.set_color("font_placeholder_color", "LineEdit", Color(dim, 0.7))
	th.set_color("caret_color", "LineEdit", text)
	th.set_color("selection_color", "LineEdit", Color(0.92, 0.72, 0.28, 0.55))
	th.set_color("font_selected_color", "LineEdit", text)

	## Kaydırma: bej oluk + ahşap tutamak
	var track := StyleBoxFlat.new()
	track.bg_color = pal["track"]
	track.border_color = pal["track_edge"]
	track.set_border_width_all(3)
	track.set_corner_radius_all(3)
	track.content_margin_left = 9
	track.content_margin_right = 9
	for sb_owner in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox("scroll", sb_owner, track)
		th.set_stylebox("scroll_focus", sb_owner, track)
		th.set_stylebox("grabber", sb_owner, _tex_style("scroll_grab.png", [3, 3, 3, 3], [9, 9, 9, 9], false, dir))
		th.set_stylebox("grabber_highlight", sb_owner, _tex_style("scroll_grab_hover.png", [3, 3, 3, 3], [9, 9, 9, 9], false, dir))
		th.set_stylebox("grabber_pressed", sb_owner, _tex_style("scroll_grab_hover.png", [3, 3, 3, 3], [9, 9, 9, 9], false, dir))
	th.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	th.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	th.set_stylebox("panel", "Panel", StyleBoxEmpty.new())

	## Kaydırıcı (ses)
	th.set_stylebox("slider", "HSlider", _tex_style("slider_track.png", [3, 3, 3, 3], [0, 9, 0, 9], false, dir))
	th.set_stylebox("grabber_area", "HSlider", _tex_style("slider_fill.png", [3, 3, 3, 3], [0, 9, 0, 9], false, dir))
	th.set_stylebox("grabber_area_highlight", "HSlider", _tex_style("slider_fill.png", [3, 3, 3, 3], [0, 9, 0, 9], false, dir))
	th.set_icon("grabber", "HSlider", tex("knob.png", dir))
	th.set_icon("grabber_highlight", "HSlider", tex("knob_hover.png", dir))
	th.set_icon("grabber_disabled", "HSlider", tex("knob.png", dir))

	## Açma/kapama (tam ekran, FPS)
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		th.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
	for icon_name in ["checked", "checked_mirrored", "checked_disabled", "checked_disabled_mirrored"]:
		th.set_icon(icon_name, "CheckButton", tex("toggle_on.png", dir))
	for icon_name in ["unchecked", "unchecked_mirrored", "unchecked_disabled", "unchecked_disabled_mirrored"]:
		th.set_icon(icon_name, "CheckButton", tex("toggle_off.png", dir))
	th.set_color("font_color", "CheckButton", text)
	th.set_color("font_hover_color", "CheckButton", text)
	th.set_color("font_pressed_color", "CheckButton", text)

	_theme_cache[dir] = th
	return th


## Arka plan: mevcut piksel manzara (assets/ui/lobby_bg.png) + üstüne sıcak bej örtü (eski koyu gri örtü yerine).
static func add_background(root: Control) -> void:
	var bg := TextureRect.new()
	bg.name = "BackgroundImage"
	bg.texture = load("res://assets/ui/lobby_bg.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var wash := ColorRect.new()
	wash.name = "Wash"
	wash.color = C_WASH
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wash)


## Bir karakterin temel istatistikleri - ikon + değer (bkz. tools/gen_menu_kit.py STAT_ICONS). Tüm karakterler aynı
## temel değerlerle başlıyor (bkz. character_select.gd eski BASE_STATS).
const BASE_STATS := [
	{"icon": "stat_hp.png", "label": "Can", "value": "100"},
	{"icon": "stat_speed.png", "label": "Hız", "value": "240"},
	{"icon": "stat_dmg.png", "label": "Hasar", "value": "10"},
	{"icon": "stat_rate.png", "label": "Atış", "value": "1/sn"},
]


## Vitrin altındaki 2x2 istatistik kutusu (çukur bej zemin, ikon + değer).
static func make_stats_grid() -> PanelContainer:
	var box := make_panel("inset")
	var grid := GridContainer.new()
	grid.columns = 2
	## 2 sütun 32 px metinle 336 px'lik vitrine sığmalı (en geniş: "Hasar 10" + "Atış 1/sn" = 300 + paylar).
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	for s: Dictionary in BASE_STATS:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 9)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon := TextureRect.new()
		icon.texture = tex(str(s["icon"]))
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		var l := make_label("%s %s" % [s["label"], s["value"]], FS_BODY, C_TEXT)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(l)
		grid.add_child(cell)
	return box
