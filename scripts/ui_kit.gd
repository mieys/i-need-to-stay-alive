class_name UIKit
extends RefCounted

## Oyun içi arayüz kiti için TEK giriş noktası (dükkan, envanter, özellikler, seyyar satıcı, level atlama, sandık, silah
## seçimi, duraklatma/ayarlar, tuş atamaları, debug, görev bandı, HUD panelleri...).
## Kullanıcı isteği (2026-09-24): "aynı arayüz değişikliklerini tıpkı ana menülerde karakter seçimlerinde v.b yaptığın
## tarzdaki gibi oyun içi tüm arayüzler için de tasarlamanı istiyorum fakat biraz daha koyu olmalı (level atlama kartları
## v.b gibi tier bazlı kartların renklerinin buna göre tasarlanması gerekiyor)."
## -> Menülerle (MenuKit) AYNI çizim dili ve AYNI stil/tema kodu, sadece doku klasörü (assets/ui/game, tools/gen_menu_kit.py
##    build_game) ve renkler bir ton koyu (MenuKit.PAL_GAME): ahşap çerçeve + parşömen iç + pirinç çivi, koyu kahve yazı.
## Kullanım: oyun içi bir panelin/ekranın KÖK Control'üne `theme = UIKit.theme()` (Label/Button/LineEdit/Slider/Scroll...
## hepsi kit görünümünü ve koyu yazıyı alır). Projenin genel teması (assets/fonts/theme.tres) krem yazıyı korur - HUD'da oyun
## dünyasının ÜSTÜNDE duran yazılar (altın, sayaçlar, bildirimler) koyu zeminde okunmaya devam eder.
## API (panel_style / style_button / style_label / C_* / FS_*) eski kitle aynı - ~20 ekran değişmeden yeni görünümü aldı.
## HUD çerçeveleri (can/kalkan barı, avatar, yetenek slotları, minimap halkası, yetenek çubuğu, buff rozeti) ayrı:
## tools/gen_ui_kit.py -> assets/ui/kit (HUD yerleşimi o dokuların geometrisine bağlı, sadece paleti yeni kite uyarlandı).

const KIT := "res://assets/ui/kit/"      ## HUD çerçeveleri (tools/gen_ui_kit.py)
const GAME := MenuKit.GAME_DIR           ## paneller/butonlar/tier dokuları (tools/gen_menu_kit.py build_game)

## Yazı boyutları (m5x7: 16'nın/8'in katları keskin).
const FS_BODY := 32
const FS_TITLE := 48
const FS_BIG := 64

## Renk paleti: bej panel ÜSTÜNDE okunan koyu tonlar (MenuKit.PAL_GAME ile aynı).
const C_TEXT := Color("#3a2212")
const C_TEXT_DIM := Color("#5e3f24")
const C_ACCENT := Color("#8a3f1e")   ## kiremit: başlıklar
const C_GOLD := Color("#8a5608")     ## altın fiyat/sayılar (koyu altın - bej zeminde okunur)
const C_OUTLINE := Color("#3a2212")
const C_GOOD := Color("#3d6616")
const C_BAD := Color("#a3301c")
## Koyu zeminler (bark buton, oyun dünyası üstü) için açık yazı.
const C_CREAM := Color("#fff0d6")

## Parşömen üstünde okunan "mürekkep" renkleri (BBCode için hex) - eski koyu kitin parlak neon tonlarının (#55ff55,
## #66ccff, #ffaa00...) bej zemindeki karşılıkları. TEK kaynak: level atlama kartı açıklamaları (level_up_screen.gd),
## yetenek ipuçları (skill_icon.gd) ve kategori renkleri buradan okur.
const INK := {
	"health": "#2f7a1f",      ## can / yenilenme / sıvışma
	"damage": "#a82a1e",      ## hasar / kritik hasar / saldırı gücü
	"crit": "#b04a24",
	"speed": "#1f6a96",       ## hareket hızı / toplama mesafesi
	"attack_speed": "#96640a",
	"shield": "#2a58a8",      ## kalkan miktarı / soğurma
	"shield_pen": "#80580c",
	"exp": "#6a3496",
	"luck": "#86660a",
	"range": "#a4501e",
	"cooldown": "#3a5a8a",
	"value": "#a0560a",       ## sayılar (eskiden altın turuncusu #ffaa00)
	"passive": "#86660a",
	"text": "#3a2212",
}
## Kategori renkleri (level kartı "Saldırı/Savunma/Yardımcı", silah kartı "Yakın Dövüş/Menzilli/Kalkan").
const C_CAT_ATTACK := Color("#9a2e22")
const C_CAT_DEFENSE := Color("#3d6616")
const C_CAT_UTILITY := Color("#2c5c9a")

const STATES := ["normal", "hover", "pressed", "disabled", "focus"]

## Eski varyant adları -> oyun kiti buton paletleri (tools/gen_menu_kit.py GAME_BTN_PALS).
const VARIANTS := {"wood": "tan", "green": "sage", "red": "rose", "dark": "bark"}
## Buton payları: 24x16 sanat px doku, 9-slice payı 8/5 sanat px; içerik payları eski kitle aynı (sıkı yerleşimler bozulmasın).
const BTN_MARGINS := [8, 5, 8, 5]
const BTN_CONTENT := [18, 4, 18, 4]
const BTN_CONTENT_PRESSED := [18, 6, 18, 2]
## Mini (kare) buton: 12x12 sanat px, pay 4.
const MINI_MARGINS := [4, 4, 4, 4]
const MINI_CONTENT := [6, 6, 6, 6]
const MINI_CONTENT_PRESSED := [6, 8, 6, 4]

static var _tex_cache: Dictionary = {}
static var _style_cache: Dictionary = {}


## Oyun içi tema (bkz. dosya başı notu). Önbellekli - her ekran aynı Theme nesnesini paylaşır.
static func theme() -> Theme:
	return MenuKit.build_theme(MenuKit.PAL_GAME)


## HUD dokusu (assets/ui/kit).
static func tex(file: String) -> Texture2D:
	if _tex_cache.has(file):
		return _tex_cache[file]
	var t: Texture2D = load(KIT + file) as Texture2D
	_tex_cache[file] = t
	return t


## Oyun kiti dokusu (assets/ui/game): tier kartları/slotları vb.
static func game_tex(file: String) -> Texture2D:
	return MenuKit.tex(file, GAME)


static func button_style(variant: String = "wood", state: String = "normal", mini: bool = false) -> StyleBox:
	var v: String = VARIANTS.get(variant, variant)
	if mini:
		return MenuKit.btn_style(GAME, "btn_mini_", v, state, MINI_MARGINS, MINI_CONTENT, MINI_CONTENT_PRESSED)
	return MenuKit.btn_style(GAME, "btn_", v, state, BTN_MARGINS, BTN_CONTENT, BTN_CONTENT_PRESSED)


## Herhangi bir Button'a tek çağrıda 5 durumlu kit stilini + varyantın yazı renklerini uygular.
## variant: wood (varsayılan, ten) / green (onay/satın al/başla, adaçayı) / dark (ikincil, koyu ahşap + krem yazı) /
## red (tehlikeli/kapat, kiremit). Yazı rengi VARYANTA göre her zaman yazılır (eski koyu kitte krem yazı sabitti; açık
## butonlar üstünde krem okunmazdı) - özel bir renk isteyen çağıran, bu çağrıdan SONRA kendi rengini verir.
static func style_button(btn: Button, variant: String = "wood", mini: bool = false, font_size: int = -1) -> void:
	if not is_instance_valid(btn):
		return
	for st in STATES:
		btn.add_theme_stylebox_override(st, button_style(variant, st, mini))
	var v: String = VARIANTS.get(variant, variant)
	var cols: Array = MenuKit.BTN_TEXT.get(v, MenuKit.BTN_TEXT["tan"])
	btn.add_theme_color_override("font_color", cols[0])
	btn.add_theme_color_override("font_hover_color", cols[1])
	btn.add_theme_color_override("font_pressed_color", cols[0])
	btn.add_theme_color_override("font_focus_color", cols[0])
	btn.add_theme_color_override("font_hover_pressed_color", cols[0])
	btn.add_theme_color_override("font_disabled_color", MenuKit.PAL_GAME["disabled_text"])
	btn.add_theme_constant_override("outline_size", 0)
	if font_size > 0:
		btn.add_theme_font_size_override("font_size", font_size)


## Panel türleri: window / window_tight (ahşap pencere + parşömen iç), inset (çukur bej alan), card / card_selected /
## card_sold (eşya kartı), plaque (başlık levhası: parşömen şerit, koyu yazı), banner (kurdele), status_badge / ability_bar
## (HUD, assets/ui/kit). İçerik payları eski kitle AYNI (mevcut ekranların yerleşimi değişmesin).
static func panel_style(kind: String = "window") -> StyleBox:
	var key: String = "p|" + kind
	if _style_cache.has(key):
		return _style_cache[key]
	var sb: StyleBox
	match kind:
		"window":
			sb = MenuKit._tex_style("panel.png", [10, 10, 10, 10], [44, 44, 44, 44], true, GAME)
		"window_tight":
			sb = MenuKit._tex_style("panel.png", [10, 10, 10, 10], [18, 18, 18, 18], true, GAME)
		"window_small":
			## Küçük HUD pencereleri (takım listesi, hediye/istatistik açılır pencereleri) - aynı ahşap çerçeve, dar iç boşluk.
			sb = MenuKit._tex_style("panel.png", [10, 10, 10, 10], [14, 12, 14, 12], true, GAME)
		"inset":
			sb = MenuKit._tex_style("inset.png", [4, 4, 4, 4], [12, 12, 12, 12], true, GAME)
		"inset_tight":
			sb = MenuKit._tex_style("inset.png", [4, 4, 4, 4], [6, 4, 6, 4], true, GAME)
		"card":
			sb = MenuKit._tex_style("card_normal.png", [5, 5, 5, 5], [14, 14, 14, 14], true, GAME)
		"card_selected":
			sb = MenuKit._tex_style("card_selected.png", [5, 5, 5, 5], [14, 14, 14, 14], true, GAME)
		"card_sold":
			sb = MenuKit._tex_style("card_sold.png", [5, 5, 5, 5], [14, 14, 14, 14], true, GAME)
		"plaque":
			sb = MenuKit._tex_style("plaque.png", [6, 5, 6, 5], [22, 6, 22, 6], false, GAME)
		"banner":
			sb = MenuKit.style("banner", GAME)
		"status_badge":
			## Buff/debuff rozetleri (status_effect_badge.gd) - HUD dokusu, bkz. tools/gen_ui_kit.py status_badge_panel.
			var b := StyleBoxTexture.new()
			b.texture = tex("panel_status_badge.png")
			_margins(b, 10.0, 4.0)
			sb = b
		"ability_bar":
			## Yetenek çubuğunun arkası (hud.gd _create_ability_bar_frame) - oval uçlu ince ahşap pervaz, HUD dokusu.
			## Pay yarıçaptan küçük OLAMAZ yoksa eğri kesilip esnetilir (bkz. tools/gen_ui_kit.py ability_bar_panel).
			var a := StyleBoxTexture.new()
			a.texture = tex("panel_ability_bar.png")
			a.texture_margin_left = 30.0
			a.texture_margin_right = 30.0
			a.texture_margin_top = 26.0
			a.texture_margin_bottom = 26.0
			a.content_margin_left = 10.0
			a.content_margin_right = 10.0
			a.content_margin_top = 6.0
			a.content_margin_bottom = 6.0
			sb = a
		"hud_flat":
			## Sade HUD kutusu (kullanıcı isteği 2026-09-25: grup paneli / hasar tablosu "daha basit, gereksiz çerçeve
			## ayrıntısı olmasın") - yarı saydam koyu ceviz zemin + 2 px ahşap kenar, piksel köşe (kenar yumuşatma yok).
			sb = _flat(HUD_FLAT_BG, HUD_FLAT_BORDER, 8.0, 6.0)
		"hud_flat_btn":
			sb = _flat(Color(0.26, 0.17, 0.1, 0.92), HUD_FLAT_BORDER, 8.0, 2.0)
		"hud_flat_btn_hover":
			sb = _flat(Color(0.36, 0.24, 0.14, 0.95), Color(0.66, 0.48, 0.28), 8.0, 2.0)
		"hud_flat_btn_pressed":
			sb = _flat(Color(0.18, 0.11, 0.06, 0.95), HUD_FLAT_BORDER, 8.0, 2.0)
		_:
			sb = StyleBoxEmpty.new()
	_style_cache[key] = sb
	return sb


const HUD_FLAT_BG := Color(0.11, 0.075, 0.05, 0.8)
const HUD_FLAT_BORDER := Color(0.47, 0.33, 0.19, 1.0)
## Koyu sade kutuların üstündeki açık yazı renkleri.
const HUD_TEXT_LIGHT := Color(0.95, 0.9, 0.8)
const HUD_TEXT_DIM := Color(0.72, 0.64, 0.52)
const HUD_TEXT_ACCENT := Color(1.0, 0.8, 0.42)


static func _flat(bg: Color, border: Color, pad_x: float, pad_y: float) -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.bg_color = bg
	f.border_color = border
	f.set_border_width_all(2)
	f.set_corner_radius_all(3)
	f.anti_aliasing = false
	f.content_margin_left = pad_x
	f.content_margin_right = pad_x
	f.content_margin_top = pad_y
	f.content_margin_bottom = pad_y
	return f


## Sade (hud_flat) küçük buton: düz koyu zemin, ahşap kenar, açık yazı.
static func style_flat_button(btn: Button, font_size: int = 16) -> void:
	btn.add_theme_stylebox_override("normal", panel_style("hud_flat_btn"))
	btn.add_theme_stylebox_override("hover", panel_style("hud_flat_btn_hover"))
	btn.add_theme_stylebox_override("pressed", panel_style("hud_flat_btn_pressed"))
	btn.add_theme_stylebox_override("disabled", panel_style("hud_flat_btn_pressed"))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, HUD_TEXT_LIGHT)
	btn.add_theme_color_override("font_disabled_color", HUD_TEXT_DIM)


static func _margins(sb: StyleBoxTexture, tex_margin: float, content: float) -> void:
	sb.texture_margin_left = tex_margin
	sb.texture_margin_right = tex_margin
	sb.texture_margin_top = tex_margin
	sb.texture_margin_bottom = tex_margin
	sb.content_margin_left = content
	sb.content_margin_right = content
	sb.content_margin_top = content
	sb.content_margin_bottom = content


## Bir Label'a kit yazı stili uygular. outline > 0: yalnızca AÇIK renkli yazılarda (oyun dünyası/koyu zemin üstü) koyu
## kontur çizilir - bej panel üstündeki koyu yazıya kontur eklemek harfleri kalınlaştırıp bulanıklaştırırdı.
static func style_label(lbl: Label, font_size: int = FS_BODY, color: Color = C_TEXT, outline: int = 0) -> void:
	if not is_instance_valid(lbl):
		return
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	if outline > 0 and color.get_luminance() > 0.55:
		lbl.add_theme_color_override("font_outline_color", C_OUTLINE)
		lbl.add_theme_constant_override("outline_size", outline)
	else:
		lbl.add_theme_constant_override("outline_size", 0)
